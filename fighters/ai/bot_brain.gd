class_name BotBrain
extends RefCounted
## IA de bot : perçoit (cible, menaces, ligne de vue, mémoire), choisit un comportement selon sa personnalité,
## puis produit une intention (déplacement, saut, visée, tir, esquive, mêlée).

enum State { ENGAGE, RUSH, RETREAT, LOOT, SEARCH, HIGH }

const RANK := {"pistol": 0, "smg": 1, "rifle": 1, "shotgun": 2, "launcher": 2, "katana": 2, "sniper": 3, "railgun": 3}
const THINK_EVERY := 0.25

var p: Personality
var state := State.ENGAGE
var target: Node2D
var nav := Navigator.new()
var aim: Aimer
var _think := 0.0
var _retarget := 0.0
var _last_seen := Vector2.INF
var _unseen := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var _dodge_cd := 0.0
var _loot: Node2D
var _look := 0.0
var _threat := 0.0
## Perception (lignes de vue, menaces) cadencée : un humain ne réévalue pas tout 120 fois par seconde.
const LOOK_EVERY := 0.08


## level ∈ [0,1] : niveau général ; archetype : vide = au hasard.
func _init(level: float = 0.6, archetype: String = "") -> void:
	var id := archetype if archetype != "" else String(Personality.ids().pick_random())
	p = Personality.make(id, level)
	aim = Aimer.new(p)


func think(f: Node2D, delta: float) -> Dictionary:
	var it := {"move": 0.0, "jump": false, "jump_held": false, "drop": false, "dash": false, "fire": false,
		"melee": false, "aim": f.global_position + Vector2(f.facing * 60, -20)}
	_perceive(f, delta)
	_think -= delta
	if _think <= 0.0:
		_think = THINK_EVERY * randf_range(0.8, 1.2)
		state = _choose(f)
	_act(f, delta, it)
	_combat(f, delta, it)
	_dodge(f, delta, it)
	_ammo(f, it)
	return it


## Recharge à l'abri (hors de vue) ou quand le chargeur est vide ; sans munitions, va au contact ou cherche une arme.
func _ammo(f: Node2D, it: Dictionary) -> void:
	var g: Gun = f.gun
	var low: bool = g.mag < int(g.def.mag) * (0.25 + 0.4 * p.caution)
	if g.mag == 0 or (low and _unseen > 0.3):
		it.reload = true
	if f.hp < 45.0 and f.inventory.medkits > 0 and (_unseen > 0.2 or f.hp < 25.0):
		it.heal = true
	if g.mag == 0 and g.reserve == 0 and not g.reloading():
		state = State.LOOT if is_instance_valid(_loot) else State.RUSH


func _perceive(f: Node2D, delta: float) -> void:
	_retarget -= delta
	_dodge_cd -= delta
	if _retarget <= 0.0 or not _alive(target):
		target = _pick(f)
		_retarget = randf_range(1.5, 3.5)
	if not _alive(target):
		return
	_look -= delta
	if _look > 0.0:
		if _unseen > 0.0:
			_unseen += delta
		return
	_look = LOOK_EVERY
	if _sees(f, _chest(target)):
		if _unseen > 0.6:
			aim.acquire(null)
		aim.acquire(target)
		_last_seen = target.global_position
		_unseen = 0.0
	else:
		_unseen += LOOK_EVERY


func _choose(f: Node2D) -> State:
	_loot = _wanted_pickup(f)
	if not _alive(target):
		return State.LOOT if is_instance_valid(_loot) else State.SEARCH
	var dist: float = f.global_position.distance_to(target.global_position)
	var scores := {
		State.ENGAGE: 0.5,
		State.RUSH: p.aggression * (1.2 if dist < 220.0 or f.gun.id == "shotgun" else 0.5),
		State.RETREAT: p.caution * 1.6 if f.hp < p.flee_hp() else 0.0,
		State.LOOT: (p.greed * 0.9 + (0.8 if f.gun.reserve == 0 else 0.0)) if is_instance_valid(_loot) else 0.0,
		State.SEARCH: 0.8 if _unseen > 1.5 else 0.0,
		State.HIGH: p.height * 0.7 if target.global_position.y > f.global_position.y - 30.0 else 0.0,
	}
	var best := State.ENGAGE
	for s: State in scores:
		if scores[s] + randf() * 0.15 > scores[best]:
			best = s
	return best


func _act(f: Node2D, delta: float, it: Dictionary) -> void:
	var pos: Vector2 = f.global_position
	if not _alive(target) and state in [State.RETREAT, State.RUSH, State.HIGH, State.ENGAGE]:
		state = State.SEARCH
	match state:
		State.LOOT:
			if is_instance_valid(_loot):
				nav.steer(f, _loot.global_position, delta, it, p.mobility)
		State.SEARCH:
			if _last_seen != Vector2.INF:
				nav.steer(f, _last_seen, delta, it, p.mobility)
		State.RETREAT:
			var away := pos + Vector2(signf(pos.x - target.global_position.x) * 200.0, -80.0)
			nav.steer(f, away, delta, it, p.mobility)
		State.RUSH:
			nav.steer(f, target.global_position, delta, it, p.mobility)
		State.HIGH:
			nav.steer(f, Vector2(target.global_position.x * 0.5 + pos.x * 0.5, pos.y - 80.0), delta, it, p.mobility)
		_:
			_engage(f, delta, it)


## Tient sa distance idéale (arme × personnalité) en se décalant de façon irrégulière.
func _engage(f: Node2D, delta: float, it: Dictionary) -> void:
	var to: Vector2 = target.global_position - f.global_position
	var ideal: float = float(f.gun.def.ideal) * p.range_mult
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe = [-1.0, 1.0, 0.0, 1.0, -1.0].pick_random()
		_strafe_t = randf_range(0.25, 0.9) * lerpf(1.4, 0.6, p.mobility)
	if absf(to.y) > 60.0 or absf(to.x) > ideal + 50.0:
		nav.steer(f, target.global_position, delta, it, p.mobility)
	elif absf(to.x) < ideal - 60.0:
		it.move = -signf(to.x)
	else:
		it.move = _strafe
	if f.is_on_floor() and randf() < delta * p.mobility * 1.5:
		it.jump = true
		it.jump_held = randf() < 0.6


func _combat(f: Node2D, delta: float, it: Dictionary) -> void:
	if not _alive(target):
		return
	var chest := _chest(target)
	var tp := chest if randf() > p.accuracy * 0.25 else chest + Vector2(0, -7)
	aim.track(tp, target.velocity, delta)
	var from_aim: Vector2 = f.global_position + Vector2(0, -27)
	var comp: float = f.gun.climb * f.facing * p.accuracy
	it.aim = from_aim + (aim.point - from_aim).rotated(comp)
	var from: Vector2 = f.global_position + Vector2(0, -27)
	var in_range: bool = from.distance_to(chest) < float(f.gun.def.range) * 0.9
	if _unseen < 0.1 and in_range and state != State.LOOT and aim.trigger(from, chest, delta):
		it.fire = true
		if f.gun.cd <= 0.0:
			aim.shot()
	if from.distance_to(chest) < 30.0 and randf() < delta * (1.0 + 6.0 * p.melee) and f.gun.kind() != "blade":
		it.melee = true
	var d := from.distance_to(chest)
	if f.gun.kind() == "projectile":
		var flight: float = d / float(f.gun.def.speed)
		it.aim = (it.aim as Vector2) + Vector2(0, -160.0 * flight * flight)
		if d < 70.0:
			it.fire = false
	if f.grenades > 0 and d > 90.0 and d < 320.0 and _unseen < 0.1 and randf() < delta * p.aggression * 0.5:
		it.aim = chest + Vector2(0, -d * 0.35)
		it.throw = true


## Esquive : si un adversaire en vue me met en joue, sauter ou dasher (selon prudence et mobilité).
func _dodge(f: Node2D, delta: float, it: Dictionary) -> void:
	_threat -= delta
	if _dodge_cd > 0.0 or _threat > 0.0:
		return
	_threat = LOOK_EVERY
	delta = LOOK_EVERY
	for o in f.get_tree().get_nodes_in_group("fighters"):
		if o == f or not o.alive:
			continue
		var to_me: Vector2 = _chest(f) - (o.global_position + Vector2(0, -27))
		if to_me.length() > 420.0 or absf(o.aim_dir.angle_to(to_me)) > 0.1:
			continue
		if randf() < delta * 6.0 * (p.caution * 0.5 + p.mobility * 0.5) and _sees(f, _chest(o)):
			_dodge_cd = randf_range(0.6, 1.4)
			if f.is_on_floor() or randf() < 0.5:
				it.jump = true
				it.jump_held = true
			if randf() < p.mobility * 0.7:
				it.dash = true
				var toward := signf(o.global_position.x - f.global_position.x)
				it.move = toward if randf() < p.aggression else -toward
			return


func _pick(f: Node2D) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for o in f.get_tree().get_nodes_in_group("fighters"):
		if o == f or not o.alive:
			continue
		var d: float = f.global_position.distance_to(o.global_position) * randf_range(0.7, 1.3)
		if o.is_player:
			d *= 0.85
		if d < best_d:
			best_d = d
			best = o
	return best


## Objet au sol utile (arme plus forte, munitions si à court, soin si blessé), à portée selon l'avidité du bot.
func _wanted_pickup(f: Node2D) -> Node2D:
	var need := _wanted_loot(f)
	if need:
		return need
	var mine: int = RANK.get(f.gun.id, 0)
	var best: Node2D = null
	for pk in f.get_tree().get_nodes_in_group("pickups"):
		var ammo_run: bool = pk.weapon_id == f.gun.id and f.gun.reserve < int(f.gun.def.reserve) / 2
		if (RANK.get(pk.weapon_id, 0) <= mine and not ammo_run) or (pk.immune == f and pk.immune_t > 0.0):
			continue
		var d: float = f.global_position.distance_to(pk.global_position)
		if d < 120.0 + 260.0 * p.greed and (best == null or d < f.global_position.distance_to(best.global_position)):
			best = pk
	return best


func _wanted_loot(f: Node2D) -> Node2D:
	var want := ""
	if f.hp < 55.0:
		want = "medkit"
	elif not f.gun.infinite() and f.gun.reserve < int(f.gun.def.mag):
		want = "ammo"
	if want == "":
		return null
	var best: Node2D = null
	for l in f.get_tree().get_nodes_in_group("loot"):
		var d: float = f.global_position.distance_to(l.global_position)
		var closer: bool = best == null or d < f.global_position.distance_to(best.global_position)
		if l.kind == want and d < 150.0 + 250.0 * p.greed and closer:
			best = l
	return best


func _sees(f: Node2D, to: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = f.get_world_2d().direct_space_state
	var from: Vector2 = f.global_position + Vector2(0, -27)
	var q := PhysicsRayQueryParameters2D.create(from, to, Juice.MASK_WORLD | Juice.MASK_PLATFORMS)
	return space.intersect_ray(q).is_empty()


static func _chest(o: Node2D) -> Vector2:
	return o.global_position + Vector2(0, -22)


static func _alive(o: Variant) -> bool:
	return is_instance_valid(o) and o.alive
