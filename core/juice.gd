extends Node
## Autoload : temps de jeu (hitstop, ralenti), tremblement, ondes de choc, références partagées de la scène.

signal fighter_killed(victim: Node2D, killer: Node2D)
## Message court pour le joueur (déblocage, etc.), affiché par l'interface.
signal notified(text: String)
## Exécution lancée (victime tenue, kill cam) : l'interface affiche le titre.
signal executed(victim: Node2D, killer: Node2D)
## Ralenti à la demande déclenché.
signal focus_used
## Exploit du joueur de cette machine (« parry », « flawless ») : profil, succès.
signal feat(kind: String)

const MASK_WORLD := 1
const MASK_FIGHTERS := 2
const MASK_PLATFORMS := 4
## Portes construites : bloquent les pillards et leurs balles, pas le joueur.
const MASK_DOORS := 8

var fx: Node2D
var stains: Node2D
var arena: Node2D
var world: Node2D
var camera: Camera2D
## Caméras visibles (une en solo, deux en écran partagé) : culling, météo, tests « à l'écran ».
var cameras: Array[Camera2D] = []
## Vue partagée en cours (null en solo).
var split: CanvasLayer
var hd := true
## Tests : traite la manette n°0 comme branchée.
var force_pad := false
## Vent de la manche (px/s, positif vers la droite) : pluie, neige, fumée, écharpes, grenades.
var wind := 0.0
var weather: Node2D
## Partie en ligne en cours (NetSession) ; null hors ligne.
var net: Node
## Partie de survie en cours (ressources, faim, jour/nuit) ; null en arène.
var survival: Node
## Interrupteurs de profilage (--off=…), jamais utilisés en jeu normal.
var off: PackedStringArray = []
## Chiffres de dégâts au-dessus des touches (option du menu).
var damage_numbers: bool = Settings.get_pref("hud", "damage_numbers", true)
## Tireurs hors champ qui viennent de toucher le joueur : [{at, t}] (indicateur au bord de l'écran).
var threats: Array[Dictionary] = []
## Jauge de ralenti à la demande (0 à 1) : se remplit en éliminant.
var gauge := 0.0
const GAUGE_TIME := 3.0
var trauma := 0.0
var aberration := 0.0
var zoom_punch := 0.0
## Intensité du bord rouge de dégâts : vie basse du joueur + coups récents.
var hurt := 0.0
var shockwaves: Array[Dictionary] = []
## Kill cam : point filmé, temps restant (réel) et poids de transition partagé par caméras et interface.
var focus := Vector2.ZERO
var focus_t := 0.0
var focus_w := 0.0
var _hitstop := 0.0
var _slowmo := 0.0
var _slowmo_scale := 1.0
var _stopped := false
## Temps réel de l'image, mesuré une fois par image (horloge, ou pas fixe avec --fixed-fps).
var _real := 0.0
var _real_frame := -1
var _last_us := 0
## Pas réel imposé (tests lancés avec --fixed-fps, que le jeu ne voit pas dans ses arguments) ; 0 = horloge.
var fixed_step := 0.0


func _process(delta: float) -> void:
	var real := real_delta(delta)
	trauma = maxf(trauma - real * 1.5, 0.0)
	aberration = move_toward(aberration, 0.0, real * 2.5)
	zoom_punch = lerpf(zoom_punch, 0.0, minf(real * 6.0, 1.0))
	for w in shockwaves:
		w.age += real
	shockwaves = shockwaves.filter(func(w: Dictionary) -> bool: return w.age < w.life)
	for th in threats:
		th.t -= real
	threats = threats.filter(func(th: Dictionary) -> bool: return th.t > 0.0)
	focus_t -= real
	focus_w = move_toward(focus_w, 1.0 if focus_t > 0.0 else 0.0, real * (5.0 if focus_t > 0.0 else 3.0))
	_tick_time(real)


## Ne dépend pas de delta : diviser par Engine.time_scale se trompe l'image où l'échelle change (hitstop),
## et une seule image lente vidait alors tout un ralenti.
func real_delta(_delta: float) -> float:
	var f := Engine.get_process_frames()
	if f != _real_frame:
		_real_frame = f
		var now := Time.get_ticks_usec()
		_real = fixed_step if fixed_step > 0.0 else clampf((now - _last_us) / 1000000.0, 0.0, 0.1)
		_last_us = now
	return _real


func _tick_time(real: float) -> void:
	_hitstop -= real
	_slowmo -= real
	if _hitstop > 0.0:
		Engine.time_scale = 0.02
		_stopped = true
		return
	var goal := _slowmo_scale if _slowmo > 0.0 else 1.0
	if _stopped:
		Engine.time_scale = goal
		_stopped = false
	Engine.time_scale = lerpf(Engine.time_scale, goal, minf(real * 7.0, 1.0))


func hitstop(sec: float) -> void:
	_hitstop = maxf(_hitstop, sec)


func slowmo(sec: float, scale: float) -> void:
	_slowmo = maxf(_slowmo, sec)
	_slowmo_scale = scale


func shake(amount: float, at: Vector2 = Vector2.INF) -> void:
	if at != Vector2.INF and camera:
		amount *= clampf(1.0 - camera.get_screen_center_position().distance_to(at) / 520.0, 0.0, 1.0)
	trauma = minf(trauma + amount, 1.0)


## Dernière élimination de la manche : ralenti fort, caméra qui serre sur la victime, bandes noires.
func kill_cam(at: Vector2, sec: float = 1.5) -> void:
	focus = at
	focus_t = sec
	hitstop(0.08)
	slowmo(sec, 0.22)
	aberration += 0.6
	Sfx.play_ui("slowmo", -2.0)


## Ralenti à la demande : jauge pleine, hors ligne seulement (le temps doit rester le même pour tous en ligne).
func use_focus() -> bool:
	if gauge < 1.0 or net != null:
		return false
	gauge = 0.0
	slowmo(GAUGE_TIME, 0.4)
	focus_used.emit()
	aberration += 0.5
	Sfx.play_ui("slowmo", -4.0)
	return true


func notify(text: String) -> void:
	notified.emit(text)


func on_screen(p: Vector2, margin: float = 0.0) -> bool:
	for r in views(margin):
		if r.has_point(p):
			return true
	return false


## Rectangles du monde vus par chaque caméra active.
func views(margin: float = 0.0) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var list: Array = cameras if not cameras.is_empty() else ([camera] if camera else [])
	for c: Camera2D in list:
		if is_instance_valid(c):
			var half := c.get_viewport_rect().size * 0.5 / c.zoom
			out.append(Rect2(c.get_screen_center_position() - half, half * 2.0).grow(margin))
	return out


func shockwave(pos: Vector2, strength: float = 1.0) -> void:
	shockwaves.append({"pos": pos, "age": 0.0, "life": 0.5, "strength": strength})
	if shockwaves.size() > 4:
		shockwaves.pop_front()


func reset() -> void:
	trauma = 0.0
	hurt = 0.0
	aberration = 0.0
	zoom_punch = 0.0
	shockwaves.clear()
	focus_t = 0.0
	focus_w = 0.0
	_hitstop = 0.0
	_slowmo = 0.0
	Engine.time_scale = 1.0
