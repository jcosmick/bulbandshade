@tool
extends Node2D
## Parete di fondo della stanza (solo decorazione, nessuna collisione).

## Stile del fondo: stanza con carta da parati, oppure serra con finestroni
## quadrati di vetro smerigliato su un muretto di mattoni. Le piante oltre il
## vetro sono su due piani che scorrono in parallasse quando la telecamera si
## muove (solo in gioco, non nell'editor). Il magazzino ha una parete in
## lamiera e scaffalature su due piani in parallasse, dietro pilastri fissi.
@export_enum("room", "greenhouse", "warehouse") var style := "room":
	set(value):
		style = value
		_refresh()
@export var rect := Rect2(0, 0, 1080, 1520):
	set(value):
		rect = value
		_refresh()
## Altezza (y) della zoccolatura in legno (nella serra: del muretto; nel
## magazzino: della fascia di cemento con le strisce di pericolo).
@export var wainscot_y := 1200.0:
	set(value):
		wainscot_y = value
		_refresh()
## Solo magazzino: opacità dell'ombra che scaffali e pile proiettano sul muro
## (0 = nessuna ombra, 1 = nera).
@export_range(0.0, 0.2, 0.01) var rack_shadow_opacity := 0.1:
	set(value):
		rack_shadow_opacity = value
		_refresh()
## Solo serra e magazzino: cambialo per avere piante, vetri e scaffali
## disposti diversamente.
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
## Magazzino: la parete di lamiera è la cosa più lontana, quindi segue la
## telecamera più degli scaffali.
const PARALLAX_WALL := 0.75
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

## Magazzino: parete in lamiera ondulata con fascia di cemento in basso.
const SHEET := Color(0.27, 0.27, 0.32)
const SHEET_RIB := Color(0.24, 0.24, 0.29)
const SHEET_SEAM := Color(0.2, 0.2, 0.25)
const CONCRETE := Color(0.24, 0.23, 0.26)
## Distanza tra due bande chiare della lamiera (ogni banda è larga la metà).
const RIB_STEP := 140.0
## Scaffalature: sagome piatte un po' più chiare della parete, come viste
## attraverso la polvere; quelle lontane quasi si confondono con la lamiera.
const RACK_FAR := Color(0.29, 0.29, 0.34)
const RACK_NEAR := Color(0.33, 0.33, 0.38)
const GOODS_FAR := Color(0.31, 0.3, 0.34)
const GOODS_NEAR := [Color(0.38, 0.33, 0.31), Color(0.35, 0.31, 0.3), Color(0.36, 0.34, 0.36)]
const RACK_SHADOW_OFFSET := Vector2(14, 10)
## Pilastri e trave in primo piano (fermi col livello).
const GIRDER := Color(0.17, 0.17, 0.21)
const GIRDER_LIGHT := Color(0.26, 0.26, 0.31)
const PILLAR_STEP := 720.0
const PILLAR_WIDTH := 48.0

var _far: Node2D
var _near: Node2D
var _front: Node2D
## Solo magazzino: la parete di fondo, in parallasse dietro agli scaffali.
var _back: Node2D


func _ready() -> void:
	z_index = -10
	# Strati di serra e magazzino, disegnati sopra il fondo in quest'ordine.
	# Interni: non finiscono nella scena salvata.
	_back = _make_layer(_paint_layer.bind(-1))
	_far = _make_layer(_paint_layer.bind(0))
	_near = _make_layer(_paint_layer.bind(1))
	_front = _make_layer(_paint_layer.bind(2))


func _make_layer(painter: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.draw.connect(painter)
	add_child(layer, false, Node.INTERNAL_MODE_FRONT)
	return layer


func _refresh() -> void:
	queue_redraw()
	for layer in [_back, _far, _near, _front]:
		if layer:
			layer.queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or style == "room":
		return
	# Solo in orizzontale: in verticale piante e scaffali si staccherebbero
	# dal pavimento.
	var screen_center := get_viewport().get_canvas_transform().affine_inverse() * (get_viewport_rect().size / 2.0)
	var shift := to_local(screen_center).x - rect.get_center().x
	_back.position.x = shift * PARALLAX_WALL
	_far.position.x = shift * PARALLAX_FAR
	_near.position.x = shift * PARALLAX_NEAR


func _draw() -> void:
	if style == "greenhouse":
		_draw_glass(self, 1.0)
		return
	if style == "warehouse":
		# Riempie i bordi che la parete in parallasse lascia scoperti.
		draw_rect(rect, SHEET)
		return
	draw_rect(rect, WALL)
	var x := rect.position.x
	while x < rect.end.x:
		draw_rect(Rect2(x, rect.position.y, STRIPE_STEP / 2.0, wainscot_y - rect.position.y), STRIPE)
		x += STRIPE_STEP
	draw_rect(Rect2(rect.position.x, wainscot_y, rect.size.x, rect.end.y - wainscot_y), PANEL)
	draw_rect(Rect2(rect.position.x, wainscot_y - 6.0, rect.size.x, 12.0), MOLDING)


## Strato -1 (parete), 0 (lontano), 1 (vicino) o 2 (primo piano) dello stile
## attuale.
func _paint_layer(which: int) -> void:
	if which == -1:
		if style == "warehouse":
			_draw_sheet_wall()
	elif style == "greenhouse":
		if which == 2:
			_draw_front()
		else:
			_draw_foliage(which == 1)
	elif style == "warehouse":
		if which == 2:
			_draw_pillars()
		else:
			_draw_racks(which == 1)


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


## Magazzino: lamiera a bande larghe, giunte orizzontali e fascia di cemento.
func _draw_sheet_wall() -> void:
	var top := rect.position.y
	_back.draw_rect(rect, SHEET)
	var x := rect.position.x
	while x < rect.end.x:
		_back.draw_rect(Rect2(x, top, minf(RIB_STEP / 2.0, rect.end.x - x), wainscot_y - top), SHEET_RIB)
		x += RIB_STEP
	var y := top + 300.0
	while y < wainscot_y:
		_back.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), SHEET_SEAM, 4.0)
		y += 300.0
	_back.draw_rect(Rect2(rect.position.x, wainscot_y, rect.size.x, rect.end.y - wainscot_y), CONCRETE)
	_back.draw_line(Vector2(rect.position.x, wainscot_y), Vector2(rect.end.x, wainscot_y), SHEET_SEAM, 6.0)


## Scaffalature su un piano, come sagome piatte senza dettagli: quelle
## lontane alte, sottili e quasi del colore della parete; quelle vicine basse e
## robuste, con poche scatole, qualche pila a terra e qualche scala. Restano
## dentro il fondo: scorrendo escono solo dai lati che la telecamera non
## inquadra.
func _draw_racks(near: bool) -> void:
	var canvas := _near if near else _far
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern * 2 + (1 if near else 0)
	var floor_y := rect.end.y
	var bay := 300.0 if near else 200.0
	var x := rect.position.x + rng.randf_range(40.0, 260.0)
	while true:
		var bays := mini(rng.randi_range(2, 3), int((rect.end.x - 40.0 - x) / bay))
		if bays < 1:
			break
		var levels := rng.randi_range(2, 3)
		if not near:
			var most := clampi(int((floor_y - rect.position.y - 200.0) / 170.0), 2, 7)
			levels = rng.randi_range(most - 1, most)
		_draw_rack(canvas, Vector2(x, floor_y), bays, levels, near, rng)
		x += bays * bay
		# Nello spazio tra uno scaffale e l'altro, a volte una pila o una scala.
		var space := rng.randf_range(180.0, 420.0) if near else rng.randf_range(120.0, 300.0)
		if near and x + space < rect.end.x - 40.0:
			var roll := rng.randf()
			if roll < 0.35:
				_draw_floor_stack(canvas, Vector2(x + space / 2.0, floor_y), rng)
			elif roll < 0.55:
				_draw_ladder(canvas, Vector2(x + space * 0.3, floor_y), rng)
		x += space


## Scaffale di `bays` campate e `levels` ripiani, appoggiato in `base`
## (spigolo in basso a sinistra).
func _draw_rack(canvas: CanvasItem, base: Vector2, bays: int, levels: int, near: bool, rng: RandomNumberGenerator) -> void:
	var bay := 300.0 if near else 200.0
	var gap := 230.0 if near else 170.0
	var upright := 16.0 if near else 8.0
	var beam := 20.0 if near else 8.0
	var color := RACK_NEAR if near else RACK_FAR
	var top := base.y - levels * gap - beam
	canvas.draw_rect(Rect2(Vector2(base.x, top) + RACK_SHADOW_OFFSET, Vector2(bays * bay + upright, base.y - top)), Color(0, 0, 0, rack_shadow_opacity))
	# Merce: a terra e su ogni ripiano, poca e sparsa.
	for level in levels + 1:
		var shelf_y := base.y - level * gap
		var height := gap - beam - 16.0 if level < levels else gap * 0.5
		for b in bays:
			if rng.randf() > (0.15 if level == levels else 0.4):
				continue
			var area := Rect2(base.x + b * bay + upright, shelf_y - height, bay - upright, height)
			_draw_goods(canvas, area, near, rng)
	for b in bays + 1:
		canvas.draw_rect(Rect2(base.x + b * bay, top, upright, base.y - top), color)
	for level in range(1, levels + 1):
		canvas.draw_rect(Rect2(base.x, base.y - level * gap, bays * bay + upright, beam), color)


## Una o due scatole (a volte con una più piccola sopra) appoggiate sul fondo
## di `area`.
func _draw_goods(canvas: CanvasItem, area: Rect2, near: bool, rng: RandomNumberGenerator) -> void:
	var x := area.position.x + rng.randf_range(0.05, 0.3) * area.size.x
	for i in rng.randi_range(1, 2):
		var size := Vector2(rng.randf_range(0.25, 0.4), rng.randf_range(0.4, 0.75)) * area.size
		if x + size.x > area.end.x - 6.0:
			break
		_draw_box(canvas, Rect2(x, area.end.y - size.y, size.x, size.y), near, rng)
		if near and rng.randf() < 0.3:
			var small := size * Vector2(0.7, 0.5)
			_draw_box(canvas, Rect2(x + (size.x - small.x) / 2.0, area.end.y - size.y - small.y, small.x, small.y), near, rng)
		x += size.x + rng.randf_range(6.0, 30.0)


## Scatola piatta: un colore e, vicino, un'ombra sul fondo.
func _draw_box(canvas: CanvasItem, r: Rect2, near: bool, rng: RandomNumberGenerator) -> void:
	var color: Color = GOODS_NEAR[rng.randi() % GOODS_NEAR.size()] if near else GOODS_FAR
	canvas.draw_rect(r, color)
	if near:
		canvas.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * 0.18, r.size.x, r.size.y * 0.18), color.darkened(0.12))


## Pila di scatole a terra, più stretta salendo.
func _draw_floor_stack(canvas: CanvasItem, base: Vector2, rng: RandomNumberGenerator) -> void:
	var width := rng.randf_range(110.0, 170.0)
	var y := base.y
	for i in rng.randi_range(2, 4):
		var height := rng.randf_range(70.0, 110.0)
		var offset := rng.randf_range(-12.0, 12.0)
		var box := Rect2(base.x - width / 2.0 + offset, y - height, width, height)
		canvas.draw_rect(Rect2(box.position + RACK_SHADOW_OFFSET, box.size), Color(0, 0, 0, rack_shadow_opacity))
		_draw_box(canvas, box, true, rng)
		y -= height
		width *= rng.randf_range(0.8, 0.95)


## Scala a pioli appoggiata (sagoma).
func _draw_ladder(canvas: CanvasItem, base: Vector2, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(420.0, 620.0)
	var bottom_l := base
	var bottom_r := base + Vector2(70.0, 0)
	var top_l := base + Vector2(height * 0.18, -height)
	var top_r := top_l + Vector2(56.0, 0)
	canvas.draw_line(bottom_l, top_l, RACK_NEAR, 10.0)
	canvas.draw_line(bottom_r, top_r, RACK_NEAR, 10.0)
	var rungs := int(height / 60.0)
	for i in range(1, rungs):
		var t := float(i) / rungs
		canvas.draw_line(bottom_l.lerp(top_l, t), bottom_r.lerp(top_r, t), RACK_NEAR, 6.0)


## Pilastri in acciaio a I e trave in alto, davanti agli scaffali.
func _draw_pillars() -> void:
	var top := rect.position.y
	var x := rect.position.x + PILLAR_STEP / 2.0
	while x < rect.end.x:
		var pillar := Rect2(x - PILLAR_WIDTH / 2.0, top, PILLAR_WIDTH, rect.size.y)
		_front.draw_rect(pillar, GIRDER)
		# Ali della trave a I, più chiare, con i rivetti.
		for edge in [pillar.position.x, pillar.end.x - 8.0]:
			_front.draw_rect(Rect2(edge, top, 8.0, rect.size.y), GIRDER_LIGHT)
		var ry := top + 60.0
		while ry < rect.end.y:
			for rx in [pillar.position.x + 4.0, pillar.end.x - 4.0]:
				_front.draw_circle(Vector2(rx, ry), 3.0, GIRDER)
			ry += 60.0
		# Piastra di base sulla fascia di cemento.
		_front.draw_rect(Rect2(pillar.position.x - 10.0, rect.end.y - 24.0, PILLAR_WIDTH + 20.0, 24.0), GIRDER_LIGHT)
		x += PILLAR_STEP
	_front.draw_rect(Rect2(rect.position.x, top, rect.size.x, 40.0), GIRDER)
	_front.draw_line(Vector2(rect.position.x, top + 38.0), Vector2(rect.end.x, top + 38.0), GIRDER_LIGHT, 4.0)


func _rect_polygon(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
