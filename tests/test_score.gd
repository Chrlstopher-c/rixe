extends RefCounted
## Test du score : éliminations comptées, record retenu seulement s'il est battu, remise à zéro de la partie.


func names() -> Array[String]:
	return ["score", "profile"]


func test_score(t: Node) -> void:
	var s := RunScore.new()
	s.best = 3
	for i in 2:
		s.add_kill()
	t.check(not s.end_run(false), "2 éliminations ne battent pas un record de 3")
	s.reset()
	for i in 5:
		s.add_kill()
	t.check(s.end_run(false), "5 éliminations battent le record")
	t.check(Settings.load_best() == Settings.load_best(), "lecture du record sans erreur")
	s.reset()
	t.check(s.kills == 0, "nouvelle partie à zéro")
	await t.frames(1)


func test_profile(t: Node) -> void:
	var pr: Profile = t.main.profile
	pr.xp = 0
	pr.stats = {}
	pr.unlocked = []
	pr.outfit = {}
	pr.daily = {"date": "x", "index": 0, "start": 0, "done": false}
	var me: Fighter = t.main.spawn_test_fighter(Vector2(300, -10), ScriptBrain.new(), "rifle", true)
	var v: Fighter = t.main.spawn_test_fighter(Vector2(500, -10), ScriptBrain.new(), "rifle", false)
	await t.frames(5)
	v.death_cause = "headshot"
	Juice.fighter_killed.emit(v, me)
	t.check(pr.stat("kills") == 1 and pr.stat("heads") == 1 and pr.xp == 15, "élimination comptée (+15 XP : %d)" % pr.xp)
	t.check("first_blood" in pr.unlocked, "succès Premier sang")
	for i in 9:
		Juice.fighter_killed.emit(v, me)
	t.check(pr.daily.done and pr.stat("dailies") == 1, "défi du jour (10 par la tête) réussi")
	t.check(pr.level() >= 3, "niveau monté (%d)" % pr.level())
	var scr: CanvasLayer = null
	for c in t.main.get_children():
		if c is CanvasLayer and c.get("profile") == pr:
			scr = c
	scr.adjust("hat", 1)
	t.check(Outfit.value(pr.outfit, "hat") == "casquette", "chapeau débloqué choisi (%s)" % Outfit.value(pr.outfit, "hat"))
	for i in 6:
		scr.adjust("hat", 1)
	t.check(Outfit.level_of("hat", Outfit.value(pr.outfit, "hat")) <= pr.level(), "jamais un objet verrouillé")
	var f: Fighter = t.main.spawner.spawn_player(Vector2(600, -10), ScriptBrain.new())
	t.check(f.outfit.get("hat", "") == pr.outfit.hat, "le joueur porte sa tenue en jeu")
	f.queue_free()
	me.queue_free()
	v.queue_free()
	pr.outfit = {}
	t.main.spawner.outfit = {}
