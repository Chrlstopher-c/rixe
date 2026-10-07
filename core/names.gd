class_name Names
## Pseudos : celui du joueur (« anon » + nombre au premier lancement, modifiable) et ceux des joueurs en ligne.
## En interne les combattants gardent des clés stables (« Toi », « J2 »…) ; on ne traduit qu'à l'affichage.

const MAX_LEN := 14
const ALLOWED := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"

## Pseudo du joueur de cette machine.
static var nick := ""
## Pseudos des autres joueurs, par clé interne (en ligne : « J2 », « Hôte »…).
static var others := {}


static func load_nick() -> String:
	if nick == "":
		var cfg := ConfigFile.new()
		cfg.load(Settings.PATH)
		nick = clean(String(cfg.get_value("player", "nick", "")))
		if nick == "":
			nick = "anon%d" % randi_range(1000, 9999)
			save_nick(nick)
	return nick


static func save_nick(n: String) -> void:
	nick = clean(n) if clean(n) != "" else nick
	if not Settings.persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	cfg.set_value("player", "nick", nick)
	var err := cfg.save(Settings.PATH)
	if err != OK:
		push_warning("pseudo non enregistré (%d)" % err)


## Garde lettres, chiffres, tiret et souligné, 14 caractères au plus.
static func clean(n: String) -> String:
	var out := ""
	for ch in n:
		if ALLOWED.contains(ch) and out.length() < MAX_LEN:
			out += ch
	return out


## Nom affiché d'un combattant ou d'une ligne de classement.
static func label(key: String) -> String:
	if key == "Toi":
		return load_nick()
	return String(others.get(key, key))
