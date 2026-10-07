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
## Version du protocole réseau : deux jeux ne jouent ensemble que s'ils ont la même version et le même protocole.
const PROTO := 2
## Délai pour recevoir la présentation de l'autre (un jeu trop ancien ne se présente pas).
const HI_TIMEOUT := 5.0

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
var version: String = ProjectSettings.get_setting("application/config/version", "dev")
## L'autre jeu s'est présenté avec la même version.
var peer_ok := false
## Décors recalés depuis l'hôte (invité) : un écart de génération entre machines a été corrigé.
var map_resyncs := 0
## Après un recalage, le décor de l'invité correspond bien à celui de l'hôte.
var map_ok := true
var _hi_wait := -1.0
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
	s.link.joined.connect(s._on_joined)
	s.link.failed.connect(s._on_failed)
	s.link.open(code, role)
	Juice.net = s
	return s


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_host() -> bool:
	return link.is_host()


func connected() -> bool:
	return link.ready_to_play() and peer_ok


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


## Exécution d'une marionnette (bot de l'hôte) par l'invité : l'hôte immobilise le bot et le laisse en vie jusqu'au
## coup de grâce (arraché de tête ou de torse), que l'invité lui transmet comme une touche normale.
func remote_execution(victim: Fighter, by: Fighter) -> void:
	send_event({"t": "exec", "id": victim.net_id, "l": victim.net_life, "by": by.net_id})


func _on_exec(msg: Dictionary) -> void:
	var v: Fighter = fighters._local(String(msg.id), int(msg.l))
	if v == null or v.held:
		return
	v.held = true
	v.executed = true
	var hp0 := v.hp
	v.hp = maxf(v.hp, 500.0)
	v.velocity = Vector2.ZERO
	await get_tree().create_timer(2.5, true, false, true).timeout
	if is_instance_valid(v) and v.alive:
		v.held = false
		v.executed = false
		v.hp = hp0


func item_born(item: Node2D) -> void:
	world.item_born(item)


func item_changed(item: Node2D) -> void:
	world.item_changed(item)


# Manches.

## Manche générée : l'hôte la décrit (graine, carte, place de l'invité), l'invité la regénère à l'identique.
func round_started() -> void:
	started = true
	var h: int = Juice.arena.terrain.checksum()
	if is_host():
		epoch += 1
	fighters.reset()
	world.reset_round()
	if is_host():
		send_event({"t": "round", "seed": main.seed_base, "round": main.round_no, "mode": main.game_mode,
			"opt": main.game_option, "map": main.forced_map, "pos": guest_spot, "h": h})


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
	var real: float = Juice.real_delta(delta)
	if _hi_wait >= 0.0 and not peer_ok:
		_hi_wait -= real
		if _hi_wait < 0.0:
			_refuse("L'autre joueur a une version trop ancienne du jeu (avant %s) : mettez-le à jour" % version)
	if not connected() or not started:
		return
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


func _on_joined(peer_here: bool) -> void:
	if peer_here:
		_greet()


## Présentation à l'autre jeu : version et protocole.
func _greet() -> void:
	peer_ok = false
	_hi_wait = HI_TIMEOUT
	link.send({"t": "hi", "v": version, "p": PROTO, "n": Names.load_nick()})


func _on_hi(msg: Dictionary) -> void:
	var v := String(msg.get("v", "?"))
	if v != version or int(msg.get("p", 0)) != PROTO:
		_refuse("Versions différentes : toi %s, l'autre %s. Mettez le jeu à jour des deux côtés" % [version, v])
		return
	peer_ok = true
	_hi_wait = -1.0
	Names.others[GUEST if is_host() else HOST_LABEL] = Names.clean(String(msg.get("n", ""))) if msg.get("n", "") != "" \
		else (GUEST if is_host() else HOST_LABEL)


func _refuse(reason: String) -> void:
	push_warning("partie en ligne refusée : " + reason)
	_hi_wait = -1.0
	ended.emit(reason)
	leave()


func _on_peer(here: bool) -> void:
	if here:
		_greet()
		return
	peer_ok = false
	if is_host():
		fighters.drop_puppet(GUEST)
		Juice.notify("%s a quitté la partie" % GUEST)
	else:
		ended.emit("L'hôte a quitté la partie")


func _on_message(msg: Dictionary) -> void:
	var t: String = msg.get("t", "")
	if t == "hi":
		_on_hi(msg)
		return
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
		"exec":
			_on_exec(msg)
		"need_map":
			send_event({"t": "map", "pack": Juice.arena.terrain.pack_cells(), "h": Juice.arena.terrain.checksum()})
		"map":
			Juice.arena.terrain.unpack_cells(msg.pack)
			map_ok = Juice.arena.terrain.checksum() == int(msg.h)
			if not map_ok:
				push_warning("décor toujours différent après recalage")
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
	check_map(int(msg.get("h", 0)))


## Invité : décor regénéré comparé à celui de l'hôte ; s'il diffère (calcul différent d'une machine à l'autre),
## l'hôte envoie le sien et l'invité s'y recale.
func check_map(expected: int) -> void:
	if Juice.arena.terrain.checksum() == expected:
		return
	map_resyncs += 1
	map_ok = false
	push_warning("décor différent de l'hôte (manche %d) : recalage" % main.round_no)
	Juice.notify("Décor recalé sur celui de l'hôte")
	send_event({"t": "need_map"})


func _on_match_message(t: String, msg: Dictionary) -> void:
	match t:
		"hud":
			main._hud.remote_info = msg.info
			main._hud.respawn_t = msg.respawn
			main._hud.bots_left = msg.bots
			main.match_state.time_left = msg.time
		"banner":
			main._hud.banner(msg.text)
		"say":
			main.announcer.say(String(msg.k), 0.5)
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
