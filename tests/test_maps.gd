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
