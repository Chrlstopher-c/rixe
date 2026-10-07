class_name Modes
## Modes de jeu : règles affichées au menu, option réglable (durée ou objectif), clé de classement.

const ORDER := ["arcade", "chrono", "objectif", "survie"]
const ALL := {
	"arcade": {"label": "ARCADE", "desc": "Manches de plus en plus dures · une seule vie", "options": []},
	"chrono": {"label": "CHRONO", "desc": "Un max d'éliminations avant la fin du temps · réapparitions",
		"options": [60, 120, 180, 300, 600], "default": 2},
	"objectif": {"label": "OBJECTIF", "desc": "Le premier à N éliminations gagne · réapparitions",
		"options": [5, 10, 20, 30], "default": 1},
	"survie": {"label": "SURVIE", "desc": "Récolte, construis, mange et tiens la nuit face aux pillards",
		"options": []},
}


static func label(mode: String) -> String:
	return ALL[mode].label


static func has_option(mode: String) -> bool:
	return not (ALL[mode].options as Array).is_empty()


static func default_option(mode: String) -> int:
	return int(ALL[mode].get("default", 0))


static func option_value(mode: String, index: int) -> int:
	var opts: Array = ALL[mode].options
	return int(opts[clampi(index, 0, opts.size() - 1)]) if not opts.is_empty() else 0


static func option_text(mode: String, index: int) -> String:
	var v := option_value(mode, index)
	match mode:
		"chrono":
			return "DURÉE  %d:%02d" % [v / 60, v % 60]
		"objectif":
			return "OBJECTIF  %d ÉLIMINATIONS" % v
	return ""


## Clé de classement : un tableau par mode et par réglage.
static func board_key(mode: String, index: int) -> String:
	return mode if not has_option(mode) else "%s_%d" % [mode, option_value(mode, index)]


## En mode objectif on classe au temps (plus court = mieux), ailleurs au nombre d'éliminations.
static func lower_is_better(mode: String) -> bool:
	return mode == "objectif"


static func respawns(mode: String) -> bool:
	return mode == "chrono" or mode == "objectif"
