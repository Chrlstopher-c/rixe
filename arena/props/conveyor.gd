class_name Conveyor
extends Node2D
## Tapis roulant (usine) : bloc de machine indestructible dont le dessus entraîne ceux qui s'y tiennent.

var rect := Rect2()
var speed := 70.0
var _t := 0.0


func setup(r: Rect2, s: float) -> void:
	rect = r
	speed = s
	z_index = 1


func _physics_process(delta: float) -> void:
	_t += delta
	for f in get_tree().get_nodes_in_group("fighters"):
		if f.alive and not f.remote and f.is_on_floor() and _on_top(f.global_position):
			f.position.x += speed * delta
	if Juice.on_screen(rect.get_center(), 40.0):
		queue_redraw()


func _on_top(p: Vector2) -> bool:
	return p.x > rect.position.x and p.x < rect.end.x and absf(p.y - rect.position.y) < 3.0


func _draw() -> void:
	var tex: Texture2D = Juice.arena.terrain.tex.get("grate")
	draw_rect(rect, Color(0.08, 0.08, 0.1))
	var belt := Rect2(rect.position, Vector2(rect.size.x, 5))
	if tex:
		draw_texture_rect(tex, belt, true, Color(0.7, 0.7, 0.8))
	var step := 14.0
	var off := fposmod(_t * speed, step)
	var x := rect.position.x + off
	while x < rect.end.x - 4.0:
		var d := signf(speed)
		var y := rect.position.y
		var chevron := PackedVector2Array([Vector2(x - d * 2, y + 1), Vector2(x + d * 1.5, y + 2.5),
			Vector2(x - d * 2, y + 4)])
		draw_polyline(chevron, Color(2.0, 1.6, 0.4, 0.8), 1.0)
		x += step
	for end in [rect.position.x + 4.0, rect.end.x - 4.0]:
		draw_circle(Vector2(end, rect.position.y + rect.size.y * 0.5), 3.5, Color(0.25, 0.25, 0.3))
