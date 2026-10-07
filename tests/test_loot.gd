extends RefCounted
## Tests du butin et de l'inventaire : objets lâchés à la mort, munitions, soin différé, changement d'arme.


func names() -> Array[String]:
	return ["loot", "inventory", "inventory_screen"]


func test_loot(t: Node) -> void:
	var f: Fighter = t.main.spawn_test_fighter(Vector2(400, -10), ScriptBrain.new(), "rifle", false)
	f.inventory.medkits = 1
	f.grenades = 1
	await t.until(func() -> bool: return f.is_on_floor(), 120)
	f.take_hit(999.0, Vector2.RIGHT, f.global_position + Vector2(0, -22), null, 0.0)
	await t.frames(2)
	var kinds: Array = t.main.get_tree().get_nodes_in_group("loot").map(func(l: Node) -> String: return l.kind)
	t.check("medkit" in kinds and "grenade" in kinds, "trousse et grenade portées tombent (%s)" % str(kinds))
	var me: Fighter = t.main.spawn_test_fighter(Vector2(400, -10), ScriptBrain.new())
	me.gun.reserve = 0
	var ammo := Loot.new()
	Juice.world.add_child(ammo)
	ammo.global_position = Vector2(400, -20)
	ammo.setup("ammo", Vector2.ZERO)
	await t.frames(60)
	t.check(me.gun.reserve > 0, "boîte de munitions ramassée (%d)" % me.gun.reserve)
	for l in t.main.get_tree().get_nodes_in_group("loot"):
		l.queue_free()


func test_inventory(t: Node) -> void:
	var brain := ScriptBrain.new()
	var f: Fighter = t.main.spawn_test_fighter(Vector2(400, -10), brain)
	f.inventory.take(Gun.new(f, "pistol"))
	t.check(f.gun.id == "pistol" and f.inventory.guns.size() == 2, "deuxième arme en main")
	f.inventory.select(0)
	t.check(f.gun.id == "rifle" and f.inventory.switching > 0.0, "touche 1 : retour au fusil, temps de dégainer")
	f.hp = 40.0
	f.inventory.medkits = 1
	t.check(f.inventory.use_medkit(), "trousse utilisée")
	await t.frames(int(Inventory.HEAL_TIME * 120) + 10)
	t.check(f.hp >= 84.0 and f.inventory.medkits == 0, "soin progressif de 45 (%.0f)" % f.hp)


func test_inventory_screen(t: Node) -> void:
	var f: Fighter = t.main.spawn_test_fighter(Vector2(400, -10), ScriptBrain.new())
	f.inventory.take(Gun.new(f, "smg"))
	f.inventory.bag.append("extmag")
	var screen: CanvasLayer = t.main._inventory
	screen.open(f)
	await t.frames(3)
	screen.click({"kind": "bag", "index": 0})
	screen.click({"kind": "slot", "index": 1, "slot": "mag"})
	t.check(f.inventory.guns[1].attachments.get("mag", "") == "extmag", "sac → mitraillette par clics")
	t.check(f.inventory.guns[1].def.mag == 60, "chargeur étendu appliqué (60)")
	screen.click({"kind": "slot", "index": 1, "slot": "mag"})
	t.check(f.inventory.bag == ["extmag"], "clic sur l'accessoire monté : retour au sac")
	screen.close()
