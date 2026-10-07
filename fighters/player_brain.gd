class_name PlayerBrain
extends RefCounted
## Intention du joueur lue au clavier/souris.


func think(f: Node2D, _delta: float) -> Dictionary:
	return {
		"move": Input.get_axis("left", "right"),
		"jump": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"drop": Input.is_action_pressed("down"),
		"dash": Input.is_action_just_pressed("dash"),
		"fire": Input.is_action_pressed("fire"),
		"melee": Input.is_action_just_pressed("melee"),
		"reload": Input.is_action_just_pressed("reload"),
		"throw": Input.is_action_just_pressed("throw"),
		"aiming": Input.is_action_pressed("aim"),
		"aim": f.get_global_mouse_position(),
	}
