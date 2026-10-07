extends Node2D
## Couche d'effets : particules (étincelles, sang, fumée, douilles, éclairs, anneaux), traçantes, éclairs lumineux.

enum Kind { SPARK, BLOOD, SMOKE, FLASH, SHELL, RING }

const MAX_PARTS := 1400


class P:
	var kind: int
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var size: float
	var color: Color
	var rot := 0.0
	var spin := 0.0
	var grav := 0.0
	var drag := 0.0


var parts: Array[P] = []
var tracers: Array[Dictionary] = []
var _lights: Array[PointLight2D] = []
var _light_i := 0


func _ready() -> void:
	z_index = 20
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.gradient = Gradient.new()
	tex.gradient.set_color(1, Color(1, 1, 1, 0))
	for i in 6:
		var l := PointLight2D.new()
		l.texture = tex
		l.texture_scale = 2.5
		l.energy = 0.0
		add_child(l)
		_lights.append(l)


func clear() -> void:
	parts.clear()
	tracers.clear()


func emit(kind: int, pos: Vector2, vel: Vector2, life: float, size: float, color: Color) -> P:
	if parts.size() >= MAX_PARTS:
		parts.pop_front()
	var p := P.new()
	p.kind = kind
	p.pos = pos
	p.vel = vel
	p.life = life
	p.max_life = life
	p.size = size
	p.color = color
	parts.append(p)
	return p


func _process(delta: float) -> void:
	var keep: Array[P] = []
	for p in parts:
		if _step(p, delta):
			keep.append(p)
	parts = keep
	for t in tracers:
		t.life -= delta
	tracers = tracers.filter(func(t: Dictionary) -> bool: return t.life > 0.0)
	for l in _lights:
		l.energy = move_toward(l.energy, 0.0, delta * 30.0)
	queue_redraw()


func _step(p: P, delta: float) -> bool:
	p.life -= delta
	if p.life <= 0.0:
		return false
	p.vel.y += p.grav * delta
	p.vel /= 1.0 + p.drag * delta
	p.rot += p.spin * delta
	var next := p.pos + p.vel * delta
	if (p.kind == Kind.BLOOD or p.kind == Kind.SHELL) and Juice.arena.solid_at(next):
		if p.kind == Kind.BLOOD:
			Juice.stains.add(p.pos, p.size * randf_range(0.6, 1.2), p.color)
			return false
		p.vel = Vector2(p.vel.x * 0.5, -absf(p.vel.y) * 0.35)
		p.spin *= 0.5
		return true
	p.pos = next
	return true


func _draw() -> void:
	for t in tracers:
		_draw_tracer(t)
	for p in parts:
		var k := p.life / p.max_life
		match p.kind:
			Kind.SPARK, Kind.BLOOD:
				var c := p.color
				c.a *= minf(k * 2.0, 1.0)
				draw_line(p.pos - p.vel * 0.03, p.pos, c, p.size)
			Kind.SMOKE:
				var c := p.color
				c.a *= k * k
				draw_circle(p.pos, p.size * (1.0 + (1.0 - k) * 2.0), c)
			Kind.FLASH:
				_draw_flash(p, k)
			Kind.SHELL:
				draw_set_transform(p.pos, p.rot)
				draw_rect(Rect2(-1.2, -0.6, 2.4, 1.2), p.color * Color(1, 1, 1, minf(k * 4.0, 1.0)))
				draw_set_transform(Vector2.ZERO)
			Kind.RING:
				var c := p.color
				c.a *= k
				draw_arc(p.pos, p.size * (1.0 - k * k * k), 0.0, TAU, 32, c, 0.4 + 1.2 * k)


func _draw_tracer(t: Dictionary) -> void:
	var k: float = t.life / t.max
	var from: Vector2 = t.from
	var to: Vector2 = t.to
	var a := from.lerp(to, 1.0 - k)
	var col: Color = t.color
	draw_line(a, to, Color(col, k), t.width * (0.5 + k))
	draw_line(a.lerp(to, 0.3), to, Color(3, 3, 3, k), maxf(t.width * 0.4, 0.6))


func _draw_flash(p: P, k: float) -> void:
	var dir := p.vel.normalized()
	var s := p.size * 0.6 * (0.6 + 0.4 * k)
	var side := dir.orthogonal() * s * 0.35
	var tip := p.pos + dir * s * 2.2
	draw_colored_polygon(PackedVector2Array([p.pos - side, tip, p.pos + side, p.pos - dir * s * 0.4]), p.color)
	draw_circle(p.pos, s * 0.3, Color(2.2, 2.0, 1.7))


func flash_light(pos: Vector2, color: Color, energy: float) -> void:
	var l := _lights[_light_i]
	_light_i = (_light_i + 1) % _lights.size()
	l.global_position = pos
	var m := maxf(maxf(color.r, color.g), maxf(color.b, 0.001))
	l.color = Color(color.r / m, color.g / m, color.b / m)
	l.energy = energy
