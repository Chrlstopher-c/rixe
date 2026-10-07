class_name Melee
extends RefCounted
## Corps à corps en combos : direct, crochet puis coup de pied de finition, chaque appui dans la fenêtre enchaîne le
## coup suivant (les deux premiers étourdissent un instant pour que la suite porte) ; en l'air, coup de pied sauté.

## Coups : membre, armement, durée, portée, dégâts, recul, étourdissement, délai avant le coup d'après.
const STEPS := [
	{"name": "jab", "limb": "arm", "windup": 0.05, "dur": 0.15, "range": 26.0, "dmg": 11.0, "knock": 110.0,
		"stun": 0.3, "cd": 0.04},
	{"name": "cross", "limb": "arm", "windup": 0.06, "dur": 0.17, "range": 28.0, "dmg": 15.0, "knock": 160.0,
		"stun": 0.35, "cd": 0.05},
	{"name": "kick", "limb": "leg", "windup": 0.06, "dur": 0.22, "range": 30.0, "dmg": 26.0, "knock": 420.0,
		"stun": 0.0, "cd": 0.4},
]
const AIR := {"name": "air", "limb": "leg", "windup": 0.04, "dur": 0.3, "range": 32.0, "dmg": 24.0, "knock": 380.0,
	"stun": 0.0, "cd": 0.35}
## Durée de référence (exécutions, synchronisation).
const DURATION := 0.2
## Après un coup, un nouvel appui pendant cette fenêtre enchaîne sur le suivant.
const CHAIN := 0.35
const ARC := 1.0

var owner: Node2D
var t := 0.0
## Coup en cours (index dans STEPS, 3 = coup sauté).
var step := 0
var _cd := 0.0
var _chain := 0.0
var _struck := false
var _queued := false
var _was_pressed := false


func _init(holder: Node2D) -> void:
	owner = holder


static func def_of(i: int) -> Dictionary:
	return AIR if i >= STEPS.size() else STEPS[i]


func current() -> Dictionary:
	return def_of(step)


func active() -> bool:
	return t > 0.0


func kicking() -> bool:
	return active() and current().limb == "leg"


## Avancement de l'animation de 0 à 1 (pour la pose du squelette).
func progress() -> float:
	return 1.0 - t / float(current().dur) if t > 0.0 else 0.0


func tick(delta: float, pressed: bool) -> void:
	_cd -= delta
	_chain -= delta
	if pressed and not _was_pressed and (t > 0.0 or _cd > 0.0):
		_queued = true
	_was_pressed = pressed
	if t <= 0.0 and _cd <= 0.0 and (pressed or _queued):
		_start()
	if t <= 0.0:
		return
	t -= delta
	if not _struck and float(current().dur) - t >= float(current().windup):
		_struck = true
		_strike()
	if t <= 0.0:
		_chain = CHAIN
		_cd = float(current().cd)


func _start() -> void:
	_queued = false
	if not owner.is_on_floor():
		step = STEPS.size()
		owner.velocity += owner.aim_dir * 140.0
	elif _chain > 0.0 and step < STEPS.size() - 1:
		step += 1
	else:
		step = 0
	owner.moves.open_parry()
	t = float(current().dur)
	_struck = false
	Sfx.play("swing", owner.global_position, -3.0, 0.15)


func _strike() -> void:
	var d := current()
	var origin: Vector2 = owner.global_position + Vector2(0, -24)
	var dir: Vector2 = owner.aim_dir
	var landed := false
	for o in owner.get_tree().get_nodes_in_group("fighters"):
		if o == owner or not o.alive:
			continue
		var target := _closest_joint(o, origin)
		var to := target - origin
		if to.length() > float(d.range) or absf(to.angle_to(dir)) > ARC:
			continue
		if o.moves.parries(owner):
			continue
		o.take_hit(float(d.dmg), (dir + Vector2(0, -0.35)).normalized(), target, owner, float(d.knock))
		if float(d.stun) > 0.0 and not o.remote:
			o.moves.stun_t = maxf(o.moves.stun_t, float(d.stun))
		landed = true
	Juice.fx.emit(5, origin + dir * 14.0, Vector2.ZERO, 0.12, 12.0, Color(2.5, 2.3, 2.2, 0.7))
	Juice.arena.damage(origin + dir * 20.0, 14.0 if d.limb == "leg" else 7.0, 4.0, owner)
	if landed:
		_chain = CHAIN + float(d.dur)
		Sfx.play("punch", origin, 2.0 if d.limb == "leg" else -1.0, 0.15)
		Juice.shake(0.25 if d.limb == "leg" else 0.12, origin)
		Juice.hitstop(0.05 if d.limb == "leg" else 0.03)


static func _closest_joint(f: Node2D, from: Vector2) -> Vector2:
	var best := Vector2.INF
	var pts: Dictionary = f.rig.global_joints()
	for k in pts:
		var p: Vector2 = pts[k]
		if best == Vector2.INF or from.distance_to(p) < from.distance_to(best):
			best = p
	return best
