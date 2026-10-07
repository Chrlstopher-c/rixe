class_name GameConfig
extends RefCounted
## Réglages d'une partie personnalisée (locale ou en ligne) : mode et durée/objectif, carte, équipes, bots (nombre
## et niveau), armes autorisées, joueurs maximum en ligne, équipe choisie par chaque joueur.

const MAPS := ["hasard", "plateformes", "toits", "mine"]
const LEVELS := {"facile": 0.25, "normal": 0.45, "difficile": 0.65, "expert": 0.85}
const LEVEL_ORDER := ["facile", "normal", "difficile", "expert"]
const ARMS := {
	"toutes": [],
	"pistolets": ["pistol"],
	"automatiques": ["rifle", "smg"],
	"fusils à pompe": ["shotgun"],
	"précision": ["sniper", "railgun"],
	"lames": ["katana"],
	"explosifs": ["launcher"],
}
const ARMS_ORDER := ["toutes", "pistolets", "automatiques", "fusils à pompe", "précision", "lames", "explosifs"]
## Couleurs d'équipe (index 1 à 4) ; 0 = chacun pour soi.
const TEAMS := ["", "rouge", "bleu", "vert", "jaune"]
const TEAM_COLORS := [Color.WHITE, Color(1.0, 0.3, 0.3), Color(0.3, 0.6, 1.0), Color(0.4, 1.0, 0.5),
	Color(1.0, 0.85, 0.3)]
## -1 = nombre de bots automatique (règle habituelle du mode).
const AUTO := -1

## Partie personnalisée (sinon : règles habituelles, difficulté qui monte en arcade).
var custom := false
var mode := "arcade"
var option := 0
var map := "hasard"
## Nombre d'équipes : 0 (chacun pour soi), 2, 3 ou 4.
var teams := 0
var bots := AUTO
var level := "normal"
var arms := "toutes"
var max_players := 2
## Équipe choisie par joueur (identifiant interne → index d'équipe 1..teams).
var team_of := {}


func to_dict() -> Dictionary:
	return {"mode": mode, "option": option, "map": map, "teams": teams, "bots": bots, "level": level, "arms": arms,
		"max_players": max_players, "team_of": team_of, "custom": custom}


static func from_dict(d: Dictionary) -> GameConfig:
	var c := GameConfig.new()
	for k in ["mode", "option", "map", "teams", "bots", "level", "arms", "max_players", "team_of", "custom"]:
		if d.has(k):
			c.set(k, d[k])
	return c


func level_value() -> float:
	return LEVELS.get(level, 0.45)


func forced_map() -> String:
	return "" if map == "hasard" else map


## Armes permises (vide = toutes).
func allowed() -> Array:
	return ARMS.get(arms, [])


func allows(weapon: String) -> bool:
	return allowed().is_empty() or weapon in allowed() or weapon == "pickaxe"


## Arme imposée si celle voulue n'est pas permise.
func pick_weapon(wanted: String, rng: RandomNumberGenerator) -> String:
	if allows(wanted):
		return wanted
	var list := allowed()
	return list[rng.randi_range(0, list.size() - 1)]


## Équipe d'un joueur humain (défaut : répartis l'un après l'autre).
func team_index(id: String, order: int) -> int:
	if teams <= 0 or mode == "arcade":
		return 0
	return clampi(int(team_of.get(id, order % teams + 1)), 1, teams)


static func team_name(i: int) -> String:
	return TEAMS[i] if i > 0 and i < TEAMS.size() else ""
