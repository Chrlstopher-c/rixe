class_name Intro
extends CanvasLayer
## Intro au lancement (à la place du logo Godot) : un tireur abat un stickman d'une balle dans la tête, puis le titre
## RIXE s'abat lettre par lettre et saigne ; fondu vers l'écran titre. Une touche ou un clic la passe.

signal finished

const BG := Color(0.02, 0.01, 0.04)
const SHOT := 0.55
const HIT := 0.62
const LETTERS := 1.05
const LETTER_GAP := 0.13
const FADE := 3.0
const END := 3.5
const FLOOR := 292.0
const SCALE := 3.2
const SHOOTER := Color(0.3, 0.9, 1.0)
const VICTIM := Color(1.0, 0.45, 0.2)
const POSE := {"head": Vector2(1, -31), "shoulder": Vector2(0, -25.5), "hip": Vector2(0, -15),
	"knee0": Vector2(-2.5, -7.5), "foot0": Vector2(-3.5, 0), "knee1": Vector2(3, -7.5), "foot1": Vector2(3.5, 0),
	"elbow0": Vector2(5, -24.5), "hand0": Vector2(11, -25), "elbow1": Vector2(4, -22), "hand1": Vector2(9, -24)}
const BONES := [["hip", "shoulder"], ["hip", "knee0"], ["knee0", "foot0"], ["hip", "knee1"], ["knee1", "foot1"],
	["shoulder", "elbow0"], ["elbow0", "hand0"], ["shoulder", "elbow1"], ["elbow1", "hand1"]]

var t := 0.0
var _canvas := Control.new()
var _font: Font = ThemeDB.fallback_font
var _blood: Array[Dictionary] = []
var _head := {}
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


func skip() -> void:
	t = maxf(t, FADE)


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) \
			and event.is_pressed():
		skip()
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	t += dt
	_shake = maxf(_shake - dt * 2.5, 0.0)
	_cue(SHOT, "rifle", 2.0)
	if _cue(HIT, "headshot", 4.0):
		_burst()
	for i in 4:
		if _cue(LETTERS + i * LETTER_GAP, "impact", 2.0):
			_shake = 0.35 if i < 3 else 0.7
	_cue(LETTERS + 3 * LETTER_GAP, "gore", 0.0)
	_step_blood(dt)
	if t >= END:
		finished.emit()
		queue_free()
		return
	_canvas.queue_redraw()


## Joue un son une seule fois quand le temps passe `at` ; vrai à ce moment-là.
func _cue(at: float, sound: String, db: float) -> bool:
	if t < at or _played.has(at):
		return false
	_played[at] = true
	if t < FADE:
		Sfx.play_ui(sound, db)
	return true


func _burst() -> void:
	_shake = 0.6
	var at := _victim_at() + POSE.head * Vector2(-SCALE, SCALE)
	_head = {"p": at, "v": Vector2(150, -260), "r": 0.0}
	for i in 46:
		var v := Vector2.from_angle(randf_range(-1.1, 0.5)) * randf_range(60, 340)
		_blood.append({"p": at, "v": v, "s": randf_range(1.0, 2.6), "rest": false})


func _step_blood(dt: float) -> void:
	for b in _blood:
		if b.rest:
			continue
		b.v.y += 620.0 * dt
		b.p += b.v * dt
		if b.p.y >= FLOOR:
			b.p.y = FLOOR
			b.rest = true
	if not _head.is_empty() and _head.p.y < FLOOR - 5.0:
		_head.v.y += 620.0 * dt
		_head.p += _head.v * dt
		_head.r += dt * 9.0
	for i in _drips.size():
		_drips[i].z = minf(_drips[i].z + dt * 26.0, 40.0)


func _victim_at() -> Vector2:
	return Vector2(_canvas.size.x * 0.5 + 130.0, FLOOR)


func _draw_intro() -> void:
	var s := _canvas.size
	var fade := clampf((t - FADE) / (END - FADE), 0.0, 1.0)
	var a := 1.0 - fade
	_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(BG, a))
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 6.0
	_canvas.draw_set_transform(off)
	var appear := clampf(t / 0.35, 0.0, 1.0) * a
	_canvas.draw_line(Vector2(0, FLOOR + 1), Vector2(s.x, FLOOR + 1), Color(0.25, 0.22, 0.3, 0.5 * appear), 1.0)
	var shooter := Vector2(s.x * 0.5 - 150.0, FLOOR)
	_draw_figure(shooter, 1.0, SHOOTER, 0.0, true, appear)
	var fall := clampf((t - HIT) / 0.45, 0.0, 1.0)
	_draw_figure(_victim_at(), -1.0, VICTIM, ease(fall, 2.2) * 1.45, t < HIT, appear)
	_draw_shot(shooter, a)
	for b in _blood:
		_canvas.draw_rect(Rect2(b.p, Vector2(b.s, b.s if not b.rest else b.s * 0.6)), Color(1.4, 0.06, 0.08, a))
	if not _head.is_empty():
		_canvas.draw_circle(_head.p, 4.4 * SCALE, Color(VICTIM * 1.4, 0.9 * a))
		_canvas.draw_circle(_head.p, 3.7 * SCALE, Color(0.035, 0.03, 0.055, a))
	_draw_title(s, a)
	_canvas.draw_set_transform(Vector2.ZERO)


func _draw_figure(at: Vector2, facing: float, col: Color, tilt: float, with_head: bool, a: float) -> void:
	var j := {}
	for k: String in POSE:
		j[k] = at + (POSE[k] * Vector2(facing * SCALE, SCALE)).rotated(tilt * -facing)
	var dark := Color(0.035, 0.03, 0.055, a)
	for b in BONES:
		_canvas.draw_line(j[b[0]], j[b[1]], Color(col * 1.5, 0.85 * a), 3.4 * SCALE * 0.5, true)
		_canvas.draw_line(j[b[0]], j[b[1]], dark, 2.2 * SCALE * 0.5, true)
	var hand: Vector2 = j.hand0
	_canvas.draw_line(hand, hand + Vector2(facing * 16.0, 0).rotated(tilt * -facing), Color(0.3, 0.3, 0.35, a), 3.0)
	if with_head:
		_canvas.draw_circle(j.head, 4.4 * SCALE, Color(col * 1.5, 0.85 * a))
		_canvas.draw_circle(j.head, 3.7 * SCALE, dark)
		_canvas.draw_line(j.head + Vector2(facing * 3.0, -1), j.head + Vector2(facing * 8.0, -1), col * 3.0, 2.0)
	elif t >= HIT:
		_canvas.draw_circle(j.shoulder + (j.shoulder - j.hip).normalized() * 6.0, 3.0, Color(1.4, 0.06, 0.08, a))


func _draw_shot(shooter: Vector2, a: float) -> void:
	if t < SHOT or t > HIT + 0.12:
		return
	var muzzle := shooter + POSE.hand0 * SCALE + Vector2(16, 0)
	var target := _victim_at() + POSE.head * Vector2(-SCALE, SCALE)
	var k := clampf((t - SHOT) / (HIT - SHOT), 0.0, 1.0)
	var fade := 1.0 - clampf((t - HIT) / 0.12, 0.0, 1.0)
	_canvas.draw_line(muzzle, muzzle.lerp(target, k), Color(2.6, 2.2, 1.4, fade * a), 2.0)
	if t < SHOT + 0.06:
		_canvas.draw_circle(muzzle, 7.0, Color(3.0, 2.4, 1.2, a))


## Le titre : chaque lettre tombe de haut et grossie, avec un décalage rouge / cyan, puis saigne.
func _draw_title(s: Vector2, a: float) -> void:
	var size := 116
	var word := "RIXE"
	var total := _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 3 * 12.0
	var x := (s.x - total) * 0.5
	var base_y := 140.0
	_draw_smear(Vector2(s.x * 0.5, base_y - size * 0.32), total + 60.0, a)
	for i in word.length():
		var ch := word[i]
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var k := clampf((t - LETTERS - i * LETTER_GAP) / 0.12, 0.0, 1.0)
		if k > 0.0:
			if k >= 1.0 and _drips.size() < 14 and randf() < 0.12:
				_drips.append(Vector3(x + randf_range(4, w - 4), base_y + 4.0, 0.0))
			var sc := lerpf(2.4, 1.0, ease(k, 0.4))
			var center := Vector2(x + w * 0.5, base_y - size * 0.35)
			_canvas.draw_set_transform(center + Vector2(randf_range(-1, 1), 0) * _shake * 6.0, 0.0, Vector2(sc, sc))
			var p := Vector2(-w * 0.5, size * 0.35)
			var spread := 2.0 + _shake * 6.0
			_canvas.draw_string(_font, p + Vector2(-spread, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				Color(2.0, 0.1, 0.15, 0.6 * k * a))
			_canvas.draw_string(_font, p + Vector2(spread, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				Color(0.2, 1.4, 2.0, 0.5 * k * a))
			_canvas.draw_string(_font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.6, 1.5, 1.5, k * a))
		x += w + 12.0
	_canvas.draw_set_transform(Vector2.ZERO)
	for d in _drips:
		_canvas.draw_line(Vector2(d.x, d.y), Vector2(d.x, d.y + d.z), Color(1.3, 0.05, 0.08, a), 2.0)
		_canvas.draw_circle(Vector2(d.x, d.y + d.z), 1.6, Color(1.3, 0.05, 0.08, a))
	var tag := clampf((t - 2.1) / 0.4, 0.0, 1.0) * a
	_canvas.draw_string(_font, Vector2(0, base_y + 44.0), "COMBATS DE STICKMEN", HORIZONTAL_ALIGNMENT_CENTER, s.x,
		14, Color(1, 0.9, 0.95, 0.75 * tag))


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
