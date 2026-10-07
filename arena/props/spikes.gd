class_name Spikes
extends Area2D
## Pièges à pointes (survie) : blessent et ralentissent les pillards qui marchent dessus.

const DAMAGE := 12.0
const EVERY := 0.5

var _cd := {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = Juice.MASK_FIGHTERS
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)
	add_to_group("spikes")
	z_index = 6


func _physics_process(delta: float) -> void:
	for k in _cd.keys():
		_cd[k] -= delta
	for f in get_overlapping_bodies():
		if f is Fighter and f.alive and not f.is_player and _cd.get(f, 0.0) <= 0.0:
			_cd[f] = EVERY
			f.take_hit(DAMAGE, Vector2.UP, f.global_position + Vector2(0, -2), null, 0.0)
			f.velocity.x *= 0.3


func _draw() -> void:
	for i in 3:
		var x := -3.0 + i * 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1.4, 0), Vector2(x, -6), Vector2(x + 1.4, 0)]),
			Color(0.75, 0.75, 0.8))
