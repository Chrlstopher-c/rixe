class_name Builder
extends Node2D
## Construction (survie, touche B) : bloc fantôme sur la grille à la souris, clic gauche pour poser (payé en
## ressources), clic droit pour démonter une construction (moitié remboursée).

const REACH := 150.0
const BLOCKS := [
	{"id": "mur_bois", "name": "Mur de bois", "kind": Terrain.K.WOOD, "cost": {"bois": 2}},
	{"id": "mur_pierre", "name": "Mur de pierre", "kind": Terrain.K.BRICK, "cost": {"pierre": 3}},
	{"id": "plateforme", "name": "Plateforme", "kind": Terrain.K.PLAT, "cost": {"bois": 1}},
	{"id": "porte", "name": "Porte", "prop": "door", "cost": {"bois": 4}},
	{"id": "pointes", "name": "Pointes", "prop": "spikes", "cost": {"metal": 2}},
]

var active := false
var selected := 0
var survival: Survival
var player: Node2D
var _cell := Vector2i.ZERO
var _ok := false


func _ready() -> void:
	z_index = 30


func toggle() -> void:
	active = not active
	queue_redraw()


func select(i: int) -> void:
	selected = posmod(i, BLOCKS.size())


func _process(_delta: float) -> void:
	if not active or not is_instance_valid(player):
		return
	var mouse := get_global_mouse_position()
	_cell = Terrain.cell_of(mouse)
	_ok = can_place(_cell)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active or not (event is InputEventMouseButton) or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			place(Terrain.cell_of(get_global_mouse_position()))
		MOUSE_BUTTON_RIGHT:
			remove(Terrain.cell_of(get_global_mouse_position()))
		MOUSE_BUTTON_WHEEL_UP:
			select(selected - 1)
		MOUSE_BUTTON_WHEEL_DOWN:
			select(selected + 1)
		_:
			return
	get_viewport().set_input_as_handled()


func can_place(c: Vector2i) -> bool:
	var center := Terrain.cell_rect(c).get_center()
	if Juice.arena.solid_at(center) or center.distance_to(player.global_position + Vector2(0, -18)) > REACH:
		return false
	for f in get_tree().get_nodes_in_group("fighters"):
		if f.alive and Rect2(f.global_position - Vector2(7, 36), Vector2(14, 36)).intersects(Terrain.cell_rect(c)):
			return false
	return survival.can_afford(BLOCKS[selected].cost)


func place(c: Vector2i) -> bool:
	if not can_place(c):
		return false
	var b: Dictionary = BLOCKS[selected]
	survival.spend(b.cost)
	var t: Terrain = Juice.arena.terrain
	if b.has("kind"):
		t.place(c, b.kind)
		t.hp[c] = Terrain.HP[b.kind]
		t.built[c] = b.id
	else:
		var prop: Node2D = Door.new() if b.prop == "door" else Spikes.new()
		prop.position = Terrain.cell_rect(c).position + Vector2(4, 8)
		prop.set_meta("block", b.id)
		Juice.arena.add_child(prop)
	Sfx.play("reload_in", Terrain.cell_rect(c).get_center(), -4.0, 0.15)
	return true


func remove(c: Vector2i) -> bool:
	var t: Terrain = Juice.arena.terrain
	if not t.built.has(c):
		return false
	var b := _block(t.built[c])
	t.carve(Terrain.cell_rect(c))
	t.built.erase(c)
	for k in b.cost:
		survival.add(k, int(b.cost[k]) / 2)
	return true


static func _block(id: String) -> Dictionary:
	for b in BLOCKS:
		if b.id == id:
			return b
	return BLOCKS[0]


func _draw() -> void:
	if not active:
		return
	var r := Terrain.cell_rect(_cell)
	var col := Color(0.4, 1.8, 0.8, 0.45) if _ok else Color(1.8, 0.4, 0.4, 0.45)
	draw_rect(r, col)
	draw_rect(r, Color(col, 0.9), false, 1.0)
	if is_instance_valid(player):
		draw_arc(player.global_position + Vector2(0, -18), REACH, 0.0, TAU, 64, Color(1, 1, 1, 0.08), 1.0)
