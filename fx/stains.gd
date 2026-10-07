extends Node2D
## Taches de sang persistantes, gravées une seule fois dans une texture (SubViewport jamais effacé) :
## coût constant quel que soit le nombre de taches.

const ORIGIN := Vector2(-300, -720)

var _scale := 2.0
var _size := Vector2(2200, 760)
var _view := Sprite2D.new()

var _vp := SubViewport.new()
var _pen := Node2D.new()
var _pending: Array[Dictionary] = []
var _erase: Array[Rect2] = []
var _eraser := ShaderMaterial.new()


func _ready() -> void:
	z_index = 5
	_vp.size = Vector2i(_size * _scale)
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
	_view.texture = _vp.get_texture()
	_view.centered = false
	_view.position = ORIGIN
	_view.scale = Vector2.ONE / _scale
	add_child(_view)


## Adapte la texture à la largeur de carte (moins fine sur les très grandes cartes).
func configure(width: float) -> void:
	var size := Vector2(width + 600.0, 760)
	var scale := 2.0 if width <= 2000.0 else 1.0
	if size == _size and scale == _scale:
		return
	_size = size
	_scale = scale
	_vp.size = Vector2i(_size * _scale)
	_view.scale = Vector2.ONE / _scale
	clear()


func add(pos: Vector2, r: float, color: Color) -> void:
	if "stains" in Juice.off:
		return
	_pending.append({"p": pos, "r": r, "c": color.darkened(randf_range(0.0, 0.35))})


## Efface les taches d'une zone (décor détruit).
func erase(r: Rect2) -> void:
	_erase.append(r)


func _draw_erase(rubber: Node2D) -> void:
	for r in _erase:
		rubber.draw_rect(Rect2((r.position - ORIGIN) * _scale, r.size * _scale).grow(2.0), Color(0, 0, 0, 0))
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
		_pen.draw_set_transform((s.p - ORIGIN) * _scale, 0.0, Vector2(1.6, 0.55) * _scale)
		_pen.draw_circle(Vector2.ZERO, s.r, s.c)
	_pen.draw_set_transform(Vector2.ZERO)
	_pending.clear()
