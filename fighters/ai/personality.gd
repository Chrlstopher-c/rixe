class_name Personality
extends RefCounted
## Caractère d'un bot : chiffres qui pilotent ses choix (distance, agressivité, prudence, précision, mobilité).

const ARCHETYPES := {
	"brute": {"color": Color(1.0, 0.25, 0.25),
		"name": "Brute", "aggression": 0.95, "range": 0.45, "accuracy": 0.45, "reaction": 0.45,
		"mobility": 0.4, "caution": 0.05, "melee": 0.9, "greed": 0.3, "burst": 4, "weapon": "shotgun",
		"height": 0.0},
	"tireur": {"color": Color(0.75, 0.4, 1.0),
		"name": "Tireur", "aggression": 0.25, "range": 1.6, "accuracy": 0.85, "reaction": 0.3,
		"mobility": 0.3, "caution": 0.6, "melee": 0.1, "greed": 0.7, "burst": 2, "weapon": "railgun",
		"height": 0.9},
	"acrobate": {"color": Color(0.6, 1.0, 0.3),
		"name": "Acrobate", "aggression": 0.6, "range": 0.9, "accuracy": 0.55, "reaction": 0.28,
		"mobility": 0.95, "caution": 0.4, "melee": 0.4, "greed": 0.5, "burst": 5, "weapon": "rifle",
		"height": 0.5},
	"renard": {"color": Color(1.0, 0.6, 0.15),
		"name": "Renard", "aggression": 0.45, "range": 1.1, "accuracy": 0.65, "reaction": 0.35,
		"mobility": 0.55, "caution": 0.9, "melee": 0.2, "greed": 0.85, "burst": 3, "weapon": "rifle",
		"height": 0.4},
	"fou": {"color": Color(1.0, 0.3, 0.8),
		"name": "Fou", "aggression": 0.85, "range": 0.7, "accuracy": 0.3, "reaction": 0.22,
		"mobility": 0.7, "caution": 0.15, "melee": 0.5, "greed": 0.2, "burst": 9, "weapon": "rifle",
		"height": 0.2},
}

var id := "renard"
var label := "Renard"
var aggression := 0.5
var range_mult := 1.0
var accuracy := 0.5
var reaction := 0.35
var mobility := 0.5
var caution := 0.5
var melee := 0.3
var greed := 0.5
var burst := 3
var weapon := "rifle"
var height := 0.3


static func make(archetype: String, level: float = 0.5) -> Personality:
	var p := Personality.new()
	var a: Dictionary = ARCHETYPES[archetype]
	p.id = archetype
	p.label = a.name
	p.aggression = a.aggression
	p.range_mult = a.range
	p.accuracy = clampf(a.accuracy + (level - 0.5) * 0.4, 0.05, 0.98)
	p.reaction = maxf(a.reaction * lerpf(1.4, 0.7, level), 0.12)
	p.mobility = a.mobility
	p.caution = a.caution
	p.melee = a.melee
	p.greed = a.greed
	p.burst = a.burst
	p.weapon = a.weapon
	p.height = a.height
	return p


static func ids() -> Array:
	return ARCHETYPES.keys()


## Seuil de vie sous lequel le bot décroche pour se soigner.
func flee_hp() -> float:
	return lerpf(0.0, 55.0, caution)
