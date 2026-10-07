class_name MatchState
extends RefCounted
## État d'une partie : statistiques par combattant, chrono, objectif, file de réapparitions, fin de partie.

const RESPAWN_DELAY := 2.5

var mode := "arcade"
var option := 0
var stats := {}
var time_left := 0.0
var elapsed := 0.0
var over := false
var winner := ""
var _respawns: Array[Dictionary] = []


func _init(m: String = "arcade", opt: int = 0) -> void:
	mode = m
	option = opt
	time_left = float(Modes.option_value(m, opt)) if m == "chrono" else 0.0


func register(f: Node2D) -> void:
	if not stats.has(f.display_name):
		stats[f.display_name] = {"kills": 0, "deaths": 0, "color": f.team_color, "player": f.is_player,
			"team": f.team if f.team != "joueurs" else ""}


## Compte une mort ; met en file la réapparition si le mode en a.
func record_kill(victim: Node2D, killer: Node2D) -> void:
	if over:
		return
	register(victim)
	stats[victim.display_name].deaths += 1
	var friendly: bool = is_instance_valid(killer) and killer.team != "" and killer.team == victim.team
	if is_instance_valid(killer) and killer != victim and not friendly:
		register(killer)
		stats[killer.display_name].kills += 1
		var target := Modes.option_value(mode, option)
		var team: String = stats[killer.display_name].get("team", "")
		if mode == "objectif" and team != "" and team_kills(team) >= target:
			_finish("ÉQUIPE " + team.to_upper())
		elif mode == "objectif" and team == "" and stats[killer.display_name].kills >= target:
			_finish(killer.display_name)
	if Modes.respawns(mode) and not over:
		_respawns.append({"name": victim.display_name, "color": victim.team_color, "player": victim.is_player,
			"t": RESPAWN_DELAY})


## Avance le temps ; renvoie les réapparitions dues.
func tick(real: float) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	if over:
		return due
	elapsed += real
	if mode == "chrono":
		time_left = maxf(time_left - real, 0.0)
		if time_left <= 0.0:
			_finish(ranking()[0].name if not stats.is_empty() else "")
			return due
	for r in _respawns:
		r.t -= real
		if r.t <= 0.0:
			due.append(r)
	_respawns = _respawns.filter(func(r: Dictionary) -> bool: return r.t > 0.0)
	return due


func respawn_in(name: String) -> float:
	for r in _respawns:
		if r.name == name:
			return r.t
	return -1.0


func finish_arcade() -> void:
	_finish("")


func _finish(who: String) -> void:
	over = true
	winner = who
	_respawns.clear()


## Partie en équipes : éliminations cumulées par équipe (vide en chacun pour soi).
func team_totals() -> Dictionary:
	var out := {}
	for n in stats:
		var t: String = stats[n].get("team", "")
		if t != "":
			out[t] = int(out.get(t, 0)) + int(stats[n].kills)
	return out


func team_kills(team: String) -> int:
	return int(team_totals().get(team, 0))


## Ligne « ROUGE 12 · BLEU 9 », équipe en tête d'abord.
func teams_line() -> String:
	var tot := team_totals()
	var names := tot.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return tot[a] > tot[b])
	return "   ·   ".join(names.map(func(t: String) -> String: return "%s %d" % [t.to_upper(), tot[t]]))


func kills_of(name: String) -> int:
	return int(stats[name].kills) if stats.has(name) else 0


## Classement : éliminations décroissantes, puis morts croissantes.
func ranking() -> Array:
	var rows := []
	for n in stats:
		var s: Dictionary = stats[n]
		rows.append({"name": n, "kills": s.kills, "deaths": s.deaths, "color": s.color, "player": s.player})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.kills > b.kills or (a.kills == b.kills and a.deaths < b.deaths))
	return rows
