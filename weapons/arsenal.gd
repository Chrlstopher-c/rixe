class_name Arsenal
## Catalogue des armes : cadence, dégâts, dispersion, recul, couleur de traçante (HDR → bloom).

const WEAPONS := {
	"rifle": {
		"name": "Fusil", "rate": 0.09, "dmg": 9.0, "pellets": 1, "spread": 0.04, "range": 520.0,
		"knock": 45.0, "kick": 8.0, "recoil": 2.0, "shake": 0.07, "tracer": Color(4.0, 2.4, 1.0),
		"width": 1.2, "length": 11.0, "pierce": false, "shell": true, "flash": 4.0, "ideal": 170.0,
		"thick": 1.4,
	},
	"shotgun": {
		"name": "Fusil à pompe", "rate": 0.8, "dmg": 9.0, "pellets": 9, "spread": 0.2, "range": 260.0,
		"knock": 70.0, "kick": 150.0, "recoil": 4.5, "shake": 0.35, "tracer": Color(4.0, 1.7, 0.7),
		"width": 1.0, "length": 10.0, "pierce": false, "shell": true, "flash": 7.0, "ideal": 70.0,
		"thick": 2.0,
	},
	"railgun": {
		"name": "Railgun", "rate": 1.3, "dmg": 80.0, "pellets": 1, "spread": 0.0, "range": 900.0,
		"knock": 300.0, "kick": 110.0, "recoil": 6.0, "shake": 0.5, "tracer": Color(1.0, 2.6, 5.0),
		"width": 3.2, "length": 14.0, "pierce": true, "shell": false, "flash": 6.0, "ideal": 300.0,
		"thick": 1.8,
	},
}


static func ids() -> Array:
	return WEAPONS.keys()
