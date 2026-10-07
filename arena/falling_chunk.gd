class_name FallingChunk
extends Node2D
## Morceau de décor détaché : tombe d'un bloc, écrase les combattants en dessous, puis se repose dans la grille
## (ou se brise s'il retombe dans le vide).

const GRAVITY := 900.0

var terrain: Terrain
var cells := {}
var _vel := 0.0
var _hit := {}


## cells : cellule d'origine → type ; le morceau garde sa forme pendant la chute.
func setup(t: Terrain, detached: Dictionary) -> void:
	terrain = t
	cells = detached
	z_index = 2
	add_to_group("falling")


func _physics_process(delta: float) -> void:
	_vel = minf(_vel + GRAVITY * delta, 600.0)
	var step := _vel * delta
	if _blocked(position.y + step):
		_land()
		return
	position.y += step
	_crush()
	if position.y > 900.0:
		queue_free()
	queue_redraw()


## La forme heurterait-elle du décor fixe à ce décalage ?
func _blocked(offset_y: float) -> bool:
	for c: Vector2i in cells:
		if cells.has(c + Vector2i.DOWN):
			continue
		var bottom := Terrain.cell_rect(c).position + Vector2(4.0, 8.0 + offset_y)
		if Juice.arena.solid_at(bottom):
			return true
	return false


func _land() -> void:
	var rows := int(floorf(position.y / Terrain.CELL))
	for c: Vector2i in cells:
		var to := c + Vector2i(0, rows)
		if terrain.is_solid_cell(to):
			continue
		terrain.place(to, cells[c])
	Juice.shake(minf(cells.size() / 60.0, 0.6), global_position + Terrain.cell_rect(cells.keys()[0]).position)
	Sfx.play("impact", Terrain.cell_rect(cells.keys()[0]).position + position, 2.0, 0.2)
	queue_free()


func _crush() -> void:
	var dmg := clampf(cells.size() * 4.0, 15.0, 70.0)
	for f in get_tree().get_nodes_in_group("fighters"):
		if not f.alive or _hit.has(f):
			continue
		var head: Vector2 = f.global_position + Vector2(0, -32)
		for c: Vector2i in cells:
			if Terrain.cell_rect(c).grow(2.0).has_point(head - position):
				_hit[f] = true
				f.take_hit(dmg, Vector2.DOWN, head, null, 120.0)
				break


func _draw() -> void:
	for c: Vector2i in cells:
		var r := Terrain.cell_rect(c)
		var tex: Texture2D = terrain.tex.metal if cells[c] in [Terrain.K.PLAT, Terrain.K.CRATE] else terrain.tex.bricks
		if cells[c] == Terrain.K.CONCRETE:
			tex = terrain.tex.concrete
		elif cells[c] == Terrain.K.GLASS:
			tex = terrain.tex.glass
		var src := Rect2(fposmod(r.position.x, 32.0), fposmod(r.position.y, 32.0), 8, 8)
		draw_texture_rect_region(tex, r, src, Color(0.85, 0.82, 0.88))
