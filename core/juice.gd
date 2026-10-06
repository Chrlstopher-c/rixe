extends Node
## Autoload : temps de jeu (hitstop, ralenti), tremblement, ondes de choc, références partagées de la scène.

signal fighter_killed(victim: Node2D, killer: Node2D)

const MASK_WORLD := 1
const MASK_FIGHTERS := 2
const MASK_PLATFORMS := 4

var fx: Node2D
var stains: Node2D
var arena: Node2D
var world: Node2D
var camera: Camera2D
var hd := true
var trauma := 0.0
var aberration := 0.0
var zoom_punch := 0.0
var shockwaves: Array[Dictionary] = []
var _hitstop := 0.0
var _slowmo := 0.0
var _slowmo_scale := 1.0
var _stopped := false


func _process(delta: float) -> void:
	var real := real_delta(delta)
	trauma = maxf(trauma - real * 1.5, 0.0)
	aberration = move_toward(aberration, 0.0, real * 2.5)
	zoom_punch = lerpf(zoom_punch, 0.0, minf(real * 6.0, 1.0))
	for w in shockwaves:
		w.age += real
	shockwaves = shockwaves.filter(func(w: Dictionary) -> bool: return w.age < w.life)
	_tick_time(real)


func real_delta(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.01)


func _tick_time(real: float) -> void:
	_hitstop -= real
	_slowmo -= real
	if _hitstop > 0.0:
		Engine.time_scale = 0.02
		_stopped = true
		return
	var goal := _slowmo_scale if _slowmo > 0.0 else 1.0
	if _stopped:
		Engine.time_scale = goal
		_stopped = false
	Engine.time_scale = lerpf(Engine.time_scale, goal, minf(real * 7.0, 1.0))


func hitstop(sec: float) -> void:
	_hitstop = maxf(_hitstop, sec)


func slowmo(sec: float, scale: float) -> void:
	_slowmo = maxf(_slowmo, sec)
	_slowmo_scale = scale


func shake(amount: float, at: Vector2 = Vector2.INF) -> void:
	if at != Vector2.INF and camera:
		amount *= clampf(1.0 - camera.get_screen_center_position().distance_to(at) / 520.0, 0.0, 1.0)
	trauma = minf(trauma + amount, 1.0)


func shockwave(pos: Vector2, strength: float = 1.0) -> void:
	shockwaves.append({"pos": pos, "age": 0.0, "life": 0.5, "strength": strength})
	if shockwaves.size() > 4:
		shockwaves.pop_front()


func reset() -> void:
	trauma = 0.0
	aberration = 0.0
	zoom_punch = 0.0
	shockwaves.clear()
	_hitstop = 0.0
	_slowmo = 0.0
	Engine.time_scale = 1.0
