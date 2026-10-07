class_name RunScore
extends RefCounted
## Score d'une partie (éliminations du joueur jusqu'à sa mort) et record persistant.

var kills := 0
var best := 0


func _init() -> void:
	best = Settings.load_best()


func add_kill() -> void:
	kills += 1


## Termine la partie ; renvoie true si c'est un nouveau record (enregistré).
func end_run(save: bool) -> bool:
	var record := kills > best
	if record and save:
		best = kills
		Settings.save_best(best)
	return record


func reset() -> void:
	kills = 0
