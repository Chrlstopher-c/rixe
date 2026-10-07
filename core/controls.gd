class_name Controls
## Actions clavier/souris, en touches physiques (ZQSD sur AZERTY = WASD sur QWERTY).


static func register() -> void:
	_keys("left", [KEY_A, KEY_LEFT])
	_keys("right", [KEY_D, KEY_RIGHT])
	_keys("jump", [KEY_W, KEY_SPACE, KEY_UP])
	_keys("down", [KEY_S, KEY_DOWN])
	_keys("dash", [KEY_SHIFT])
	_keys("fire", [KEY_J])
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_keys("reload", [KEY_R])
	_keys("melee", [KEY_E, KEY_F])
	_mouse("melee", MOUSE_BUTTON_MIDDLE)


static func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


static func _keys(action: String, codes: Array) -> void:
	_ensure(action)
	for code: Key in codes:
		var e := InputEventKey.new()
		e.physical_keycode = code
		InputMap.action_add_event(action, e)


static func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
