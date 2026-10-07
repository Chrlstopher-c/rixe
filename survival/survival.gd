class_name Survival
extends Node
## Partie de survie : ressources, faim, cycle jour/nuit, compte des nuits tenues. Les vagues sont lancées par main.

signal night_started(day: int)
signal day_started(day: int)
signal changed

const DAY := 150.0
const NIGHT := 90.0
const STARVE := 360.0
const RES := ["bois", "pierre", "metal", "nourriture"]
const NAMES := {"bois": "Bois", "pierre": "Pierre", "metal": "Métal", "nourriture": "Nourriture"}

var day := 1
var night := false
var t := 0.0
var hunger := 100.0
var nights_survived := 0
var res := {"bois": 0, "pierre": 0, "metal": 0, "nourriture": 2}
var player: Node2D


func add(kind: String, n: int = 1) -> void:
	res[kind] = int(res.get(kind, 0)) + n
	changed.emit()


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if int(res.get(k, 0)) < int(cost[k]):
			return false
	return true


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		res[k] -= int(cost[k])
	changed.emit()
	return true


## Manger : une ration rend 30 de satiété.
func eat() -> bool:
	if int(res.nourriture) <= 0 or hunger >= 95.0:
		return false
	res.nourriture -= 1
	hunger = minf(hunger + 30.0, 100.0)
	Sfx.play_ui("pickup", -4.0)
	changed.emit()
	return true


func _process(delta: float) -> void:
	t += delta
	hunger = maxf(hunger - delta * 100.0 / STARVE, 0.0)
	if hunger <= 0.0 and is_instance_valid(player) and player.alive:
		player.hp -= 1.5 * delta
		if player.hp <= 0.0:
			player.take_hit(5.0, Vector2.DOWN, player.global_position + Vector2(0, -22), null, 0.0)
	if not night and t >= DAY:
		night = true
		t = 0.0
		night_started.emit(day)
	elif night and t >= NIGHT:
		night = false
		t = 0.0
		nights_survived += 1
		day += 1
		day_started.emit(day)


## Lumière du jour (1 = plein jour, 0 = nuit noire) avec crépuscule et aube progressifs.
func daylight() -> float:
	if not night:
		return lerpf(0.6, 1.0, minf(t / 10.0, 1.0)) if t < 10.0 else lerpf(0.6, 1.0, clampf((DAY - t) / 15.0, 0.0, 1.0))
	if t < 12.0:
		return lerpf(0.6, 0.0, t / 12.0)
	if t > NIGHT - 12.0:
		return lerpf(0.0, 0.6, (t - (NIGHT - 12.0)) / 12.0)
	return 0.0


func clock() -> String:
	var left := (NIGHT if night else DAY) - t
	return "%d:%02d" % [int(left) / 60, int(left) % 60]
