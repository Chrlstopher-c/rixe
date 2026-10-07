extends RefCounted
## Tests en ligne (hors « all ») : deux processus du jeu, hôte et invité, reliés par un relais local.
## Lancés par tools/online_test.sh, qui fournit RIXE_RELAY et RIXE_ROOM.


## Empreintes du décor relevées par l'invité à chaque manche reçue (écoute branchée dès la connexion).
var _round_hashes := []


func names() -> Array[String]:
	return ["online_link_host", "online_link_guest", "online_match_host", "online_match_guest", "online_show_host",
		"online_show_guest", "online_checks_host", "online_checks_guest", "online_version_host", "online_version_guest",
		"online_exec_host", "online_exec_guest", "online_board_host", "online_board_guest"]


func _link(t: Node, role: String) -> NetLink:
	var link := NetLink.new()
	t.main.add_child(link)
	link.open(OS.get_environment("RIXE_ROOM"), role)
	return link


func test_online_link_host(t: Node) -> void:
	var link := _link(t, "host")
	var got := []
	link.received.connect(func(m: Dictionary) -> void: got.append(m))
	var here: bool = await t.until(func() -> bool: return link.ready_to_play(), 3000)
	t.check(here, "l'invité a rejoint")
	link.send({"t": "salut", "v": Vector2(1, 2), "list": [1, "deux"]})
	var back: bool = await t.until(func() -> bool: return not got.is_empty(), 1200)
	t.check(back and got[0].get("t") == "retour" and got[0].get("v") == Vector2(3, 4), "réponse de l'invité reçue")
	await t.until(func() -> bool: return link.rtt > 0.0, 1200)
	t.check(link.rtt > 0.0 and link.rtt < 1.0, "latence mesurée (%.0f ms)" % (link.rtt * 1000.0))
	await t.until(func() -> bool: return not link.peer_here, 2400)
	t.check(not link.peer_here, "départ de l'invité détecté")
	link.close()


func test_online_link_guest(t: Node) -> void:
	await t.frames(60)
	var link := _link(t, "guest")
	var got := []
	link.received.connect(func(m: Dictionary) -> void: got.append(m))
	var ok: bool = await t.until(func() -> bool: return link.ready_to_play(), 1200)
	t.check(ok, "l'invité rejoint la partie")
	await t.until(func() -> bool: return not got.is_empty(), 1200)
	t.check(not got.is_empty() and got[0].get("list") == [1, "deux"], "message de l'hôte reçu intact")
	link.send({"t": "retour", "v": Vector2(3, 4)})
	await t.frames(600)
	link.close()
	await t.frames(30)
	var wrong := NetLink.new()
	t.main.add_child(wrong)
	var reasons := []
	wrong.failed.connect(func(r: String) -> void: reasons.append(r))
	wrong.open("QQQQ", "guest")
	await t.until(func() -> bool: return not reasons.is_empty(), 1200)
	t.check(reasons == ["Aucune partie avec ce code"], "code inconnu : message clair (%s)" % [reasons])


# Partie complète : hôte et invité jouent la même manche d'arcade contre les bots.

static func terrain_hash() -> int:
	var h := 0
	var cells: Dictionary = Juice.arena.terrain.kind
	for c in cells:
		h ^= hash([c, cells[c]])
	return h ^ cells.size()


func _inbox(s: NetSession) -> Array:
	var box := []
	s.link.received.connect(func(m: Dictionary) -> void:
		if m.get("t") == "test":
			box.append(m))
	return box


func _say(s: NetSession, step: String, data: Variant = null) -> void:
	s.link.send({"t": "test", "step": step, "data": data})


func _heard(t: Node, box: Array, step: String, frames: int = 1200) -> Variant:
	var found := []
	await t.until(func() -> bool:
		for m in box:
			if m.step == step:
				found.append(m.data)
				return true
		return false, frames)
	return found[0] if not found.is_empty() else "∅"


func _fighters(main: Node, remote: bool, human: bool) -> Array:
	return main._fighters.get_children().filter(func(f: Node) -> bool:
		return f is Fighter and f.alive and f.remote == remote and f.is_player == human)


func test_online_match_host(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	var s := NetSession.begin(main, "host", OS.get_environment("RIXE_ROOM"))
	var box := _inbox(s)
	t.check(await t.until(func() -> bool: return s.connected(), 7200), "l'invité a rejoint")
	main._on_start("arcade", 0)
	var born_hash := terrain_hash()
	main.player.brain = ScriptBrain.new()
	_tough(main.player)
	var puppet_up: bool = await t.until(func() -> bool: return not _fighters(main, true, true).is_empty(), 600)
	t.check(puppet_up, "le combattant de l'invité apparaît chez l'hôte")
	var guest_hash: Variant = await _heard(t, box, "hash")
	t.check(guest_hash == born_hash, "même décor des deux côtés")
	t.check(String(Names.others.get("J2", "")).begins_with("anon"),
		"pseudo de l'invité reçu (%s)" % Names.others.get("J2"))
	var items := get_items(main)
	_say(s, "items", items)
	var p2: Fighter = _fighters(main, true, true)[0] if puppet_up else null
	var x0: float = p2.global_position.x if p2 else 0.0
	await _heard(t, box, "moved")
	await t.frames(30)
	t.check(p2 != null and p2.global_position.x > x0 + 40.0, "l'invité se déplace chez l'hôte (%.0f px)" % [
		(p2.global_position.x - x0) if p2 else 0.0])
	var target_id: Variant = await _heard(t, box, "hit_bot")
	await t.frames(30)
	var bot := _bot_named(main, String(target_id))
	t.check(bot == null or bot.hp < Fighter.MAX_HP, "une balle de l'invité blesse le bot chez l'hôte")
	await _heard(t, box, "fired")
	t.check(main.match_state.stats.has("J2"), "l'invité compte au classement")
	p2 = _fighters(main, true, true)[0] if not _fighters(main, true, true).is_empty() else null
	if p2:
		p2.take_hit(99999.0, Vector2.RIGHT, p2.global_position + Vector2(0, -22), main.player, 0.0)
	var gone: bool = await t.until(func() -> bool: return _fighters(main, true, true).is_empty(), 600)
	t.check(gone and main.match_state.stats.J2.deaths == 1, "l'hôte tue l'invité : mort rejouée, comptée")
	t.check(not main._scoreboard.visible, "l'hôte encore debout : la partie continue")
	for b in _fighters(main, false, false):
		b.shield = 0.0
		b.take_hit(999.0, Vector2.RIGHT, b.global_position + Vector2(0, -22), main.player, 0.0)
	var next: bool = await t.until(func() -> bool: return main.round_no == 2 and main._restart_in < 0.0, 900)
	t.check(next, "tous les bots tombés : manche 2")
	var born2 := terrain_hash()
	var hash2: Variant = await _heard(t, box, "hash2")
	t.check(hash2 == born2, "manche 2 : même décor des deux côtés")
	t.check(await t.until(func() -> bool: return not _fighters(main, true, true).is_empty(), 600),
		"l'invité réapparaît à la manche 2")
	await _heard(t, box, "bye", 600)
	s.leave()


## Les bots tirent pour de vrai : les joueurs du test doivent tenir jusqu'à l'étape où on les tue exprès.
static func _tough(f: Fighter) -> void:
	f.shield = 0.0
	f.hp = 5000.0
	for part in f.body.hp:
		f.body.hp[part] = 5000.0


func get_items(main: Node) -> int:
	return Juice.world.get_children().filter(func(n: Node) -> bool:
		return n is WeaponPickup or n is AttachmentPickup).size()


func _bot_named(main: Node, id: String) -> Fighter:
	for f in main._fighters.get_children():
		if f is Fighter and f.net_id == id:
			return f
	return null


## L'invité peut arriver avant que l'hôte ait ouvert le salon : il réessaie tant que le code est inconnu.
func _join(t: Node, main: Node) -> NetSession:
	for i in 20:
		var s := NetSession.begin(main, "guest", OS.get_environment("RIXE_ROOM"))
		_round_hashes.clear()
		s.link.received.connect(func(m: Dictionary) -> void:
			if m.get("t") == "round":
				_round_hashes.append(terrain_hash()))
		var why := []
		s.ended.connect(func(r: String) -> void: why.append(r))
		await t.until(func() -> bool: return s.connected() or not why.is_empty(), 600)
		if s.connected():
			return s
		s.leave()
		await t.frames(60)
	return NetSession.begin(main, "guest", OS.get_environment("RIXE_ROOM"))


func test_online_match_guest(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	var s := await _join(t, main)
	var box := _inbox(s)
	var hashes := _round_hashes
	var in_game: bool = await t.until(func() -> bool: return is_instance_valid(main.player) and s.started, 1200)
	t.check(in_game, "l'invité entre dans la manche de l'hôte")
	var me: Fighter = main.player
	var brain := ScriptBrain.new()
	me.brain = brain
	_tough(me)
	_say(s, "hash", hashes[0] if not hashes.is_empty() else 0)
	var host_items: Variant = await _heard(t, box, "items")
	await t.frames(30)
	t.check(int(host_items) > 0 and get_items(main) == int(host_items), "mêmes objets au sol (%s / %d)" % [
		host_items, get_items(main)])
	t.check(await t.until(func() -> bool: return not _fighters(main, true, false).is_empty(), 600),
		"les bots de l'hôte apparaissent chez l'invité")
	t.check(not _fighters(main, true, true).is_empty(), "l'hôte apparaît chez l'invité")
	brain.move = 1.0
	await t.frames(90)
	brain.move = 0.0
	_say(s, "moved")
	await t.frames(300)
	var bots := _fighters(main, true, false)
	if not bots.is_empty():
		var b: Fighter = bots[0]
		b.take_hit(12.0, Vector2.RIGHT, b.global_position + Vector2(0, -22), me, 0.0)
		_say(s, "hit_bot", b.net_id)
	brain.aim = me.global_position + Vector2(200, -20)
	brain.fire = true
	await t.frames(30)
	brain.fire = false
	_say(s, "fired")
	var me_ref: WeakRef = weakref(me)
	var died: bool = await t.until(func() -> bool: return me_ref.get_ref() == null or not me_ref.get_ref().alive, 600)
	t.check(died, "tué par l'hôte : l'invité tombe chez lui")
	var round2: bool = await t.until(func() -> bool:
		return main.round_no == 2 and is_instance_valid(main.player) and main.player.alive, 1500)
	t.check(round2, "manche 2 reçue, l'invité réapparaît")
	_say(s, "hash2", hashes[1] if hashes.size() > 1 else 0)
	await t.frames(60)
	_say(s, "bye")
	await t.frames(30)
	s.leave()


# Démo filmable : deux IA jouent en ligne l'une avec l'autre (tools/online_test.sh show, fenêtres réelles).

func test_online_show_host(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	var s := NetSession.begin(main, "host", OS.get_environment("RIXE_ROOM"))
	await t.until(func() -> bool: return s.connected(), 6000)
	main._on_start("arcade", 0)
	main.player.brain = BotBrain.new(1.0, "acrobate")
	await t.frames(120 * 40)
	s.leave()


func test_online_show_guest(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	var s := await _join(t, main)
	await t.until(func() -> bool: return is_instance_valid(main.player) and s.started, 1200)
	for i in 120 * 40:
		if is_instance_valid(main.player) and main.player.brain is PlayerBrain:
			main.player.brain = BotBrain.new(1.0, "brute")
		await t.frames(1)
	s.leave()


# Contrôles : décor identique (et recalage s'il diffère), refus clair si les versions diffèrent.

func test_online_checks_host(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	var s := NetSession.begin(main, "host", OS.get_environment("RIXE_ROOM"))
	var box := _inbox(s)
	t.check(await t.until(func() -> bool: return s.connected(), 7200), "l'invité a rejoint (mêmes versions)")
	main._on_start("arcade", 0)
	_tough(main.player)
	var resyncs: Variant = await _heard(t, box, "resyncs")
	t.check(resyncs == 0, "décor généré à l'identique chez l'invité (recalages : %s)" % [resyncs])
	_say(s, "corrupt", Juice.arena.terrain.checksum())
	var fixed: Variant = await _heard(t, box, "fixed")
	t.check(fixed == true, "décor abîmé chez l'invité : recalé sur celui de l'hôte")
	await _heard(t, box, "bye", 600)
	s.leave()


func test_online_checks_guest(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	var s := await _join(t, main)
	var box := _inbox(s)
	await t.until(func() -> bool: return is_instance_valid(main.player) and s.started, 1200)
	_tough(main.player)
	await t.frames(30)
	_say(s, "resyncs", s.map_resyncs)
	var host_hash: Variant = await _heard(t, box, "corrupt")
	var cells: Dictionary = Juice.arena.terrain.kind
	for i in 40:
		cells.erase(cells.keys()[0])
	s.check_map(int(host_hash) if host_hash is int else 0)
	var done: bool = await t.until(func() -> bool: return s.map_resyncs == 1 and s.map_ok, 600)
	t.check(s.map_resyncs == 1, "écart détecté")
	_say(s, "fixed", done and s.map_ok)
	await t.frames(30)
	_say(s, "bye")
	await t.frames(30)
	s.leave()


func test_online_version_host(t: Node) -> void:
	var s := NetSession.begin(t.main, "host", OS.get_environment("RIXE_ROOM"))
	var why := []
	s.ended.connect(func(r: String) -> void: why.append(r))
	await t.until(func() -> bool: return not why.is_empty(), 3000)
	t.check(not why.is_empty() and String(why[0]).begins_with("Versions différentes"), "hôte : refus clair (%s)" % [why])
	t.check(Juice.net == null, "hôte : partie en ligne fermée")


func test_online_version_guest(t: Node) -> void:
	var s: NetSession = null
	var why := []
	for i in 20:
		s = NetSession.begin(t.main, "guest", OS.get_environment("RIXE_ROOM"))
		s.version = "0.0.0"
		why.clear()
		s.ended.connect(func(r: String) -> void: why.append(r))
		await t.until(func() -> bool: return not why.is_empty(), 600)
		if why.is_empty() or not String(why[0]).begins_with("Aucune"):
			break
		await t.frames(60)
	t.check(not why.is_empty() and String(why[0]).contains("toi 0.0.0"), "invité : refus clair (%s)" % [why])
	t.check(Juice.net == null, "invité : partie en ligne fermée, jamais connecté")


# Exécution d'un bot de l'hôte par l'invité.

func test_online_exec_host(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	var s := NetSession.begin(main, "host", OS.get_environment("RIXE_ROOM"))
	var box := _inbox(s)
	t.check(await t.until(func() -> bool: return s.connected(), 7200), "l'invité a rejoint")
	main._on_start("arcade", 0)
	_tough(main.player)
	await t.until(func() -> bool: return not _fighters(main, true, true).is_empty(), 1200)
	await t.frames(240)
	var guest: Fighter = _fighters(main, true, true)[0]
	var bots := _fighters(main, false, false)
	var bot: Fighter = bots[0]
	for other in bots.slice(1):
		other.queue_free()
	bot.brain = ScriptBrain.new()
	bot.shield = 0.0
	bot.hp = 20.0
	bot.global_position = guest.global_position + Vector2(22, -4)
	_say(s, "bot", bot.net_id)
	var ref: WeakRef = weakref(bot)
	var dead: bool = await t.until(func() -> bool: return ref.get_ref() == null or not ref.get_ref().alive, 1800)
	t.check(dead, "le bot meurt chez l'hôte")
	t.check(main.match_state.kills_of("J2") >= 1, "l'élimination revient à l'invité")
	t.check(bot == null or ref.get_ref() == null or ref.get_ref().executed, "comptée comme exécution")
	await _heard(t, box, "bye", 600)
	s.leave()


func test_online_exec_guest(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	var s := await _join(t, main)
	var box := _inbox(s)
	await t.until(func() -> bool: return is_instance_valid(main.player) and s.started, 1200)
	var me: Fighter = main.player
	var brain := ScriptBrain.new()
	me.brain = brain
	_tough(me)
	var id: Variant = await _heard(t, box, "bot", 2400)
	var found: bool = await t.until(func() -> bool:
		var b: Variant = s.fighters.puppets.get(String(id))
		return is_instance_valid(b) and Execution.staggered(b), 600)
	t.check(found, "bot vacillant visible chez l'invité")
	var b: Fighter = s.fighters.puppets.get(String(id))
	me.global_position = b.global_position + Vector2(-20, 0)
	await t.frames(20)
	t.check(Execution.target_for(me) == b, "l'invité peut l'exécuter")
	brain.press_melee()
	await t.frames(3)
	t.check(me.execution.running(), "exécution lancée chez l'invité")
	var ref: WeakRef = weakref(b)
	var gone: bool = await t.until(func() -> bool: return ref.get_ref() == null or not ref.get_ref().alive, 1200)
	t.check(gone, "le bot tombe chez l'invité")
	await t.frames(60)
	_say(s, "bye")
	await t.frames(30)
	s.leave()


# Classement mondial (Worker) : envoi d'un score sous le pseudo, relecture du top.

func test_online_board_host(t: Node) -> void:
	var wb: WorldBoard = t.main.world_board
	wb.enabled = true
	var board := "chrono_%d" % randi_range(100000, 999999)
	wb.submit(board, 7.0)
	var got: bool = await t.until(func() -> bool: return wb.cache.has(board), 1200)
	var list: Variant = wb.cache.get(board)
	t.check(got and list is Array and not list.is_empty(), "score envoyé puis relu (%s)" % [list])
	t.check(got and list is Array and not list.is_empty() and list[0].name == Names.load_nick() and list[0].score == 7.0,
		"en tête sous mon pseudo")
	t.main._menu.world = true
	t.main._menu.show_title()
	t.main._menu._open("board")
	await t.frames(5)
	wb.enabled = false


func test_online_board_guest(t: Node) -> void:
	await t.frames(5)
	t.check(true, "rien à faire côté invité")
