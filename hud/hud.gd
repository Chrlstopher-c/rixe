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
var _toasts: Array[Dictionary] = []


func _ready() -> void:
	layer = 20
	Juice.notified.connect(func(text: String) -> void: _toasts.append({"text": text, "t": 0.0}))
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
	for t in _toasts:
		t.t += real
	_toasts = _toasts.filter(func(t: Dictionary) -> bool: return t.t < 3.0)
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
	_draw_toasts()
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
	var empty := g.mag == 0 and not g.infinite()
	var col := Color(2.0, 0.5, 0.5) if empty or g.mag <= int(g.def.mag) / 5 else Color(1.6, 1.55, 1.5)
	var x := size.x - 140.0
	var count := "—" if g.infinite() else "%d" % g.mag
	_canvas.draw_string(_font, Vector2(x, size.y - 16), count, HORIZONTAL_ALIGNMENT_RIGHT, 60, 22, col)
	if not g.infinite():
		_canvas.draw_string(_font, Vector2(x + 64, size.y - 16), "/ %d" % g.reserve, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(1, 0.9, 0.95, 0.7))
	_draw_kit(x, size)
	_canvas.draw_string(_font, Vector2(x, size.y - 40), String(g.def.name).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT,
		124, 8, Color(1, 0.9, 0.95, 0.6))
	var names := g.attachments.values().map(func(a: String) -> String: return Arsenal.ATTACHMENTS[a].name)
	if not names.is_empty():
		_canvas.draw_string(_font, Vector2(x - 120, size.y - 50), " · ".join(names), HORIZONTAL_ALIGNMENT_RIGHT, 244, 7,
			Color(0.6, 1.8, 0.9, 0.7))
	if g.reloading():
		var r := Rect2(x + 4, size.y - 12, 120, 3)
		_canvas.draw_rect(r, Color(0, 0, 0, 0.5))
		_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * g.reload_progress(), r.size.y)), Color(0.4, 1.6, 1.9))
	elif empty:
		var msg := "R : RECHARGER" if g.reserve > 0 else "PLUS DE MUNITIONS · E : COUP DE PIED"
		_canvas.draw_string(_font, Vector2(0, size.y * 0.5 + 40), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10,
			Color(2.0, 0.6, 0.6, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.01)))


## Grenades, trousses de soin et arme de rechange, à gauche du compteur de munitions.
func _draw_kit(x: float, size: Vector2) -> void:
	for i in player.grenades:
		_canvas.draw_circle(Vector2(x - 8 - i * 9, size.y - 22), 3.0, Color(0.5, 0.9, 0.4))
	for i in player.inventory.medkits:
		var c := Vector2(x - 12 - i * 11, size.y - 34)
		_canvas.draw_rect(Rect2(c - Vector2(4, 4), Vector2(8, 8)), Color(0.9, 0.9, 0.9))
		_canvas.draw_rect(Rect2(c - Vector2(0.8, 3), Vector2(1.6, 6)), Color(2.0, 0.3, 0.3))
		_canvas.draw_rect(Rect2(c - Vector2(3, 0.8), Vector2(6, 1.6)), Color(2.0, 0.3, 0.3))
	var spare: Gun = player.inventory.other()
	if spare:
		var line := "%d · %s" % [2 - player.inventory.active, String(spare.def.name).to_upper()]
		_canvas.draw_string(_font, Vector2(x, size.y - 60), line, HORIZONTAL_ALIGNMENT_RIGHT, 124, 7,
			Color(1, 0.9, 0.95, 0.45))



func _draw_toasts() -> void:
	for i in _toasts.size():
		var t: Dictionary = _toasts[i]
		var a := clampf(t.t * 6.0, 0.0, 1.0) * clampf((3.0 - t.t) * 2.0, 0.0, 1.0)
		var y := 80.0 + i * 16.0
		_canvas.draw_rect(Rect2(_canvas.size.x * 0.5 - 90, y - 11, 180, 15), Color(0.02, 0.08, 0.04, 0.6 * a))
		_canvas.draw_string(_font, Vector2(0, y), t.text, HORIZONTAL_ALIGNMENT_CENTER, _canvas.size.x, 10,
			Color(0.6, 2.0, 0.9, a))
