extends RefCounted
## Tests de mouvement : saut répétable après atterrissage, spam, nombre de sauts en l'air.


func names() -> Array[String]:
	return ["movement", "movement_keys", "movement_hold"]


func test_movement(t: Node) -> void:
	var brain := ScriptBrain.new()
	var f: Fighter = t.main.spawn_test_fighter(Vector2(400, -10), brain)
	t.check(await t.until(func() -> bool: return f.is_on_floor(), 120), "le combattant se pose au sol")
	for i in 6:
		brain.press_jump()
		await t.frames(2)
		t.check(f.velocity.y < -100.0, "saut n°%d après atterrissage (vy=%.0f)" % [i + 1, f.velocity.y])
		brain.jump_held = false
		t.check(await t.until(func() -> bool: return f.is_on_floor(), 240), "retombe au sol après le saut %d" % (i + 1))
		await t.frames(1)
	await _air_jumps(t, f, brain)


func _air_jumps(t: Node, f: Fighter, brain: ScriptBrain) -> void:
	var air := [0]
	f.jumped.connect(func(in_air: bool) -> void: air[0] += int(in_air))
	brain.press_jump()
	await t.frames(12)
	brain.jump_held = false
	for i in 4:
		brain.press_jump()
		await t.frames(2)
		brain.jump_held = false
		await t.frames(8)
	t.check(air[0] == 2, "exactement 2 sauts en l'air (obtenu %d)" % air[0])


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func test_movement_keys(t: Node) -> void:
	var f: Fighter = t.main.spawn_test_fighter(Vector2(400, -10), PlayerBrain.new())
	t.check(await t.until(func() -> bool: return f.is_on_floor(), 120), "posé au sol")
	var count := [0]
	f.jumped.connect(func(_a: bool) -> void: count[0] += 1)
	for i in 5:
		for code: Key in [KEY_SPACE, KEY_W]:
			_key(code, true)
			await t.frames(3)
			_key(code, false)
			t.check(await t.until(func() -> bool: return f.is_on_floor() and f.velocity.y >= 0.0, 240), "atterrit")
			await t.frames(2)
	t.check(count[0] == 10, "10 sauts au clavier enchaînés (obtenu %d)" % count[0])


func test_movement_hold(t: Node) -> void:
	var brain := ScriptBrain.new()
	var f: Fighter = t.main.spawn_test_fighter(Vector2(400, -10), brain)
	await t.until(func() -> bool: return f.is_on_floor(), 120)
	var ground := [0]
	f.jumped.connect(func(in_air: bool) -> void: ground[0] += int(not in_air))
	brain.press_jump()
	await t.frames(360)
	t.check(ground[0] >= 3, "touche maintenue = rebonds enchaînés (obtenu %d en 3 s)" % ground[0])
