class_name Arsenal
## Catalogue des armes : cadence, dégâts, dispersion, recul, couleur de traçante (HDR → bloom).

const WEAPONS := {
	"rifle": {
		"name": "Fusil", "rate": 0.09, "dmg": 9.0, "pellets": 1, "spread": 0.04, "range": 520.0,
		"knock": 45.0, "kick": 8.0, "recoil": 2.0, "shake": 0.07, "tracer": Color(4.0, 2.4, 1.0),
		"width": 1.2, "length": 11.0, "pierce": false, "shell": true, "flash": 4.0, "ideal": 170.0,
		"thick": 1.4, "terrain_dmg": 12.0, "terrain_radius": 3.0,
		"ricochet": 0.55, "bounces": 2, "mag": 30, "reserve": 90, "reload": 1.4, "climb": 0.022,
	},
	"shotgun": {
		"name": "Fusil à pompe", "rate": 0.8, "dmg": 9.0, "pellets": 9, "spread": 0.2, "range": 260.0,
		"knock": 70.0, "kick": 150.0, "recoil": 4.5, "shake": 0.35, "tracer": Color(4.0, 1.7, 0.7),
		"width": 1.0, "length": 10.0, "pierce": false, "shell": true, "flash": 7.0, "ideal": 70.0,
		"thick": 2.0, "terrain_dmg": 9.0, "terrain_radius": 4.0,
		"ricochet": 0.35, "bounces": 1, "mag": 6, "reserve": 18, "reload": 1.8, "climb": 0.14,
	},
	"railgun": {
		"name": "Railgun", "rate": 1.3, "dmg": 80.0, "pellets": 1, "spread": 0.0, "range": 900.0,
		"knock": 300.0, "kick": 110.0, "recoil": 6.0, "shake": 0.5, "tracer": Color(1.0, 2.6, 5.0),
		"width": 3.2, "length": 14.0, "pierce": true, "shell": false, "flash": 6.0, "ideal": 300.0,
		"thick": 1.8, "terrain_dmg": 90.0, "terrain_radius": 12.0,
		"ricochet": 0.9, "bounces": 1, "mag": 4, "reserve": 8, "reload": 2.2, "climb": 0.16,
	},
	"pistol": {
		"name": "Pistolet", "rate": 0.2, "dmg": 14.0, "pellets": 1, "spread": 0.03, "range": 420.0,
		"knock": 50.0, "kick": 6.0, "recoil": 2.5, "shake": 0.08, "tracer": Color(3.6, 2.6, 1.4),
		"width": 1.0, "length": 7.0, "pierce": false, "shell": true, "flash": 3.5, "ideal": 150.0,
		"thick": 1.3, "terrain_dmg": 10.0, "terrain_radius": 3.0,
		"ricochet": 0.5, "bounces": 1, "mag": 12, "reserve": 48, "reload": 1.0, "climb": 0.05,
	},
	"smg": {
		"name": "Mitraillette", "rate": 0.055, "dmg": 6.0, "pellets": 1, "spread": 0.08, "range": 330.0,
		"knock": 28.0, "kick": 5.0, "recoil": 1.6, "shake": 0.05, "tracer": Color(4.0, 3.0, 1.2),
		"width": 0.9, "length": 9.0, "pierce": false, "shell": true, "flash": 3.0, "ideal": 120.0,
		"thick": 1.6, "terrain_dmg": 7.0, "terrain_radius": 3.0,
		"ricochet": 0.45, "bounces": 1, "mag": 40, "reserve": 120, "reload": 1.6, "climb": 0.012,
	},
	"sniper": {
		"name": "Fusil de précision", "rate": 1.0, "dmg": 95.0, "pellets": 1, "spread": 0.07, "ads_spread": 0.002,
		"range": 1300.0, "knock": 220.0, "kick": 60.0, "recoil": 5.0, "shake": 0.3, "tracer": Color(4.5, 4.5, 4.0),
		"width": 1.6, "length": 16.0, "pierce": false, "shell": true, "flash": 5.0, "ideal": 380.0,
		"thick": 1.5, "terrain_dmg": 30.0, "terrain_radius": 5.0,
		"ricochet": 0.2, "bounces": 1, "mag": 5, "reserve": 15, "reload": 2.4, "climb": 0.2, "look": "scope",
	},
	"launcher": {
		"name": "Lance-grenades", "kind": "projectile", "rate": 0.9, "dmg": 70.0, "pellets": 1, "spread": 0.02,
		"range": 600.0, "knock": 0.0, "kick": 70.0, "recoil": 5.0, "shake": 0.3, "tracer": Color(4.0, 1.6, 0.6),
		"width": 1.0, "length": 12.0, "pierce": false, "shell": false, "flash": 5.0, "ideal": 220.0,
		"thick": 2.8, "terrain_dmg": 0.0, "terrain_radius": 0.0, "speed": 430.0, "radius": 46.0,
		"ricochet": 0.0, "bounces": 0, "mag": 4, "reserve": 12, "reload": 2.0, "climb": 0.12, "look": "tube",
	},
	"katana": {
		"name": "Katana", "kind": "blade", "rate": 0.38, "dmg": 46.0, "pellets": 1, "spread": 0.0, "range": 36.0,
		"knock": 160.0, "kick": -120.0, "recoil": 0.0, "shake": 0.15, "tracer": Color(3.0, 3.4, 4.0),
		"width": 0.0, "length": 15.0, "pierce": false, "shell": false, "flash": 0.0, "ideal": 26.0,
		"thick": 0.9, "terrain_dmg": 18.0, "terrain_radius": 6.0,
		"ricochet": 0.0, "bounces": 0, "mag": 0, "reserve": 0, "reload": 0.1, "climb": 0.0, "look": "blade",
	},
	"pickaxe": {
		"name": "Pioche", "kind": "blade", "rate": 0.42, "dmg": 18.0, "pellets": 1, "spread": 0.0, "range": 30.0,
		"knock": 90.0, "kick": -60.0, "recoil": 0.0, "shake": 0.08, "tracer": Color(2.4, 2.2, 2.0),
		"width": 0.0, "length": 11.0, "pierce": false, "shell": false, "flash": 0.0, "ideal": 24.0,
		"thick": 1.2, "terrain_dmg": 70.0, "terrain_radius": 5.0, "tool": true,
		"ricochet": 0.0, "bounces": 0, "mag": 0, "reserve": 0, "reload": 0.1, "climb": 0.0, "look": "blade",
	},
}

## Accessoires : un par emplacement ; leurs effets multiplient les caractéristiques de l'arme.
const ATTACHMENTS := {
	"reddot": {"name": "Point rouge", "slot": "optic", "mods": {"spread": 0.7, "ads_spread": 0.6}},
	"scope": {"name": "Lunette", "slot": "optic", "mods": {"ads_spread": 0.3, "range": 1.4, "ads_reach": 1.7}},
	"extmag": {"name": "Chargeur étendu", "slot": "mag", "mods": {"mag": 1.5, "reload": 1.15}},
	"barrel": {"name": "Canon long", "slot": "barrel", "mods": {"dmg": 1.15, "range": 1.25, "spread": 0.85,
		"length": 1.25}},
	"stock": {"name": "Crosse", "slot": "stock", "mods": {"climb": 0.55, "kick": 0.6}},
}
const SLOTS := ["optic", "mag", "barrel", "stock"]


## Caractéristiques d'une arme équipée d'accessoires (emplacement → identifiant).
static func compose(id: String, attachments: Dictionary) -> Dictionary:
	var d: Dictionary = WEAPONS[id].duplicate()
	if not d.has("ads_spread"):
		d.ads_spread = d.spread * 0.4
	for slot in attachments:
		var mods: Dictionary = ATTACHMENTS[attachments[slot]].mods
		for k in mods:
			d[k] = float(d.get(k, 1.0)) * float(mods[k])
	d.mag = roundi(float(d.mag))
	return d


static func accepts(id: String) -> bool:
	return WEAPONS[id].get("kind", "hitscan") != "blade"


## Grenades à main par vie, puissance et retard.
const GRENADES := 2
const GRENADE := {"dmg": 80.0, "radius": 52.0, "fuse": 1.7, "throw": 360.0}


## Remontée du canon : retour à zéro (rad/s) quand on cesse de tirer.
const RECOVER := 1.6


## Armes de combat (les outils comme la pioche n'apparaissent pas au hasard).
static func ids() -> Array:
	return WEAPONS.keys().filter(func(w: String) -> bool: return not WEAPONS[w].get("tool", false))
