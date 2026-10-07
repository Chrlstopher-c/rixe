extends RefCounted
## Tests audio : tous les bruitages se chargent et ont une durée.


func names() -> Array[String]:
	return ["audio"]


func test_audio(t: Node) -> void:
	for s in Sfx.SOUNDS:
		var st: AudioStream = Sfx.streams.get(s)
		t.check(st != null and st.get_length() > 0.05, "son %s chargé" % s)
	Sfx.play("rifle", Vector2.ZERO)
	var track: AudioStreamWAV = Sfx.music.stream
	t.check(track.get_length() > 20.0, "musique chargée (%.1f s)" % track.get_length())
	t.check(track.loop_mode == AudioStreamWAV.LOOP_FORWARD, "musique en boucle")
	Sfx.start_music()
	await t.frames(5)
	t.check(Sfx.music.playing, "la musique joue")
