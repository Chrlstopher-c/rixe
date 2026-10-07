class_name RelayConfig
## Adresse du relais en ligne : variable RIXE_RELAY, sinon online/relay.cfg (hors dépôt, embarqué à l'export),
## sinon le relais local de développement (wrangler dev).

const FILE := "res://online/relay.cfg"
const LOCAL := "ws://127.0.0.1:8787"


static func url() -> String:
	var env := OS.get_environment("RIXE_RELAY")
	if env != "":
		return env.trim_suffix("/")
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		return String(cfg.get_value("relay", "url", LOCAL)).trim_suffix("/")
	return LOCAL
