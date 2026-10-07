class_name Grapple
extends RefCounted
## Projection : saisit l'adversaire juste devant, le soulève par-dessus sa tête et le jette derrière soi ; il retombe
## étourdi. Un adversaire distant (en ligne) est projeté d'un coup, sans la prise (son joueur garde la main).

const REACH := 26.0
const LIFT := 0.3
const COOLDOWN := 0.7
const DAMAGE := 22.0
const THROW := Vector2(330.0, -280.0)
const STUN := 0.9

var owner: Node2D
var victim: Node2D
var t := 0.0
var _cd := 0.0
var _side := 1.0


func _init(holder: Node2D) -> void:
	owner = holder


func active() -> bool:
	return t > 0.0


## Avancement de la prise de 0 à 1 (pose du squelette).
func progress() -> float:
	return 1.0 - t / LIFT if t > 0.0 else 0.0


func tick(delta: float, pressed: bool) -> void:
	_cd -= delta
	if t > 0.0:
		_hold(delta)
	elif pressed and _cd <= 0.0 and owner.is_on_floor():
		_cd = COOLDOWN
		var target := target_for(owner)
		if target:
			_seize(target)
		else:
			Sfx.play("swing", owner.global_position, -8.0, 0.1)


## Adversaire vivant à portée de main, devant soi.
static func target_for(f: Node2D) -> Node2D:
	var best: Node2D = null
	for o in f.get_tree().get_nodes_in_group("fighters"):
		if o == f or not o.alive or o.get("held") or o.moves.dodging():
			continue
		var d: Vector2 = o.global_position - f.global_position
		if absf(d.y) < 20.0 and absf(d.x) < REACH and signf(d.x) in [float(f.facing), 0.0]:
			if best == null or absf(d.x) < absf(best.global_position.x - f.global_position.x):
				best = o
	return best


func _seize(target: Node2D) -> void:
	_side = float(owner.facing)
	Sfx.play("punch", target.global_position, -2.0, 0.1)
	if target.remote:
		_throw(target)
		return
	victim = target
	victim.held = true
	_ghost(victim, true)
	t = LIFT


func _hold(delta: float) -> void:
	t -= delta
	if not is_instance_valid(victim) or not victim.alive:
		_release()
		return
	var k := clampf(1.0 - t / LIFT, 0.0, 1.0)
	var arc := Vector2(_side * 16.0, -6.0).rotated(-_side * k * PI * 0.8) + Vector2(0, -26.0 * sin(k * PI * 0.5))
	victim.global_position = owner.global_position + arc
	if t <= 0.0:
		var v := victim
		_release()
		_throw(v)


## Le lanceur et sa victime se traversent pendant la prise (sinon la victime resterait coincée contre lui).
func _ghost(target: Node2D, on: bool) -> void:
	if on:
		owner.add_collision_exception_with(target)
		target.add_collision_exception_with(owner)


func _release() -> void:
	if is_instance_valid(victim):
		victim.held = false
	victim = null
	t = 0.0


func _throw(target: Node2D) -> void:
	var dir := Vector2(-_side * THROW.x, THROW.y)
	target.take_hit(DAMAGE, dir.normalized(), target.global_position + Vector2(0, -20), owner,
		dir.length() if target.remote else 0.0)
	if not target.remote and target.alive:
		target.velocity = dir
		target.moves.stun_t = STUN
		var ref: WeakRef = weakref(target)
		var me: WeakRef = weakref(owner)
		owner.get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
			if ref.get_ref() and me.get_ref():
				me.get_ref().remove_collision_exception_with(ref.get_ref())
				ref.get_ref().remove_collision_exception_with(me.get_ref()))
	Sfx.play("land", target.global_position, 4.0, 0.1)
	Juice.shake(0.35, target.global_position)
	Juice.hitstop(0.06)
	if Fighter.local_human(owner):
		Juice.feat.emit("throw")
