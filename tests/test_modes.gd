extends RefCounted
## Tests des modes : fin de manche arcade au dernier bot, chrono (réapparitions, fin au temps), objectif, classement.


func names() -> Array[String]:
	return ["arcade_last_bot", "chrono", "objectif", "leaderboard", "boss"]


func _kill(victim: Fighter, killer: Fighter) -> void:
	victim.shield = 0.0
	victim.take_hit(999.0, Vector2.RIGHT, victim.global_position + Vector2(0, -24), killer, 0.0)


func _bots(main: Node) -> Array[Fighter]:
	var out: Array[Fighter] = []
	for f in main._fighters.get_children():
		if f is Fighter and f.alive and not f.is_player and not f.is_queued_for_deletion():
			out.append(f)
	return out


func _cleanup(main: Node) -> void:
	main.live_rules = false
	main._scoreboard.close()
	main.get_tree().paused = false
	main._restart_in = -1.0
	main._end_in = -1.0
	main.forced_map = ""
	Juice.reset()
	main.round_no = 1
	main.game_mode = "arcade"


func test_arcade_last_bot(t: Node) -> void:
	var main: Node = t.main
	_cleanup(main)
	main.live_rules = true
	main.attract = false
	main.match_state = MatchState.new("arcade")
	main.player = main.spawn_test_fighter(Vector2(300, -10), ScriptBrain.new(), "rifle", true)
	var bots: Array[Fighter] = []
	for i in 3:
		bots.append(main.spawn_test_fighter(Vector2(600 + i * 120, -10), ScriptBrain.new(), "rifle", false))
	await t.frames(10)
	_kill(bots[0], main.player)
	_kill(bots[1], main.player)
	await t.frames(3)
	t.check(main._restart_in < 0.0, "la manche continue tant qu'un bot est en vie")
	t.check(main._hud.bots_left == 1, "il reste 1 bot (affiché %d)" % main._hud.bots_left)
	t.check(Juice.focus_t <= 0.0, "pas de kill cam avant le dernier bot")
	_kill(bots[2], main.player)
	await t.frames(3)
	t.check(main._restart_in >= 0.0 and main.round_no == 2, "le dernier bot tombé termine la manche")
	t.check(Juice.focus_t > 0.0 and Juice._slowmo > 0.0, "kill cam sur la dernière élimination")
	await t.frames(20)
	t.check(Juice.focus_w > 0.3 and main._camera.zoom.x > main._camera.base_zoom + 0.1, "la caméra serre sur la victime")
	_cleanup(main)


func test_chrono(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	main.forced_map = "plateformes"
	main._on_start("chrono", 0)
	main.match_state.time_left = 6.0
	await t.frames(5)
	var bots := _bots(main)
	t.check(bots.size() == 5, "5 bots en chrono (obtenu %d)" % bots.size())
	_kill(bots[0], main.player)
	await t.frames(5)
	t.check(main.match_state.kills_of("Toi") == 1, "élimination comptée")
	var back: bool = await t.until(func() -> bool: return _bots(main).size() == 5, 600)
	t.check(back, "le bot éliminé réapparaît")
	var ended: bool = await t.until(func() -> bool: return main._scoreboard.visible, 900)
	t.check(ended and main.get_tree().paused, "fin de partie au bout du temps, jeu figé")
	t.check(main._scoreboard._title == "TEMPS ÉCOULÉ", "écran de fin du chrono")
	_cleanup(main)


func test_objectif(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	main._on_start("objectif", 0)
	await t.frames(5)
	for b in _bots(main):
		_kill(b, main.player)
	await t.until(func() -> bool: return main._scoreboard.visible, 900)
	t.check(main.match_state.over and main.match_state.winner == "Toi", "5 éliminations = victoire")
	t.check(main._scoreboard.visible and main._scoreboard._title == "VICTOIRE", "écran de victoire")
	_cleanup(main)


func test_leaderboard(t: Node) -> void:
	var list := []
	for s in [3, 9, 5, 7, 1, 8]:
		Leaderboard.insert(list, s, false)
	var scores := list.map(func(e: Dictionary) -> float: return e.score)
	t.check(scores == [9.0, 8.0, 7.0, 5.0, 3.0], "top 5 trié décroissant (obtenu %s)" % str(scores))
	t.check(Leaderboard.insert(list, 2, false) == -1, "un score trop faible n'entre pas")
	var times := []
	for s in [40.0, 25.0, 31.0]:
		Leaderboard.insert(times, s, true)
	t.check(times[0].score == 25.0, "objectif : le temps le plus court en tête")
	await t.frames(1)


func test_boss(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	main._on_start("arcade", 0, 5)
	await t.frames(5)
	var bosses: Array = _bots(main).filter(func(f: Fighter) -> bool: return f.boss)
	t.check(bosses.size() == 1, "manche 5 : un boss")
	if bosses.is_empty():
		_cleanup(main)
		return
	var b: Fighter = bosses[0]
	t.check(b.hp == Boss.HP and b.rig.scale.x > 1.9 and b.body.hp.head > 100.0, "grand, blindé, 600 PV")
	var brain := ScriptBrain.new()
	b.brain = brain
	b.shield = 0.0
	brain.aim = b.global_position + Vector2(-200, -20)
	var mag0: int = b.gun.mag
	brain.fire = true
	await t.frames(20)
	t.check(b.gun.charge_t > 0.0 and b.gun.mag == mag0, "le boss annonce son tir avant de tirer")
	await t.frames(60)
	t.check(b.gun.mag < mag0, "puis il tire")
	brain.fire = false
	b.take_hit(50.0, Vector2.RIGHT, b.global_position + Vector2(0, -30), main.player, 300.0)
	t.check(absf(b.velocity.x) < 120.0, "peu sensible au recul")
	_cleanup(main)
