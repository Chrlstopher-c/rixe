extends RefCounted
## Tests de la personnalisation : effets des accessoires, montage au sol, déblocage, équipement de départ.


func names() -> Array[String]:
	return ["attachments", "armory"]


func test_attachments(t: Node) -> void:
	var base := Arsenal.compose("rifle", {})
	var tuned := Arsenal.compose("rifle", {"stock": "stock", "mag": "extmag"})
	t.check(tuned.climb < base.climb, "la crosse réduit la remontée")
	t.check(tuned.mag == 45, "chargeur étendu : 45 cartouches (obtenu %d)" % tuned.mag)
	var f: Fighter = t.main.spawn_test_fighter(Vector2(400, -10), ScriptBrain.new())
	await t.until(func() -> bool: return f.is_on_floor(), 120)
	var p := AttachmentPickup.new()
	Juice.world.add_child(p)
	p.global_position = f.global_position + Vector2(0, -20)
	p.setup("scope", Vector2.ZERO)
	await t.frames(20)
	t.check(f.gun.attachments.get("optic", "") == "scope", "la lunette se monte en passant dessus")
	t.check(Unlocks.has("attachment", "scope"), "la lunette est débloquée pour l'armurerie")
	t.check(f.gun.def.ads_reach > 1.0, "la lunette allonge la visée")
	var p2 := AttachmentPickup.new()
	Juice.world.add_child(p2)
	p2.global_position = f.global_position + Vector2(0, -20)
	p2.setup("reddot", Vector2.ZERO)
	await t.frames(20)
	t.check(f.inventory.bag == ["reddot"], "viseur déjà pris : le point rouge va dans le sac")
	t.check(f.inventory.mount(0, 0) and f.gun.attachments.optic == "reddot", "monté depuis le sac")
	t.check(f.inventory.bag == ["scope"], "la lunette retourne au sac")
	t.check(f.inventory.unmount(0, "optic") and not f.gun.attachments.has("optic"), "démontage vers le sac")
	f.queue_free()
	for a in t.main.get_tree().get_nodes_in_group("attachments"):
		a.queue_free()


func test_armory(t: Node) -> void:
	Unlocks.unlock("weapon", "smg")
	Unlocks.unlock("attachment", "stock")
	t.check("smg" in Unlocks.weapons(), "la mitraillette ramassée est disponible")
	t.check("stock" in Unlocks.attachments("stock"), "la crosse est disponible")
	Unlocks.save_loadout({"weapon": "smg", "attachments": {"stock": "stock"}})
	var me: Fighter = t.main._spawn_player(Vector2(500, -10), PlayerBrain.new())
	t.check(me.gun.id == "smg" and me.gun.attachments.get("stock", "") == "stock", "départ avec l'équipement choisi")
	me.queue_free()
	Unlocks.save_loadout({"weapon": "rifle", "attachments": {}})
	await t.frames(2)
