class_name Boss
## Boss (arcade, toutes les 5 manches) : grand, blindé (membres 4 fois plus solides), peu sensible au recul, et
## ses tirs s'annoncent (lueur rouge au canon une demi-seconde avant chaque rafale).

const SCALE := 1.7
const HP := 600.0
const ARMOR := 4.0
const KNOCK := 0.25
const CHARGE := 0.5
const COLOR := Color(1.0, 0.18, 0.15)


## Transforme un combattant en boss (aussi les marionnettes en ligne, pour l'aspect).
static func make(f: Fighter) -> void:
	if f.boss:
		return
	f.boss = true
	if not f.remote:
		f.display_name = "BOSS"
	f.team_color = COLOR
	f.rig.scale = Vector2.ONE * 1.22 * SCALE
	var cap: CapsuleShape2D = f._shape.shape
	cap.radius = 9.0
	cap.height = 56.0
	f._shape.position = Vector2(0, -28)
	f.hp = HP
	for part in f.body.hp:
		f.body.hp[part] = float(BodyParts.PARTS[part].hp) * ARMOR


## Rafale demandée : d'abord la lueur d'avertissement, le tir part quand elle est finie.
static func charge(g: Gun, delta: float, trigger: bool) -> bool:
	if g.charge_t > 0.0:
		g.charge_t -= delta
		return g.charge_t <= 0.0
	if trigger and g.cd <= 0.0 and g.mag > 0 and g.reload_t <= 0.0:
		g.charge_t = CHARGE
		Sfx.play("reload_out", g.owner.global_position, -2.0, 0.0)
	return false
