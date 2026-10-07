class_name Navigator
extends RefCounted
## Déplacement vers un point : monter sur une plateforme accessible, descendre, sauter murs et trous, se débloquer.

const JUMP_REACH := 90.0
const STUCK_TIME := 0.8

var _hold := 0.0
var _stuck := 0.0
var _best := INF
var _goal := Vector2.INF
var _step_goal := Vector2.INF


## Remplit move/jump/jump_held/drop/dash dans l'intention pour aller vers goal.
func steer(f: Node2D, goal: Vector2, delta: float, it: Dictionary, mobility: float) -> void:
	_hold -= delta
	if goal.distance_to(_goal) > 40.0:
		_goal = goal
		_best = INF
		_stuck = 0.0
	var pos: Vector2 = f.global_position
	var target := _waypoint(f, goal)
	var dx := target.x - pos.x
	it.move = signf(dx) if absf(dx) > 6.0 else 0.0
	if target.y < pos.y - 20.0:
		_climb(f, target, it)
	elif goal.y > pos.y + 30.0 and f.is_on_floor():
		it.drop = true
	_obstacles(f, it)
	_unstick(f, goal, delta, it, mobility)
	it.jump_held = it.jump_held or _hold > 0.0


## Point intermédiaire : sous une plateforme accessible si le but est plus haut, sinon le but lui-même.
func _waypoint(f: Node2D, goal: Vector2) -> Vector2:
	var pos: Vector2 = f.global_position
	if goal.y > pos.y - 30.0:
		return goal
	var best := Vector2.INF
	var best_cost := INF
	for r: Rect2 in Juice.arena.platforms:
		var up := pos.y - r.position.y
		if up < 15.0 or up > JUMP_REACH * 1.7:
			continue
		var x := clampf(goal.x, r.position.x + 10.0, r.end.x - 10.0)
		if Juice.arena.terrain.at(Vector2(x, r.position.y + 1.0)) != Terrain.K.PLAT:
			continue
		var cost := absf(x - pos.x) + absf(x - goal.x) * 0.6 + up * 0.5
		if cost < best_cost:
			best_cost = cost
			best = Vector2(x, r.position.y)
	return best if best != Vector2.INF else goal


func _climb(f: Node2D, target: Vector2, it: Dictionary) -> void:
	var pos: Vector2 = f.global_position
	var under := absf(target.x - pos.x) < 40.0
	if f.is_on_floor() and under:
		it.jump = true
		_hold = 0.4
	elif not f.is_on_floor() and f.velocity.y > -40.0 and pos.y > target.y + 4.0:
		it.jump = true
		_hold = 0.3


func _obstacles(f: Node2D, it: Dictionary) -> void:
	if not f.is_on_floor() or it.move == 0.0:
		return
	var pos: Vector2 = f.global_position
	var ahead := pos + Vector2(it.move * 12.0, 3.0)
	var hole: bool = not Juice.arena.solid_at(ahead) and not Juice.arena.solid_at(ahead + Vector2(0, 10))
	if f.is_on_wall() or (hole and pos.y < 1.0):
		it.jump = true
		_hold = 0.25


func _unstick(f: Node2D, goal: Vector2, delta: float, it: Dictionary, mobility: float) -> void:
	var d: float = f.global_position.distance_to(goal)
	if d < _best - 4.0:
		_best = d
		_stuck = 0.0
		return
	_stuck += delta
	if _stuck > STUCK_TIME and d > 30.0:
		_stuck = 0.0
		_best = INF
		it.jump = true
		_hold = 0.4
		if randf() < mobility:
			it.dash = true
