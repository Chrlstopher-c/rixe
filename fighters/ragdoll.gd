class_name Ragdoll
extends Node2D
## Cadavre physique (PBD) : membres articulés, collisions avec l'arène, démembrement et saignements.

const LINKS := [["head", "shoulder"], ["shoulder", "hip"], ["shoulder", "elbow0"], ["elbow0", "hand0"],
	["shoulder", "elbow1"], ["elbow1", "hand1"], ["hip", "knee0"], ["knee0", "foot0"], ["hip", "knee1"],
	["knee1", "foot1"]]
const GRAVITY := 900.0
const LIFE := 9.0

var pos := {}
var vel := {}
var links: Array = []
var bleeders: Array[String] = []
var color := Color.WHITE
var is_gib := false
var _age := 0.0


## pts : points présents (membres manquants absents) ; cut : liens tranchés ; bleed : points qui saignent.
func setup(pts: Dictionary, base_vel: Vector2, impulse: Vector2, bleed: Array, team: Color, cut: Array = []) -> void:
	z_index = 9
	color = team
	for k in pts:
		if k == "neck":
			continue
		pos[k] = pts[k]
		vel[k] = base_vel + impulse * randf_range(0.5, 1.3) + Vector2(randf_range(-40, 40), randf_range(-60, 0))
	if vel.has("head"):
		vel.head = vel.head + impulse * 0.5
	for l in LINKS:
		if pos.has(l[0]) and pos.has(l[1]) and not ([l[0], l[1]] in cut):
			links.append([l[0], l[1], (pts[l[0]] as Vector2).distance_to(pts[l[1]])])
	for b in bleed:
		if pos.has(b):
			bleeders.append(b)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFE:
		queue_free()
		return
	var prev := pos.duplicate()
	for k in pos:
		vel[k] = (vel[k] as Vector2 + Vector2(0, GRAVITY * delta)) * 0.998
		pos[k] = pos[k] + vel[k] * delta
	for it in 6:
		_solve_links()
	for k in pos:
		_collide(k, prev[k], delta)
	if _age < 2.5:
		_bleed(delta)
	queue_redraw()


func _solve_links() -> void:
	for l in links:
		var a: Vector2 = pos[l[0]]
		var b: Vector2 = pos[l[1]]
		var d := b - a
		var len := maxf(d.length(), 0.001)
		var corr := d * (0.5 * (len - float(l[2])) / len)
		pos[l[0]] = a + corr
		pos[l[1]] = b - corr


func _collide(k: String, prev: Vector2, delta: float) -> void:
	var p: Vector2 = pos[k]
	var fixed: Vector2 = Juice.arena.push_out(prev, p)
	if fixed != p:
		fixed.x = lerpf(fixed.x, prev.x, 0.35)
		pos[k] = fixed
	vel[k] = (pos[k] - prev) / maxf(delta, 0.0001)


func _bleed(delta: float) -> void:
	for k in bleeders:
		var pulse := maxf(sin(_age * 11.0), 0.0) * (1.0 - _age / 2.5)
		if randf() < delta * 60.0 * pulse:
			var v: Vector2 = vel[k] * 0.3 + Vector2(randf_range(-60, 60), randf_range(-160, -40))
			Effects.spurt(pos[k], v, 1)


func _draw() -> void:
	var fade := clampf((LIFE - _age) / 1.5, 0.0, 1.0)
	var c := Color(StickRig.BODY, fade)
	for l in links:
		draw_line(pos[l[0]], pos[l[1]], c, 2.6, Juice.hd)
	if pos.has("head"):
		draw_circle(pos.head, 3.7 * 1.22, c)
	for k in bleeders:
		draw_circle(pos[k], 1.2, Color(Effects.BLOOD, fade))
