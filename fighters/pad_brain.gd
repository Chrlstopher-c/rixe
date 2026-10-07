class_name PadBrain
extends RefCounted
## Intention d'un joueur à la manette (appareil n°) : sticks, gâchettes, boutons ; légère aide à la visée.

const DEAD := 0.25
const REACH := 140.0

var device := 0
var _prev := {}
var _aim := Vector2.RIGHT
## Dernière activité (secondes de jeu) : permet au clavier/souris de reprendre la main.
var last_used := -99.0


func _init(dev: int = 0) -> void:
	device = dev


func think(f: Node2D, _delta: float) -> Dictionary:
	var move := _axis(JOY_AXIS_LEFT_X)
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		move = -1.0
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		move = 1.0
	var stick := Vector2(_axis(JOY_AXIS_RIGHT_X), _axis(JOY_AXIS_RIGHT_Y))
	if stick != Vector2.ZERO:
		_aim = stick.normalized()
	var chest: Vector2 = f.global_position + Vector2(0, -22)
	var it := {
		"move": move,
		"jump": _just(JOY_BUTTON_A),
		"jump_held": Input.is_joy_button_pressed(device, JOY_BUTTON_A),
		"drop": _axis(JOY_AXIS_LEFT_Y) > 0.6 or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN),
		"dash": _just(JOY_BUTTON_LEFT_SHOULDER),
		"fire": Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.4,
		"aiming": Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > 0.4,
		"melee": _just(JOY_BUTTON_B),
		"reload": _just(JOY_BUTTON_X),
		"throw": _just(JOY_BUTTON_RIGHT_SHOULDER),
		"cycle": _just(JOY_BUTTON_Y),
		"heal": _just(JOY_BUTTON_DPAD_UP),
		"focus": _just(JOY_BUTTON_LEFT_STICK),
		"select": -1,
		"aim": chest + _assist(f, chest, _aim) * REACH,
	}
	if move != 0.0 or stick != Vector2.ZERO or it.fire or it.jump_held:
		last_used = Time.get_ticks_msec() / 1000.0
	return it


func _axis(a: JoyAxis) -> float:
	var v := Input.get_joy_axis(device, a)
	return 0.0 if absf(v) < DEAD else v


## Bouton tout juste enfoncé (front montant), suivi par appareil.
func _just(b: JoyButton) -> bool:
	var now := Input.is_joy_button_pressed(device, b)
	var was: bool = _prev.get(b, false)
	_prev[b] = now
	return now and not was


## Aide à la visée : si un adversaire est presque dans l'axe, la visée glisse vers lui.
func _assist(f: Node2D, chest: Vector2, dir: Vector2) -> Vector2:
	var best := dir
	var best_off := 0.18
	for o in f.get_tree().get_nodes_in_group("fighters"):
		if o == f or not o.alive:
			continue
		var to: Vector2 = o.global_position + Vector2(0, -22) - chest
		var off := absf(dir.angle_to(to))
		if to.length() < 360.0 and off < best_off:
			best_off = off
			best = dir.slerp(to.normalized(), 0.6)
	return best


## Vibration courte (coups reçus, tirs lourds).
func rumble(weak: float, strong: float, sec: float) -> void:
	Input.start_joy_vibration(device, weak, strong, sec)
