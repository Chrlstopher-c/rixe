extends Node2D
## Point d'entrée : construit le monde et enchaîne les manches (toi contre des bots, chacun pour soi).

const PLAYER_COLOR := Color(0.3, 0.9, 1.0)

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
var _scoreboard: CanvasLayer
var _inventory: CanvasLayer
var _bot_kinds := {}
var player: Fighter
var _fighters: Node2D
var _hud: CanvasLayer
var _camera: Camera2D
var _restart_in := -1.0
var _rng := RandomNumberGenerator.new()
var _tests := ""
var _off: PackedStringArray = []


func _ready() -> void:
	Controls.register()
	var prefs := Settings.load_all()
	Juice.hd = prefs.hd
	_volume = prefs.volume
	Settings.apply_volume(_volume)
	_parse_args()
	_build()
	Juice.fighter_killed.connect(_on_killed)
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


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--demo":
			demo = true
		elif a == "--pixel":
			Juice.hd = false
		elif a.begins_with("--shot="):
			_shot(a.get_slice("=", 1))
		elif a.begins_with("--tests="):
			_tests = a.get_slice("=", 1)
			Settings.persist = false
		elif a == "--play":
			_skip_title = true
		elif a.begins_with("--off="):
			_off = a.get_slice("=", 1).split(",")
			Juice.off = _off
		elif a.begins_with("--round="):
			round_no = int(a.get_slice("=", 1))
		elif a.begins_with("--perf="):
			var probe := preload("res://core/perf_probe.gd").new()
			probe.duration = float(a.get_slice("=", 1))
			probe.fighters = func() -> int: return _fighters.get_child_count()
			add_child(probe)
		elif a.begins_with("--seed="):
			seed_base = int(a.get_slice("=", 1))


func _shot(path: String) -> void:
	await get_tree().create_timer(6.0, true, false, true).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("shot %s %dx%d" % [path, img.get_width(), img.get_height()])
	get_tree().quit()


func _build() -> void:
	_build_environment()
	if not ("backdrop" in _off):
		_backdrop = preload("res://arena/backdrop.gd").new()
		add_child(_backdrop)
	Juice.world = Node2D.new()
	add_child(Juice.world)
	Juice.arena = _child(Juice.world, preload("res://arena/arena.gd").new())
	Juice.stains = _child(Juice.world, preload("res://fx/stains.gd").new())
	_fighters = _child(Juice.world, Node2D.new())
	Juice.fx = _child(Juice.world, preload("res://fx/fx_layer.gd").new())
	_camera = preload("res://core/game_camera.gd").new()
	_camera.limit_left = -20
	_camera.limit_right = int(Juice.arena.W) + 20
	_camera.limit_top = -440
	_camera.limit_bottom = 44
	add_child(_camera)
	Juice.camera = _camera
	if not ("post" in _off):
		add_child(preload("res://fx/post.gd").new())
	_build_screens()


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CANVAS
	env.environment.glow_enabled = not ("glow" in _off)
	env.environment.glow_intensity = 0.55
	env.environment.glow_strength = 0.9
	env.environment.glow_hdr_threshold = 1.0
	env.environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	add_child(env)


func _build_screens() -> void:
	_menu = preload("res://hud/menu.gd").new()
	add_child(_menu)
	_menu.best = score.best
	_menu.start_requested.connect(_on_start)
	_menu.resume_requested.connect(_resume)
	_menu.title_requested.connect(_to_title)
	_menu.restart_requested.connect(func() -> void: _on_start(game_mode, game_option))
	_menu.quit_requested.connect(func() -> void: get_tree().quit())
	_menu.hd_changed.connect(_set_hd)
	_menu.volume_changed.connect(_on_volume)
	_scoreboard = preload("res://hud/scoreboard.gd").new()
	add_child(_scoreboard)
	_scoreboard.replay_requested.connect(func() -> void: _on_start(game_mode, game_option))
	_scoreboard.menu_requested.connect(_to_title)
	_inventory = preload("res://hud/inventory_screen.gd").new()
	add_child(_inventory)
	_inventory.close_requested.connect(_toggle_inventory)
	_hud = preload("res://hud/hud.gd").new()
	_hud.best = score.best
	_hud.show_crosshair = not demo
	add_child(_hud)


func _child(parent: Node, node: Node) -> Node:
	parent.add_child(node)
	return node


func _start_round() -> void:
	Juice.reset()
	for c in _fighters.get_children():
		c.queue_free()
	for c in Juice.world.get_children():
		if c is Ragdoll or c is WeaponPickup or c is AttachmentPickup or c is Grenade or c is Loot:
			c.queue_free()
	Juice.fx.clear()
	Juice.stains.clear()
	_rng.seed = seed_base * 1000 + round_no
	Juice.arena.generate(_rng.seed)
	apply_theme(Themes.names()[_rng.randi_range(0, Themes.names().size() - 1)])
	var n := mini(2 + round_no, 6) if game_mode == "arcade" or attract else 5
	var spots: Array = Juice.arena.spawn_points(n + 1, _rng)
	var mine := _rng.randi_range(0, n)
	var brain: RefCounted = BotBrain.new(1.0, "acrobate") if demo or attract else PlayerBrain.new()
	player = _spawn_player(spots[mine], brain)
	_bot_kinds.clear()
	var b := 0
	for i in spots.size():
		if i != mine:
			_spawn_bot(spots[i], "")
			b += 1
	_spawn_pickups()
	_camera.target = player
	_camera.snap_to(player.global_position + Vector2(0, -34))
	_hud.player = player
	_hud.round_no = round_no
	_hud.bots_left = b
	for f in _fighters.get_children():
		if f is Fighter and not f.is_queued_for_deletion():
			match_state.register(f)
	_hud.banner("MANCHE %d" % round_no if game_mode == "arcade" or attract else Modes.label(game_mode))
	Sfx.play_ui("round", -6.0)


func reset_for_test() -> void:
	Juice.reset()
	for c in _fighters.get_children():
		c.free()
	for c in Juice.world.get_children():
		if c is Ragdoll or c is WeaponPickup or c is AttachmentPickup or c is Grenade or c is Loot:
			c.free()
	Juice.fx.clear()
	Juice.arena.generate_flat()


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


## Bot d'un archétype (vide = au hasard) ; même nom et même caractère à chaque réapparition.
func _spawn_bot(pos: Vector2, name: String) -> Fighter:
	var kind: String = _bot_kinds.get(name, Personality.ids()[_rng.randi_range(0, Personality.ids().size() - 1)])
	var level := clampf(0.25 + round_no * 0.08, 0.25, 0.8) if game_mode == "arcade" else 0.45
	var brain := BotBrain.new(level, kind)
	if name == "":
		name = _unique_name(brain.p.label)
		_bot_kinds[name] = kind
	var w: String = brain.p.weapon if _rng.randf() < 0.6 else Arsenal.ids()[_rng.randi_range(0, 2)]
	return _spawn(name, pos, Personality.ARCHETYPES[kind].color, brain, w, false)


func _unique_name(label: String) -> String:
	if not _bot_kinds.has(label):
		return label
	var i := 2
	while _bot_kinds.has("%s %d" % [label, i]):
		i += 1
	return "%s %d" % [label, i]


func _spawn_pickups() -> void:
	var plats: Array = Juice.arena.platforms
	for i in 2:
		if plats.is_empty():
			return
		var r: Rect2 = plats[_rng.randi_range(0, plats.size() - 1)]
		var p := WeaponPickup.new()
		Juice.world.add_child(p)
		p.global_position = Vector2(r.get_center().x, r.position.y - 20.0)
		p.setup(Arsenal.ids()[_rng.randi_range(0, Arsenal.ids().size() - 1)], Vector2.ZERO)
	var atts := Arsenal.ATTACHMENTS.keys()
	for i in _rng.randi_range(1, 2):
		if plats.is_empty():
			return
		var r: Rect2 = plats[_rng.randi_range(0, plats.size() - 1)]
		var a := AttachmentPickup.new()
		Juice.world.add_child(a)
		a.global_position = Vector2(r.position.x + 12.0, r.position.y - 20.0)
		a.setup(atts[_rng.randi_range(0, atts.size() - 1)], Vector2.ZERO)


## Le joueur humain part avec l'équipement choisi à l'armurerie ; la démo garde le fusil.
func _spawn_player(pos: Vector2, brain: RefCounted) -> Fighter:
	if brain is PlayerBrain:
		var l := Unlocks.loadout()
		return _spawn("Toi", pos, PLAYER_COLOR, brain, l.weapon, true, l.attachments)
	return _spawn("Toi", pos, PLAYER_COLOR, brain, "rifle", true)


func _spawn(nm: String, pos: Vector2, color: Color, brain: RefCounted, weapon: String, is_player: bool,
		mods: Dictionary = {}) -> Fighter:
	var f := Fighter.new()
	f.setup(nm, color, brain, weapon, is_player, mods)
	f.position = pos
	_fighters.add_child(f)
	return f


func _on_killed(victim: Node2D, killer: Node2D) -> void:
	if _tests != "" and not live_rules:
		return
	var kname: String = killer.display_name if is_instance_valid(killer) else "?"
	_hud.feed("%s  élimine  %s" % [kname, victim.display_name], victim.team_color)
	match_state.record_kill(victim, killer)
	if is_instance_valid(killer) and killer == player:
		score.add_kill()
		_hud.kills = score.kills
	if attract or demo or not Modes.respawns(game_mode):
		_rounds_after_kill(victim)
	elif match_state.over:
		_end_match()


## Mode arcade (et démo) : la manche se gagne quand plus aucun bot n'est en vie.
func _rounds_after_kill(victim: Node2D) -> void:
	if _restart_in >= 0.0:
		return
	if victim == player:
		if attract or demo:
			_hud.banner("ÉLIMINÉ")
			_restart_in = 3.0
		else:
			match_state.finish_arcade()
			_end_match()
		return
	_hud.bots_left = _alive_bots()
	if _hud.bots_left <= 0:
		_hud.banner("MANCHE GAGNÉE")
		round_no += 1
		_restart_in = 3.0


func _alive_bots() -> int:
	var n := 0
	for f in _fighters.get_children():
		if f is Fighter and f.alive and not f.is_player:
			n += 1
	return n


## Fin de partie : classement des combattants, score du joueur soumis au tableau du mode, jeu figé.
func _end_match() -> void:
	var rows := match_state.ranking()
	var key := Modes.board_key(game_mode, game_option)
	var lower := Modes.lower_is_better(game_mode)
	var mine := match_state.kills_of("Toi")
	var value: float = match_state.elapsed if lower else float(mine)
	var counts := not lower or match_state.winner == "Toi"
	var rank := Leaderboard.submit(key, value, lower) if counts and (lower or mine > 0) else -1
	score.end_run(game_mode == "arcade")
	score.reset()
	_hud.best = score.best
	_menu.best = score.best
	var texts := _end_texts(rows)
	_hud.visible = false
	_scoreboard.open(texts[0], texts[1], rows, game_mode, Leaderboard.entries(key), rank)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_ui("round", -4.0)


func _end_texts(rows: Array) -> Array[String]:
	var place := 1
	for i in rows.size():
		if rows[i].name == "Toi":
			place = i + 1
	var mine := match_state.kills_of("Toi")
	match game_mode:
		"chrono":
			return ["TEMPS ÉCOULÉ", "Tu finis %s sur %d · %d éliminations" % [_ordinal(place), rows.size(), mine]]
		"objectif":
			if match_state.winner == "Toi":
				return ["VICTOIRE", "Objectif atteint en %s" % Leaderboard.format_score("objectif", match_state.elapsed)]
			return ["%s GAGNE" % match_state.winner.to_upper(), "Tu finis %s · %d éliminations" % [_ordinal(place), mine]]
	return ["ÉLIMINÉ", "Manche %d atteinte · %d éliminations" % [round_no, mine]]


static func _ordinal(n: int) -> String:
	return "1er" if n == 1 else "%de" % n


func _respawn(entry: Dictionary) -> void:
	var pos := _far_spawn()
	if entry.player:
		var brain: RefCounted = BotBrain.new(1.0, "acrobate") if demo else PlayerBrain.new()
		player = _spawn_player(pos, brain)
		_camera.target = player
		_hud.player = player
	else:
		_spawn_bot(pos, entry.name)
	Juice.fx.emit(5, pos + Vector2(0, -20), Vector2.ZERO, 0.4, 24.0, Color(entry.color * 1.8, 0.8))


## Point d'apparition le plus éloigné des combattants en vie.
func _far_spawn() -> Vector2:
	var best := Vector2(Juice.arena.W * 0.5, -60)
	var best_d := -1.0
	for p: Vector2 in Juice.arena.spawn_points(10, _rng):
		var d := INF
		for f in _fighters.get_children():
			if f is Fighter and f.alive:
				d = minf(d, p.distance_to(f.global_position))
		if d > best_d:
			best_d = d
			best = p
	return best


func _process(delta: float) -> void:
	var real: float = Juice.real_delta(delta)
	if _restart_in >= 0.0:
		_restart_in -= real
		if _restart_in < 0.0:
			_start_round()
	if attract or demo or match_state == null or not Modes.respawns(game_mode) or _scoreboard.visible:
		return
	for entry in match_state.tick(real):
		_respawn(entry)
	_hud.respawn_t = match_state.respawn_in("Toi")
	if match_state.over:
		_end_match()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				_set_hd(not Juice.hd)
			KEY_ESCAPE:
				if not attract and not demo:
					_pause()
			KEY_TAB:
				if not attract and not demo and not _menu.visible and not _scoreboard.visible:
					_toggle_inventory()


func _on_start(mode: String, option: int) -> void:
	game_mode = mode
	game_option = option
	attract = false
	round_no = 1
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


func _to_title() -> void:
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
		get_tree().paused = true
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
