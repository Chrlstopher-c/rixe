class_name IntroFighter
extends RefCounted
## Dessin d'un combattant de l'intro : squelette lumineux, traînées de mouvement, visage expressif (colère, cri,
## douleur, peur, rictus, mort).

const BONES := [["hip", "shoulder"], ["hip", "knee0"], ["knee0", "foot0"], ["hip", "knee1"], ["knee1", "foot1"],
	["shoulder", "elbow0"], ["elbow0", "hand0"], ["shoulder", "elbow1"], ["elbow1", "hand1"]]
const DARK := Color(0.035, 0.03, 0.055)
const HEAD := 4.4 * IntroChoreo.SCALE


static func trail(c: CanvasItem, d: Dictionary, col: Color, a: float) -> void:
	for b in BONES:
		c.draw_line(d.j[b[0]], d.j[b[1]], Color(col * 1.4, a), 5.0, true)


static func body(c: CanvasItem, d: Dictionary, col: Color, a: float, with_head: bool) -> void:
	var j: Dictionary = d.j
	for b in BONES:
		c.draw_line(j[b[0]], j[b[1]], Color(col * 1.6, 0.9 * a), 5.6, true)
	for b in BONES:
		c.draw_line(j[b[0]], j[b[1]], Color(DARK, a), 3.4, true)
	if with_head:
		head(c, j.head, d.facing, d.expr, col, a)
	else:
		c.draw_circle(j.shoulder + (j.shoulder - j.hip).normalized() * 5.0, 5.0, Color(1.5, 0.05, 0.08, a))
		c.draw_circle(j.shoulder + (j.shoulder - j.hip).normalized() * 5.0, 2.4, Color(0.5, 0.02, 0.03, a))


static func head(c: CanvasItem, at: Vector2, f: float, expr: String, col: Color, a: float) -> void:
	c.draw_circle(at, HEAD, Color(col * 1.6, 0.9 * a))
	c.draw_circle(at, HEAD - 2.2, Color(DARK, a))
	face(c, at, f, expr, Color(col * 3.0, a))


## Traits du visage, tournés vers `f` (1 = droite).
static func face(c: CanvasItem, h: Vector2, f: float, expr: String, ink: Color) -> void:
	var r := HEAD
	var eye := h + Vector2(f * 0.38 * r, -0.18 * r)
	var mouth := h + Vector2(f * 0.42 * r, 0.38 * r)
	var white := Color(2.2, 2.2, 2.2, ink.a)
	match expr:
		"angry":
			c.draw_rect(Rect2(eye - Vector2(1.5, 1.5), Vector2(3, 3)), white)
			c.draw_line(eye + Vector2(-f * 4.0, -5.0), eye + Vector2(f * 3.5, -2.5), ink, 2.0)
			c.draw_line(mouth + Vector2(-f * 3.0, 0), mouth + Vector2(f * 2.0, 0.5), ink, 1.5)
		"shout":
			c.draw_rect(Rect2(eye - Vector2(1.5, 1.5), Vector2(3, 3)), white)
			c.draw_line(eye + Vector2(-f * 4.0, -5.5), eye + Vector2(f * 3.5, -2.5), ink, 2.0)
			c.draw_circle(mouth, 3.6, Color(0.6, 0.05, 0.08, ink.a))
			c.draw_arc(mouth, 3.6, 0.0, TAU, 12, ink, 1.2)
		"pain":
			c.draw_polyline(PackedVector2Array([eye + Vector2(-f * 3, -3), eye, eye + Vector2(-f * 3, 3)]), ink, 1.8)
			c.draw_polyline(PackedVector2Array([mouth + Vector2(-f * 3, 1), mouth + Vector2(-f * 1, -1.5),
				mouth + Vector2(f * 1, 1), mouth + Vector2(f * 3, -1.5)]), ink, 1.5)
		"fear":
			c.draw_arc(eye, 2.8, 0.0, TAU, 10, white, 1.4)
			c.draw_circle(eye, 0.9, white)
			c.draw_line(eye + Vector2(-f * 3.5, -4.0), eye + Vector2(f * 3.5, -6.0), ink, 1.6)
			c.draw_arc(mouth, 2.0, 0.0, TAU, 10, ink, 1.4)
		"smug":
			c.draw_line(eye + Vector2(-f * 2.5, 0), eye + Vector2(f * 2.5, 0), white, 2.0)
			c.draw_line(eye + Vector2(-f * 4.0, -4.0), eye + Vector2(f * 3.5, -3.0), ink, 1.6)
			c.draw_arc(mouth + Vector2(0, -2.5), 3.0, PI * 0.15, PI * 0.85, 8, ink, 1.5)
		"dead":
			c.draw_line(eye + Vector2(-2.5, -2.5), eye + Vector2(2.5, 2.5), white, 1.6)
			c.draw_line(eye + Vector2(-2.5, 2.5), eye + Vector2(2.5, -2.5), white, 1.6)
			c.draw_line(mouth + Vector2(-f * 3, 0), mouth + Vector2(f * 3, 0), ink, 1.4)
			c.draw_circle(mouth + Vector2(f * 1.5, 1.8), 1.6, Color(1.6, 0.3, 0.4, ink.a))
