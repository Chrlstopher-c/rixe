class_name Maps
## Types de cartes : Plateformes (sol + 3 étages), Toits (immeubles sur le vide), Mine (roche creusée de galeries).

const ALL := {
	"plateformes": {"label": "PLATEFORMES", "weight": 2},
	"toits": {"label": "TOITS", "weight": 1},
	"mine": {"label": "MINE", "weight": 1},
	"usine": {"label": "USINE", "weight": 1},
	"foret": {"label": "FORÊT DE NUIT", "weight": 1},
	"survie": {"label": "TERRES SAUVAGES", "weight": 0},
}
const SURVIVAL_W := 6000.0
## Profondeur à partir de laquelle une chute tue, sur les cartes sans sol.
const VOID_Y := 240.0


## Nom affiché d'une carte (cartes perso : leur nom).
static func label(map: String) -> String:
	if map.begins_with(MapStore.PREFIX):
		return map.trim_prefix(MapStore.PREFIX).to_upper()
	return String(ALL.get(map, ALL.plateformes).label)


static func pick(rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in ALL:
		total += int(ALL[k].weight)
	var r := rng.randi_range(1, total)
	for k in ALL:
		r -= int(ALL[k].weight)
		if r <= 0:
			return k
	return "plateformes"


static func build(arena: Node2D, map: String, rng: RandomNumberGenerator) -> void:
	if map.begins_with(MapStore.PREFIX):
		MapStore.build(arena, map.trim_prefix(MapStore.PREFIX))
		arena.terrain.flush()
		return
	match map:
		"toits":
			_roofs(arena, rng)
		"mine":
			_mine(arena, rng)
		"usine":
			_factory(arena, rng)
		"foret":
			_forest(arena, rng)
		"survie":
			_wilds(arena, rng)
			arena.terrain.flush()
			return
		_:
			_platforms(arena, rng)
	arena.terrain.flush()
	if not ("props" in Juice.off):
		_props(arena, map, rng)


## Barils explosifs posés au sol, lampes accrochées sous un plafond (plateforme, galerie).
static func _props(arena: Node2D, map: String, rng: RandomNumberGenerator) -> void:
	var barrels := 3 if map == "mine" else 2
	var lamps := 4 if map == "mine" else 2
	for i in 40:
		if barrels <= 0 and lamps <= 0:
			return
		var x := snappedf(rng.randf_range(60, arena.W - 60), 4.0)
		var spots: Array[float] = arena.stand_spots(x)
		if spots.is_empty():
			continue
		var y: float = spots[rng.randi_range(0, spots.size() - 1)]
		if barrels > 0 and rng.randf() < 0.5:
			var b := Barrel.new()
			b.position = Vector2(x, y)
			arena.add_child(b)
			barrels -= 1
		elif lamps > 0:
			var ceiling := _ceiling(arena, Vector2(x, y - 20.0))
			if ceiling != Vector2.INF:
				var lamp := Lamp.new()
				lamp.setup(ceiling, minf(24.0, (y - ceiling.y) * 0.4))
				arena.add_child(lamp)
				lamps -= 1


static func _ceiling(arena: Node2D, from: Vector2) -> Vector2:
	for dy in range(0, 140, 4):
		var p := from - Vector2(0, dy)
		if arena.solid_at(p):
			return Vector2(from.x, floorf(p.y / 8.0) * 8.0 + 8.0)
	return Vector2.INF


static func _platforms(arena: Node2D, rng: RandomNumberGenerator) -> void:
	arena.add_bedrock()
	arena.terrain.fill(Rect2(0, 0, arena.W, arena.DIRT_DEPTH), Terrain.K.DIRT)
	for i in rng.randi_range(3, 5):
		var w := 16.0 * rng.randi_range(2, 3)
		var h := 16.0 * rng.randi_range(1, 2)
		var x := snappedf(rng.randf_range(140, arena.W - 180), 16.0)
		arena.terrain.fill(Rect2(x, -h, w, h), Terrain.K.CRATE)
	for level in range(1, 4):
		_level(arena, rng, -level * arena.LEVEL_GAP, 60.0, 190.0)


## Usine : dalle de béton, tapis roulants en sens opposés, presses qui s'abattent dessus, cloisons vitrées,
## piliers de béton et deux étages de passerelles.
static func _factory(arena: Node2D, rng: RandomNumberGenerator) -> void:
	arena.add_bedrock()
	arena.terrain.fill(Rect2(0, 0, arena.W, arena.DIRT_DEPTH), Terrain.K.CONCRETE)
	var x := 180.0
	var dir := 1.0
	while x < arena.W - 300.0:
		var w := snappedf(rng.randf_range(200, 300), 8.0)
		var belt := Rect2(x, -16, w, 16)
		arena.add_machine(belt)
		var c := Conveyor.new()
		c.setup(belt, dir * rng.randf_range(60, 95))
		arena.add_child(c)
		var p := Press.new()
		p.setup(x + w * rng.randf_range(0.3, 0.7), -2.0 * arena.LEVEL_GAP + 10.0, -16.0, rng.randf() * 4.0)
		arena.add_child(p)
		dir = -dir
		x += w + snappedf(rng.randf_range(140, 220), 8.0)
	for i in rng.randi_range(2, 3):
		var gx := snappedf(rng.randf_range(100, arena.W - 100), 8.0)
		if arena.terrain.at(Vector2(gx, -4)) == Terrain.K.NONE and not arena.rect_solid_at(Vector2(gx, -8)):
			arena.terrain.fill(Rect2(gx, -48, 8, 48), Terrain.K.GLASS)
	for i in rng.randi_range(2, 3):
		var px := snappedf(rng.randf_range(100, arena.W - 100), 8.0)
		if not arena.rect_solid_at(Vector2(px, -8)):
			arena.terrain.fill(Rect2(px, -40, 16, 40), Terrain.K.CONCRETE)
	for level in range(2, 4):
		_level(arena, rng, -level * arena.LEVEL_GAP, 80.0, 200.0)


## Forêt de nuit : collines, arbres serrés, buissons, cabanes de planches dans les arbres.
static func _forest(arena: Node2D, rng: RandomNumberGenerator) -> void:
	arena.add_bedrock()
	var phase := [rng.randf() * TAU, rng.randf() * TAU]
	var heights := {}
	var x := 0.0
	while x < arena.W:
		var h := 24.0 * sin(x / 340.0 + phase[0]) + 10.0 * sin(x / 120.0 + phase[1])
		var top := snappedf(clampf(-20.0 + h, -56.0, -8.0), 8.0)
		heights[x] = top
		arena.terrain.fill(Rect2(x, top, 8, arena.DIRT_DEPTH - top), Terrain.K.DIRT)
		x += 8.0
	x = 90.0
	while x < arena.W - 90.0:
		var top: float = heights[snappedf(x, 8.0)]
		if rng.randf() < 0.7:
			var tree := WildTree.new()
			arena.add_child(tree)
			tree.setup(Vector2(x, top + 1.0), rng.randi_range(8, 12), rng)
		else:
			var bush := Bush.new()
			bush.position = Vector2(x, top)
			arena.add_child(bush)
		x += snappedf(rng.randf_range(60, 130), 8.0)
	for i in rng.randi_range(3, 4):
		var px := snappedf(rng.randf_range(80, arena.W - 200), 8.0)
		var py := snappedf(rng.randf_range(-170, -100), 8.0)
		var r := Rect2(px, py, snappedf(rng.randf_range(72, 120), 8.0), 8)
		arena.terrain.fill(r, Terrain.K.WOOD)
		arena.platforms.append(r)
		_struts(arena, r)
	arena.add_child(Fireflies.new())


## Immeubles séparés par des vides : toit destructible sur 4 cellules, structure indestructible dessous.
static func _roofs(arena: Node2D, rng: RandomNumberGenerator) -> void:
	var x := 0.0
	while x < arena.W:
		var w := snappedf(rng.randf_range(150, 320), 8.0)
		w = minf(w, arena.W - x)
		var top := snappedf(rng.randf_range(-110, 0), 8.0)
		arena.terrain.fill(Rect2(x, top, w, 32), Terrain.K.BRICK)
		arena.add_building(Rect2(x, top + 32, w, 600))
		if w > 90.0 and rng.randf() < 0.75:
			var n := Neon.new()
			n.position = Vector2(x + rng.randf_range(34, w - 34), top + rng.randf_range(70, 150))
			n.setup(Vector2(rng.randf_range(34, 60), rng.randf_range(14, 22)),
				Neon.PALETTE[rng.randi_range(0, Neon.PALETTE.size() - 1)], rng.randi_range(0, 2), rng.randf() * 10.0)
			arena.add_child(n)
		if rng.randf() < 0.6:
			var pw := snappedf(rng.randf_range(56, minf(w - 16, 120)), 8.0)
			var r := Rect2(snappedf(x + rng.randf_range(8, w - pw - 8), 8.0), top - arena.LEVEL_GAP, pw, arena.PLATFORM_H)
			arena.platforms.append(r)
			arena.terrain.fill(r, Terrain.K.PLAT)
			_struts(arena, r)
		x += w + snappedf(rng.randf_range(48, 104), 8.0)
	arena.void_y = VOID_Y


## Roche épaisse sous une croûte de terre, galeries et salles creusées, puits vers la surface, voie de wagonnet.
static func _mine(arena: Node2D, rng: RandomNumberGenerator) -> void:
	arena.add_bedrock()
	var surface := -264.0
	arena.terrain.fill(Rect2(0, surface, arena.W, 32), Terrain.K.DIRT)
	arena.terrain.fill(Rect2(0, surface + 32, arena.W, arena.DIRT_DEPTH - surface - 32), Terrain.K.ROCK)
	for row in [-40.0, -128.0, -208.0]:
		_tunnel(arena, rng, row)
	for i in 4:
		var x := snappedf(rng.randf_range(80, arena.W - 120), 8.0)
		arena.terrain.carve(Rect2(x, surface, 40, -40.0 - surface))
	for i in 5:
		var x := snappedf(rng.randf_range(60, arena.W - 160), 8.0)
		arena.terrain.carve(Rect2(x, -200, rng.randf_range(80, 140), 170))
	_rails(arena, rng)


## Voie de wagonnet sur une portion aplanie de la galerie du bas.
static func _rails(arena: Node2D, rng: RandomNumberGenerator) -> void:
	var length := snappedf(rng.randf_range(320, 440), 8.0)
	var x := snappedf(rng.randf_range(80, arena.W - 80 - length), 8.0)
	arena.terrain.carve(Rect2(x, -88, length, 48))
	arena.terrain.fill(Rect2(x, -40, length, 16), Terrain.K.ROCK)
	var phase := rng.randf()
	if "props" in Juice.off:
		return
	var cart := Minecart.new()
	cart.setup(x, x + length, -40.0, phase)
	arena.add_child(cart)


static func _tunnel(arena: Node2D, rng: RandomNumberGenerator, y: float) -> void:
	var x := 0.0
	var h := 48.0
	while x < arena.W:
		var dy := snappedf(rng.randf_range(-16, 16), 8.0)
		arena.terrain.carve(Rect2(x, y + dy - h, 64, h))
		x += 56.0


static func _level(arena: Node2D, rng: RandomNumberGenerator, y: float, gap_min: float, gap_max: float) -> void:
	var x := snappedf(rng.randf_range(30, 160), 8.0)
	while x < arena.W - 120:
		var w := snappedf(rng.randf_range(80, 200), 8.0)
		var r := Rect2(x, y, minf(w, arena.W - 20 - x), arena.PLATFORM_H)
		arena.platforms.append(r)
		arena.terrain.fill(r, Terrain.K.PLAT)
		_struts(arena, r)
		x = snappedf(x + w + rng.randf_range(gap_min, gap_max), 8.0)


## Les cellules au-dessus des montants dessinés tiennent seules : la plateforme ne tombe que si on les détruit.
static func _struts(arena: Node2D, r: Rect2) -> void:
	for x in [r.position.x + 6.0, r.end.x - 6.0]:
		arena.terrain.anchors[Terrain.cell_of(Vector2(x, r.position.y + 1.0))] = true


## Terres sauvages (survie) : collines de terre sur roche, arbres, rochers, buissons, carcasses de métal.
static func _wilds(arena: Node2D, rng: RandomNumberGenerator) -> void:
	arena.add_bedrock()
	var phase := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var heights := {}
	var x := 0.0
	while x < arena.W:
		var h := 40.0 * sin(x / 610.0 + phase[0]) + 22.0 * sin(x / 230.0 + phase[1]) + 8.0 * sin(x / 90.0 + phase[2])
		var top := snappedf(clampf(-60.0 + h, -140.0, -8.0), 8.0)
		heights[x] = top
		arena.terrain.fill(Rect2(x, top, 8, 32), Terrain.K.DIRT)
		arena.terrain.fill(Rect2(x, top + 32, 8, arena.DIRT_DEPTH - top - 32), Terrain.K.ROCK)
		x += 8.0
	_dress_wilds(arena, rng, heights)


static func _dress_wilds(arena: Node2D, rng: RandomNumberGenerator, heights: Dictionary) -> void:
	var x := 120.0
	while x < arena.W - 120.0:
		var top: float = heights[snappedf(x, 8.0)]
		var roll := rng.randf()
		if roll < 0.45:
			var tree := WildTree.new()
			arena.add_child(tree)
			tree.setup(Vector2(x, top + 1.0), rng.randi_range(6, 10), rng)
		elif roll < 0.62:
			arena.terrain.fill(Rect2(x, top - 16, 24, 16), Terrain.K.ROCK)
		elif roll < 0.8:
			var bush := Bush.new()
			bush.position = Vector2(x, top)
			arena.add_child(bush)
		elif roll < 0.9:
			arena.terrain.fill(Rect2(x, top - 16, 32, 16), Terrain.K.CRATE)
		x += snappedf(rng.randf_range(70, 190), 8.0)
