class_name Bush
extends StaticBody2D
## Buisson à baies (survie) : un coup (pied, pioche, lame) cueille de la nourriture ; il repousse au bout d'un moment.

const REGROW := 60.0

var ripe := true
var _t := 0.0


func _ready() -> void:
	collision_layer = Juice.MASK_WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 10)
	shape.shape = rect
	shape.position = Vector2(0, -5)
	add_child(shape)
	add_to_group("bushes")
	z_index = 4


func take_hit(_dmg: float, _dir: Vector2, _at: Vector2, from: Node2D, _knock: float) -> void:
	if not ripe:
		return
	ripe = false
	_t = REGROW
	if is_instance_valid(from) and from.get("is_player") and Juice.survival:
		Juice.survival.add("nourriture", 2)
	for i in 6:
		var b = Juice.fx.emit(4, global_position + Vector2(0, -6), Vector2(randf_range(-60, 60), randf_range(-120, -40)),
			1.0, 1.0, Color(1.8, 0.3, 0.5))
		b.grav = 600.0
	Sfx.play("pickup", global_position, -6.0, 0.2)
	queue_redraw()


func _process(delta: float) -> void:
	if not ripe:
		_t -= delta
		if _t <= 0.0:
			ripe = true
			queue_redraw()


func _draw() -> void:
	var g := Color(0.16, 0.34, 0.15)
	draw_circle(Vector2(-4, -5), 5.0, g)
	draw_circle(Vector2(4, -5), 5.0, g.darkened(0.1))
	draw_circle(Vector2(0, -8), 5.0, g.lightened(0.05))
	if ripe:
		for p in [Vector2(-5, -7), Vector2(3, -9), Vector2(5, -4), Vector2(-1, -4)]:
			draw_circle(p, 1.1, Color(1.8, 0.25, 0.45))
