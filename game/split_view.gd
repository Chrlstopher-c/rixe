class_name SplitView
extends CanvasLayer
## Écran partagé à deux : deux rendus du même monde côte à côte, chacun avec sa caméra, son fond, son
## post-traitement et son interface. Les rendus sont faits en pleine définition puis réduits dans leur moitié.

var cams: Array[Camera2D] = []
var huds: Array[CanvasLayer] = []
var backdrops: Array[CanvasLayer] = []
var subs: Array[SubViewport] = []
var _rects: Array[TextureRect] = []
## Interface principale (cachée) dont les compteurs sont recopiés dans chaque moitié.
var source_hud: CanvasLayer


func _ready() -> void:
	layer = 5
	for i in 2:
		_build_half(i)
	get_viewport().size_changed.connect(_resize)
	_resize()


func _build_half(i: int) -> void:
	var sub := SubViewport.new()
	sub.world_2d = get_viewport().world_2d
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.size_2d_override = Vector2i(320, 360)
	sub.size_2d_override_stretch = true
	add_child(sub)
	var cam: Camera2D = preload("res://core/game_camera.gd").new()
	cam.base_zoom = 0.95
	sub.add_child(cam)
	var back: CanvasLayer = preload("res://arena/backdrop.gd").new()
	back.cam = cam
	sub.add_child(back)
	var post: CanvasLayer = preload("res://fx/post.gd").new()
	post.view_cam = cam
	sub.add_child(post)
	var hud: CanvasLayer = preload("res://hud/hud.gd").new()
	sub.add_child(hud)
	subs.append(sub)
	cams.append(cam)
	backdrops.append(back)
	huds.append(hud)
	_show(sub, i)


## Affiche le rendu d'une moitié réduit dans son demi-écran (et le trait de séparation).
func _show(sub: SubViewport, i: int) -> void:
	var rect := TextureRect.new()
	rect.texture = sub.get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(i * 320.0, 0)
	rect.size = Vector2(320, 360)
	add_child(rect)
	_rects.append(rect)
	if i == 1:
		var line := ColorRect.new()
		line.color = Color(0, 0, 0)
		line.position = Vector2(319, 0)
		line.size = Vector2(2, 360)
		add_child(line)


## Rendu en pleine définition : chaque moitié vaut la moitié de la fenêtre réelle.
func _resize() -> void:
	var win := Vector2(get_window().size)
	for s in subs:
		s.size = Vector2i(maxi(int(win.x * 0.5), 320), maxi(int(win.y), 360))


func bind(players: Array, arena_w: float, mode: String, state: MatchState) -> void:
	for i in 2:
		var cam := cams[i]
		cam.limit_left = -20
		cam.limit_right = int(arena_w) + 20
		cam.limit_top = -440
		cam.limit_bottom = 44
		follow(i, players[i])
		huds[i].mode = mode
		huds[i].match_state = state
		huds[i].show_crosshair = i == 0
	Juice.cameras = cams.duplicate()


func follow(i: int, f: Node2D) -> void:
	cams[i].target = f
	if is_instance_valid(f):
		cams[i].snap_to(f.global_position + Vector2(0, -34))
	huds[i].player = f


func set_theme(name: String) -> void:
	for b in backdrops:
		b.set_theme(name)


## Souris → monde, dans la moitié du joueur n° i (le joueur 1 vise dans la moitié gauche).
func mouse_world(i: int) -> Vector2:
	var m: Vector2 = get_viewport().get_mouse_position()
	var local := m - Vector2(i * 320.0, 0) - Vector2(160, 180)
	var cam := cams[i]
	return cam.get_screen_center_position() + local / cam.zoom


func _process(_delta: float) -> void:
	if not is_instance_valid(source_hud):
		return
	for h in huds:
		h.round_no = source_hud.round_no
		h.bots_left = source_hud.bots_left
		h.kills = source_hud.kills
		h.best = source_hud.best


func _exit_tree() -> void:
	Juice.cameras.clear()
