extends RefCounted
## Tests audio : bruitages chargés, musique en couches synchrones qui suit l'action.


func names() -> Array[String]:
	return ["audio", "announcer", "ambience"]


func test_audio(t: Node) -> void:
	for s in Sfx.SOUNDS:
		var st: AudioStream = Sfx.streams.get(s)
		t.check(st != null and st.get_length() > 0.02, "son %s chargé" % s)
	Sfx.play("rifle", Vector2.ZERO)
	var sync: AudioStreamSynchronized = Sfx.music.stream
	t.check(sync.stream_count == 3, "trois couches musicales")
	var lengths := []
	for i in sync.stream_count:
		var track: AudioStreamWAV = sync.get_sync_stream(i)
		t.check(track.loop_mode == AudioStreamWAV.LOOP_FORWARD, "couche %d en boucle" % i)
		lengths.append(snappedf(track.get_length(), 0.01))
	t.check(lengths[0] > 20.0 and lengths.count(lengths[0]) == 3, "couches de même durée %s" % [lengths])
	Sfx.start_music()
	Sfx.heat = 0.0
	Sfx.tension = false
	await t.frames(480)
	t.check(Sfx.music.playing and Sfx._layer_db[1] < -40.0, "au calme : pas de batterie")
	Sfx.add_heat(0.6)
	await t.frames(120)
	t.check(Sfx._layer_db[1] > -6.0, "fusillade : la couche combat monte (%.0f dB)" % Sfx._layer_db[1])
	Sfx.tension = true
	await t.frames(120)
	t.check(Sfx._layer_db[2] > -6.0, "dernier debout : couche tension")
	Juice.slowmo(1.0, 0.3)
	await t.frames(30)
	t.check(Sfx._lowpass.cutoff_hz < 5000.0, "ralenti : musique assourdie (%.0f Hz, échelle %.2f)" % [
		Sfx._lowpass.cutoff_hz, Engine.time_scale])
	Juice.reset()
	Sfx.heat = 0.0


func test_announcer(t: Node) -> void:
	var a: Announcer = t.main.announcer
	a.reset()
	a.enabled = true
	for k in Announcer.LINES:
		t.check(a.streams.get(k) != null, "voix %s chargée" % k)
	var me: Fighter = t.main.spawn_test_fighter(Vector2(300, -10), ScriptBrain.new(), "rifle", true)
	var bot: Fighter = t.main.spawn_test_fighter(Vector2(500, -10), ScriptBrain.new(), "rifle", false)
	await t.frames(5)
	bot.death_cause = "decap"
	a.last_said = ""
	Juice.fighter_killed.emit(bot, me)
	await t.frames(40)
	t.check(a.last_said == "decap", "décapitation annoncée (%s)" % a.last_said)
	bot.death_cause = "shot"
	Juice.fighter_killed.emit(bot, me)
	await t.frames(80)
	t.check(a.last_said == "double", "deux éliminations rapprochées : doublé (%s)" % a.last_said)
	a.last_said = ""
	Juice.fighter_killed.emit(me, bot)
	await t.frames(60)
	t.check(a.last_said == "", "rien quand c'est un bot qui tue")
	a.enabled = false
	me.queue_free()
	bot.queue_free()


func test_ambience(t: Node) -> void:
	Sfx.set_theme("acier")
	var sync: AudioStreamSynchronized = Sfx.music.stream
	var len_acier: float = sync.get_sync_stream(0).get_length()
	Sfx.set_theme("rouille")
	var len_rouille: float = sync.get_sync_stream(0).get_length()
	t.check(absf(len_acier - len_rouille) > 2.0, "musique différente selon le décor (%.1f s / %.1f s)" % [len_acier,
		len_rouille])
	Sfx.set_place("mine")
	var wet_mine: float = Sfx._reverb.wet
	Sfx.set_place("toits")
	t.check(wet_mine > Sfx._reverb.wet * 3.0, "plus d'écho dans la mine qu'en plein air")
	Sfx.set_theme("crepuscule")
	await t.frames(2)
