extends CanvasLayer
## Écran titre et menu de pause : navigation clavier (ZQSD/flèches, Entrée) ou souris ; réglages volume et HD/pixel.

signal start_requested
signal resume_requested
signal quit_requested
signal hd_changed(on: bool)
signal volume_changed(v: float)

const ACCENT := Color(0.3, 0.9, 1.0)

var mode := ""
var volume := 0.8
var hd := true
var _sel := 0
var _t := 0.0
var _canvas := Control.new()
var _font: Font = ThemeDB.fallback_font
var _rects: Array[Rect2] = []


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


func show_pause() -> void:
	_open("pause")


func close() -> void:
	mode = ""
	visible = false


func _open(m: String) -> void:
	mode = m
	_sel = 0
	visible = true


func _items() -> Array[String]:
	var vol := "VOLUME  %d %%" % roundi(volume * 100.0)
	var disp := "AFFICHAGE  %s" % ("HD" if hd else "PIXEL")
	var first := "JOUER" if mode == "title" else "REPRENDRE"
	return [first, vol, disp, "QUITTER"]


func _process(delta: float) -> void:
	_t += delta
	if visible:
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	var k: int = event.physical_keycode
	if k in [KEY_W, KEY_UP]:
		_sel = posmod(_sel - 1, 4)
	elif k in [KEY_S, KEY_DOWN]:
		_sel = (_sel + 1) % 4
	elif k in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
		_adjust(-1 if k in [KEY_A, KEY_LEFT] else 1)
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		activate(_sel)
	elif k == KEY_ESCAPE:
		if mode == "pause":
			resume_requested.emit()
		else:
			quit_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _adjust(step: int) -> void:
	if _sel == 1:
		volume = clampf(volume + step * 0.1, 0.0, 1.0)
		volume_changed.emit(volume)
	elif _sel == 2:
		hd = not hd
		hd_changed.emit(hd)


func activate(i: int) -> void:
	_sel = i
	match i:
		0:
			if mode == "title":
				start_requested.emit()
			else:
				resume_requested.emit()
		1:
			_adjust(1 if volume < 1.0 else -10)
		2:
			_adjust(1)
		3:
			quit_requested.emit()


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
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04, 0.55 if mode == "title" else 0.7))
	var cx := size.x * 0.5
	if mode == "title":
		var pulse := 1.6 + 0.4 * sin(_t * 2.0)
		_canvas.draw_string(_font, Vector2(0, size.y * 0.3), "RIXE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 64,
			Color(ACCENT * pulse, 1.0))
		var sub := "combat à mort · stickmen"
		_canvas.draw_string(_font, Vector2(0, size.y * 0.3 + 22), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10,
			Color(1, 0.85, 0.9, 0.7))
	else:
		_canvas.draw_string(_font, Vector2(0, size.y * 0.3), "PAUSE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 32,
			Color(1.6, 1.5, 1.5))
	_draw_items(cx, size.y * 0.48)
	var help := "ZQSD bouger · Espace sauter · clic tirer · Maj dash · E coup de pied · F1 HD/pixel"
	_canvas.draw_string(_font, Vector2(0, size.y - 14), help, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8,
		Color(1, 0.9, 0.95, 0.55))


func _draw_items(cx: float, y0: float) -> void:
	_rects.clear()
	var items := _items()
	for i in items.size():
		var y := y0 + i * 22.0
		var r := Rect2(cx - 90, y - 13, 180, 19)
		_rects.append(r)
		var on := i == _sel
		if on:
			_canvas.draw_rect(r, Color(ACCENT, 0.12))
			_canvas.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), ACCENT * 1.8)
		var col := Color(ACCENT * 1.6) if on else Color(1, 0.92, 0.95, 0.75)
		_canvas.draw_string(_font, Vector2(r.position.x, y), items[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, col)
