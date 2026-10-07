class_name ScriptBrain
extends RefCounted
## Cerveau piloté par un test : intentions posées à la main ; jump/dash/melee sont des impulsions d'une frame.

var move := 0.0
var jump_held := false
var drop := false
var fire := false
var aiming := false
var reload := false
var aim := Vector2.ZERO
var _jump := false
var _dash := false
var _melee := false
var _throw := false


func press_jump() -> void:
	_jump = true
	jump_held = true


func press_dash() -> void:
	_dash = true


func press_melee() -> void:
	_melee = true


func press_throw() -> void:
	_throw = true


func think(f: Node2D, _delta: float) -> Dictionary:
	var it := {"move": move, "jump": _jump, "jump_held": jump_held, "drop": drop, "dash": _dash, "fire": fire,
		"melee": _melee, "throw": _throw, "aiming": aiming, "reload": reload, "aim": aim if aim != Vector2.ZERO else f.global_position + Vector2(100, -20)}
	_jump = false
	_dash = false
	_melee = false
	_throw = false
	return it
