extends Node2D
## Taches de sang persistantes laissées par les gouttes sur le décor.

const MAX := 1500
var _items: Array[Dictionary] = []
var _dirty := false


func _ready() -> void:
	z_index = 5


func add(pos: Vector2, r: float, color: Color) -> void:
	_items.append({"p": pos, "r": r, "c": color.darkened(randf_range(0.0, 0.35))})
	if _items.size() > MAX:
		_items.pop_front()
	_dirty = true


func clear() -> void:
	_items.clear()
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		queue_redraw()


func _draw() -> void:
	for s in _items:
		draw_set_transform(s.p, 0.0, Vector2(1.6, 0.55))
		draw_circle(Vector2.ZERO, s.r, s.c)
	draw_set_transform(Vector2.ZERO)
