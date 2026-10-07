extends RefCounted
## Tests de combat : zones touchées, démembrement, ralenti réservé aux morts par la tête.


func names() -> Array[String]:
	return ["hitzones", "dismember", "headshot_slowmo", "legshot"]


func _target(t: Node, is_player: bool = false) -> Fighter:
	var f: Fighter = t.main.spawn_test_fighter(Vector2(600, -10), ScriptBrain.new(), "rifle", is_player)
	await t.until(func() -> bool: return f.is_on_floor(), 120)
	await t.frames(30)
	return f


func _shoot_at(f: Fighter, joint: String, dmg: float, from: Node2D = null) -> void:
	var at := f.rig.to_global(f.rig.j[joint])
	f.take_hit(dmg, Vector2.RIGHT, at + Vector2(-0.5, 0), from, 0.0)


func test_hitzones(t: Node) -> void:
	var f := await _target(t)
	for case in [["head", "head"], ["hip", "torso"], ["foot1", "leg1"], ["knee0", "leg0"]]:
		f.hp = 999.0
		f.body = BodyParts.new()
		_shoot_at(f, case[0], 1.0)
		t.check(f.last_zone == case[1] or (case[1].begins_with("leg") and f.last_zone.begins_with("leg")),
			"tir sur %s → zone %s (obtenu %s)" % [case[0], case[1], f.last_zone])


func test_dismember(t: Node) -> void:
	var f := await _target(t)
	f.hp = 999.0
	for i in 8:
		_shoot_at(f, "foot0", 9.0)
	t.check(f.alive, "survit à la perte d'une jambe")
	t.check(f.body.legs_left() < 2, "une jambe arrachée après 8 balles")
	t.check(f.leg_factor() < 1.0, "plus lent sans sa jambe")
	t.check(_gibs(t) >= 1, "le membre vole en morceau physique")
	for i in 3:
		_shoot_at(f, "head", 9.0)
	t.check(not f.alive, "tête détruite = mort immédiate malgré une grosse réserve de vie")
	t.check(f.death_cause == "decap", "cause de mort : décapitation (obtenu %s)" % f.death_cause)


func _gibs(t: Node) -> int:
	var n := 0
	for c in Juice.world.get_children():
		if c is Ragdoll and c.is_gib:
			n += 1
	return n


func test_headshot_slowmo(t: Node) -> void:
	var shooter: Fighter = t.main.spawn_test_fighter(Vector2(300, -10), ScriptBrain.new(), "rifle", true)
	var a := await _target(t)
	a.hp = 5.0
	_shoot_at(a, "hip", 9.0, shooter)
	await t.frames(2)
	t.check(Juice._slowmo <= 0.0, "pas de ralenti sur une mort au torse")
	Juice.reset()
	var b := await _target(t)
	b.hp = 5.0
	_shoot_at(b, "head", 9.0, shooter)
	t.check(Juice._slowmo > 0.0, "ralenti sur une mort par la tête")


func test_legshot(t: Node) -> void:
	var brain := ScriptBrain.new()
	var me: Fighter = t.main.spawn_test_fighter(Vector2(440, -10), brain, "rifle", true)
	var foe := await _target(t)
	foe.hp = 999.0
	var legs0: float = foe.body.hp.leg0 + foe.body.hp.leg1
	for i in 90:
		brain.aim = foe.global_position + Vector2(0, -1)
		brain.fire = true
		await t.frames(1)
	brain.fire = false
	var legs1: float = foe.body.hp.leg0 + foe.body.hp.leg1
	t.check(legs1 < legs0 - 10.0, "viser les pieds blesse les jambes (%.0f → %.0f)" % [legs0, legs1])
