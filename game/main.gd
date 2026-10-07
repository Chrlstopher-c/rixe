extends Node2D
## Point d'entrée : construit le monde et enchaîne les manches (toi contre des bots, chacun pour soi).

const PLAYER_COLOR := Spawner.PLAYER_COLOR

var round_no := 1
var seed_base := 1
var demo := false
var attract := false
var _skip_title := false
var _menu: CanvasLayer
var _backdrop: CanvasLayer
var _volume := 0.8
var score := RunScore.new()
var game_mode := "arcade"
var game_option := 0
var match_state := MatchState.new("arcade")
## Active les règles de partie pendant les tests (désactivées par défaut pour isoler les scénarios).
var live_rules := false
## Carte imposée (tests, --map=…) ; vide = au hasard à chaque manche.
var forced_map := ""
var _scoreboard: CanvasLayer
var _inventory: CanvasLayer
var spawner: Spawner
var rules := RoundRules.new(self)
var director: SurvivalDirector
var duo: Duo
var _post: CanvasLayer
var player: Fighter
var _fighters: Node2D
var _hud: CanvasLayer
var _camera: Camera2D
var _restart_in := -1.0
## Fin de partie différée le temps de la kill cam (secondes réelles, -1 = rien en attente).
var _end_in := -1.0
var _rng := RandomNumberGenerator.new()
var _tests := ""
var _off: PackedStringArray = []


func _ready() -> void:
	Controls.register()
	var prefs := Settings.load_all()
	Juice.hd = prefs.hd
	_volume = prefs.volume
	Settings.apply_volume(_volume)
	Bootstrap.parse_args(self)
	Bootstrap.build(self)
	Juice.fighter_killed.connect(rules.on_killed)
	_set_hd(Juice.hd)
	if _tests != "":
		add_child(preload("res://tests/test_runner.gd").new(self, _tests))
		return
	Sfx.start_music()
	attract = not demo and not _skip_title
	if attract:
		_hud.visible = false
		_menu.show_title()
	_start_round()


func _shot(path: String) -> void:
	await get_tree().create_timer(6.0, true, false, true).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("shot %s %dx%d" % [path, img.get_width(), img.get_height()])
	get_tree().quit()


func _child(parent: Node, node: Node) -> Node:
	parent.add_child(node)
	return node


func _start_round() -> void:
	_clear_world()
	_rng.seed = seed_base * 1000 + round_no
	var map_type: String = forced_map if forced_map != "" else Maps.pick(_rng)
	if game_mode == "survie" and not attract:
		map_type = "survie"
	Juice.arena.generate(_rng.seed, map_type)
	Juice.stains.configure(Juice.arena.W)
	_camera.limit_right = int(Juice.arena.W) + 20
	var theme_name: String = Themes.names()[_rng.randi_range(0, Themes.names().size() - 1)]
	apply_theme(theme_name)
	var w: Array = Weather.pick(map_type, theme_name, _rng)
	Juice.wind = w[1]
	Juice.weather.set_kind(w[0])
	var b := _populate_survival() if game_mode == "survie" and not attract else _populate()
	if not _net_guest():
		spawner.spawn_pickups()
	if duo and not attract:
		duo.enter()
		duo.bind()
		duo.split.set_theme(theme_name)
	_camera.target = player
	_camera.snap_to(player.global_position + Vector2(0, -34))
	_hud.player = player
	_hud.round_no = round_no
	_hud.bots_left = b
	for f in _fighters.get_children():
		if f is Fighter and not f.is_queued_for_deletion():
			match_state.register(f)
	if Juice.net and not attract:
		Juice.net.round_started()
	var head := "MANCHE %d" % round_no if game_mode == "arcade" or attract else Modes.label(game_mode)
	_hud.banner("%s  ·  %s" % [head, Maps.ALL[map_type].label])
	Sfx.play_ui("round", -6.0)


func _clear_world() -> void:
	_end_in = -1.0
	Juice.reset()
	for c in _fighters.get_children():
		c.queue_free()
	for c in Juice.world.get_children():
		if c is Ragdoll or c is WeaponPickup or c is AttachmentPickup or c is Grenade or c is Loot:
			c.queue_free()
	Juice.fx.clear()
	Juice.stains.clear()


## Joueur et bots sur des points d'apparition distincts ; renvoie le nombre de bots.
func _populate() -> int:
	var n := mini(2 + round_no, 6) if game_mode == "arcade" or attract else 5
	var spots: Array = Juice.arena.spawn_points(n + 1, _rng)
	var mine := _rng.randi_range(0, spots.size() - 1)
	var taken := -1
	if _net_guest():
		player = Juice.net.spawn_guest(Juice.net.guest_spot)
		return 0
	if duo and not attract:
		taken = duo.populate(spots, mine)
	else:
		var brain: RefCounted = BotBrain.new(1.0, "acrobate") if demo or attract else PlayerBrain.new()
		player = _spawn_player(spots[mine], brain)
	if Juice.net and not attract:
		taken = (mine + 1) % spots.size()
		Juice.net.guest_spot = spots[taken]
		if game_mode == "arcade":
			player.team = "joueurs"
	spawner.clear_names()
	var b := 0
	for i in spots.size():
		if i != mine and i != taken:
			_spawn_bot(spots[i], "")
			b += 1
	return b


## Survie : le joueur seul, une pioche en seconde arme ; le directeur gère ressources, nuit et pillards.
func _populate_survival() -> int:
	if is_instance_valid(director):
		director.queue_free()
	director = SurvivalDirector.new()
	director.spawn_bot = func(pos: Vector2) -> Node2D: return _spawn_bot(pos, "")
	director.backdrop = _backdrop
	add_child(director)
	var spots: Array = Juice.arena.spawn_points(1, _rng)
	player = _spawn_player(spots[0] if not spots.is_empty() else Vector2(Juice.arena.W * 0.5, -200), PlayerBrain.new())
	player.inventory.take(Gun.new(player, "pickaxe"))
	player.inventory.select(0)
	director.bind_player(player)
	return 0


func reset_for_test() -> void:
	Juice.reset()
	for c in _fighters.get_children():
		c.free()
	for c in Juice.world.get_children():
		if c is Ragdoll or c is WeaponPickup or c is AttachmentPickup or c is Grenade or c is Loot:
			c.free()
	Juice.fx.clear()
	Juice.arena.generate_flat()


## Pluie sur les toits (et parfois ailleurs), neige sur l'acier, rien sous terre ; vent tiré au sort.
func apply_theme(name: String) -> void:
	Juice.arena.set_theme(name)
	if _backdrop:
		_backdrop.set_theme(name)


func follow(f: Fighter) -> void:
	_camera.target = f
	_camera.snap_to(f.global_position + Vector2(0, -34))
	_hud.player = f


func spawn_test_fighter(pos: Vector2, brain: RefCounted, weapon: String = "rifle", is_player: bool = true) -> Fighter:
	var f := _spawn("Test", pos, PLAYER_COLOR, brain, weapon, is_player)
	f.shield = 0.0
	return f


func _spawn(nm: String, pos: Vector2, color: Color, brain: RefCounted, weapon: String, is_player: bool,
		mods: Dictionary = {}) -> Fighter:
	return spawner.spawn(nm, pos, color, brain, weapon, is_player, mods)


func _spawn_player(pos: Vector2, brain: RefCounted) -> Fighter:
	return spawner.spawn_player(pos, brain)


func _spawn_bot(pos: Vector2, name: String) -> Fighter:
	var level := clampf(0.25 + round_no * 0.08, 0.25, 0.8) if game_mode == "arcade" else 0.45
	return spawner.spawn_bot(pos, name, level)


func _respawn(entry: Dictionary) -> void:
	var pos := spawner.far_spawn()
	if Juice.net and Juice.net.respawn(entry, pos):
		return
	if duo and duo.respawn(entry, pos):
		pass
	elif entry.player:
		var brain: RefCounted = BotBrain.new(1.0, "acrobate") if demo else PlayerBrain.new()
		if duo:
			var kb := PlayerBrain.new()
			kb.pad_enabled = false
			brain = kb
		player = _spawn_player(pos, brain)
		_camera.target = player
		_hud.player = player
		if duo:
			duo.split.follow(0, player)
	else:
		_spawn_bot(pos, entry.name)
	Juice.fx.emit(5, pos + Vector2(0, -20), Vector2.ZERO, 0.4, 24.0, Color(entry.color * 1.8, 0.8))


func _process(delta: float) -> void:
	var real: float = Juice.real_delta(delta)
	if _restart_in >= 0.0:
		_restart_in -= real
		if _restart_in < 0.0:
			_start_round()
	if _end_in >= 0.0:
		_end_in -= real
		if _end_in < 0.0:
			rules.end_match()
		return
	if _tests == "" or live_rules:
		Sfx.tension = rules.last_stand()
	if attract or demo or match_state == null or not Modes.respawns(game_mode) or _scoreboard.visible:
		return
	if _net_guest():
		return
	for entry in match_state.tick(real):
		_respawn(entry)
	_hud.respawn_t = match_state.respawn_in("Toi")
	if match_state.over:
		rules.end_match()


func _unhandled_input(event: InputEvent) -> void:
	var k := Controls.menu_key(event)
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B:
		k = 0
	if k != 0:
		match k:
			KEY_F1:
				_set_hd(not Juice.hd)
			KEY_ESCAPE:
				if not attract and not demo:
					_pause()
			KEY_B:
				if is_instance_valid(director) and not get_tree().paused:
					director.builder.toggle()
			KEY_C:
				if is_instance_valid(director) and not get_tree().paused:
					director.state.eat()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				if is_instance_valid(director) and director.builder.active:
					director.builder.select(k - KEY_1)
			KEY_TAB:
				if not attract and not demo and not _menu.visible and not _scoreboard.visible:
					_toggle_inventory()


## Invité d'une partie en ligne : la partie (manches, bots, objets) est menée par l'hôte.
func _net_guest() -> bool:
	return Juice.net != null and not Juice.net.is_host() and not attract


func _on_start(mode: String, option: int, first_round: int = 1) -> void:
	_leave_survival()
	var two: bool = _menu.players == 2 and mode != "survie"
	if two and duo == null:
		duo = Duo.new(self)
	elif not two and duo:
		duo.leave()
		duo = null
	game_mode = mode
	game_option = option
	attract = false
	round_no = first_round
	_restart_in = -1.0
	_menu.close()
	_scoreboard.close()
	get_tree().paused = false
	_hud.visible = true
	_hud.mode = mode
	score.reset()
	_hud.kills = 0
	match_state = MatchState.new(mode, option)
	_hud.match_state = match_state
	_start_round()
	_set_hd(Juice.hd)


## Écran partagé : la vue principale ne montre plus le monde (sa caméra regarde ailleurs) ni son interface.
func _set_root_view(on: bool) -> void:
	_camera.enabled = on
	if not on:
		get_viewport().canvas_transform = Transform2D(0.0, Vector2(-100000, -100000))
	for layer in [_backdrop, _post, _hud]:
		if layer:
			layer.visible = on


func _leave_survival() -> void:
	if is_instance_valid(director):
		director.queue_free()
	director = null
	if _backdrop:
		_backdrop.set_tint(Color.WHITE)


func _to_title() -> void:
	_leave_survival()
	if duo:
		duo.leave()
		duo = null
	_scoreboard.close()
	get_tree().paused = false
	attract = true
	game_mode = "arcade"
	round_no = 1
	_restart_in = -1.0
	_hud.visible = false
	match_state = MatchState.new("arcade")
	_menu.best = score.best
	_menu.show_title()
	_start_round()
	_set_hd(Juice.hd)


func _toggle_inventory() -> void:
	if _inventory.visible:
		_inventory.close()
		_hud.visible = true
		get_tree().paused = false
		_set_hd(Juice.hd)
	elif is_instance_valid(player) and player.alive:
		_inventory.open(player)
		_hud.visible = false
		get_tree().paused = Juice.net == null
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _pause() -> void:
	get_tree().paused = true
	_menu.volume = _volume
	_menu.hd = Juice.hd
	_menu.show_pause()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume() -> void:
	_menu.close()
	get_tree().paused = false
	_set_hd(Juice.hd)


func _on_volume(v: float) -> void:
	_volume = v
	Settings.apply_volume(v)
	Settings.save_all(_volume, Juice.hd)


func _set_hd(on: bool) -> void:
	Juice.hd = on
	var w := get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if on else Window.CONTENT_SCALE_MODE_VIEWPORT
	get_viewport().msaa_2d = Viewport.MSAA_4X if on and not ("msaa" in _off) else Viewport.MSAA_DISABLED
	var menu_open: bool = _menu != null and _menu.visible
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if not (demo or menu_open) else Input.MOUSE_MODE_VISIBLE
	if _menu:
		_menu.hd = on
		Settings.save_all(_volume, on)
