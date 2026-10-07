class_name Minecart
extends Node2D
## Wagonnet de mine : roule sur ses rails d'un butoir à l'autre, marque une pause, repart. Percute et projette ce
## qui se trouve sur la voie ; s'arrête si le sol sous ses roues a été détruit.

const SPEED := 120.0
const PAUSE := 1.4
const DAMAGE := 40.0
const SIZE := Vector2(26, 14)

var from_x := 0.0
var to_x := 0.0
var rail_y := 0.0
var dir := 1.0
var _wait := 0.0
var _cool := {}


func setup(x0: float, x1: float, y: float, phase: float) -> void:
	from_x = x0 + SIZE.x * 0.5
	to_x = x1 - SIZE.x * 0.5
	rail_y = y
	position = Vector2(lerpf(from_x, to_x, phase), y)
	z_index = 3


func _physics_process(delta: float) -> void:
	for k in _cool.keys():
		_cool[k] -= delta
		if _cool[k] <= 0.0:
			_cool.erase(k)
	if _wait > 0.0:
		_wait -= delta
	elif _grounded():
		position.x += dir * SPEED * delta
		if (dir > 0.0 and position.x >= to_x) or (dir < 0.0 and position.x <= from_x):
			position.x = clampf(position.x, from_x, to_x)
			dir = -dir
			_wait = PAUSE
			Sfx.play("land", global_position, -4.0, 0.1)
		_ram()
	if Juice.on_screen(global_position, 300.0):
		queue_redraw()


func _grounded() -> bool:
	return Juice.arena.solid_at(global_position + Vector2(dir * SIZE.x * 0.4, 2.0))


func _ram() -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		var d: Vector2 = f.global_position - global_position
		if f.alive and not _cool.has(f) and absf(d.x) < SIZE.x * 0.5 + 4.0 and d.y > -SIZE.y and d.y < 6.0 \
				and signf(d.x) in [dir, 0.0]:
			_cool[f] = 0.8
			f.take_hit(DAMAGE, Vector2(dir, -0.6).normalized(), f.global_position + Vector2(0, -14), null, 320.0)
			Juice.shake(0.25, global_position)


func _draw() -> void:
	var a := from_x - position.x - SIZE.x * 0.5
	var b := to_x - position.x + SIZE.x * 0.5
	draw_line(Vector2(a, -1), Vector2(b, -1), Color(0.75, 0.7, 0.72), 1.5)
	for i in int((b - a) / 10.0) + 1:
		var x := a + i * 10.0
		draw_line(Vector2(x, 0), Vector2(x + 4, 0), Color(0.3, 0.2, 0.12), 1.5)
	for e in [a, b]:
		draw_rect(Rect2(e - 2, -9, 4, 9), Color(0.5, 0.18, 0.12))
	var w := SIZE.x
	var body := PackedVector2Array([Vector2(-w * 0.5, -SIZE.y), Vector2(w * 0.5, -SIZE.y),
		Vector2(w * 0.4, -4), Vector2(-w * 0.4, -4)])
	draw_colored_polygon(body, Color(0.4, 0.36, 0.38))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(1.3, 0.8, 0.45), 1.0)
	for i in 4:
		draw_circle(Vector2(-8 + i * 5.5, -SIZE.y - 1.0 - (i % 2)), 2.6, Color(0.5, 0.45, 0.5))
	draw_circle(Vector2(-3, -SIZE.y - 2.5), 1.0, Color(2.2, 1.5, 0.4))
	var lamp := Vector2(dir * (w * 0.5 + 1.5), -SIZE.y + 4.0)
	draw_circle(lamp, 7.0, Color(2.0, 1.4, 0.5, 0.12))
	draw_circle(lamp, 1.8, Color(3.0, 2.2, 0.8))
	var spin := position.x / 4.0
	for x in [-7.0, 7.0]:
		draw_circle(Vector2(x, -3), 3.0, Color(0.12, 0.11, 0.13))
		draw_line(Vector2(x, -3), Vector2(x, -3) + Vector2.from_angle(spin) * 2.6, Color(0.5, 0.45, 0.4), 1.0)
