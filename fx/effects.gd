class_name Effects
## Recettes d'effets composés (bouche à feu, impact, sang, poussière, douilles) au-dessus de la couche fx.

const BLOOD := Color(0.55, 0.02, 0.05)


static func muzzle(pos: Vector2, dir: Vector2, color: Color, size: float) -> void:
	var fx: Node2D = Juice.fx
	var f = fx.emit(3, pos, dir * 0.01, 0.05, size, color)
	f.vel = dir
	for i in int(size):
		var d := dir.rotated(randf_range(-0.5, 0.5))
		var s = fx.emit(0, pos, d * randf_range(150, 420), randf_range(0.05, 0.14), 0.8, color)
		s.drag = 6.0
	var smoke = fx.emit(2, pos + dir * 3.0, dir * 30.0 + Vector2(0, -10), 0.5, 2.0, Color(0.6, 0.55, 0.6, 0.25))
	smoke.drag = 3.0
	fx.flash_light(pos, color, 0.7)


static func impact(pos: Vector2, normal: Vector2, color: Color) -> void:
	var fx: Node2D = Juice.fx
	for i in 7:
		var d := normal.rotated(randf_range(-1.1, 1.1))
		var s = fx.emit(0, pos, d * randf_range(120, 380), randf_range(0.12, 0.3), 0.9, color)
		s.grav = 500.0
		s.drag = 2.0
	for i in 2:
		var sm = fx.emit(2, pos, normal * randf_range(10, 30), randf_range(0.4, 0.8), 1.8, Color(0.5, 0.4, 0.5, 0.3))
		sm.drag = 2.0
	fx.emit(5, pos, Vector2.ZERO, 0.14, 5.0, Color(color, 0.6))


static func blood(pos: Vector2, dir: Vector2, amount: int) -> void:
	var fx: Node2D = Juice.fx
	for i in amount:
		var d := dir.rotated(randf_range(-0.7, 0.7))
		var v := d * randf_range(60, 320) + Vector2(0, -40)
		var b = fx.emit(1, pos, v, randf_range(0.5, 1.4), randf_range(1.0, 2.0), BLOOD)
		b.grav = 700.0
		b.drag = 0.6
	var mist = fx.emit(2, pos, dir * 20.0, 0.35, 2.5, Color(0.6, 0.0, 0.05, 0.5))
	mist.drag = 4.0


static func dust(pos: Vector2, amount: int, spread: float = 1.0) -> void:
	var fx: Node2D = Juice.fx
	for i in amount:
		var v := Vector2(randf_range(-70, 70) * spread, randf_range(-30, -5))
		var d = fx.emit(2, pos + Vector2(randf_range(-4, 4), 0), v, randf_range(0.3, 0.6), 1.6, Color(0.75, 0.6, 0.65, 0.35))
		d.drag = 4.0


static func shell(pos: Vector2, dir: Vector2) -> void:
	var fx: Node2D = Juice.fx
	var v := Vector2(-dir.x * randf_range(30, 80), randf_range(-160, -110))
	var s = fx.emit(4, pos, v, 2.5, 1.0, Color(1.6, 1.15, 0.4))
	s.grav = 700.0
	s.spin = randf_range(-30, 30)


static func tracer(from: Vector2, to: Vector2, color: Color, width: float, life: float = 0.09) -> void:
	Juice.fx.tracers.append({"from": from, "to": to, "color": color, "width": width, "life": life, "max": life})


## Giclée d'un membre arraché : gerbe de sang, morceaux de chair, brume, anneau rouge.
static func gore_burst(pos: Vector2, dir: Vector2, intensity: float) -> void:
	var fx: Node2D = Juice.fx
	blood(pos, dir, int(18 * intensity))
	for i in int(10 * intensity):
		var v := Vector2(randf_range(-160, 160), randf_range(-260, -60)) + dir * 120.0
		var chunk = fx.emit(4, pos, v, 3.0, 1.0, Color(0.45, 0.02, 0.04))
		chunk.grav = 800.0
		chunk.spin = randf_range(-20, 20)
	for i in 3:
		var m = fx.emit(2, pos, Vector2(randf_range(-30, 30), randf_range(-30, 0)), 0.6, 3.0, Color(0.5, 0.0, 0.03, 0.45))
		m.drag = 3.0
	fx.emit(5, pos, Vector2.ZERO, 0.22, 12.0 * intensity, Color(1.6, 0.1, 0.15, 0.8))


## Jet artériel : gouttes rapides dans une direction donnée.
static func spurt(pos: Vector2, vel: Vector2, amount: int) -> void:
	var fx: Node2D = Juice.fx
	for i in amount:
		var b = fx.emit(1, pos, vel.rotated(randf_range(-0.15, 0.15)) * randf_range(0.8, 1.2), 1.2, 1.4, BLOOD)
		b.grav = 700.0
		b.drag = 0.4
