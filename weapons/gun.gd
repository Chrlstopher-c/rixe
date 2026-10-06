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
	for i in def.pellets:
		_pellet(muzzle, dir.rotated(randf_range(-def.spread, def.spread)))
	owner.rig.recoil = def.recoil
	owner.velocity -= dir * def.kick
	Effects.muzzle(muzzle, dir, def.tracer, def.flash)
	if def.shell:
		Effects.shell(owner.rig.ejection_global(), dir)
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
		else:
			Effects.impact(end, hit.normal, def.tracer)
		break
	Effects.tracer(from, end, def.tracer, def.width, 0.16 if def.pierce else 0.08)
