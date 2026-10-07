class_name NetWorld
extends RefCounted
## Monde en ligne : tirs rejoués à l'identique (traçantes, impacts, sons), grenades visuelles, trous dans le décor,
## barils et lampes, objets au sol (l'hôte les numérote et en garde la trace, l'invité en reçoit des copies).

var s: Node
var _terrain: Array = []
var _props: Array[Node2D] = []
var _items := {}
var _next_item := 0


func _init(session: Node) -> void:
	s = session


## Barils et lampes, dans l'ordre de génération (identique des deux côtés).
func reset_round() -> void:
	_props.clear()
	if not s.is_host():
		_items.clear()
	for c in Juice.arena.get_children():
		if c is Barrel or c is Lamp:
			_props.append(c)


func flush() -> void:
	if _terrain.is_empty():
		return
	s.send_event({"t": "terrain", "list": _terrain})
	_terrain = []


func on_message(t: String, msg: Dictionary) -> bool:
	match t:
		"shot":
			_on_shot(msg)
		"slash":
			_on_slash(msg)
		"gren":
			_on_grenade(msg)
		"terrain":
			for d: Array in msg.list:
				Juice.arena.damage(d[0], d[1], d[2])
		"prop":
			_on_prop(msg)
		"item":
			_on_item(msg)
		"gone":
			_on_gone(int(msg.id))
		_:
			return false
	return true


func _owner_id(n: Node2D) -> String:
	return n.net_id if n.net_id != "" else n.display_name


func _puppet(id: String) -> Variant:
	var p: Variant = s.fighters.puppets.get(id)
	return p if is_instance_valid(p) and p.alive else null


# Tirs.

func shot_fired(owner: Node2D, muzzle: Vector2, dir: Vector2) -> void:
	if owner.remote:
		return
	var segs: Array = owner.gun.segs.duplicate()
	s.send_event({"t": "shot", "by": _owner_id(owner), "m": muzzle, "dir": dir, "segs": segs})


func _on_shot(msg: Dictionary) -> void:
	var p: Variant = _puppet(String(msg.by))
	if p == null:
		return
	var def: Dictionary = p.gun.def
	p.rig.recoil = def.recoil
	Effects.muzzle(msg.m, msg.dir, def.tracer, def.flash)
	Sfx.play(p.gun.id, msg.m, -2.0)
	if def.get("shell", false):
		Effects.shell(p.rig.ejection_global(), msg.dir)
	for seg: Array in msg.segs:
		Effects.tracer(seg[0], seg[1], def.tracer, def.width, 0.16 if def.get("pierce", false) else 0.08)
		if int(seg[2]) == 1:
			Effects.impact(seg[1], -(seg[1] - seg[0]).normalized(), def.tracer)


func slashed(owner: Node2D) -> void:
	if not owner.remote:
		s.send_event({"t": "slash", "by": _owner_id(owner)})


func _on_slash(msg: Dictionary) -> void:
	var p: Variant = _puppet(String(msg.by))
	if p:
		p.gun.swing = 1.0
		Sfx.play("slash", p.global_position, -2.0, 0.12)


func grenade_thrown(g: Grenade) -> void:
	if g.cosmetic or not is_instance_valid(g.thrower) or g.thrower.remote:
		return
	s.send_event({"t": "gren", "by": _owner_id(g.thrower), "pos": g.global_position, "v": g.vel, "fuse": g.fuse,
		"imp": g.impact, "r": g.radius, "g": g.gravity})


func _on_grenade(msg: Dictionary) -> void:
	var g := Grenade.new()
	g.cosmetic = true
	Juice.world.add_child(g)
	g.global_position = msg.pos
	g.setup(_puppet(String(msg.by)), msg.v, msg.fuse, msg.imp, 0.0, msg.r)
	g.gravity = msg.g


# Décor.

func terrain_hit(at: Vector2, dmg: float, radius: float) -> void:
	if not s.applying:
		_terrain.append([at, dmg, radius])


func prop_event(prop: Node2D, kind: String, dir: Vector2) -> void:
	var i := _props.find(prop)
	if i >= 0 and not s.applying:
		s.send_event({"t": "prop", "i": i, "k": kind, "dir": dir})


func _on_prop(msg: Dictionary) -> void:
	var i: int = msg.i
	if i < 0 or i >= _props.size() or not is_instance_valid(_props[i]):
		return
	var prop := _props[i]
	if msg.k == "boom" and prop is Barrel:
		prop.explode(null, true)
	elif msg.k == "fall" and prop is Lamp:
		prop.take_hit(0.0, msg.dir, prop.global_position, null, 0.0)


# Objets au sol : l'hôte numérote et annonce, l'invité ne garde que les copies reçues.

func item_born(item: Node2D) -> void:
	if not s.is_host():
		if item.net_item < 0:
			item.queue_free()
		return
	item.net_item = _next_item
	_next_item += 1
	_items[item.net_item] = item
	_announce.call_deferred(item)


func _announce(item: Node2D) -> void:
	if is_instance_valid(item) and not item.is_queued_for_deletion():
		s.send_event({"t": "item", "id": item.net_item, "pos": item.global_position, "v": item.vel,
			"data": _describe(item)})


## Hôte : renvoie tous les objets au sol (un invité vient d'arriver en cours de partie).
func announce_all() -> void:
	for item in _items.values():
		if is_instance_valid(item):
			_announce(item)


func _describe(item: Node2D) -> Array:
	if item is WeaponPickup:
		return ["w", item.weapon_id, item.mag, item.reserve, item.attachments]
	if item is AttachmentPickup:
		return ["a", item.att]
	return ["l", item.kind]


## Objet ramassé ici : disparu (« gone ») ou changé (arme échangée au sol).
func item_changed(item: Node2D) -> void:
	if item.net_item < 0:
		return
	if item.is_queued_for_deletion():
		_items.erase(item.net_item)
		s.send_event({"t": "gone", "id": item.net_item})
	else:
		_announce(item)


func _on_item(msg: Dictionary) -> void:
	var id: int = msg.id
	var item: Variant = _items.get(id)
	var data: Array = msg.data
	if not is_instance_valid(item):
		item = {"w": WeaponPickup, "a": AttachmentPickup, "l": Loot}[data[0]].new()
		item.net_item = id
		_items[id] = item
		Juice.world.add_child(item)
	item.global_position = msg.pos
	match data[0]:
		"w":
			item.setup(data[1], msg.v, null, data[2], data[3], data[4])
		"a":
			item.setup(data[1], msg.v)
		"l":
			item.setup(data[1], msg.v)


func _on_gone(id: int) -> void:
	var item: Variant = _items.get(id)
	if is_instance_valid(item):
		item.queue_free()
	_items.erase(id)
