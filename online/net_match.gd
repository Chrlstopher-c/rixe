class_name NetMatch
extends RefCounted
## Partie en ligne côté déroulé : l'invité regénère chaque manche de l'hôte (même graine), vérifie le décor,
## reçoit interface, bannières, kill cam et écran de fin ; l'hôte envoie la fin de partie.

var s: Node
## Réglages de la partie en préparation, tels que l'hôte les a fixés (affichés dans le salon de chacun).
var cfg := GameConfig.new()


func _init(session: Node) -> void:
	s = session


func on_round(msg: Dictionary) -> void:
	s.epoch = int(msg.e)
	s.guest_spot = msg.spots.get(s.my_id(), s.main.spawner.far_spawn()) if msg.has("spots") else Vector2(800, -60)
	s.main.seed_base = int(msg.seed)
	s.main.forced_map = String(msg.map)
	var cfg := GameConfig.from_dict(msg.get("cfg", {}))
	if not s.started or s.main.game_mode != msg.mode or int(msg.round) == 1:
		s.main._on_start(String(msg.mode), int(msg.opt), int(msg.round), cfg)
	else:
		s.main.config = cfg
		s.main.spawner.config = cfg
		s.main.round_no = int(msg.round)
		s.main._start_round()
	check_map(int(msg.get("h", 0)))


## Invité : décor regénéré comparé à celui de l'hôte ; s'il diffère (calcul différent d'une machine à l'autre),
## l'hôte envoie le sien et l'invité s'y recale.
func check_map(expected: int) -> void:
	if Juice.arena.terrain.checksum() == expected:
		return
	s.map_resyncs += 1
	s.map_ok = false
	push_warning("décor différent de l'hôte (manche %d) : recalage" % s.main.round_no)
	Juice.notify("Décor recalé sur celui de l'hôte")
	s.send_event({"t": "need_map"})


## Hôte : nouveaux réglages, envoyés à tous les invités.
func share(c: GameConfig) -> void:
	cfg = c
	s.send_event({"t": "cfg", "cfg": c.to_dict()})


## Invité : demande à rejoindre une équipe (l'hôte tranche et renvoie les réglages).
func ask_team(team: int) -> void:
	cfg.team_of[s.my_id()] = team
	s.send_event({"t": "team", "team": team})


func on_message(t: String, msg: Dictionary) -> void:
	match t:
		"cfg":
			cfg = GameConfig.from_dict(msg.cfg)
		"team":
			if s.is_host():
				cfg.team_of[NetSession.slot_id(int(msg.get("_from", 1)))] = int(msg.team)
				share(cfg)
		"hud":
			s.main._hud.remote_info = msg.info
			s.main._hud.respawn_t = msg.respawn
			s.main._hud.bots_left = msg.bots
			s.main.match_state.time_left = msg.time
		"banner":
			s.main._hud.banner(msg.text)
		"say":
			s.main.announcer.say(String(msg.k), 0.5)
		"killcam":
			Juice.kill_cam(msg.at)
		"end":
			_show_end(msg)


## Écran de fin de l'invité : le classement de l'hôte, vu de l'invité (« Toi » = l'invité, « Hôte » = l'hôte).
func _show_end(msg: Dictionary) -> void:
	var state := MatchState.new(String(msg.mode), int(msg.opt))
	for id: String in msg.stats:
		state.stats[_mine(id)] = msg.stats[id]
	state.winner = _mine(String(msg.winner))
	state.elapsed = float(msg.elapsed)
	state.over = true
	s.main.match_state = state
	var rows := state.ranking()
	var texts := EndTexts.make(String(msg.mode), rows, state, int(msg.round), 0)
	s.main.rules.show_end(texts[0], texts[1], rows, [], -1)


func _mine(id: String) -> String:
	if id == s.my_id():
		return "Toi"
	return NetSession.HOST_LABEL if id == "Toi" else id


## Hôte : fin de partie envoyée avec les statistiques brutes (l'invité refait ses propres textes).
func send_end() -> void:
	var ms: MatchState = s.main.match_state
	s.send_event({"t": "end", "mode": ms.mode, "opt": ms.option, "stats": ms.stats, "winner": ms.winner,
		"elapsed": ms.elapsed, "round": s.main.round_no})
