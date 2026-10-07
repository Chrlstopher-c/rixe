class_name PhotoMode
extends CanvasLayer
## Mode photo : jeu figé, interface masquée, caméra libre (ZQSD / flèches, molette ou + / - pour le zoom),
## P pour enregistrer l'image (dossier « captures » du jeu), Échap pour revenir.

signal finished

const SPEED := 260.0

var active := false
var _main: Node
var _hint := Control.new()
var _font: Font = ThemeDB.fallback_font
var _saved := ""
var _saved_t := 0.0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.draw.connect(_draw_hint)
	add_child(_hint)
	visible = false


func setup(main: Node) -> void:
	_main = main


func start() -> void:
	active = true
	visible = true
	_main._hud.visible = false
	_main._camera.target = null


func stop() -> void:
	active = false
	visible = false
	_main._hud.visible = true
	_main._camera.target = _main.player
	_main._camera.zoom_extra = 0.0
	finished.emit()


func _process(delta: float) -> void:
	if not active:
		return
	var real: float = Juice.real_delta(delta)
	var move := Vector2(Input.get_axis("left", "right"), Input.get_axis("jump", "down"))
	_main._camera.global_position += move * SPEED * real / _main._camera.zoom.x
	_saved_t -= real
	_hint.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_main._camera.zoom_extra = minf(_main._camera.zoom_extra + 0.1, 2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_main._camera.zoom_extra = maxf(_main._camera.zoom_extra - 0.1, -0.6)
	var k := Controls.menu_key(event)
	match k:
		KEY_P:
			_shoot()
		KEY_EQUAL, KEY_KP_ADD:
			_main._camera.zoom_extra = minf(_main._camera.zoom_extra + 0.1, 2.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_main._camera.zoom_extra = maxf(_main._camera.zoom_extra - 0.1, -0.6)
		KEY_ESCAPE:
			stop()
		_:
			return
	get_viewport().set_input_as_handled()


## Capture sans l'aide à l'écran : on masque l'indication le temps d'une image.
func _shoot() -> void:
	visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	visible = true
	DirAccess.make_dir_recursive_absolute("user://captures")
	var name := "user://captures/rixe-%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	var err := img.save_png(name)
	if err != OK:
		push_warning("capture impossible (%d)" % err)
		_saved = "Capture impossible"
	else:
		_saved = "Enregistrée : " + ProjectSettings.globalize_path(name)
	_saved_t = 3.0


func _draw_hint() -> void:
	var s := _hint.size
	var line := "MODE PHOTO   ·   ZQSD déplacer   ·   molette zoom   ·   P enregistrer   ·   Échap revenir"
	_hint.draw_string(_font, Vector2(0, s.y - 10), line, HORIZONTAL_ALIGNMENT_CENTER, s.x, 8, Color(1, 0.95, 0.95, 0.7))
	if _saved_t > 0.0:
		_hint.draw_string(_font, Vector2(0, 20), _saved, HORIZONTAL_ALIGNMENT_CENTER, s.x, 8, Color(0.6, 2.0, 0.9))
