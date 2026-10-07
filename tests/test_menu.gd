extends RefCounted
## Tests du menu : écran titre → Entrée lance la partie ; Échap met en pause ; salon en ligne (héberger, code).


func names() -> Array[String]:
	return ["menu", "lobby", "crosshair"]


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


func _type(text: String) -> void:
	for ch in text:
		for pressed in [true, false]:
			var e := InputEventKey.new()
			e.keycode = OS.find_keycode_from_string(ch)
			e.unicode = ch.unicode_at(0)
			e.pressed = pressed
			Input.parse_input_event(e)


func test_lobby(t: Node) -> void:
	var main: Node = t.main
	var relay := OS.get_environment("RIXE_RELAY")
	OS.set_environment("RIXE_RELAY", "ws://127.0.0.1:9")
	main.attract = true
	main._menu.show_title()
	await t.frames(3)
	main._menu.activate(main._menu._ids().find("online"))
	await t.frames(3)
	var lobby: CanvasLayer = main._lobby
	t.check(lobby.visible and not main._menu.visible, "EN LIGNE ouvre le salon")
	lobby.activate(lobby._ids().find("host"))
	await t.frames(3)
	t.check(lobby.screen == "host" and lobby.code.length() == 4 and Juice.net != null, "héberger : code de 4 lettres")
	t.check(lobby._text("launch").contains("attente"), "lancer attend un 2e joueur")
	_key(KEY_ESCAPE)
	await t.frames(3)
	t.check(lobby.screen == "home" and Juice.net == null, "annuler ferme la partie en ligne")
	lobby.activate(lobby._ids().find("join_screen"))
	_type("abz")
	await t.frames(3)
	t.check(lobby.code == "ABZ", "le code se tape au clavier (%s)" % lobby.code)
	_key(KEY_ENTER)
	await t.frames(3)
	t.check(lobby.screen == "join" and lobby.status.contains("4 lettres"), "code incomplet refusé")
	_type("q")
	_key(KEY_ENTER)
	await t.frames(3)
	t.check(lobby.screen == "joined" and Juice.net != null, "code complet : connexion lancée")
	var t0 := Time.get_ticks_msec()
	while not lobby.failed and Time.get_ticks_msec() - t0 < 25000:
		await t.frames(1)
	var failed: bool = lobby.failed
	t.check(failed and lobby.screen == "join", "relais absent : retour à la saisie, erreur affichée (%s)" % lobby.status)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	await t.frames(3)
	t.check(not lobby.visible and main._menu.visible, "retour au menu principal")
	OS.set_environment("RIXE_RELAY", relay)


func test_crosshair(t: Node) -> void:
	var main: Node = t.main
	main.attract = true
	main._menu.show_title()
	await t.frames(3)
	main._menu.activate(main._menu._ids().find("crosshair"))
	await t.frames(3)
	var sight: CanvasLayer = null
	for c in main.get_children():
		if c is CanvasLayer and c.has_method("adjust") and c.visible:
			sight = c
	t.check(sight != null and not main._menu.visible, "VISEUR ouvre l'écran du viseur")
	if sight == null:
		return
	t.check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE or DisplayServer.get_name() == "headless", "curseur visible")
	sight.adjust("preset", 1)
	t.check(sight.cfg.preset == "précis" and main._hud.crosshair.preset == "précis", "modèle suivant appliqué au jeu")
	sight.adjust("length", 1)
	var c := Crosshair.resolve(sight.cfg)
	t.check(sight.cfg.preset == "perso" and c.length == 4.0 and c.color == "vert", "réglage touché : viseur perso (%s)" % [c])
	sight.adjust("shape", 1)
	sight.adjust("color", 1)
	sight.adjust("dot", 1)
	await t.frames(5)
	t.check(Crosshair.resolve(main._hud.crosshair).shape == "cercle", "forme changée, visible en jeu")
	_key(KEY_ESCAPE)
	await t.frames(3)
	t.check(not sight.visible and main._menu.visible, "Échap : retour au menu")
	main._hud.crosshair = {}
