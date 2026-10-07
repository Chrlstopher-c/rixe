class_name NetSession
extends Node
## Partie en ligne : relie le jeu au relais. Chacun envoie l'état des combattants dont il a la charge et rejoue
## celui de l'autre ; l'hôte arbitre (bots, objets, manches, fin de partie), l'invité pilote son seul combattant.
## Règle des dégâts : celui qui provoque l'effet le calcule, et transmet les touches subies par une marionnette.

signal ended(reason: String)

const SNAP := 0.05
const HUD_EVERY := 0.25
## Nom affiché de l'hôte chez les invités (avant de connaître son pseudo).
const HOST_LABEL := "Hôte"
## Version du protocole réseau : des jeux ne jouent ensemble que s'ils ont la même version et le même protocole.
const PROTO := 3
## Délai pour recevoir la présentation de l'autre (un jeu trop ancien ne se présente pas).
const HI_TIMEOUT := 5.0

var main: Node
var link: NetLink
var fighters := NetFighters.new(self)
var world := NetWorld.new(self)
var match_sync := NetMatch.new(self)
## Changement reçu en cours d'application : ne pas le renvoyer.
var applying := false
## Dégâts de zone rejoués des deux côtés (barils) : chacun ne touche que ses propres combattants.
var local_only := false
## Manche en cours (l'hôte l'incrémente) : les messages d'une ancienne manche sont ignorés.
var epoch := 0
## Invité : sa place d'apparition ; hôte : place prévue pour chaque invité (identifiant → position).
var guest_spot := Vector2.ZERO
var guest_spots := {}
var started := false
var version: String = ProjectSettings.get_setting("application/config/version", "dev")
## Places des jeux qui se sont présentés avec la même version ; places refusées par l'hôte (version différente).
var ok_slots: Array[int] = []
var _blocked: Array[int] = []
## Décors recalés depuis l'hôte (invité) : un écart de génération entre machines a été corrigé.
var map_resyncs := 0
## Après un recalage, le décor de l'invité correspond bien à celui de l'hôte.
var map_ok := true
## Attente de la présentation de chaque place (secondes restantes).
var _hi_wait := {}
var _snap_t := 0.0
var _hud_t := 0.0


static func begin(m: Node, role: String, code: String, max_players: int = 2) -> NetSession:
	var s := NetSession.new()
	s.main = m
	s.link = NetLink.new()
	s.add_child(s.link)
	m.add_child(s)
	s.link.received.connect(s._on_message)
	s.link.peer_changed.connect(s._on_peer)
	s.link.joined.connect(s._on_joined)
	s.link.failed.connect(s._on_failed)
	s.link.open(code, role, RelayConfig.url(), max_players)
	Juice.net = s
	return s


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_host() -> bool:
	return link.is_host()


## Prêt à jouer : l'invité a reconnu l'hôte ; l'hôte a au moins un invité reconnu.
func connected() -> bool:
	if not link.ready_to_play():
		return false
	return 0 in ok_slots if not is_host() else not ok_slots.is_empty()


## Identifiant de mon combattant : « Toi » pour l'hôte, « J2 » à « J4 » pour les invités (place + 1).
func my_id() -> String:
	return "Toi" if is_host() else slot_id(link.slot)


static func slot_id(slot: int) -> String:
	return "Toi" if slot == 0 else "J%d" % (slot + 1)


## Identifiants des invités reconnus (côté hôte).
func guest_ids() -> Array[String]:
	var out: Array[String] = []
	for sl in ok_slots:
		if sl != 0:
			out.append(slot_id(sl))
	return out


## Joueurs du salon (moi compris), pour l'affichage : [{id, nick, slot}].
func players() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"id": my_id(), "nick": Names.load_nick(), "slot": link.slot}]
	for sl in ok_slots:
		var key := HOST_LABEL if sl == 0 else slot_id(sl)
		out.append({"id": slot_id(sl), "nick": Names.label(key), "slot": sl})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.slot < b.slot)
	return out


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
		send_event(_round_msg(h))


func _round_msg(h: int) -> Dictionary:
	return {"t": "round", "seed": main.seed_base, "round": main.round_no, "mode": main.game_mode,
		"opt": main.game_option, "map": main.forced_map, "spots": guest_spots, "h": h, "cfg": main.config.to_dict()}


## Hôte : places d'apparition des invités, prises après la sienne ; renvoie les index utilisés.
func assign_spots(spots: Array, mine: int) -> Array[int]:
	var used: Array[int] = []
	guest_spots.clear()
	var ids := guest_ids()
	for i in ids.size():
		var k := (mine + 1 + i) % spots.size()
		if k == mine:
			guest_spots[ids[i]] = main.spawner.far_spawn()
			continue
		guest_spots[ids[i]] = spots[k]
		used.append(k)
	return used


## Hôte : réapparition de l'invité (chrono, objectif) ; l'invité recrée son combattant à cet endroit.
func respawn(entry: Dictionary, pos: Vector2) -> bool:
	if not entry.name in guest_ids():
		return false
	send_event({"t": "spawn", "to": entry.name, "pos": pos})
	return true


## Invité : son combattant, à la place donnée par l'hôte.
func spawn_guest(pos: Vector2) -> Fighter:
	var f: Fighter = main._spawn_player(pos, PlayerBrain.new())
	f.net_id = my_id()
	main.spawner.join_team(f, my_id(), link.slot)
	if main.game_mode == "arcade":
		f.team = "joueurs"
	return f


func _process(delta: float) -> void:
	var real: float = Juice.real_delta(delta)
	_tick_hi(real)
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
	for id in guest_ids():
		send_event({"t": "hud", "to": id, "info": main._hud.info_for(id), "time": ms.time_left,
			"respawn": ms.respawn_in(id), "bots": main._hud.bots_left})


## Invité tombé : la caméra suit un autre joueur encore debout.
func _spectate() -> void:
	if is_instance_valid(main.player) and main.player.alive:
		return
	var cam: Variant = main._camera.target
	if is_instance_valid(cam) and cam.alive:
		return
	for p in fighters.puppets.values():
		if is_instance_valid(p) and p.alive and p.is_player:
			main._camera.target = p
			return


func _on_failed(reason: String) -> void:
	ended.emit(reason)


func _on_joined(_peer_here: bool) -> void:
	for sl in link.peers:
		_hi_wait[sl] = HI_TIMEOUT
	_greet()


## Présentation aux autres jeux : version, protocole, pseudo.
func _greet() -> void:
	link.send({"t": "hi", "v": version, "p": PROTO, "n": Names.load_nick()})


func _tick_hi(real: float) -> void:
	for sl: int in _hi_wait.keys():
		_hi_wait[sl] -= real
		if _hi_wait[sl] > 0.0:
			continue
		_hi_wait.erase(sl)
		if sl in ok_slots or sl in _blocked:
			continue
		if sl == 0 and not is_host():
			_refuse("L'hôte a une version trop ancienne du jeu (avant %s) : mettez-le à jour" % version)
		elif is_host():
			_blocked.append(sl)
			Juice.notify("Un joueur avec une version trop ancienne a été refusé")


func _on_hi(msg: Dictionary) -> void:
	var sl: int = msg.get("_from", -1)
	var v := String(msg.get("v", "?"))
	if v != version or int(msg.get("p", 0)) != PROTO:
		var why := "Versions différentes : toi %s, l'hôte %s. Mettez le jeu à jour" % [v, version]
		if is_host():
			_blocked.append(sl)
			link.send({"t": "bye", "to": slot_id(sl), "why": why})
		elif sl == 0:
			_refuse("Versions différentes : toi %s, l'hôte %s. Mettez le jeu à jour des deux côtés" % [version, v])
		return
	if sl in _blocked:
		return
	_hi_wait.erase(sl)
	var nick := Names.clean(String(msg.get("n", "")))
	var key := HOST_LABEL if sl == 0 else slot_id(sl)
	Names.others[key] = nick if nick != "" else key
	if not sl in ok_slots:
		ok_slots.append(sl)
		if is_host() and started:
			_late_join(slot_id(sl))
		elif is_host():
			match_sync.share(match_sync.cfg)


## Hôte : un invité arrive en cours de partie ; il reçoit la manche, sa place et les objets au sol.
func _late_join(id: String) -> void:
	guest_spots[id] = main.spawner.far_spawn()
	var msg := _round_msg(Juice.arena.terrain.checksum())
	msg["to"] = id
	send_event(msg)
	world.announce_all()


func _refuse(reason: String) -> void:
	push_warning("partie en ligne refusée : " + reason)
	_hi_wait.clear()
	ended.emit(reason)
	leave()


func _on_peer(sl: int, here: bool) -> void:
	if here:
		_hi_wait[sl] = HI_TIMEOUT
		_greet()
		return
	ok_slots.erase(sl)
	_hi_wait.erase(sl)
	if sl == 0 and not is_host():
		ended.emit("L'hôte a quitté la partie")
		return
	var id := slot_id(sl)
	fighters.drop_puppet(id)
	Juice.notify("%s a quitté la partie" % Names.label(HOST_LABEL if sl == 0 else id))


func _on_message(msg: Dictionary) -> void:
	var t: String = msg.get("t", "")
	if int(msg.get("_from", -1)) in _blocked:
		return
	if t == "hi":
		_on_hi(msg)
		return
	if msg.has("to") and msg.to != my_id():
		return
	if t == "bye":
		_refuse(String(msg.get("why", "Refusé par l'hôte")))
		return
	if t == "round" and not is_host():
		match_sync.on_round(msg)
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
			send_event({"t": "map", "to": slot_id(int(msg.get("_from", 1))), "pack": Juice.arena.terrain.pack_cells(),
				"h": Juice.arena.terrain.checksum()})
		"map":
			Juice.arena.terrain.unpack_cells(msg.pack)
			map_ok = Juice.arena.terrain.checksum() == int(msg.h)
			if not map_ok:
				push_warning("décor toujours différent après recalage")
		_:
			if not world.on_message(t, msg):
				match_sync.on_message(t, msg)
	applying = false


## Invité : contrôle du décor après une manche (voir NetMatch).
func check_map(expected: int) -> void:
	match_sync.check_map(expected)


## Hôte : fin de partie envoyée aux invités.
func send_end() -> void:
	match_sync.send_end()
