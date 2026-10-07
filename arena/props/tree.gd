class_name WildTree
extends Node2D
## Arbre : un tronc en cellules de bois (destructible, il tombe si on le coupe à la base) et un feuillage dessiné
## qui s'envole en feuilles quand le haut du tronc disparaît.

var top_cell := Vector2i.ZERO
var crown := 18.0
var tint := Color(0.2, 0.42, 0.18)
var _alive := true
var _sway := 0.0


func setup(base: Vector2, height: int, rng: RandomNumberGenerator) -> void:
	var t: Terrain = Juice.arena.terrain
	var base_cell := Terrain.cell_of(base)
	for i in height:
		var c := base_cell - Vector2i(0, i + 1)
		t.fill(Terrain.cell_rect(c), Terrain.K.WOOD)
	top_cell = base_cell - Vector2i(0, height)
	crown = rng.randf_range(14.0, 22.0)
	tint = Color(0.16, 0.36, 0.16).lerp(Color(0.32, 0.4, 0.14), rng.randf())
	_sway = rng.randf() * TAU
	position = Terrain.cell_rect(top_cell).get_center()
	z_index = 3
	add_to_group("trees")


func _process(delta: float) -> void:
	_sway += delta
	if not _alive:
		return
	if not Juice.arena.terrain.is_solid_cell(top_cell):
		_alive = false
		for i in 24:
			var v := Vector2(randf_range(-80, 80), randf_range(-140, -20))
			var leaf = Juice.fx.emit(4, global_position + Vector2(randf_range(-crown, crown), randf_range(-crown, 4)),
				v, randf_range(1.0, 2.0), 1.2, tint * 1.4)
			leaf.grav = 200.0
			leaf.spin = randf_range(-10, 10)
		queue_free()
		return
	if Juice.on_screen(global_position, 60.0):
		queue_redraw()


func _draw() -> void:
	var dx := sin(_sway * 0.9) * 1.2 + Juice.wind * 0.02
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var p := Vector2(cos(a) * crown * 0.55 + dx, sin(a) * crown * 0.35 - crown * 0.5)
		draw_circle(p, crown * 0.62, tint.darkened(0.15 + 0.1 * (i % 2)))
	draw_circle(Vector2(dx, -crown * 0.8), crown * 0.6, tint.lightened(0.08))
