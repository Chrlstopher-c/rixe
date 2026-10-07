extends Node2D
## Arène procédurale : murs et roche indestructibles + décor destructible (sol, caisses, plateformes traversables).

const W := 1600.0
const LEVEL_GAP := 74.0
const PLATFORM_H := 8.0
## Épaisseur de sol destructible au-dessus de la roche.
const DIRT_DEPTH := 40.0

var solids: Array[Rect2] = []
var solid_kinds: Array[String] = []
## Plateformes telles que générées (points d'apparition, objets, navigation des bots) ; leur état réel est dans terrain.
var platforms: Array[Rect2] = []
var terrain := Terrain.new()
var _tex := {}
var theme := "crepuscule"
var rim := Color(1.6, 0.75, 0.5)


func _ready() -> void:
	terrain.z_index = 1
	add_child(terrain)
	set_theme(theme)


func set_theme(name: String) -> void:
	theme = name
	rim = Themes.ALL[name].rim
	for n in ["ground", "metal", "bricks"]:
		_tex[n] = Themes.texture(name, n)
	terrain.tex = _tex
	terrain.rim = rim
	terrain.redraw_all()
	queue_redraw()


func generate(seed_value: int) -> void:
	_reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_gen_cover(rng)
	for level in range(1, 4):
		_gen_level(rng, -level * LEVEL_GAP)
	terrain.flush()
	queue_redraw()


func generate_flat() -> void:
	_reset()
	terrain.flush()
	queue_redraw()


func _reset() -> void:
	for c in get_children():
		if c != terrain:
			c.free()
	terrain.clear()
	solids.clear()
	solid_kinds.clear()
	platforms.clear()
	_add_solid(Rect2(-300, DIRT_DEPTH, W + 600, 400), "bedrock")
	_add_solid(Rect2(-300, -700, 300, 700 + DIRT_DEPTH), "wall")
	_add_solid(Rect2(W, -700, 300, 700 + DIRT_DEPTH), "wall")
	terrain.fill(Rect2(0, 0, W, DIRT_DEPTH), Terrain.K.DIRT)


func _gen_cover(rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(3, 5):
		var w := 16.0 * rng.randi_range(2, 3)
		var h := 16.0 * rng.randi_range(1, 2)
		var x := snappedf(rng.randf_range(140, W - 180), 16.0)
		terrain.fill(Rect2(x, -h, w, h), Terrain.K.CRATE)


func _gen_level(rng: RandomNumberGenerator, y: float) -> void:
	var x := snappedf(rng.randf_range(30, 160), 8.0)
	while x < W - 120:
		var w := snappedf(rng.randf_range(80, 200), 8.0)
		var r := Rect2(x, y, minf(w, W - 20 - x), PLATFORM_H)
		platforms.append(r)
		terrain.fill(r, Terrain.K.PLAT)
		x = snappedf(x + w + rng.randf_range(60, 190), 8.0)


func _add_solid(r: Rect2, kind: String) -> void:
	solids.append(r)
	solid_kinds.append(kind)
	var body := StaticBody2D.new()
	body.collision_layer = Juice.MASK_WORLD
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	body.add_child(shape)
	add_child(body)


## Dégâts au décor (impacts, explosions) ; renvoie le nombre de cellules détruites.
func damage(at: Vector2, dmg: float, radius: float) -> int:
	var n := terrain.damage(at, dmg, radius)
	if n > 0:
		queue_redraw()
	return n


func solid_at(p: Vector2) -> bool:
	if terrain.at(p) != Terrain.K.NONE:
		return true
	if p.y < DIRT_DEPTH and p.x >= 0.0 and p.x <= W:
		return false
	for r in solids:
		if r.has_point(p):
			return true
	return false


func push_out(prev: Vector2, p: Vector2) -> Vector2:
	for r in solids:
		if r.has_point(p):
			return _exit_rect(r, p)
	var k := terrain.at(p)
	if k == Terrain.K.NONE:
		return p
	var cell := Terrain.cell_rect(Terrain.cell_of(p))
	if k == Terrain.K.PLAT:
		return Vector2(p.x, cell.position.y - 0.01) if prev.y <= cell.position.y + 1.0 else p
	return _exit_cell(cell, p, prev)


## Sort d'une cellule pleine par le côté libre le plus proche (le dessus en priorité).
func _exit_cell(cell: Rect2, p: Vector2, prev: Vector2) -> Vector2:
	var c := Terrain.cell_of(cell.get_center())
	if not terrain.is_solid_cell(c + Vector2i.UP) or prev.y < cell.position.y:
		return Vector2(p.x, cell.position.y - 0.01)
	if not terrain.is_solid_cell(c + Vector2i.LEFT) and p.x < cell.get_center().x:
		return Vector2(cell.position.x - 0.01, p.y)
	if not terrain.is_solid_cell(c + Vector2i.RIGHT):
		return Vector2(cell.end.x + 0.01, p.y)
	return prev


func _exit_rect(r: Rect2, p: Vector2) -> Vector2:
	var d := [p.y - r.position.y, r.end.y - p.y, p.x - r.position.x, r.end.x - p.x]
	var m: float = d.min()
	if m == d[0]:
		return Vector2(p.x, r.position.y - 0.01)
	if m == d[1]:
		return Vector2(p.x, r.end.y + 0.01)
	if m == d[2]:
		return Vector2(r.position.x - 0.01, p.y)
	return Vector2(r.end.x + 0.01, p.y)


func spawn_points(n: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in n:
		var x := lerpf(120.0, W - 120.0, (i + 0.5) / n) + rng.randf_range(-40, 40)
		out.append(Vector2(x, -60.0))
	return out


func _draw() -> void:
	for r in platforms:
		_draw_strut(r)
	for i in solids.size():
		_draw_solid(solids[i], solid_kinds[i])


## Montants des plateformes, tant que le bout de plateforme qu'ils portent existe.
func _draw_strut(r: Rect2) -> void:
	var c := Color(0.07, 0.04, 0.09)
	for x in [r.position.x + 6.0, r.end.x - 6.0]:
		if terrain.at(Vector2(x, r.position.y + 1.0)) == Terrain.K.PLAT:
			draw_line(Vector2(x, r.end.y), Vector2(x, 0), c, 2.0)


func _draw_solid(r: Rect2, kind: String) -> void:
	match kind:
		"bedrock":
			draw_rect(r, Color(0.045, 0.03, 0.03))
		"wall":
			draw_texture_rect(_tex.bricks, r, true, Color(0.45, 0.4, 0.5))
