extends RefCounted
## Test du menu : écran titre → Entrée lance la partie au clavier ; Échap met en pause ; Entrée reprend.


func names() -> Array[String]:
	return ["menu"]


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)


func test_menu(t: Node) -> void:
	var main: Node = t.main
	main.attract = true
	main._menu.show_title()
	await t.frames(5)
	_key(KEY_ENTER)
	await t.frames(5)
	t.check(not main.attract and not main._menu.visible, "Entrée sur l'écran titre lance la partie")
	t.check(main.player.brain is PlayerBrain, "le joueur est aux commandes")
	_key(KEY_ESCAPE)
	await t.frames(5)
	t.check(main.get_tree().paused and main._menu.mode == "pause", "Échap met en pause")
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	await t.frames(2)
	_key(KEY_UP)
	_key(KEY_ENTER)
	await t.frames(5)
	t.check(not main.get_tree().paused, "Entrée sur REPRENDRE relance le jeu")
