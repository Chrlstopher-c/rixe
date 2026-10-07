class_name Settings
## Réglages persistants du joueur (user://settings.cfg) : volume, mode d'affichage, record, viseur.

const PATH := "user://settings.cfg"

## Désactivé pendant les tests pour ne jamais toucher aux réglages du joueur.
static var persist := true


static func load_all() -> Dictionary:
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("réglages illisibles (%d), valeurs par défaut" % err)
	return {"volume": float(cfg.get_value("audio", "volume", 0.8)), "hd": bool(cfg.get_value("video", "hd", true))}


static func save_all(volume: float, hd: bool) -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("video", "hd", hd)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("réglages non enregistrés (%d)" % err)


static func load_best() -> int:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return int(cfg.get_value("score", "best", 0))


static func save_best(best: int) -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("score", "best", best)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("record non enregistré (%d)" % err)


## Préférence simple (section, clé) ; `default` si absente.
static func get_pref(section: String, key: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg.get_value(section, key, default)


static func set_pref(section: String, key: String, value: Variant) -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(section, key, value)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("préférence non enregistrée (%d)" % err)


## Viseur choisi : {"preset": nom, "custom": réglages du viseur personnalisé}.
static func load_crosshair() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	var v: Variant = cfg.get_value("hud", "crosshair", {})
	return v if v is Dictionary else {}


static func save_crosshair(c: Dictionary) -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("hud", "crosshair", c)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("viseur non enregistré (%d)" % err)


static func apply_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
