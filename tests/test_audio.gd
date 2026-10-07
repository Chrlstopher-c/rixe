extends RefCounted
## Tests audio : bruitages chargés, musique en couches synchrones qui suit l'action.


func names() -> Array[String]:
	return ["audio"]


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
