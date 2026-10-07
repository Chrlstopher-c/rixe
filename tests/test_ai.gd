extends RefCounted
## Tests des IA : personnalités, comportements (foncer, fuir, esquiver), navigation vers une plateforme, réaction.


func names() -> Array[String]:
	return ["personalities", "behaviours", "navigation", "humanize"]


func _bot(t: Node, pos: Vector2, kind: String, level: float = 0.6) -> Fighter:
	var b := BotBrain.new(level, kind)
	var f: Fighter = t.main.spawn_test_fighter(pos, b, b.p.weapon, false)
	f.team_color = Personality.ARCHETYPES[kind].color
	return f


func _dummy(t: Node, pos: Vector2) -> Fighter:
	var f: Fighter = t.main.spawn_test_fighter(pos, ScriptBrain.new(), "rifle", true)
	f.hp = 9999.0
	f.body.hp = {"head": 9999.0, "torso": 9999.0, "arm0": 9999.0, "arm1": 9999.0, "leg0": 9999.0, "leg1": 9999.0}
	return f


func test_personalities(t: Node) -> void:
	var brute := Personality.make("brute")
	var tireur := Personality.make("tireur")
	var ok := brute.aggression > tireur.aggression and tireur.range_mult > brute.range_mult
	t.check(ok, "brute agressive, tireur à distance")
	t.check(tireur.accuracy > brute.accuracy, "tireur plus précis")
	t.check(Personality.make("renard").flee_hp() > brute.flee_hp(), "le renard décroche plus tôt")
	t.check(Personality.make("tireur", 0.9).reaction < Personality.make("tireur", 0.1).reaction, "niveau → réaction")
	await t.frames(1)


func test_behaviours(t: Node) -> void:
	var me := _dummy(t, Vector2(300, -10))
	var brute := _bot(t, Vector2(700, -10), "brute")
	var brute_ref: WeakRef = weakref(brute)
	var gap := INF
	for i in 480:
		if brute_ref.get_ref():
			gap = minf(gap, brute.global_position.distance_to(me.global_position))
		await t.frames(1)
	t.check(gap < 200.0, "la brute fonce au contact (écart %.0f)" % gap)
	if brute_ref.get_ref():
		brute.queue_free()
	me.global_position = Vector2(300, -10)
	me.velocity = Vector2.ZERO
	var fox := _bot(t, Vector2(420, -10), "renard")
	fox.hp = 15.0
	fox.recent_hit = 0.0
	var fox_ref: WeakRef = weakref(fox)
	await t.frames(300)
	var fled := 999.0
	var fox_now: Node2D = fox_ref.get_ref()
	if fox_now:
		fled = fox_now.global_position.distance_to(me.global_position)
	t.check(fled > 200.0, "le renard blessé s'enfuit (écart %.0f)" % fled)
	if fox_ref.get_ref():
		fox.queue_free()
	me.global_position = Vector2(300, -10)
	me.velocity = Vector2.ZERO
	var acro := _bot(t, Vector2(600, -10), "acrobate", 0.9)
	var jumps := [0]
	acro.jumped.connect(func(_a: bool) -> void: jumps[0] += 1)
	var brain: ScriptBrain = me.brain
	var acro_ref: WeakRef = weakref(acro)
	for i in 480:
		if acro_ref.get_ref():
			brain.aim = acro.global_position + Vector2(0, -22)
		await t.frames(1)
	t.check(jumps[0] >= 3, "l'acrobate visé esquive en sautant (%d sauts en 4 s)" % jumps[0])


func test_navigation(t: Node) -> void:
	Juice.arena.terrain.fill(Rect2(560, -74, 160, 8), Terrain.K.PLAT)
	Juice.arena.platforms.append(Rect2(560, -74, 160, 8))
	Juice.arena.terrain.flush()
	var me := _dummy(t, Vector2(640, -100))
	var tireur := _bot(t, Vector2(300, -10), "tireur")
	tireur.brain.state = BotBrain.State.RUSH
	var up: bool = await t.until(func() -> bool:
		tireur.brain._think = 1.0
		tireur.brain.state = BotBrain.State.RUSH
		return tireur.global_position.y < -60.0 and tireur.is_on_floor(), 600)
	t.check(up, "le bot monte sur la plateforme de sa cible (y=%.0f)" % tireur.global_position.y)
	if is_instance_valid(me):
		me.queue_free()


func test_humanize(t: Node) -> void:
	var me := _dummy(t, Vector2(300, -10))
	var tireur := _bot(t, Vector2(560, -10), "tireur", 0.2)
	var shots := [0]
	var first := [-1]
	var frame := [0]
	for i in 180:
		frame[0] += 1
		if is_instance_valid(tireur) and tireur.gun.cd > 0.0 and first[0] < 0:
			first[0] = frame[0]
		await t.frames(1)
	var react: float = tireur.brain.p.reaction
	var waited: float = first[0] / 120.0
	t.check(first[0] < 0 or waited >= react * 0.7, "pas de tir avant la réaction (%.2f s ≥ %.2f)" % [waited, react])
	t.check(first[0] > 0, "finit par tirer")
	if is_instance_valid(me):
		me.queue_free()
