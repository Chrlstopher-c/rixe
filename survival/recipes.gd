class_name Recipes
## Fabrication (survie) : munitions, soins, grenades à partir des ressources récoltées.

const ALL := [
	{"id": "munitions", "name": "Munitions (+1 chargeur x2)", "cost": {"metal": 1}},
	{"id": "soin", "name": "Trousse de soin", "cost": {"nourriture": 3}},
	{"id": "grenade", "name": "Grenade", "cost": {"metal": 2, "pierre": 1}},
]


static func cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s" % [cost[k], Survival.NAMES[k].to_lower()])
	return ", ".join(parts)


## Fabrique pour ce combattant ; false si trop cher ou inutile (déjà plein).
static func craft(id: String, s: Survival, f: Node2D) -> bool:
	var r: Dictionary = {}
	for x in ALL:
		if x.id == id:
			r = x
	if r.is_empty() or not s.can_afford(r.cost):
		return false
	match id:
		"munitions":
			var g: Gun = f.gun if not f.gun.infinite() else f.inventory.other()
			if g == null or g.infinite():
				return false
			g.reserve += int(g.def.mag) * 2
		"soin":
			if f.inventory.medkits >= Inventory.MAX_MEDKITS:
				return false
			f.inventory.medkits += 1
		"grenade":
			if f.grenades >= 4:
				return false
			f.grenades += 1
	s.spend(r.cost)
	Sfx.play_ui("reload_in", -4.0)
	return true
