class_name RoundRules
extends RefCounted
## Règles de partie : fil des morts, fin de manche (arcade), fin de partie et kill cam, couche musicale de tension.
## En ligne, seul l'hôte arbitre ; l'invité reçoit bannières, kill cam et écran de fin.

var m: Node


func _init(main: Node) -> void:
	m = main


func on_killed(victim: Node2D, killer: Node2D) -> void:
	if m._tests != "" and not m.live_rules:
		return
	_feed(victim, killer)
	if Juice.net and not Juice.net.is_host():
		return
	m.match_state.record_kill(victim, killer)
	if m.game_mode == "survie" and not m.attract:
		if victim == m.player and not m._scoreboard.visible:
			m.match_state.finish_arcade()
			end_after_kill(victim)
		return
	if is_instance_valid(killer) and killer == m.player:
		m.score.add_kill()
		m._hud.kills = m.score.kills
	if m.attract or m.demo or not Modes.respawns(m.game_mode):
		_rounds_after_kill(victim)
	elif m.match_state.over:
		end_after_kill(victim)


func _feed(victim: Node2D, killer: Node2D) -> void:
	if victim.death_cause == "fall" and not is_instance_valid(killer):
		m._hud.feed("%s  tombe dans le vide" % Names.label(victim.display_name), victim.team_color)
		return
	var kname: String = Names.label(killer.display_name) if is_instance_valid(killer) else "?"
	var verb := "exécute" if victim.executed else "élimine"
	m._hud.feed("%s  %s  %s" % [kname, verb, Names.label(victim.display_name)], victim.team_color)


## Mode arcade (et démo) : la manche se gagne quand plus aucun bot n'est en vie ; à plusieurs humains,
## la partie continue tant que l'un d'eux est debout.
func _rounds_after_kill(victim: Node2D) -> void:
	if m._restart_in >= 0.0:
		return
	if victim.is_player:
		var other := _other_human(victim)
		if other and not m.attract:
			Juice.notify("%s est tombé, %s continue" % [Names.label(victim.display_name),
				Names.label(other.display_name)])
			return
		if m.attract or m.demo:
			m._hud.banner("ÉLIMINÉ")
			m._restart_in = 3.0
		else:
			m.match_state.finish_arcade()
			end_after_kill(victim)
		return
	m._hud.bots_left = alive_bots()
	if victim.boss:
		_announce("boss_down")
		if m._hud.bots_left > 0:
			_kill_cam(victim)
	if m._hud.bots_left == 1:
		_announce("last")
	if m._hud.bots_left <= 0:
		_kill_cam(victim)
		_banner("MANCHE GAGNÉE")
		_announce("round_won")
		m.round_no += 1
		m._restart_in = 3.0


func _other_human(victim: Node2D) -> Node2D:
	for f in m._fighters.get_children():
		if f is Fighter and f != victim and f.alive and f.is_player:
			return f
	return null


func alive_bots() -> int:
	var n := 0
	for f in m._fighters.get_children():
		if f is Fighter and f.alive and not f.is_player:
			n += 1
	return n


## Couche musicale de tension : dernier bot de la manche, vie basse, fin de chrono.
func last_stand() -> bool:
	if m._scoreboard.visible or not is_instance_valid(m.player) or not m.player.alive:
		return false
	if m.player.hp < 30.0:
		return true
	if m.game_mode == "chrono" and m.match_state:
		return m.match_state.time_left < 15.0
	return m.game_mode == "arcade" and m._hud.bots_left == 1


## La dernière élimination se rejoue au ralenti avant l'écran de fin.
func end_after_kill(victim: Node2D) -> void:
	if m._end_in >= 0.0 or m._scoreboard.visible:
		return
	_kill_cam(victim)
	m._end_in = 1.6


func _kill_cam(victim: Node2D) -> void:
	var at: Vector2 = victim.global_position + Vector2(0, -26)
	Juice.kill_cam(at)
	if Juice.net:
		Juice.net.send_event({"t": "killcam", "at": at})


func _announce(key: String) -> void:
	m.announcer.say(key, 0.5)
	if Juice.net:
		Juice.net.send_event({"t": "say", "k": key})


func _banner(text: String) -> void:
	m._hud.banner(text)
	if Juice.net:
		Juice.net.send_event({"t": "banner", "text": text})


## Fin de partie : classement des combattants, score du joueur soumis au tableau du mode, jeu figé.
func end_match() -> void:
	m._end_in = -1.0
	var rows: Array = m.match_state.ranking()
	var key := Modes.board_key(m.game_mode, m.game_option)
	var lower := Modes.lower_is_better(m.game_mode)
	var mine: int = m.match_state.kills_of("Toi")
	var value: float = m.match_state.elapsed if lower else float(mine)
	var director: Variant = m.director
	if m.game_mode == "survie":
		value = float(director.state.nights_survived) if is_instance_valid(director) else 0.0
	var counts: bool = not lower or m.match_state.winner == "Toi"
	var rank := Leaderboard.submit(key, value, lower) if counts and (lower or value > 0.0) else -1
	if counts and value > 0.0:
		m.world_board.submit(key, value)
	m.score.end_run(m.game_mode == "arcade")
	m.score.reset()
	m._hud.best = m.score.best
	m._menu.best = m.score.best
	var nights: int = director.state.nights_survived if is_instance_valid(director) else 0
	var texts := EndTexts.make(m.game_mode, rows, m.match_state, m.round_no, nights)
	if Juice.net:
		Juice.net.send_end()
	show_end(texts[0], texts[1], rows, Leaderboard.entries(key), rank)


func show_end(title: String, sub: String, rows: Array, board: Array, rank: int) -> void:
	m._hud.visible = false
	m._scoreboard.open(title, sub, rows, m.game_mode, board, rank)
	if not Juice.net:
		m.get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_ui("round", -4.0)
