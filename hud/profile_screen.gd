extends CanvasLayer
## Écran PROFIL : niveau et expérience, défi du jour, statistiques, succès, et tenue (chapeau, masque, cape,
## couleur) avec aperçu ; seuls les objets débloqués se choisissent, le prochain déblocage est indiqué.

signal back_requested

const ACCENT := Color(0.3, 0.9, 1.0)
const ROWS := ["hat", "mask", "cape", "color", "back"]
const STATS := [["kills", "Éliminations"], ["heads", "Par la tête"], ["decaps", "Décapitations"],
	["execs", "Exécutions"], ["parries", "Parades"], ["bosses", "Boss abattus"], ["rounds", "Manches gagnées"],
	["best_round", "Meilleure manche"], ["matches", "Parties"]]
## Squelette de l'aperçu (debout, de profil, regard à droite).
const POSE := {"head": Vector2(1, -31), "neck": Vector2(0.5, -27), "shoulder": Vector2(0, -25.5),
	"hip": Vector2(0, -15), "knee0": Vector2(-2.5, -7.5), "foot0": Vector2(-3.5, 0), "knee1": Vector2(3, -7.5),
	"foot1": Vector2(3.5, 0), "elbow0": Vector2(3, -20), "hand0": Vector2(7, -21), "elbow1": Vector2(-2, -19.5),
	"hand1": Vector2(1, -15)}

var profile: Profile
## Joueur à rhabiller tout de suite (aperçu en jeu) ; null au menu.
var spawner: Spawner
var _sel := 0
var _t := 0.0
var _canvas := Control.new()
var _font: Font = ThemeDB.fallback_font
var _rects: Array[Rect2] = []


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_screen)
	_canvas.gui_input.connect(_on_mouse)
	add_child(_canvas)
	visible = false


func open() -> void:
	_sel = 0
	visible = true


func _text(id: String) -> String:
	if id == "back":
		return "RETOUR"
	return "%s  ‹ %s ›" % [Outfit.LABELS[id], Outfit.value(profile.outfit, id).to_upper()]


## Objet suivant parmi ceux déjà débloqués.
func adjust(id: String, step: int) -> void:
	if id == "back":
		return
	var list := Outfit.names(id).filter(func(n: String) -> bool:
		return Outfit.level_of(id, n) <= profile.level())
	var cur := list.find(Outfit.value(profile.outfit, id))
	profile.outfit[id] = list[posmod(cur + step, list.size())]
	profile.save()
	if spawner:
		spawner.outfit = profile.outfit


func activate(i: int) -> void:
	_sel = i
	if ROWS[i] == "back":
		visible = false
		back_requested.emit()
	else:
		adjust(ROWS[i], 1)


func _process(delta: float) -> void:
	_t += delta
	if visible:
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var k := Controls.menu_key(event)
	if not visible or k == 0:
		return
	if k in [KEY_W, KEY_UP]:
		_sel = posmod(_sel - 1, ROWS.size())
	elif k in [KEY_S, KEY_DOWN]:
		_sel = (_sel + 1) % ROWS.size()
	elif k in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
		adjust(ROWS[_sel], -1 if k in [KEY_A, KEY_LEFT] else 1)
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		activate(_sel)
	elif k == KEY_ESCAPE:
		activate(ROWS.size() - 1)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_mouse(event: InputEvent) -> void:
	if not (event is InputEventMouse):
		return
	for i in _rects.size():
		if _rects[i].has_point(event.position):
			_sel = i
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					activate(i)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					adjust(ROWS[i], -1)


func _draw_screen() -> void:
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04, 0.85))
	_canvas.draw_string(_font, Vector2(0, 30), "PROFIL  ·  %s" % Names.load_nick(), HORIZONTAL_ALIGNMENT_CENTER,
		size.x, 20, Color(1.6, 1.5, 1.5))
	_draw_level(Vector2(24, 60), size.x * 0.3)
	_draw_stats(Vector2(24, 132))
	_draw_outfit(Vector2(size.x * 0.5, 64))
	_draw_achievements(Vector2(size.x * 0.7, 60))
	var help := "Tenues : débloquées en montant de niveau · Échap pour revenir"
	_canvas.draw_string(_font, Vector2(0, size.y - 12), help, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8,
		Color(1, 0.9, 0.95, 0.55))


func _draw_level(at: Vector2, w: float) -> void:
	var dim := Color(1, 0.9, 0.95, 0.7)
	_canvas.draw_string(_font, at, "NIVEAU %d" % profile.level(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACCENT * 1.6)
	var bar := Rect2(at + Vector2(0, 8), Vector2(w, 4))
	_canvas.draw_rect(bar, Color(0, 0, 0, 0.6))
	_canvas.draw_rect(Rect2(bar.position, Vector2(w * profile.progress(), 4)), ACCENT * 1.4)
	_canvas.draw_string(_font, at + Vector2(0, 24), "%d XP" % profile.xp, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, dim)
	var d := profile.current_daily()
	var done: bool = profile.daily.get("done", false)
	_canvas.draw_string(_font, at + Vector2(0, 44), "DÉFI DU JOUR", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(2.0, 1.7, 0.6))
	var line := "%s  ·  %d / %d%s" % [d.text, profile.daily_progress(), d.goal, "  · réussi" if done else ""]
	_canvas.draw_string(_font, at + Vector2(0, 56), line, HORIZONTAL_ALIGNMENT_LEFT, w + 40, 8,
		Color(0.6, 2.0, 0.9) if done else dim)


func _draw_stats(at: Vector2) -> void:
	_canvas.draw_string(_font, at, "STATISTIQUES", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.9, 0.95, 0.8))
	for i in STATS.size():
		var line := "%s   %d" % [STATS[i][1], profile.stat(STATS[i][0])]
		_canvas.draw_string(_font, at + Vector2(0, 14 + i * 11), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color(1, 0.92, 0.95, 0.75))


func _draw_outfit(at: Vector2) -> void:
	var box := Rect2(at + Vector2(-50, 0), Vector2(100, 96))
	_canvas.draw_rect(box, Color(0.08, 0.07, 0.12, 0.9))
	_canvas.draw_rect(box, Color(ACCENT, 0.25), false, 1.0)
	var col := Outfit.color(profile.outfit)
	_canvas.draw_set_transform(box.get_center() + Vector2(0, 40), 0.0, Vector2(2.6, 2.6))
	_draw_figure(col)
	_canvas.draw_set_transform(Vector2.ZERO)
	_rects.clear()
	for i in ROWS.size():
		var y := at.y + 118 + i * 17.0
		var r := Rect2(at.x - 100, y - 12, 200, 16)
		_rects.append(r)
		var on := i == _sel
		if on:
			_canvas.draw_rect(r, Color(ACCENT, 0.12))
			_canvas.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), ACCENT * 1.8)
		_canvas.draw_string(_font, Vector2(r.position.x, y), _text(ROWS[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
			11, Color(ACCENT * 1.6) if on else Color(1, 0.92, 0.95, 0.78))
	var next := _next_unlock()
	if next != "":
		_canvas.draw_string(_font, Vector2(at.x - 120, at.y + 118 + ROWS.size() * 17.0 + 6), next,
			HORIZONTAL_ALIGNMENT_CENTER, 240, 8, Color(1, 0.9, 0.95, 0.55))


func _draw_figure(col: Color) -> void:
	var c := Color(0.035, 0.03, 0.055)
	var j := POSE
	Outfit.draw_back(_canvas, j, 1, col, profile.outfit, true)
	for pair in [["hip", "shoulder"], ["hip", "knee0"], ["knee0", "foot0"], ["hip", "knee1"], ["knee1", "foot1"],
			["shoulder", "elbow0"], ["elbow0", "hand0"], ["shoulder", "elbow1"], ["elbow1", "hand1"]]:
		_canvas.draw_line(j[pair[0]], j[pair[1]], Color(col * 1.4, 0.9), 3.4, true)
		_canvas.draw_line(j[pair[0]], j[pair[1]], c, 2.2, true)
	_canvas.draw_circle(j.head, 4.4, Color(col * 1.4, 0.9))
	_canvas.draw_circle(j.head, 3.7, c)
	_canvas.draw_line(j.head + Vector2(1.2, -0.5), j.head + Vector2(3.6, -0.2), col * 3.0, 1.2)
	Outfit.draw_front(_canvas, j, 1, col, profile.outfit, true)


func _next_unlock() -> String:
	var best_lvl := 99
	var best_name := ""
	for part in Outfit.PARTS:
		for e in Outfit.PARTS[part]:
			if e[1] > profile.level() and e[1] < best_lvl:
				best_lvl = e[1]
				best_name = e[0]
	return "Prochain : %s au niveau %d" % [best_name, best_lvl] if best_name != "" else ""


func _draw_achievements(at: Vector2) -> void:
	_canvas.draw_string(_font, at, "SUCCÈS  %d / %d" % [profile.unlocked.size(), Profile.ACHIEVEMENTS.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.9, 0.95, 0.8))
	var i := 0
	for id: String in Profile.ACHIEVEMENTS:
		var a: Dictionary = Profile.ACHIEVEMENTS[id]
		var got: bool = id in profile.unlocked
		var y := at.y + 16 + i * 20
		var mark := Vector2(at.x + 3, y - 3)
		if got:
			_canvas.draw_polyline(PackedVector2Array([mark + Vector2(-2.5, 0), mark + Vector2(-0.5, 2),
				mark + Vector2(3, -2.5)]), Color(0.6, 2.0, 0.9), 1.2, true)
		else:
			_canvas.draw_circle(mark, 1.2, Color(1, 0.9, 0.95, 0.4))
		_canvas.draw_string(_font, Vector2(at.x + 10, y), String(a.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.6, 2.0, 0.9) if got else Color(1, 0.9, 0.95, 0.6))
		_canvas.draw_string(_font, Vector2(at.x + 14, y + 9), a.desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
			Color(1, 0.9, 0.95, 0.4))
		i += 1
