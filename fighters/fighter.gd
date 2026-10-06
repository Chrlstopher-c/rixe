class_name Fighter
extends CharacterBody2D
## Combattant : déplacement nerveux (coyote, buffer, double saut, dash), visée, dégâts, mort en ragdoll.

const RUN := 205.0
const ACCEL_GROUND := 2000.0
const ACCEL_AIR := 1300.0
const GRAVITY := 900.0
const JUMP := 390.0
const AIR_JUMP := 350.0
const DASH := 560.0
const DASH_TIME := 0.13
const COYOTE := 0.09
const BUFFER := 0.12
const MAX_HP := 100.0
const SPAWN_SHIELD := 2.5
const PLAYER_DAMAGE_TAKEN := 0.45
const REGEN_DELAY := 3.0
const REGEN_RATE := 12.0

var display_name := "?"
var team_color := Color.WHITE
var is_player := false
var brain: RefCounted
var gun: Gun
var rig: StickRig
var hp := MAX_HP
var alive := true
var aim_dir := Vector2.RIGHT
var facing := 1
var hit_flash := 0.0
var dash_t := 0.0
var recent_hit := 0.0
var shield := SPAWN_SHIELD
var _since_hit := 99.0
var intent := {}
var _air_jumps := 1
var _coyote := 0.0
var _buffer := 0.0
var _dash_cd := 0.0
var _drop_t := 0.0


func setup(nm: String, color: Color, think: RefCounted, weapon_id: String, player: bool) -> void:
	display_name = nm
	team_color = color
	brain = think
	is_player = player
	gun = Gun.new(self, weapon_id)


func _ready() -> void:
	add_to_group("fighters")
	collision_layer = Juice.MASK_FIGHTERS
	collision_mask = Juice.MASK_WORLD | Juice.MASK_PLATFORMS
	floor_snap_length = 4.0
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 6.0
	cap.height = 34.0
	shape.shape = cap
	shape.position = Vector2(0, -17)
	add_child(shape)
	rig = StickRig.new()
	rig.fighter = self
	rig.scale = Vector2.ONE * 1.22
	add_child(rig)
	z_index = 10


func _physics_process(delta: float) -> void:
	if not alive:
		return
	intent = brain.think(self, delta)
	_aim()
	_timers(delta)
	_move(delta)
	_jump()
	_dash()
	var was_floor := is_on_floor()
	var vy := velocity.y
	move_and_slide()
	if not was_floor and is_on_floor():
		_land(vy)
	gun.tick(delta, intent.fire)


func _aim() -> void:
	var target: Vector2 = intent.aim
	var from := global_position + Vector2(0, -27)
	aim_dir = (target - from).normalized() if from.distance_to(target) > 2.0 else aim_dir
	facing = 1 if aim_dir.x >= 0.0 else -1


func _timers(delta: float) -> void:
	hit_flash -= delta
	shield -= delta
	_since_hit += delta
	if is_player and _since_hit > REGEN_DELAY:
		hp = minf(hp + REGEN_RATE * delta, MAX_HP)
	recent_hit -= delta
	_dash_cd -= delta
	_coyote = COYOTE if is_on_floor() else _coyote - delta
	_buffer = BUFFER if intent.jump else _buffer - delta
	_drop_t -= delta
	set_collision_mask_value(3, _drop_t <= 0.0)
	if is_on_floor():
		_air_jumps = 1


func _move(delta: float) -> void:
	if dash_t > 0.0:
		dash_t -= delta
		velocity.y = 0.0
		if int(dash_t * 120.0) % 3 == 0:
			Effects.dust(global_position + Vector2(0, -2), 1, 0.3)
		return
	var goal: float = intent.move * RUN
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	velocity.x = move_toward(velocity.x, goal, accel * delta)
	var g := GRAVITY
	if velocity.y < 0.0 and not intent.jump_held:
		g *= 2.2
	elif velocity.y > 0.0:
		g *= 1.35
	velocity.y = minf(velocity.y + g * delta, 520.0)
	if intent.drop and is_on_floor() and _on_platform():
		_drop_t = 0.22
		position.y += 2.0


func _jump() -> void:
	if _buffer <= 0.0:
		return
	if _coyote > 0.0:
		velocity.y = -JUMP
		Effects.dust(global_position, 5)
	elif _air_jumps > 0:
		_air_jumps -= 1
		velocity.y = -AIR_JUMP
		Juice.fx.emit(5, global_position, Vector2.ZERO, 0.25, 9.0, Color(team_color, 0.8))
	else:
		return
	_buffer = 0.0
	_coyote = 0.0
	rig.stretch()


func _dash() -> void:
	if not intent.dash or _dash_cd > 0.0:
		return
	var dir := Vector2(signf(intent.move) if absf(intent.move) > 0.1 else float(facing), 0)
	velocity = dir * DASH
	dash_t = DASH_TIME
	_dash_cd = 0.55
	Effects.dust(global_position, 6, 1.6)
	if is_player:
		Juice.shake(0.12)


func _land(vy: float) -> void:
	rig.squash(clampf(vy / 520.0, 0.15, 1.0))
	if vy > 250.0:
		Effects.dust(global_position, int(vy / 60.0), 1.3)
		Juice.shake(vy / 4000.0, global_position)


func _on_platform() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c is Node and (c as Node).is_in_group("platform"):
			return true
	return false


func take_hit(dmg: float, dir: Vector2, at: Vector2, from: Node2D, knock: float) -> void:
	if not alive:
		return
	if shield > 0.0:
		Effects.impact(at, -dir, team_color * 2.0)
		return
	if is_player:
		dmg *= PLAYER_DAMAGE_TAKEN
	_since_hit = 0.0
	hp -= dmg
	velocity += dir * knock
	hit_flash = 0.07
	recent_hit = 0.6
	Effects.blood(at, dir, int(3 + dmg * 0.4))
	var player_involved: bool = is_player or (is_instance_valid(from) and from.get("is_player"))
	if player_involved and dmg >= 20.0:
		Juice.hitstop(0.05)
	if is_player:
		Juice.aberration = minf(Juice.aberration + 0.35, 1.5)
		Juice.shake(0.18)
	if hp <= 0.0:
		_die(dir, from, dmg)


func _die(dir: Vector2, killer: Node2D, dmg: float) -> void:
	alive = false
	var body := Ragdoll.new()
	Juice.world.add_child(body)
	var sever := 0 if dmg < 30.0 else randi_range(1, 3)
	body.setup(rig.global_joints(), velocity, dir * (220.0 + dmg * 3.0), sever, team_color)
	var chest := global_position + Vector2(0, -22)
	Effects.blood(chest, dir, 26 + sever * 10)
	Juice.fx.emit(5, chest, Vector2.ZERO, 0.3, 22.0, Color(team_color * 1.5, 0.8))
	Juice.shockwave(chest, 1.0)
	Juice.zoom_punch = 0.1
	Juice.aberration += 0.7
	Juice.shake(0.45, chest)
	if is_player or (is_instance_valid(killer) and killer.get("is_player")):
		Juice.hitstop(0.07)
		Juice.slowmo(0.9, 0.22)
	Juice.fighter_killed.emit(self, killer)
	queue_free()
