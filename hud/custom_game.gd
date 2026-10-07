extends CanvasLayer
## Partie personnalisée : réglages (mode, durée/objectif, carte, équipes, bots, niveau, armes), choix de son équipe,
## et en ligne la liste des joueurs du salon. L'hôte (ou le joueur seul) règle et lance ; un invité voit les
## réglages de l'hôte en direct et ne choisit que son équipe.

signal back_requested

const ACCENT := Color(0.3, 0.9, 1.0)
const MODES := ["arcade", "chrono", "objectif"]

var main: Node
## Session en ligne (null = partie locale).
var session: NetSession
## Code du salon, affiché en grand en ligne.
var code := ""
var cfg := GameConfig.new()
var _sel := 0
var _t := 0.0
var _canvas := Control.new()
var _font: Font = ThemeDB.fallback_font
var _rects: Array[Rect2] = []


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_screen)
	_canvas.gui_input.connect(_on_mouse)
	add_child(_canvas)
	visible = false


func open_local() -> void:
	session = null
	code = ""
	cfg = GameConfig.new()
	cfg.custom = true
	_show()


func _show() -> void:
	_sel = 0
	visible = true
	if main and main._menu:
		main._menu.close()


func open_online(s: NetSession, room: String) -> void:
	session = s
	code = room
	if s.is_host():
		cfg = GameConfig.new()
		cfg.custom = true
		cfg.max_players = s.link.max_players
		s.match_sync.share(cfg)
	_show()


func close() -> void:
	visible = false


func is_guest() -> bool:
	return session != null and not session.is_host()


## Réglages affichés : les miens (local, hôte) ou ceux reçus de l'hôte (invité).
func shown() -> GameConfig:
	return session.match_sync.cfg if is_guest() else cfg


func _ids() -> Array[String]:
	var c := shown()
	var ids: Array[String] = ["mode"]
	if Modes.has_option(c.mode):
		ids.append("option")
	ids.append("map")
	if c.mode != "arcade":
		ids.append("teams")
		if c.teams > 0:
			ids.append("my_team")
	ids.append_array(["bots", "level", "arms", "launch", "back"])
	return ids


func _text(id: String) -> String:
	var c := shown()
	match id:
		"mode":
			return "MODE  ‹ %s ›" % Modes.label(c.mode)
		"option":
			return "‹ %s ›" % Modes.option_text(c.mode, c.option)
		"map":
			return "CARTE  ‹ %s ›" % ("AU HASARD" if c.map == "hasard" else Maps.label(c.map))
		"teams":
			return "ÉQUIPES  ‹ %s ›" % ("CHACUN POUR SOI" if c.teams == 0 else "%d ÉQUIPES" % c.teams)
		"my_team":
			return "MON ÉQUIPE  ‹ %s ›" % GameConfig.team_name(_my_team()).to_upper()
		"bots":
			return "BOTS  ‹ %s ›" % ("AUTO" if c.bots < 0 else str(c.bots))
		"level":
			return "NIVEAU DES BOTS  ‹ %s ›" % c.level.to_upper()
		"arms":
			return "ARMES  ‹ %s ›" % c.arms.to_upper()
		"launch":
			if is_guest():
				return "EN ATTENTE DE L'HÔTE…"
			if session and not session.connected():
				return "LANCER  (en attente d'un joueur)"
			return "LANCER"
	return "QUITTER LE SALON" if session else "RETOUR"


func _my_id() -> String:
	return session.my_id() if session else "Toi"


func _my_team() -> int:
	return shown().team_index(_my_id(), session.link.slot if session else 0)


func adjust(id: String, step: int) -> void:
	if id == "my_team":
		var t := posmod(_my_team() - 1 + step, shown().teams) + 1
		if is_guest():
			session.match_sync.ask_team(t)
		else:
			cfg.team_of[_my_id()] = t
			_share()
		return
	if is_guest():
		return
	match id:
		"mode":
			cfg.mode = MODES[posmod(MODES.find(cfg.mode) + step, MODES.size())]
			cfg.option = Modes.default_option(cfg.mode)
			_sel = mini(_sel, _ids().size() - 1)
		"option":
			cfg.option = posmod(cfg.option + step, (Modes.ALL[cfg.mode].options as Array).size())
		"map":
			var maps: Array = GameConfig.MAPS + MapStore.names().map(func(n: String) -> String:
				return MapStore.PREFIX + n)
			cfg.map = _cycle(maps, cfg.map, step)
		"teams":
			cfg.teams = [0, 2, 3, 4][posmod([0, 2, 3, 4].find(cfg.teams) + step, 4)]
		"bots":
			cfg.bots = posmod(cfg.bots + 1 + step, 10) - 1
		"level":
			cfg.level = _cycle(GameConfig.LEVEL_ORDER, cfg.level, step)
		"arms":
			cfg.arms = _cycle(GameConfig.ARMS_ORDER, cfg.arms, step)
	_share()


static func _cycle(list: Array, cur: String, step: int) -> String:
	return list[posmod(list.find(cur) + step, list.size())]


func _share() -> void:
	if session and session.is_host():
		session.match_sync.share(cfg)


func activate(i: int) -> void:
	_sel = i
	match _ids()[i]:
		"launch":
			if is_guest() or (session and not session.connected()):
				return
			visible = false
			main.start_custom(cfg)
		"back":
			visible = false
			if session:
				session.leave()
				session = null
			back_requested.emit()
		var id:
			adjust(id, 1)


func _process(delta: float) -> void:
	_t += delta
	if visible:
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var k := Controls.menu_key(event)
	if not visible or k == 0:
		return
	var n := _ids().size()
	if k in [KEY_W, KEY_UP]:
		_sel = posmod(_sel - 1, n)
	elif k in [KEY_S, KEY_DOWN]:
		_sel = (_sel + 1) % n
	elif k in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
		adjust(_ids()[_sel], -1 if k in [KEY_A, KEY_LEFT] else 1)
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		activate(_sel)
	elif k == KEY_ESCAPE:
		activate(_ids().size() - 1)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_mouse(event: InputEvent) -> void:
	if not (event is InputEventMouse):
		return
	for i in _rects.size():
		if _rects[i].has_point(event.position):
			_sel = i
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					activate(i)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					adjust(_ids()[i], -1)


func _draw_screen() -> void:
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04, 0.82))
	var title := "PARTIE PERSONNALISÉE" if session == null else "SALON EN LIGNE"
	_canvas.draw_string(_font, Vector2(0, size.y * 0.1), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22,
		Color(1.6, 1.5, 1.5))
	var c := shown()
	_canvas.draw_string(_font, Vector2(0, size.y * 0.1 + 16), Modes.ALL[c.mode].desc, HORIZONTAL_ALIGNMENT_CENTER,
		size.x, 9, Color(1, 0.85, 0.9, 0.7))
	var left := size.x * (0.36 if session else 0.5)
	_draw_rows(left, size.y * 0.24)
	if session:
		_draw_room(Rect2(size.x * 0.66, size.y * 0.2, size.x * 0.3, size.y * 0.6))
	var help := "‹ › ou clic gauche / droit pour changer · Entrée pour valider · Échap pour quitter"
	if is_guest():
		help = "L'hôte règle la partie · tu choisis ton équipe · la partie démarre quand l'hôte lance"
	_canvas.draw_string(_font, Vector2(0, size.y - 12), help, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8,
		Color(1, 0.9, 0.95, 0.55))


func _draw_rows(cx: float, y0: float) -> void:
	_rects.clear()
	var ids := _ids()
	var panel := Rect2(cx - 140, y0 - 20, 280, ids.size() * 18.0 + 10)
	_canvas.draw_rect(panel, Color(0.02, 0.01, 0.05, 0.72))
	_canvas.draw_rect(panel, Color(ACCENT, 0.25), false, 1.0)
	for i in ids.size():
		var y := y0 + i * 18.0
		var r := Rect2(cx - 120, y - 12, 240, 16)
		_rects.append(r)
		var on := i == _sel
		var locked: bool = is_guest() and not ids[i] in ["my_team", "back"]
		if on:
			_canvas.draw_rect(r, Color(ACCENT, 0.12))
			_canvas.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), ACCENT * 1.8)
		var col := Color(ACCENT * 1.6) if on else Color(1, 0.92, 0.95, 0.45 if locked else 0.78)
		if ids[i] == "my_team":
			col = Color(GameConfig.TEAM_COLORS[_my_team()] * 1.5, 1.0)
		_canvas.draw_string(_font, Vector2(r.position.x, y), _text(ids[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
			12 if ids[i] == "launch" else 11, col)


## En ligne : code du salon et joueurs présents (pseudo, équipe, hôte).
func _draw_room(box: Rect2) -> void:
	_canvas.draw_rect(box, Color(0.02, 0.01, 0.05, 0.72))
	_canvas.draw_rect(box, Color(ACCENT, 0.25), false, 1.0)
	var pulse := 1.5 + 0.3 * sin(_t * 3.0)
	_canvas.draw_string(_font, box.position + Vector2(0, 30), code, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 30,
		Color(ACCENT * pulse, 1.0))
	_canvas.draw_string(_font, box.position + Vector2(0, 44), "code à donner aux autres", HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x, 8, Color(1, 0.9, 0.95, 0.55))
	var c := shown()
	var players := session.players()
	_canvas.draw_string(_font, box.position + Vector2(10, 66), "JOUEURS  %d / %d" % [players.size(),
		session.link.max_players], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.9, 0.95, 0.7))
	for i in players.size():
		var p: Dictionary = players[i]
		var t := c.team_index(p.id, p.slot)
		var col := Color(GameConfig.TEAM_COLORS[t] * 1.5, 1.0) if t > 0 else Color(1, 0.95, 0.95, 0.9)
		var line := "%s%s%s" % [p.nick, "  (hôte)" if p.slot == 0 else "", "  — toi" if p.id == _my_id() else ""]
		_canvas.draw_string(_font, box.position + Vector2(14, 84 + i * 15), line, HORIZONTAL_ALIGNMENT_LEFT,
			box.size.x - 20, 10, col)
