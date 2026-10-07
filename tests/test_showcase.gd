extends RefCounted
## Démonstration scriptée (à filmer, hors « all ») : membres arrachés, coup de pied, décapitation au ralenti.


func names() -> Array[String]:
	return ["showcase"]


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
