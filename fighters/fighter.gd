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
var moves := Moves.new(self)
var _shape: CollisionShape2D
var execution := Execution.new(self)
## Tenu pendant qu'on l'exécute : ne bouge plus, ne pense plus.
var held := false
var executed := false
## > 0 : un joueur peut l'exécuter maintenant (repère au-dessus de la tête).
var mark_t := 0.0
## En ligne : identifiant partagé, vie en cours (chaque réapparition l'incrémente), marionnette d'un autre joueur.
var net_id := ""
var net_life := 0
var remote := false
## Boss d'arcade (voir Boss).
var boss := false
## Diagnostic du tir (RIXE_DEBUG_FIRE=1) : une ligne par seconde dans la console.
var _debug_fire := OS.get_environment("RIXE_DEBUG_FIRE") != ""
var _debug_t := 0.0
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
	_shape = CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 6.0
	cap.height = 34.0
	_shape.shape = cap
	_shape.position = Vector2(0, -17)
	add_child(_shape)
	rig = StickRig.new()
	rig.fighter = self
	rig.scale = Vector2.ONE * 1.22
	add_child(rig)
	z_index = 10


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if remote:
		if Juice.net:
			Juice.net.drive(self, delta)
		return
	if global_position.y > Juice.arena.void_y:
		death_cause = "fall"
		hp = 0.0
		_die(Vector2.DOWN, null, 0.0)
		return
	mark_t -= delta
	if held:
		velocity = Vector2.ZERO
		return
	if execution.running():
		execution.tick(delta)
		move_and_slide()
		return
	intent = brain.think(self, delta)
	if moves.stunned():
		intent = {"move": 0.0, "jump": false, "jump_held": false, "drop": false, "dash": false, "fire": false,
			"aim": intent.aim}
	_aim()
	_timers(delta)
	_move(delta)
	moves.tick(delta)
	_jump()
	_dash()
	var was_floor := is_on_floor()
	var vy := velocity.y
	move_and_slide()
	_step_up()
	if not was_floor and is_on_floor():
		_land(vy)
	if intent.get("focus", false) and local_human(self) and Juice.use_focus():
		Juice.notify("RALENTI")
	if not _try_execute():
		melee.tick(delta, intent.get("melee", false))
	_throw_cd -= delta
	if intent.get("throw", false):
		throw_grenade()
	_inventory_input(delta)
	var can_fire: bool = body.arms_left() > 0 and not melee.active() and inventory.switching <= 0.0
	gun.tick(delta, intent.fire and can_fire, intent.get("reload", false))
	if _debug_fire and is_player:
		_trace_fire(delta, can_fire)
	_bleed_stumps(delta)


func _trace_fire(delta: float, can_fire: bool) -> void:
	_debug_t -= delta
	if _debug_t > 0.0:
		return
	_debug_t = 0.5
	var pads := Input.get_connected_joypads().map(func(d: int) -> String: return Input.get_joy_name(d))
	var fmt := "[tir] cerveau=%s detente=%s arme=%s chargeur=%d/%d cd=%.2f recharge=%.2f bras=%d pied=%s"
	print((fmt + " changement=%.2f manettes=%s") % [
		brain.get_script().resource_path.get_file(), intent.fire, gun.id, gun.mag, gun.reserve, gun.cd, gun.reload_t,
		body.arms_left(), melee.active(), inventory.switching, pads])


## Joueur : repère le bot vacillant à portée et l'achève au lieu du coup de pied.
func _try_execute() -> bool:
	if not is_player:
		return false
	var target := Execution.target_for(self)
	if target == null:
		return false
	target.mark_t = 0.1
	if not intent.get("melee", false) or melee.active():
		return false
	execution.start(target)
	return true


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
	if moves.slide_t > 0.0:
		velocity.y = minf(velocity.y + GRAVITY * delta, 520.0)
		return
	if intent.drop and is_on_floor() and not _on_platform() and moves.try_slide(intent.move):
		return
	var goal: float = intent.move * RUN * leg_factor() * (0.6 if aiming else 1.0)
	if Execution.staggered(self):
		goal *= 0.55
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
	elif moves.try_wall_jump():
		jumped.emit(true)
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
	if is_on_floor():
		moves.start_roll()
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
	if Juice.net:
		Juice.net.grenade_thrown(g)
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


## Hauteur réduite pendant la glissade (les tirs à hauteur de tête passent au-dessus).
func set_low(on: bool) -> void:
	var cap: CapsuleShape2D = _shape.shape
	cap.height = 20.0 if on else 34.0
	_shape.position = Vector2(0, -10.0 if on else -17.0)


func _on_platform() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c is Node and (c as Node).is_in_group("platform"):
			return true
	return false


## `part` force la zone touchée (exécutions) ; vide = calculée depuis la ligne de tir.
func take_hit(dmg: float, dir: Vector2, at: Vector2, from: Variant, knock: float, part: String = "") -> void:
	if not alive:
		return
	if remote:
		if Juice.net:
			Juice.net.puppet_hit(self, dmg, dir, at, from, knock, part)
		return
	if shield > 0.0:
		Effects.impact(at, -dir, team_color * 2.0)
		return
	if moves.dodging() and is_instance_valid(from):
		Juice.fx.emit(5, at, Vector2.ZERO, 0.15, 8.0, Color(team_color * 2.0, 0.6))
		return
	if is_player:
		dmg *= PLAYER_DAMAGE_TAKEN
	last_zone = part if part != "" else body.zone(rig.global_joints(), at, dir)
	var res := body.damage(last_zone, dmg)
	_since_hit = 0.0
	hp -= res.dmg
	velocity += dir * knock * (Boss.KNOCK if boss else 1.0)
	hit_flash = 0.045
	recent_hit = 0.6
	Effects.blood(at, dir, int(2 + res.dmg * 0.3))
	Sfx.play("flesh", at, -3.0, 0.2)
	Sfx.add_heat(0.3 if is_player else (0.1 if Juice.on_screen(at) else 0.0))
	_hit_feedback(from, res.dmg)
	if res.broke:
		_sever(last_zone, dir, res.dmg)
		if last_zone == "head" or last_zone == "torso":
			death_cause = "decap" if last_zone == "head" else "split"
			hp = 0.0
	if local_human(from) and from != self:
		Effects.hit_marker(at, last_zone == "head", hp <= 0.0)
		Effects.damage_number(at, res.dmg, last_zone == "head")
	if local_human(self) and is_instance_valid(from) and from != self and not Juice.on_screen(from.global_position):
		Juice.threats.append({"at": from.global_position, "t": 1.2})
	if hp <= 0.0:
		_die(dir, from, res.dmg)


## Joueur humain de cette machine (pas la marionnette d'un joueur distant).
static func local_human(n: Variant) -> bool:
	return is_instance_valid(n) and n.get("is_player") and not n.get("remote")


func _hit_feedback(from: Variant, dmg: float) -> void:
	var player_involved: bool = local_human(self) or local_human(from)
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


func _die(dir: Vector2, killer: Variant, dmg: float) -> void:
	alive = false
	if death_cause == "":
		death_cause = "headshot" if last_zone == "head" else "shot"
	var corpse := Ragdoll.new()
	Juice.world.add_child(corpse)
	var cut := [["shoulder", "hip"]] if death_cause == "split" else []
	var bleed: Array = _spurt.keys() + (["shoulder", "hip"] if not cut.is_empty() else [])
	corpse.setup(Remains.corpse_points(self), velocity, dir * (220.0 + dmg * 3.0), bleed, team_color, cut)
	var chest := global_position + Vector2(0, -26)
	Effects.blood(chest, dir, 24)
	if death_cause == "split":
		Effects.gore_burst(chest, dir, 1.4)
	Juice.fx.emit(5, chest, Vector2.ZERO, 0.3, 22.0, Color(team_color * 1.5, 0.8))
	Juice.shockwave(chest, 1.0)
	Juice.zoom_punch = 0.08
	Juice.shake(0.4, chest)
	_kill_time_fx(killer, chest)
	if local_human(killer) and killer != self:
		Juice.gauge = minf(Juice.gauge + (0.5 if death_cause in ["headshot", "decap"] else 0.34), 1.0)
	if Juice.net and not remote:
		Juice.net.local_death(self, dir, killer, dmg)
	if Juice.net == null or Juice.net.is_host():
		drop_weapon(Vector2(dir.x * 80.0, -200.0))
		var spare := inventory.other()
		if spare:
			Remains.drop_gun(self, spare, Vector2(-dir.x * 60.0, -180.0))
		Remains.drop_loot(self)
	Juice.fighter_killed.emit(self, killer if is_instance_valid(killer) else null)
	queue_free()


## Ralenti réservé aux morts par la tête (à l'écran ou impliquant le joueur) ; sinon simple à-coup.
func _kill_time_fx(killer: Variant, at: Vector2) -> void:
	var player_involved: bool = local_human(self) or local_human(killer)
	var head_kill := death_cause == "headshot" or death_cause == "decap"
	if head_kill and (player_involved or Juice.on_screen(at)):
		Juice.hitstop(0.06)
		Juice.slowmo(0.9, 0.22)
		Sfx.play_ui("slowmo", -2.0)
		Juice.aberration += 0.7
	elif player_involved:
		Juice.hitstop(0.04)


func drop_weapon(v: Vector2) -> void:
	Remains.drop_gun(self, gun, v)


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
