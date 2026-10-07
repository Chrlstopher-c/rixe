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
}


## Remontée du canon : retour à zéro (rad/s) quand on cesse de tirer.
const RECOVER := 1.6


static func ids() -> Array:
	return WEAPONS.keys()
