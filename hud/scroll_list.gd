class_name ScrollList
extends RefCounted
## Liste défilante des menus : ne montre que les lignes qui tiennent entre leur départ et le bas de l'écran, suit la
## sélection (clavier, manette, molette) et affiche un chevron en haut ou en bas quand des lignes sont cachées.

var first := 0
var rows := 0
var count := 0


## Fenêtre visible pour `n` lignes de hauteur `h`, la première à `y0`, rien sous `bottom` ; garde `sel` à l'écran.
func layout(n: int, sel: int, y0: float, bottom: float, h: float) -> void:
	count = n
	rows = clampi(int((bottom - y0) / h) + 1, 1, maxi(n, 1))
	if sel < first:
		first = sel
	elif sel >= first + rows:
		first = sel - rows + 1
	first = clampi(first, 0, maxi(n - rows, 0))


func last() -> int:
	return mini(first + rows, count)


## Molette : -1 vers le haut, 1 vers le bas, 0 sinon.
static func wheel(event: InputEvent) -> int:
	if not (event is InputEventMouseButton and event.pressed):
		return 0
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			return -1
		MOUSE_BUTTON_WHEEL_DOWN:
			return 1
	return 0


## Chevrons au-dessus de la première ligne et sous la dernière quand il en reste de cachées.
func draw_arrows(c: CanvasItem, cx: float, top: float, bottom: float, col: Color) -> void:
	if first > 0:
		c.draw_polyline(PackedVector2Array([Vector2(cx - 6, top + 3), Vector2(cx, top - 2), Vector2(cx + 6, top + 3)]),
			col, 1.5, true)
	if last() < count:
		c.draw_polyline(PackedVector2Array([Vector2(cx - 6, bottom - 3), Vector2(cx, bottom + 2),
			Vector2(cx + 6, bottom - 3)]), col, 1.5, true)
