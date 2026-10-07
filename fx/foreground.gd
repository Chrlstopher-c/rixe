class_name Foreground
extends CanvasLayer
## Premier plan en parallaxe : silhouettes sombres collées aux bords de l'écran (câbles avec ampoules en haut,
## feuillages en bas) qui glissent plus vite que le décor quand la caméra avance, sans jamais couvrir le jeu.

const SPAN := 800.0
## Vitesse relative au décor (1 = suit le monde, plus = premier plan).
const SPEED := 1.35

var _strip := Node2D.new()
var _seed := 0
var _map := ""


func _ready() -> void:
	layer = 15
	_strip.draw.connect(_draw_strip)
	add_child(_strip)


func regenerate(seed_value: int, map: String) -> void:
	_seed = seed_value
	_map = map
	visible = map != "survie"
	_strip.queue_redraw()


func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(Juice.camera):
		return
	var cam: Camera2D = Juice.camera
	var x := cam.get_screen_center_position().x * SPEED * cam.zoom.x
	_strip.position.x = -fposmod(x, SPAN)


func _draw_strip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var dark := Color(0.015, 0.01, 0.02, 0.92)
	var h: float = _strip.get_viewport_rect().size.y
	for rep in 3:
		var x0 := rep * SPAN
		if _map != "mine":
			_cables(rng, dark, x0)
		_leaves(rng, dark, x0, h)
		rng.seed = _seed


func _cables(rng: RandomNumberGenerator, dark: Color, x0: float) -> void:
	var x := 0.0
	while x < SPAN:
		var w := rng.randf_range(160, 280)
		var y := rng.randf_range(-6, 4)
		var sag := rng.randf_range(10, 22)
		var pts := PackedVector2Array()
		for i in 17:
			var k := i / 16.0
			pts.append(Vector2(x0 + x + w * k, y + sag * 4.0 * k * (1.0 - k)))
		_strip.draw_polyline(pts, dark, 1.6, true)
		for i in rng.randi_range(2, 4):
			var p := pts[rng.randi_range(3, 13)]
			_strip.draw_line(p, p + Vector2(0, 4), dark, 0.8)
			_strip.draw_circle(p + Vector2(0, 6), 1.6, Color(2.4, 1.7, 0.7, 0.85))
		x += w


func _leaves(rng: RandomNumberGenerator, dark: Color, x0: float, h: float) -> void:
	for i in 5:
		var c := Vector2(x0 + rng.randf_range(0, SPAN), h + rng.randf_range(4, 12))
		for j in 6:
			_strip.draw_circle(c + Vector2(rng.randf_range(-20, 20), rng.randf_range(-12, 4)), rng.randf_range(7, 12),
				dark)
