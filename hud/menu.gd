extends CanvasLayer
## Écran titre (mode, réglage, jouer, classement, options) et menu de pause ; clavier (ZQSD/flèches, Entrée) ou souris.

signal start_requested(mode: String, option: int)
signal resume_requested
signal title_requested
signal restart_requested
signal quit_requested
signal hd_changed(on: bool)
signal volume_changed(v: float)

const ACCENT := Color(0.3, 0.9, 1.0)

var mode := ""
var volume := 0.8
var hd := true
var best := 0
var game_mode := "arcade"
var options := {"arcade": 0, "chrono": Modes.default_option("chrono"), "objectif": Modes.default_option("objectif")}
var _sel := 0
var _t := 0.0
var _canvas := Control.new()
var _font: Font = ThemeDB.fallback_font
var _rects: Array[Rect2] = []
var loadout := {"weapon": "rifle", "attachments": {}}


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_menu)
	_canvas.gui_input.connect(_on_mouse)
	add_child(_canvas)
	close()


func show_title() -> void:
	_open("title")
	_sel = _ids().find("play")


func show_pause() -> void:
	_open("pause")


func close() -> void:
	mode = ""
	visible = false


func _open(m: String) -> void:
	mode = m
	_sel = 0
	visible = true


## Identifiants des lignes du menu courant.
func _ids() -> Array[String]:
	if mode == "board":
		return ["board_mode", "back"]
	if mode == "armory":
		var ids: Array[String] = ["weapon"]
		if Arsenal.accepts(loadout.weapon):
			for s in Arsenal.SLOTS:
				ids.append("slot_" + s)
		ids.append("back")
		return ids
	if mode == "pause":
		return ["resume", "restart", "volume", "display", "title", "quit"]
	var ids: Array[String] = ["mode"]
	if Modes.has_option(game_mode):
		ids.append("option")
	ids.append_array(["play", "armory", "board", "volume", "display", "quit"])
	return ids


func _text(id: String) -> String:
	match id:
		"mode", "board_mode":
			return "MODE  ‹ %s ›" % Modes.label(game_mode)
		"option":
			return "‹ %s ›" % Modes.option_text(game_mode, options[game_mode])
		"play":
			return "JOUER"
		"board":
			return "CLASSEMENT"
		"armory":
			return "ARMURERIE"
		"weapon":
			return "ARME  ‹ %s ›" % String(Arsenal.WEAPONS[loadout.weapon].name).to_upper()
		"volume":
			return "VOLUME  %d %%" % roundi(volume * 100.0)
		"display":
			return "AFFICHAGE  %s" % ("HD" if hd else "PIXEL")
		"resume":
			return "REPRENDRE"
		"title":
			return "MENU PRINCIPAL"
		"restart":
			return "RECOMMENCER"
		"back":
			return "RETOUR"
	if id.begins_with("slot_"):
		var slot := id.substr(5)
		var a: String = loadout.attachments.get(slot, "")
		var label: String = {"optic": "VISEUR", "mag": "CHARGEUR", "barrel": "CANON", "stock": "CROSSE"}[slot]
		var name := "aucun" if a == "" else String(Arsenal.ATTACHMENTS[a].name)
		return "%s  ‹ %s ›" % [label, name.to_upper()]
	return "QUITTER"


func _process(delta: float) -> void:
	_t += delta
	if visible:
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	var k: int = event.physical_keycode
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
		_back()
	else:
		return
	get_viewport().set_input_as_handled()


func _back() -> void:
	match mode:
		"pause":
			resume_requested.emit()
		"board", "armory":
			show_title()
		_:
			quit_requested.emit()


func _adjust(id: String, step: int) -> void:
	match id:
		"mode", "board_mode":
			var i := Modes.ORDER.find(game_mode)
			game_mode = Modes.ORDER[posmod(i + step, Modes.ORDER.size())]
			_sel = mini(_sel, _ids().size() - 1)
		"option":
			var count: int = (Modes.ALL[game_mode].options as Array).size()
			options[game_mode] = posmod(options[game_mode] + step, count)
		"weapon":
			loadout.weapon = _cycle(Unlocks.weapons(), loadout.weapon, step)
			if not Arsenal.accepts(loadout.weapon):
				loadout.attachments = {}
			Unlocks.save_loadout(loadout)
		"volume":
			volume = clampf(volume + step * 0.1, 0.0, 1.0)
			volume_changed.emit(volume)
		"display":
			hd = not hd
			hd_changed.emit(hd)
		_:
			if id.begins_with("slot_"):
				var slot := id.substr(5)
				var a := _cycle(Unlocks.attachments(slot), loadout.attachments.get(slot, ""), step)
				if a == "":
					loadout.attachments.erase(slot)
				else:
					loadout.attachments[slot] = a
				Unlocks.save_loadout(loadout)


static func _cycle(list: Array, current: String, step: int) -> String:
	if list.is_empty():
		return current
	var i := list.find(current)
	return list[posmod(i + step, list.size())]


func activate(i: int) -> void:
	_sel = i
	var id: String = _ids()[i]
	match id:
		"play":
			start_requested.emit(game_mode, options[game_mode])
		"board":
			_open("board")
		"armory":
			loadout = Unlocks.loadout()
			_open("armory")
		"back":
			show_title()
		"resume":
			resume_requested.emit()
		"title":
			title_requested.emit()
		"restart":
			restart_requested.emit()
		"quit":
			quit_requested.emit()
		"volume":
			_adjust(id, 1 if volume < 1.0 else -10)
		_:
			_adjust(id, 1)


func _on_mouse(event: InputEvent) -> void:
	if not (event is InputEventMouse):
		return
	for i in _rects.size():
		if _rects[i].has_point(event.position):
			_sel = i
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				activate(i)


func _draw_menu() -> void:
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04, 0.55 if mode == "title" else 0.75))
	var top := size.y * (0.24 if mode == "title" else 0.22)
	if mode == "title":
		var pulse := 1.6 + 0.4 * sin(_t * 2.0)
		_canvas.draw_string(_font, Vector2(0, top), "RIXE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 56,
			Color(ACCENT * pulse, 1.0))
		_canvas.draw_string(_font, Vector2(0, top + 20), Modes.ALL[game_mode].desc, HORIZONTAL_ALIGNMENT_CENTER,
			size.x, 10, Color(1, 0.85, 0.9, 0.75))
	else:
		var head: String = {"pause": "PAUSE", "board": "CLASSEMENT", "armory": "ARMURERIE"}[mode]
		_canvas.draw_string(_font, Vector2(0, top), head, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(1.6, 1.5, 1.5))
	if mode == "board":
		_draw_board(size.x * 0.5, top + 26)
	if mode == "armory":
		var hint := "Ramasse une arme ou un accessoire en partie pour le débloquer ici"
		_canvas.draw_string(_font, Vector2(0, top + 20), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9,
			Color(1, 0.9, 0.95, 0.6))
	_draw_items(size.x * 0.5, size.y * (0.4 if mode == "title" else 0.36) + (150.0 if mode == "board" else 0.0))
	var help := "ZQSD · Espace · clic tirer · clic droit viser · R recharger · G grenade · H soin · Tab sac · E pied"
	_canvas.draw_string(_font, Vector2(0, size.y - 12), help, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8,
		Color(1, 0.9, 0.95, 0.55))


func _draw_board(cx: float, y0: float) -> void:
	var key := Modes.board_key(game_mode, options[game_mode])
	var list := Leaderboard.entries(key)
	var sub := Modes.option_text(game_mode, options[game_mode]) if Modes.has_option(game_mode) else "une seule vie"
	_canvas.draw_string(_font, Vector2(0, y0), sub, HORIZONTAL_ALIGNMENT_CENTER, _canvas.size.x, 10,
		Color(1, 0.9, 0.95, 0.7))
	if list.is_empty():
		_canvas.draw_string(_font, Vector2(0, y0 + 26), "Aucun score pour l'instant", HORIZONTAL_ALIGNMENT_CENTER,
			_canvas.size.x, 10, Color(1, 0.9, 0.95, 0.5))
	for i in list.size():
		var e: Dictionary = list[i]
		var line := "%d.   %s   ·   %s" % [i + 1, Leaderboard.format_score(game_mode, e.score), e.date]
		_canvas.draw_string(_font, Vector2(0, y0 + 24 + i * 16), line, HORIZONTAL_ALIGNMENT_CENTER, _canvas.size.x,
			11, Color(ACCENT * 1.5) if i == 0 else Color(1, 0.92, 0.95, 0.8))


func _draw_items(cx: float, y0: float) -> void:
	_rects.clear()
	var ids := _ids()
	var panel := Rect2(cx - 130, y0 - 22, 260, ids.size() * 20.0 + 14)
	_canvas.draw_rect(panel, Color(0.02, 0.01, 0.05, 0.72))
	_canvas.draw_rect(panel, Color(ACCENT, 0.25), false, 1.0)
	for i in ids.size():
		var y := y0 + i * 20.0
		var r := Rect2(cx - 110, y - 13, 220, 18)
		_rects.append(r)
		var on := i == _sel
		if on:
			_canvas.draw_rect(r, Color(ACCENT, 0.12))
			_canvas.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), ACCENT * 1.8)
		var col := Color(ACCENT * 1.6) if on else Color(1, 0.92, 0.95, 0.75)
		var s := 12 if ids[i] != "play" else 14
		_canvas.draw_string(_font, Vector2(r.position.x, y), _text(ids[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, s, col)
