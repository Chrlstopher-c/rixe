extends RefCounted
## Tests de mêlée : coup de pied (touche, blesse, repousse), combos et coup sauté, exécution d'un bot vacillant.


func names() -> Array[String]:
	return ["melee", "combo", "grab", "execution"]


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
	t.check(b.global_position.x > 618.5, "la cible recule (x=%.0f)" % b.global_position.x)
	var far: Fighter = t.main.spawn_test_fighter(Vector2(900, -10), ScriptBrain.new(), "rifle", false)
	await t.frames(30)
	brain.press_melee()
	await t.frames(60)
	t.check(far.hp == Fighter.MAX_HP, "une cible lointaine n'est pas touchée")


func test_combo(t: Node) -> void:
	var brain := ScriptBrain.new()
	var a: Fighter = t.main.spawn_test_fighter(Vector2(600, -10), brain, "rifle", true)
	var b: Fighter = t.main.spawn_test_fighter(Vector2(620, -10), ScriptBrain.new(), "rifle", false)
	await t.until(func() -> bool: return a.is_on_floor() and b.is_on_floor(), 120)
	await t.frames(20)
	brain.aim = b.global_position + Vector2(0, -20)
	var steps := []
	var stunned := false
	for i in 3:
		brain.press_melee()
		await t.until(func() -> bool: return a.melee.active(), 30)
		steps.append(a.melee.step)
		await t.frames(int(Melee.STEPS[i].windup * 120) + 2)
		stunned = stunned or b.moves.stunned()
		await t.until(func() -> bool: return not a.melee.active(), 60)
		await t.frames(4)
		brain.aim = b.global_position + Vector2(0, -20)
	t.check(steps == [0, 1, 2], "trois appuis : direct, crochet, coup de pied (%s)" % str(steps))
	t.check(stunned, "les coups de poing étourdissent la cible")
	t.check(b.hp < Fighter.MAX_HP - 40.0, "le combo complet fait mal (%.0f PV)" % b.hp)
	await t.frames(80)
	brain.press_melee()
	await t.until(func() -> bool: return a.melee.active(), 30)
	t.check(a.melee.step == 0, "après une pause, le combo repart du début")
	await t.frames(60)
	brain.press_jump()
	await t.frames(10)
	brain.press_melee()
	await t.frames(2)
	t.check(a.melee.step == Melee.STEPS.size(), "en l'air : coup de pied sauté")
	a.queue_free()
	if is_instance_valid(b):
		b.queue_free()


func test_grab(t: Node) -> void:
	var brain := ScriptBrain.new()
	var a: Fighter = t.main.spawn_test_fighter(Vector2(600, -10), brain, "rifle", true)
	var b: Fighter = t.main.spawn_test_fighter(Vector2(618, -10), ScriptBrain.new(), "rifle", false)
	await t.until(func() -> bool: return a.is_on_floor() and b.is_on_floor(), 120)
	await t.frames(10)
	brain.aim = b.global_position + Vector2(0, -20)
	await t.frames(2)
	brain.press_grab()
	await t.frames(12)
	t.check(b.held and a.grapple.active(), "projection : l'adversaire est saisi")
	var thrown: bool = await t.until(func() -> bool: return not b.held, 120)


	await t.frames(8)
	t.check(thrown and b.global_position.x < a.global_position.x, "il est jeté derrière (x=%.0f)" % b.global_position.x)
	t.check(b.hp < Fighter.MAX_HP and b.moves.stunned(), "il est blessé et étourdi")
	brain.aim = a.global_position + Vector2(100, -20)
	await t.frames(90)
	brain.press_grab()
	await t.frames(4)
	t.check(not a.grapple.active(), "personne à portée : rien n'est saisi")
	a.queue_free()
	b.queue_free()


func test_execution(t: Node) -> void:
	var brain := ScriptBrain.new()
	var a: Fighter = t.main.spawn_test_fighter(Vector2(600, -10), brain, "rifle", true)
	var b: Fighter = t.main.spawn_test_fighter(Vector2(630, -10), ScriptBrain.new(), "rifle", false)
	await t.until(func() -> bool: return a.is_on_floor() and b.is_on_floor(), 120)
	await t.frames(5)
	t.check(Execution.target_for(a) == null, "un bot en pleine forme ne s'exécute pas")
	b.hp = 20.0
	b._since_hit = 0.0
	await t.frames(2)
	t.check(Execution.target_for(a) == b and b.mark_t > 0.0, "bot vacillant à portée : repéré")
	var seen := []
	var on_exec := func(v: Node2D, k: Node2D) -> void: seen.append([v, k])
	Juice.executed.connect(on_exec)
	var ref: WeakRef = weakref(b)
	brain.press_melee()
	await t.frames(2)
	t.check(seen.size() == 1 and seen[0][1] == a, "l'exécution démarre au lieu du coup de pied")
	t.check(b.held and a.execution.running() and Juice.focus_t > 0.0, "victime tenue, kill cam")
	var arms_legs: int = b.body.arms_left() + b.body.legs_left()
	await t.until(func() -> bool: return ref.get_ref() == null or b.body.arms_left() + b.body.legs_left() < arms_legs, 300)
	t.check(ref.get_ref() != null and b.alive, "premier coup : un membre arraché, toujours en vie")
	var dead: bool = await t.until(func() -> bool: return ref.get_ref() == null or not b.alive, 600)
	t.check(dead, "coup de grâce : la victime meurt")
	await t.frames(3)
	t.check(not a.execution.running(), "le joueur reprend la main")
	Juice.executed.disconnect(on_exec)
	a.queue_free()
