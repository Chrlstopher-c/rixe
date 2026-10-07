class_name Crosshair
## Viseur : modèles prêts à l'emploi et viseur personnalisé (forme, taille, écart, épaisseur, couleur, contour,
## point central, écartement selon la dispersion). Réglage enregistré dans les réglages du joueur.

const SHAPES := ["croix", "cercle", "point", "T"]
const COLORS := {
	"blanc": Color(2.0, 1.9, 1.9), "cyan": Color(0.4, 1.9, 2.2), "vert": Color(0.5, 2.2, 0.7),
	"jaune": Color(2.2, 2.0, 0.4), "rouge": Color(2.4, 0.4, 0.4), "magenta": Color(2.2, 0.5, 2.0),
}
const PRESETS := {
	"classique": {"shape": "croix", "length": 4.0, "gap": 3.0, "thick": 1.0, "dot": true, "outline": false,
		"color": "blanc", "dynamic": true},
	"précis": {"shape": "croix", "length": 3.0, "gap": 1.5, "thick": 1.0, "dot": false, "outline": true,
		"color": "vert", "dynamic": false},
	"point": {"shape": "point", "length": 2.0, "gap": 0.0, "thick": 1.0, "dot": true, "outline": true,
		"color": "cyan", "dynamic": false},
	"cercle": {"shape": "cercle", "length": 4.0, "gap": 6.0, "thick": 1.0, "dot": true, "outline": false,
		"color": "blanc", "dynamic": true},
	"T": {"shape": "T", "length": 5.0, "gap": 2.0, "thick": 1.5, "dot": false, "outline": true,
		"color": "jaune", "dynamic": true},
}
## Bornes des réglages numériques du viseur personnalisé : [min, max, pas].
const RANGES := {"length": [1.0, 12.0, 1.0], "gap": [0.0, 12.0, 1.0], "thick": [0.5, 3.0, 0.5]}


## Réglage complet du modèle choisi (« perso » = valeurs de l'utilisateur).
static func resolve(cfg: Dictionary) -> Dictionary:
	var name: String = cfg.get("preset", "classique")
	if name == "perso":
		var out: Dictionary = PRESETS.classique.duplicate()
		out.merge(cfg.get("custom", {}), true)
		return out
	return (PRESETS.get(name, PRESETS.classique) as Dictionary).duplicate()


## Dessine le viseur en `m` ; `spread` = écart supplémentaire dû à la dispersion de l'arme.
static func draw(canvas: CanvasItem, m: Vector2, c: Dictionary, spread: float) -> void:
	var col: Color = Color(COLORS.get(c.color, COLORS.blanc), 0.92)
	var gap: float = c.gap + (spread if c.dynamic else 0.0)
	var t: float = c.thick
	if c.outline:
		_shape(canvas, m, c, gap, t + 1.5, Color(0, 0, 0, 0.75))
	_shape(canvas, m, c, gap, t, col)


static func _shape(canvas: CanvasItem, m: Vector2, c: Dictionary, gap: float, t: float, col: Color) -> void:
	var arm: float = c.length
	match String(c.shape):
		"croix", "T":
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				if c.shape == "T" and d == Vector2.UP:
					continue
				canvas.draw_line(m + d * gap, m + d * (gap + arm), col, t)
		"cercle":
			canvas.draw_arc(m, gap + arm * 0.5, 0.0, TAU, 32, col, t)
	if c.dot or c.shape == "point":
		canvas.draw_circle(m, maxf(t * 0.7, c.length * 0.35 if c.shape == "point" else 0.0), col)
