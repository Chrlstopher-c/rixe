class_name Remains
## Ce qu'un combattant laisse en mourant : armes au sol, butin (munitions, soin, grenade, accessoires du sac),
## et les points du squelette pour le cadavre (sans les membres déjà arrachés).


static func drop_gun(f: Fighter, g: Gun, v: Vector2) -> void:
	if g.kind() == "fists":
		return
	var p := WeaponPickup.new()
	Juice.world.add_child(p)
	p.global_position = f.rig.to_global(f.rig.j.pivot)
	p.setup(g.id, v, f, g.mag, g.reserve, g.attachments)


## Butin laissé à la mort : munitions souvent, soin et grenade parfois, plus les accessoires du sac.
static func drop_loot(f: Fighter) -> void:
	var drops: Array[String] = []
	if randf() < 0.65:
		drops.append("ammo")
	if randf() < 0.35 or f.inventory.medkits > 0:
		drops.append("medkit")
	if f.gun.kind() == "fists":
		drops.erase("ammo")
	elif randf() < 0.3 or f.grenades > 0:
		drops.append("grenade")
	for k in drops:
		var l := Loot.new()
		Juice.world.add_child(l)
		l.global_position = f.global_position + Vector2(0, -16)
		l.setup(k, Vector2(randf_range(-110, 110), randf_range(-240, -140)))
	for att in f.inventory.bag:
		var a := AttachmentPickup.new()
		Juice.world.add_child(a)
		a.global_position = f.global_position + Vector2(0, -16)
		a.setup(att, Vector2(randf_range(-90, 90), randf_range(-220, -140)), f)


static func corpse_points(f: Fighter) -> Dictionary:
	var pts: Dictionary = f.rig.global_joints()
	for part in f.body.missing:
		if part == "torso":
			continue
		var keys: Array = BodyParts.DETACH[part]
		for i in range(1, keys.size()):
			pts.erase(keys[i])
	return pts
