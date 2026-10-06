extends Node2D
## Point d'entrée : construit le monde et enchaîne les manches (toi contre des bots, chacun pour soi).

const PLAYER_COLOR := Color(0.3, 0.9, 1.0)
const BOT_COLORS := [Color(1.0, 0.25, 0.3), Color(1.0, 0.6, 0.15), Color(0.95, 0.3, 0.95), Color(0.65, 1.0, 0.3)]

var round_no := 1
var seed_base := 1
var demo := false
var player: Fighter
var _fighters: Node2D
var _hud: CanvasLayer
var _camera: Camera2D
var _restart_in := -1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Controls.register()
	_parse_args()
	_build()
	Juice.fighter_killed.connect(_on_killed)
	_set_hd(Juice.hd)
	_start_round()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--demo":
			demo = true
		elif a == "--hd":
			Juice.hd = true
		elif a.begins_with("--seed="):
			seed_base = int(a.get_slice("=", 1))


func _build() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CANVAS
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.55
	env.environment.glow_strength = 0.9
	env.environment.glow_hdr_threshold = 1.0
	env.environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	add_child(env)
	add_child(preload("res://arena/backdrop.gd").new())
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
	add_child(preload("res://fx/post.gd").new())
	_hud = preload("res://hud/hud.gd").new()
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
		if c is Ragdoll:
			c.queue_free()
	Juice.fx.clear()
	Juice.stains.clear()
	_rng.seed = seed_base * 1000 + round_no
	Juice.arena.generate(_rng.seed)
	var n := mini(2 + round_no, 6)
	var spots: Array = Juice.arena.spawn_points(n + 1, _rng)
	var mine := _rng.randi_range(0, n)
	var brain: RefCounted = BotBrain.new(1.0) if demo else PlayerBrain.new()
	player = _spawn("Toi", spots[mine], PLAYER_COLOR, brain, "rifle", true)
	var b := 0
	for i in spots.size():
		if i != mine:
			var w: String = Arsenal.ids()[_rng.randi_range(0, 2)]
			_spawn("Bot %d" % (b + 1), spots[i], BOT_COLORS[b % 4], BotBrain.new(_rng.randf_range(0.4, 0.75)), w, false)
			b += 1
	_camera.target = player
	_camera.snap_to(player.global_position + Vector2(0, -34))
	_hud.player = player
	_hud.round_no = round_no
	_hud.bots_left = b
	_hud.banner("MANCHE %d" % round_no)


func _spawn(nm: String, pos: Vector2, color: Color, brain: RefCounted, weapon: String, is_player: bool) -> Fighter:
	var f := Fighter.new()
	f.setup(nm, color, brain, weapon, is_player)
	f.position = pos
	_fighters.add_child(f)
	return f


func _on_killed(victim: Node2D, killer: Node2D) -> void:
	var kname: String = killer.display_name if is_instance_valid(killer) else "?"
	_hud.feed("%s  élimine  %s" % [kname, victim.display_name], victim.team_color)
	if is_instance_valid(killer) and killer == player:
		_hud.kills += 1
	if _restart_in >= 0.0:
		return
	if victim == player:
		_hud.banner("ÉLIMINÉ")
		_restart_in = 3.0
		return
	_hud.bots_left = _alive_bots() - 1
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


func _process(delta: float) -> void:
	if _restart_in >= 0.0:
		_restart_in -= Juice.real_delta(delta)
		if _restart_in < 0.0:
			_start_round()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				_set_hd(not Juice.hd)
			KEY_R:
				_start_round()
			KEY_ESCAPE:
				get_tree().quit()


func _set_hd(on: bool) -> void:
	Juice.hd = on
	var w := get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if on else Window.CONTENT_SCALE_MODE_VIEWPORT
	get_viewport().msaa_2d = Viewport.MSAA_4X if on else Viewport.MSAA_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if not demo else Input.MOUSE_MODE_VISIBLE
