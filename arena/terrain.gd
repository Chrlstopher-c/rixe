class_name Terrain
extends Node2D
## Décor destructible en cellules de 8 px (sol, plateformes, caisses) : vie par cellule, collisions et rendu par
## tronçons de 16 colonnes reconstruits seulement quand ils changent.

enum K { NONE, DIRT, PLAT, CRATE, ROCK, BRICK, WOOD }

const CELL := 8.0
const CHUNK := 16
const HP := {K.DIRT: 36.0, K.PLAT: 26.0, K.CRATE: 22.0, K.ROCK: 60.0, K.BRICK: 45.0, K.WOOD: 30.0}
const DEBRIS := {K.DIRT: Color(0.38, 0.22, 0.14), K.PLAT: Color(0.45, 0.48, 0.56), K.CRATE: Color(0.5, 0.52, 0.6),
	K.ROCK: Color(0.3, 0.27, 0.3), K.BRICK: Color(0.55, 0.3, 0.28), K.WOOD: Color(0.45, 0.28, 0.14)}
## Ressource rendue par une cellule détruite (survie).
const YIELD := {K.ROCK: "pierre", K.BRICK: "pierre", K.WOOD: "bois", K.CRATE: "metal", K.PLAT: "metal"}

signal cell_broken(c: Vector2i, k: int, by: Variant)

var kind := {}
var hp := {}
## Cellules par tronçon (index → {cellule: true}) : un tronçon ne parcourt que les siennes.
var by_chunk := {}
## Cellules posées par le joueur (survie) : remboursables, cibles des pillards.
var built := {}
## Cellules qui tiennent toutes seules (montants des plateformes) ; le reste doit toucher un appui.
var anchors := {}
## Ligne de surface (rangée de cellule) par colonne au moment de la génération : l'herbe se dessine dessus.
var surface := {}
var tex := {}
var rim := Color(1.6, 0.75, 0.5)
var _chunks := {}


func clear() -> void:
	kind.clear()
	hp.clear()
	by_chunk.clear()
	surface.clear()
	anchors.clear()
	built.clear()
	for c in _chunks.values():
		c.free()
	_chunks.clear()


## Empreinte du décor, identique sur toutes les machines (entiers seulement) : contrôle de synchro en ligne.
func checksum() -> int:
	var h := kind.size()
	for c: Vector2i in kind:
		h = (h + ((c.x * 73856093) ^ (c.y * 19349663) ^ (int(kind[c]) * 83492791))) & 0x3fffffffffffffff
	return h


## Décor complet compressé (cellules et solidité), pour recaler une machine désynchronisée.
func pack_cells() -> Dictionary:
	var xs := PackedInt32Array()
	var ys := PackedInt32Array()
	var ks := PackedByteArray()
	var hs := PackedFloat32Array()
	for c: Vector2i in kind:
		xs.append(c.x)
		ys.append(c.y)
		ks.append(int(kind[c]))
		hs.append(float(hp[c]))
	var raw := var_to_bytes([xs, ys, ks, hs])
	return {"size": raw.size(), "data": raw.compress(FileAccess.COMPRESSION_ZSTD)}


func unpack_cells(pack: Dictionary) -> void:
	var a: Array = bytes_to_var(PackedByteArray(pack.data).decompress(int(pack.size), FileAccess.COMPRESSION_ZSTD))
	for c: Vector2i in kind:
		_dirty(c.x)
	kind.clear()
	hp.clear()
	by_chunk.clear()
	var xs: PackedInt32Array = a[0]
	for i in xs.size():
		var c := Vector2i(xs[i], a[1][i])
		kind[c] = int(a[2][i])
		hp[c] = a[3][i]
		_chunk_cells(c.x)[c] = true
		_dirty(c.x)
	flush()


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
			if k == K.DIRT and y < surface.get(x, 9999):
				surface[x] = y
			_chunk_cells(c.x)[c] = true
			_dirty(c.x)


func at(p: Vector2) -> int:
	return kind.get(cell_of(p), K.NONE)


func is_solid_cell(c: Vector2i) -> bool:
	return kind.get(c, K.NONE) != K.NONE


## Vide une zone (galeries de la mine) sans débris.
func carve(r: Rect2) -> void:
	var a := cell_of(r.position)
	var b := cell_of(r.end - Vector2(0.01, 0.01))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var c := Vector2i(x, y)
			if kind.has(c):
				kind.erase(c)
				hp.erase(c)
				_chunk_cells(x).erase(c)
				_dirty(x)


## Dégâts en zone : chaque cellule du rayon perd de la vie (atténuée au bord) ; renvoie le nombre de cellules détruites.
func damage(center: Vector2, dmg: float, radius: float, by: Variant = null) -> int:
	if not is_instance_valid(by):
		by = null
	var broken := 0
	var touched: Array[Vector2i] = []
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
				cell_broken.emit(c, kind[c], by)
				_break(c)
				broken += 1
				for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					touched.append(c + side)
	if broken > 0:
		_settle(touched)
	return broken


## Remet une cellule (morceau retombé) sans déclencher de débris.
func place(c: Vector2i, k: int) -> void:
	kind[c] = k
	hp[c] = HP[k] * 0.6
	_chunk_cells(c.x)[c] = true
	_dirty(c.x)


## Après une destruction : les morceaux voisins qui ne touchent plus aucun appui se détachent et tombent.
func _settle(seeds: Array[Vector2i]) -> void:
	var seen := {}
	for s in seeds:
		if not kind.has(s) or seen.has(s):
			continue
		var group := _component(s, seen)
		if not group.is_empty():
			_detach(group)


## Composante connexe de s ; vide si elle touche un appui (ou si elle est trop grande pour bouger).
func _component(s: Vector2i, seen: Dictionary) -> Dictionary:
	var group := {}
	var stack: Array[Vector2i] = [s]
	var supported := false
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if group.has(c) or not kind.has(c):
			continue
		group[c] = kind[c]
		seen[c] = true
		if group.size() > 400 or _anchored(c):
			supported = true
			break
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			stack.append(c + d)
	return {} if supported else group


func _anchored(c: Vector2i) -> bool:
	if anchors.has(c):
		return true
	var below := cell_rect(c).get_center() + Vector2(0, CELL)
	return kind.get(c + Vector2i.DOWN, K.NONE) == K.NONE and get_parent().rect_solid_at(below)


func _detach(group: Dictionary) -> void:
	for c: Vector2i in group:
		kind.erase(c)
		hp.erase(c)
		_chunk_cells(c.x).erase(c)
		_dirty(c.x)
	var chunk := FallingChunk.new()
	chunk.setup(self, group)
	get_parent().add_child(chunk)


func _break(c: Vector2i) -> void:
	var k: int = kind[c]
	kind.erase(c)
	hp.erase(c)
	built.erase(c)
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
