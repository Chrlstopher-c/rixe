extends RefCounted
## Tests de la manette : déplacement au stick, saut au bouton A, visée au stick droit, navigation des menus.


func names() -> Array[String]:
	return ["pad"]


func _axis(axis: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = v
	Input.parse_input_event(e)


func _button(b: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = pressed
	Input.parse_input_event(e)


func test_pad(t: Node) -> void:
	var f: Fighter = t.main.spawn_test_fighter(Vector2(400, -10), PadBrain.new(0))
	await t.until(func() -> bool: return f.is_on_floor(), 120)
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await t.frames(40)
	t.check(f.global_position.x > 430.0, "stick gauche : avance (x=%.0f)" % f.global_position.x)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_X, -1.0)
	await t.frames(3)
	t.check(f.facing == -1, "stick droit : vise à gauche")
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_button(JOY_BUTTON_A, true)
	await t.frames(3)
	_button(JOY_BUTTON_A, false)
	t.check(f.velocity.y < -100.0, "bouton A : saute")
	var key := Controls.menu_key(_pad_event(JOY_BUTTON_DPAD_DOWN))
	t.check(key == KEY_DOWN and Controls.menu_key(_pad_event(JOY_BUTTON_A)) == KEY_ENTER, "croix et A pilotent les menus")


func _pad_event(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	return e
