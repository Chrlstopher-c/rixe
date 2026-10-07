class_name Replay
extends Node2D
## Rediffusion : enregistre en continu les 15 dernières secondes (squelettes, traçantes, morts) et les rejoue par
## dessus le décor, jeu figé, caméra libre sur le joueur. Commandes : Espace pause, ‹ › reculer / avancer,
## ↑ ↓ vitesse, Échap ou Entrée pour revenir.

signal finished

const RATE := 1.0 / 30.0
const SECONDS := 15.0
const BONES := [["hip", "shoulder"], ["hip", "knee0"], ["knee0", "foot0"], ["hip", "knee1"], ["knee1", "foot1"],
	["shoulder", "elbow0"], ["elbow0", "hand0"], ["shoulder", "elbow1"], ["elbow1", "hand1"]]

var playing := false
## Images enregistrées : {t, fighters: [{id, j, color, outfit, facing, player}], shots: [[from, to, color]], deaths}.
var frames: Array[Dictionary] = []
var _acc := 0.0
var _shots: Array = []
var _deaths: Array = []
var _cursor := 0.0
var _speed := 1.0
var _paused := false
var _main: Node
var _font: Font = ThemeDB.fallback_font
var _bar := CanvasLayer.new()
var _hint := Control.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 70
	_bar.layer = 40
	_bar.visible = false
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.draw.connect(_draw_hint)
	_bar.add_child(_hint)
	add_child(_bar)


func setup(main: Node) -> void:
	_main = main


func clear() -> void:
	frames.clear()
	_shots.clear()
	_deaths.clear()


func shot(from: Vector2, to: Vector2, color: Color) -> void:
	if not playing:
		_shots.append([from, to, color])


func death(at: Vector2, color: Color) -> void:
	if not playing:
		_deaths.append([at, color])


func _physics_process(delta: float) -> void:
	if playing or get_tree().paused:
		return
	_acc += delta
	if _acc < RATE:
		return
	_acc = 0.0
	var fs := []
	for f in _main._fighters.get_children():
		if f is Fighter and f.alive and is_instance_valid(f.rig):
			fs.append({"id": f.display_name, "j": f.rig.global_joints(), "color": f.team_color, "outfit": f.outfit,
				"facing": f.facing, "player": f == _main.player, "aim": f.gun.shot_dir(),
				"len": float(f.gun.def.get("length", 8.0))})
	frames.append({"fighters": fs, "shots": _shots, "deaths": _deaths})
	_shots = []
	_deaths = []
	while frames.size() > int(SECONDS / RATE):
		frames.pop_front()


func can_play() -> bool:
	return frames.size() > 30


func play() -> void:
	if not can_play():
		return
	playing = true
	_cursor = 0.0
	_speed = 1.0
	_paused = false
	_main._fighters.visible = false
	Juice.fx.visible = false
	_main._hud.visible = false
	_bar.visible = true


func stop() -> void:
	playing = false
	_main._fighters.visible = true
	Juice.fx.visible = true
	_main._hud.visible = true
	_bar.visible = false
	queue_redraw()
	finished.emit()


func _process(delta: float) -> void:
	if not playing:
		return
	var real: float = Juice.real_delta(delta)
	if not _paused:
		_cursor = minf(_cursor + real / RATE * _speed, frames.size() - 1.0)
	var fr := frames[int(_cursor)]
	for f: Dictionary in fr.fighters:
		if f.player:
			_main._camera.global_position = _main._camera.global_position.lerp(f.j.hip + Vector2(0, -20),
				minf(real * 6.0, 1.0))
	queue_redraw()
	_hint.queue_redraw()


## Bandeau : progression, vitesse, commandes.
func _draw_hint() -> void:
	var s := _hint.size
	var k := _cursor / maxf(frames.size() - 1.0, 1.0)
	_hint.draw_rect(Rect2(0, 0, s.x, 18), Color(0, 0, 0, 0.6))
	_hint.draw_string(_font, Vector2(10, 12), "REDIFFUSION  ·  x%s%s" % [str(_speed), "  ·  PAUSE" if _paused else ""],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(2.2, 0.5, 0.45))
	_hint.draw_rect(Rect2(10, s.y - 22, s.x - 20, 2), Color(1, 1, 1, 0.2))
	_hint.draw_rect(Rect2(10, s.y - 22, (s.x - 20) * k, 2), Color(2.2, 0.5, 0.45))
	var help := "Espace pause   ·   ‹ › reculer / avancer   ·   ↑ ↓ vitesse   ·   Échap revenir"
	_hint.draw_string(_font, Vector2(0, s.y - 8), help, HORIZONTAL_ALIGNMENT_CENTER, s.x, 8, Color(1, 0.95, 0.95, 0.7))


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	var k := Controls.menu_key(event)
	match k:
		KEY_SPACE:
			_paused = not _paused
		KEY_A, KEY_LEFT:
			_cursor = maxf(_cursor - 30.0, 0.0)
		KEY_D, KEY_RIGHT:
			_cursor = minf(_cursor + 30.0, frames.size() - 1.0)
		KEY_W, KEY_UP:
			_speed = minf(_speed * 2.0, 2.0)
		KEY_S, KEY_DOWN:
			_speed = maxf(_speed * 0.5, 0.25)
		KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER:
			stop()
		_:
			return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	if not playing:
		return
	var i := int(_cursor)
	for back in range(maxi(i - 3, 0), i + 1):
		for s: Array in frames[back].shots:
			var a := 1.0 - (i - back) / 4.0
			draw_line(s[0], s[1], Color(s[2], a), 1.0)
	for back in range(maxi(i - 20, 0), i + 1):
		for d: Array in frames[back].deaths:
			draw_circle(d[0], 6.0 + (i - back), Color(1.6, 0.1, 0.12, 0.5 * (1.0 - (i - back) / 21.0)))
	for f: Dictionary in frames[i].fighters:
		_draw_fighter(f)


func _draw_fighter(f: Dictionary) -> void:
	var j: Dictionary = f.j
	var c := Color(0.035, 0.03, 0.055)
	Outfit.draw_back(self, j, f.facing, f.color, f.outfit, Juice.hd)
	for b in BONES:
		draw_line(j[b[0]], j[b[1]], Color(f.color * 1.5, 0.8), 3.6, Juice.hd)
		draw_line(j[b[0]], j[b[1]], c, 2.4, Juice.hd)
	var hand: Vector2 = j.hand0
	draw_line(hand, hand + f.aim * f.len * 1.22, Color(0.2, 0.2, 0.24), 2.2, Juice.hd)
	draw_circle(j.head, 5.2, Color(f.color * 1.5, 0.8))
	draw_circle(j.head, 4.4, c)
	Outfit.draw_front(self, j, f.facing, f.color, f.outfit, Juice.hd)
