extends CanvasLayer
## Interface : vie du joueur, manche, éliminations, fil des morts, bannières animées, viseur.

var player: Node2D
var round_no := 1
var kills := 0
var bots_left := 0
var show_crosshair := true
var _canvas := Control.new()
var _banner := ""
var _banner_t := 0.0
var _feed: Array[Dictionary] = []
var _font: Font = ThemeDB.fallback_font
var _hp_shown := 100.0


func _ready() -> void:
	layer = 20
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func banner(text: String) -> void:
	_banner = text
	_banner_t = 0.0


func feed(text: String, color: Color) -> void:
	_feed.append({"text": text, "color": color, "t": 0.0})
	if _feed.size() > 5:
		_feed.pop_front()


func _process(delta: float) -> void:
	var real: float = Juice.real_delta(delta)
	_banner_t += real
	for f in _feed:
		f.t += real
	_feed = _feed.filter(func(f: Dictionary) -> bool: return f.t < 4.0)
	var hp: float = player.hp if is_instance_valid(player) else 0.0
	_hp_shown = lerpf(_hp_shown, hp, minf(real * 6.0, 1.0))
	_canvas.queue_redraw()


func _draw_hud() -> void:
	_draw_health()
	var info := "MANCHE %d   ·   BOTS %d   ·   ÉLIMINATIONS %d" % [round_no, bots_left, kills]
	_canvas.draw_string(_font, Vector2(12, 30), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.9, 0.95, 0.75))
	for i in _feed.size():
		var f: Dictionary = _feed[i]
		var a := clampf(4.0 - f.t, 0.0, 1.0)
		_canvas.draw_string(_font, Vector2(400, 18 + i * 11), f.text, HORIZONTAL_ALIGNMENT_RIGHT, 228, 8,
			Color(f.color, a))
	_draw_banner()
	if show_crosshair:
		_draw_crosshair(_canvas.get_local_mouse_position())


func _draw_health() -> void:
	var r := Rect2(12, 12, 120, 6)
	_canvas.draw_rect(r.grow(1), Color(0, 0, 0, 0.6))
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(_hp_shown / 100.0, 0, 1), r.size.y)),
		Color(1.6, 0.25, 0.3))
	var hp: float = player.hp if is_instance_valid(player) else 0.0
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(hp / 100.0, 0, 1), r.size.y)), Color(0.4, 1.6, 1.9))


func _draw_banner() -> void:
	if _banner == "" or _banner_t > 2.6:
		return
	var t := _banner_t
	var a := clampf(t * 6.0, 0.0, 1.0) * clampf((2.6 - t) * 3.0, 0.0, 1.0)
	var s := int(lerpf(34.0, 22.0, clampf(t * 5.0, 0.0, 1.0)))
	var y := 150.0
	_canvas.draw_rect(Rect2(0, y - 26, 640, 38), Color(0, 0, 0, 0.45 * a))
	_canvas.draw_string(_font, Vector2(0, y), _banner, HORIZONTAL_ALIGNMENT_CENTER, 640, s, Color(1.8, 1.6, 1.5, a))


func _draw_crosshair(m: Vector2) -> void:
	var c := Color(2.0, 1.9, 1.9, 0.9)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		_canvas.draw_line(m + d * 3.0, m + d * 7.0, c, 1.0)
	_canvas.draw_circle(m, 0.8, c)
