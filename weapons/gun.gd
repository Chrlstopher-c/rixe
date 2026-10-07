class_name Gun
extends RefCounted
## Arme tenue par un combattant : cadence, tir hitscan (dispersion, perforation), recul et effets.

var id: String
var def: Dictionary
var owner: Node2D
var cd := 0.0


func _init(holder: Node2D, weapon_id: String) -> void:
	owner = holder
	id = weapon_id
	def = Arsenal.WEAPONS[weapon_id]


func tick(delta: float, trigger: bool) -> void:
	cd -= delta
	if trigger and cd <= 0.0:
		cd = def.rate
		_fire()


func _fire() -> void:
	var dir: Vector2 = owner.aim_dir
	var muzzle: Vector2 = owner.rig.muzzle_global()
	var one_hand: bool = owner.body.arms_left() < 2
	var spread: float = def.spread * 2.5 + 0.04 if one_hand else def.spread
	for i in def.pellets:
		_pellet(muzzle, dir.rotated(randf_range(-spread, spread)))
	owner.rig.recoil = def.recoil
	owner.velocity -= dir * def.kick
	Effects.muzzle(muzzle, dir, def.tracer, def.flash)
	Sfx.play(id, muzzle, 0.0 if owner.is_player else -4.0)
	if def.shell:
		Effects.shell(owner.rig.ejection_global(), dir)
		Sfx.play("shell", muzzle, -14.0, 0.2)
	Juice.shake(def.shake * (1.0 if owner.is_player else 0.4), muzzle)
	if id == "railgun":
		Juice.shockwave(muzzle, 0.6)
		if owner.is_player:
			Juice.aberration += 0.6


func _pellet(from: Vector2, dir: Vector2) -> void:
	var space: PhysicsDirectSpaceState2D = owner.get_world_2d().direct_space_state
	var to: Vector2 = from + dir * def.range
	var exclude: Array[RID] = [owner.get_rid()]
	var mask := Juice.MASK_WORLD | Juice.MASK_FIGHTERS | Juice.MASK_PLATFORMS
	var end := to
	for hop in (6 if def.pierce else 1):
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, mask, exclude))
		if hit.is_empty():
			break
		end = hit.position
		var target: Object = hit.collider
		if target.has_method("take_hit"):
			target.take_hit(def.dmg, dir, end, owner, def.knock)
			exclude.append(target.get_rid())
			if def.pierce:
				end = to
				continue
		elif not _graze_legs(end, dir, exclude):
			Effects.impact(end, hit.normal, def.tracer)
			Sfx.play("impact", end, -8.0, 0.25)
		break
	Effects.tracer(from, end, def.tracer, def.width, 0.16 if def.pierce else 0.08)


## Un tir arrêté par le sol au ras d'un pied touche quand même la jambe (sinon viser les pieds est impossible).
func _graze_legs(at: Vector2, dir: Vector2, exclude: Array[RID]) -> bool:
	for f in owner.get_tree().get_nodes_in_group("fighters"):
		if not f.alive or f.get_rid() in exclude:
			continue
		var feet: Vector2 = f.global_position
		if absf(at.x - feet.x) < 8.0 and at.y > feet.y - 12.0 and at.y < feet.y + 4.0:
			var leg := "foot0" if f.body.has("leg0") else "foot1"
			f.take_hit(def.dmg, dir, f.rig.to_global(f.rig.j[leg]) + Vector2(0, -2), owner, def.knock)
			return true
	return false
