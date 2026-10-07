class_name Weather
extends Node2D
## Météo autour de la caméra : pluie (gouttes inclinées par le vent, éclaboussures), neige (flocons qui dérivent).

const RAIN := 220
const SNOW := 160

var kind := ""
var _drops: Array[Vector4] = []
var _t := 0.0


func _ready() -> void:
	z_index = 25


## Météo d'une manche : pluie sur les toits (et parfois ailleurs), neige sur l'acier, rien sous terre ; [type, vent].
static func pick(map_type: String, theme_name: String, rng: RandomNumberGenerator) -> Array:
	var w := ""
	if map_type == "toits" or (map_type == "plateformes" and rng.randf() < 0.3):
		w = "rain"
	if theme_name == "acier" and map_type != "toits":
		w = "snow"
	if map_type == "mine":
		w = ""
	return [w, rng.randf_range(-70.0, 70.0) if w != "" else rng.randf_range(-20.0, 20.0)]


func set_kind(k: String) -> void:
	kind = k
	_drops.clear()
	var n := RAIN if k == "rain" else (SNOW if k == "snow" else 0)
	for i in n:
		_drops.append(Vector4(randf() * 760.0, randf() * 460.0, randf_range(0.6, 1.0), randf() * TAU))


func _process(delta: float) -> void:
	_t += delta
	if kind == "":
		return
	var wind: float = Juice.wind
	for i in _drops.size():
		var d := _drops[i]
		if kind == "rain":
			d.y += 520.0 * d.z * delta
			d.x += wind * 1.6 * delta
		else:
			d.y += 34.0 * d.z * delta
			d.x += (wind * 0.8 + sin(_t * 1.3 + d.w) * 14.0) * delta
		d.x = fposmod(d.x, 760.0)
		d.y = fposmod(d.y, 460.0)
		_drops[i] = d
	if kind == "rain" and Juice.camera and randf() < 0.9 and not ("splash" in Juice.off):
		_splash()
	queue_redraw()


func _splash() -> void:
	var c: Vector2 = Juice.camera.get_screen_center_position()
	var x := c.x + randf_range(-340, 340)
	var spots: Array[float] = Juice.arena.stand_spots(x)
	for y in spots:
		if absf(y - c.y) < 220.0:
			var s = Juice.fx.emit(0, Vector2(x, y - 1), Vector2(randf_range(-30, 30), -50), 0.18, 0.6, Color(0.7, 0.8, 1.0, 0.5))
			s.grav = 400.0
			return


func _draw() -> void:
	if kind == "" or not Juice.camera:
		return
	var origin: Vector2 = Juice.camera.get_screen_center_position() - Vector2(380, 230)
	var tilt := Vector2(Juice.wind * 0.012, 1.0)
	for d in _drops:
		var p := origin + Vector2(d.x, d.y)
		if kind == "rain":
			draw_line(p, p + tilt * 9.0 * d.z, Color(0.7, 0.8, 1.0, 0.25 * d.z), 1.0)
		else:
			draw_circle(p, 0.7 + d.z * 0.8, Color(1.6, 1.6, 1.8, 0.6 * d.z))
