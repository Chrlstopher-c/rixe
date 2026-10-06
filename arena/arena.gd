extends Node2D
## Arène procédurale : sol, murs, caisses de couverture, plateformes traversables ; collisions et rendu texturé.

const W := 1600.0
const LEVEL_GAP := 74.0
const PLATFORM_H := 8.0
const RIM := Color(1.6, 0.75, 0.5)

var solids: Array[Rect2] = []
var solid_kinds: Array[String] = []
var platforms: Array[Rect2] = []
var _tex := {}


func _ready() -> void:
	for n in ["ground", "metal", "bricks"]:
		_tex[n] = load("res://assets/textures/%s.png" % n)


func generate(seed_value: int) -> void:
	for c in get_children():
		c.queue_free()
	solids.clear()
	solid_kinds.clear()
	platforms.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_add_solid(Rect2(-300, 0, W + 600, 400), "ground")
	_add_solid(Rect2(-300, -700, 300, 700), "wall")
	_add_solid(Rect2(W, -700, 300, 700), "wall")
	_gen_cover(rng)
	for level in range(1, 4):
		_gen_level(rng, -level * LEVEL_GAP)
	queue_redraw()


func _gen_cover(rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(3, 5):
		var w := 16.0 * rng.randi_range(2, 3)
		var h := 16.0 * rng.randi_range(1, 2)
		var x := snappedf(rng.randf_range(140, W - 180), 16.0)
		_add_solid(Rect2(x, -h, w, h), "crate")


func _gen_level(rng: RandomNumberGenerator, y: float) -> void:
	var x := rng.randf_range(30, 160)
	while x < W - 120:
		var w := snappedf(rng.randf_range(80, 200), 8.0)
		_add_platform(Rect2(x, y, minf(w, W - 20 - x), PLATFORM_H))
		x += w + rng.randf_range(60, 190)


func _add_solid(r: Rect2, kind: String) -> void:
	solids.append(r)
	solid_kinds.append(kind)
	_body(r, Juice.MASK_WORLD, false)


func _add_platform(r: Rect2) -> void:
	platforms.append(r)
	_body(r, Juice.MASK_PLATFORMS, true).add_to_group("platform")


func _body(r: Rect2, layer_bits: int, one_way: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer_bits
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)
	return body


func solid_at(p: Vector2) -> bool:
	for r in solids:
		if r.has_point(p):
			return true
	for r in platforms:
		if r.has_point(p):
			return true
	return false


func push_out(prev: Vector2, p: Vector2) -> Vector2:
	for r in solids:
		if r.has_point(p):
			return _exit_rect(r, p)
	for r in platforms:
		if r.has_point(p) and prev.y <= r.position.y + 1.0:
			return Vector2(p.x, r.position.y - 0.01)
	return p


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
	for r in platforms:
		_draw_platform(r)


func _draw_strut(r: Rect2) -> void:
	var c := Color(0.07, 0.04, 0.09)
	for x in [r.position.x + 6.0, r.end.x - 6.0]:
		draw_line(Vector2(x, r.end.y), Vector2(x, 0), c, 2.0)
	draw_line(Vector2(r.position.x + 6, r.end.y + 6), Vector2(r.end.x - 6, r.end.y + 6), c, 1.0)


func _draw_solid(r: Rect2, kind: String) -> void:
	match kind:
		"ground":
			draw_texture_rect(_tex.ground, Rect2(r.position, Vector2(r.size.x, 32)), true)
			draw_rect(Rect2(r.position + Vector2(0, 32), r.size - Vector2(0, 32)), Color(0.06, 0.035, 0.03))
			draw_rect(Rect2(r.position + Vector2(0, 26), Vector2(r.size.x, 6)), Color(0, 0, 0, 0.35))
		"wall":
			draw_texture_rect(_tex.bricks, r, true, Color(0.45, 0.4, 0.5))
		_:
			draw_texture_rect(_tex.metal, r, true)
			draw_line(r.position, Vector2(r.end.x, r.position.y), RIM, 1.0)


func _draw_platform(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(2, r.size.y), Vector2(r.size.x - 4, 4)), Color(0, 0, 0, 0.35))
	draw_texture_rect(_tex.metal, r, true)
	draw_line(r.position, Vector2(r.end.x, r.position.y), RIM, 1.0)
