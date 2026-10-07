class_name WeaponPickup
extends Node2D
## Arme au sol : tombe, rebondit, brille ; un combattant qui passe dessus l'échange contre la sienne,
## ou récupère ses munitions si c'est la même arme.

const GRAB_RADIUS := 16.0
const GRAVITY := 900.0

var weapon_id := "rifle"
var vel := Vector2.ZERO
var immune: Node2D
var immune_t := 0.0
## Munitions portées (-1 = plein).
var mag := -1
var reserve := -1
var _t := 0.0


func setup(id: String, v: Vector2, dropper: Node2D = null, ammo_mag: int = -1, ammo_reserve: int = -1) -> void:
	weapon_id = id
	var d: Dictionary = Arsenal.WEAPONS[id]
	mag = int(d.mag) if ammo_mag < 0 else ammo_mag
	reserve = int(d.reserve) if ammo_reserve < 0 else ammo_reserve
	vel = v
	immune = dropper
	immune_t = 1.5
	z_index = 8
	add_to_group("pickups")


func _physics_process(delta: float) -> void:
	_t += delta
	immune_t -= delta
	vel.y += GRAVITY * delta
	var next := global_position + vel * delta
	if Juice.arena.solid_at(next + Vector2(0, 2)):
		vel = Vector2(vel.x * 0.5, -absf(vel.y) * 0.3) if absf(vel.y) > 60.0 else Vector2(vel.x * 0.8, 0.0)
	else:
		global_position = next
	_try_grab()
	queue_redraw()


func _try_grab() -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		if not f.alive or f.body.arms_left() == 0:
			continue
		var same: bool = f.gun.id == weapon_id
		if same and (f.gun.infinite() or f.gun.reserve >= int(f.gun.def.reserve) * 2 or mag + reserve <= 0):
			continue
		if f == immune and immune_t > 0.0:
			continue
		if f.global_position.distance_to(global_position + Vector2(0, 8)) < GRAB_RADIUS + 10.0:
			if same:
				_take_ammo(f)
			else:
				_swap(f)
			return


func _swap(f: Node2D) -> void:
	var old: Gun = f.gun
	f.gun = Gun.new(f, weapon_id)
	f.gun.mag = mag
	f.gun.reserve = reserve
	Sfx.play("pickup", global_position, -2.0, 0.05)
	Juice.fx.emit(5, global_position, Vector2.ZERO, 0.25, 10.0, Color(2.0, 1.8, 1.4, 0.8))
	setup(old.id, Vector2(-f.facing * 60.0, -160.0), f, old.mag, old.reserve)


func _take_ammo(f: Node2D) -> void:
	f.gun.reserve = mini(f.gun.reserve + mag + reserve, int(f.gun.def.reserve) * 2)
	Sfx.play("pickup", global_position, -4.0, 0.1)
	Juice.fx.emit(5, global_position, Vector2.ZERO, 0.2, 8.0, Color(1.6, 1.6, 1.2, 0.7))
	queue_free()


func _draw() -> void:
	var bob := sin(_t * 3.0) * 1.5
	var col: Color = Arsenal.WEAPONS[weapon_id].tracer
	var beam := Color(col.r, col.g, col.b, 0.0).clamp()
	for i in 6:
		var a := 0.12 * (1.0 - i / 6.0)
		draw_rect(Rect2(-1.5 - i * 0.5, -40 + i * 2, 3 + i, 40 - i * 2), Color(beam, a))
	var d: Dictionary = Arsenal.WEAPONS[weapon_id]
	var L: float = d.length
	draw_set_transform(Vector2(-L * 0.5, -4 + bob), sin(_t * 1.5) * 0.15)
	draw_rect(Rect2(-1.5, -1.8, L + 3, 3.6), col * 0.5)
	draw_rect(Rect2(0, -1.0, L, 2.0), Color(0.13, 0.12, 0.17))
	draw_rect(Rect2(1, -1.0, L - 4, 0.6), col)
	draw_set_transform(Vector2.ZERO)
