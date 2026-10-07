class_name EndTexts
## Titre et sous-titre de l'écran de fin selon le mode et le résultat du joueur.


static func make(mode: String, rows: Array, state: MatchState, round_no: int, nights: int) -> Array[String]:
	var place := 1
	for i in rows.size():
		if rows[i].name == "Toi":
			place = i + 1
	var mine := state.kills_of("Toi")
	if not state.team_totals().is_empty():
		var title := "%s GAGNE" % state.winner if state.winner != "" else "FIN DE PARTIE"
		return [title, state.teams_line()]
	match mode:
		"survie":
			var label := Leaderboard.format_score("survie", nights)
			return ["TU ES TOMBÉ", "%s tenue%s · %d pillards éliminés" % [label, "s" if nights > 1 else "", mine]]
		"chrono":
			return ["TEMPS ÉCOULÉ", "Tu finis %s sur %d · %d éliminations" % [ordinal(place), rows.size(), mine]]
		"objectif":
			if state.winner == "Toi":
				return ["VICTOIRE", "Objectif atteint en %s" % Leaderboard.format_score("objectif", state.elapsed)]
			return ["%s GAGNE" % state.winner.to_upper(), "Tu finis %s · %d éliminations" % [ordinal(place), mine]]
	return ["ÉLIMINÉ", "Manche %d atteinte · %d éliminations" % [round_no, mine]]


static func ordinal(n: int) -> String:
	return "1er" if n == 1 else "%de" % n
