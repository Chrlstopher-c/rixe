extends RefCounted
## Tests des cartes : chaque type se génère avec des points d'apparition valides ; chute mortelle sur les toits.


func names() -> Array[String]:
	return ["maps"]


func test_maps(t: Node) -> void:
	var arena: Node2D = Juice.arena
	var rng := RandomNumberGenerator.new()
	for map in Maps.ALL:
		for seed in [3, 17]:
			arena.generate(seed, map)
			rng.seed = seed
			var spots: Array[Vector2] = arena.spawn_points(7, rng)
			t.check(spots.size() == 7, "%s/%d : 7 points d'apparition (obtenu %d)" % [map, seed, spots.size()])
			for s in spots:
				var ok: bool = not arena.solid_at(s) and arena.solid_at(s + Vector2(0, 10))
				if not ok:
					t.check(false, "%s/%d : point %s posé sur un sol libre" % [map, seed, str(s)])
					break
	arena.generate(5, "mine")
	var hollow := 0
	for x in range(40, 1560, 40):
		if not arena.solid_at(Vector2(x, -60)):
			hollow += 1
	t.check(hollow > 10, "mine : galeries creusées dans la roche (%d)" % hollow)
	await _minecart(t, arena)
	arena.generate(5, "toits")
	t.check(arena.void_y < INF, "toits : vide mortel")
	var gap_x := -1.0
	var start := -1.0
	for x in range(100, 1500, 4):
		var empty: bool = arena.stand_spots(x).is_empty()
		if empty and start < 0.0:
			start = x
		elif not empty and start > 0.0:
			gap_x = (start + x) * 0.5
			break
	t.check(gap_x > 0.0, "toits : un vide entre deux immeubles")
	var f: Fighter = t.main.spawn_test_fighter(Vector2(gap_x, -150), ScriptBrain.new())
	var ref: WeakRef = weakref(f)
	var died: bool = await t.until(func() -> bool: return ref.get_ref() == null or not f.alive, 600)
	t.check(died, "chute dans le vide = mort")
	arena.generate_flat()


func _minecart(t: Node, arena: Node2D) -> void:
	var carts := arena.get_children().filter(func(n: Node) -> bool: return n is Minecart)
	t.check(carts.size() == 1, "mine : un wagonnet sur sa voie")
	if carts.is_empty():
		return
	var cart: Minecart = carts[0]
	var x0 := cart.position.x
	cart.dir = 1.0 if cart.to_x - x0 > x0 - cart.from_x else -1.0
	cart._wait = 0.0
	var f: Fighter = t.main.spawn_test_fighter(Vector2(x0 + cart.dir * 60.0, cart.rail_y - 4.0), ScriptBrain.new())
	var ref: WeakRef = weakref(f)
	var hit: bool = await t.until(func() -> bool: return ref.get_ref() == null or f.hp < Fighter.MAX_HP, 240)
	t.check(absf(cart.position.x - x0) > 20.0, "le wagonnet roule (%.0f px)" % absf(cart.position.x - x0))
	t.check(hit, "le wagonnet percute le combattant sur la voie")
	if OS.has_environment("RIXE_SHOT"):
		t.main._camera.target = null
		t.main._camera.snap_to(cart.global_position + Vector2(0, -30))
		await t.frames(20)
		t.main.get_viewport().get_texture().get_image().save_png(OS.get_environment("RIXE_SHOT"))
	if ref.get_ref():
		f.queue_free()
