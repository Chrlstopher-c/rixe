class_name SurvivalDirector
extends Node
## Chef d'orchestre de la survie : récolte (cellules cassées → ressources), lumière jour/nuit, torche du joueur,
## vagues de pillards la nuit, rôdeurs le jour.

const NIGHT_TINT := Color(0.22, 0.24, 0.42)

var state := Survival.new()
var builder := Builder.new()
var spawn_bot: Callable
var backdrop: CanvasLayer
var _shade := CanvasModulate.new()
var _torch := PointLight2D.new()
var _roam := 40.0


func _ready() -> void:
	add_child(state)
	Juice.survival = state
	Juice.world.add_child(builder)
	builder.survival = state
	Juice.world.add_child(_shade)
	Juice.arena.terrain.cell_broken.connect(_on_cell_broken)
	state.night_started.connect(_on_night)
	state.day_started.connect(_on_day)
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.gradient = Gradient.new()
	tex.gradient.set_color(1, Color(1, 1, 1, 0))
	_torch.texture = tex
	_torch.texture_scale = 5.0
	_torch.color = Color(1.0, 0.8, 0.55)


func bind_player(p: Node2D) -> void:
	state.player = p
	builder.player = p
	if _torch.get_parent():
		_torch.get_parent().remove_child(_torch)
	p.add_child(_torch)
	_torch.position = Vector2(0, -20)


func _exit_tree() -> void:
	if Juice.survival == state:
		Juice.survival = null
	for n in [builder, _shade]:
		if is_instance_valid(n):
			n.queue_free()


func _on_cell_broken(_c: Vector2i, k: int, by: Variant) -> void:
	if is_instance_valid(by) and by.get("is_player") and Terrain.YIELD.has(k):
		state.add(Terrain.YIELD[k], 1)


func _process(delta: float) -> void:
	var light := state.daylight()
	var tint := NIGHT_TINT.lerp(Color.WHITE, light)
	_shade.color = tint
	if backdrop:
		backdrop.set_tint(tint)
	_torch.energy = (1.0 - light) * 1.1
	if not state.night:
		_roam -= delta
		if _roam <= 0.0:
			_roam = randf_range(35.0, 60.0)
			_raid(1 + state.day / 3)


func _on_night(day: int) -> void:
	Juice.notify("La nuit tombe : les pillards arrivent")
	_raid(2 + day * 2)


func _on_day(day: int) -> void:
	Juice.notify("Jour %d : tu as tenu la nuit" % day)


## Pillards qui entrent par les bords de la carte, loin du joueur.
func _raid(count: int) -> void:
	if not is_instance_valid(state.player):
		return
	var px: float = state.player.global_position.x
	for i in count:
		var w: float = Juice.arena.W
		var left: bool = px > w * 0.5 if i % 2 == 0 else px < w * 0.5
		var x: float = randf_range(60.0, 400.0) if left else w - randf_range(60.0, 400.0)
		var spots: Array[float] = Juice.arena.stand_spots(x)
		if spots.is_empty():
			continue
		var f: Node2D = spawn_bot.call(Vector2(x, spots[0] - 6.0))
		f.team = "pillards"
		f.brain.raid = true
		f.brain.target = state.player
