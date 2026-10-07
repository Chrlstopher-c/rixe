extends CanvasLayer
## Écran de fin de partie : titre (victoire / défaite), classement des combattants, record, rejouer ou menu.

signal replay_requested
signal menu_requested

const ACCENT := Color(0.3, 0.9, 1.0)

var _canvas := Control.new()
var _font: Font = ThemeDB.fallback_font
var _title := ""
var _sub := ""
var _rows: Array = []
var _board: Array = []
var _board_rank := -1
var _mode := "arcade"
var _t := 0.0


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_board)
	add_child(_canvas)
	visible = false


func open(title: String, sub: String, rows: Array, mode: String, board: Array, board_rank: int) -> void:
	_title = title
	_sub = sub
	_rows = rows
	_mode = mode
	_board = board
	_board_rank = board_rank
	_t = 0.0
	visible = true


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	_t += delta
	if visible:
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var k := Controls.menu_key(event)
	if not visible or k == 0 or _t < 0.6:
		return
	if k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		replay_requested.emit()
	elif k == KEY_ESCAPE:
		menu_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _draw_board() -> void:
	var size := _canvas.size
	var a := clampf(_t * 4.0, 0.0, 1.0)
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04, 0.72 * a))
	_canvas.draw_string(_font, Vector2(0, 58), _title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(ACCENT * 1.7, a))
	_canvas.draw_string(_font, Vector2(0, 76), _sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color(1, 0.9, 0.95, 0.8 * a))
	_draw_rows(Rect2(150, 96, 340, 0), a)
	_draw_records(Vector2(size.x * 0.5, 96 + 14 * (_rows.size() + 1) + 18), a)
	var help := "Entrée : rejouer   ·   Échap : menu"
	_canvas.draw_string(_font, Vector2(0, size.y - 16), help, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9,
		Color(1, 0.9, 0.95, 0.6 * a))


func _draw_rows(box: Rect2, a: float) -> void:
	var x := box.position.x
	var y := box.position.y
	var head := Color(1, 0.9, 0.95, 0.55 * a)
	_canvas.draw_string(_font, Vector2(x, y), "#", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, head)
	_canvas.draw_string(_font, Vector2(x + 24, y), "COMBATTANT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, head)
	_canvas.draw_string(_font, Vector2(x + 230, y), "ÉLIM.", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, head)
	_canvas.draw_string(_font, Vector2(x + 290, y), "MORTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, head)
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var ry := y + 14 * (i + 1)
		var k := clampf((_t - 0.15 - i * 0.07) * 6.0, 0.0, 1.0) * a
		if r.player:
			_canvas.draw_rect(Rect2(x - 6, ry - 10, box.size.x + 12, 13), Color(ACCENT, 0.14 * k))
		var col: Color = Color(r.color * (1.6 if r.player else 1.2), k)
		_canvas.draw_string(_font, Vector2(x, ry), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, k))
		_canvas.draw_string(_font, Vector2(x + 24, ry), r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
		_canvas.draw_string(_font, Vector2(x + 230, ry), str(r.kills), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, k))
		_canvas.draw_string(_font, Vector2(x + 290, ry), str(r.deaths), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(1, 1, 1, 0.7 * k))


func _draw_records(at: Vector2, a: float) -> void:
	if _board.is_empty():
		return
	var place := "1er" if _board_rank == 0 else "%de" % (_board_rank + 1)
	var title := "MEILLEURS SCORES" + ("   ·   NOUVEAU RECORD : %s" % place if _board_rank >= 0 else "")
	_canvas.draw_string(_font, Vector2(0, at.y), title, HORIZONTAL_ALIGNMENT_CENTER, _canvas.size.x, 9,
		Color(ACCENT * 1.5, a))
	for i in _board.size():
		var e: Dictionary = _board[i]
		var on := i == _board_rank
		var line := "%d.  %s   %s" % [i + 1, Leaderboard.format_score(_mode, e.score), e.date]
		var col := Color(ACCENT * 1.8, a) if on else Color(1, 0.92, 0.95, 0.7 * a)
		_canvas.draw_string(_font, Vector2(0, at.y + 13 * (i + 1)), line, HORIZONTAL_ALIGNMENT_CENTER,
			_canvas.size.x, 9, col)
