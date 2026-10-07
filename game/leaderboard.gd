class_name Leaderboard
## Classements persistants (top 5 par mode et réglage) dans user://settings.cfg, section [leaderboard].

const SIZE := 5


static func entries(key: String) -> Array:
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	return cfg.get_value("leaderboard", key, [])


## Insère un score ; renvoie son rang (0 = meilleur) ou -1 s'il n'entre pas dans le top.
static func submit(key: String, score: float, lower_better: bool) -> int:
	var list := entries(key)
	var rank := insert(list, score, lower_better)
	if rank >= 0 and Settings.persist:
		var cfg := ConfigFile.new()
		cfg.load(Settings.PATH)
		cfg.set_value("leaderboard", key, list)
		var err := cfg.save(Settings.PATH)
		if err != OK:
			push_warning("classement non enregistré (%d)" % err)
	return rank


## Insère dans la liste triée (modifiée sur place, tronquée au top) ; renvoie le rang ou -1.
static func insert(list: Array, score: float, lower_better: bool) -> int:
	var rank := list.size()
	for i in list.size():
		var other: float = list[i].score
		if (score < other) if lower_better else (score > other):
			rank = i
			break
	if rank >= SIZE:
		return -1
	list.insert(rank, {"score": score, "date": Time.get_date_string_from_system()})
	list.resize(mini(list.size(), SIZE))
	return rank


static func format_score(mode: String, score: float) -> String:
	if Modes.lower_is_better(mode):
		return "%d:%04.1f" % [int(score) / 60, fmod(score, 60.0)]
	return "%d élim." % int(score)
