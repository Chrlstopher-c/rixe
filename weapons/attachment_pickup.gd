class_name AttachmentPickup
extends Node2D
## Accessoire au sol : se monte sur l'arme du premier combattant qui passe (échange si l'emplacement est pris).

const GRAVITY := 900.0

var att := "reddot"
var vel := Vector2.ZERO
var immune: Node2D
var immune_t := 0.0
var _t := 0.0


func setup(id: String, v: Vector2, dropper: Node2D = null) -> void:
	att = id
	vel = v
	immune = dropper
	immune_t = 1.5
	z_index = 8
	add_to_group("attachments")


func _physics_process(delta: float) -> void:
	_t += delta
	immune_t -= delta
	vel.y += GRAVITY * delta
	var next := global_position + vel * delta
	if Juice.arena.solid_at(next + Vector2(0, 2)):
		vel = Vector2(vel.x * 0.5, -absf(vel.y) * 0.3) if absf(vel.y) > 60.0 else Vector2(vel.x * 0.8, 0.0)
	else:
		global_position = next
	_try_grab()
	queue_redraw()


func _try_grab() -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		if not f.alive or not Arsenal.accepts(f.gun.id) or (f == immune and immune_t > 0.0):
			continue
		if f.gun.attachments.values().has(att):
			continue
		if f.global_position.distance_to(global_position + Vector2(0, 8)) < 24.0:
			_mount(f)
			return


func _mount(f: Node2D) -> void:
	var old: String = f.gun.equip(att)
	if f.is_player and Unlocks.unlock("attachment", att):
		Juice.notify("Débloqué : " + String(Arsenal.ATTACHMENTS[att].name))
	Sfx.play("reload_in", global_position, -4.0, 0.1)
	Juice.fx.emit(5, global_position, Vector2.ZERO, 0.25, 10.0, Color(1.4, 2.0, 1.4, 0.8))
	if old == "":
		queue_free()
	else:
		setup(old, Vector2(-f.facing * 60.0, -160.0), f)


func _draw() -> void:
	var bob := sin(_t * 3.0) * 1.5
	for i in 5:
		draw_rect(Rect2(-1.0 - i * 0.4, -30 + i * 2, 2 + i * 0.8, 30 - i * 2), Color(0.5, 1.8, 0.8, 0.08 * (1.0 - i / 5.0)))
	draw_set_transform(Vector2(0, -4 + bob), sin(_t * 1.5) * 0.2)
	draw_rect(Rect2(-3, -2, 6, 4), Color(0.13, 0.12, 0.17))
	draw_rect(Rect2(-3, -2, 6, 4), Color(0.5, 1.8, 0.8), false, 0.8)
	draw_circle(Vector2.ZERO, 0.9, Color(0.6, 2.2, 1.0))
	draw_set_transform(Vector2.ZERO)
