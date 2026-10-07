class_name Outfit
## Tenues du joueur : chapeau, masque, cape et couleur, débloqués par niveau (Profile). Dessinées sur le squelette
## (en jeu, et en aperçu dans l'écran PROFIL) à partir des articulations tête / épaules.

const PARTS := {
	"hat": [["aucun", 1], ["casquette", 2], ["bandeau", 3], ["haut-de-forme", 5], ["casque", 7], ["cornes", 9],
		["couronne", 12]],
	"mask": [["aucun", 1], ["lunettes", 3], ["ninja", 6], ["crâne", 10]],
	"cape": [["aucune", 1], ["courte", 4], ["longue", 8]],
	"color": [["cyan", 1], ["rouge", 2], ["vert", 3], ["jaune", 4], ["violet", 6], ["orange", 8], ["blanc", 11]],
}
const COLORS := {"cyan": Color(0.3, 0.9, 1.0), "rouge": Color(1.0, 0.3, 0.3), "vert": Color(0.4, 1.0, 0.5),
	"jaune": Color(1.0, 0.85, 0.3), "violet": Color(0.75, 0.45, 1.0), "orange": Color(1.0, 0.6, 0.2),
	"blanc": Color(0.95, 0.95, 1.0)}
const LABELS := {"hat": "CHAPEAU", "mask": "MASQUE", "cape": "CAPE", "color": "COULEUR"}


static func level_of(part: String, item: String) -> int:
	for e in PARTS[part]:
		if e[0] == item:
			return e[1]
	return 99


static func names(part: String) -> Array:
	return PARTS[part].map(func(e: Array) -> String: return e[0])


static func value(outfit: Dictionary, part: String) -> String:
	return String(outfit.get(part, PARTS[part][0][0]))


## Objets débloqués exactement à ce niveau (annonce de montée de niveau).
static func unlocked_at(level: int) -> Array:
	var out := []
	for part in PARTS:
		for e in PARTS[part]:
			if e[1] == level and e[1] > 1:
				out.append(e[0])
	return out


static func color(outfit: Dictionary) -> Color:
	return COLORS.get(value(outfit, "color"), COLORS.cyan)


## Derrière le corps : la cape. `j` = articulations, `facing` = 1 ou -1, `col` = couleur d'accent.
static func draw_back(c: CanvasItem, j: Dictionary, facing: int, col: Color, outfit: Dictionary, hd: bool) -> void:
	if not outfit.is_empty():
		_cape(c, j, facing, value(outfit, "cape"), Color(col * 0.55, 0.95), hd)


## Devant : masque puis chapeau, sur la tête.
static func draw_front(c: CanvasItem, j: Dictionary, facing: int, col: Color, outfit: Dictionary, hd: bool) -> void:
	if outfit.is_empty() or not j.has("head"):
		return
	var dark := Color(0.06, 0.05, 0.08)
	_mask(c, j.head, facing, value(outfit, "mask"), col, dark)
	_hat(c, j.head, facing, value(outfit, "hat"), col, dark, hd)


static func _hat(c: CanvasItem, h: Vector2, f: int, hat: String, col: Color, dark: Color, hd: bool) -> void:
	match hat:
		"casquette":
			c.draw_rect(Rect2(h + Vector2(-3.8, -4.6), Vector2(7.6, 2.4)), col * 0.9)
			c.draw_line(h + Vector2(f * 2.0, -2.4), h + Vector2(f * 6.5, -2.2), col * 0.9, 1.2, hd)
		"bandeau":
			c.draw_line(h + Vector2(-3.8, -2.0), h + Vector2(3.8, -2.0), col * 1.4, 1.2, hd)
			c.draw_line(h + Vector2(-f * 3.6, -2.0), h + Vector2(-f * 7.0, -0.5), col * 1.4, 0.8, hd)
		"haut-de-forme":
			c.draw_rect(Rect2(h + Vector2(-5.0, -4.2), Vector2(10.0, 1.4)), dark)
			c.draw_rect(Rect2(h + Vector2(-3.2, -10.5), Vector2(6.4, 6.6)), dark)
			c.draw_rect(Rect2(h + Vector2(-3.2, -6.0), Vector2(6.4, 1.0)), col * 1.3)
		"casque":
			c.draw_arc(h + Vector2(0, -0.6), 4.6, PI, TAU, 16, Color(0.35, 0.4, 0.38), 2.4, hd)
		"cornes":
			for s in [-1, 1]:
				c.draw_polyline(PackedVector2Array([h + Vector2(s * 2.6, -2.8), h + Vector2(s * 4.8, -6.5),
					h + Vector2(s * 3.4, -9.0)]), Color(0.9, 0.85, 0.75), 1.3, hd)
		"couronne":
			var pts := PackedVector2Array([h + Vector2(-4, -3.5), h + Vector2(-4, -7.5), h + Vector2(-2, -5.2),
				h + Vector2(0, -8.2), h + Vector2(2, -5.2), h + Vector2(4, -7.5), h + Vector2(4, -3.5)])
			c.draw_colored_polygon(pts, Color(2.2, 1.7, 0.4))


static func _mask(c: CanvasItem, h: Vector2, f: int, mask: String, col: Color, dark: Color) -> void:
	match mask:
		"lunettes":
			c.draw_rect(Rect2(h + Vector2(f * 0.4 - 1.0, -1.6), Vector2(3.6 * f, 1.8)), Color(0.05, 0.05, 0.06))
			c.draw_line(h + Vector2(f * 1.0, -1.2), h + Vector2(f * 3.2, -1.2), col * 2.0, 0.6)
		"ninja":
			c.draw_rect(Rect2(h + Vector2(-3.6, -0.3), Vector2(7.2, 3.6)), dark * 2.5)
		"crâne":
			c.draw_circle(h + Vector2(f * 0.6, 0), 3.4, Color(0.92, 0.9, 0.84))
			c.draw_circle(h + Vector2(f * 1.8, -0.8), 0.9, Color(0.05, 0.03, 0.05))
			c.draw_circle(h + Vector2(f * -0.2, -0.8), 0.9, Color(0.05, 0.03, 0.05))


static func _cape(c: CanvasItem, j: Dictionary, f: int, cape: String, col: Color, hd: bool) -> void:
	if cape == "aucune" or not j.has("shoulder") or not j.has("hip"):
		return
	var s: Vector2 = j.shoulder
	var length := 10.0 if cape == "courte" else 17.0
	var tail := s + Vector2(-f * (5.0 + length * 0.35), length)
	var pts := PackedVector2Array([s + Vector2(-f * 1.5, -0.5), s + Vector2(f * 1.0, 0.5), tail + Vector2(-f * 3.0, 0),
		tail + Vector2(-f * 7.0, -2.0)])
	c.draw_colored_polygon(pts, col)
	c.draw_polyline(pts, Color(col * 1.6, 1.0), 0.6, hd)
