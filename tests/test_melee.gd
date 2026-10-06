extends RefCounted
## Test de mêlée : le coup de pied touche une cible proche dans l'axe, la blesse et la repousse.


func names() -> Array[String]:
	return ["melee"]


func test_melee(t: Node) -> void:
	var brain := ScriptBrain.new()
	var a: Fighter = t.main.spawn_test_fighter(Vector2(600, -10), brain, "rifle", true)
	var b: Fighter = t.main.spawn_test_fighter(Vector2(618, -10), ScriptBrain.new(), "rifle", false)
	await t.until(func() -> bool: return a.is_on_floor() and b.is_on_floor(), 120)
	await t.frames(20)
	brain.aim = b.global_position + Vector2(0, -20)
	await t.frames(2)
	var hp0 := b.hp
	brain.press_melee()
	await t.frames(30)
	t.check(b.hp < hp0, "la cible perd de la vie (%.0f → %.0f)" % [hp0, b.hp])
	t.check(b.global_position.x > 630.0, "la cible est repoussée (x=%.0f)" % b.global_position.x)
	var far: Fighter = t.main.spawn_test_fighter(Vector2(900, -10), ScriptBrain.new(), "rifle", false)
	await t.frames(30)
	brain.press_melee()
	await t.frames(60)
	t.check(far.hp == Fighter.MAX_HP, "une cible lointaine n'est pas touchée")
