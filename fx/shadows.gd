class_name Shadows
## Ombres portées 2D : occulteurs rectangulaires pour le décor, et réglage des lumières qui projettent des ombres
## (explosions : les éclairs permanents, lampes ou tirs, coûtent trop). Coupables au menu (option OMBRES).

## Option du joueur (réglages), coupée par défaut : sur les cartes chargées (mine, toits) le 1 % bas passe sous 50.
static var enabled: bool = Settings.get_pref("video", "shadows", false)


## Option changée : toutes les lumières concernées suivent.
static func set_enabled(tree: SceneTree, on: bool) -> void:
	enabled = on
	Settings.set_pref("video", "shadows", on)
	for l in tree.get_nodes_in_group("shadow_lights"):
		l.shadow_enabled = on
	if Juice.arena:
		for ch in Juice.arena.terrain.get_children():
			if ch is TerrainChunk:
				ch.dirty = true


## Occulteurs seulement si les ombres sont actives (même inutilisés, ils coûtent ~20 % d'images par seconde).
static func wanted() -> bool:
	return enabled and not ("shadows" in Juice.off)


static func occluder(r: Rect2) -> Node2D:
	if not wanted():
		return Node2D.new()
	var o := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)])
	o.occluder = poly
	return o


## Une lumière qui projette des ombres douces et sombres (si l'option est active).
static func cast(l: Light2D) -> void:
	l.add_to_group("shadow_lights")
	l.shadow_enabled = enabled and not ("shadows" in Juice.off)
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	l.shadow_color = Color(0, 0, 0, 0.85)
