extends Camera2D
## Caméra : suit la cible avec anticipation de visée, tremblement par bruit, punch de zoom ; expose sa vitesse (flou).

var base_zoom := 1.15

var target: Node2D
var velocity := Vector2.ZERO
var _noise := FastNoiseLite.new()
var _t := 0.0
var _last := Vector2.ZERO


func _ready() -> void:
	_noise.frequency = 1.0
	ignore_rotation = false


func snap_to(pos: Vector2) -> void:
	global_position = pos
	_last = get_screen_center_position()


func _process(delta: float) -> void:
	var real: float = Juice.real_delta(delta)
	_t += real
	var goal := _follow_goal() if is_instance_valid(target) else global_position
	goal = goal.lerp(Juice.focus, Juice.focus_w)
	global_position = global_position.lerp(goal, 1.0 - exp(-(5.0 + Juice.focus_w * 6.0) * real))
	var s := Juice.trauma * Juice.trauma
	offset = Vector2(_noise.get_noise_2d(_t * 30.0, 0.0), _noise.get_noise_2d(0.0, _t * 30.0)) * 9.0 * s
	rotation = _noise.get_noise_2d(_t * 20.0, 50.0) * 0.035 * s
	zoom = Vector2.ONE * (base_zoom + Juice.zoom_punch + smoothstep(0.0, 1.0, Juice.focus_w) * 0.55)
	var center := get_screen_center_position()
	velocity = (center - _last) / maxf(real, 0.0001)
	_last = center


func _follow_goal() -> Vector2:
	var aim: Vector2 = target.get("aim_dir")
	var goal: Vector2 = target.global_position + Vector2(0, -34) + aim * 36.0 + target.get("velocity") * 0.12
	if target.get("aiming"):
		var far: float = target.get("gun").def.get("ads_reach", 1.0)
		var reach: Vector2 = (target.get("aim_point") - target.global_position) * 0.45 * far
		goal += reach.limit_length(170.0 * far)
	return goal
