class_name NetFighters
extends RefCounted
## Combattants en ligne : instantanés (position, visée, vie, arme, membres) des combattants dont on a la charge,
## marionnettes interpolées pour ceux de l'autre joueur, touches transmises, morts rejouées.

## Écart au-delà duquel une marionnette est replacée d'un coup plutôt que rattrapée.
const SNAP_DIST := 64.0
const CATCH_UP := 10.0
const F_AIMING := 1
const F_PLAYER := 2
const F_SHIELD := 4
const F_ROLL := 8
const F_SLIDE := 16
const F_STUN := 32
const F_BOSS := 64

var s: Node
## Marionnettes par identifiant réseau.
var puppets := {}
var _targets := {}
## Dernière vie morte connue par identifiant (les instantanés en retard ne ressuscitent personne).
var _dead := {}
var _lives := {}


func _init(session: Node) -> void:
	s = session


func reset() -> void:
	puppets.clear()
	_targets.clear()
	_dead.clear()


func drop_puppet(id: String) -> void:
	var p: Variant = puppets.get(id)
	if is_instance_valid(p):
		p.queue_free()
	puppets.erase(id)
	_targets.erase(id)


## Combattants dont cette machine a la charge : tous ceux qui ne sont pas des marionnettes.
func _owned() -> Array[Fighter]:
	var out: Array[Fighter] = []
	for f in s.main._fighters.get_children():
		if f is Fighter and f.alive and not f.remote and not f.is_queued_for_deletion():
			if f.net_id == "":
				f.net_id = f.display_name
			if f.net_life == 0:
				f.net_life = int(_lives.get(f.net_id, 0)) + 1
				_lives[f.net_id] = f.net_life
			out.append(f)
	return out


func snapshot() -> Dictionary:
	var rows := []
	for f in _owned():
		var flags := (F_AIMING if f.aiming else 0) | (F_PLAYER if f.is_player else 0) | (F_SHIELD if f.shield > 0.0 else 0)
		flags |= (F_ROLL if f.moves.roll_t > 0.0 else 0) | (F_SLIDE if f.moves.slide_t > 0.0 else 0)
		flags |= (F_STUN if f.moves.stunned() else 0) | (F_BOSS if f.boss else 0)
		rows.append([f.net_id, f.net_life, f.global_position, f.velocity, f.aim_dir, f.hp, f.gun.id,
			f.gun.attachments, f.body.missing.duplicate(), f.team, f.team_color, flags, f.melee.t, f.dash_t, f.outfit])
	return {"t": "s", "f": rows}


func on_snapshot(msg: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	for row: Array in msg.f:
		var id: String = row[0]
		var life: int = row[1]
		if int(_dead.get(id, 0)) >= life:
			continue
		var p: Variant = puppets.get(id)
		if not is_instance_valid(p) or p.net_life != life:
			if is_instance_valid(p):
				p.queue_free()
			p = _make_puppet(row)
		_targets[id] = {"row": row, "at": now}


func _make_puppet(row: Array) -> Fighter:
	var id: String = row[0]
	var human := (int(row[11]) & F_PLAYER) != 0
	var f: Fighter = s.main.spawner.spawn(s.label(id), row[2], row[10], NetPuppetBrain.new(), row[6], human, row[7])
	f.net_id = id
	f.net_life = row[1]
	f.remote = true
	f.outfit = row[14] if row.size() > 14 else {}
	if int(row[11]) & F_BOSS:
		Boss.make(f)
	f.team = row[9]
	f.shield = 0.0
	puppets[id] = f
	if s.is_host():
		s.main.match_state.register(f)
	return f


## Marionnette : rattrape la position annoncée (extrapolée), reprend visée, arme, membres et animations.
func drive(f: Fighter, _delta: float) -> void:
	var tgt: Variant = _targets.get(f.net_id)
	if tgt == null:
		return
	var row: Array = tgt.row
	var age := minf((Time.get_ticks_msec() - int(tgt.at)) / 1000.0, 0.15)
	var vel: Vector2 = row[3]
	var goal: Vector2 = row[2] + vel * age
	var err := goal - f.global_position
	if err.length() > SNAP_DIST:
		f.global_position = goal
		f.velocity = vel
	else:
		f.velocity = vel + err * CATCH_UP
	f.aim_dir = row[4]
	f.facing = 1 if f.aim_dir.x >= 0.0 else -1
	f.hp = row[5]
	f.aiming = (int(row[11]) & F_AIMING) != 0
	f.melee.t = row[12]
	f.dash_t = row[13]
	_sync_moves(f, int(row[11]))
	if f.gun.id != row[6] or f.gun.attachments != row[7]:
		f.gun = Gun.new(f, row[6], row[7])
	_sync_limbs(f, row[8], Vector2.UP)
	f.move_and_slide()


## Roulade, glissade, étourdissement de la marionnette (visuels seulement : le propriétaire en décide).
func _sync_moves(f: Fighter, flags: int) -> void:
	f.moves.roll_t = Moves.ROLL_TIME * 0.5 if flags & F_ROLL else 0.0
	f.moves.stun_t = 0.3 if flags & F_STUN else 0.0
	var sliding := (flags & F_SLIDE) != 0
	if sliding != (f.moves.slide_t > 0.0):
		f.set_low(sliding)
	f.moves.slide_t = 0.1 if sliding else 0.0


func _sync_limbs(f: Fighter, missing: Array, dir: Vector2) -> void:
	for part: String in missing:
		if f.body.has(part):
			f.body.missing.append(part)
			f._sever(part, dir, 20.0)


## Touche reçue par une marionnette ici : effets visibles tout de suite, dégâts calculés chez son propriétaire.
## Seules les attaques de nos propres combattants comptent (le reste est rejoué de l'autre côté).
func puppet_hit(f: Fighter, dmg: float, dir: Vector2, at: Vector2, from: Variant, knock: float, part: String) -> void:
	if s.local_only or s.applying or not (is_instance_valid(from) and from is Fighter and not from.remote):
		return
	var zone := part if part != "" else f.body.zone(f.rig.global_joints(), at, dir)
	s.send_event({"t": "hit", "id": f.net_id, "l": f.net_life, "d": dmg, "dir": dir, "at": at, "k": knock,
		"p": zone, "by": from.net_id if from.net_id != "" else from.display_name})
	f.hit_flash = 0.045
	Effects.blood(at, dir, int(2 + dmg * 0.2))
	Sfx.play("flesh", at, -3.0, 0.2)
	if Fighter.local_human(from):
		Effects.hit_marker(at, zone == "head", false)
		Effects.damage_number(at, dmg * float(BodyParts.PARTS[zone].mult), zone == "head")


func on_hit(msg: Dictionary) -> void:
	var victim := _local(String(msg.id), int(msg.l))
	if victim == null:
		return
	var by: Variant = puppets.get(String(msg.by))
	victim.take_hit(msg.d, msg.dir, msg.at, by if is_instance_valid(by) else null, msg.k, String(msg.p))


func _local(id: String, life: int) -> Fighter:
	for f in s.main._fighters.get_children():
		if f is Fighter and f.alive and not f.remote and f.net_id == id and f.net_life == life:
			return f
	return null


## Mort d'un de nos combattants : l'autre côté fait tomber la marionnette de la même façon.
func local_death(f: Fighter, dir: Vector2, killer: Variant, dmg: float) -> void:
	var by := ""
	if is_instance_valid(killer):
		by = killer.net_id if killer.net_id != "" else killer.display_name
	s.send_event({"t": "died", "id": f.net_id, "l": f.net_life, "dir": dir, "cause": f.death_cause, "by": by,
		"dmg": dmg, "exec": f.executed, "missing": f.body.missing.duplicate()})


func on_died(msg: Dictionary) -> void:
	var id: String = msg.id
	_dead[id] = maxi(int(_dead.get(id, 0)), int(msg.l))
	var p: Variant = puppets.get(id)
	if not is_instance_valid(p) or p.net_life != int(msg.l) or not p.alive:
		return
	_sync_limbs(p, msg.missing, msg.dir)
	p.death_cause = msg.cause
	p.executed = msg.exec
	var killer: Variant = puppets.get(String(msg.by))
	if not is_instance_valid(killer):
		killer = _local_any(String(msg.by))
	p._die(msg.dir, killer, msg.dmg)
	puppets.erase(id)


func _local_any(id: String) -> Variant:
	for f in s.main._fighters.get_children():
		if f is Fighter and not f.remote and f.net_id == id:
			return f
	return null
