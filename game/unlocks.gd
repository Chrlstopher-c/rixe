class_name Unlocks
## Déblocages persistants (armes et accessoires ramassés au moins une fois) et équipement de départ choisi.

const DEFAULT_WEAPONS := ["rifle", "pistol"]

static var _cache := {}
static var _loaded := false
static var _loadout := {}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	_cache = cfg.get_value("unlocks", "items", {})
	for w in DEFAULT_WEAPONS:
		_cache["weapon:" + w] = true


static func has(kind: String, id: String) -> bool:
	_load()
	return _cache.has(kind + ":" + id)


## Débloque ; renvoie true si c'est nouveau.
static func unlock(kind: String, id: String) -> bool:
	_load()
	var key := kind + ":" + id
	if _cache.has(key):
		return false
	_cache[key] = true
	_save("unlocks", "items", _cache)
	return true


static func weapons() -> Array:
	return Arsenal.ids().filter(func(w: String) -> bool: return has("weapon", w))


static func attachments(slot: String) -> Array:
	var out := [""]
	for a in Arsenal.ATTACHMENTS:
		if Arsenal.ATTACHMENTS[a].slot == slot and has("attachment", a):
			out.append(a)
	return out


static func loadout() -> Dictionary:
	if _loadout.is_empty():
		var cfg := ConfigFile.new()
		cfg.load(Settings.PATH)
		_loadout = cfg.get_value("unlocks", "loadout", {"weapon": "rifle", "attachments": {}})
	var l: Dictionary = _loadout.duplicate(true)
	if not has("weapon", l.weapon):
		l.weapon = "rifle"
	return l


static func save_loadout(l: Dictionary) -> void:
	_loadout = l.duplicate(true)
	_save("unlocks", "loadout", l)


static func _save(section: String, key: String, value: Variant) -> void:
	if not Settings.persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	cfg.set_value(section, key, value)
	var err := cfg.save(Settings.PATH)
	if err != OK:
		push_warning("déblocages non enregistrés (%d)" % err)
