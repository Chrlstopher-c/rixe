class_name Lamp
extends StaticBody2D
## Lampe suspendue : éclaire en vacillant ; une balle la décroche, elle tombe, écrase et s'éteint dans une gerbe.

const CRUSH := 35.0

var anchor := Vector2.ZERO
var chain := 24.0
var _falling := false
var _vel := Vector2.ZERO
var _t := 0.0
var _light := PointLight2D.new()
var _dead := false


func setup(ceiling: Vector2, length: float) -> void:
	anchor = ceiling
	chain = length
	position = ceiling + Vector2(0, length)


func _ready() -> void:
	collision_layer = Juice.MASK_WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(7, 6)
	shape.shape = rect
	add_child(shape)
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.gradient = Gradient.new()
	tex.gradient.set_color(1, Color(1, 1, 1, 0))
	_light.texture = tex
	_light.texture_scale = 3.0
	_light.color = Color(1.0, 0.75, 0.45)
	_light.energy = 0.9
	add_child(_light)
	z_index = 7


func take_hit(_dmg: float, dir: Vector2, at: Vector2, _from: Node2D, _knock: float) -> void:
	if _falling or _dead:
		return
	_falling = true
	_vel = dir * 40.0
	Effects.impact(at, -dir, Color(2.4, 1.8, 1.0))
	Sfx.play("tink", at, -2.0, 0.1)


func _physics_process(delta: float) -> void:
	_t += delta
	if _dead:
		return
	if not _falling:
		_light.energy = 0.85 + sin(_t * 23.0) * 0.05 + (0.3 if randf() < 0.01 else 0.0)
		rotation = sin(_t * 1.7) * 0.06
		queue_redraw()
		return
	_vel.y += 900.0 * delta
	position += _vel * delta
	rotation += delta * 4.0
	if Juice.arena.solid_at(global_position + Vector2(0, 4)) or global_position.y > Juice.arena.void_y:
		_shatter()
	queue_redraw()


func _shatter() -> void:
	_dead = true
	_light.energy = 0.0
	for f in get_tree().get_nodes_in_group("fighters"):
		var d: Vector2 = f.global_position - global_position
		if f.alive and absf(d.x) < 12.0 and absf(d.y) < 40.0:
			f.take_hit(CRUSH, Vector2.DOWN, f.global_position + Vector2(0, -30), null, 60.0)
	for i in 10:
		var v := Vector2(randf_range(-160, 160), randf_range(-220, -60))
		var s = Juice.fx.emit(0, global_position, v, randf_range(0.2, 0.5), 0.9, Color(3.0, 2.2, 1.2))
		s.grav = 600.0
	Sfx.play("impact", global_position, 0.0, 0.1)
	queue_free()


func _draw() -> void:
	if not _falling:
		draw_line(to_local(anchor), Vector2(0, -3), Color(0.15, 0.13, 0.16), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(2, -3), Vector2(-2, -3)]),
		Color(0.2, 0.18, 0.22))
	draw_circle(Vector2(0, 1), 1.8, Color(3.0, 2.2, 1.2) if not _dead else Color(0.2, 0.2, 0.2))
