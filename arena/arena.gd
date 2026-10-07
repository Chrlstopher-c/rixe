extends Node2D
## Arène procédurale : murs et roche indestructibles + décor destructible (sol, caisses, plateformes traversables).

## Largeur de la carte (1600 en arène, bien plus en survie).
var W := 1600.0
const LEVEL_GAP := 74.0
const PLATFORM_H := 8.0
## Épaisseur de sol destructible au-dessus de la roche.
const DIRT_DEPTH := 40.0

var solids: Array[Rect2] = []
var solid_kinds: Array[String] = []
## Plateformes telles que générées (points d'apparition, objets, navigation des bots) ; leur état réel est dans terrain.
var platforms: Array[Rect2] = []
var terrain := Terrain.new()
var _tex := {}
var theme := "crepuscule"
var rim := Color(1.6, 0.75, 0.5)
var map := "plateformes"
## Hauteur sous laquelle on meurt (cartes sans sol) ; INF = pas de vide.
var void_y := INF


func _ready() -> void:
	terrain.z_index = 1
	add_child(terrain)
	set_theme(theme)


func set_theme(name: String) -> void:
	theme = name
	rim = Themes.ALL[name].rim
	for n in ["ground", "metal", "bricks", "concrete", "glass", "grate"]:
		_tex[n] = Themes.texture(name, n)
	terrain.tex = _tex
	terrain.rim = rim
	terrain.redraw_all()
	queue_redraw()


func generate(seed_value: int, map_type: String = "plateformes") -> void:
	W = Maps.SURVIVAL_W if map_type == "survie" else 1600.0
	_reset()
	map = map_type
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	Maps.build(self, map_type, rng)
	terrain.flush()
	queue_redraw()


func generate_flat() -> void:
	W = 1600.0
	_reset()
	add_bedrock()
	terrain.fill(Rect2(0, 0, W, DIRT_DEPTH), Terrain.K.DIRT)
	terrain.flush()
	queue_redraw()


func _reset() -> void:
	for c in get_children():
		if c != terrain:
			c.free()
	terrain.clear()
	solids.clear()
	solid_kinds.clear()
	platforms.clear()
	void_y = INF
	map = "plateformes"
	_add_solid(Rect2(-300, -700, 300, 1300), "wall")
	_add_solid(Rect2(W, -700, 300, 1300), "wall")


func add_bedrock() -> void:
	_add_solid(Rect2(-300, DIRT_DEPTH, W + 600, 400), "bedrock")


## Structure d'immeuble indestructible (toits).
func add_building(r: Rect2) -> void:
	_add_solid(r, "building")


## Bloc de machine indestructible (tapis roulant de l'usine), dessiné par la machine elle-même.
func add_machine(r: Rect2) -> void:
	_add_solid(r, "machine")


func _add_solid(r: Rect2, kind: String) -> void:
	solids.append(r)
	solid_kinds.append(kind)
	var body := StaticBody2D.new()
	body.collision_layer = Juice.MASK_WORLD
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	body.add_child(shape)
	add_child(body)
	add_child(Shadows.occluder(r))


## Dégâts au décor (impacts, explosions) ; renvoie le nombre de cellules détruites.
func damage(at: Vector2, dmg: float, radius: float, by: Variant = null) -> int:
	if Juice.net:
		Juice.net.terrain_hit(at, dmg, radius)
	var n := terrain.damage(at, dmg, radius, by)
	if n > 0:
		queue_redraw()
	return n


## Décor indestructible seulement (roche, murs, immeubles) : sert d'appui au décor destructible.
func rect_solid_at(p: Vector2) -> bool:
	for r in solids:
		if r.has_point(p):
			return true
	return false


func solid_at(p: Vector2) -> bool:
	if terrain.at(p) != Terrain.K.NONE:
		return true
	for r in solids:
		if r.has_point(p):
			return true
	return false


func push_out(prev: Vector2, p: Vector2) -> Vector2:
	for r in solids:
		if r.has_point(p):
			return _exit_rect(r, p)
	var k := terrain.at(p)
	if k == Terrain.K.NONE:
		return p
	var cell := Terrain.cell_rect(Terrain.cell_of(p))
	if k == Terrain.K.PLAT:
		return Vector2(p.x, cell.position.y - 0.01) if prev.y <= cell.position.y + 1.0 else p
	return _exit_cell(cell, p, prev)


## Sort d'une cellule pleine par le côté libre le plus proche (le dessus en priorité).
func _exit_cell(cell: Rect2, p: Vector2, prev: Vector2) -> Vector2:
	var c := Terrain.cell_of(cell.get_center())
	if not terrain.is_solid_cell(c + Vector2i.UP) or prev.y < cell.position.y:
		return Vector2(p.x, cell.position.y - 0.01)
	if not terrain.is_solid_cell(c + Vector2i.LEFT) and p.x < cell.get_center().x:
		return Vector2(cell.position.x - 0.01, p.y)
	if not terrain.is_solid_cell(c + Vector2i.RIGHT):
		return Vector2(cell.end.x + 0.01, p.y)
	return prev


func _exit_rect(r: Rect2, p: Vector2) -> Vector2:
	var d := [p.y - r.position.y, r.end.y - p.y, p.x - r.position.x, r.end.x - p.x]
	var m: float = d.min()
	if m == d[0]:
		return Vector2(p.x, r.position.y - 0.01)
	if m == d[1]:
		return Vector2(p.x, r.end.y + 0.01)
	if m == d[2]:
		return Vector2(r.position.x - 0.01, p.y)
	return Vector2(r.end.x + 0.01, p.y)


## n points d'apparition répartis sur la largeur ; une tranche sans sol se rabat sur n'importe où ailleurs.
func spawn_points(n: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in n:
		for attempt in 40:
			var x := lerpf(120.0, W - 120.0, (i + 0.5) / n) + rng.randf_range(-60, 60)
			if attempt >= 12:
				x = rng.randf_range(80.0, W - 80.0)
			var spots := stand_spots(x)
			if not spots.is_empty():
				out.append(Vector2(x, spots[rng.randi_range(0, spots.size() - 1)] - 6.0))
				break
	return out


## Surfaces où l'on peut se tenir dans une colonne : un sol plein sous au moins 40 px de vide.
func stand_spots(x: float) -> Array[float]:
	var out: Array[float] = []
	var free := 0.0
	var y := -320.0
	while y < minf(void_y, 400.0):
		if solid_at(Vector2(x, y)):
			if free >= 40.0:
				out.append(y)
			free = 0.0
		else:
			free += 4.0
		y += 4.0
	return out


func _draw() -> void:
	if map == "mine":
		draw_texture_rect(_tex.bricks, Rect2(0, -232, W, 272), true, Color(0.16, 0.13, 0.18))
		draw_rect(Rect2(0, -232, W, 272), Color(0.0, 0.0, 0.02, 0.35))
	for r in platforms:
		_draw_strut(r)
	for i in solids.size():
		_draw_solid(solids[i], solid_kinds[i])


## Montants des plateformes, tant que le bout de plateforme qu'ils portent existe.
func _draw_strut(r: Rect2) -> void:
	var c := Color(0.07, 0.04, 0.09)
	for x in [r.position.x + 6.0, r.end.x - 6.0]:
		if terrain.at(Vector2(x, r.position.y + 1.0)) == Terrain.K.PLAT:
			draw_line(Vector2(x, r.end.y), Vector2(x, 0), c, 2.0)


func _draw_solid(r: Rect2, kind: String) -> void:
	match kind:
		"bedrock":
			draw_rect(r, Color(0.045, 0.03, 0.03))
		"wall":
			draw_texture_rect(_tex.bricks, r, true, Color(0.45, 0.4, 0.5))
		"building":
			draw_texture_rect(_tex.bricks, r, true, Color(0.32, 0.28, 0.36))
			for wy in range(int(r.position.y) + 14, int(r.position.y) + 220, 26):
				for wx in range(int(r.position.x) + 10, int(r.end.x) - 14, 22):
					var lit := (wx * 7 + wy * 13) % 5 == 0
					draw_rect(Rect2(wx, wy, 8, 10), Color(1.6, 1.2, 0.6, 0.8) if lit else Color(0.05, 0.05, 0.08))
