class_name Intro
extends CanvasLayer
## Intro au lancement (à la place du logo Godot) : courte cinématique de combat sur sa musique (IntroChoreo), coups
## qui font gicler sang et dents, ralenti sur le coup de pied sauté qui décapite, puis le titre RIXE s'abat et saigne.
## Une touche ou un clic la passe.

signal finished

const BG := Color(0.02, 0.01, 0.04)
const HERO_COL := Color(0.3, 0.9, 1.0)
const RIVAL_COL := Color(1.0, 0.45, 0.2)
const LETTERS := 4.6
const LETTER_GAP := 0.12
const FADE := 7.0
const END := 7.5
const BLOOD := Color(1.5, 0.05, 0.08)
const MUSIC := preload("res://assets/music/intro.wav")

var t := 0.0
var _canvas := Control.new()
var _font: Font = ThemeDB.fallback_font
var _player := AudioStreamPlayer.new()
## Particules : {p, v, s, kind ("blood", "tooth", "dust"), rest}.
var _bits: Array[Dictionary] = []
var _head := {}
var _flashes: Array[Vector3] = []
var _shake := 0.0
var _played := {}
var _drips: Array[Vector3] = []


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_intro)
	add_child(_canvas)
	_player.stream = MUSIC
	add_child(_player)
	if Settings.persist:
		_player.play()


func skip() -> void:
	t = maxf(t, FADE)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return
	if event.is_pressed():
		skip()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	t += dt
	_shake = maxf(_shake - dt * 2.5, 0.0)
	_fire_events()
	_step(dt * IntroChoreo.physics_speed(t))
	if t >= FADE:
		_player.volume_db = linear_to_db(maxf(1.0 - (t - FADE) / (END - FADE), 0.001))
	if t >= END:
		finished.emit()
		queue_free()
		return
	_canvas.queue_redraw()


## Vrai une seule fois, quand le temps dépasse `at` (sons et coups sautés après un passage forcé).
func _once(at: float, tag: String) -> bool:
	var key := "%s@%.2f" % [tag, at]
	if t < at or _played.has(key):
		return false
	_played[key] = true
	return t < FADE


func _fire_events() -> void:
	for h: Array in IntroChoreo.HITS:
		if _once(h[0], "hit"):
			_hit(h)
	for s: Array in IntroChoreo.SOUNDS:
		if _once(s[0], "sfx"):
			Sfx.play_ui(s[1], s[2])
			if s[1] == "land":
				_dust(_fighter("hero").j.foot0)
	for i in 4:
		if _once(LETTERS + i * LETTER_GAP, "letter"):
			_shake = 0.35 if i < 3 else 0.8
			Sfx.play_ui("impact", 2.0)


func _fighter(who: String) -> Dictionary:
	if who == "hero":
		return IntroChoreo.sample(IntroChoreo.HERO, t, 1.0)
	return IntroChoreo.sample(IntroChoreo.RIVAL, t, -1.0)


func _hit(h: Array) -> void:
	var at: Vector2 = _fighter(h[1]).j[h[2]]
	Sfx.play_ui(h[6], 4.0)
	_flashes.append(Vector3(at.x, at.y, t))
	var decap: bool = t >= IntroChoreo.DECAP
	_shake = 0.9 if decap else 0.5
	if decap:
		Sfx.play_ui("headshot", 4.0)
		_head = {"p": at, "v": Vector2(170, -330), "r": 0.0}
	for i in int(h[4]):
		var v := Vector2.from_angle(randf_range(-1.3, 0.4)) * randf_range(60, 420 if decap else 260)
		_bits.append({"p": at, "v": v * Vector2(h[3], 1), "s": randf_range(1.2, 3.6 if decap else 2.6),
			"kind": "blood", "rest": false})
	if h[5]:
		for i in 3 if decap else 2:
			var v := Vector2(h[3] * randf_range(80, 200), randf_range(-260, -120))
			_bits.append({"p": at, "v": v, "s": 2.4, "kind": "tooth", "rest": false})


func _dust(at: Vector2) -> void:
	for i in 10:
		_bits.append({"p": at, "v": Vector2(randf_range(-90, 90), randf_range(-60, -10)), "s": 2.0,
			"kind": "dust", "rest": false})


func _step(dt: float) -> void:
	if t >= IntroChoreo.DECAP and t < IntroChoreo.DECAP + 1.0 and _bits.size() < 900:
		var neck: Vector2 = _fighter("rival").j.shoulder
		for i in 3:
			var v := Vector2(randf_range(10, 120), randf_range(-320, -160))
			_bits.append({"p": neck, "v": v, "s": randf_range(1.4, 3.0), "kind": "blood", "rest": false})
	for b in _bits:
		if b.rest:
			continue
		b.v.y += (120.0 if b.kind == "dust" else 700.0) * dt
		b.p += b.v * dt
		if b.p.y >= 0.0:
			b.p.y = 0.0
			b.rest = true
	if not _head.is_empty() and _head.p.y < -IntroFighter.HEAD:
		_head.v.y += 700.0 * dt
		_head.p += _head.v * dt
		_head.r += dt * 11.0
	for i in _drips.size():
		_drips[i].z = minf(_drips[i].z + dt * 26.0, 44.0)


func _draw_intro() -> void:
	var s := _canvas.size
	var a := 1.0 - clampf((t - FADE) / (END - FADE), 0.0, 1.0)
	_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(BG, a))
	var cam := IntroChoreo.camera(t)
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 7.0
	_canvas.draw_set_transform_matrix(Transform2D(0.0, Vector2(cam.z, cam.z), 0.0,
		Vector2(s.x * 0.5, s.y * 0.5) + shake) * Transform2D(0.0, -Vector2(cam.x, cam.y)))
	_draw_world(a)
	_canvas.draw_set_transform(Vector2.ZERO)
	_draw_overlays(s, a)
	_draw_title(s, a)


func _draw_world(a: float) -> void:
	var appear := clampf(t / 0.3, 0.0, 1.0) * a
	_canvas.draw_line(Vector2(-900, 1), Vector2(900, 1), Color(0.3, 0.26, 0.36, 0.6 * appear), 1.5)
	for k in [0.07, 0.035]:
		var w := 0.22 if k < 0.05 else 0.1
		IntroFighter.trail(_canvas, IntroChoreo.sample(IntroChoreo.HERO, t - k, 1.0), HERO_COL, w * appear)
		IntroFighter.trail(_canvas, IntroChoreo.sample(IntroChoreo.RIVAL, t - k, -1.0), RIVAL_COL, w * appear)
	IntroFighter.body(_canvas, _fighter("rival"), RIVAL_COL, appear, t < IntroChoreo.DECAP)
	IntroFighter.body(_canvas, _fighter("hero"), HERO_COL, appear, true)
	for b in _bits:
		var col: Color = BLOOD if b.kind == "blood" else (Color(2.2, 2.1, 1.9) if b.kind == "tooth" else
			Color(0.5, 0.45, 0.5, 0.5))
		var size := Vector2(b.s, b.s if not b.rest else b.s * 0.5)
		_canvas.draw_rect(Rect2(b.p - size * 0.5, size), Color(col, col.a * a))
	if not _head.is_empty():
		IntroFighter.head(_canvas, _head.p, -1.0, "dead", RIVAL_COL, a)
	for f in _flashes:
		var k := (t - f.z) / 0.14
		if k < 1.0:
			for i in 8:
				var dir := Vector2.from_angle(i * TAU / 8.0 + f.z)
				_canvas.draw_line(Vector2(f.x, f.y) + dir * 6.0, Vector2(f.x, f.y) + dir * (10.0 + 26.0 * k),
					Color(3.0, 2.8, 2.4, (1.0 - k) * a), 2.0)


## Bandes noires pendant le ralenti, éclair blanc à la décapitation.
func _draw_overlays(s: Vector2, a: float) -> void:
	var slow := IntroChoreo.SLOW
	var bars := clampf(minf((t - slow.x + 0.1) / 0.15, (slow.y + 0.35 - t) / 0.2), 0.0, 1.0) * 40.0
	if bars > 0.0:
		_canvas.draw_rect(Rect2(0, 0, s.x, bars), Color(0, 0, 0, a))
		_canvas.draw_rect(Rect2(0, s.y - bars, s.x, bars), Color(0, 0, 0, a))
	var flash := 1.0 - (t - IntroChoreo.DECAP) / 0.12
	if flash > 0.0 and flash <= 1.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(1.6, 1.3, 1.3, 0.3 * flash * a))


## Le titre : chaque lettre tombe de haut et grossie, avec un décalage rouge / cyan, puis saigne.
func _draw_title(s: Vector2, a: float) -> void:
	var size := 116
	var word := "RIXE"
	var total := _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 3 * 12.0
	var x := (s.x - total) * 0.5
	var base_y := 132.0
	_draw_smear(Vector2(s.x * 0.5, base_y - size * 0.32), total + 60.0, a)
	for i in word.length():
		var ch := word[i]
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var k := clampf((t - LETTERS - i * LETTER_GAP) / 0.12, 0.0, 1.0)
		if k > 0.0:
			if k >= 1.0 and _drips.size() < 14 and randf() < 0.12:
				_drips.append(Vector3(x + randf_range(4, w - 4), base_y + 4.0, 0.0))
			_draw_letter(ch, Vector2(x + w * 0.5, base_y - size * 0.35), w, size, k, a)
		x += w + 12.0
	_canvas.draw_set_transform(Vector2.ZERO)
	for d in _drips:
		_canvas.draw_line(Vector2(d.x, d.y), Vector2(d.x, d.y + d.z), Color(BLOOD, a), 2.0)
		_canvas.draw_circle(Vector2(d.x, d.y + d.z), 1.6, Color(BLOOD, a))


func _draw_letter(ch: String, center: Vector2, w: float, size: int, k: float, a: float) -> void:
	var sc := lerpf(2.4, 1.0, ease(k, 0.4))
	_canvas.draw_set_transform(center + Vector2(randf_range(-1, 1), 0) * _shake * 6.0, 0.0, Vector2(sc, sc))
	var p := Vector2(-w * 0.5, size * 0.35)
	var spread := 2.0 + _shake * 6.0
	_canvas.draw_string(_font, p + Vector2(-spread, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(2.0, 0.1, 0.15, 0.6 * k * a))
	_canvas.draw_string(_font, p + Vector2(spread, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0.2, 1.4, 2.0, 0.5 * k * a))
	_canvas.draw_string(_font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.6, 1.5, 1.5, k * a))


## Traînée de sang derrière le titre, tirée d'un coup au dernier impact.
func _draw_smear(center: Vector2, width: float, a: float) -> void:
	var k := clampf((t - LETTERS - 3 * LETTER_GAP) / 0.18, 0.0, 1.0)
	if k <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var left := center.x - width * 0.5
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 25:
		var x := left + width * k * i / 24.0
		var h := 34.0 * sin(PI * i / 24.0) + rng.randf_range(4, 12)
		top.append(Vector2(x, center.y - h * 0.5 + rng.randf_range(-3, 3)))
		bottom.append(Vector2(x, center.y + h * 0.5 + rng.randf_range(-3, 3)))
	bottom.reverse()
	_canvas.draw_colored_polygon(top + bottom, Color(0.55, 0.02, 0.04, 0.85 * a))
