class_name AnimatedDecor
extends Sprite2D
## Décor animé en planche de sprites (sans collision) : ventilateur d'usine, torche de mine, drapeau sur les toits.
## L'animation n'avance que lorsqu'il est à l'écran ; les drapeaux flottent dans le sens du vent.

const KINDS := {
	"fan": {"sheet": preload("res://assets/sprites/fan.png"), "frames": 8, "fps": 18.0, "glow": 1.0},
	"torch": {"sheet": preload("res://assets/sprites/torch.png"), "frames": 6, "fps": 10.0, "glow": 1.8},
	"flag": {"sheet": preload("res://assets/sprites/flag.png"), "frames": 8, "fps": 9.0, "glow": 1.0},
}

var fps := 10.0
var kind := ""
var _t := 0.0


## `at` : point d'ancrage au bas du sprite (sol, support).
func setup(id: String, at: Vector2, phase: float) -> void:
	kind = id
	var k: Dictionary = KINDS[id]
	texture = k.sheet
	hframes = k.frames
	fps = k.fps
	centered = false
	var size := Vector2(texture.get_width() / float(hframes), texture.get_height())
	position = at - Vector2(size.x * 0.5, size.y)
	modulate = Color(k.glow, k.glow, k.glow)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 0
	_t = phase * hframes / fps


func _process(delta: float) -> void:
	if not Juice.on_screen(global_position, 40.0):
		return
	_t += delta
	flip_h = kind == "flag" and Juice.wind < 0.0
	frame = int(_t * fps) % hframes
