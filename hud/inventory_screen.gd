extends CanvasLayer
## Écran d'inventaire (Tab) : deux armes et leurs emplacements, sac d'accessoires, soins et grenades.
## Clic sur un accessoire du sac puis sur une arme pour le monter ; clic sur un accessoire monté pour le ranger.

signal close_requested

const ACCENT := Color(0.3, 0.9, 1.0)
const SLOT_NAMES := {"optic": "Viseur", "mag": "Chargeur", "barrel": "Canon", "stock": "Crosse"}

var fighter: Node2D
var _canvas := Control.new()
var _font: Font = ThemeDB.fallback_font
var _picked := -1
var _hot: Array[Dictionary] = []


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_screen)
	_canvas.gui_input.connect(_on_input)
	add_child(_canvas)
	visible = false


func open(f: Node2D) -> void:
	fighter = f
	_picked = -1
	visible = true


func close() -> void:
	visible = false


func _process(_delta: float) -> void:
	if visible:
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_TAB, KEY_ESCAPE:
			close_requested.emit()
		KEY_1:
			fighter.inventory.select(0)
		KEY_2:
			fighter.inventory.select(1)
		_:
			return
	get_viewport().set_input_as_handled()


func _on_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for h in _hot:
		if (h.rect as Rect2).has_point(event.position):
			click(h)
			return


## Action sur une zone cliquable : choisir dans le sac, monter sur une arme, ranger un accessoire, prendre en main.
func click(h: Dictionary) -> void:
	var inv: Inventory = fighter.inventory
	match h.kind:
		"bag":
			_picked = h.index if _picked != h.index else -1
		"weapon":
			if _picked >= 0:
				inv.mount(_picked, h.index)
				_picked = -1
			else:
				inv.select(h.index)
		"slot":
			if _picked >= 0:
				inv.mount(_picked, h.index)
				_picked = -1
			else:
				inv.unmount(h.index, h.slot)
	Sfx.play_ui("reload_in", -8.0)


func _draw_screen() -> void:
	_hot.clear()
	if not is_instance_valid(fighter):
		return
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04, 0.9))
	_canvas.draw_string(_font, Vector2(0, 40), "INVENTAIRE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1.6, 1.5, 1.5))
	var inv: Inventory = fighter.inventory
	for w in inv.guns.size():
		_draw_weapon(inv, w, Rect2(70 + w * 260, 64, 240, 130))
	_draw_bag(inv, Rect2(70, 210, 500, 46))
	var extra := "Soins : %d (H)   ·   Grenades : %d (G)" % [inv.medkits, fighter.grenades]
	_canvas.draw_string(_font, Vector2(0, 286), extra, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color(1, 0.92, 0.95, 0.8))
	var help := "Clic sur un accessoire du sac puis sur une arme pour le monter · clic sur un monté pour le ranger"
	_canvas.draw_string(_font, Vector2(0, size.y - 30), help, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8,
		Color(1, 0.9, 0.95, 0.55))
	_canvas.draw_string(_font, Vector2(0, size.y - 16), "Tab ou Échap : fermer · 1 / 2 : arme en main",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(1, 0.9, 0.95, 0.55))


func _draw_weapon(inv: Inventory, w: int, box: Rect2) -> void:
	var g: Gun = inv.guns[w]
	var on := w == inv.active
	_canvas.draw_rect(box, Color(0.05, 0.04, 0.09, 0.9))
	_canvas.draw_rect(box, Color(ACCENT, 0.9 if on else 0.25), false, 1.0)
	_hot.append({"kind": "weapon", "index": w, "rect": Rect2(box.position, Vector2(box.size.x, 30))})
	var title := "%d · %s%s" % [w + 1, String(g.def.name).to_upper(), "  (EN MAIN)" if on else ""]
	_canvas.draw_string(_font, box.position + Vector2(10, 20), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(ACCENT * 1.6) if on else Color(1, 0.92, 0.95, 0.85))
	var ammo := "∞" if g.infinite() else "%d / %d" % [g.mag, g.reserve]
	_canvas.draw_string(_font, box.position + Vector2(0, 20), ammo, HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - 10, 10,
		Color(1, 0.92, 0.95, 0.7))
	if not Arsenal.accepts(g.id):
		_canvas.draw_string(_font, box.position + Vector2(10, 60), "Pas d'accessoire sur une lame", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 9, Color(1, 0.9, 0.95, 0.5))
		return
	for i in Arsenal.SLOTS.size():
		var slot: String = Arsenal.SLOTS[i]
		var r := Rect2(box.position + Vector2(10, 36 + i * 22), Vector2(box.size.x - 20, 18))
		var att: String = g.attachments.get(slot, "")
		_canvas.draw_rect(r, Color(0.3, 0.9, 0.5, 0.22) if att != "" else Color(1, 1, 1, 0.04))
		var label := "%s : %s" % [SLOT_NAMES[slot], "—" if att == "" else String(Arsenal.ATTACHMENTS[att].name)]
		_canvas.draw_string(_font, r.position + Vector2(6, 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.6, 1.8, 0.9) if att != "" else Color(1, 0.9, 0.95, 0.5))
		_hot.append({"kind": "slot", "index": w, "slot": slot, "rect": r})


func _draw_bag(inv: Inventory, box: Rect2) -> void:
	_canvas.draw_string(_font, box.position + Vector2(0, -4), "SAC", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(1, 0.9, 0.95, 0.6))
	for i in Inventory.BAG:
		var r := Rect2(box.position + Vector2(i * 126, 4), Vector2(118, 36))
		var has := i < inv.bag.size()
		var sel := i == _picked
		_canvas.draw_rect(r, Color(ACCENT, 0.25) if sel else Color(1, 1, 1, 0.05))
		_canvas.draw_rect(r, Color(ACCENT, 0.8 if sel else 0.2), false, 1.0)
		if has:
			var name := String(Arsenal.ATTACHMENTS[inv.bag[i]].name)
			_canvas.draw_string(_font, r.position + Vector2(0, 22), name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9,
				Color(0.6, 1.8, 0.9))
			_hot.append({"kind": "bag", "index": i, "rect": r})
