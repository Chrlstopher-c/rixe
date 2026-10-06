extends Node
## Banc de tests headless : lance les scénarios demandés (--tests=a,b ou all), affiche PASS/FAIL, quitte avec un code.

var main: Node
var _failures: Array[String] = []
var _current := ""
var _suites: Array = []


func _init(game: Node, names: String) -> void:
	main = game
	for path in ["res://tests/test_movement.gd", "res://tests/test_combat.gd", "res://tests/test_audio.gd"]:
		var suite: Object = load(path).new()
		_suites.append(suite)
	_current = names


func _ready() -> void:
	Engine.time_scale = 1.0
	await get_tree().process_frame
	var ran := 0
	for suite in _suites:
		for name: String in suite.names():
			if _current != "all" and not (name in _current.split(",")):
				continue
			ran += 1
			await _run(suite, name)
	var ok := _failures.is_empty() and ran > 0
	print("TESTS %s (%d lancés, %d échecs)" % ["OK" if ok else "FAILED", ran, _failures.size()])
	get_tree().quit(0 if ok else 1)


func _run(suite: Object, name: String) -> void:
	var before := _failures.size()
	main.reset_for_test()
	await suite.call("test_" + name, self)
	print(("PASS " if _failures.size() == before else "FAIL ") + name)


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		print("  ✗ " + msg)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return false
