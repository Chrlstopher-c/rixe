class_name Moves
extends RefCounted
## Mouvements avancés d'un combattant : roulade d'esquive (dash au sol, invulnérable un court instant), glissade
## (bas en pleine course : plus bas, plus vite), saut contre un mur (en salto, comme le double saut), parade (coup de pied au bon moment contre un
## coup de pied adverse : l'attaquant est repoussé et étourdi).

const ROLL_TIME := 0.32
## Fenêtre d'invulnérabilité de la roulade (début de roulade).
const ROLL_IFRAMES := 0.24
const SLIDE_TIME := 0.45
const SLIDE_SPEED := 330.0
const SLIDE_CD := 0.5
const WALL_PUSH := 250.0
const WALL_JUMP := 360.0
const PARRY_WINDOW := 0.2
const STUN_TIME := 0.7
const FLIP_TIME := 0.42

var f: Node2D
var roll_t := 0.0
var slide_t := 0.0
var parry_t := 0.0
var stun_t := 0.0
var flip_t := 0.0
## Sens du salto (1 = horaire) : celui du déplacement.
var flip_dir := 1.0
var _slide_cd := 0.0
var _slide_dir := 1.0


func _init(fighter: Node2D) -> void:
	f = fighter


func tick(delta: float) -> void:
	roll_t = maxf(roll_t - delta, 0.0)
	parry_t = maxf(parry_t - delta, 0.0)
	stun_t = maxf(stun_t - delta, 0.0)
	flip_t = maxf(flip_t - delta, 0.0)
	_slide_cd -= delta
	if slide_t > 0.0:
		slide_t -= delta
		f.velocity.x = _slide_dir * SLIDE_SPEED * clampf(slide_t / SLIDE_TIME + 0.35, 0.0, 1.0)
		if randf() < 0.5:
			Effects.dust(f.global_position, 1, 0.6)
		if slide_t <= 0.0:
			f.set_low(false)


func dodging() -> bool:
	return roll_t > ROLL_TIME - ROLL_IFRAMES


func stunned() -> bool:
	return stun_t > 0.0


## Double saut ou saut mural : salto dans le sens du déplacement.
func start_flip() -> void:
	flip_t = FLIP_TIME
	flip_dir = signf(f.velocity.x) if absf(f.velocity.x) > 40.0 else float(f.facing)


## Dash au sol = roulade.
func start_roll() -> void:
	roll_t = ROLL_TIME
	Sfx.play("swing", f.global_position, -6.0, 0.15)


## Bas en pleine course sur un sol plein : glissade.
func try_slide(move: float) -> bool:
	if _slide_cd > 0.0 or slide_t > 0.0 or not f.is_on_floor() or absf(f.velocity.x) < 160.0 or absf(move) < 0.5:
		return false
	slide_t = SLIDE_TIME
	_slide_cd = SLIDE_TIME + SLIDE_CD
	_slide_dir = signf(f.velocity.x)
	f.set_low(true)
	Sfx.play("dash", f.global_position, -6.0, 0.1)
	Effects.dust(f.global_position, 6, 1.2)
	return true


## Saut contre un mur : en l'air, collé à une paroi, on repart dans l'autre sens.
func try_wall_jump() -> bool:
	if f.is_on_floor() or not f.is_on_wall():
		return false
	var n: Vector2 = f.get_wall_normal()
	f.velocity = Vector2(n.x * WALL_PUSH, -WALL_JUMP)
	Effects.dust(f.global_position + Vector2(-n.x * 6.0, -12.0), 5, 0.8)
	Sfx.play("land", f.global_position, -8.0, 0.1)
	return true


## Coup de pied lancé : on peut parer pendant un court instant.
func open_parry() -> void:
	parry_t = PARRY_WINDOW


## Le coup de pied de `attacker` tombe pendant ma parade (et je lui fais face) : il est repoussé et étourdi.
func parries(attacker: Node2D) -> bool:
	if parry_t <= 0.0:
		return false
	var toward: float = signf(attacker.global_position.x - f.global_position.x)
	if toward != 0.0 and toward != float(f.facing):
		return false
	attacker.velocity = Vector2(toward * 300.0, -160.0)
	attacker.moves.stun_t = STUN_TIME
	parry_t = 0.0
	var at: Vector2 = (f.global_position + attacker.global_position) * 0.5 + Vector2(0, -22)
	Juice.fx.emit(5, at, Vector2.ZERO, 0.25, 16.0, Color(2.4, 2.4, 2.8, 0.9))
	Effects.impact(at, Vector2(-toward, 0), Color(3.0, 3.0, 3.4))
	Sfx.play("tink", at, 2.0, 0.05)
	Juice.hitstop(0.08)
	Juice.shake(0.3, at)
	if Fighter.local_human(f):
		Juice.notify("PARADE !")
		Juice.feat.emit("parry")
	return true
