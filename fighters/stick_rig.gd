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
const GHOST_PAIRS := [["hip", "shoulder"], ["hip", "knee0"], ["knee0", "foot0"], ["hip", "knee1"], ["knee1", "foot1"],
	["shoulder", "elbow1"], ["elbow1", "hand1"]]

var fighter: Fighter
var j := {}
var recoil := 0.0
var muzzle_local := Vector2.ZERO
var missing: Array[String] = []
## Direction affichée du canon (visée + remontée + bascule de rechargement).
var gun_dir := Vector2.RIGHT
var _kick_trail: Array[Vector2] = []
var _phase := 0.0
var _t := 0.0
var _feet: Array[Vector2] = [Vector2(-3, 0), Vector2(3, 0)]
var _crouch := 0.0
var _crouch_v := 0.0
var _scarf: Array[Vector2] = []
var _scarf_prev: Array[Vector2] = []
var _ghosts: Array[Dictionary] = []
var _ghost_tick := false
## Rotation de la roulade (accumulée tant qu'elle dure).
var _spin := 0.0


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
	_pose_kick()
	_pose_arms()
	_update_scarf(delta)
	_update_ghosts(delta)
	_pose_moves(delta)
	if Juice.on_screen(global_position, 80.0) or not Juice.camera:
		queue_redraw()


## Roulade : le corps tourne sur lui-même autour du bassin ; glissade : penché en arrière, au ras du sol.
func _pose_moves(delta: float) -> void:
	var m: Moves = fighter.moves
	var goal := 0.0
	if m.roll_t > 0.0:
		_spin += delta * 21.0 * fighter.facing
		goal = _spin
	else:
		_spin = 0.0
		if m.slide_t > 0.0:
			goal = -0.75 * fighter.facing
	rotation = goal if m.roll_t > 0.0 else lerp_angle(rotation, goal, minf(delta * 18.0, 1.0))
	var pivot := Vector2(0, -15.0 * scale.y)
	position = pivot - pivot.rotated(rotation) + (Vector2(0, 4) if m.slide_t > 0.0 else Vector2.ZERO)


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
	var stand := -15.0 if fighter.body.legs_left() > 0 else -5.0
	j.hip = Vector2(0, stand * (1.0 - _crouch) + bob)
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


func _pose_kick() -> void:
	if not fighter.melee.kicking():
		_kick_trail.clear()
		return
	var ext := sin(fighter.melee.progress() * PI)
	var front := 0 if fighter.facing > 0 else 1
	if not has("leg%d" % front):
		return
	var hip: Vector2 = j.hip
	var foot: Vector2 = _feet[front].lerp(hip + fighter.aim_dir * 16.5, ext)
	j["foot%d" % front] = foot
	j["knee%d" % front] = ik(hip, foot, THIGH, SHIN, fighter.facing)
	j.shoulder = j.shoulder - fighter.aim_dir * 2.5 * ext
	j.head = j.head - fighter.aim_dir * 3.0 * ext
	_kick_trail.append(to_global(foot))


func _pose_arms() -> void:
	var aim: Vector2 = fighter.gun.shot_dir()
	var shoulder: Vector2 = j.shoulder
	var pivot := shoulder + Vector2(0, 1.5) + aim * (4.0 - recoil)
	var k: float = fighter.gun.reload_progress()
	if k > 0.0:
		var dip := sin(k * PI)
		aim = aim.rotated(fighter.facing * 0.9 * dip)
		pivot += Vector2(0, 2.0 * dip)
	var punch := _punch()
	if punch != Vector2.ZERO:
		pivot += aim * punch.x
		j.shoulder = j.shoulder + aim * punch.y
	gun_dir = aim
	j.hand0 = pivot
	j.hand1 = pivot + aim * 4.5
	if k > 0.0:
		j.hand1 = pivot + aim * 2.0 + Vector2(0, 3.0 + 2.0 * sin(k * TAU * 2.0))
	j.elbow0 = ik(shoulder, j.hand0, UPPER, FORE, -fighter.facing)
	j.elbow1 = ik(shoulder, j.hand1, UPPER, FORE, -fighter.facing)
	j.pivot = pivot
	muzzle_local = pivot + aim * float(fighter.gun.def.length)


## Coup de poing en cours : [allonge du poing, avancée de l'épaule] ; zéro hors des coups de poing.
func _punch() -> Vector2:
	var m: Melee = fighter.melee
	if not m.active() or m.kicking():
		return Vector2.ZERO
	var ext := sin(m.progress() * PI)
	return Vector2(7.0 if m.step == 0 else 9.5, 0.8 if m.step == 0 else 2.0) * ext


func muzzle_global() -> Vector2:
	return to_global(muzzle_local)


func ejection_global() -> Vector2:
	return to_global(j.pivot + fighter.aim_dir * 3.0)


func global_joints() -> Dictionary:
	var out := {}
	for k in ["head", "neck", "shoulder", "hip", "elbow0", "hand0", "elbow1", "hand1", "knee0", "foot0", "knee1", "foot1"]:
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
		var wind := Vector2(-fighter.facing * 60.0 + Juice.wind * 1.5 + sin(_t * 14.0 + i) * 40.0, 140.0)
		_scarf[i] = p + vel + wind * dt * dt
	for it in 3:
		for i in range(1, SCARF_N):
			var d := _scarf[i] - _scarf[i - 1]
			_scarf[i] = _scarf[i - 1] + d.limit_length(SCARF_SEG)


## Traînée fantôme : une silhouette mémorisée toutes les 2 images (6 au plus), stockée en coordonnées du monde.
func _update_ghosts(delta: float) -> void:
	for g in _ghosts:
		g.age += delta
	_ghosts = _ghosts.filter(func(g: Dictionary) -> bool: return g.age < GHOST_LIFE)
	_ghost_tick = not _ghost_tick
	if _ghost_tick and _ghosts.size() < 6 and (fighter.dash_t > 0.0 or fighter.velocity.length() > 320.0):
		var pts := PackedVector2Array()
		for pair in GHOST_PAIRS:
			pts.append(to_global(j[pair[0]]))
			pts.append(to_global(j[pair[1]]))
		_ghosts.append({"pts": pts, "head": to_global(j.head), "age": 0.0})


func _draw() -> void:
	if not j.has("pivot"):
		return
	_draw_ghosts()
	if has("head"):
		_draw_scarf()
	var c := BODY if fighter.hit_flash <= 0.0 else BODY.lerp(Color(2.2, 2.0, 2.0), 0.55)
	var back := c.lerp(Color(0.2, 0.13, 0.25), 0.35)
	var bf := 1 if fighter.facing > 0 else 0
	Outfit.draw_back(self, j, fighter.facing, fighter.team_color, fighter.outfit, Juice.hd)
	_outline()
	_part_limb("leg%d" % bf, back, 2.2)
	draw_line(j.hip, j.shoulder, c, 2.8, Juice.hd)
	_part_limb("arm0", back, 2.0)
	if has("arm0") or has("arm1"):
		_draw_gun()
	_part_limb("leg%d" % (1 - bf), c, 2.2)
	_part_limb("arm1", c, 2.0)
	if has("head"):
		draw_circle(j.head, 3.7, c)
		var visor: Vector2 = j.head + Vector2(fighter.facing * 1.2, -0.5)
		draw_line(visor, visor + Vector2(fighter.facing * 2.4, 0.3), fighter.team_color * 3.0, 1.2)
		Outfit.draw_front(self, j, fighter.facing, fighter.team_color, fighter.outfit, Juice.hd)
	_draw_stumps()
	if fighter.is_player:
		_draw_laser()
	for i in range(1, _kick_trail.size()):
		var a := float(i) / _kick_trail.size()
		draw_line(to_local(_kick_trail[i - 1]), to_local(_kick_trail[i]), Color(2.4, 2.2, 2.1, a * 0.8), 2.5 * a, Juice.hd)
	if Execution.staggered(fighter):
		_draw_stagger()
	if fighter.moves.stunned():
		_draw_stun()
	if fighter.is_player and not Fighter.local_human(fighter) and not fighter.brain is BotBrain:
		_draw_name()
	if fighter.shield > 0.0:
		var a := 0.25 + 0.25 * sin(_t * 20.0)
		draw_arc(Vector2(0, -15), 19.0, 0.0, TAU, 40, Color(fighter.team_color * 1.8, a), 1.2, Juice.hd)


## Vacillant : chevron rouge qui bat au-dessus de la tête ; plus gros et blanc-rouge quand un joueur peut l'achever.
func _draw_stagger() -> void:
	var can := fighter.mark_t > 0.0
	var beat := 0.5 + 0.5 * sin(_t * (14.0 if can else 7.0))
	var s := (1.6 if can else 1.0) * (1.0 + 0.15 * beat)
	var top: Vector2 = (j.head if has("head") else j.shoulder) + Vector2(0, -8.0 - 2.0 * beat)
	var col := Color(2.6, 0.5, 0.45, 0.95) if can else Color(1.8, 0.15, 0.2, 0.55 + 0.35 * beat)
	var pts := PackedVector2Array([top + Vector2(-3, -3) * s, top, top + Vector2(3, -3) * s])
	draw_polyline(pts, col, 1.3, Juice.hd)
	if can:
		draw_arc(top + Vector2(0, -1.5) * s, 5.5 * s, 0.0, TAU, 24, Color(col, 0.35 * beat), 1.0, Juice.hd)


## Étourdi (parade subie) : trois étoiles qui tournent au-dessus de la tête.
func _draw_stun() -> void:
	var c: Vector2 = (j.head if has("head") else j.shoulder) + Vector2(0, -6)
	for i in 3:
		var a := _t * 6.0 + i * TAU / 3.0
		var p := c + Vector2(cos(a) * 5.0, sin(a) * 1.8)
		draw_circle(p, 0.9, Color(2.4, 2.2, 0.6, 0.9))


## Pseudo au-dessus des autres joueurs humains (en ligne, écran partagé).
func _draw_name() -> void:
	var font: Font = ThemeDB.fallback_font
	var top: Vector2 = (j.head if has("head") else j.shoulder) + Vector2(-40, -9)
	draw_string(font, top, Names.label(fighter.display_name), HORIZONTAL_ALIGNMENT_CENTER, 80, 6,
		Color(fighter.team_color * 1.6, 0.85))


func _draw_laser() -> void:
	var from := muzzle_global()
	var to := from + fighter.aim_dir * 260.0
	var q := PhysicsRayQueryParameters2D.create(from, to, Juice.MASK_WORLD | Juice.MASK_PLATFORMS)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		to = hit.position
	var col := Color(fighter.team_color * 1.4, 0.12)
	draw_line(to_local(from), to_local(to), col, 0.6, Juice.hd)
	draw_circle(to_local(to), 0.9, Color(fighter.team_color * 2.5, 0.6))


func has(part: String) -> bool:
	return not (part in missing)


func _part_limb(part: String, col: Color, w: float) -> void:
	if not has(part):
		return
	var js: Array = BodyParts.PARTS[part].joints
	_limb(j[js[0]], j[js[1]], j[js[2]], col, w)


func _draw_stumps() -> void:
	for part in missing:
		if part == "torso":
			continue
		var root: Vector2 = j[BodyParts.DETACH[part][0]]
		draw_circle(root, 1.6, Effects.BLOOD * 1.3, true, -1.0, Juice.hd)


## Contour de couleur : un seul tracé multiple (draw_multiline) pour tout le squelette.
func _outline() -> void:
	var o := Color(fighter.team_color * 0.7, 1.0)
	var pts := PackedVector2Array([j.hip, j.shoulder])
	for part in ["arm0", "arm1", "leg0", "leg1"]:
		if has(part):
			var js: Array = BodyParts.PARTS[part].joints
			pts.append_array([j[js[0]], j[js[1]], j[js[1]], j[js[2]]])
	draw_multiline(pts, o, 3.3, Juice.hd)
	if has("head"):
		draw_circle(j.head, 4.4, o, true, -1.0, Juice.hd)


func _limb(a: Vector2, b: Vector2, c: Vector2, col: Color, w: float) -> void:
	draw_polyline(PackedVector2Array([a, b, c]), col, w, Juice.hd)
	draw_circle(b, w * 0.5, col, true, -1.0, Juice.hd)


func _seg(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(a, b, col, w, Juice.hd)
	draw_circle(b, w * 0.5, col, true, -1.0, Juice.hd)


func _draw_gun() -> void:
	var d: Dictionary = fighter.gun.def
	if fighter.gun.charge_t > 0.0:
		var k: float = 1.0 - fighter.gun.charge_t / Boss.CHARGE
		draw_circle(muzzle_local, 2.0 + 5.0 * k, Color(2.6, 0.3, 0.2, 0.35 + 0.5 * k))
	var look: String = d.get("look", "")
	draw_set_transform(j.pivot, gun_dir.angle(), Vector2(1, fighter.facing))
	if look == "blade":
		_draw_blade(d)
	else:
		_draw_firearm(d, look)
	draw_set_transform(Vector2.ZERO)


func _draw_firearm(d: Dictionary, look: String) -> void:
	var L: float = d.length
	var t: float = d.thick
	var metal := Color(0.13, 0.12, 0.17)
	draw_rect(Rect2(-3.5, -t * 0.5, L - 1.0, t), metal)
	draw_rect(Rect2(L - 4.5, -0.45, 4.5, 0.9), metal)
	draw_rect(Rect2(-5.5, -0.3, 2.5, t + 0.6), metal)
	draw_rect(Rect2(0.5, t * 0.5, 1.6, 2.4), metal)
	draw_rect(Rect2(1.0, -t * 0.5, L - 7.0, 0.6), fighter.team_color * 1.6)
	_draw_attachments(L, t, metal)
	match look:
		"scope":
			draw_rect(Rect2(0.5, -t * 0.5 - 2.0, 5.0, 1.6), metal)
			draw_rect(Rect2(5.0, -t * 0.5 - 2.0, 0.8, 1.6), Color(0.6, 1.6, 2.4))
		"tube":
			draw_circle(Vector2(1.5, t * 0.6), 2.2, metal)
			draw_rect(Rect2(L - 3.0, -t * 0.5 - 0.3, 1.0, t + 0.6), Color(2.4, 1.0, 0.4))
	if fighter.gun.id == "railgun":
		var pulse := 2.5 + sin(_t * 18.0) * 1.0
		for i in 3:
			draw_rect(Rect2(2.0 + i * 3.0, -d.thick * 0.5 - 0.4, 1.2, d.thick + 0.8), Color(0.4, 1.4, 2.6) * pulse * 0.5)


func _draw_attachments(L: float, t: float, metal: Color) -> void:
	var a: Dictionary = fighter.gun.attachments
	match a.get("optic", ""):
		"reddot":
			draw_rect(Rect2(1.0, -t * 0.5 - 1.4, 2.0, 1.4), metal)
			draw_circle(Vector2(2.0, -t * 0.5 - 0.7), 0.45, Color(3.0, 0.4, 0.4))
		"scope":
			draw_rect(Rect2(-0.5, -t * 0.5 - 2.2, 6.0, 1.8), metal)
			draw_rect(Rect2(5.0, -t * 0.5 - 2.2, 0.8, 1.8), Color(0.6, 1.6, 2.4))
	if a.get("mag", "") == "extmag":
		draw_rect(Rect2(0.5, t * 0.5, 1.6, 4.2), metal)
	if a.get("stock", "") == "stock":
		draw_rect(Rect2(-7.5, -0.6, 4.0, t + 1.6), metal)
	if a.get("barrel", "") == "barrel":
		draw_rect(Rect2(L - 1.0, -0.55, 2.5, 1.1), Color(0.2, 0.2, 0.25))


## Katana : poignée, garde, lame brillante ; le coup balaie un arc avec une traînée.
func _draw_blade(d: Dictionary) -> void:
	var sw: float = fighter.gun.swing
	var ang := lerpf(1.3, -1.1, 1.0 - sw) if sw > 0.0 else -0.35
	draw_set_transform(j.pivot, gun_dir.angle() - ang * fighter.facing, Vector2(1, fighter.facing))
	var L: float = d.length
	draw_rect(Rect2(-3.5, -0.6, 4.0, 1.2), Color(0.2, 0.08, 0.08))
	draw_rect(Rect2(0.3, -1.4, 0.8, 2.8), Color(0.5, 0.45, 0.3))
	draw_line(Vector2(1.2, 0), Vector2(L, -0.6), Color(2.2, 2.4, 2.8), 1.1, Juice.hd)
	if sw > 0.0:
		for i in 5:
			var a := -0.25 * i
			var c := Color(2.0, 2.4, 3.0, 0.25 * sw * (1.0 - i / 5.0))
			draw_line(Vector2(L * 0.5, 0).rotated(a), Vector2(L, -0.6).rotated(a), c, 1.6)


func _draw_scarf() -> void:
	var col := fighter.team_color * 1.25
	var pts := PackedVector2Array()
	for p in _scarf:
		pts.append(to_local(p))
	var half := pts.size() / 2 + 1
	draw_polyline(pts.slice(0, half), col, 2.0, Juice.hd)
	draw_polyline(pts.slice(half - 1), col, 1.1, Juice.hd)


func _draw_ghosts() -> void:
	if _ghosts.is_empty():
		return
	draw_set_transform_matrix(global_transform.affine_inverse())
	for g in _ghosts:
		var k: float = 1.0 - g.age / GHOST_LIFE
		var col := Color(fighter.team_color * 2.0, k * 0.4)
		draw_multiline(g.pts, col, 2.0)
		draw_circle(g.head, 3.4, col)
	draw_set_transform(Vector2.ZERO)
