class_name NetSession
extends Node
## Partie en ligne : relie le jeu au relais. Chacun envoie l'état des combattants dont il a la charge et rejoue
## celui de l'autre ; l'hôte arbitre (bots, objets, manches, fin de partie), l'invité pilote son seul combattant.
## Règle des dégâts : celui qui provoque l'effet le calcule, et transmet les touches subies par une marionnette.

signal ended(reason: String)

const SNAP := 0.05
const HUD_EVERY := 0.25
## Nom du combattant de l'invité côté hôte (comme le 2e joueur en écran partagé).
const GUEST := "J2"
const HOST_LABEL := "Hôte"

var main: Node
var link: NetLink
var fighters := NetFighters.new(self)
var world := NetWorld.new(self)
## Changement reçu en cours d'application : ne pas le renvoyer.
var applying := false
## Dégâts de zone rejoués des deux côtés (barils) : chacun ne touche que ses propres combattants.
var local_only := false
## Manche en cours (l'hôte l'incrémente) : les messages d'une ancienne manche sont ignorés.
var epoch := 0
var guest_spot := Vector2.ZERO
var started := false
var _snap_t := 0.0
var _hud_t := 0.0


static func begin(m: Node, role: String, code: String) -> NetSession:
	var s := NetSession.new()
	s.main = m
	s.link = NetLink.new()
	s.add_child(s.link)
	m.add_child(s)
	s.link.received.connect(s._on_message)
	s.link.peer_changed.connect(s._on_peer)
	s.link.failed.connect(s._on_failed)
	s.link.open(code, role)
	Juice.net = s
	return s


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_host() -> bool:
	return link.is_host()


func connected() -> bool:
	return link.ready_to_play()


func leave() -> void:
	link.close()
	if Juice.net == self:
		Juice.net = null
	queue_free()


func send_event(msg: Dictionary) -> void:
	msg["e"] = epoch
	link.send(msg)


## Nom affiché d'un combattant distant (l'invité voit l'hôte sous « Hôte »).
func label(id: String) -> String:
	return HOST_LABEL if id == "Toi" and not is_host() else id


# Branchements appelés par le jeu (combattants, armes, décor, objets).

func drive(f: Fighter, delta: float) -> void:
	fighters.drive(f, delta)


func puppet_hit(f: Fighter, dmg: float, dir: Vector2, at: Vector2, from: Variant, knock: float, part: String) -> void:
	fighters.puppet_hit(f, dmg, dir, at, from, knock, part)


func local_death(f: Fighter, dir: Vector2, killer: Variant, dmg: float) -> void:
	fighters.local_death(f, dir, killer, dmg)


func shot_fired(owner: Node2D, muzzle: Vector2, dir: Vector2) -> void:
	world.shot_fired(owner, muzzle, dir)


func slashed(owner: Node2D) -> void:
	world.slashed(owner)


func grenade_thrown(g: Grenade) -> void:
	world.grenade_thrown(g)


func terrain_hit(at: Vector2, dmg: float, radius: float) -> void:
	world.terrain_hit(at, dmg, radius)


func prop_event(prop: Node2D, kind: String, dir: Vector2 = Vector2.ZERO) -> void:
	world.prop_event(prop, kind, dir)


func item_born(item: Node2D) -> void:
	world.item_born(item)


func item_changed(item: Node2D) -> void:
	world.item_changed(item)


# Manches.

## Manche générée : l'hôte la décrit (graine, carte, place de l'invité), l'invité la regénère à l'identique.
func round_started() -> void:
	started = true
	if is_host():
		epoch += 1
	fighters.reset()
	world.reset_round()
	if is_host():
		send_event({"t": "round", "seed": main.seed_base, "round": main.round_no, "mode": main.game_mode,
			"opt": main.game_option, "map": main.forced_map, "pos": guest_spot})


## Hôte : réapparition de l'invité (chrono, objectif) ; l'invité recrée son combattant à cet endroit.
func respawn(entry: Dictionary, pos: Vector2) -> bool:
	if entry.name != GUEST:
		return false
	send_event({"t": "spawn", "pos": pos})
	return true


## Invité : son combattant, à la place donnée par l'hôte.
func spawn_guest(pos: Vector2) -> Fighter:
	var f: Fighter = main._spawn_player(pos, PlayerBrain.new())
	f.net_id = GUEST
	if main.game_mode == "arcade":
		f.team = "joueurs"
	return f


func _process(delta: float) -> void:
	if not connected() or not started:
		return
	var real: float = Juice.real_delta(delta)
	_snap_t -= real
	if _snap_t <= 0.0:
		_snap_t = SNAP
		send_event(fighters.snapshot())
		world.flush()
	if is_host():
		_hud_t -= real
		if _hud_t <= 0.0:
			_hud_t = HUD_EVERY
			_send_hud()
	else:
		_spectate()


func _send_hud() -> void:
	var ms: MatchState = main.match_state
	send_event({"t": "hud", "info": main._hud.info_for(GUEST), "time": ms.time_left, "respawn": ms.respawn_in(GUEST),
		"bots": main._hud.bots_left})


## Invité tombé : la caméra suit l'hôte en attendant.
func _spectate() -> void:
	if is_instance_valid(main.player) and main.player.alive:
		return
	var host: Variant = fighters.puppets.get("Toi")
	if is_instance_valid(host) and host.alive and main._camera.target != host:
		main._camera.target = host


func _on_failed(reason: String) -> void:
	ended.emit(reason)


func _on_peer(here: bool) -> void:
	if here:
		return
	if is_host():
		fighters.drop_puppet(GUEST)
		Juice.notify("%s a quitté la partie" % GUEST)
	else:
		ended.emit("L'hôte a quitté la partie")


func _on_message(msg: Dictionary) -> void:
	var t: String = msg.get("t", "")
	if t == "round" and not is_host():
		_on_round(msg)
		return
	if int(msg.get("e", -1)) != epoch:
		return
	applying = true
	match t:
		"s":
			fighters.on_snapshot(msg)
		"hit":
			fighters.on_hit(msg)
		"died":
			fighters.on_died(msg)
		"spawn":
			main.follow(spawn_guest(msg.pos))
		_:
			if not world.on_message(t, msg):
				_on_match_message(t, msg)
	applying = false


func _on_round(msg: Dictionary) -> void:
	epoch = int(msg.e)
	guest_spot = msg.pos
	main.seed_base = int(msg.seed)
	main.forced_map = String(msg.map)
	if not started or main.game_mode != msg.mode or int(msg.round) == 1:
		main._on_start(String(msg.mode), int(msg.opt), int(msg.round))
	else:
		main.round_no = int(msg.round)
		main._start_round()


func _on_match_message(t: String, msg: Dictionary) -> void:
	match t:
		"hud":
			main._hud.remote_info = msg.info
			main._hud.respawn_t = msg.respawn
			main._hud.bots_left = msg.bots
			main.match_state.time_left = msg.time
		"banner":
			main._hud.banner(msg.text)
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
	main.match_state = state
	var rows := state.ranking()
	var texts := EndTexts.make(String(msg.mode), rows, state, int(msg.round), 0)
	main.rules.show_end(texts[0], texts[1], rows, [], -1)


func _mine(id: String) -> String:
	if id == GUEST:
		return "Toi"
	return HOST_LABEL if id == "Toi" else id


## Hôte : fin de partie envoyée avec les statistiques brutes (l'invité refait ses propres textes).
func send_end() -> void:
	var ms: MatchState = main.match_state
	send_event({"t": "end", "mode": ms.mode, "opt": ms.option, "stats": ms.stats, "winner": ms.winner,
		"elapsed": ms.elapsed, "round": main.round_no})
