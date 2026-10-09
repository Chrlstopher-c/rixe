extends CanvasLayer
## Écran VISEUR : choisir un modèle ou régler le sien (toucher un réglage passe en « perso »), avec aperçu en grand
## qui s'écarte comme en jeu quand l'option dynamique est active. Clavier (ZQSD/flèches, Entrée) ou souris.

signal back_requested
signal changed(cfg: Dictionary)

const ACCENT := Color(0.3, 0.9, 1.0)
const NAMES := ["classique", "précis", "point", "cercle", "T", "perso"]
const ROWS := ["preset", "shape", "length", "gap", "thick", "dot", "outline", "color", "dynamic", "back"]
const LABELS := {"preset": "MODÈLE", "shape": "FORME", "length": "LONGUEUR", "gap": "ÉCART", "thick": "ÉPAISSEUR",
	"dot": "POINT CENTRAL", "outline": "CONTOUR", "color": "COULEUR", "dynamic": "S'ÉCARTE AU TIR"}

var cfg := {}
var _sel := 0
var _t := 0.0
var _canvas := Control.new()
var _font: Font = ThemeDB.fallback_font
var _rects: Array[Rect2] = []
var _list := ScrollList.new()


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_screen)
	_canvas.gui_input.connect(_on_mouse)
	add_child(_canvas)
	visible = false


func open() -> void:
	cfg = Settings.load_crosshair()
	if not cfg.has("preset"):
		cfg = {"preset": "classique", "custom": {}}
	_sel = 0
	visible = true


func _text(id: String) -> String:
	var c := Crosshair.resolve(cfg)
	match id:
		"preset":
			return "MODÈLE  ‹ %s ›" % String(cfg.preset).to_upper()
		"shape", "color":
			return "%s  ‹ %s ›" % [LABELS[id], String(c[id]).to_upper()]
		"length", "gap", "thick":
			return "%s  ‹ %s ›" % [LABELS[id], str(c[id])]
		"dot", "outline", "dynamic":
			return "%s  ‹ %s ›" % [LABELS[id], "OUI" if c[id] else "NON"]
	return "RETOUR"


## Change un réglage ; hors du modèle « perso », on part des valeurs du modèle affiché.
func adjust(id: String, step: int) -> void:
	if id == "preset":
		cfg.preset = NAMES[posmod(NAMES.find(cfg.preset) + step, NAMES.size())]
		_save()
		return
	var c := Crosshair.resolve(cfg)
	match id:
		"shape":
			c.shape = _cycle(Crosshair.SHAPES, c.shape, step)
		"color":
			c.color = _cycle(Crosshair.COLORS.keys(), c.color, step)
		"length", "gap", "thick":
			var r: Array = Crosshair.RANGES[id]
			c[id] = clampf(float(c[id]) + step * float(r[2]), r[0], r[1])
		"dot", "outline", "dynamic":
			c[id] = not c[id]
	cfg = {"preset": "perso", "custom": c}
	_save()


static func _cycle(list: Array, cur: String, step: int) -> String:
	return list[posmod(list.find(cur) + step, list.size())]


func _save() -> void:
	Settings.save_crosshair(cfg)
	changed.emit(cfg)


func activate(i: int) -> void:
	_sel = i
	if ROWS[i] == "back":
		visible = false
		back_requested.emit()
	else:
		adjust(ROWS[i], 1)


func _process(delta: float) -> void:
	_t += delta
	if visible:
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var k := Controls.menu_key(event)
	if not visible or k == 0:
		return
	if k in [KEY_W, KEY_UP]:
		_sel = posmod(_sel - 1, ROWS.size())
	elif k in [KEY_S, KEY_DOWN]:
		_sel = (_sel + 1) % ROWS.size()
	elif k in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
		if ROWS[_sel] != "back":
			adjust(ROWS[_sel], -1 if k in [KEY_A, KEY_LEFT] else 1)
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		activate(_sel)
	elif k == KEY_ESCAPE:
		activate(ROWS.size() - 1)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_mouse(event: InputEvent) -> void:
	if not (event is InputEventMouse):
		return
	var step := ScrollList.wheel(event)
	if step != 0:
		_sel = clampi(_sel + step, 0, ROWS.size() - 1)
		return
	for k in _rects.size():
		if _rects[k].has_point(event.position):
			var i := _list.first + k
			_sel = i
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					activate(i)
				elif event.button_index == MOUSE_BUTTON_RIGHT and ROWS[i] != "back":
					adjust(ROWS[i], -1)


func _draw_screen() -> void:
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04, 0.8))
	_canvas.draw_string(_font, Vector2(0, size.y * 0.13), "VISEUR", HORIZONTAL_ALIGNMENT_CENTER, size.x, 24,
		Color(1.6, 1.5, 1.5))
	var box := Rect2(size.x * 0.5 - 50, size.y * 0.17, 100, 64)
	_canvas.draw_rect(box, Color(0.08, 0.07, 0.12, 0.9))
	_canvas.draw_rect(box, Color(ACCENT, 0.25), false, 1.0)
	_canvas.draw_set_transform(box.get_center(), 0.0, Vector2(2.5, 2.5))
	Crosshair.draw(_canvas, Vector2.ZERO, Crosshair.resolve(cfg), 2.0 + 2.0 * sin(_t * 3.0))
	_canvas.draw_set_transform(Vector2.ZERO)
	_draw_rows(size.x * 0.5, size.y * 0.45)
	var help := "‹ › ou clic gauche / droit pour changer · toucher un réglage crée ton viseur perso · Échap : retour"
	_canvas.draw_string(_font, Vector2(0, size.y - 12), help, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8,
		Color(1, 0.9, 0.95, 0.55))


func _draw_rows(cx: float, y0: float) -> void:
	_rects.clear()
	_list.layout(ROWS.size(), _sel, y0, _canvas.size.y - 30.0, 17.0)
	var panel := Rect2(cx - 130, y0 - 20, 260, _list.rows * 17.0 + 10)
	_canvas.draw_rect(panel, Color(0.02, 0.01, 0.05, 0.72))
	_canvas.draw_rect(panel, Color(ACCENT, 0.25), false, 1.0)
	_list.draw_arrows(_canvas, cx, panel.position.y + 4, panel.end.y - 3, Color(ACCENT * 1.6, 0.9))
	for i in range(_list.first, _list.last()):
		var y := y0 + (i - _list.first) * 17.0
		var r := Rect2(cx - 110, y - 12, 220, 16)
		_rects.append(r)
		var on := i == _sel
		if on:
			_canvas.draw_rect(r, Color(ACCENT, 0.12))
			_canvas.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), ACCENT * 1.8)
		var col := Color(ACCENT * 1.6) if on else Color(1, 0.92, 0.95, 0.75)
		_canvas.draw_string(_font, Vector2(r.position.x, y), _text(ROWS[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11,
			col)
