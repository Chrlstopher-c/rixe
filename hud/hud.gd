extends CanvasLayer
## Interface : vie du joueur, manche, éliminations, fil des morts, bannières animées, viseur.

var player: Node2D
var round_no := 1
var kills := 0
var best := 0
var mode := "arcade"
var match_state: MatchState
var respawn_t := -1.0
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
	var info := _info_line()
	_canvas.draw_string(_font, Vector2(12, 30), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.9, 0.95, 0.75))
	for i in _feed.size():
		var f: Dictionary = _feed[i]
		var a := clampf(4.0 - f.t, 0.0, 1.0)
		_canvas.draw_string(_font, Vector2(400, 18 + i * 11), f.text, HORIZONTAL_ALIGNMENT_RIGHT, 228, 8,
			Color(f.color, a))
	_draw_banner()
	_draw_mode_center()
	_draw_ammo()
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
	var gap := 3.0
	if is_instance_valid(player):
		var spread: float = player.gun.def.spread * (1.0 if player.body.arms_left() == 2 else 2.5)
		gap += spread * player.global_position.distance_to(player.get_global_mouse_position()) * 0.6
		gap += player.rig.recoil * 1.2
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		_canvas.draw_line(m + d * gap, m + d * (gap + 4.0), c, 1.0)
	_canvas.draw_circle(m, 0.7, c)


func _info_line() -> String:
	if mode == "arcade" or match_state == null:
		return "MANCHE %d   ·   BOTS %d   ·   ÉLIMINATIONS %d   ·   RECORD %d" % [round_no, bots_left, kills, best]
	var rows := match_state.ranking()
	var place := 1
	for i in rows.size():
		if rows[i].name == "Toi":
			place = i + 1
	var lead: String = rows[0].name if not rows.is_empty() else "-"
	var lead_k: int = rows[0].kills if not rows.is_empty() else 0
	var mine := match_state.kills_of("Toi")
	if mode == "objectif":
		var goal := Modes.option_value(mode, match_state.option)
		return "ÉLIMINATIONS %d / %d   ·   RANG %d   ·   EN TÊTE : %s (%d)" % [mine, goal, place, lead, lead_k]
	return "ÉLIMINATIONS %d   ·   RANG %d / %d   ·   EN TÊTE : %s (%d)" % [mine, place, rows.size(), lead, lead_k]


func _draw_mode_center() -> void:
	var w := _canvas.size.x
	if mode == "chrono" and match_state:
		var t := ceili(match_state.time_left)
		var urgent := match_state.time_left < 10.0
		var col := Color(2.0, 0.5, 0.5) if urgent else Color(1.6, 1.55, 1.5)
		var size := 22 if not urgent else int(22 + 4 * absf(sin(match_state.time_left * PI)))
		_canvas.draw_string(_font, Vector2(0, 30), "%d:%02d" % [t / 60, t % 60], HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
	if respawn_t > 0.0:
		_canvas.draw_rect(Rect2(0, 186, w, 26), Color(0, 0, 0, 0.4))
		_canvas.draw_string(_font, Vector2(0, 204), "RÉAPPARITION  %d" % ceili(respawn_t), HORIZONTAL_ALIGNMENT_CENTER,
			w, 14, Color(0.6, 1.8, 2.0))


func _draw_ammo() -> void:
	if not is_instance_valid(player) or not player.alive:
		return
	var g: Gun = player.gun
	var size := _canvas.size
	var empty := g.mag == 0
	var col := Color(2.0, 0.5, 0.5) if empty or g.mag <= int(g.def.mag) / 5 else Color(1.6, 1.55, 1.5)
	var x := size.x - 140.0
	_canvas.draw_string(_font, Vector2(x, size.y - 16), "%d" % g.mag, HORIZONTAL_ALIGNMENT_RIGHT, 60, 22, col)
	_canvas.draw_string(_font, Vector2(x + 64, size.y - 16), "/ %d" % g.reserve, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(1, 0.9, 0.95, 0.7))
	_canvas.draw_string(_font, Vector2(x, size.y - 40), String(g.def.name).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT,
		124, 8, Color(1, 0.9, 0.95, 0.6))
	if g.reloading():
		var r := Rect2(x + 4, size.y - 12, 120, 3)
		_canvas.draw_rect(r, Color(0, 0, 0, 0.5))
		_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * g.reload_progress(), r.size.y)), Color(0.4, 1.6, 1.9))
	elif empty:
		var msg := "R : RECHARGER" if g.reserve > 0 else "PLUS DE MUNITIONS · E : COUP DE PIED"
		_canvas.draw_string(_font, Vector2(0, size.y * 0.5 + 40), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10,
			Color(2.0, 0.6, 0.6, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.01)))
