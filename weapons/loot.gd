class_name Loot
extends Node2D
## Butin au sol (munitions, trousse de soin, grenade) : tombe des combattants éliminés, se ramasse en passant.

const GRAVITY := 900.0
const KINDS := {
	"ammo": {"name": "Munitions", "color": Color(1.8, 1.5, 0.6)},
	"medkit": {"name": "Soin", "color": Color(0.6, 2.0, 0.8)},
	"grenade": {"name": "Grenade", "color": Color(0.9, 1.6, 0.5)},
}

var kind := "ammo"
var vel := Vector2.ZERO
var life := 30.0
var _t := 0.0
var net_item := -1


func setup(k: String, v: Vector2) -> void:
	kind = k
	vel = v
	z_index = 8
	add_to_group("loot")


func _ready() -> void:
	if Juice.net:
		Juice.net.item_born(self)


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	vel.y += GRAVITY * delta
	var next := global_position + vel * delta
	if Juice.arena.solid_at(next + Vector2(0, 2)):
		vel = Vector2(vel.x * 0.5, -absf(vel.y) * 0.3) if absf(vel.y) > 60.0 else Vector2(vel.x * 0.8, 0.0)
	else:
		global_position = next
	for f in get_tree().get_nodes_in_group("fighters"):
		var near: bool = f.global_position.distance_to(global_position + Vector2(0, 6)) < 20.0
		if f.alive and not f.remote and near and _apply(f):
			Sfx.play("pickup", global_position, -4.0, 0.15)
			Juice.fx.emit(5, global_position, Vector2.ZERO, 0.2, 8.0, Color(KINDS[kind].color, 0.7))
			queue_free()
			if Juice.net:
				Juice.net.item_changed(self)
			return
	queue_redraw()


## Effet sur le combattant ; false si inutile (on laisse l'objet au sol).
func _apply(f: Node2D) -> bool:
	match kind:
		"ammo":
			var g: Gun = f.gun if not f.gun.infinite() else f.inventory.other()
			if g == null or g.infinite() or g.reserve >= int(g.def.reserve) * 2:
				return false
			g.reserve = mini(g.reserve + int(g.def.mag) * 2, int(g.def.reserve) * 2)
		"medkit":
			if f.inventory.medkits >= Inventory.MAX_MEDKITS:
				if f.hp >= f.MAX_HP:
					return false
				f.hp = minf(f.hp + 25.0, f.MAX_HP)
			else:
				f.inventory.medkits += 1
		"grenade":
			if f.grenades >= 4:
				return false
			f.grenades += 1
	return true


func _draw() -> void:
	var bob := sin(_t * 3.5) * 1.2
	var col: Color = KINDS[kind].color
	var fade := clampf(life / 3.0, 0.0, 1.0)
	draw_set_transform(Vector2(0, -4 + bob))
	match kind:
		"ammo":
			draw_rect(Rect2(-3.5, -2.5, 7, 5), Color(0.25, 0.22, 0.12, fade))
			draw_rect(Rect2(-2.5, -1.5, 5, 1), Color(col, fade))
		"medkit":
			draw_rect(Rect2(-3.5, -3, 7, 6), Color(0.9, 0.9, 0.9, fade))
			draw_rect(Rect2(-0.6, -2.2, 1.2, 4.4), Color(2.0, 0.3, 0.3, fade))
			draw_rect(Rect2(-2.2, -0.6, 4.4, 1.2), Color(2.0, 0.3, 0.3, fade))
		_:
			draw_circle(Vector2.ZERO, 2.6, Color(0.16, 0.2, 0.14, fade))
			draw_circle(Vector2(0.9, -0.9), 0.8, Color(col, fade))
	draw_circle(Vector2.ZERO, 6.0 + sin(_t * 4.0), Color(col, 0.08 * fade))
	draw_set_transform(Vector2.ZERO)
