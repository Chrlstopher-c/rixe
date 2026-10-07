class_name Door
extends StaticBody2D
## Porte construite (survie) : le joueur passe, les pillards et leurs balles butent dessus jusqu'à la casser.

var hp := 90.0


func _ready() -> void:
	collision_layer = Juice.MASK_DOORS
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 24)
	shape.shape = rect
	shape.position = Vector2(0, -12)
	add_child(shape)
	add_to_group("doors")
	z_index = 4


func take_hit(dmg: float, _dir: Vector2, at: Vector2, _from: Node2D, _knock: float) -> void:
	hp -= dmg
	Effects.impact(at, Vector2.UP, Color(1.6, 1.2, 0.7))
	if hp <= 0.0:
		for i in 8:
			var v := Vector2(randf_range(-90, 90), randf_range(-200, -60))
			var d = Juice.fx.emit(4, global_position + Vector2(0, -12), v, 1.5, 1.6, Color(0.45, 0.28, 0.14))
			d.grav = 800.0
		Sfx.play("impact", global_position, 0.0, 0.1)
		queue_free()
	queue_redraw()


func _draw() -> void:
	var wood := Color(0.5, 0.3, 0.15).darkened(clampf(1.0 - hp / 90.0, 0.0, 0.5))
	draw_rect(Rect2(-4, -24, 8, 24), wood)
	draw_rect(Rect2(-4, -24, 8, 24), Color(0.22, 0.13, 0.06), false, 1.0)
	draw_circle(Vector2(2, -12), 0.9, Color(1.6, 1.3, 0.6))
