class_name BodyParts
extends RefCounted
## Dégâts localisés : quelle partie du squelette un tir touche, vie par membre, membres arrachés.

const PARTS := {
	"head": {"joints": ["head", "neck"], "radius": 4.6, "mult": 2.5, "hp": 40.0},
	"torso": {"joints": ["hip", "shoulder"], "radius": 2.8, "mult": 1.0, "hp": 75.0},
	"arm0": {"joints": ["shoulder", "elbow0", "hand0"], "radius": 1.6, "mult": 0.6, "hp": 30.0},
	"arm1": {"joints": ["shoulder", "elbow1", "hand1"], "radius": 1.6, "mult": 0.6, "hp": 30.0},
	"leg0": {"joints": ["hip", "knee0", "foot0"], "radius": 1.8, "mult": 0.6, "hp": 35.0},
	"leg1": {"joints": ["hip", "knee1", "foot1"], "radius": 1.8, "mult": 0.6, "hp": 35.0},
}
## Points du ragdoll emportés avec chaque membre arraché ; le premier est le moignon resté sur le corps.
const DETACH := {
	"head": ["shoulder", "head"],
	"arm0": ["shoulder", "elbow0", "hand0"],
	"arm1": ["shoulder", "elbow1", "hand1"],
	"leg0": ["hip", "knee0", "foot0"],
	"leg1": ["hip", "knee1", "foot1"],
	"torso": ["hip", "shoulder"],
}

var hp := {}
var missing: Array[String] = []


func _init() -> void:
	for p in PARTS:
		hp[p] = PARTS[p].hp


func has(part: String) -> bool:
	return not (part in missing)


func arms_left() -> int:
	return int(has("arm0")) + int(has("arm1"))


func legs_left() -> int:
	return int(has("leg0")) + int(has("leg1"))


## Partie la plus proche de la ligne de tir passant par `at` (joints en coordonnées globales).
func zone(joints: Dictionary, at: Vector2, dir: Vector2) -> String:
	var best := "torso"
	var best_d := INF
	for p in PARTS:
		if not has(p):
			continue
		var js: Array = PARTS[p].joints
		var d := INF
		for i in js.size() - 1:
			d = minf(d, _seg_line_dist(joints[js[i]], joints[js[i + 1]], at, dir))
		d -= float(PARTS[p].radius)
		if d < best_d:
			best_d = d
			best = p
	return best


static func _seg_line_dist(a: Vector2, b: Vector2, at: Vector2, dir: Vector2) -> float:
	var sa := (a - at).cross(dir)
	var sb := (b - at).cross(dir)
	if signf(sa) != signf(sb):
		return 0.0
	return minf(absf(sa), absf(sb))


## Applique les dégâts à une partie ; renvoie les dégâts réels et si le membre vient de lâcher.
func damage(part: String, dmg: float) -> Dictionary:
	var real: float = dmg * float(PARTS[part].mult)
	hp[part] -= real
	var broke: bool = hp[part] <= 0.0 and has(part)
	if broke:
		missing.append(part)
	return {"dmg": real, "broke": broke}
