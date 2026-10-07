class_name Profile
extends Node
## Progression du joueur : expérience et niveau, statistiques, succès, défi du jour, tenues débloquées par niveau.
## Écoute les événements du jeu (éliminations, exécutions, parades, manches) ; enregistré dans les réglages.

signal leveled(level: int)
signal achieved(id: String)

const XP := {"kill": 10, "head": 5, "exec": 15, "round": 25, "boss": 60, "parry": 8, "daily": 200}
const ACHIEVEMENTS := {
	"first_blood": {"name": "Premier sang", "desc": "Une première élimination", "stat": "kills", "goal": 1},
	"butcher": {"name": "Boucher", "desc": "100 éliminations", "stat": "kills", "goal": 100},
	"headhunter": {"name": "Chasseur de têtes", "desc": "50 tirs à la tête mortels", "stat": "heads", "goal": 50},
	"decap": {"name": "Décapiteur", "desc": "10 décapitations", "stat": "decaps", "goal": 10},
	"executioner": {"name": "Bourreau", "desc": "5 exécutions", "stat": "execs", "goal": 5},
	"parry": {"name": "Mur", "desc": "10 parades", "stat": "parries", "goal": 10},
	"bossbane": {"name": "Tueur de boss", "desc": "Abattre un boss", "stat": "bosses", "goal": 1},
	"survivor": {"name": "Survivant", "desc": "Atteindre la manche 10 en arcade", "stat": "best_round", "goal": 10},
	"flawless": {"name": "Intouchable", "desc": "5 éliminations d'affilée sans être touché", "stat": "flawless",
		"goal": 1},
	"veteran": {"name": "Vétéran", "desc": "Finir 25 parties", "stat": "matches", "goal": 25},
	"daily": {"name": "Assidu", "desc": "Réussir 5 défis du jour", "stat": "dailies", "goal": 5},
	"online": {"name": "En réseau", "desc": "Jouer une partie en ligne", "stat": "online", "goal": 1},
}
const DAILIES := [
	{"id": "heads", "text": "10 éliminations par la tête", "stat": "heads", "goal": 10},
	{"id": "execs", "text": "3 exécutions", "stat": "execs", "goal": 3},
	{"id": "kills", "text": "40 éliminations", "stat": "kills", "goal": 40},
	{"id": "rounds", "text": "Gagner 5 manches", "stat": "rounds", "goal": 5},
	{"id": "parries", "text": "3 parades", "stat": "parries", "goal": 3},
	{"id": "decaps", "text": "5 décapitations", "stat": "decaps", "goal": 5},
]

var xp := 0
var stats := {}
var unlocked: Array = []
var daily := {}
## Tenue choisie (voir Outfit).
var outfit := {}
## Désactivé pendant les tests (sauf si un test le force) : rien n'est écrit.
var enabled := Settings.persist


func _ready() -> void:
	var data: Variant = Settings.get_pref("profile", "data", {})
	if data is Dictionary:
		xp = int(data.get("xp", 0))
		stats = data.get("stats", {})
		unlocked = data.get("unlocked", [])
		daily = data.get("daily", {})
		outfit = data.get("outfit", {})
	_roll_daily()
	Juice.fighter_killed.connect(_on_killed)
	Juice.executed.connect(func(_v: Node2D, k: Node2D) -> void:
		if Fighter.local_human(k):
			add("execs", 1, XP.exec))
	Juice.feat.connect(_on_feat)


func _on_feat(kind: String) -> void:
	match kind:
		"parry":
			add("parries", 1, XP.parry)
		"flawless":
			add("flawless", 1, 30)
		"throw":
			add("throws", 1, 8)


static func level_of(points: int) -> int:
	return int(floor(sqrt(points / 60.0))) + 1


func level() -> int:
	return level_of(xp)


## Progression vers le niveau suivant (0 à 1).
func progress() -> float:
	var l := level()
	var lo := 60 * (l - 1) * (l - 1)
	var hi := 60 * l * l
	return float(xp - lo) / float(hi - lo)


func stat(key: String) -> int:
	return int(stats.get(key, 0))


## Ajoute à une statistique (et de l'expérience) ; vérifie succès et défi du jour.
func add(key: String, n: int, points: int = 0) -> void:
	stats[key] = stat(key) + n
	gain(points)
	_check()


## Garde le maximum (meilleure manche…).
func best(key: String, value: int) -> void:
	if value > stat(key):
		stats[key] = value
		_check()


func gain(points: int) -> void:
	if points <= 0:
		return
	var before := level()
	xp += points
	if level() > before:
		leveled.emit(level())
		Juice.notify("NIVEAU %d" % level())
		for o in Outfit.unlocked_at(level()):
			Juice.notify("Tenue débloquée : %s" % o)
	save()


func _on_killed(victim: Node2D, killer: Node2D) -> void:
	if not Fighter.local_human(killer) or killer == victim:
		return
	add("kills", 1, XP.kill)
	if victim.death_cause in ["headshot", "decap"]:
		add("heads", 1, XP.head)
	if victim.death_cause == "decap":
		add("decaps", 1)
	if victim.get("boss"):
		add("bosses", 1, XP.boss)


func _check() -> void:
	for id: String in ACHIEVEMENTS:
		var a: Dictionary = ACHIEVEMENTS[id]
		if not id in unlocked and stat(a.stat) >= int(a.goal):
			unlocked.append(id)
			achieved.emit(id)
			Juice.notify("Succès : %s" % a.name)
	if not daily.is_empty() and not daily.get("done", false):
		var d := current_daily()
		if stat(d.stat) - int(daily.get("start", 0)) >= int(d.goal):
			daily.done = true
			stats["dailies"] = stat("dailies") + 1
			Juice.notify("Défi du jour réussi ! +%d XP" % XP.daily)
			gain(XP.daily)
	save()


## Défi du jour : tiré d'après la date, mesuré depuis le début de la journée.
func current_daily() -> Dictionary:
	return DAILIES[int(daily.get("index", 0)) % DAILIES.size()]


func daily_progress() -> int:
	return mini(stat(current_daily().stat) - int(daily.get("start", 0)), int(current_daily().goal))


func _roll_daily() -> void:
	var today := Time.get_date_string_from_system()
	if daily.get("date", "") == today:
		return
	var idx := absi(hash(today)) % DAILIES.size()
	daily = {"date": today, "index": idx, "start": stat(DAILIES[idx].stat), "done": false}
	save()


func save() -> void:
	if enabled and Settings.persist:
		Settings.set_pref("profile", "data", {"xp": xp, "stats": stats, "unlocked": unlocked, "daily": daily,
			"outfit": outfit})
