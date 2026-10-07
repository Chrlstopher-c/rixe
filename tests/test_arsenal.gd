extends RefCounted
## Tests des nouvelles armes : chaque arme tire sans erreur, la lame tranche au contact, les grenades explosent.


func names() -> Array[String]:
	return ["arsenal", "grenade"]


func test_arsenal(t: Node) -> void:
	for id in Arsenal.ids():
		var brain := ScriptBrain.new()
		var f: Fighter = t.main.spawn_test_fighter(Vector2(300, -10), brain, id)
		var target: Fighter = t.main.spawn_test_fighter(Vector2(320 if id == "katana" else 520, -10), ScriptBrain.new(),
			"rifle", false)
		target.hp = 9999.0
		var ref: WeakRef = weakref(target)
		await t.until(func() -> bool: return f.is_on_floor() and target.is_on_floor(), 120)
		brain.aim = target.global_position + Vector2(0, -60 if id == "launcher" else -22)
		brain.fire = true
		await t.frames(150)
		brain.fire = false
		var hurt: bool = ref.get_ref() == null or target.hp < 9999.0
		t.check(hurt, "%s blesse la cible" % id)
		if weakref(f).get_ref():
			f.queue_free()
		if ref.get_ref():
			target.queue_free()
		await t.frames(2)
		for g in t.main.get_tree().get_nodes_in_group("grenades"):
			g.queue_free()


func test_grenade(t: Node) -> void:
	var brain := ScriptBrain.new()
	var me: Fighter = t.main.spawn_test_fighter(Vector2(300, -10), brain)
	var foe: Fighter = t.main.spawn_test_fighter(Vector2(600, -10), ScriptBrain.new(), "rifle", false)
	await t.until(func() -> bool: return me.is_on_floor() and foe.is_on_floor(), 120)
	brain.aim = Vector2(400, -60)
	brain.press_throw()
	await t.frames(3)
	t.check(me.grenades == Arsenal.GRENADES - 1, "une grenade lancée")
	t.check(t.main.get_tree().get_nodes_in_group("grenades").size() == 1, "la grenade vole")
	var foe_ref: WeakRef = weakref(foe)
	var g := Grenade.new()
	Juice.world.add_child(g)
	g.global_position = foe.global_position + Vector2(-6, -4)
	g.setup(me, Vector2.ZERO, 0.1, false, 80.0, 52.0)
	await t.frames(30)
	t.check(foe_ref.get_ref() == null or foe.hp < Fighter.MAX_HP, "l'explosion blesse la cible")
	t.check(not Juice.arena.solid_at(Vector2(594, 2)), "l'explosion creuse le sol")
	await t.frames(int(Arsenal.GRENADE.fuse * 120))
	t.check(t.main.get_tree().get_nodes_in_group("grenades").is_empty(), "les grenades ont explosé")
