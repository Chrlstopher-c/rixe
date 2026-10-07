extends RefCounted
## Test du ramassage : une arme au sol est échangée contre celle du combattant qui passe dessus.


func names() -> Array[String]:
	return ["pickup", "bot_pickup"]


func test_pickup(t: Node) -> void:
	var brain := ScriptBrain.new()
	var f: Fighter = t.main.spawn_test_fighter(Vector2(500, -10), brain, "rifle", true)
	var p := WeaponPickup.new()
	Juice.world.add_child(p)
	p.global_position = Vector2(560, -30)
	p.setup("railgun", Vector2.ZERO)
	await t.until(func() -> bool: return f.is_on_floor(), 120)
	brain.move = 1.0
	var got: bool = await t.until(func() -> bool: return f.gun.id == "railgun", 240)
	brain.move = 0.0
	t.check(got, "le combattant ramasse le railgun en passant dessus")
	t.check(is_instance_valid(p) and p.weapon_id == "rifle", "son ancien fusil reste au sol")
	await t.frames(60)
	t.check(f.gun.id == "railgun", "pas de ré-échange immédiat (immunité)")
	f.take_hit(999.0, Vector2.RIGHT, f.global_position + Vector2(0, -22), null, 0.0)
	await t.frames(2)
	var n := 0
	for c in Juice.world.get_children():
		if c is WeaponPickup and c.weapon_id == "railgun":
			n += 1
	t.check(n == 1, "l'arme tombe à la mort")


func test_bot_pickup(t: Node) -> void:
	var bot: Fighter = t.main.spawn_test_fighter(Vector2(500, -10), BotBrain.new(0.5), "rifle", false)
	var p := WeaponPickup.new()
	Juice.world.add_child(p)
	p.global_position = Vector2(680, -30)
	p.setup("railgun", Vector2.ZERO)
	var got: bool = await t.until(func() -> bool: return bot.gun.id == "railgun", 600)
	t.check(got, "le bot va chercher le railgun posé à 180 px")
