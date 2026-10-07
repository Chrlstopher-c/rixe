class_name Press
extends Node2D
## Presse hydraulique (usine) : repos en haut, alerte (bandes clignotantes et voyant), descente éclair jusqu'au sol,
## puis remontée. Écrase ce qui est dessous (chaque machine ne blesse que ses propres combattants en ligne).

const IDLE := 2.6
const WARN := 0.8
const SLAM := 0.12
const HOLD := 0.45
const RISE := 1.1
const DAMAGE := 220.0

var top := -200.0
var floor_y := 0.0
var width := 40.0
var _t := 0.0
var _hit := false


func setup(x: float, top_y: float, bottom_y: float, phase: float) -> void:
	position = Vector2(x, 0)
	top = top_y
	floor_y = bottom_y
	_t = phase
	z_index = 3


## Hauteur du bas de la tête selon le cycle (0 = en haut, 1 = au sol).
func _drop() -> float:
	var t := fmod(_t, IDLE + WARN + SLAM + HOLD + RISE)
	if t < IDLE + WARN:
		return 0.0
	t -= IDLE + WARN
	if t < SLAM:
		return t / SLAM
	t -= SLAM
	return 1.0 if t < HOLD else 1.0 - (t - HOLD) / RISE


func _warning() -> bool:
	var t := fmod(_t, IDLE + WARN + SLAM + HOLD + RISE)
	return t > IDLE and t < IDLE + WARN


func _physics_process(delta: float) -> void:
	var before := _drop()
	_t += delta
	var now := _drop()
	if now >= 1.0 and before < 1.0:
		_slam()
	if Juice.on_screen(Vector2(position.x, floor_y), 80.0):
		queue_redraw()


func _bottom() -> float:
	return lerpf(top + 40.0, floor_y, _drop())


func _slam() -> void:
	var at := Vector2(position.x, floor_y)
	for f in get_tree().get_nodes_in_group("fighters"):
		var d: Vector2 = f.global_position - at
		if f.alive and absf(d.x) < width * 0.5 + 4.0 and d.y > -60.0 and d.y < 4.0:
			f.take_hit(DAMAGE, Vector2.DOWN, f.global_position + Vector2(0, -26), null, 60.0)
	Effects.dust(at, 10, 2.0)
	Sfx.play("land", at, 6.0, 0.05)
	Juice.shake(0.45, at)


func _draw() -> void:
	var b := _bottom() - position.y
	var w := width
	draw_rect(Rect2(-4, top, 8, b - top - 22), Color(0.3, 0.3, 0.34))
	draw_rect(Rect2(-w * 0.5, b - 22, w, 22), Color(0.16, 0.16, 0.2))
	var stripes := Color(2.2, 1.6, 0.2) if not _warning() or fmod(_t, 0.2) < 0.1 else Color(0.3, 0.2, 0.05)
	for i in 5:
		var x := -w * 0.5 + i * w / 5.0
		draw_line(Vector2(x, b - 4), Vector2(x + w / 10.0, b), stripes, 2.0)
	draw_circle(Vector2(0, b - 15), 2.5, Color(2.6, 0.3, 0.2) if _warning() else Color(0.3, 0.1, 0.1))
