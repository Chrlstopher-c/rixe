extends CanvasLayer
## Pilote le shader de post-traitement depuis l'état de Juice et de la caméra.

const SHUTTER := 0.2
var _mat := ShaderMaterial.new()


func _ready() -> void:
	layer = 10
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat.shader = load("res://fx/post.gdshader")
	rect.material = _mat
	add_child(rect)


func _process(delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var real: float = Juice.real_delta(delta)
	var cam: Camera2D = Juice.camera
	var blur := Vector2.ZERO
	if cam:
		blur = (cam.velocity * real * SHUTTER / size).limit_length(0.01)
	_mat.set_shader_parameter("blur", blur)
	_mat.set_shader_parameter("zoom_blur", Juice.zoom_punch * 0.5)
	_mat.set_shader_parameter("aberration", Juice.aberration)
	_mat.set_shader_parameter("aspect", size.x / size.y)
	_mat.set_shader_parameter("waves", _waves(size))


func _waves(size: Vector2) -> PackedVector4Array:
	var out := PackedVector4Array()
	var xf := get_viewport().get_canvas_transform()
	for w in Juice.shockwaves:
		var k: float = w.age / w.life
		var uv: Vector2 = (xf * (w.pos as Vector2)) / size
		out.append(Vector4(uv.x, uv.y, k * 0.4, (1.0 - k) * w.strength))
	while out.size() < 4:
		out.append(Vector4.ZERO)
	return out
