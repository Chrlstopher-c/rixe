class_name StickRig
extends Node2D
## Squelette procédural : pose (course, saut, visée), IK deux os, squash/stretch, écharpe verlet, traînées fantômes.

const BODY := Color(0.035, 0.03, 0.055)
const THIGH := 8.0
const SHIN := 8.0
const UPPER := 5.5
const FORE := 5.5
const SCARF_N := 7
const SCARF_SEG := 2.6
const GHOST_LIFE := 0.16

var fighter: Fighter
var j := {}
var recoil := 0.0
var muzzle_local := Vector2.ZERO
var _phase := 0.0
var _t := 0.0
var _feet: Array[Vector2] = [Vector2(-3, 0), Vector2(3, 0)]
var _crouch := 0.0
var _crouch_v := 0.0
var _scarf: Array[Vector2] = []
var _scarf_prev: Array[Vector2] = []
var _ghosts: Array[Dictionary] = []


static func ik(a: Vector2, b: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var dist := clampf(a.distance_to(b), 0.01, l1 + l2 - 0.01)
	var dir := (b - a).normalized()
	var x := (dist * dist + l1 * l1 - l2 * l2) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	return a + dir * x + dir.orthogonal() * h * bend


func _ready() -> void:
	_process(0.0)


func squash(amount: float) -> void:
	_crouch_v += amount * 60.0


func stretch() -> void:
	_crouch_v -= 25.0


func _process(delta: float) -> void:
	_t += delta
	_springs(delta)
	_pose_body(delta)
	_pose_legs(delta)
	_pose_arms()
	_update_scarf(delta)
	_update_ghosts(delta)
	queue_redraw()


func _springs(delta: float) -> void:
	_crouch_v += (-_crouch * 260.0 - _crouch_v * 16.0) * delta
	_crouch = clampf(_crouch + _crouch_v * delta, -0.15, 0.45)
	recoil = move_toward(recoil, 0.0, delta * 30.0)


func _pose_body(delta: float) -> void:
	var v := fighter.velocity
	var run := clampf(v.x / Fighter.RUN, -1.0, 1.0)
	var bob := 0.0
	if fighter.is_on_floor():
		_phase += absf(v.x) * delta * 0.075
		bob = -absf(sin(_phase)) * 1.3 * absf(run) + sin(_t * 2.4) * 0.35 * (1.0 - absf(run))
	var lean := run * 0.24 + clampf(v.y / 900.0, -0.1, 0.1) * fighter.facing
	j.hip = Vector2(0, -15.0 * (1.0 - _crouch) + bob)
	j.shoulder = j.hip + Vector2(0, -10.5).rotated(lean)
	j.neck = j.shoulder + Vector2(0, -1.5).rotated(lean)
	j.head = j.shoulder + Vector2(0, -5.2).rotated(lean * 0.6) + fighter.aim_dir * 0.8


func _pose_legs(delta: float) -> void:
	var targets: Array[Vector2] = []
	var hip: Vector2 = j.hip
	var f := float(fighter.facing)
	if fighter.is_on_floor():
		var run := clampf(absf(fighter.velocity.x) / Fighter.RUN, 0.0, 1.0)
		var dir := signf(fighter.velocity.x) if absf(fighter.velocity.x) > 5.0 else f
		for i in 2:
			var ph := _phase + PI * i
			var idle := Vector2((i * 2 - 1) * 3.2 + f * 0.6, 0)
			var gait := Vector2(sin(ph) * 7.5 * dir, -maxf(0.0, -cos(ph)) * 4.5)
			targets.append(idle.lerp(gait, minf(run * 3.0, 1.0)))
	else:
		var up := fighter.velocity.y < 0.0
		for i in 2:
			var tuck := Vector2((i * 2 - 1) * 2.5 + f * 2.5, 8.0) if up else Vector2((i * 2 - 1) * 3.5 - f, 13.5)
			targets.append(hip + tuck)
	var rate := 30.0 if fighter.is_on_floor() else 12.0
	for i in 2:
		_feet[i] = _feet[i].lerp(targets[i], minf(delta * rate, 1.0))
		j["foot%d" % i] = _feet[i]
		j["knee%d" % i] = ik(hip, _feet[i], THIGH, SHIN, f)


func _pose_arms() -> void:
	var aim := fighter.aim_dir
	var shoulder: Vector2 = j.shoulder
	var pivot := shoulder + Vector2(0, 1.5) + aim * (4.0 - recoil)
	j.hand0 = pivot
	j.hand1 = pivot + aim * 4.5
	j.elbow0 = ik(shoulder, j.hand0, UPPER, FORE, -fighter.facing)
	j.elbow1 = ik(shoulder, j.hand1, UPPER, FORE, -fighter.facing)
	j.pivot = pivot
	muzzle_local = pivot + aim * float(fighter.gun.def.length)


func muzzle_global() -> Vector2:
	return to_global(muzzle_local)


func ejection_global() -> Vector2:
	return to_global(j.pivot + fighter.aim_dir * 3.0)


func global_joints() -> Dictionary:
	var out := {}
	for k in ["head", "shoulder", "hip", "elbow0", "hand0", "elbow1", "hand1", "knee0", "foot0", "knee1", "foot1"]:
		out[k] = to_global(j[k])
	return out


func _update_scarf(delta: float) -> void:
	var anchor := to_global(j.neck)
	if _scarf.is_empty():
		for i in SCARF_N:
			_scarf.append(anchor)
			_scarf_prev.append(anchor)
	_scarf[0] = anchor
	var dt := maxf(delta, 0.0001)
	for i in range(1, SCARF_N):
		var p := _scarf[i]
		var vel := (p - _scarf_prev[i]) * 0.94
		_scarf_prev[i] = p
		var wind := Vector2(-fighter.facing * 60.0 + sin(_t * 14.0 + i) * 40.0, 140.0)
		_scarf[i] = p + vel + wind * dt * dt
	for it in 3:
		for i in range(1, SCARF_N):
			var d := _scarf[i] - _scarf[i - 1]
			_scarf[i] = _scarf[i - 1] + d.limit_length(SCARF_SEG)


func _update_ghosts(delta: float) -> void:
	for g in _ghosts:
		g.age += delta
	_ghosts = _ghosts.filter(func(g: Dictionary) -> bool: return g.age < GHOST_LIFE)
	if fighter.dash_t > 0.0 or fighter.velocity.length() > 320.0:
		_ghosts.append({"pts": global_joints(), "age": 0.0})


func _draw() -> void:
	if not j.has("pivot"):
		return
	_draw_ghosts()
	_draw_scarf()
	var c := BODY if fighter.hit_flash <= 0.0 else Color(2.4, 2.4, 2.4)
	var back := c.lerp(Color(0.2, 0.13, 0.25), 0.35)
	var bf := 1 if fighter.facing > 0 else 0
	_outline()
	_limb(j.hip, j["knee%d" % bf], j["foot%d" % bf], back, 2.2)
	_seg(j.hip, j.shoulder, c, 2.8)
	_limb(j.shoulder, j.elbow0, j.hand0, back, 2.0)
	_draw_gun()
	_limb(j.hip, j["knee%d" % (1 - bf)], j["foot%d" % (1 - bf)], c, 2.2)
	_limb(j.shoulder, j.elbow1, j.hand1, c, 2.0)
	draw_circle(j.head, 3.7, c)
	if fighter.shield > 0.0:
		var a := 0.25 + 0.25 * sin(_t * 20.0)
		draw_arc(Vector2(0, -15), 19.0, 0.0, TAU, 40, Color(fighter.team_color * 1.8, a), 1.2, Juice.hd)
	var visor: Vector2 = j.head + Vector2(fighter.facing * 1.2, -0.5)
	draw_line(visor, visor + Vector2(fighter.facing * 2.4, 0.3), fighter.team_color * 3.0, 1.2)


func _outline() -> void:
	var o := Color(fighter.team_color * 0.7, 1.0)
	for pair in [["hip", "shoulder"], ["hip", "knee0"], ["knee0", "foot0"], ["hip", "knee1"], ["knee1", "foot1"],
			["shoulder", "elbow0"], ["elbow0", "hand0"], ["shoulder", "elbow1"], ["elbow1", "hand1"]]:
		draw_line(j[pair[0]], j[pair[1]], o, 3.3, Juice.hd)
	draw_circle(j.head, 4.4, o, true, -1.0, Juice.hd)


func _limb(a: Vector2, b: Vector2, c: Vector2, col: Color, w: float) -> void:
	_seg(a, b, col, w)
	_seg(b, c, col, w)


func _seg(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(a, b, col, w, Juice.hd)
	draw_circle(b, w * 0.5, col, true, -1.0, Juice.hd)


func _draw_gun() -> void:
	var d: Dictionary = fighter.gun.def
	var L: float = d.length
	var t: float = d.thick
	draw_set_transform(j.pivot, fighter.aim_dir.angle(), Vector2(1, fighter.facing))
	var metal := Color(0.13, 0.12, 0.17)
	draw_rect(Rect2(-3.5, -t * 0.5, L - 1.0, t), metal)
	draw_rect(Rect2(L - 4.5, -0.45, 4.5, 0.9), metal)
	draw_rect(Rect2(-5.5, -0.3, 2.5, t + 0.6), metal)
	draw_rect(Rect2(0.5, t * 0.5, 1.6, 2.4), metal)
	draw_rect(Rect2(1.0, -t * 0.5, L - 7.0, 0.6), fighter.team_color * 1.6)
	if fighter.gun.id == "railgun":
		var pulse := 2.5 + sin(_t * 18.0) * 1.0
		for i in 3:
			draw_rect(Rect2(2.0 + i * 3.0, -t * 0.5 - 0.4, 1.2, t + 0.8), Color(0.4, 1.4, 2.6) * pulse * 0.5)
	draw_set_transform(Vector2.ZERO)


func _draw_scarf() -> void:
	var col := fighter.team_color * 1.25
	for i in range(1, _scarf.size()):
		var w := lerpf(2.4, 0.7, float(i) / SCARF_N)
		draw_line(to_local(_scarf[i - 1]), to_local(_scarf[i]), col, w, Juice.hd)


func _draw_ghosts() -> void:
	for g in _ghosts:
		var k: float = 1.0 - g.age / GHOST_LIFE
		var col := Color(fighter.team_color * 2.0, k * 0.4)
		var p: Dictionary = g.pts
		for pair in [["hip", "shoulder"], ["hip", "knee0"], ["knee0", "foot0"], ["hip", "knee1"], ["knee1", "foot1"],
				["shoulder", "elbow1"], ["elbow1", "hand1"]]:
			draw_line(to_local(p[pair[0]]), to_local(p[pair[1]]), col, 2.0)
		draw_circle(to_local(p.head), 3.4, col)
