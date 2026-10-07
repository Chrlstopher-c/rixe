class_name Aimer
extends RefCounted
## Visée humaine : temps de réaction, suivi par ressort (dépasse la cible quand elle bouge vite), erreur qui dérive,
## tirs en rafales.

var p: Personality
var point := Vector2.ZERO
var _vel := Vector2.ZERO
var _err := Vector2.ZERO
var _err_goal := Vector2.ZERO
var _react := 0.0
var _burst_left := 0
var _pause := 0.0
var _target: Node2D


func _init(personality: Personality) -> void:
	p = personality


## Nouveau regard (cible changée ou revue après l'avoir perdue) : repart sur un temps de réaction.
func acquire(target: Node2D) -> void:
	if target != _target:
		_target = target
		_react = p.reaction * randf_range(0.8, 1.4)
		_burst_left = 0


func track(target_point: Vector2, target_vel: Vector2, delta: float) -> void:
	_react -= delta
	if randf() < delta * 2.5:
		_err_goal = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * lerpf(34.0, 4.0, p.accuracy)
	_err = _err.lerp(_err_goal, minf(delta * 4.0, 1.0))
	var goal := target_point + target_vel * 0.08 + _err
	if point == Vector2.ZERO:
		point = goal
	var k := lerpf(40.0, 160.0, p.accuracy)
	var damp := 2.0 * sqrt(k) * lerpf(0.55, 0.95, p.accuracy)
	_vel += ((goal - point) * k - _vel * damp) * delta
	point += _vel * delta


## Décide d'appuyer sur la détente : réaction écoulée, visée assez juste, rythme de rafale.
func trigger(from: Vector2, target_point: Vector2, delta: float) -> bool:
	if _react > 0.0:
		return false
	_pause -= delta
	if _pause > 0.0:
		return false
	var off := absf((point - from).angle_to(target_point - from))
	if off > lerpf(0.28, 0.08, p.accuracy):
		return false
	if _burst_left <= 0:
		_burst_left = maxi(1, p.burst + randi_range(-1, 2))
	return true


## Appelé après un tir effectif : décompte la rafale, pause entre deux rafales.
func shot() -> void:
	_burst_left -= 1
	if _burst_left <= 0:
		_pause = randf_range(0.15, 0.5) * (1.6 - p.aggression)
