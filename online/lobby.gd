extends CanvasLayer
## Entrée du jeu en ligne : héberger (nombre de joueurs maximum, puis code de 4 lettres à donner aux autres) ou
## rejoindre (taper le code). Une fois connecté, la partie se prépare dans l'écran de partie personnalisée.

signal back_requested

const ACCENT := Color(0.3, 0.9, 1.0)
const ERROR := Color(2.0, 0.55, 0.5)

var main: Node
## Écran de partie personnalisée, ouvert dès que le salon est créé ou rejoint.
var custom: CanvasLayer
var max_players := 2
var screen := "home"
var code := ""
var status := ""
## Le message d'état est une erreur (affiché en rouge).
var failed := false
var _sel := 0
var _t := 0.0
var _canvas := Control.new()
var _font: Font = ThemeDB.fallback_font
var _rects: Array[Rect2] = []
var _session: NetSession


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_lobby)
	_canvas.gui_input.connect(_on_mouse)
	add_child(_canvas)
	visible = false


func open() -> void:
	visible = true
	_go("home")


func close() -> void:
	visible = false


func _go(s: String, msg: String = "", error: bool = false) -> void:
	screen = s
	status = msg
	failed = error
	_sel = 0


func _ids() -> Array[String]:
	match screen:
		"join":
			return ["code", "join", "back"]
		"joined":
			return ["cancel"]
	return ["max", "host", "join_screen", "back"]


func _text(id: String) -> String:
	match id:
		"max":
			return "JOUEURS MAX  ‹ %d ›" % max_players
		"host":
			return "HÉBERGER UNE PARTIE"
		"join_screen":
			return "REJOINDRE AVEC UN CODE"
		"code":
			var shown := PackedStringArray()
			for i in 4:
				shown.append(code[i] if i < code.length() else "_")
			return "CODE  " + " ".join(shown)
		"join":
			return "REJOINDRE"
		"cancel":
			return "ANNULER"
	return "RETOUR"


func _process(delta: float) -> void:
	_t += delta
	if visible:
		_canvas.queue_redraw()
		if screen == "joined" and _session and is_instance_valid(_session) and _session.connected():
			_to_room()


## Salon créé ou rejoint : la préparation de la partie continue dans l'écran de partie personnalisée.
func _to_room() -> void:
	visible = false
	custom.open_online(_session, code)


## Retour depuis le salon (QUITTER LE SALON) : la session est déjà fermée.
func back_from_room() -> void:
	_leave()
	open()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if screen == "join" and event is InputEventKey and event.pressed and _type(event):
		get_viewport().set_input_as_handled()
		return
	var k := Controls.menu_key(event)
	if k == 0:
		return
	var n := _ids().size()
	if k in [KEY_W, KEY_UP]:
		_sel = posmod(_sel - 1, n)
	elif k in [KEY_S, KEY_DOWN]:
		_sel = (_sel + 1) % n
	elif k in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
		_adjust(_ids()[_sel], -1 if k in [KEY_A, KEY_LEFT] else 1)
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		activate(_sel)
	elif k == KEY_ESCAPE:
		_cancel()
	else:
		return
	get_viewport().set_input_as_handled()


## Saisie du code : lettres (selon la disposition du clavier), retour arrière, Entrée pour rejoindre.
func _type(e: InputEventKey) -> bool:
	var kc := e.keycode if e.keycode != KEY_NONE else e.physical_keycode
	if kc == KEY_BACKSPACE:
		code = code.left(maxi(code.length() - 1, 0))
		return true
	if kc in [KEY_ENTER, KEY_KP_ENTER]:
		activate(_ids().find("join"))
		return true
	var ch := char(e.unicode).to_upper() if e.unicode > 0 else ""
	if ch.length() == 1 and ch >= "A" and ch <= "Z":
		if code.length() < 4:
			code += ch
		return true
	return false


func _adjust(id: String, step: int) -> void:
	if id == "max":
		max_players = posmod(max_players - 2 + step, 3) + 2


func activate(i: int) -> void:
	_sel = i
	match _ids()[i]:
		"host":
			host()
		"join_screen":
			code = ""
			_go("join")
		"join", "code":
			if code.length() == 4:
				join(code)
			else:
				status = "Le code fait 4 lettres"
		"cancel", "back":
			_cancel()
		var id:
			_adjust(id, 1)


func host() -> void:
	code = ""
	for i in 4:
		code += char(65 + randi() % 26)
	_start("host", "Donne ce code aux autres joueurs")
	_to_room()


func join(c: String) -> void:
	code = c.to_upper()
	_start("guest", "Connexion…")
	_go("joined", "Connexion…")


func _start(role: String, msg: String) -> void:
	_leave()
	status = msg
	_session = NetSession.begin(main, role, code, max_players)
	_session.link.joined.connect(_on_joined)
	_session.ended.connect(_on_ended)


func _on_joined(_peer_here: bool) -> void:
	if screen == "joined":
		status = "Connecté · présentation à l'hôte…"


## Lien perdu (code inconnu, relais injoignable, autre joueur parti) : retour au salon ou au menu, avec la raison.
func _on_ended(reason: String) -> void:
	_leave()
	if visible:
		_go("join" if screen == "joined" else "home", reason, true)
	else:
		main._to_title()
		Juice.notify(reason)


func _cancel() -> void:
	match screen:
		"home":
			close()
			back_requested.emit()
		_:
			_leave()
			_go("home")


func _leave() -> void:
	if _session and is_instance_valid(_session):
		for c in [[_session.ended, _on_ended], [_session.link.joined, _on_joined]]:
			if c[0].is_connected(c[1]):
				c[0].disconnect(c[1])
		_session.leave()
	_session = null


func _on_mouse(event: InputEvent) -> void:
	if not (event is InputEventMouse):
		return
	for i in _rects.size():
		if _rects[i].has_point(event.position):
			_sel = i
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				activate(i)


func _draw_lobby() -> void:
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04, 0.75))
	var top := size.y * 0.22
	_canvas.draw_string(_font, Vector2(0, top), "EN LIGNE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28,
		Color(1.6, 1.5, 1.5))
	if screen in ["host", "joined"] and code != "":
		var pulse := 1.5 + 0.3 * sin(_t * 3.0)
		_canvas.draw_string(_font, Vector2(0, top + 40), code, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40,
			Color(ACCENT * pulse, 1.0))
	_canvas.draw_string(_font, Vector2(0, top + 62), status, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10,
		ERROR if failed else Color(1, 0.9, 0.95, 0.75))
	_draw_items(size.x * 0.5, size.y * 0.5)
	var help := "Partie à deux par Internet · sans ouvrir de port · Échap pour revenir"
	_canvas.draw_string(_font, Vector2(0, size.y - 12), help, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8,
		Color(1, 0.9, 0.95, 0.55))


func _draw_items(cx: float, y0: float) -> void:
	_rects.clear()
	var ids := _ids()
	var panel := Rect2(cx - 140, y0 - 22, 280, ids.size() * 20.0 + 14)
	_canvas.draw_rect(panel, Color(0.02, 0.01, 0.05, 0.72))
	_canvas.draw_rect(panel, Color(ACCENT, 0.25), false, 1.0)
	for i in ids.size():
		var y := y0 + i * 20.0
		var r := Rect2(cx - 120, y - 13, 240, 18)
		_rects.append(r)
		var on := i == _sel
		if on:
			_canvas.draw_rect(r, Color(ACCENT, 0.12))
			_canvas.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), ACCENT * 1.8)
		var col := Color(ACCENT * 1.6) if on else Color(1, 0.92, 0.95, 0.75)
		_canvas.draw_string(_font, Vector2(r.position.x, y), _text(ids[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12,
			col)
