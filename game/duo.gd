class_name Duo
extends RefCounted
## Partie à deux sur le même écran : joueur 1 au clavier/souris (« Toi »), joueur 2 à la manette (« J2 »),
## écran partagé ; coopération contre les bots en arcade, chacun pour soi en chrono et objectif.

const P2_NAME := "J2"
const P2_COLOR := Color(1.0, 0.82, 0.3)

var main: Node
var split: SplitView
var player2: Node2D


func _init(owner: Node) -> void:
	main = owner


## Place les deux joueurs ; renvoie l'index de point d'apparition pris par le joueur 2.
func populate(spots: Array, mine: int) -> int:
	var kb := PlayerBrain.new()
	kb.pad_enabled = false
	main.player = main._spawn_player(spots[mine], kb)
	var other := (mine + 1) % spots.size()
	player2 = main._spawn(P2_NAME, spots[other], P2_COLOR, PadBrain.new(0), "rifle", true)
	if main.game_mode == "arcade":
		main.player.team = "joueurs"
		player2.team = "joueurs"
	return other


func enter() -> void:
	if split:
		return
	split = SplitView.new()
	split.source_hud = main._hud
	main.add_child(split)
	Juice.split = split
	main._set_root_view(false)


func leave() -> void:
	if split:
		split.queue_free()
	split = null
	Juice.split = null
	Juice.cameras.clear()
	main._set_root_view(true)


func bind() -> void:
	split.bind([main.player, player2], Juice.arena.W, main.game_mode, main.match_state)


## Un humain tombe en arcade : la partie continue tant que l'autre est debout.
func survivor_left(victim: Node2D) -> bool:
	var other: Variant = player2 if victim == main.player else main.player
	if is_instance_valid(other) and other.alive:
		Juice.notify("%s est tombé, %s continue" % [victim.display_name, other.display_name])
		return true
	return false


func respawn(entry: Dictionary, pos: Vector2) -> bool:
	if entry.name != P2_NAME:
		return false
	player2 = main._spawn(P2_NAME, pos, P2_COLOR, PadBrain.new(0), "rifle", true)
	split.follow(1, player2)
	return true
