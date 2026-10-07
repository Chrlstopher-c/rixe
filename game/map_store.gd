class_name MapStore
## Cartes faites à l'éditeur : fichiers JSON dans le dossier du jeu (user://cartes), cellules [x, y, matière].
## En jeu une carte perso s'appelle « perso:<nom> » ; en ligne, l'invité la reçoit par le recalage du décor.

const DIR := "user://cartes"
const PREFIX := "perso:"


static func names() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(f.get_basename())
	out.sort()
	return out


static func save(name: String, cells: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var list := []
	for c: Vector2i in cells:
		list.append([c.x, c.y, int(cells[c])])
	var f := FileAccess.open("%s/%s.json" % [DIR, name], FileAccess.WRITE)
	if f == null:
		push_warning("carte non enregistrée : %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify({"version": 1, "cells": list}))
	return true


static func load_cells(name: String) -> Dictionary:
	var out := {}
	var f := FileAccess.open("%s/%s.json" % [DIR, name], FileAccess.READ)
	if f == null:
		push_warning("carte introuvable : %s" % name)
		return out
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		push_warning("carte illisible : %s" % name)
		return out
	for e: Array in data.get("cells", []):
		out[Vector2i(int(e[0]), int(e[1]))] = int(e[2])
	return out


## Nouveau nom libre : « carte 1 », « carte 2 »…
static func fresh_name() -> String:
	var taken := names()
	var i := 1
	while "carte %d" % i in taken:
		i += 1
	return "carte %d" % i


## Construit le décor d'une carte perso (roche dessous, plateformes tenues comme sur les cartes du jeu).
static func build(arena: Node2D, name: String) -> void:
	arena.add_bedrock()
	var cells := load_cells(name)
	if cells.is_empty():
		arena.terrain.fill(Rect2(0, 0, arena.W, arena.DIRT_DEPTH), Terrain.K.DIRT)
		return
	for c: Vector2i in cells:
		arena.terrain.place(c, cells[c], true)
		if cells[c] == Terrain.K.PLAT:
			arena.terrain.anchors[c] = true
