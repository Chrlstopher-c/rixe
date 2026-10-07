class_name Bootstrap
## Démarrage : lecture des options de lancement et construction de la scène (monde, caméra, écrans).


static func parse_args(m: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--demo":
			m.demo = true
		elif a == "--pixel":
			Juice.hd = false
		elif a.begins_with("--shot="):
			m._shot(a.get_slice("=", 1))
		elif a.begins_with("--tests="):
			m._tests = a.get_slice("=", 1)
			Settings.persist = false
		elif a == "--play":
			m._skip_title = true
		elif a.begins_with("--off="):
			m._off = a.get_slice("=", 1).split(",")
			Juice.off = m._off
		elif a.begins_with("--map="):
			m.forced_map = a.get_slice("=", 1)
		elif a.begins_with("--round="):
			m.round_no = int(a.get_slice("=", 1))
		elif a.begins_with("--perf="):
			var probe := preload("res://core/perf_probe.gd").new()
			probe.duration = float(a.get_slice("=", 1))
			probe.fighters = func() -> int: return m._fighters.get_child_count()
			m.add_child(probe)
		elif a.begins_with("--seed="):
			m.seed_base = int(a.get_slice("=", 1))


static func build(m: Node) -> void:
	_environment(m)
	if not ("backdrop" in m._off):
		m._backdrop = preload("res://arena/backdrop.gd").new()
		m.add_child(m._backdrop)
	Juice.world = Node2D.new()
	m.add_child(Juice.world)
	Juice.arena = m._child(Juice.world, preload("res://arena/arena.gd").new())
	Juice.stains = m._child(Juice.world, preload("res://fx/stains.gd").new())
	m._fighters = m._child(Juice.world, Node2D.new())
	m.spawner = Spawner.new(m._fighters, m._rng)
	Juice.fx = m._child(Juice.world, preload("res://fx/fx_layer.gd").new())
	Juice.weather = m._child(Juice.world, preload("res://fx/weather.gd").new())
	m._camera = preload("res://core/game_camera.gd").new()
	m._camera.limit_left = -20
	m._camera.limit_right = int(Juice.arena.W) + 20
	m._camera.limit_top = -440
	m._camera.limit_bottom = 44
	m.add_child(m._camera)
	Juice.camera = m._camera
	if not ("post" in m._off):
		m._post = preload("res://fx/post.gd").new()
		m.add_child(m._post)
	_screens(m)


static func _environment(m: Node) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CANVAS
	env.environment.glow_enabled = not ("glow" in m._off)
	env.environment.glow_intensity = 0.55
	env.environment.glow_strength = 0.9
	env.environment.glow_hdr_threshold = 1.0
	env.environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	m.add_child(env)


static func _screens(m: Node) -> void:
	m._menu = preload("res://hud/menu.gd").new()
	m.add_child(m._menu)
	m._menu.best = m.score.best
	m._menu.start_requested.connect(m._on_start)
	m._menu.resume_requested.connect(m._resume)
	m._menu.title_requested.connect(m._to_title)
	m._menu.restart_requested.connect(func() -> void: m._on_start(m.game_mode, m.game_option))
	m._menu.quit_requested.connect(func() -> void: m.get_tree().quit())
	m._menu.hd_changed.connect(m._set_hd)
	m._menu.volume_changed.connect(m._on_volume)
	m._scoreboard = preload("res://hud/scoreboard.gd").new()
	m.add_child(m._scoreboard)
	m._scoreboard.replay_requested.connect(func() -> void: m._on_start(m.game_mode, m.game_option))
	m._scoreboard.menu_requested.connect(m._to_title)
	m._inventory = preload("res://hud/inventory_screen.gd").new()
	m.add_child(m._inventory)
	m._inventory.close_requested.connect(m._toggle_inventory)
	m._hud = preload("res://hud/hud.gd").new()
	m._hud.best = m.score.best
	m._hud.show_crosshair = not m.demo
	m.add_child(m._hud)
