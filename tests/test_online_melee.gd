extends "res://tests/test_online.gd"
## Corps à corps en ligne : l'invité exécute un bot de l'hôte, puis le projette ; l'élimination et les coups reviennent
## à l'hôte. Mêmes utilitaires que test_online.gd.


func names() -> Array[String]:
	return ["online_exec_host", "online_exec_guest", "online_throw_host", "online_throw_guest"]


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
	var dead := false
	for i in 1800:
		var b: Variant = ref.get_ref()
		if b == null or not b.alive:
			dead = true
			break
		if not b.held:
			b.hp = 20.0
			b._since_hit = 0.0
		await t.frames(1)
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
	var near := false
	for i in 15:
		if not is_instance_valid(b):
			break
		me.global_position = b.global_position + Vector2(-20, 0)
		me.velocity = Vector2.ZERO
		await t.frames(12)
		if is_instance_valid(b) and Execution.target_for(me) == b:
			near = true
			break
	t.check(near, "l'invité peut l'exécuter")
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


# Projection en ligne : l'invité saisit un bot de l'hôte ; le coup (dégâts, jet) revient à l'hôte.

func test_online_throw_host(t: Node) -> void:
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
	bot.global_position = guest.global_position + Vector2(18, -4)
	_say(s, "bot", bot.net_id)
	var ref: WeakRef = weakref(bot)
	var hit := false
	for i in 1800:
		var b: Variant = ref.get_ref()
		if b == null or b.hp < Fighter.MAX_HP:
			hit = true
			break
		await t.frames(1)
	t.check(hit, "la projection de l'invité blesse le bot chez l'hôte")
	await _heard(t, box, "bye", 600)
	s.leave()


func test_online_throw_guest(t: Node) -> void:
	var main: Node = t.main
	main.live_rules = true
	var s := await _join(t, main)
	await t.until(func() -> bool: return is_instance_valid(main.player) and s.started, 1200)
	var me: Fighter = main.player
	var brain := ScriptBrain.new()
	me.brain = brain
	_tough(me)
	var box := _inbox(s)
	var id: Variant = await _heard(t, box, "bot", 2400)
	await t.until(func() -> bool: return is_instance_valid(s.fighters.puppets.get(String(id))), 600)
	var b: Variant = s.fighters.puppets.get(String(id))
	var seized := false
	for i in 20:
		if not is_instance_valid(b):
			break
		me.global_position = b.global_position + Vector2(-16, 0)
		me.velocity = Vector2.ZERO
		brain.aim = b.global_position + Vector2(0, -20)
		await t.until(func() -> bool: return me.is_on_floor(), 60)
		await t.frames(2)
		if is_instance_valid(b) and Grapple.target_for(me) == b:
			brain.press_grab()
			await t.frames(3)
			if me.grapple._cd > 0.0:
				seized = true
				break
	t.check(seized, "l'invité saisit le bot distant")
	await t.frames(120)
	_say(s, "bye")
	await t.frames(30)
	s.leave()
