extends RefCounted
## Test des ambiances : chaque thème charge ses textures d'arène et de fond, et les manches les font varier.


func names() -> Array[String]:
	return ["themes"]


func test_themes(t: Node) -> void:
	for n in Themes.names():
		t.main.apply_theme(n)
		await t.frames(1)
		for k in ["ground", "metal", "bricks"]:
			t.check(Juice.arena._tex[k] != null, "%s : tuile %s chargée" % [n, k])
		t.check(t.main._backdrop._sky.texture != null, "%s : ciel chargé" % n)
		t.check(Juice.arena.rim == Themes.ALL[n].rim, "%s : liseré appliqué" % n)
	var seen := {}
	for r in 12:
		t.main.round_no = r + 1
		t.main._start_round()
		seen[Juice.arena.theme] = true
		await t.frames(1)
	t.check(seen.size() >= 2, "les manches changent d'ambiance (%d vues sur 12 manches)" % seen.size())
