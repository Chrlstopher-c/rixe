class_name Gun
extends RefCounted
## Arme tenue par un combattant : chargeur et réserve, rechargement, cadence, remontée du canon, tir hitscan
## (dispersion, perforation, ricochets) et effets.

signal reloaded

var id: String
var def: Dictionary
var owner: Node2D
var cd := 0.0
var mag := 0
var reserve := 0
var reload_t := 0.0
## Remontée du canon accumulée par les tirs (radians), à compenser à la souris.
var climb := 0.0
var _since_shot := 99.0
## Coup de lame en cours (0 → 1) pour l'animation.
var swing := 0.0
## Accessoires montés (emplacement → identifiant).
var attachments := {}
## Segments du dernier tir [début, fin, 0 rien / 1 décor / 2 cible] : rejoués chez l'autre joueur en ligne.
var segs: Array = []
## Boss : avertissement avant de tirer (secondes restantes).
var charge_t := 0.0


func _init(holder: Node2D, weapon_id: String, mods: Dictionary = {}) -> void:
	owner = holder
	id = weapon_id
	attachments = mods.duplicate()
	def = Arsenal.compose(id, attachments)
	mag = int(def.mag)
	reserve = int(def.reserve)


## Monte un accessoire ; renvoie celui qu'il remplace (ou "").
func equip(att: String) -> String:
	var slot: String = Arsenal.ATTACHMENTS[att].slot
	var old: String = attachments.get(slot, "")
	attachments[slot] = att
	def = Arsenal.compose(id, attachments)
	mag = mini(mag, int(def.mag))
	return old


func kind() -> String:
	return def.get("kind", "hitscan")


func infinite() -> bool:
	return int(def.mag) <= 0


func reloading() -> bool:
	return reload_t > 0.0


## Avancement du rechargement (0 → 1), pour la pose et l'interface.
func reload_progress() -> float:
	return 1.0 - reload_t / float(def.reload) if reload_t > 0.0 else 0.0


func tick(delta: float, trigger: bool, reload_pressed: bool = false) -> void:
	cd -= delta
	swing = maxf(swing - delta * 4.0, 0.0)
	_since_shot += delta
	if _since_shot > 0.18:
		climb = move_toward(climb, 0.0, Arsenal.RECOVER * delta)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			_finish_reload()
		return
	if reload_pressed:
		start_reload()
	if owner.get("boss"):
		trigger = Boss.charge(self, delta, trigger)
	if not trigger or cd > 0.0:
		return
	if infinite():
		cd = def.rate
		_slash()
		return
	if mag <= 0:
		cd = 0.3
		if not start_reload():
			Sfx.play("dry", owner.global_position, -6.0, 0.05)
		return
	cd = def.rate
	mag -= 1
	_since_shot = 0.0
	_fire()


func start_reload() -> bool:
	if infinite() or reload_t > 0.0 or mag >= int(def.mag) or reserve <= 0:
		return false
	reload_t = def.reload
	Sfx.play("reload_out", owner.global_position, -4.0, 0.05)
	Juice.fx.emit(4, owner.rig.ejection_global(), Vector2(-owner.facing * 30.0, -60.0), 2.0, 2.2, Color(0.12, 0.12, 0.16))
	return true


func _finish_reload() -> void:
	var need: int = int(def.mag) - mag
	var take := mini(need, reserve)
	mag += take
	reserve -= take
	Sfx.play("reload_in", owner.global_position, -3.0, 0.05)
	reloaded.emit()


## Direction réelle du tir : la visée, remontée par le recul accumulé.
func shot_dir() -> Vector2:
	return owner.aim_dir.rotated(-climb * owner.facing)


func _fire() -> void:
	segs.clear()
	var dir := shot_dir()
	var muzzle: Vector2 = owner.rig.muzzle_global()
	var spread := _spread()
	if kind() == "projectile":
		_launch(muzzle, dir.rotated(randf_range(-spread, spread)))
	else:
		for i in def.pellets:
			_pellet(muzzle, dir.rotated(randf_range(-spread, spread)))
	climb = minf(climb + float(def.climb) * (0.4 if owner.get("aiming") else 1.0), 0.6)
	owner.rig.recoil = def.recoil
	owner.velocity -= dir * def.kick
	Effects.muzzle(muzzle, dir, def.tracer, def.flash)
	Sfx.play(id, muzzle, 0.0 if owner.is_player else -4.0)
	if Juice.on_screen(muzzle):
		Sfx.add_heat(0.05)
	if def.shell:
		Effects.shell(owner.rig.ejection_global(), dir)
		Sfx.play("shell", muzzle, -14.0, 0.2)
	Juice.shake(def.shake * (1.0 if owner.is_player else 0.4), muzzle)
	if id == "railgun":
		Juice.shockwave(muzzle, 0.6)
		if owner.is_player:
			Juice.aberration += 0.6
	if Juice.net:
		Juice.net.shot_fired(owner, muzzle, dir)


func _spread() -> float:
	var s: float = def.ads_spread if owner.get("aiming") else def.spread
	if owner.body.arms_left() < 2:
		s = s * 2.5 + 0.04
	return s


func _launch(from: Vector2, dir: Vector2) -> void:
	var gren := Grenade.new()
	Juice.world.add_child(gren)
	gren.global_position = from
	gren.setup(owner, dir * float(def.speed) + owner.velocity * 0.3, 3.0, true, def.dmg, def.radius)
	gren.gravity = 320.0
	if Juice.net:
		Juice.net.grenade_thrown(gren)


## Coup de lame : arc devant soi, touche le membre le plus proche, tranche le décor.
func _slash() -> void:
	swing = 1.0
	var dir := shot_dir()
	var origin: Vector2 = owner.global_position + Vector2(0, -24)
	Sfx.play("slash", origin, -2.0, 0.12)
	if Juice.net:
		Juice.net.slashed(owner)
	var landed := false
	for o in owner.get_tree().get_nodes_in_group("fighters"):
		if o == owner or not o.alive:
			continue
		var hit_at := Melee._closest_joint(o, origin)
		var to := hit_at - origin
		if to.length() <= float(def.range) and absf(to.angle_to(dir)) <= 1.1:
			o.take_hit(def.dmg, dir, hit_at, owner, def.knock)
			landed = true
	Juice.arena.damage(origin + dir * float(def.range), def.terrain_dmg, def.terrain_radius, owner)
	if landed:
		Juice.hitstop(0.05)
		Juice.shake(0.2, origin)


func _pellet(from: Vector2, dir: Vector2) -> void:
	_trace(from, dir, def.range, def.dmg, int(def.bounces), [owner.get_rid()])


## Un segment de trajectoire : touche, perce (railgun) ou ricoche sur le décor selon l'angle d'incidence.
func _trace(from: Vector2, dir: Vector2, reach: float, dmg: float, bounces: int, exclude: Array[RID]) -> void:
	var space: PhysicsDirectSpaceState2D = owner.get_world_2d().direct_space_state
	var to: Vector2 = from + dir * reach
	var mask := Juice.MASK_WORLD | Juice.MASK_FIGHTERS | Juice.MASK_PLATFORMS
	if not owner.is_player:
		mask |= Juice.MASK_DOORS
	var end := to
	var hit := {}
	for hop in (6 if def.pierce else 1):
		hit = space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, mask, exclude))
		if hit.is_empty():
			break
		end = hit.position
		if hit.collider.has_method("take_hit"):
			hit.collider.take_hit(dmg, dir, end, owner, def.knock)
			exclude.append(hit.collider.get_rid())
			if def.pierce:
				end = to
				hit = {}
				continue
		elif _graze_legs(end, dir, exclude):
			hit = {}
		break
	Effects.tracer(from, end, def.tracer, def.width, 0.16 if def.pierce else 0.08)
	var ends := 0 if hit.is_empty() else (2 if hit.collider.has_method("take_hit") else 1)
	segs.append([from, end, ends])
	if hit.is_empty() or hit.collider.has_method("take_hit"):
		return
	_hit_world(end, dir, hit.normal, dmg, bounces, reach - from.distance_to(end))


func _hit_world(at: Vector2, dir: Vector2, normal: Vector2, dmg: float, bounces: int, left: float) -> void:
	Juice.arena.damage(at - normal * 2.0, def.terrain_dmg * dmg / def.dmg, def.terrain_radius, owner)
	var graze := 1.0 - absf(dir.dot(normal))
	if bounces > 0 and left > 30.0 and randf() < float(def.ricochet) * (0.25 + graze):
		var jitter: float = def.get("ricochet_spread", 0.12)
		var out := dir.bounce(normal).rotated(randf_range(-jitter, jitter))
		Effects.impact(at, normal, def.tracer * 1.3)
		Sfx.play("ricochet", at, -6.0, 0.2)
		_trace(at + normal * 0.6, out, left * 0.75, dmg * 0.65, bounces - 1, [])
		return
	Effects.impact(at, normal, def.tracer)
	Effects.bullet_hole(at - normal * 1.5)
	Sfx.play("impact", at, -8.0, 0.25)


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
