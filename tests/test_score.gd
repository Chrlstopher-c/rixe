extends RefCounted
## Test du score : éliminations comptées, record retenu seulement s'il est battu, remise à zéro de la partie.


func names() -> Array[String]:
	return ["score"]


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
