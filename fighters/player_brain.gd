class_name PlayerBrain
extends RefCounted
## Intention du joueur seul : clavier/souris, ou la première manette dès qu'elle sert (la dernière utilisée gagne).

var pad := PadBrain.new(0)
var _mouse_t := -99.0
var _last_mouse := Vector2.ZERO


func think(f: Node2D, delta: float) -> Dictionary:
	var kb := _keyboard(f)
	if Input.get_connected_joypads().is_empty() and not Juice.force_pad:
		return kb
	var p := pad.think(f, delta)
	var mouse := f.get_viewport().get_mouse_position()
	if mouse != _last_mouse or kb.fire or kb.move != 0.0:
		_last_mouse = mouse
		_mouse_t = Time.get_ticks_msec() / 1000.0
	return p if pad.last_used > _mouse_t else kb


func rumble(weak: float, strong: float, sec: float) -> void:
	pad.rumble(weak, strong, sec)


func _keyboard(f: Node2D) -> Dictionary:
	var building: bool = Juice.survival != null and Juice.survival.get_parent().builder.active
	return {
		"move": Input.get_axis("left", "right"),
		"jump": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"drop": Input.is_action_pressed("down"),
		"dash": Input.is_action_just_pressed("dash"),
		"fire": Input.is_action_pressed("fire") and not building,
		"melee": Input.is_action_just_pressed("melee"),
		"reload": Input.is_action_just_pressed("reload"),
		"throw": Input.is_action_just_pressed("throw"),
		"select": -1 if building else _selected(),
		"cycle": Input.is_action_just_pressed("cycle"),
		"heal": Input.is_action_just_pressed("heal"),
		"aiming": Input.is_action_pressed("aim") and not building,
		"aim": f.get_global_mouse_position(),
	}


func _selected() -> int:
	if Input.is_action_just_pressed("weapon1"):
		return 0
	return 1 if Input.is_action_just_pressed("weapon2") else -1
