class_name Announcer
extends Node
## Annonceur : voix d'arène (générée en local) sur les beaux coups du joueur de cette machine — décapitation,
## tir à la tête, exécution, séries (doublé, triplé, carnage) — et sur le rythme de la manche.

## Fenêtre pour enchaîner une série d'éliminations.
const STREAK_WINDOW := 3.0
const LINES := ["decap", "execution", "headshot", "double", "triple", "rampage", "last", "round_won", "fight",
	"flawless", "boss", "boss_down", "focus"]
## Éliminations d'affilée sans être touché pour « Intouchable ».
const FLAWLESS := 5
## Plus le rang est haut, plus l'annonce passe devant les autres.
const PRIORITY := {"execution": 5, "rampage": 4, "triple": 3, "double": 2, "decap": 2, "headshot": 1, "last": 1,
	"round_won": 3, "fight": 0, "flawless": 4, "boss": 5, "boss_down": 5, "focus": 1}

var streams := {}
var enabled := true
var _player := AudioStreamPlayer.new()
var _pending := ""
var _delay := 0.0
var _streak := 0
var _streak_t := 0.0
## Temps depuis la dernière annonce : on n'en coupe pas une avant qu'elle ait été comprise.
var _since := 99.0
var _clean := 0
var _last_hurt := 0.0
## Dernière annonce prononcée (tests).
var last_said := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in LINES:
		streams[k] = load("res://assets/voice/%s.wav" % k)
	_player.bus = Sfx.voice_bus()
	add_child(_player)
	Juice.fighter_killed.connect(_on_killed)
	Juice.focus_used.connect(func() -> void: say("focus", 0.05))
	Juice.executed.connect(func(_v: Node2D, k: Node2D) -> void:
		if Fighter.local_human(k):
			say("execution"))


## Nouvelle manche : la série repart de zéro.
func reset() -> void:
	_streak = 0
	_streak_t = 0.0
	_clean = 0
	_pending = ""


## Programme une annonce ; une annonce plus importante remplace celle qui attend.
func say(key: String, after: float = 0.12) -> void:
	if not enabled or not streams.has(key):
		return
	if _pending != "" and PRIORITY[_pending] > PRIORITY[key]:
		return
	_pending = key
	_delay = after


func _on_killed(victim: Node2D, killer: Node2D) -> void:
	if not Fighter.local_human(killer) or killer == victim:
		return
	_streak = _streak + 1 if _streak_t > 0.0 else 1
	_streak_t = STREAK_WINDOW
	_clean += 1
	if _clean == FLAWLESS:
		say("flawless", 0.6)
		Juice.feat.emit("flawless")
	match _streak:
		2:
			say("double", 0.35)
		3:
			say("triple", 0.35)
		5:
			say("rampage", 0.35)
	if victim.executed:
		return
	if victim.death_cause == "decap":
		say("decap")
	elif victim.death_cause == "headshot":
		say("headshot")


func _process(delta: float) -> void:
	var real: float = Juice.real_delta(delta)
	_streak_t -= real
	_since += real
	if Juice.hurt > _last_hurt + 0.1:
		_clean = 0
	_last_hurt = Juice.hurt
	if _pending == "":
		return
	_delay -= real
	if _delay > 0.0 or (_player.playing and _since < 0.55):
		return
	_player.stream = streams[_pending]
	_player.play()
	last_said = _pending
	_since = 0.0
	_pending = ""
