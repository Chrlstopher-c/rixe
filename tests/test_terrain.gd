extends RefCounted
## Tests du décor destructible : cratère dans le sol, plateforme percée, roche indestructible, montée de marche.


func names() -> Array[String]:
	return ["terrain", "ricochet", "collapse"]


func test_terrain(t: Node) -> void:
	var arena: Node2D = Juice.arena
	t.check(arena.solid_at(Vector2(800, 4)), "le sol est plein au départ")
	var ref: Fighter = t.main.spawn_test_fighter(Vector2(300, -30), ScriptBrain.new())
	await t.until(func() -> bool: return ref.is_on_floor(), 240)
	t.check(absf(ref.global_position.y) < 1.0, "debout sur le sol intact (y=%.1f)" % ref.global_position.y)
	for i in 30:
		arena.damage(Vector2(800, 4 + i), 40.0, 12.0)
	await t.frames(3)
	t.check(not arena.solid_at(Vector2(800, 4)), "les tirs creusent un cratère")
	t.check(arena.solid_at(Vector2(800, 60)), "la roche sous le sol reste indestructible")
	var f: Fighter = t.main.spawn_test_fighter(Vector2(800, -30), ScriptBrain.new())
	var fell: bool = await t.until(func() -> bool: return f.is_on_floor() and f.global_position.y > 8.0, 240)
	t.check(fell, "un combattant tombe dans le cratère (y=%.0f)" % f.global_position.y)
	arena.terrain.fill(Rect2(400, -74, 96, 8), Terrain.K.PLAT)
	var g: Fighter = t.main.spawn_test_fighter(Vector2(448, -110), ScriptBrain.new())
	await t.until(func() -> bool: return g.is_on_floor(), 240)
	t.check(g.global_position.y < -70.0, "debout sur la plateforme")
	arena.damage(Vector2(448, -70), 200.0, 20.0)
	var dropped: bool = await t.until(func() -> bool: return g.global_position.y > -10.0, 240)
	t.check(dropped, "plateforme détruite sous ses pieds : il tombe")
	await _step(t, arena)


func _step(t: Node, arena: Node2D) -> void:
	arena.terrain.fill(Rect2(1200, -8, 8, 8), Terrain.K.CRATE)
	var brain := ScriptBrain.new()
	var f: Fighter = t.main.spawn_test_fighter(Vector2(1170, -10), brain)
	await t.until(func() -> bool: return f.is_on_floor(), 120)
	brain.move = 1.0
	var passed: bool = await t.until(func() -> bool: return f.global_position.x > 1215.0, 240)
	t.check(passed, "monte une marche de 8 px sans sauter (x=%.0f)" % f.global_position.x)


func test_ricochet(t: Node) -> void:
	var shooter: Fighter = t.main.spawn_test_fighter(Vector2(200, -10), ScriptBrain.new())
	var target: Fighter = t.main.spawn_test_fighter(Vector2(520, -10), ScriptBrain.new(), "rifle", false)
	await t.until(func() -> bool: return target.is_on_floor(), 120)
	var gun := Gun.new(shooter, "rifle")
	gun.def = gun.def.duplicate()
	gun.def.ricochet = 100.0
	gun.def.ricochet_spread = 0.0
	var from := Vector2(300, -20)
	var dir := (Vector2(400, 0) - from).normalized()
	var before: int = Juice.fx.tracers.size()
	gun._trace(from, dir, 600.0, 9.0, 2, [shooter.get_rid()])
	t.check(Juice.fx.tracers.size() >= before + 2, "la balle rasante ricoche (2 segments de traçante)")
	t.check(target.hp < Fighter.MAX_HP, "le ricochet touche le combattant dans l'axe de rebond")
	var straight := Gun.new(shooter, "rifle")
	straight.def = straight.def.duplicate()
	straight.def.ricochet = 0.0
	before = Juice.fx.tracers.size()
	straight._trace(Vector2(700, -40), Vector2.DOWN, 600.0, 9.0, 2, [shooter.get_rid()])
	t.check(Juice.fx.tracers.size() == before + 1, "sans ricochet : un seul segment")


func test_collapse(t: Node) -> void:
	var arena: Node2D = Juice.arena
	var r := Rect2(400, -74, 96, 8)
	arena.terrain.fill(r, Terrain.K.PLAT)
	Maps._struts(arena, r)
	arena.terrain.flush()
	var under: Fighter = t.main.spawn_test_fighter(Vector2(424, -10), ScriptBrain.new(), "rifle", false)
	await t.until(func() -> bool: return under.is_on_floor(), 120)
	arena.damage(Vector2(452, -70), 200.0, 3.0)
	await t.frames(5)
	var none: bool = t.main.get_tree().get_nodes_in_group("falling").is_empty()
	t.check(none, "coupée au milieu, chaque moitié tient sur son montant")
	arena.damage(Vector2(406, -70), 200.0, 3.0)
	await t.frames(2)
	t.check(not t.main.get_tree().get_nodes_in_group("falling").is_empty(), "montant détruit : la moitié gauche tombe")
	var ref: WeakRef = weakref(under)
	await t.frames(120)
	t.check(ref.get_ref() == null or under.hp < Fighter.MAX_HP, "le morceau écrase le combattant dessous")
	t.check(arena.solid_at(Vector2(430, -4)) or arena.solid_at(Vector2(430, -12)), "le morceau se repose au sol")
