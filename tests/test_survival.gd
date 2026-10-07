extends RefCounted
## Tests de la survie : monde, récolte, construction, nuit et pillards, faim, fabrication, fin de partie.


func names() -> Array[String]:
	return ["survival"]


func _cleanup(main: Node) -> void:
	main.live_rules = false
	main._scoreboard.close()
	main.get_tree().paused = false
	main._leave_survival()
	main.game_mode = "arcade"


func test_survival(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	main._on_start("survie", 0)
	await t.frames(5)
	var s: Survival = Juice.survival
	var p: Fighter = main.player
	t.check(Juice.arena.W == Maps.SURVIVAL_W and s != null, "grande carte de survie (%.0f px)" % Juice.arena.W)
	t.check(t.main.get_tree().get_nodes_in_group("trees").size() > 10, "des arbres partout")
	t.check(p.inventory.guns.size() == 2 and p.inventory.other().id == "pickaxe", "une pioche en seconde arme")
	await _harvest(t, p, s)
	await _build(t, main, p, s)
	await _night(t, s)
	await _hunger_and_craft(t, p, s)
	p.shield = 0.0
	p.take_hit(9999.0, Vector2.RIGHT, p.global_position + Vector2(0, -22), null, 0.0)
	await t.until(func() -> bool: return main._scoreboard.visible, 900)
	t.check(main._scoreboard.visible and main._scoreboard._title == "TU ES TOMBÉ", "mort du joueur = fin de la survie")
	_cleanup(main)


func _harvest(t: Node, p: Fighter, s: Survival) -> void:
	var tree: Node2D = t.main.get_tree().get_nodes_in_group("trees")[0]
	var before := int(s.res.bois)
	for i in 6:
		Juice.arena.damage(tree.global_position + Vector2(0, 12 + i * 8), 200.0, 3.0, p)
	await t.frames(2)
	t.check(int(s.res.bois) > before, "couper un arbre donne du bois (%d → %d)" % [before, s.res.bois])


func _build(t: Node, main: Node, p: Fighter, s: Survival) -> void:
	var b: Builder = main.director.builder
	s.res.bois = 10
	b.select(0)
	var c := Terrain.cell_of(p.global_position + Vector2(40, -60))
	while Juice.arena.solid_at(Terrain.cell_rect(c).get_center()):
		c += Vector2i.UP
	t.check(b.place(c), "mur de bois posé")
	t.check(Juice.arena.terrain.built.has(c) and s.res.bois == 8, "le mur coûte 2 bois")
	t.check(b.remove(c) and s.res.bois == 9, "démonté : 1 bois rendu")
	await t.frames(1)


func _night(t: Node, s: Survival) -> void:
	s.t = Survival.DAY
	await t.frames(3)
	var raiders: Array = t.main.get_tree().get_nodes_in_group("fighters").filter(func(f: Node) -> bool:
		return f.team == "pillards")
	t.check(s.night and raiders.size() >= 4, "la nuit amène des pillards (%d)" % raiders.size())
	t.check(raiders.all(func(f: Node) -> bool: return f.brain.raid), "les pillards forcent les constructions")


func _hunger_and_craft(t: Node, p: Fighter, s: Survival) -> void:
	p.hp = 80.0
	s.hunger = 0.0
	await t.frames(120)
	t.check(p.hp < 80.0, "affamé : la vie baisse")
	s.res.nourriture = 1
	t.check(s.eat() and s.hunger >= 29.0, "manger rend de la satiété")
	s.res.metal = 1
	var g: Gun = p.inventory.guns[0]
	var r0 := g.reserve
	p.inventory.select(0)
	t.check(Recipes.craft("munitions", s, p) and g.reserve > r0, "fabriquer des munitions avec du métal")
