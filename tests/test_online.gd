extends RefCounted
## Tests en ligne (hors « all ») : deux processus du jeu, hôte et invité, reliés par un relais local.
## Lancés par tools/online_test.sh, qui fournit RIXE_RELAY et RIXE_ROOM.


func names() -> Array[String]:
	return ["online_link_host", "online_link_guest"]


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
