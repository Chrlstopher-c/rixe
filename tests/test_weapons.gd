extends RefCounted
## Tests de l'armurerie : chargeur et réserve, rechargement, munitions ramassées, visée précise, remontée du canon.


func names() -> Array[String]:
	return ["ammo", "aim_recoil"]


func test_ammo(t: Node) -> void:
	var brain := ScriptBrain.new()
	var f: Fighter = t.main.spawn_test_fighter(Vector2(400, -10), brain, "shotgun")
	await t.until(func() -> bool: return f.is_on_floor(), 120)
	brain.aim = Vector2(800, -20)
	brain.fire = true
	await t.until(func() -> bool: return f.gun.mag == 0, 900)
	brain.fire = false
	t.check(f.gun.mag == 0 and f.gun.reserve == 18, "6 cartouches tirées, réserve intacte")
	f.gun.start_reload()
	t.check(f.gun.reloading(), "rechargement lancé")
	await t.until(func() -> bool: return not f.gun.reloading(), 600)
	t.check(f.gun.mag == 6 and f.gun.reserve == 12, "chargeur plein, réserve entamée (%d/%d)" % [f.gun.mag, f.gun.reserve])
	f.gun.mag = 0
	f.gun.reserve = 0
	var p := WeaponPickup.new()
	Juice.world.add_child(p)
	p.global_position = f.global_position + Vector2(0, -20)
	p.setup("shotgun", Vector2.ZERO)
	await t.frames(20)
	t.check(f.gun.reserve == 24, "même arme au sol = munitions récupérées (%d)" % f.gun.reserve)


func test_aim_recoil(t: Node) -> void:
	var brain := ScriptBrain.new()
	var f: Fighter = t.main.spawn_test_fighter(Vector2(400, -10), brain, "rifle")
	await t.until(func() -> bool: return f.is_on_floor(), 120)
	brain.aim = Vector2(900, -27)
	brain.fire = true
	await t.frames(60)
	brain.fire = false
	var climbed: float = f.gun.climb
	t.check(climbed > 0.1, "une rafale fait remonter le canon (%.2f rad)" % climbed)
	t.check(f.gun.shot_dir().y < f.aim_dir.y - 0.05, "le tir part plus haut que la visée")
	await t.frames(120)
	t.check(f.gun.climb < climbed * 0.3, "le canon redescend quand on arrête")
	brain.move = 1.0
	await t.frames(40)
	var free_speed := absf(f.velocity.x)
	brain.aiming = true
	await t.frames(40)
	t.check(f.aiming and absf(f.velocity.x) < free_speed * 0.75, "visée précise : déplacement ralenti")
	t.check(f.gun._spread() < f.gun.def.spread, "visée précise : dispersion réduite")
