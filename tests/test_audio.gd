extends RefCounted
## Tests audio : tous les bruitages se chargent et ont une durée.


func names() -> Array[String]:
	return ["audio"]


func test_audio(t: Node) -> void:
	for s in Sfx.SOUNDS:
		var st: AudioStream = Sfx.streams.get(s)
		t.check(st != null and st.get_length() > 0.05, "son %s chargé" % s)
	Sfx.play("rifle", Vector2.ZERO)
	await t.frames(1)
