extends RefCounted
## Tests de l'écran partagé : deux joueurs, deux caméras, la partie continue tant qu'un des deux est debout.


func names() -> Array[String]:
	return ["duo"]


func test_duo(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	main._menu.players = 2
	main._on_start("arcade", 0)
	await t.frames(5)
	t.check(main.duo != null and is_instance_valid(Juice.split), "écran partagé actif")
	t.check(Juice.cameras.size() == 2 and not main._camera.enabled, "deux caméras, la vue principale s'efface")
	var p1: Fighter = main.player
	var p2: Fighter = main.duo.player2
	t.check(p2.brain is PadBrain and p1.brain is PlayerBrain and not p1.brain.pad_enabled, "J1 clavier, J2 manette")
	t.check(p1.team == "joueurs" and p2.team == "joueurs", "coopération en arcade")
	p2.shield = 0.0
	p2.take_hit(9999.0, Vector2.RIGHT, p2.global_position + Vector2(0, -22), null, 0.0)
	await t.frames(5)
	t.check(not main._scoreboard.visible, "J2 tombé : la partie continue")
	p1.shield = 0.0
	p1.take_hit(9999.0, Vector2.RIGHT, p1.global_position + Vector2(0, -22), null, 0.0)
	await t.frames(5)
	t.check(main._scoreboard.visible, "les deux tombés : fin de partie")
	main._scoreboard.close()
	main.get_tree().paused = false
	main._to_title()
	await t.frames(2)
	t.check(main.duo == null and Juice.split == null and main._camera.enabled, "retour au titre : vue normale")
	main._menu.players = 1
	main.live_rules = false
	main._menu.close()
