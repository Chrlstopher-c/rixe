extends RefCounted
## Tests de mouvement : saut répétable après atterrissage, spam, nombre de sauts en l'air.


func names() -> Array[String]:
	return ["movement", "movement_keys", "movement_hold", "roll", "slide", "wall_jump", "parry"]


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


func _on_floor(t: Node, f: Fighter) -> void:
	await t.until(func() -> bool: return f.is_on_floor(), 120)
	await t.frames(5)


func test_roll(t: Node) -> void:
	var brain := ScriptBrain.new()
	var f: Fighter = t.main.spawn_test_fighter(Vector2(500, -10), brain)
	await _on_floor(t, f)
	brain.press_dash()
	await t.frames(3)
	t.check(f.moves.dodging(), "dash au sol = roulade invulnérable")
	var hp0 := f.hp
	f.take_hit(30.0, Vector2.RIGHT, f.global_position + Vector2(0, -20), f, 0.0)
	t.check(f.hp == hp0, "une balle pendant la roulade est esquivée")
	await t.frames(60)
	f.take_hit(30.0, Vector2.RIGHT, f.global_position + Vector2(0, -20), f, 0.0)
	t.check(f.hp < hp0, "après la roulade, on reprend des dégâts")


func test_slide(t: Node) -> void:
	var brain := ScriptBrain.new()
	var f: Fighter = t.main.spawn_test_fighter(Vector2(300, -10), brain)
	await _on_floor(t, f)
	brain.move = 1.0
	await t.frames(40)
	brain.drop = true
	await t.frames(3)
	brain.drop = false
	var cap: CapsuleShape2D = f._shape.shape
	t.check(f.moves.slide_t > 0.0 and cap.height < 30.0, "bas en pleine course = glissade, silhouette basse")
	t.check(absf(f.velocity.x) > Fighter.RUN, "la glissade va plus vite que la course")
	await t.frames(90)
	brain.move = 0.0
	t.check(f.moves.slide_t <= 0.0 and cap.height == 34.0, "fin de glissade : on se relève")


func test_wall_jump(t: Node) -> void:
	var brain := ScriptBrain.new()
	var f: Fighter = t.main.spawn_test_fighter(Vector2(40, -10), brain)
	await _on_floor(t, f)
	brain.move = -1.0
	brain.press_jump()
	await t.frames(12)
	brain.jump_held = false
	f._air_jumps = 0
	await t.until(func() -> bool: return f.is_on_wall(), 60)
	brain.press_jump()
	await t.frames(3)
	t.check(f.velocity.x > 100.0 and f.velocity.y < 0.0,
		"contre le mur, sauter repart dans l'autre sens (%s)" % f.velocity)
	brain.move = 0.0


func test_parry(t: Node) -> void:
	var ab := ScriptBrain.new()
	var db := ScriptBrain.new()
	var a: Fighter = t.main.spawn_test_fighter(Vector2(600, -10), ab)
	var d: Fighter = t.main.spawn_test_fighter(Vector2(618, -10), db)
	await t.until(func() -> bool: return a.is_on_floor() and d.is_on_floor(), 120)
	await t.frames(10)
	ab.aim = d.global_position + Vector2(0, -20)
	db.aim = a.global_position + Vector2(0, -20)
	await t.frames(2)
	var hp0 := d.hp
	db.press_melee()
	await t.frames(2)
	ab.press_melee()
	await t.frames(30)
	t.check(d.hp == hp0, "parade : pas de dégâts")
	t.check(a.moves.stunned() or a.moves.stun_t > 0.0 or absf(a.velocity.x) > 50.0, "l'attaquant est repoussé et étourdi")
