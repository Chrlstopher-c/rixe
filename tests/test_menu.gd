extends RefCounted
## Tests du menu : écran titre → Entrée lance la partie ; Échap met en pause ; salon en ligne (héberger, code).


func names() -> Array[String]:
	return ["menu", "lobby", "crosshair", "nick", "custom", "replay_photo", "editor", "intro"]


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
	var room: CanvasLayer = main._custom
	t.check(room.visible and room.code.length() == 4 and Juice.net != null, "héberger : salon ouvert, code de 4 lettres")
	t.check(room._text("launch").contains("attente"), "lancer attend un 2e joueur")
	_key(KEY_ESCAPE)
	await t.frames(3)
	t.check(lobby.visible and lobby.screen == "home" and Juice.net == null, "quitter le salon ferme la partie en ligne")
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
	t.check(sight.cfg.preset == "perso" and c.length == 4.0 and c.color == "vert",
		"réglage touché : viseur perso (%s)" % [c])
	sight.adjust("shape", 1)
	sight.adjust("color", 1)
	sight.adjust("dot", 1)
	await t.frames(5)
	t.check(Crosshair.resolve(main._hud.crosshair).shape == "cercle", "forme changée, visible en jeu")
	_key(KEY_ESCAPE)
	await t.frames(3)
	t.check(not sight.visible and main._menu.visible, "Échap : retour au menu")
	main._hud.crosshair = {}


func test_nick(t: Node) -> void:
	var main: Node = t.main
	var n0 := Names.load_nick()
	t.check(n0.begins_with("anon") or n0 != "", "pseudo par défaut (%s)" % n0)
	main.attract = true
	main._menu.show_title()
	await t.frames(3)
	main._menu.activate(main._menu._ids().find("nick"))
	for i in 20:
		_type_key(KEY_BACKSPACE, 0)
	_type("Zorg_42!")
	_type_key(KEY_ENTER, 0)
	await t.frames(3)
	t.check(Names.nick == "Zorg_42" and not main._menu.editing_nick,
		"pseudo modifié, caractères interdits retirés (%s)" % Names.nick)
	t.check(Names.label("Toi") == "Zorg_42", "le joueur s'affiche sous son pseudo")
	Names.nick = n0


func _type_key(code: Key, uni: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.unicode = uni
		e.pressed = pressed
		Input.parse_input_event(e)


func test_custom(t: Node) -> void:
	var main: Node = t.main
	main.attract = true
	main._menu.show_title()
	await t.frames(3)
	main._menu.activate(main._menu._ids().find("custom"))
	await t.frames(3)
	var c: CanvasLayer = main._custom
	t.check(c.visible and c.session == null, "PARTIE PERSONNALISÉE ouvre les réglages (local)")
	c.adjust("mode", 1)
	c.adjust("teams", 1)
	c.adjust("bots", 3)
	c.adjust("level", 2)
	c.adjust("arms", 1)
	c.adjust("map", 1)
	t.check(c.cfg.mode == "chrono" and c.cfg.teams == 2 and c.cfg.bots == 2 and c.cfg.level == "expert",
		"réglages modifiés (%s)" % [c.cfg.to_dict()])
	t.check("my_team" in c._ids(), "en équipes : choix de son équipe")
	c.adjust("my_team", 1)
	c.activate(c._ids().find("launch"))
	await t.frames(10)
	var bots: Array = main._fighters.get_children().filter(func(f: Node) -> bool: return f is Fighter and not f.is_player)
	t.check(main.config.custom and bots.size() == 2, "partie lancée avec 2 bots (%d)" % bots.size())
	t.check(main.player.team == "bleu", "le joueur est dans l'équipe choisie (%s)" % main.player.team)
	t.check(bots.all(func(b: Fighter) -> bool: return b.gun.id == "pistol" or b.gun.id == "pickaxe"),
		"armes limitées aux pistolets")
	t.check(main.player.gun.id == "pistol", "le joueur aussi (%s)" % main.player.gun.id)
	t.check(Juice.arena.map == "plateformes", "carte choisie (%s)" % Juice.arena.map)
	main._to_title()
	main.attract = true


func test_replay_photo(t: Node) -> void:
	var main: Node = t.main
	var me: Fighter = main.spawn_test_fighter(Vector2(300, -10), ScriptBrain.new(), "rifle", true)
	main.player = me
	main.follow(me)
	var rp: Replay = Juice.replay
	rp.clear()
	await t.frames(240)
	t.check(rp.can_play() and rp.frames.size() >= 50,
		"les dernières secondes sont enregistrées (%d images)" % rp.frames.size())
	main._pause()
	main._menu.activate(main._menu._ids().find("replay"))
	await t.frames(30)
	t.check(rp.playing and not main._fighters.visible, "rediffusion lancée depuis la pause")
	_key(KEY_ESCAPE)
	await t.frames(5)
	t.check(not rp.playing and main._fighters.visible and main._menu.mode == "pause", "Échap : retour à la pause")
	main._menu.activate(main._menu._ids().find("photo"))
	await t.frames(5)
	t.check(main.photo.active and not main._hud.visible, "mode photo : interface masquée")
	if DisplayServer.get_name() != "headless":
		main.photo._shoot()
		await t.frames(10)
		t.check(main.photo._saved.begins_with("Enregistrée"), "capture enregistrée (%s)" % main.photo._saved)
	_key(KEY_ESCAPE)
	await t.frames(5)
	t.check(not main.photo.active and main._menu.mode == "pause", "retour à la pause")
	main._resume()
	me.queue_free()


func test_editor(t: Node) -> void:
	var main: Node = t.main
	main.attract = true
	main._menu.show_title()
	await t.frames(3)
	main._menu.activate(main._menu._ids().find("editor"))
	await t.frames(3)
	var ed: CanvasLayer = null
	for c in main.get_children():
		if c is CanvasLayer and c.has_method("paint"):
			ed = c
	t.check(ed != null and ed.active, "ÉDITEUR DE CARTES ouvert")
	ed.map_name = "zz-test-editeur"
	ed.material = 1
	ed.brush = 2
	for i in 10:
		ed.paint(Vector2(400 + i * 16, -60), false)
	ed.material = 6
	ed.paint(Vector2(800, -120), false)
	ed.paint(Vector2(200, 8), true)
	t.check(Juice.arena.terrain.kind.get(Terrain.cell_of(Vector2(400, -60))) == Terrain.K.CONCRETE, "béton peint")
	t.check(not Juice.arena.terrain.kind.has(Terrain.cell_of(Vector2(200, 8))), "cellule effacée")
	t.check(ed.save() and "zz-test-editeur" in MapStore.names(), "carte enregistrée")
	ed.try_map()
	await t.frames(10)
	t.check(Juice.arena.map == "perso:zz-test-editeur", "partie lancée sur la carte (%s)" % Juice.arena.map)
	var painted: int = Juice.arena.terrain.kind.get(Terrain.cell_of(Vector2(400, -60)), 0)
	t.check(painted == Terrain.K.CONCRETE, "le décor peint est là")
	DirAccess.remove_absolute("user://cartes/zz-test-editeur.json")
	main._to_title()
	main.attract = true


func test_intro(t: Node) -> void:
	var intro := Intro.new()
	t.main.add_child(intro)
	var ref: WeakRef = weakref(intro)
	await t.frames(150)
	t.check(intro._head.size() > 0 and intro._blood.size() > 0, "intro : le tir décapite la cible")
	var done: bool = await t.until(func() -> bool: return ref.get_ref() == null, 600)
	t.check(done, "intro : se termine seule et laisse la place au titre")
	intro = Intro.new()
	t.main.add_child(intro)
	ref = weakref(intro)
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	intro._input(ev)
	var skipped: bool = await t.until(func() -> bool: return ref.get_ref() == null, 90)
	t.check(skipped, "intro : une touche la passe")
