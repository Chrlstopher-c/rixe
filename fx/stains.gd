extends Node2D
## Taches de sang persistantes, gravées une seule fois dans une texture (SubViewport jamais effacé) :
## coût constant quel que soit le nombre de taches.

const SCALE := 2.0
const ORIGIN := Vector2(-300, -720)
const SIZE := Vector2(2200, 760)

var _vp := SubViewport.new()
var _pen := Node2D.new()
var _pending: Array[Dictionary] = []
var _erase: Array[Rect2] = []
var _eraser := ShaderMaterial.new()


func _ready() -> void:
	z_index = 5
	_vp.size = Vector2i(SIZE * SCALE)
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_pen.draw.connect(_draw_pending)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nrender_mode blend_disabled;\nvoid fragment() { COLOR = vec4(0.0); }"
	_eraser.shader = sh
	var rubber := Node2D.new()
	rubber.material = _eraser
	rubber.draw.connect(func() -> void: _draw_erase(rubber))
	rubber.name = "Rubber"
	_vp.add_child(rubber)
	_vp.add_child(_pen)
	add_child(_vp)
	var view := Sprite2D.new()
	view.texture = _vp.get_texture()
	view.centered = false
	view.position = ORIGIN
	view.scale = Vector2.ONE / SCALE
	add_child(view)


func add(pos: Vector2, r: float, color: Color) -> void:
	if "stains" in Juice.off:
		return
	_pending.append({"p": pos, "r": r, "c": color.darkened(randf_range(0.0, 0.35))})


## Efface les taches d'une zone (décor détruit).
func erase(r: Rect2) -> void:
	_erase.append(r)


func _draw_erase(rubber: Node2D) -> void:
	for r in _erase:
		rubber.draw_rect(Rect2((r.position - ORIGIN) * SCALE, r.size * SCALE).grow(2.0), Color(0, 0, 0, 0))
	_erase.clear()


func clear() -> void:
	_pending.clear()
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE


func _process(_delta: float) -> void:
	_pen.queue_redraw()
	if not _erase.is_empty():
		_vp.get_node("Rubber").queue_redraw()


func _draw_pending() -> void:
	for s in _pending:
		_pen.draw_set_transform((s.p - ORIGIN) * SCALE, 0.0, Vector2(1.6, 0.55) * SCALE)
		_pen.draw_circle(Vector2.ZERO, s.r, s.c)
	_pen.draw_set_transform(Vector2.ZERO)
	_pending.clear()
