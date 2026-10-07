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
	_keys("throw", [KEY_G])
	_keys("weapon1", [KEY_1])
	_keys("weapon2", [KEY_2])
	_mouse("cycle", MOUSE_BUTTON_WHEEL_UP)
	_mouse("cycle", MOUSE_BUTTON_WHEEL_DOWN)
	_keys("heal", [KEY_H])
	_keys("inventory", [KEY_TAB])
	_keys("melee", [KEY_E, KEY_F])
	_keys("focus", [KEY_X])
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


## Bouton de manette traduit en touche pour les menus (croix, A = valider, B / Start = retour) ; 0 sinon.
static func menu_key(event: InputEvent) -> int:
	if event is InputEventKey:
		return event.physical_keycode if event.pressed and not event.echo else 0
	if not (event is InputEventJoypadButton) or not event.pressed:
		return 0
	match event.button_index:
		JOY_BUTTON_DPAD_UP:
			return KEY_UP
		JOY_BUTTON_DPAD_DOWN:
			return KEY_DOWN
		JOY_BUTTON_DPAD_LEFT:
			return KEY_LEFT
		JOY_BUTTON_DPAD_RIGHT:
			return KEY_RIGHT
		JOY_BUTTON_A:
			return KEY_ENTER
		JOY_BUTTON_B, JOY_BUTTON_START:
			return KEY_ESCAPE
		JOY_BUTTON_BACK:
			return KEY_TAB
	return 0
