class_name Melee
extends RefCounted
## Coup de pied de mêlée façon Mortal Kombat : armement, frappe en arc dans l'axe de visée, gros recul.

const WINDUP := 0.06
const DURATION := 0.2
const COOLDOWN := 0.45
const RANGE := 30.0
const ARC := 1.0
const DAMAGE := 20.0
const KNOCK := 340.0

var owner: Node2D
var t := 0.0
var _cd := 0.0
var _struck := false


func _init(holder: Node2D) -> void:
	owner = holder


func active() -> bool:
	return t > 0.0


## Avancement de l'animation de 0 à 1 (pour la pose du squelette).
func progress() -> float:
	return 1.0 - t / DURATION if t > 0.0 else 0.0


func tick(delta: float, pressed: bool) -> void:
	_cd -= delta
	if pressed and _cd <= 0.0 and t <= 0.0:
		t = DURATION
		_cd = COOLDOWN
		_struck = false
		Sfx.play("swing", owner.global_position, -3.0)
	if t <= 0.0:
		return
	t -= delta
	if not _struck and DURATION - t >= WINDUP:
		_struck = true
		_strike()


func _strike() -> void:
	var origin: Vector2 = owner.global_position + Vector2(0, -24)
	var dir: Vector2 = owner.aim_dir
	var landed := false
	for o in owner.get_tree().get_nodes_in_group("fighters"):
		if o == owner or not o.alive:
			continue
		var target := _closest_joint(o, origin)
		var to := target - origin
		if to.length() <= RANGE and absf(to.angle_to(dir)) <= ARC:
			o.take_hit(DAMAGE, (dir + Vector2(0, -0.35)).normalized(), target, owner, KNOCK)
			landed = true
	Juice.fx.emit(5, origin + dir * 14.0, Vector2.ZERO, 0.12, 12.0, Color(2.5, 2.3, 2.2, 0.7))
	if landed:
		Sfx.play("punch", origin, 2.0)
		Juice.shake(0.25, origin)
		Juice.hitstop(0.05)


static func _closest_joint(f: Node2D, from: Vector2) -> Vector2:
	var best := Vector2.INF
	var pts: Dictionary = f.rig.global_joints()
	for k in pts:
		var p: Vector2 = pts[k]
		if best == Vector2.INF or from.distance_to(p) < from.distance_to(best):
			best = p
	return best
