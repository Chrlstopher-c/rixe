class_name Puddles
extends Node2D
## Flaques sous la pluie : posées sur les sols plats du décor, elles reflètent la scène (shader d'écran) et se
## rident sous les gouttes ; une flaque dont le sol est détruit ou recouvert disparaît.

const MAX := 10
const DEPTH := 4.0
const SKIP := [Terrain.K.NONE, Terrain.K.PLAT, Terrain.K.CRATE, Terrain.K.GLASS]

## Flaques : [rangée, première colonne, nombre de colonnes].
var spots: Array[Vector3i] = []
var _rings: Array[Vector3] = []
var _check := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = 12
	material = ShaderMaterial.new()
	material.shader = preload("res://fx/puddle.gdshader")


## Choisit les flaques d'après le décor (tirage déterministe pour une carte donnée).
func build(on: bool) -> void:
	spots.clear()
	_rings.clear()
	if on and Juice.arena:
		var rng := RandomNumberGenerator.new()
		rng.seed = Juice.arena.terrain.checksum()
		var runs := flat_runs(Juice.arena.terrain)
		while not runs.is_empty() and spots.size() < MAX:
			var r: Vector3i = runs.pop_at(rng.randi_range(0, runs.size() - 1))
			var w := rng.randi_range(3, mini(r.z - 1, 9))
			spots.append(Vector3i(r.x, r.y + rng.randi_range(0, r.z - w), w))
	queue_redraw()


## Suites d'au moins 4 colonnes dont la surface est à la même hauteur : [rangée, première colonne, longueur].
static func flat_runs(t: Terrain) -> Array[Vector3i]:
	var tops := {}
	for c: Vector2i in t.kind:
		if not (t.kind[c] in SKIP) and not t.is_solid_cell(c + Vector2i.UP):
			tops[c] = true
	var out: Array[Vector3i] = []
	for c: Vector2i in tops:
		if tops.has(c + Vector2i.LEFT):
			continue
		var n := 1
		while tops.has(c + Vector2i(n, 0)):
			n += 1
		if n >= 4:
			out.append(Vector3i(c.y, c.x, n))
	out.sort()
	return out


func _intact(s: Vector3i, t: Terrain) -> bool:
	for i in s.z:
		var c := Vector2i(s.y + i, s.x)
		if t.kind.get(c, Terrain.K.NONE) in SKIP or t.is_solid_cell(c + Vector2i.UP):
			return false
	return true


func _process(delta: float) -> void:
	if spots.is_empty():
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.3
		var t: Terrain = Juice.arena.terrain
		spots = spots.filter(func(s: Vector3i) -> bool: return _intact(s, t))
	if randf() < 0.5:
		var s := spots[randi() % spots.size()]
		_rings.append(Vector3((s.y + randf_range(0.3, s.z - 0.3)) * Terrain.CELL, s.x * Terrain.CELL + 2.0, 0.0))
	for i in _rings.size():
		_rings[i].z += delta
	_rings = _rings.filter(func(r: Vector3) -> bool: return r.z < 0.45)
	queue_redraw()


func _draw() -> void:
	var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	for s in spots:
		var p := Vector2(s.y, s.x) * Terrain.CELL
		var w := s.z * Terrain.CELL
		var pts := PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w, DEPTH), p + Vector2(0, DEPTH)])
		draw_colored_polygon(pts, Color(1, 1, 1, 0.85), uv)
	for r in _rings:
		var k := r.z / 0.45
		draw_set_transform(Vector2(r.x, r.y), 0.0, Vector2(1.0, 0.3))
		draw_arc(Vector2.ZERO, 1.0 + k * 5.0, 0.0, TAU, 12, Color(0.8, 0.9, 1.2, 0.5 * (1.0 - k)), 1.0)
	draw_set_transform(Vector2.ZERO)
