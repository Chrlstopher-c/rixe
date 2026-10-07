extends CanvasLayer
## Éditeur de cartes : peindre le décor cellule par cellule (clic gauche), effacer (clic droit), choisir la matière
## (molette ou 1 à 8), la taille du pinceau (+ / -), déplacer la vue (ZQSD), enregistrer (Entrée), essayer la carte
## (F5), charger une autre carte (Tab), revenir (Échap). Les cartes servent ensuite en partie perso et en ligne.

signal back_requested

const MATERIALS := [
	["TERRE", Terrain.K.DIRT, Color(0.45, 0.3, 0.2)], ["BÉTON", Terrain.K.CONCRETE, Color(0.5, 0.5, 0.55)],
	["BRIQUE", Terrain.K.BRICK, Color(0.6, 0.35, 0.3)], ["ROCHE", Terrain.K.ROCK, Color(0.35, 0.32, 0.36)],
	["BOIS", Terrain.K.WOOD, Color(0.5, 0.32, 0.16)], ["VERRE", Terrain.K.GLASS, Color(0.6, 0.85, 1.0)],
	["PLATEFORME", Terrain.K.PLAT, Color(0.5, 0.6, 0.75)], ["CAISSE", Terrain.K.CRATE, Color(0.55, 0.57, 0.65)],
]
const CAM_SPEED := 320.0

var main: Node
var active := false
var map_name := ""
var material := 0
var brush := 1
var _canvas := Control.new()
var _font: Font = ThemeDB.fallback_font
var _status := ""
var _status_t := 0.0


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_ui)
	add_child(_canvas)
	visible = false


## Ouvre l'éditeur sur une carte existante, ou une nouvelle carte (sol de terre).
func open(name: String = "") -> void:
	active = true
	visible = true
	main._menu.close()
	main._clear_world()
	main._hud.visible = false
	map_name = name if name != "" else MapStore.fresh_name()
	if name != "" and MapStore.names().has(name):
		Juice.arena.generate(0, MapStore.PREFIX + name)
	else:
		Juice.arena.generate_flat()
	main._camera.target = null
	main._camera.snap_to(Vector2(Juice.arena.W * 0.5, -100))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	active = false
	visible = false


func _process(delta: float) -> void:
	if not active:
		return
	var real: float = Juice.real_delta(delta)
	var move := Vector2(Input.get_axis("left", "right"), Input.get_axis("jump", "down"))
	main._camera.global_position += move * CAM_SPEED * real
	var mouse: Vector2 = main.get_global_mouse_position()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		paint(mouse, false)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		paint(mouse, true)
	_status_t -= real
	_canvas.queue_redraw()


## Pinceau carré (1 à 3 cellules) : pose la matière choisie, ou efface.
func paint(at: Vector2, erase: bool) -> void:
	var t: Terrain = Juice.arena.terrain
	var c0 := Terrain.cell_of(at)
	for dx in range(-(brush - 1), brush):
		for dy in range(-(brush - 1), brush):
			var c := c0 + Vector2i(dx, dy)
			var cols := int(Juice.arena.W / Terrain.CELL)
			if c.x < 0 or c.x >= cols or c.y < -60 or c.y >= int(Juice.arena.DIRT_DEPTH / Terrain.CELL):
				continue
			if erase:
				t.remove(c)
			elif t.kind.get(c, Terrain.K.NONE) != MATERIALS[material][1]:
				t.place(c, MATERIALS[material][1], true)


func save() -> bool:
	var ok := MapStore.save(map_name, Juice.arena.terrain.kind)
	_status = "Enregistrée : %s" % map_name if ok else "Enregistrement impossible"
	_status_t = 2.5
	return ok


## Essai : enregistre puis lance une partie perso (arcade) sur la carte.
func try_map() -> void:
	if not save():
		return
	close()
	var cfg := GameConfig.new()
	cfg.custom = true
	cfg.map = MapStore.PREFIX + map_name
	main.start_custom(cfg)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			material = posmod(material - 1, MATERIALS.size())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			material = posmod(material + 1, MATERIALS.size())
	var k := Controls.menu_key(event)
	if k >= KEY_1 and k <= KEY_8:
		material = k - KEY_1
	match k:
		KEY_EQUAL, KEY_KP_ADD:
			brush = mini(brush + 1, 3)
		KEY_MINUS, KEY_KP_SUBTRACT:
			brush = maxi(brush - 1, 1)
		KEY_ENTER, KEY_KP_ENTER:
			save()
		KEY_F5:
			try_map()
		KEY_TAB:
			_next_map()
		KEY_ESCAPE:
			close()
			back_requested.emit()
		_:
			if not (k >= KEY_1 and k <= KEY_8):
				return
	get_viewport().set_input_as_handled()


func _next_map() -> void:
	var list := MapStore.names()
	if list.is_empty():
		return
	open(list[(list.find(map_name) + 1) % list.size()])


func _draw_ui() -> void:
	var s := _canvas.size
	var xf: Transform2D = _canvas.get_viewport().get_canvas_transform()
	var mouse: Vector2 = main.get_global_mouse_position()
	var c0 := Terrain.cell_of(mouse) - Vector2i(brush - 1, brush - 1)
	var side := Vector2(2 * brush - 1, 2 * brush - 1) * Terrain.CELL * xf.get_scale()
	var r := Rect2(xf * Vector2(c0 * Terrain.CELL), side)
	_canvas.draw_rect(r, Color(MATERIALS[material][2] * 1.6, 0.9), false, 1.0)
	_canvas.draw_rect(Rect2(0, 0, s.x, 20), Color(0, 0, 0, 0.6))
	_canvas.draw_string(_font, Vector2(10, 13), "ÉDITEUR  ·  %s  ·  pinceau %d" % [map_name.to_upper(), brush],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 1.8, 2.0))
	for i in MATERIALS.size():
		var box := Rect2(10 + i * 76, s.y - 40, 70, 16)
		var on := i == material
		_canvas.draw_rect(box, Color(MATERIALS[i][2], 0.9 if on else 0.45))
		_canvas.draw_rect(box, Color(2, 2, 2, 0.9) if on else Color(0, 0, 0, 0.6), false, 1.0)
		_canvas.draw_string(_font, box.position + Vector2(0, 11), "%d %s" % [i + 1, MATERIALS[i][0]],
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 7, Color(1, 1, 1, 0.95))
	var help := "clic gauche peindre · clic droit effacer · ZQSD vue · + - pinceau · Entrée enregistrer · " \
		+ "F5 essayer · Tab carte suivante · Échap"
	_canvas.draw_string(_font, Vector2(0, s.y - 10), help, HORIZONTAL_ALIGNMENT_CENTER, s.x, 7,
		Color(1, 0.95, 0.95, 0.65))
	if _status_t > 0.0:
		_canvas.draw_string(_font, Vector2(0, 36), _status, HORIZONTAL_ALIGNMENT_CENTER, s.x, 10,
			Color(0.6, 2.0, 0.9))
