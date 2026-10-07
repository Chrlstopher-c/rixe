class_name Spawner
extends RefCounted
## Apparitions : combattants (joueur avec son équipement, bots à caractère fixe par nom), objets de départ,
## point d'apparition le plus éloigné des combattants en vie.

const PLAYER_COLOR := Color(0.3, 0.9, 1.0)

var fighters: Node2D
var rng: RandomNumberGenerator
var config := GameConfig.new()
var _bot_kinds := {}
## Équipe de chaque bot (par nom), gardée d'une réapparition à l'autre.
var _bot_teams := {}
var _team_turn := 0


func _init(root: Node2D, random: RandomNumberGenerator) -> void:
	fighters = root
	rng = random


func clear_names() -> void:
	_bot_kinds.clear()
	_bot_teams.clear()
	_team_turn = 0


func spawn(nm: String, pos: Vector2, color: Color, brain: RefCounted, weapon: String, is_player: bool,
		mods: Dictionary = {}) -> Fighter:
	var f := Fighter.new()
	f.setup(nm, color, brain, weapon, is_player, mods)
	f.position = pos
	fighters.add_child(f)
	return f


## Le joueur humain part avec l'équipement choisi à l'armurerie ; la démo garde le fusil.
func spawn_player(pos: Vector2, brain: RefCounted) -> Fighter:
	var f: Fighter
	if brain is PlayerBrain:
		var l := Unlocks.loadout()
		var w := config.pick_weapon(l.weapon, rng)
		f = spawn("Toi", pos, PLAYER_COLOR, brain, w, true, l.attachments if w == l.weapon else {})
	else:
		f = spawn("Toi", pos, PLAYER_COLOR, brain, config.pick_weapon("rifle", rng), true)
	join_team(f, "Toi", 0)
	return f


## Équipe d'un joueur humain selon les réglages (couleur d'équipe comprise) ; rien en chacun pour soi.
func join_team(f: Fighter, id: String, order: int) -> void:
	var t := config.team_index(id, order)
	if t > 0:
		f.team = GameConfig.team_name(t)
		f.team_color = GameConfig.TEAM_COLORS[t]


## Bot d'un archétype (nom vide = au hasard) ; même nom et même caractère à chaque réapparition.
func spawn_bot(pos: Vector2, name: String, level: float) -> Fighter:
	var ids := Personality.ids()
	var kind: String = _bot_kinds.get(name, ids[rng.randi_range(0, ids.size() - 1)])
	var brain := BotBrain.new(level, kind)
	if name == "":
		name = _unique_name(brain.p.label)
		_bot_kinds[name] = kind
	var w: String = brain.p.weapon if rng.randf() < 0.6 else Arsenal.ids()[rng.randi_range(0, Arsenal.ids().size() - 1)]
	var f := spawn(name, pos, Personality.ARCHETYPES[kind].color, brain, config.pick_weapon(w, rng), false)
	if config.teams > 0 and config.mode != "arcade":
		if not _bot_teams.has(name):
			_bot_teams[name] = _team_turn % config.teams + 1
			_team_turn += 1
		var t: int = _bot_teams[name]
		f.team = GameConfig.team_name(t)
		f.team_color = GameConfig.TEAM_COLORS[t]
	return f


func _unique_name(label: String) -> String:
	if not _bot_kinds.has(label):
		return label
	var i := 2
	while _bot_kinds.has("%s %d" % [label, i]):
		i += 1
	return "%s %d" % [label, i]


## Deux armes et un ou deux accessoires posés sur des plateformes au début de la manche.
func spawn_pickups() -> void:
	var plats: Array = Juice.arena.platforms
	if plats.is_empty():
		return
	for i in 2:
		var r: Rect2 = plats[rng.randi_range(0, plats.size() - 1)]
		var p := WeaponPickup.new()
		Juice.world.add_child(p)
		p.global_position = Vector2(r.get_center().x, r.position.y - 20.0)
		var ids: Array = Arsenal.ids().filter(func(w: String) -> bool: return config.allows(w))
		p.setup(ids[rng.randi_range(0, ids.size() - 1)], Vector2.ZERO)
	var atts := Arsenal.ATTACHMENTS.keys()
	for i in rng.randi_range(1, 2):
		var r: Rect2 = plats[rng.randi_range(0, plats.size() - 1)]
		var a := AttachmentPickup.new()
		Juice.world.add_child(a)
		a.global_position = Vector2(r.position.x + 12.0, r.position.y - 20.0)
		a.setup(atts[rng.randi_range(0, atts.size() - 1)], Vector2.ZERO)


## Point d'apparition le plus éloigné des combattants en vie.
func far_spawn() -> Vector2:
	var best := Vector2(Juice.arena.W * 0.5, -60)
	var best_d := -1.0
	for p: Vector2 in Juice.arena.spawn_points(10, rng):
		var d := INF
		for f in fighters.get_children():
			if f is Fighter and f.alive:
				d = minf(d, p.distance_to(f.global_position))
		if d > best_d:
			best_d = d
			best = p
	return best
