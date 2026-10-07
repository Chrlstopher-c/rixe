class_name Grenade
extends Node2D
## Grenade (à main ou tirée) : vole, rebondit sur le décor, explose au retard ou au contact (lance-grenades).
## L'explosion blesse en zone (y compris le lanceur), arrache des membres et creuse le décor.


var vel := Vector2.ZERO
var fuse := 1.7
var impact := false
var dmg := 80.0
var radius := 52.0
var gravity := 700.0
var thrower: Node2D
var _spin := 0.0
var _armed := 0.08
var _t := 0.0


func setup(from: Node2D, v: Vector2, fuse_s: float, on_impact: bool, damage: float, blast: float) -> void:
	thrower = from
	vel = v
	fuse = fuse_s
	impact = on_impact
	dmg = damage
	radius = blast
	z_index = 15
	add_to_group("grenades")


func _physics_process(delta: float) -> void:
	_t += delta
	_armed -= delta
	fuse -= delta
	vel.y += gravity * delta
	_spin += vel.x * delta * 0.2
	var next := global_position + vel * delta
	if Juice.arena.solid_at(next):
		if impact and _armed <= 0.0:
			explode()
			return
		_bounce(next)
	else:
		global_position = next
	if (impact and _armed <= 0.0 and _hits_fighter()) or fuse <= 0.0:
		explode()
		return
	if impact and randf() < 0.6:
		Juice.fx.emit(2, global_position, -vel * 0.05, 0.4, 1.4, Color(0.7, 0.6, 0.6, 0.3))
	queue_redraw()


func _bounce(next: Vector2) -> void:
	var hit_x: bool = Juice.arena.solid_at(Vector2(next.x, global_position.y))
	var hit_y: bool = Juice.arena.solid_at(Vector2(global_position.x, next.y))
	if hit_y or not hit_x:
		vel.y = -vel.y * 0.45
		vel.x *= 0.7
	if hit_x:
		vel.x = -vel.x * 0.5
	if vel.length() > 60.0:
		Sfx.play("tink", global_position, -10.0, 0.2)


func _hits_fighter() -> bool:
	for f in get_tree().get_nodes_in_group("fighters"):
		if f.alive and (f != thrower or _t > 0.3) and global_position.distance_to(f.global_position + Vector2(0, -18)) < 12.0:
			return true
	return false


func explode() -> void:
	var at := global_position
	for f in get_tree().get_nodes_in_group("fighters"):
		if not f.alive:
			continue
		var chest: Vector2 = f.global_position + Vector2(0, -20)
		var d := chest.distance_to(at)
		if d > radius:
			continue
		var k := 1.0 - d / radius
		var dir := (chest - at).normalized() if d > 1.0 else Vector2.UP
		f.take_hit(dmg * (0.35 + 0.65 * k), dir, chest - dir * 6.0, thrower, 260.0 * k + 80.0)
	Juice.arena.damage(at, 140.0, radius * 0.55)
	Effects.explosion(at, radius)
	Sfx.play("explosion", at, 3.0, 0.1)
	queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, _spin)
	draw_circle(Vector2.ZERO, 2.6, Color(0.16, 0.18, 0.14))
	draw_rect(Rect2(-1.0, -3.8, 2.0, 1.4), Color(0.3, 0.3, 0.32))
	var blink := 2.5 if fmod(_t, 0.25 if fuse < 0.6 else 0.5) < 0.1 else 0.6
	draw_circle(Vector2(0.9, -0.9), 0.8, Color(blink, 0.3, 0.2))
	draw_set_transform(Vector2.ZERO)
