class_name Inventory
extends RefCounted
## Inventaire d'un combattant : deux armes (une en main), sac d'accessoires, trousses de soin.

const MAX_GUNS := 2
const BAG := 4
const MAX_MEDKITS := 2
const HEAL := 45.0
const HEAL_TIME := 1.4
const SWITCH_TIME := 0.3

var owner: Node2D
var guns: Array[Gun] = []
var active := 0
var bag: Array[String] = []
var medkits := 0
var switching := 0.0
var healing := 0.0


func _init(holder: Node2D, first: Gun) -> void:
	owner = holder
	guns.append(first)


func current() -> Gun:
	return guns[active]


func other() -> Gun:
	return guns[1 - active] if guns.size() > 1 else null


func tick(delta: float) -> void:
	switching = maxf(switching - delta, 0.0)
	if healing > 0.0:
		var step := minf(delta, healing)
		healing -= step
		owner.hp = minf(owner.hp + HEAL / HEAL_TIME * step, owner.MAX_HP)


func select(i: int) -> void:
	if i == active or i < 0 or i >= guns.size():
		return
	current().reload_t = 0.0
	active = i
	owner.gun = current()
	switching = SWITCH_TIME
	Sfx.play("reload_out", owner.global_position, -10.0, 0.1)


func cycle() -> void:
	select((active + 1) % guns.size())


## Prend une arme : deuxième emplacement libre, sinon remplace celle en main ; renvoie l'arme lâchée ou null.
func take(g: Gun) -> Gun:
	if guns.size() < MAX_GUNS:
		guns.append(g)
		select(guns.size() - 1)
		return null
	var old := current()
	guns[active] = g
	owner.gun = g
	switching = SWITCH_TIME
	return old


## Accessoire ramassé : monté s'il y a la place, sinon rangé dans le sac ; renvoie celui qu'il faut lâcher.
func take_attachment(att: String) -> String:
	var g := current()
	var slot: String = Arsenal.ATTACHMENTS[att].slot
	if Arsenal.accepts(g.id) and not g.attachments.has(slot):
		g.equip(att)
		return ""
	if bag.size() < BAG:
		bag.append(att)
		return ""
	return g.equip(att) if Arsenal.accepts(g.id) else att


## Monte l'accessoire n° i du sac sur l'arme n° w (l'ancien retourne au sac).
func mount(i: int, w: int) -> bool:
	if i < 0 or i >= bag.size() or w < 0 or w >= guns.size() or not Arsenal.accepts(guns[w].id):
		return false
	var att := bag[i]
	bag.remove_at(i)
	var old := guns[w].equip(att)
	if old != "":
		bag.append(old)
	return true


## Démonte l'accessoire d'un emplacement de l'arme n° w vers le sac.
func unmount(w: int, slot: String) -> bool:
	if w >= guns.size() or not guns[w].attachments.has(slot) or bag.size() >= BAG:
		return false
	bag.append(guns[w].attachments[slot])
	guns[w].attachments.erase(slot)
	guns[w].def = Arsenal.compose(guns[w].id, guns[w].attachments)
	guns[w].mag = mini(guns[w].mag, int(guns[w].def.mag))
	return true


func use_medkit() -> bool:
	if medkits <= 0 or healing > 0.0 or owner.hp >= owner.MAX_HP:
		return false
	medkits -= 1
	healing = HEAL_TIME
	Sfx.play("pickup", owner.global_position, -2.0, 0.05)
	return true
