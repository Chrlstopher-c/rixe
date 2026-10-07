extends RefCounted
## Tests de l'environnement : barils explosifs (réaction en chaîne), lampes qui tombent, météo et vent.


func names() -> Array[String]:
	return ["props", "weather"]


func test_props(t: Node) -> void:
	var arena: Node2D = Juice.arena
	var victim: Fighter = t.main.spawn_test_fighter(Vector2(620, -10), ScriptBrain.new(), "rifle", false)
	await t.until(func() -> bool: return victim.is_on_floor(), 120)
	var a := Barrel.new()
	a.position = Vector2(600, 0)
	arena.add_child(a)
	var b := Barrel.new()
	b.position = Vector2(640, 0)
	arena.add_child(b)
	var bref: WeakRef = weakref(b)
	var vref: WeakRef = weakref(victim)
	a.take_hit(30.0, Vector2.RIGHT, a.global_position + Vector2(-5, -7), null, 0.0)
	await t.frames(5)
	t.check(bref.get_ref() == null, "réaction en chaîne : le baril voisin explose aussi")
	t.check(vref.get_ref() == null or victim.hp < Fighter.MAX_HP, "l'explosion blesse le combattant à côté")
	arena.terrain.fill(Rect2(880, -80, 48, 8), Terrain.K.PLAT)
	arena.terrain.flush()
	var lamp := Lamp.new()
	lamp.setup(Vector2(900, -72), 20.0)
	arena.add_child(lamp)
	var lref: WeakRef = weakref(lamp)
	lamp.take_hit(9.0, Vector2.RIGHT, lamp.global_position, null, 0.0)
	var broke: bool = await t.until(func() -> bool: return lref.get_ref() == null, 240)
	t.check(broke, "une lampe touchée tombe et se brise au sol")


func test_weather(t: Node) -> void:
	var w: Node2D = Juice.weather
	Juice.wind = 60.0
	w.set_kind("rain")
	t.check(w._drops.size() == 220, "pluie : 220 gouttes")
	var smoke = Juice.fx.emit(2, Vector2(400, -100), Vector2.ZERO, 2.0, 2.0, Color.WHITE)
	await t.frames(60)
	t.check(smoke.pos.x > 400.0, "le vent pousse la fumée (x=%.1f)" % smoke.pos.x)
	var pd: Puddles = w.puddles
	print("flaques : %d (suites %d)" % [pd.spots.size(), Puddles.flat_runs(Juice.arena.terrain).size()])
	t.check(not pd.spots.is_empty(), "pluie : des flaques sur les sols plats")
	var s: Vector3i = pd.spots[0] if not pd.spots.is_empty() else Vector3i.ZERO
	Juice.arena.terrain.remove(Vector2i(s.y + 1, s.x))
	await t.frames(45)
	t.check(not s in pd.spots, "une flaque dont le sol est détruit disparaît")
	w.set_kind("snow")
	t.check(pd.spots.is_empty(), "pas de flaques sous la neige")
	t.check(w._drops.size() == 160, "neige : 160 flocons")
	w.set_kind("")
	Juice.wind = 0.0
