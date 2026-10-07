class_name Terrain
extends Node2D
## Décor destructible en cellules de 8 px (sol, plateformes, caisses) : vie par cellule, collisions et rendu par
## tronçons de 16 colonnes reconstruits seulement quand ils changent.

enum K { NONE, DIRT, PLAT, CRATE }

const CELL := 8.0
const CHUNK := 16
const HP := {K.DIRT: 36.0, K.PLAT: 26.0, K.CRATE: 22.0}
const DEBRIS := {K.DIRT: Color(0.38, 0.22, 0.14), K.PLAT: Color(0.45, 0.48, 0.56), K.CRATE: Color(0.5, 0.52, 0.6)}

var kind := {}
var hp := {}
## Cellules par tronçon (index → {cellule: true}) : un tronçon ne parcourt que les siennes.
var by_chunk := {}
var tex := {}
var rim := Color(1.6, 0.75, 0.5)
var _chunks := {}


func clear() -> void:
	kind.clear()
	hp.clear()
	by_chunk.clear()
	for c in _chunks.values():
		c.free()
	_chunks.clear()


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


static func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c) * CELL, Vector2(CELL, CELL))


func fill(r: Rect2, k: int) -> void:
	var a := cell_of(r.position)
	var b := cell_of(r.end - Vector2(0.01, 0.01))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var c := Vector2i(x, y)
			kind[c] = k
			hp[c] = HP[k]
			_chunk_cells(c.x)[c] = true
			_dirty(c.x)


func at(p: Vector2) -> int:
	return kind.get(cell_of(p), K.NONE)


func is_solid_cell(c: Vector2i) -> bool:
	return kind.get(c, K.NONE) != K.NONE


## Dégâts en zone : chaque cellule du rayon perd de la vie (atténuée au bord) ; renvoie le nombre de cellules détruites.
func damage(center: Vector2, dmg: float, radius: float) -> int:
	var broken := 0
	var r := maxf(radius, CELL * 0.5)
	var a := cell_of(center - Vector2(r, r))
	var b := cell_of(center + Vector2(r, r))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var c := Vector2i(x, y)
			if not kind.has(c):
				continue
			var d := cell_rect(c).get_center().distance_to(center)
			if d > r + CELL * 0.5:
				continue
			hp[c] -= dmg * clampf(1.0 - d / (r + CELL), 0.25, 1.0)
			_dirty(x)
			if hp[c] <= 0.0:
				_break(c)
				broken += 1
	return broken


func _break(c: Vector2i) -> void:
	var k: int = kind[c]
	kind.erase(c)
	hp.erase(c)
	_chunk_cells(c.x).erase(c)
	var center := cell_rect(c).get_center()
	for i in 2:
		var v := Vector2(randf_range(-90, 90), randf_range(-220, -60))
		var d = Juice.fx.emit(4, center, v, randf_range(1.0, 2.2), 1.6, DEBRIS[k])
		d.grav = 800.0
		d.spin = randf_range(-25, 25)
	var dust = Juice.fx.emit(2, center, Vector2(randf_range(-20, 20), -15), 0.7, 3.0, Color(DEBRIS[k], 0.35))
	dust.drag = 2.0
	if Juice.stains:
		Juice.stains.erase(cell_rect(c))


func _chunk_cells(cell_x: int) -> Dictionary:
	var cx := floori(float(cell_x) / CHUNK)
	if not by_chunk.has(cx):
		by_chunk[cx] = {}
	return by_chunk[cx]


func _dirty(cell_x: int) -> void:
	var cx := floori(float(cell_x) / CHUNK)
	if not _chunks.has(cx):
		var ch := TerrainChunk.new()
		ch.terrain = self
		ch.index = cx
		_chunks[cx] = ch
		add_child(ch)
	_chunks[cx].dirty = true


## Reconstruit tout de suite les tronçons modifiés (après une génération, avant la première frame physique).
func flush() -> void:
	for ch in _chunks.values():
		if ch.dirty:
			ch.dirty = false
			ch.rebuild()
			ch.queue_redraw()


func redraw_all() -> void:
	for ch in _chunks.values():
		ch.queue_redraw()
