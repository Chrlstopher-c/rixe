class_name Execution
extends RefCounted
## Exécution façon Mortal Kombat : un bot vacillant (vie basse) à portée s'achève au corps à corps,
## en deux temps (un membre, puis le coup de grâce) sous la kill cam.

## Vie sous laquelle un combattant vacille et peut être exécuté.
const STAGGER_HP := 25.0
const REACH := 44.0
## Temps de jeu (déjà ralenti par la kill cam) : premier coup, coup de grâce, fin.
const HIT1 := 0.05
const HIT2 := 0.17
const END := 0.3
const FINISHERS := ["decap", "split", "uppercut"]

var owner: Node2D
var victim: Node2D
var finisher := ""
var t := -1.0
var _step := 0


func _init(holder: Node2D) -> void:
	owner = holder


func running() -> bool:
	return t >= 0.0


static func staggered(f: Node2D) -> bool:
	return f.alive and not f.is_player and f.hp <= STAGGER_HP and f.shield <= 0.0


## Bot vacillant le plus proche que `f` peut achever (null si aucun).
static func target_for(f: Node2D) -> Node2D:
	if not f.alive or f.body.legs_left() + f.body.arms_left() == 0:
		return null
	var best: Node2D = null
	var best_d := REACH
	for o in f.get_tree().get_nodes_in_group("fighters"):
		if o == f or not staggered(o) or o.get("held"):
			continue
		if f.team != "" and o.team == f.team:
			continue
		var d: float = f.global_position.distance_to(o.global_position)
		if d < best_d and absf(o.global_position.y - f.global_position.y) < 24.0:
			best = o
			best_d = d
	return best


func start(v: Node2D) -> void:
	victim = v
	finisher = FINISHERS[randi() % FINISHERS.size()]
	t = 0.0
	_step = 0
	v.held = true
	v.velocity = Vector2.ZERO
	owner.velocity = Vector2.ZERO
	var side := signf(owner.global_position.x - v.global_position.x)
	owner.global_position.x = v.global_position.x + (side if side != 0.0 else -1.0) * 15.0
	Juice.kill_cam(v.global_position + Vector2(0, -24), 1.6)
	Juice.executed.emit(v, owner)
	Sfx.play("swing", owner.global_position, 0.0)


func tick(delta: float) -> void:
	if not is_instance_valid(victim) or not victim.alive:
		t = -1.0
		return
	t += delta
	owner.velocity = Vector2.ZERO
	owner.melee.t = maxf(owner.melee.t - delta * 4.0, 0.0)
	owner.aim_dir = (victim.global_position - owner.global_position).normalized() + Vector2(0, -0.6)
	owner.aim_dir = owner.aim_dir.normalized()
	owner.facing = 1 if owner.aim_dir.x >= 0.0 else -1
	if _step == 0 and t >= HIT1:
		_step = 1
		_maim()
	elif _step == 1 and t >= HIT2:
		_step = 2
		_finish()
	elif t >= END:
		t = -1.0


func _dir() -> Vector2:
	return Vector2(signf(victim.global_position.x - owner.global_position.x), 0.0)


## Premier coup : arrache un bras ou une jambe sans tuer.
func _maim() -> void:
	owner.melee.t = Melee.DURATION
	var parts := ["arm0", "arm1", "leg0", "leg1"].filter(func(p: String) -> bool: return victim.body.has(p))
	if parts.is_empty():
		return
	var part: String = parts[randi() % parts.size()]
	var need := _lethal(part)
	victim.hp = maxf(victim.hp, 1.0) + need * float(BodyParts.PARTS[part].mult)
	victim.take_hit(need, _dir(), victim.global_position + Vector2(0, -20), owner, 0.0, part)
	victim.velocity = Vector2.ZERO
	Sfx.play("punch", victim.global_position, 3.0)
	Juice.hitstop(0.06)
	Juice.shake(0.35, victim.global_position)


## Coup de grâce : décapitation, coupé en deux ou tête envoyée en l'air.
func _finish() -> void:
	owner.melee.t = Melee.DURATION
	victim.held = false
	var dir := _dir()
	var part := "torso" if finisher == "split" else "head"
	var push := dir + Vector2(0, -0.4)
	if finisher == "uppercut":
		push = Vector2(dir.x * 0.25, -1.0)
	victim.executed = true
	victim.take_hit(_lethal(part), push.normalized(), victim.global_position + Vector2(0, -26), owner, 260.0, part)
	Effects.gore_burst(victim.global_position + Vector2(0, -26), push.normalized(), 1.6)
	Sfx.play("gore", owner.global_position, 4.0)
	Juice.hitstop(0.1)
	Juice.shake(0.7, owner.global_position)
	Juice.shockwave(owner.global_position + Vector2(0, -24), 1.4)


## Dégâts juste suffisants pour arracher la partie (sans projeter les morceaux à des vitesses absurdes).
func _lethal(part: String) -> float:
	return victim.body.hp[part] / float(BodyParts.PARTS[part].mult) + 1.0
