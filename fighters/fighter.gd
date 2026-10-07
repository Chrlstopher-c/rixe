class_name Fighter
extends CharacterBody2D
## Combattant : déplacement nerveux (coyote, buffer, double saut, dash), visée, dégâts, mort en ragdoll.

signal jumped(in_air: bool)

const RUN := 205.0
const ACCEL_GROUND := 2000.0
const ACCEL_AIR := 1300.0
const GRAVITY := 900.0
const JUMP := 390.0
const AIR_JUMP := 350.0
const DASH := 560.0
const DASH_TIME := 0.13
const COYOTE := 0.09
const BUFFER := 0.2
const AIR_JUMPS := 2
const MAX_HP := 100.0
const SPAWN_SHIELD := 2.5
const PLAYER_DAMAGE_TAKEN := 0.45
const REGEN_DELAY := 3.0
const REGEN_RATE := 12.0

var display_name := "?"
## Équipe ("" = chacun pour soi) : les bots d'une même équipe ne se visent pas.
var team := ""
var team_color := Color.WHITE
var is_player := false
var brain: RefCounted
var gun: Gun
var inventory: Inventory
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
## Visée précise (clic droit) : dispersion et remontée réduites, déplacement ralenti, caméra qui glisse.
var aiming := false
var grenades := Arsenal.GRENADES
var _throw_cd := 0.0
var aim_point := Vector2.ZERO
var body := BodyParts.new()
var melee := Melee.new(self)
var last_zone := ""
var death_cause := ""
var _spurt := {}
var _air_jumps := AIR_JUMPS
var _coyote := 0.0
var _buffer := 0.0
var _dash_cd := 0.0
var _drop_t := 0.0


func setup(nm: String, color: Color, think: RefCounted, weapon_id: String, player: bool, mods: Dictionary = {}) -> void:
	display_name = nm
	team_color = color
	brain = think
	is_player = player
	gun = Gun.new(self, weapon_id, mods)
	inventory = Inventory.new(self, gun)


func _ready() -> void:
	add_to_group("fighters")
	collision_layer = Juice.MASK_FIGHTERS
	collision_mask = Juice.MASK_WORLD | Juice.MASK_PLATFORMS | (0 if is_player else Juice.MASK_DOORS)
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
	if global_position.y > Juice.arena.void_y:
		death_cause = "fall"
		hp = 0.0
		_die(Vector2.DOWN, null, 0.0)
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
	_step_up()
	if not was_floor and is_on_floor():
		_land(vy)
	melee.tick(delta, intent.get("melee", false))
	_throw_cd -= delta
	if intent.get("throw", false):
		throw_grenade()
	_inventory_input(delta)
	var can_fire: bool = body.arms_left() > 0 and not melee.active() and inventory.switching <= 0.0
	gun.tick(delta, intent.fire and can_fire, intent.get("reload", false))
	_bleed_stumps(delta)


func _aim() -> void:
	var target: Vector2 = intent.aim
	aim_point = target
	aiming = intent.get("aiming", false) and dash_t <= 0.0
	var from := global_position + Vector2(0, -27)
	aim_dir = (target - from).normalized() if from.distance_to(target) > 2.0 else aim_dir
	facing = 1 if aim_dir.x >= 0.0 else -1


func _timers(delta: float) -> void:
	hit_flash -= delta
	shield -= delta
	if is_player and (brain is PlayerBrain or brain is PadBrain):
		var low := clampf(1.0 - hp / 45.0, 0.0, 1.0) * 0.45
		Juice.hurt = maxf(move_toward(Juice.hurt, 0.0, delta * 1.2), low)
	_since_hit += delta
	var fed: bool = Juice.survival == null or Juice.survival.hunger > 30.0
	if _since_hit > REGEN_DELAY and hp < MAX_HP and fed:
		hp = minf(hp + REGEN_RATE * delta * (1.0 if is_player else 0.6), MAX_HP)
	recent_hit -= delta
	_dash_cd -= delta
	_coyote = COYOTE if is_on_floor() else _coyote - delta
	var rehop: bool = intent.jump_held and is_on_floor() and velocity.y >= 0.0
	_buffer = BUFFER if intent.jump or rehop else _buffer - delta
	_drop_t -= delta
	set_collision_mask_value(3, _drop_t <= 0.0)
	if is_on_floor():
		_air_jumps = AIR_JUMPS


func _move(delta: float) -> void:
	if dash_t > 0.0:
		dash_t -= delta
		velocity.y = 0.0
		if int(dash_t * 120.0) % 3 == 0:
			Effects.dust(global_position + Vector2(0, -2), 1, 0.3)
		return
	var goal: float = intent.move * RUN * leg_factor() * (0.6 if aiming else 1.0)
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
		velocity.y = -JUMP * sqrt(leg_factor())
		Effects.dust(global_position, 5)
		jumped.emit(false)
		Sfx.play("jump", global_position, -6.0)
	elif _air_jumps > 0:
		_air_jumps -= 1
		velocity.y = -AIR_JUMP
		jumped.emit(true)
		Sfx.play("air_jump", global_position, -5.0)
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
	Sfx.play("dash", global_position, -4.0)
	if is_player:
		Juice.shake(0.12)


## Monte seul une marche d'une cellule de décor (bords de cratères, caisses entamées).
func _step_up() -> void:
	if not (is_on_floor() and is_on_wall()) or absf(intent.move) < 0.1:
		return
	var dir := signf(intent.move)
	var up := global_transform.translated(Vector2(0, -9))
	if not test_move(up, Vector2(dir * 3.0, 0)) and not test_move(global_transform, Vector2(0, -9)):
		position += Vector2(dir * 2.0, -9.0)


func _inventory_input(delta: float) -> void:
	inventory.tick(delta)
	var sel: int = intent.get("select", -1)
	if sel >= 0:
		inventory.select(sel)
	elif intent.get("cycle", false):
		inventory.cycle()
	if intent.get("heal", false):
		inventory.use_medkit()


func throw_grenade() -> void:
	if grenades <= 0 or _throw_cd > 0.0 or body.arms_left() == 0:
		return
	grenades -= 1
	_throw_cd = 0.6
	var g := Grenade.new()
	Juice.world.add_child(g)
	g.global_position = rig.to_global(rig.j.hand1)
	var d: Dictionary = Arsenal.GRENADE
	var v := (aim_dir + Vector2(0, -0.25)).normalized() * float(d.throw) + velocity * 0.5
	g.setup(self, v, d.fuse, false, d.dmg, d.radius)
	Sfx.play("swing", global_position, -6.0, 0.1)


func leg_factor() -> float:
	return [0.35, 0.65, 1.0][body.legs_left()]


func _land(vy: float) -> void:
	rig.squash(clampf(vy / 520.0, 0.15, 1.0))
	if vy > 120.0:
		Sfx.play("land", global_position, -10.0 + vy / 60.0)
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
	last_zone = body.zone(rig.global_joints(), at, dir)
	var res := body.damage(last_zone, dmg)
	_since_hit = 0.0
	hp -= res.dmg
	velocity += dir * knock
	hit_flash = 0.045
	recent_hit = 0.6
	Effects.blood(at, dir, int(2 + res.dmg * 0.3))
	Sfx.play("flesh", at, -3.0, 0.2)
	_hit_feedback(from, res.dmg)
	if res.broke:
		_sever(last_zone, dir, res.dmg)
		if last_zone == "head" or last_zone == "torso":
			death_cause = "decap" if last_zone == "head" else "split"
			hp = 0.0
	if is_instance_valid(from) and from.get("is_player") and from != self:
		Effects.hit_marker(at, last_zone == "head", hp <= 0.0)
	if hp <= 0.0:
		_die(dir, from, res.dmg)


func _hit_feedback(from: Node2D, dmg: float) -> void:
	var player_involved: bool = is_player or (is_instance_valid(from) and from.get("is_player"))
	if player_involved and dmg >= 20.0:
		Juice.hitstop(0.04)
	if brain and brain.has_method("rumble"):
		brain.rumble(0.3, 0.2 + minf(dmg / 60.0, 0.8), 0.18)
	if is_player and (brain is PlayerBrain or brain is PadBrain):
		Juice.hurt = minf(Juice.hurt + 0.35, 0.8)
		Juice.aberration = minf(Juice.aberration + 0.35, 1.5)
		Juice.shake(0.18)


## Arrache un membre : morceau physique qui vole, jet de sang au moignon.
func _sever(part: String, dir: Vector2, dmg: float) -> void:
	rig.missing = body.missing
	if part == "torso":
		return
	var pts := rig.global_joints()
	var keys: Array = BodyParts.DETACH[part]
	var piece := {}
	for k in keys:
		piece[k] = pts[k]
	var gib := Ragdoll.new()
	gib.is_gib = true
	Juice.world.add_child(gib)
	gib.setup(piece, velocity, dir * (160.0 + dmg * 4.0) + Vector2(0, -120), [keys[0]], team_color)
	_spurt[keys[0]] = 2.5
	Effects.gore_burst(pts[keys[0]], dir, 1.0 if part == "head" else 0.6)
	Sfx.play("gore", pts[keys[0]], 2.0)


func _die(dir: Vector2, killer: Node2D, dmg: float) -> void:
	alive = false
	if death_cause == "":
		death_cause = "headshot" if last_zone == "head" else "shot"
	var corpse := Ragdoll.new()
	Juice.world.add_child(corpse)
	var cut := [["shoulder", "hip"]] if death_cause == "split" else []
	var bleed: Array = _spurt.keys() + (["shoulder", "hip"] if not cut.is_empty() else [])
	corpse.setup(_corpse_points(), velocity, dir * (220.0 + dmg * 3.0), bleed, team_color, cut)
	var chest := global_position + Vector2(0, -26)
	Effects.blood(chest, dir, 24)
	if death_cause == "split":
		Effects.gore_burst(chest, dir, 1.4)
	Juice.fx.emit(5, chest, Vector2.ZERO, 0.3, 22.0, Color(team_color * 1.5, 0.8))
	Juice.shockwave(chest, 1.0)
	Juice.zoom_punch = 0.08
	Juice.shake(0.4, chest)
	_kill_time_fx(killer, chest)
	drop_weapon(Vector2(dir.x * 80.0, -200.0))
	var spare := inventory.other()
	if spare:
		_drop_gun(spare, Vector2(-dir.x * 60.0, -180.0))
	_drop_loot()
	Juice.fighter_killed.emit(self, killer)
	queue_free()


## Ralenti réservé aux morts par la tête (à l'écran ou impliquant le joueur) ; sinon simple à-coup.
func _kill_time_fx(killer: Node2D, at: Vector2) -> void:
	var player_involved: bool = is_player or (is_instance_valid(killer) and killer.get("is_player"))
	var head_kill := death_cause == "headshot" or death_cause == "decap"
	if head_kill and (player_involved or Juice.on_screen(at)):
		Juice.hitstop(0.06)
		Juice.slowmo(0.9, 0.22)
		Sfx.play_ui("slowmo", -2.0)
		Juice.aberration += 0.7
	elif player_involved:
		Juice.hitstop(0.04)


func drop_weapon(v: Vector2) -> void:
	_drop_gun(gun, v)


func _drop_gun(g: Gun, v: Vector2) -> void:
	var p := WeaponPickup.new()
	Juice.world.add_child(p)
	p.global_position = rig.to_global(rig.j.pivot)
	p.setup(g.id, v, self, g.mag, g.reserve, g.attachments)


## Butin laissé à la mort : munitions souvent, soin et grenade parfois, plus les accessoires du sac.
func _drop_loot() -> void:
	var drops: Array[String] = []
	if randf() < 0.65:
		drops.append("ammo")
	if randf() < 0.35 or inventory.medkits > 0:
		drops.append("medkit")
	if randf() < 0.3 or grenades > 0:
		drops.append("grenade")
	for k in drops:
		var l := Loot.new()
		Juice.world.add_child(l)
		l.global_position = global_position + Vector2(0, -16)
		l.setup(k, Vector2(randf_range(-110, 110), randf_range(-240, -140)))
	for att in inventory.bag:
		var a := AttachmentPickup.new()
		Juice.world.add_child(a)
		a.global_position = global_position + Vector2(0, -16)
		a.setup(att, Vector2(randf_range(-90, 90), randf_range(-220, -140)), self)


func _corpse_points() -> Dictionary:
	var pts := rig.global_joints()
	for part in body.missing:
		if part == "torso":
			continue
		var keys: Array = BodyParts.DETACH[part]
		for i in range(1, keys.size()):
			pts.erase(keys[i])
	return pts


func _bleed_stumps(delta: float) -> void:
	for k in _spurt.keys():
		_spurt[k] -= delta
		if _spurt[k] <= 0.0:
			_spurt.erase(k)
			continue
		var pulse := maxf(sin(float(_spurt[k]) * 12.0), 0.0)
		if randf() < delta * 50.0 * pulse:
			var at := rig.to_global(rig.j[k])
			Effects.spurt(at, Vector2(randf_range(-90, 90), randf_range(-200, -80)) + velocity * 0.5, 1)
