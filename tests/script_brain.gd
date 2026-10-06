class_name ScriptBrain
extends RefCounted
## Cerveau piloté par un test : intentions posées à la main ; jump/dash/melee sont des impulsions d'une frame.

var move := 0.0
var jump_held := false
var drop := false
var fire := false
var aim := Vector2.ZERO
var _jump := false
var _dash := false
var _melee := false


func press_jump() -> void:
	_jump = true
	jump_held = true


func press_dash() -> void:
	_dash = true


func press_melee() -> void:
	_melee = true


func think(f: Node2D, _delta: float) -> Dictionary:
	var it := {"move": move, "jump": _jump, "jump_held": jump_held, "drop": drop, "dash": _dash, "fire": fire,
		"melee": _melee, "aim": aim if aim != Vector2.ZERO else f.global_position + Vector2(100, -20)}
	_jump = false
	_dash = false
	_melee = false
	return it
