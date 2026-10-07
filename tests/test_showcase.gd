extends RefCounted
## Démonstration scriptée (à filmer, hors « all ») : membres arrachés, coup de pied, décapitation au ralenti.


func names() -> Array[String]:
	return ["showcase", "showcase_end", "showcase_armory", "showcase_inventory", "showcase_survival", "showcase_duo",
		"showcase_killcam", "showcase_execution",
		"showcase_crosshair", "showcase_custom"]


func _fire_at(t: Node, brain: ScriptBrain, target: Variant, joint: String, frames: int) -> void:
	for i in frames:
		if not is_instance_valid(target) or not target.alive:
			break
		brain.aim = target.rig.to_global(target.rig.j[joint])
		brain.fire = true
		await t.frames(1)
	brain.fire = false


func test_showcase(t: Node) -> void:
	var brain := ScriptBrain.new()
	var me: Fighter = t.main.spawn_test_fighter(Vector2(480, -10), brain, "rifle", true)
	var foe_brain := ScriptBrain.new()
	foe_brain.aim = Vector2(300, -40)
	var foe: Fighter = t.main.spawn_test_fighter(Vector2(600, -10), foe_brain, "rifle", false)
	foe.team_color = Color(1.0, 0.25, 0.3)
	foe.hp = 2000.0
	foe.body.hp["torso"] = 500.0
	foe.body.hp["head"] = 999.0
	t.main.follow(me)
	await t.frames(90)
	await _fire_at(t, brain, foe, "knee0", 240)
	await t.frames(60)
	await _fire_at(t, brain, foe, "elbow1", 240)
	await t.frames(60)
	brain.move = 1.0
	var close := func() -> bool:
		return not is_instance_valid(foe) or me.global_position.distance_to(foe.global_position) < 22.0
	await t.until(close, 240)
	brain.move = 0.0
	if is_instance_valid(foe):
		brain.aim = foe.rig.to_global(foe.rig.j.shoulder)
	brain.press_melee()
	await t.frames(80)
	brain.move = -1.0
	await t.frames(40)
	brain.move = 0.0
	if is_instance_valid(foe):
		foe.body.hp["head"] = 40.0
	await _fire_at(t, brain, foe, "head", 300)
	await t.frames(240)
	t.check(not is_instance_valid(foe) or not foe.alive, "la cible meurt")


func test_showcase_end(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	main._on_start("chrono", 0)
	main.player.brain = BotBrain.new(1.0)
	main.match_state.time_left = 6.0
	await t.until(func() -> bool: return main._scoreboard.visible, 1200)
	await t.frames(240)
	t.check(main._scoreboard.visible, "écran de fin affiché")


func test_showcase_armory(t: Node) -> void:
	var main: Node = t.main
	for w in ["smg", "sniper", "katana"]:
		Unlocks.unlock("weapon", w)
	for a in ["scope", "extmag", "stock"]:
		Unlocks.unlock("attachment", a)
	Unlocks.save_loadout({"weapon": "sniper", "attachments": {"optic": "scope", "stock": "stock"}})
	main.attract = true
	main._start_round()
	main._menu.show_title()
	main._menu.activate(main._menu._ids().find("armory"))
	await t.frames(400)
	t.check(main._menu.mode == "armory", "armurerie ouverte")


func test_showcase_inventory(t: Node) -> void:
	var main: Node = t.main
	main.attract = false
	main.game_mode = "chrono"
	main._start_round()
	await t.frames(30)
	var f: Fighter = main.player
	f.inventory.take(Gun.new(f, "sniper", {"optic": "scope"}))
	f.inventory.bag.append_array(["extmag", "stock", "reddot"])
	f.inventory.medkits = 2
	main._toggle_inventory()
	await t.frames(300)
	t.check(main._inventory.visible, "inventaire ouvert")


func test_showcase_survival(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	main._on_start("survie", 0)
	await t.frames(10)
	var s: Survival = Juice.survival
	var p: Fighter = main.player
	p.brain = BotBrain.new(1.0, "renard")
	s.res = {"bois": 14, "pierre": 6, "metal": 3, "nourriture": 4}
	var b: Builder = main.director.builder
	b.toggle()
	for i in 4:
		var c := Terrain.cell_of(p.global_position + Vector2(36, -8 - i * 8))
		b.place(c)
	await t.frames(120)
	s.t = Survival.DAY - 3.0
	await t.frames(2400)
	t.check(true, "vitrine")


func test_showcase_duo(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	main._menu.players = 2
	main._on_start("arcade", 0)
	await t.frames(5)
	main.player.brain = BotBrain.new(1.0, "renard")
	main.duo.player2.brain = BotBrain.new(1.0, "brute")
	await t.frames(1500)
	t.check(true, "vitrine")


func test_showcase_killcam(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	main.attract = false
	main.match_state = MatchState.new("arcade")
	var brain := ScriptBrain.new()
	main.player = main.spawn_test_fighter(Vector2(380, -10), brain, "rifle", true)
	main.follow(main.player)
	var foe: Fighter = main.spawn_test_fighter(Vector2(620, -10), ScriptBrain.new(), "rifle", false)
	foe.team_color = Color(1.0, 0.25, 0.3)
	await t.frames(90)
	await _fire_at(t, brain, foe, "hip", 120)
	if is_instance_valid(foe) and foe.alive:
		foe.take_hit(999.0, Vector2.RIGHT, foe.rig.to_global(foe.rig.j.hip), main.player, 60.0)
	await t.frames(360)
	t.check(main.round_no == 2, "manche gagnée")
	main.live_rules = false


func test_showcase_execution(t: Node) -> void:
	var main: Node = t.main
	var brain := ScriptBrain.new()
	var me: Fighter = main.spawn_test_fighter(Vector2(500, -10), brain, "rifle", true)
	main.follow(me)
	for i in 3:
		var foe: Fighter = main.spawn_test_fighter(me.global_position + Vector2(90, -10), ScriptBrain.new(), "rifle", false)
		foe.team_color = [Color(1.0, 0.25, 0.3), Color(1.0, 0.7, 0.2), Color(0.7, 0.4, 1.0)][i]
		foe.execution.finisher = ""
		await t.frames(60)
		foe.hp = 20.0
		foe._since_hit = 0.0
		brain.move = 1.0
		await t.until(func() -> bool: return Execution.target_for(me) != null, 240)
		brain.move = 0.0
		await t.frames(50)
		brain.press_melee()
		await t.frames(420)
	t.check(true, "vitrine")


func test_showcase_crosshair(t: Node) -> void:
	var main: Node = t.main
	main.attract = true
	main._menu.show_title()
	await t.frames(30)
	main._menu.activate(main._menu._ids().find("crosshair"))
	var sight: CanvasLayer = null
	for c in main.get_children():
		if c is CanvasLayer and c.has_method("adjust") and c.visible:
			sight = c
	for i in 6:
		await t.frames(70)
		sight.adjust("preset", 1)
	for id in ["length", "length", "gap", "color", "thick", "shape"]:
		await t.frames(50)
		sight.adjust(id, 1)
	await t.frames(80)
	t.check(true, "vitrine")


func test_showcase_custom(t: Node) -> void:
	var main: Node = t.main
	main.attract = true
	main._menu.show_title()
	await t.frames(40)
	main._menu.activate(main._menu._ids().find("custom"))
	var c: CanvasLayer = main._custom
	for id in ["mode", "teams", "my_team", "bots", "bots", "level", "arms", "map"]:
		await t.frames(45)
		c.adjust(id, 1)
	await t.frames(60)
	c.activate(c._ids().size() - 1)
	await t.frames(20)
	var s := NetSession.begin(main, "host", "SHOW", 4)
	c.open_online(s, "KZRP")
	await t.frames(240)
	s.leave()
	t.check(true, "vitrine")
