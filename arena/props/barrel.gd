class_name Barrel
extends StaticBody2D
## Baril explosif : encaisse quelques balles puis explose (dégâts en zone, décor creusé) ; tombe si le sol disparaît.

const RADIUS := 58.0
const DAMAGE := 85.0

var hp := 24.0
var _vel := 0.0
var _flash := 0.0
var _done := false


func _ready() -> void:
	collision_layer = Juice.MASK_WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 14)
	shape.shape = rect
	shape.position = Vector2(0, -7)
	add_child(shape)
	add_to_group("barrels")
	z_index = 7


func take_hit(dmg: float, _dir: Vector2, at: Vector2, from: Node2D, _knock: float) -> void:
	if _done:
		return
	hp -= dmg
	_flash = 0.06
	Effects.impact(at, (at - global_position).normalized(), Color(3.0, 1.6, 0.6))
	if hp <= 0.0:
		explode(from)


## `remote` : explosion reçue de l'autre joueur en ligne (le décor arrive à part).
func explode(by: Node2D = null, remote: bool = false) -> void:
	if _done:
		return
	_done = true
	if Juice.net and not remote:
		Juice.net.prop_event(self, "boom")
	var at := global_position + Vector2(0, -7)
	if Juice.net:
		Juice.net.local_only = true
	for f in get_tree().get_nodes_in_group("fighters"):
		if not f.alive:
			continue
		var chest: Vector2 = f.global_position + Vector2(0, -20)
		var d := chest.distance_to(at)
		if d < RADIUS:
			var k := 1.0 - d / RADIUS
			var dir := (chest - at).normalized() if d > 1.0 else Vector2.UP
			f.take_hit(DAMAGE * (0.3 + 0.7 * k), dir, chest - dir * 6.0, by, 300.0 * k + 80.0)
	for b in get_tree().get_nodes_in_group("barrels"):
		if b != self and b.global_position.distance_to(at) < RADIUS * 0.8:
			b.call_deferred("explode", by, remote)
	if Juice.net:
		Juice.net.local_only = false
	if not remote:
		Juice.arena.damage(at, 160.0, RADIUS * 0.5)
	Effects.explosion(at, RADIUS)
	Sfx.play("explosion", at, 4.0, 0.1)
	queue_free()


func _physics_process(delta: float) -> void:
	_flash -= delta
	if Juice.arena.solid_at(global_position + Vector2(0, 1)):
		_vel = 0.0
		return
	_vel = minf(_vel + 900.0 * delta, 500.0)
	global_position.y += _vel * delta
	if global_position.y > Juice.arena.void_y:
		queue_free()


func _draw() -> void:
	var body := Color(0.55, 0.12, 0.1) if _flash <= 0.0 else Color(3, 3, 3)
	draw_rect(Rect2(-5, -14, 10, 14), body)
	draw_rect(Rect2(-5, -11, 10, 1.2), Color(0.25, 0.06, 0.05))
	draw_rect(Rect2(-5, -4, 10, 1.2), Color(0.25, 0.06, 0.05))
	draw_rect(Rect2(-2.5, -9, 5, 3), Color(2.4, 1.8, 0.3))
