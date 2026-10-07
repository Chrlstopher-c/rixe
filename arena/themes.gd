class_name Themes
## Ambiances d'arène : dossier de textures Pigment + couleurs d'accent (liseré des plateformes, brume, braises).

const ALL := {
	"crepuscule": {"rim": Color(1.6, 0.75, 0.5), "haze": Color(0.55, 0.2, 0.38), "ember": Color(2.2, 0.9, 0.4)},
	"acier": {"rim": Color(0.6, 1.1, 1.6), "haze": Color(0.25, 0.32, 0.45), "ember": Color(1.2, 1.4, 1.8)},
	"rouille": {"rim": Color(1.8, 1.0, 0.45), "haze": Color(0.6, 0.3, 0.15), "ember": Color(2.4, 1.2, 0.4)},
}


static func names() -> Array:
	return ALL.keys()


static func texture(theme: String, file: String) -> Texture2D:
	return load("res://assets/textures/%s/%s.png" % [theme, file])
