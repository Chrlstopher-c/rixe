extends CanvasLayer
## Décor de fond en parallaxe : ciel, 4 couches de montagnes low poly, brumes, braises flottantes.

const LAYERS := [[0.05, 40.0], [0.12, 70.0], [0.22, 100.0], [0.36, 132.0]]

var _sprites: Array[Sprite2D] = []
var _hazes: Array[Sprite2D] = []
var _embers: Node2D
var _ember_data: Array[Vector4] = []
var _t := 0.0
var _sky: Sprite2D
var _ember := Color(2.2, 0.9, 0.4)


func _ready() -> void:
	layer = -10
	_sky = Sprite2D.new()
	_sky.centered = false
	add_child(_sky)
	for i in LAYERS.size():
		_sprites.append(_sprite(null))
		if i < LAYERS.size() - 1:
			_hazes.append(_sprite(null))
	_embers = Node2D.new()
	_embers.draw.connect(_draw_embers)
	add_child(_embers)
	for i in 70:
		_ember_data.append(Vector4(randf() * 640, randf() * 360, randf_range(0.2, 1.0), randf() * TAU))
	set_theme("crepuscule")


func set_theme(name: String) -> void:
	var cfg: Dictionary = Themes.ALL[name]
	_sky.texture = Themes.texture(name, "sky")
	for i in _sprites.size():
		_sprites[i].texture = Themes.texture(name, "mtn%d" % i)
	for h in _hazes:
		h.texture = _haze_texture(cfg.haze)
	_ember = cfg.ember


## Calque répété horizontalement : on fait défiler sa région plutôt que de le déplacer (cartes de toute largeur).
func _sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 900, 360)
	add_child(s)
	return s


## Teinte jour/nuit appliquée au ciel, aux montagnes et aux brumes.
func set_tint(c: Color) -> void:
	for s in get_children():
		if s is Sprite2D:
			s.modulate = c


func _haze_texture(haze: Color) -> GradientTexture2D:
	var g := GradientTexture2D.new()
	g.width = 1800
	g.height = 360
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(haze, 0.0))
	g.gradient.set_color(1, Color(haze, 0.28))
	return g


func _process(delta: float) -> void:
	_t += delta
	var c := Vector2(320, -110)
	if Juice.camera:
		c = Juice.camera.get_screen_center_position()
	for i in _sprites.size():
		var f: float = LAYERS[i][0]
		var pos := Vector2(-80.0, LAYERS[i][1] - (c.y + 110.0) * f * 0.6)
		var scroll := roundf((c.x - 320.0) * f)
		_sprites[i].position = pos.round()
		_sprites[i].region_rect.position.x = scroll
		if i < _hazes.size():
			_hazes[i].position = pos.round() + Vector2(0, 40)
	_embers.queue_redraw()


func _draw_embers() -> void:
	for e in _ember_data:
		var y := fposmod(e.y - _t * 12.0 * e.z, 380.0) - 10.0
		var x := e.x + sin(_t * 0.8 + e.w) * 8.0
		_embers.draw_circle(Vector2(x, y), 0.6 + e.z * 0.6, Color(_ember, 0.35 + e.z * 0.5))
