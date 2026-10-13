@tool
extends Node2D
## Parete di fondo della stanza (solo decorazione, nessuna collisione).

## Stile del fondo: stanza con carta da parati, oppure serra con finestroni
## quadrati di vetro smerigliato su un muretto di mattoni. Le piante oltre il
## vetro sono su due piani che scorrono in parallasse quando la telecamera si
## muove (solo in gioco, non nell'editor).
@export_enum("room", "greenhouse") var style := "room":
	set(value):
		style = value
		_refresh()
@export var rect := Rect2(0, 0, 1080, 1520):
	set(value):
		rect = value
		_refresh()
## Altezza (y) della zoccolatura in legno (nella serra: del muretto).
@export var wainscot_y := 1200.0:
	set(value):
		wainscot_y = value
		_refresh()
## Solo serra: cambialo per avere piante e vetri disposti diversamente.
@export var pattern := 1:
	set(value):
		pattern = value
		_refresh()

const WALL := Color(0.38, 0.34, 0.42)
const STRIPE := Color(0.34, 0.30, 0.38)
const PANEL := Color(0.30, 0.25, 0.27)
const MOLDING := Color(0.44, 0.37, 0.36)
const STRIPE_STEP := 90.0

## Serra: telaio in ferro, vetro smerigliato più chiaro in alto.
const IRON := Color(0.2, 0.21, 0.24)
const IRON_LIGHT := Color(0.29, 0.3, 0.33)
const GLASS_TOP := Color(0.42, 0.47, 0.46)
const GLASS_BOTTOM := Color(0.31, 0.36, 0.36)
const GLASS_SHINE := Color(1, 1, 1, 0.07)
## Opacità del velo smerigliato davanti alle piante.
const FROST := 0.3
## Sagome sfocate delle piante oltre il vetro: piano lontano (più chiaro) e
## piano vicino (più scuro).
const FOLIAGE_FAR := Color(0.2, 0.29, 0.25)
const FOLIAGE_NEAR := Color(0.09, 0.15, 0.11)
## Quanto ogni piano segue la telecamera (0 = fermo col livello, 1 = fermo
## sullo schermo): più è alto, più il piano sembra lontano.
const PARALLAX_FAR := 0.6
const PARALLAX_NEAR := 0.3
const MORTAR := Color(0.25, 0.21, 0.24)
const BRICK := Color(0.33, 0.23, 0.23)
const BRICK_DARK := Color(0.27, 0.19, 0.2)
const SILL := Color(0.4, 0.38, 0.38)
## Lato del riquadro (vetro + montante) e spessore dei montanti.
const CELL := 150.0
const MULLION := 12.0
## Ogni quanti riquadri c'è un pilastro più spesso.
const COLUMN_EVERY := 3
const COLUMN := 22.0
const BRICK_SIZE := Vector2(52, 22)

var _far: Node2D
var _near: Node2D
var _front: Node2D


func _ready() -> void:
	z_index = -10
	# Strati della serra, disegnati sopra il fondo in quest'ordine. Interni:
	# non finiscono nella scena salvata.
	_far = _make_layer(_draw_foliage.bind(false))
	_near = _make_layer(_draw_foliage.bind(true))
	_front = _make_layer(_draw_front)


func _make_layer(painter: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.draw.connect(painter)
	add_child(layer, false, Node.INTERNAL_MODE_FRONT)
	return layer


func _refresh() -> void:
	queue_redraw()
	for layer in [_far, _near, _front]:
		if layer:
			layer.queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or style != "greenhouse":
		return
	# Solo in orizzontale: in verticale le piante si staccherebbero dal muretto.
	var screen_center := get_viewport().get_canvas_transform().affine_inverse() * (get_viewport_rect().size / 2.0)
	var shift := to_local(screen_center).x - rect.get_center().x
	_far.position.x = shift * PARALLAX_FAR
	_near.position.x = shift * PARALLAX_NEAR


func _draw() -> void:
	if style == "greenhouse":
		_draw_glass(self, 1.0)
		return
	draw_rect(rect, WALL)
	var x := rect.position.x
	while x < rect.end.x:
		draw_rect(Rect2(x, rect.position.y, STRIPE_STEP / 2.0, wainscot_y - rect.position.y), STRIPE)
		x += STRIPE_STEP
	draw_rect(Rect2(rect.position.x, wainscot_y, rect.size.x, rect.end.y - wainscot_y), PANEL)
	draw_rect(Rect2(rect.position.x, wainscot_y - 6.0, rect.size.x, 12.0), MOLDING)


## Lastre di vetro: sfumatura verticale continua, con piccole differenze tra
## lastre. Disegnate piene come luce di fondo e semitrasparenti come velo.
func _draw_glass(canvas: CanvasItem, alpha: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	var top := rect.position.y
	var area := Rect2(rect.position.x, top, rect.size.x, wainscot_y - top)
	var span := maxf(area.size.y, 1.0)
	var y := top
	while y < wainscot_y:
		var x := rect.position.x
		while x < rect.end.x:
			var pane := Rect2(x + MULLION / 2.0, y + MULLION / 2.0, CELL - MULLION, CELL - MULLION).intersection(area)
			if pane.has_area():
				var shade := rng.randf_range(-0.025, 0.025)
				var c_top := GLASS_BOTTOM.lerp(GLASS_TOP, 1.0 - (pane.position.y - top) / span)
				var c_bottom := GLASS_BOTTOM.lerp(GLASS_TOP, 1.0 - (pane.end.y - top) / span)
				c_top = c_top.lightened(shade) if shade > 0.0 else c_top.darkened(-shade)
				c_bottom = c_bottom.lightened(shade) if shade > 0.0 else c_bottom.darkened(-shade)
				c_top.a = alpha
				c_bottom.a = alpha
				canvas.draw_polygon(_rect_polygon(pane), PackedColorArray([c_top, c_top, c_bottom, c_bottom]))
			x += CELL
		y += CELL


## Piante dietro il vetro: macchie sfocate (cerchi concentrici trasparenti).
## Restano dentro il fondo: scorrendo escono solo dai lati che la telecamera
## non inquadra.
func _draw_foliage(near: bool) -> void:
	if style != "greenhouse":
		return
	var layer := _near if near else _far
	var color := FOLIAGE_NEAR if near else FOLIAGE_FAR
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern * 2 + (1 if near else 0)
	var size_range := Vector2(90.0, 180.0) if near else Vector2(60.0, 130.0)
	var tall_chance := 0.25 if near else 0.5
	var x := rect.position.x + 60.0 + rng.randf_range(0.0, 80.0)
	while x < rect.end.x - 60.0:
		# Il raggio non supera i bordi del fondo.
		var radius := minf(rng.randf_range(size_range.x, size_range.y), minf(x - rect.position.x, rect.end.x - x))
		var center := Vector2(x, wainscot_y - rng.randf_range(0.0, radius * (0.4 if near else 0.9)))
		for ring in 4:
			layer.draw_circle(center, radius * (1.0 - ring * 0.18), Color(color, 0.18 + ring * 0.1))
		# Ogni tanto una pianta più alta, a ciuffo.
		if rng.randf() < tall_chance:
			var tall := Vector2(x + rng.randf_range(-30.0, 30.0), center.y - radius - rng.randf_range(60.0, 200.0))
			layer.draw_line(tall, Vector2(tall.x, wainscot_y), Color(color, 0.45), 12.0 if near else 8.0)
			for ring in 3:
				layer.draw_circle(tall, radius * (0.55 - ring * 0.12), Color(color, 0.18 + ring * 0.1))
		x += rng.randf_range(130.0, 240.0) if near else rng.randf_range(90.0, 170.0)


## Velo smerigliato, telaio e muretto davanti alle piante.
func _draw_front() -> void:
	if style != "greenhouse":
		return
	_draw_glass(_front, FROST)
	var top := rect.position.y
	var glass_bottom := wainscot_y
	# Telaio: pilastri più spessi ogni tanto.
	var col := 0
	var gx := rect.position.x
	while gx <= rect.end.x:
		var width := COLUMN if col % COLUMN_EVERY == 0 else MULLION
		_front.draw_rect(Rect2(gx - width / 2.0, top, width, glass_bottom - top), IRON)
		if width == COLUMN:
			_front.draw_line(Vector2(gx - width / 2.0 + 3.0, top), Vector2(gx - width / 2.0 + 3.0, glass_bottom), IRON_LIGHT, 2.0)
		gx += CELL
		col += 1
	var gy := top
	while gy <= glass_bottom:
		_front.draw_rect(Rect2(rect.position.x, gy - MULLION / 2.0, rect.size.x, MULLION), IRON)
		gy += CELL
	# Bulloni agli incroci e riflesso in un angolo di ogni lastra.
	gy = top
	while gy < glass_bottom:
		gx = rect.position.x
		while gx < rect.end.x:
			_front.draw_circle(Vector2(gx, gy), 4.0, IRON_LIGHT)
			var corner := Vector2(gx + MULLION / 2.0 + 10.0, gy + MULLION / 2.0 + 10.0)
			if corner.y + 40.0 < glass_bottom:
				_front.draw_line(corner + Vector2(0, 40), corner + Vector2(40, 0), GLASS_SHINE, 4.0)
				_front.draw_line(corner + Vector2(0, 62), corner + Vector2(62, 0), GLASS_SHINE, 2.0)
			gx += CELL
		gy += CELL

	# Muretto di mattoni sotto le vetrate, con davanzale.
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	var wall := Rect2(rect.position.x, glass_bottom, rect.size.x, rect.end.y - glass_bottom)
	_front.draw_rect(wall, MORTAR)
	var row := 0
	var y := wall.position.y
	while y < wall.end.y:
		var bx := wall.position.x - (BRICK_SIZE.x / 2.0 if row % 2 == 1 else 0.0)
		while bx < wall.end.x:
			var brick := Rect2(bx + 2.0, y + 2.0, BRICK_SIZE.x - 4.0, BRICK_SIZE.y - 4.0).intersection(wall)
			if brick.has_area():
				_front.draw_rect(brick, BRICK.lerp(BRICK_DARK, rng.randf()))
			bx += BRICK_SIZE.x
		y += BRICK_SIZE.y
		row += 1
	_front.draw_rect(Rect2(rect.position.x, glass_bottom - 8.0, rect.size.x, 16.0), SILL)
	_front.draw_rect(Rect2(rect.position.x, glass_bottom + 8.0, rect.size.x, 4.0), MORTAR)


func _rect_polygon(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
