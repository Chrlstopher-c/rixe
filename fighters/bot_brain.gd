class_name BotBrain
extends RefCounted
## IA de bot : choix de cible, distance idéale selon l'arme, sauts/descentes de plateformes, visée imparfaite, esquive.

var skill := 0.6
var target: Node2D
var _retarget := 0.0
var _aim := Vector2.ZERO
var _err := Vector2.ZERO
var _strafe := 1.0
var _strafe_t := 0.0
var _react := 0.4
var _hold := 0.0


func _init(level: float = 0.6) -> void:
	skill = level


func think(f: Node2D, delta: float) -> Dictionary:
	var it := {"move": 0.0, "jump": false, "jump_held": _hold > 0.0, "drop": false, "dash": false, "fire": false,
		"aim": f.global_position + Vector2(f.facing * 60, -20)}
	_hold -= delta
	_retarget -= delta
	if _retarget <= 0.0 or not is_instance_valid(target) or not target.alive:
		target = _pick(f)
		_retarget = randf_range(1.5, 3.5)
		_react = lerpf(1.0, 0.4, skill)
	if not is_instance_valid(target):
		return it
	var to: Vector2 = target.global_position - f.global_position
	it.move = _horizontal(f, to, delta)
	_vertical(f, to, it)
	_shoot(f, delta, it)
	if f.recent_hit > 0.0 and randf() < delta * 2.0 * skill:
		it.dash = true
	return it


func _pick(f: Node2D) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for o in f.get_tree().get_nodes_in_group("fighters"):
		if o == f or not o.alive:
			continue
		var d: float = f.global_position.distance_to(o.global_position) * randf_range(0.7, 1.3)
		if d < best_d:
			best_d = d
			best = o
	return best


func _horizontal(f: Node2D, to: Vector2, delta: float) -> float:
	var ideal: float = f.gun.def.ideal
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe = [-1.0, 1.0, 0.0].pick_random()
		_strafe_t = randf_range(0.3, 1.0)
	if absf(to.y) > 50.0:
		return signf(to.x) if absf(to.x) > 24.0 else _strafe
	if absf(to.x) > ideal + 40.0:
		return signf(to.x)
	if absf(to.x) < ideal - 50.0:
		return -signf(to.x)
	return _strafe


func _vertical(f: Node2D, to: Vector2, it: Dictionary) -> void:
	if f.is_on_floor() and (to.y < -45.0 or f.is_on_wall()) and randf() < 0.08:
		it.jump = true
		_hold = 0.35
	elif not f.is_on_floor() and f.velocity.y > -30.0 and to.y < -60.0 and randf() < 0.1:
		it.jump = true
		_hold = 0.3
	if to.y > 45.0 and randf() < 0.05:
		it.drop = true


func _shoot(f: Node2D, delta: float, it: Dictionary) -> void:
	var chest: Vector2 = target.global_position + Vector2(0, -22)
	if _err == Vector2.ZERO or randf() < delta * 3.0:
		_err = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * lerpf(40.0, 14.0, skill)
	if _aim == Vector2.ZERO:
		_aim = chest
	_aim = _aim.lerp(chest + _err, minf(delta * lerpf(2.5, 7.0, skill), 1.0))
	it.aim = _aim
	var seen := _line_of_sight(f, chest)
	_react = _react - delta if seen else lerpf(1.0, 0.4, skill)
	var in_range: bool = f.global_position.distance_to(chest) < float(f.gun.def.range) * 0.9
	it.fire = seen and _react <= 0.0 and in_range


func _line_of_sight(f: Node2D, to: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = f.get_world_2d().direct_space_state
	var from: Vector2 = f.global_position + Vector2(0, -27)
	var q := PhysicsRayQueryParameters2D.create(from, to, Juice.MASK_WORLD | Juice.MASK_PLATFORMS)
	return space.intersect_ray(q).is_empty()
