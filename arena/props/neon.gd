class_name Neon
extends Node2D
## Enseigne au néon sur les façades (carte Toits) : cadre et motifs lumineux qui grésillent et clignotent parfois.

const PALETTE := [Color(2.6, 0.4, 1.6), Color(0.4, 2.2, 2.6), Color(2.6, 1.6, 0.4), Color(0.6, 2.6, 0.8)]

var size := Vector2(40, 18)
var color := PALETTE[0]
## Motif intérieur : 0 barres, 1 flèche, 2 cercle.
var motif := 0
var _t := 0.0
var _seed := 0.0


func setup(s: Vector2, c: Color, m: int, seed_value: float) -> void:
	size = s
	color = c
	motif = m
	_seed = seed_value
	z_index = 2


func _process(delta: float) -> void:
	_t += delta
	if Juice.on_screen(global_position, 60.0):
		queue_redraw()


## Grésillement : petites baisses rapides et, de temps en temps, une coupure franche.
func _level() -> float:
	var buzz := 0.85 + 0.15 * sin(_t * 47.0 + _seed)
	var cut := fmod(_t * 0.37 + _seed, 7.0) < 0.12
	return 0.15 if cut else buzz


func _draw() -> void:
	var a := _level()
	var col := Color(color * a, 0.95)
	var glow := Color(color * a, 0.12)
	draw_rect(Rect2(-size * 0.5, size).grow(3.0), glow)
	draw_rect(Rect2(-size * 0.5, size), Color(0.02, 0.01, 0.03, 0.9))
	draw_rect(Rect2(-size * 0.5, size), col, false, 1.2)
	match motif:
		0:
			for i in 3:
				var y := -size.y * 0.25 + i * size.y * 0.25
				draw_line(Vector2(-size.x * 0.35, y), Vector2(size.x * (0.35 - i * 0.12), y), col, 1.4)
		1:
			draw_polyline(PackedVector2Array([Vector2(-size.x * 0.3, 0), Vector2(size.x * 0.3, 0),
				Vector2(size.x * 0.12, -size.y * 0.3), Vector2(size.x * 0.3, 0), Vector2(size.x * 0.12, size.y * 0.3)]),
				col, 1.4)
		_:
			draw_arc(Vector2.ZERO, size.y * 0.32, 0.0, TAU, 20, col, 1.4)
