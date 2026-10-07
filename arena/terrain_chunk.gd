class_name TerrainChunk
extends Node2D
## Tronçon de 16 colonnes du décor destructible : ses corps de collision (pleins / traversables), ses occulteurs
## de lumière (les éclairs des tirs et des explosions projettent des ombres) et son rendu.

var terrain: Terrain
var index := 0
var dirty := true
var _solid := StaticBody2D.new()
var _plat := StaticBody2D.new()
var _occluders := Node2D.new()


func _ready() -> void:
	_solid.collision_layer = Juice.MASK_WORLD
	_solid.collision_mask = 0
	_plat.collision_layer = Juice.MASK_PLATFORMS
	_plat.collision_mask = 0
	_plat.add_to_group("platform")
	add_child(_solid)
	add_child(_plat)
	add_child(_occluders)


func _physics_process(_delta: float) -> void:
	if dirty:
		dirty = false
		rebuild()
		queue_redraw()


func _columns() -> Array[int]:
	return [index * Terrain.CHUNK, (index + 1) * Terrain.CHUNK]


## Collisions : une forme par suite horizontale de cellules de même famille (pleine ou traversable).
func rebuild() -> void:
	for body in [_solid, _plat, _occluders]:
		for s in body.get_children():
			s.free()
	var rows := {}
	for c: Vector2i in terrain.by_chunk.get(index, {}):
		rows[c.y] = true
	for y: int in rows:
		_runs(y)


func _runs(y: int) -> void:
	var start := -1
	var fam := 0
	var end := _columns()[1]
	for x in range(_columns()[0], end + 1):
		var k: int = terrain.kind.get(Vector2i(x, y), Terrain.K.NONE) if x < end else Terrain.K.NONE
		var f := 0 if k == Terrain.K.NONE else (2 if k == Terrain.K.PLAT else 1)
		if f != fam:
			if fam != 0:
				_shape(start, x, y, fam == 2)
			start = x
			fam = f


func _shape(x0: int, x1: int, y: int, one_way: bool) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2((x1 - x0) * Terrain.CELL, Terrain.CELL)
	shape.shape = rect
	shape.position = Vector2((x0 + x1) * 0.5 * Terrain.CELL, (y + 0.5) * Terrain.CELL)
	shape.one_way_collision = one_way
	(_plat if one_way else _solid).add_child(shape)
	if not one_way and _edge_row(x0, x1, y):
		_occluders.add_child(Shadows.occluder(Rect2(Vector2(x0, y) * Terrain.CELL,
			Vector2(x1 - x0, 1) * Terrain.CELL)))


## Une suite de cellules touche-t-elle du vide au-dessus ou en dessous ? (seuls les bords projettent des ombres)
func _edge_row(x0: int, x1: int, y: int) -> bool:
	for x in range(x0, x1):
		if not terrain.is_solid_cell(Vector2i(x, y - 1)) or not terrain.is_solid_cell(Vector2i(x, y + 1)):
			return true
	return false


func _draw() -> void:
	for c: Vector2i in terrain.by_chunk.get(index, {}):
		_draw_cell(c, terrain.kind[c])


func _draw_cell(c: Vector2i, k: int) -> void:
	var r := Terrain.cell_rect(c)
	var wear: float = 1.0 - terrain.hp[c] / float(Terrain.HP[k])
	var mod := Color(1, 1, 1).darkened(wear * 0.45)
	var open_top := not terrain.is_solid_cell(c + Vector2i.UP)
	match k:
		Terrain.K.ROCK, Terrain.K.BRICK:
			var src := Rect2(fposmod(r.position.x, 32.0), fposmod(r.position.y, 32.0), 8, 8)
			var tint := Color(0.42, 0.38, 0.45) if k == Terrain.K.ROCK else Color(0.75, 0.7, 0.75)
			draw_texture_rect_region(terrain.tex.bricks, r, src, mod * tint)
			if open_top:
				draw_line(r.position, Vector2(r.end.x, r.position.y), terrain.rim * 0.6, 1.0)
		Terrain.K.WOOD:
			var plank := Color(0.42, 0.26, 0.13).darkened(wear * 0.4)
			draw_rect(r, plank)
			draw_line(r.position + Vector2(2.5, 0), r.position + Vector2(2.5, 8), plank.darkened(0.35), 1.0)
			if terrain.built.has(c):
				draw_rect(r, Color(0.25, 0.15, 0.08), false, 1.0)
		Terrain.K.GLASS:
			var src := Rect2(fposmod(r.position.x, 32.0), fposmod(r.position.y, 32.0), 8, 8)
			draw_texture_rect_region(terrain.tex.glass, r, src, mod)
		Terrain.K.CONCRETE:
			var src := Rect2(fposmod(r.position.x, 32.0), fposmod(r.position.y, 32.0), 8, 8)
			draw_texture_rect_region(terrain.tex.concrete, r, src, mod * Color(0.85, 0.85, 0.9))
			if open_top:
				draw_line(r.position, Vector2(r.end.x, r.position.y), terrain.rim * 0.5, 1.0)
		Terrain.K.DIRT:
			var depth: int = c.y - int(terrain.surface.get(c.x, c.y))
			if depth <= 3:
				var src := Rect2(fposmod(r.position.x, 64.0), depth * 8.0, 8, 8)
				draw_texture_rect_region(terrain.tex.ground, r, src, mod)
			else:
				draw_rect(r, Color(0.06, 0.035, 0.03).darkened(wear * 0.3))
			if open_top and depth > 0:
				draw_line(r.position, Vector2(r.end.x, r.position.y), Color(0, 0, 0, 0.35), 1.0)
		_:
			var src := Rect2(fposmod(r.position.x, 32.0), fposmod(r.position.y, 32.0), 8, 8)
			draw_texture_rect_region(terrain.tex.metal, r, src, mod)
			if open_top:
				draw_line(r.position, Vector2(r.end.x, r.position.y), terrain.rim, 1.0)
	if wear > 0.35:
		draw_line(r.position + Vector2(2, 2), r.end - Vector2(3, 2), Color(0, 0, 0, wear * 0.6), 1.0)
