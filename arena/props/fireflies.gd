class_name Fireflies
extends Node2D
## Lucioles (forêt de nuit) : points lumineux qui dérivent et clignotent autour de ce que regarde la caméra.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.12 or Juice.views().is_empty():
		return
	_t = 0.0
	var view: Rect2 = Juice.views()[0]
	var p := Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y + 40, view.end.y - 20))
	var f = Juice.fx.emit(0, p, Vector2(randf_range(-12, 12), randf_range(-10, 4)), randf_range(1.5, 3.0), 1.2,
		Color(1.8, 2.4, 0.6, 0.9))
	f.drag = 0.5
