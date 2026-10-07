class_name IntroChoreo
extends RefCounted
## Chorégraphie de l'intro, calée sur assets/music/intro.wav (150 BPM) : poses clés des deux combattants, caméra et
## coups. Les poses sont tournées vers la droite, pieds en (0, 0), en unités de squelette (×SCALE à l'écran).

const SCALE := 3.2
## Ralenti (le coup de pied sauté) : la physique des particules y tourne au quart.
const SLOW := Vector2(3.3, 3.95)
const DECAP := 3.9

const POSES := {
	"guard": {"head": Vector2(2, -31), "shoulder": Vector2(1, -25.5), "hip": Vector2(0, -15),
		"elbow0": Vector2(5, -21), "hand0": Vector2(8, -26), "elbow1": Vector2(3, -20), "hand1": Vector2(6, -24),
		"knee0": Vector2(3.5, -8), "foot0": Vector2(5, 0), "knee1": Vector2(-3, -7.5), "foot1": Vector2(-5.5, 0)},
	"run_a": {"head": Vector2(5, -30), "shoulder": Vector2(3.5, -25), "hip": Vector2(0, -15),
		"elbow0": Vector2(6, -20), "hand0": Vector2(10, -23), "elbow1": Vector2(-2, -20), "hand1": Vector2(-5, -16),
		"knee0": Vector2(6, -10), "foot0": Vector2(9, -4), "knee1": Vector2(-2, -7), "foot1": Vector2(-8, -3)},
	"run_b": {"head": Vector2(5, -30), "shoulder": Vector2(3.5, -25), "hip": Vector2(0, -15),
		"elbow0": Vector2(-2, -20), "hand0": Vector2(-4, -16), "elbow1": Vector2(6, -20), "hand1": Vector2(10, -23),
		"knee0": Vector2(1, -7), "foot0": Vector2(-6, -2), "knee1": Vector2(6, -11), "foot1": Vector2(9, -5)},
	"punch": {"head": Vector2(5, -30), "shoulder": Vector2(4, -25.5), "hip": Vector2(0, -15),
		"elbow0": Vector2(10, -27), "hand0": Vector2(17, -29), "elbow1": Vector2(0, -20), "hand1": Vector2(3, -24),
		"knee0": Vector2(6, -8), "foot0": Vector2(9, 0), "knee1": Vector2(-4, -7), "foot1": Vector2(-8, 0)},
	"hit_head": {"head": Vector2(-6, -29), "shoulder": Vector2(-3.5, -25), "hip": Vector2(0, -15),
		"elbow0": Vector2(2, -21), "hand0": Vector2(6, -18), "elbow1": Vector2(-7, -23), "hand1": Vector2(-11, -28),
		"knee0": Vector2(3, -8), "foot0": Vector2(5, 0), "knee1": Vector2(-3, -7), "foot1": Vector2(-6, 0)},
	"kick_high": {"head": Vector2(-3, -30), "shoulder": Vector2(-2, -25), "hip": Vector2(0, -15),
		"elbow0": Vector2(3, -21), "hand0": Vector2(6, -25), "elbow1": Vector2(-6, -21), "hand1": Vector2(-9, -18),
		"knee0": Vector2(7, -21), "foot0": Vector2(15, -27), "knee1": Vector2(-1, -7.5), "foot1": Vector2(-1, 0)},
	"kick_mid": {"head": Vector2(-2, -31), "shoulder": Vector2(-1.5, -25.5), "hip": Vector2(0, -15),
		"elbow0": Vector2(3, -21), "hand0": Vector2(6, -25), "elbow1": Vector2(-6, -21), "hand1": Vector2(-9, -18),
		"knee0": Vector2(8, -17), "foot0": Vector2(15, -16), "knee1": Vector2(-1, -7.5), "foot1": Vector2(-1, 0)},
	"gut_hit": {"head": Vector2(6, -22), "shoulder": Vector2(4, -20), "hip": Vector2(-1, -14),
		"elbow0": Vector2(5, -15), "hand0": Vector2(3, -12), "elbow1": Vector2(3, -15), "hand1": Vector2(1, -12),
		"knee0": Vector2(2, -7), "foot0": Vector2(3, 0), "knee1": Vector2(-4, -7), "foot1": Vector2(-6, 0)},
	"grab_knee": {"head": Vector2(5, -29), "shoulder": Vector2(4, -25), "hip": Vector2(0, -15),
		"elbow0": Vector2(9, -26), "hand0": Vector2(13, -24), "elbow1": Vector2(8, -23), "hand1": Vector2(12, -22),
		"knee0": Vector2(8, -21), "foot0": Vector2(4, -12), "knee1": Vector2(-2, -7.5), "foot1": Vector2(-3, 0)},
	"tuck": {"head": Vector2(3, -24), "shoulder": Vector2(2, -21), "hip": Vector2(0, -15),
		"elbow0": Vector2(6, -19), "hand0": Vector2(7, -15), "elbow1": Vector2(5, -18), "hand1": Vector2(6, -14),
		"knee0": Vector2(6, -19), "foot0": Vector2(1, -12), "knee1": Vector2(5, -17), "foot1": Vector2(0, -11)},
	"fly_kick": {"head": Vector2(-5, -28), "shoulder": Vector2(-4, -24), "hip": Vector2(0, -15),
		"elbow0": Vector2(-2, -20), "hand0": Vector2(-8, -23), "elbow1": Vector2(-6, -26), "hand1": Vector2(-10, -31),
		"knee0": Vector2(9, -17), "foot0": Vector2(19, -19), "knee1": Vector2(-4, -9), "foot1": Vector2(-2, -3)},
	"limp": {"head": Vector2(1, -30), "shoulder": Vector2(0, -25), "hip": Vector2(0, -15),
		"elbow0": Vector2(4, -19), "hand0": Vector2(5, -13), "elbow1": Vector2(-3, -19), "hand1": Vector2(-5, -14),
		"knee0": Vector2(2, -8), "foot0": Vector2(1, 0), "knee1": Vector2(-1, -8), "foot1": Vector2(-3, 0)},
	"victory": {"head": Vector2(1, -31.5), "shoulder": Vector2(0.5, -26), "hip": Vector2(0, -15),
		"elbow0": Vector2(4, -31), "hand0": Vector2(6, -38), "elbow1": Vector2(-4, -21), "hand1": Vector2(-6, -17),
		"knee0": Vector2(4, -8), "foot0": Vector2(6, 0), "knee1": Vector2(-4, -8), "foot1": Vector2(-6, 0)},
}

## [temps, pose, x, y, rotation autour de la hanche, expression] ; x relatif au centre, y relatif au sol.
const HERO := [
	[0.00, "run_a", -330, 0, 0.0, "angry"], [0.14, "run_b", -270, 0, 0.0, "angry"],
	[0.28, "run_a", -200, 0, 0.0, "angry"], [0.42, "run_b", -130, 0, 0.0, "angry"],
	[0.56, "run_a", -70, 0, 0.0, "shout"], [0.70, "guard", -30, 0, 0.0, "angry"],
	[0.80, "punch", -24, 0, 0.0, "shout"], [0.95, "guard", -26, 0, 0.0, "angry"],
	[1.20, "guard", -24, 0, 0.0, "angry"], [1.28, "gut_hit", -34, 0, 0.0, "pain"],
	[1.50, "gut_hit", -36, 0, 0.0, "pain"], [1.62, "guard", -26, 0, 0.0, "angry"],
	[1.72, "kick_high", -22, 0, 0.0, "shout"], [1.88, "guard", -24, 0, 0.0, "angry"],
	[2.02, "guard", -24, 0, 0.0, "angry"], [2.10, "gut_hit", -24, 0, 0.0, "angry"],
	[2.16, "hit_head", -34, -6, 0.0, "pain"], [2.40, "hit_head", -50, 0, 0.0, "pain"],
	[2.52, "tuck", -75, -45, -2.0, "angry"], [2.70, "tuck", -105, -40, -4.6, "angry"],
	[2.84, "guard", -120, 0, -TAU, "angry"], [3.05, "guard", -122, 0, -TAU, "angry"],
	[3.22, "run_a", -110, 0, -TAU, "shout"], [3.32, "fly_kick", -95, -40, -TAU, "shout"],
	[3.90, "fly_kick", -37, -38, -TAU, "shout"], [4.20, "fly_kick", -5, -14, -TAU, "shout"],
	[4.36, "guard", 5, 0, -TAU, "angry"], [4.70, "victory", 5, 0, -TAU, "smug"],
]
const RIVAL := [
	[0.00, "run_a", 330, 0, 0.0, "angry"], [0.14, "run_b", 270, 0, 0.0, "angry"],
	[0.28, "run_a", 200, 0, 0.0, "angry"], [0.42, "run_b", 130, 0, 0.0, "angry"],
	[0.56, "run_a", 72, 0, 0.0, "shout"], [0.70, "guard", 36, 0, 0.0, "angry"],
	[0.80, "guard", 34, 0, 0.0, "angry"], [0.88, "hit_head", 44, 0, 0.0, "pain"],
	[1.02, "hit_head", 48, 0, 0.0, "pain"], [1.12, "guard", 32, 0, 0.0, "angry"],
	[1.20, "kick_mid", 26, 0, 0.0, "shout"], [1.36, "guard", 30, 0, 0.0, "angry"],
	[1.72, "guard", 32, 0, 0.0, "angry"], [1.80, "hit_head", 42, 0, -0.25, "pain"],
	[1.92, "hit_head", 46, 0, 0.0, "pain"], [2.02, "guard", 22, 0, 0.0, "shout"],
	[2.12, "grab_knee", 12, 0, 0.0, "shout"], [2.30, "guard", 18, 0, 0.0, "angry"],
	[2.60, "guard", 26, 0, 0.0, "smug"], [3.30, "guard", 32, 0, 0.0, "angry"],
	[3.60, "guard", 32, 0, 0.0, "fear"], [3.88, "guard", 32, 0, 0.0, "fear"],
	[3.92, "hit_head", 38, 0, -0.3, "dead"], [4.40, "limp", 70, 44, -1.5, "dead"],
	[4.60, "limp", 72, 46, -1.55, "dead"],
]
## [temps, cible ("hero" / "rival"), articulation, sens du sang, quantité, dents, son].
const HITS := [
	[0.80, "rival", "head", 1.0, 22, true, "punch"], [1.20, "hero", "head", -1.0, 10, false, "punch"],
	[1.72, "rival", "head", 1.0, 26, true, "punch"], [2.12, "hero", "head", -1.0, 24, true, "punch"],
	[DECAP, "rival", "head", 1.0, 110, true, "gore"],
]
## Sons sans coup : [temps, son, volume].
const SOUNDS := [[2.50, "dash", 0.0], [2.84, "land", 2.0], [3.30, "dash", 2.0], [4.36, "land", 2.0]]
## Caméra : [temps, centre x, centre y, zoom].
const CAMERA := [
	[0.0, 0, -70, 1.0], [0.75, 0, -75, 1.12], [0.82, 5, -80, 1.22], [1.1, 0, -75, 1.12], [1.7, 5, -80, 1.2],
	[2.12, -10, -80, 1.25], [2.5, -60, -80, 1.0], [2.9, -60, -70, 1.0], [3.3, -40, -85, 1.15],
	[3.85, 0, -100, 1.7], [3.95, 10, -95, 1.8], [4.4, 20, -70, 1.1], [4.6, 0, -95, 1.0],
]


static func smooth(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## Encadre `t` dans une liste de clés : [clé avant, clé après, avancement lissé].
static func bracket(keys: Array, t: float) -> Array:
	if t <= keys[0][0]:
		return [keys[0], keys[0], 0.0]
	for i in range(1, keys.size()):
		if t < keys[i][0]:
			var a: Array = keys[i - 1]
			return [a, keys[i], smooth((t - a[0]) / (keys[i][0] - a[0]))]
	return [keys[-1], keys[-1], 0.0]


## Articulations à l'écran (repère du monde : x centre, y sol) et expression d'un combattant à l'instant `t`.
static func sample(keys: Array, t: float, facing: float) -> Dictionary:
	var b := bracket(keys, t)
	var a: Array = b[0]
	var c: Array = b[1]
	var u: float = b[2]
	var root := Vector2(lerpf(a[2], c[2], u), lerpf(a[3], c[3], u))
	var rot := lerpf(a[4], c[4], u)
	var pa: Dictionary = POSES[a[1]]
	var pc: Dictionary = POSES[c[1]]
	var hip: Vector2 = pa.hip.lerp(pc.hip, u)
	var j := {}
	for k: String in pa:
		var p: Vector2 = pa[k].lerp(pc[k], u)
		p = hip + (p - hip).rotated(rot)
		j[k] = root + p * Vector2(facing * SCALE, SCALE)
	return {"j": j, "expr": a[5] if u < 0.5 else c[5], "facing": facing}


static func camera(t: float) -> Vector3:
	var b := bracket(CAMERA, t)
	var a: Array = b[0]
	var c: Array = b[1]
	var u: float = b[2]
	return Vector3(lerpf(a[1], c[1], u), lerpf(a[2], c[2], u), lerpf(a[3], c[3], u))


static func physics_speed(t: float) -> float:
	return 0.25 if t >= SLOW.x and t < SLOW.y else 1.0
