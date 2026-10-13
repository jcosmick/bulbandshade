class_name Icons
extends RefCounted
## Icone disegnate da codice per il menu (stesso stile degli oggetti di gioco).
## Ogni icona è centrata in "center" e sta in un quadrato di lato "size".

const GLASS_FILL := Color(0.6, 0.85, 1.0, 0.25)
const GLASS_EDGE := Color(0.75, 0.92, 1.0, 0.9)
const WATER := Color(0.35, 0.65, 1.0)
const WINDOW_FRAME := Color(0.45, 0.37, 0.3)
const WINDOW_LIGHT := Color(1.0, 0.92, 0.7)
const BOLT := Color(1.0, 0.85, 0.35)
const LOCK := Color(0.45, 0.44, 0.5)
const SHADOW := Color(0, 0, 0, 0.85)
const GEAR := Color(0.85, 0.82, 0.76)
const GEAR_HOLE := UiStyle.CARD


static func draw(canvas: CanvasItem, icon: String, center: Vector2, size: float) -> void:
	var s := size / 100.0
	canvas.draw_set_transform(center, 0.0, Vector2(s, s))
	match icon:
		"crate":
			_crate_with_shadow(canvas)
		"glass":
			_glass(canvas)
		"rain":
			_rain(canvas)
		"warehouse":
			_warehouse(canvas)
		"rail":
			_rail(canvas)
		"factory":
			_factory(canvas)
		"cellar":
			_cellar(canvas)
		"lock":
			_lock(canvas)
		"bolt":
			_bolt(canvas)
		"gear":
			_gear(canvas)
		"home":
			_home(canvas)
		"restart":
			_restart(canvas)
		"close":
			_close(canvas)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## Livello 1: cassa con la sua ombra a rampa.
static func _crate_with_shadow(canvas: CanvasItem) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-46, -6), Vector2(46, -46), Vector2(46, 42), Vector2(2, 42), Vector2(2, -6)
	]), SHADOW)
	_crate(canvas, Rect2(-46, -6, 48, 48))


## Livello 2: lastra di vetro davanti a una cassa.
static func _glass(canvas: CanvasItem) -> void:
	_crate(canvas, Rect2(-10, -16, 52, 52))
	var pane := Rect2(-44, -40, 40, 84)
	canvas.draw_rect(pane, GLASS_FILL)
	canvas.draw_rect(pane, GLASS_EDGE, false, 4.0)
	canvas.draw_line(Vector2(-36, -30), Vector2(-36, 2), Color(1, 1, 1, 0.7), 4.0)


## Livello 3: finestra e gocce di pioggia.
static func _rain(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(-46, -44, 56, 64), WINDOW_FRAME)
	canvas.draw_rect(Rect2(-40, -38, 44, 52), WINDOW_LIGHT)
	canvas.draw_line(Vector2(-18, -38), Vector2(-18, 14), WINDOW_FRAME, 5.0)
	canvas.draw_line(Vector2(-40, -12), Vector2(4, -12), WINDOW_FRAME, 5.0)
	for p: Vector2 in [Vector2(30, -20), Vector2(22, 18), Vector2(42, 38)]:
		_drop(canvas, p, 11.0)


## Livello 4: magazzino a più piani, percorso a zig-zag verso l'alto.
static func _warehouse(canvas: CanvasItem) -> void:
	for shelf: Rect2 in [Rect2(-46, 36, 92, 8), Rect2(-10, 8, 56, 8), Rect2(-46, -20, 56, 8), Rect2(0, -48, 46, 8)]:
		canvas.draw_rect(shelf, LevelKit.TERRAIN_EDGE)
	_crate(canvas, Rect2(-40, 14, 22, 22))
	_crate(canvas, Rect2(22, -14, 22, 22))
	canvas.draw_polyline(PackedVector2Array([
		Vector2(-30, 30), Vector2(30, 2), Vector2(-30, -26), Vector2(26, -56)
	]), BOLT, 4.0)
	_drop(canvas, Vector2(-30, -2), 7.0)


## Livello 5: cassa appesa a un carrello sulla rotaia, sotto un lucernario.
static func _rail(canvas: CanvasItem) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-40, -40), Vector2(-4, -40), Vector2(8, 46), Vector2(-28, 46)
	]), Color(WINDOW_LIGHT, 0.35))
	canvas.draw_rect(Rect2(-46, -48, 46, 8), WINDOW_LIGHT)
	canvas.draw_rect(Rect2(-48, -28, 96, 7), LevelKit.TERRAIN_EDGE)
	canvas.draw_rect(Rect2(14, -34, 22, 16), LOCK)
	for x in [18.0, 32.0]:
		canvas.draw_circle(Vector2(x, -30), 5.0, GLASS_EDGE)
	canvas.draw_line(Vector2(25, -18), Vector2(25, 2), LOCK, 4.0)
	_crate(canvas, Rect2(6, 2, 38, 34))
	canvas.draw_line(Vector2(-6, -12), Vector2(-26, -12), BOLT, 4.0)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-34, -12), Vector2(-24, -19), Vector2(-24, -5)
	]), BOLT)


## Livello 6: capannone con ciminiera, finestra accesa e cassa.
static func _factory(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(22, -48, 16, 40), LevelKit.TERRAIN_EDGE)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-46, 44), Vector2(-46, -12), Vector2(-16, -30), Vector2(-16, -12),
		Vector2(14, -30), Vector2(14, -12), Vector2(46, -30), Vector2(46, 44)
	]), LevelKit.TERRAIN_EDGE)
	canvas.draw_rect(Rect2(-36, 0, 26, 20), WINDOW_LIGHT)
	canvas.draw_line(Vector2(-23, 0), Vector2(-23, 20), WINDOW_FRAME, 4.0)
	_crate(canvas, Rect2(6, 8, 30, 30))
	_drop(canvas, Vector2(-26, -40), 7.0)


## Livello 7: cantina con ragnatela, botte, mensola di barattoli e gocciolio.
static func _cellar(canvas: CanvasItem) -> void:
	# Ragnatela nell'angolo in alto a sinistra: raggi e fili concentrici.
	var corner := Vector2(-48, -48)
	for a in [0.0, PI / 6.0, PI / 3.0, PI / 2.0]:
		canvas.draw_line(corner, corner + Vector2.from_angle(a) * 44.0, GLASS_EDGE, 2.0)
	for r in [18.0, 32.0]:
		canvas.draw_arc(corner, r, 0.0, PI / 2.0, 10, GLASS_EDGE, 2.0)
	# Mensola con due barattoli.
	canvas.draw_rect(Rect2(-2, -14, 48, 6), LevelKit.TERRAIN_EDGE)
	for jar: Rect2 in [Rect2(6, -36, 14, 22), Rect2(26, -30, 14, 16)]:
		canvas.draw_rect(jar, GLASS_FILL)
		canvas.draw_rect(Rect2(jar.position.x, jar.end.y - jar.size.y * 0.55, jar.size.x, jar.size.y * 0.55), LevelKit.WOOD)
		canvas.draw_rect(jar, GLASS_EDGE, false, 3.0)
		canvas.draw_rect(Rect2(jar.position.x - 2, jar.position.y - 5, jar.size.x + 4, 5), LOCK)
	# Botte in piedi: fianchi bombati e cerchi di ferro.
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-40, -2), Vector2(-10, -2), Vector2(-4, 21), Vector2(-10, 44),
		Vector2(-40, 44), Vector2(-46, 21)
	]), LevelKit.WOOD)
	for x in [-30.0, -20.0]:
		canvas.draw_line(Vector2(x, -2), Vector2(x, 44), LevelKit.WOOD_DARK, 2.0)
	for y in [6.0, 36.0]:
		canvas.draw_line(Vector2(-43, y), Vector2(-7, y), LOCK, 5.0)
	# Pozza d'acqua e goccia che cade dalla mensola.
	canvas.draw_rect(Rect2(4, 36, 42, 8), WATER)
	_drop(canvas, Vector2(26, 16), 6.0)


## Livello bloccato.
static func _lock(canvas: CanvasItem) -> void:
	canvas.draw_arc(Vector2(0, -12), 22.0, PI, TAU, 24, LOCK, 9.0)
	canvas.draw_line(Vector2(-22, -12), Vector2(-22, 6), LOCK, 9.0)
	canvas.draw_line(Vector2(22, -12), Vector2(22, 6), LOCK, 9.0)
	canvas.draw_rect(Rect2(-34, 4, 68, 46), LOCK)
	canvas.draw_circle(Vector2(0, 22), 7.0, Color(0, 0, 0, 0.5))
	canvas.draw_rect(Rect2(-3, 22, 6, 14), Color(0, 0, 0, 0.5))


## Fulmine (record di flash).
static func _bolt(canvas: CanvasItem) -> void:
	var points := PackedVector2Array([
		Vector2(0.2, -1.1), Vector2(-0.6, 0.15), Vector2(-0.05, 0.15),
		Vector2(-0.25, 1.1), Vector2(0.6, -0.2), Vector2(0.05, -0.2)
	])
	for i in points.size():
		points[i] *= 45.0
	canvas.draw_colored_polygon(points, BOLT)


## Ingranaggio (impostazioni): 8 denti attorno a un anello col foro centrale.
static func _gear(canvas: CanvasItem) -> void:
	const TEETH := 8
	var points := PackedVector2Array()
	for i in TEETH:
		var a := TAU * i / TEETH
		var half := TAU / TEETH
		# Ogni dente: base sul cerchio interno, punta più stretta su quello esterno.
		points.append(Vector2.from_angle(a - half * 0.32) * 34.0)
		points.append(Vector2.from_angle(a - half * 0.2) * 46.0)
		points.append(Vector2.from_angle(a + half * 0.2) * 46.0)
		points.append(Vector2.from_angle(a + half * 0.32) * 34.0)
	canvas.draw_colored_polygon(points, GEAR)
	canvas.draw_circle(Vector2.ZERO, 36.0, GEAR)
	canvas.draw_circle(Vector2.ZERO, 15.0, GEAR_HOLE)


## Casetta (torna al menu).
static func _home(canvas: CanvasItem) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(0, -44), Vector2(46, -4), Vector2(-46, -4)
	]), UiStyle.TEXT)
	canvas.draw_rect(Rect2(-32, -4, 64, 44), UiStyle.TEXT)
	canvas.draw_rect(Rect2(-9, 14, 18, 26), Color(0, 0, 0, 0.6))


## Freccia circolare (ricomincia il livello).
static func _restart(canvas: CanvasItem) -> void:
	const RADIUS := 32.0
	var start := -PI / 2.0 + 0.9
	var end := -PI / 2.0 + TAU - 0.5
	canvas.draw_arc(Vector2.ZERO, RADIUS, start, end, 32, UiStyle.TEXT, 11.0, true)
	# Punta della freccia alla fine dell'arco, orientata in senso orario.
	var tip := Vector2.from_angle(end) * RADIUS
	var forward := Vector2.from_angle(end + PI / 2.0)
	var out := Vector2.from_angle(end)
	canvas.draw_colored_polygon(PackedVector2Array([
		tip + forward * 18.0, tip - forward * 6.0 + out * 17.0, tip - forward * 6.0 - out * 17.0
	]), UiStyle.TEXT)


## X (chiudi).
static func _close(canvas: CanvasItem) -> void:
	canvas.draw_line(Vector2(-30, -30), Vector2(30, 30), UiStyle.TEXT, 12.0, true)
	canvas.draw_line(Vector2(30, -30), Vector2(-30, 30), UiStyle.TEXT, 12.0, true)


static func _crate(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, LevelKit.WOOD)
	var plank := rect.size.y / 3.0
	for i in range(1, 3):
		var y := rect.position.y + plank * i
		canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), LevelKit.WOOD_DARK, 3.0)
	canvas.draw_rect(rect.grow(-3.0), LevelKit.WOOD_DARK, false, 6.0)


static func _drop(canvas: CanvasItem, at: Vector2, r: float) -> void:
	canvas.draw_circle(at, r, WATER)
	canvas.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-r * 0.95, -r * 0.3), at + Vector2(0, -r * 2.2), at + Vector2(r * 0.95, -r * 0.3)
	]), WATER)
