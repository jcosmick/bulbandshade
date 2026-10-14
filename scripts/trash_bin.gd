@tool
class_name TrashBin
extends Node2D
## Cestino dei rifiuti, solo decorativo: niente collisioni né ombre.
## "bin" è il bidone di lamiera, "basket" il cestino di rete. Dentro può avere
## cartacce o lampadine rotte (il cimitero delle lampadine), e può essere
## rovesciato con il contenuto sparso a terra. L'origine è la base al centro:
## va a y = pavimento.

@export_enum("bin", "basket") var kind := "bin":
	set(value):
		kind = value
		queue_redraw()
@export_enum("empty", "trash", "bulbs") var contents := "trash":
	set(value):
		contents = value
		queue_redraw()
## Coperchio del bidone: chiuso (sollevato se è pieno), a terra accanto, o assente.
@export_enum("on", "off", "none") var lid := "on":
	set(value):
		lid = value
		queue_redraw()
## Rovesciato su un fianco, con l'apertura verso destra o sinistra.
@export_enum("no", "left", "right") var tipped := "no":
	set(value):
		tipped = value
		queue_redraw()
## Cambialo per un contenuto disposto diversamente.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()

const SIZES := {"bin": Vector2(76, 96), "basket": Vector2(64, 72)}
const TIN := Color(0.4, 0.41, 0.43)
const TIN_DARK := Color(0.28, 0.29, 0.31)
const TIN_LIGHT := Color(0.5, 0.51, 0.53)
const WIRE := Color(0.32, 0.32, 0.34)
const INSIDE := Color(0.12, 0.11, 0.12)
const PAPER := Color(0.52, 0.5, 0.46)
const PAPER_DARK := Color(0.38, 0.36, 0.33)
const PLASTIC := Color(0.13, 0.13, 0.15)
const PLASTIC_SHINE := Color(0.3, 0.3, 0.34)
const CAN := Color(0.4, 0.26, 0.24)
const BULB_SCALE := 0.42


func _ready() -> void:
	z_index = -5


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	var size: Vector2 = SIZES[kind]
	if tipped == "no":
		if kind == "basket":
			draw_colored_polygon(_body(size), INSIDE)
		if contents != "empty":
			_draw_peeking(rng, size)
		_draw_body(size, Transform2D.IDENTITY)
		if kind == "bin":
			_draw_lid(size, rng)
		return
	# Rovesciato: il fondo a terra da un lato, l'apertura verso `tipped`.
	var side := 1.0 if tipped == "right" else -1.0
	var xform := Transform2D(side * PI / 2.0, Vector2(-side * size.y / 2.0, -size.x / 2.0))
	if contents != "empty":
		_draw_spill(rng, size, side)
	if kind == "basket":
		draw_set_transform_matrix(xform)
		draw_colored_polygon(_body(size), INSIDE)
	_draw_body(size, xform)
	if kind == "bin" and lid == "off":
		_draw_lid_on_floor(size, -side * (size.y / 2.0 + 30.0))


## Sagoma del cestino dritto: un po' più stretto in fondo.
func _body(size: Vector2) -> PackedVector2Array:
	var top := size.x / 2.0
	var bottom := top * 0.84
	return PackedVector2Array([
		Vector2(-top, -size.y), Vector2(top, -size.y), Vector2(bottom, 0), Vector2(-bottom, 0)
	])


func _draw_body(size: Vector2, xform: Transform2D) -> void:
	draw_set_transform_matrix(xform)
	var body := _body(size)
	var top := size.x / 2.0
	if kind == "bin":
		draw_colored_polygon(body, TIN)
		# Costolature della lamiera e riflesso verticale.
		for i in 3:
			var y := -size.y * (0.25 + i * 0.25)
			var w := lerpf(top * 0.84, top, -y / size.y)
			draw_line(Vector2(-w, y), Vector2(w, y), TIN_DARK, 3.0)
		draw_line(Vector2(-top * 0.55, -size.y + 8), Vector2(-top * 0.48, -6), TIN_LIGHT, 4.0)
		draw_rect(Rect2(-top - 3, -size.y - 2, size.x + 6, 7), TIN_DARK)
		# Ammaccatura.
		draw_arc(Vector2(top * 0.35, -size.y * 0.42), 9.0, PI * 0.6, PI * 1.5, 6, TIN_DARK, 2.0)
	else:
		# Rete: aste verticali che convergono verso il fondo e due fasce.
		for i in 7:
			var t := i / 6.0
			draw_line(Vector2(lerpf(-top, top, t), -size.y), Vector2(lerpf(-top, top, t) * 0.84, 0), WIRE, 2.0)
		for y in [-size.y, -size.y * 0.5, -2.0]:
			var w := lerpf(top * 0.84, top, -y / size.y)
			draw_line(Vector2(-w, y), Vector2(w, y), WIRE, 3.5)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_lid(size: Vector2, rng: RandomNumberGenerator) -> void:
	match lid:
		"on":
			# Pieno: il coperchio è appoggiato storto sopra il contenuto.
			var full := contents != "empty"
			var angle := rng.randf_range(0.12, 0.25) * (1.0 if rng.randf() < 0.5 else -1.0) if full else 0.0
			var lift := 16.0 if full else 0.0
			draw_set_transform(Vector2(0, -size.y - 4 - lift), angle)
			_draw_lid_shape(size)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		"off":
			_draw_lid_on_floor(size, size.x / 2.0 + 34.0)


## Coperchio a cupola con la maniglia; l'origine è il bordo inferiore al centro.
func _draw_lid_shape(size: Vector2) -> void:
	var w := size.x / 2.0 + 5.0
	var dome := PackedVector2Array([Vector2(-w, 0)])
	for i in 9:
		var angle := PI + PI * i / 8.0
		dome.append(Vector2(cos(angle) * w, sin(angle) * 12.0))
	dome.append(Vector2(w, 0))
	draw_colored_polygon(dome, TIN)
	draw_line(Vector2(-w, 0), Vector2(w, 0), TIN_DARK, 3.0)
	draw_arc(Vector2(0, -14), 8.0, PI, TAU, 8, TIN_DARK, 3.0)


func _draw_lid_on_floor(size: Vector2, x: float) -> void:
	# Coperchio caduto, capovolto e un po' inclinato.
	draw_set_transform(Vector2(x, -6), PI + 0.08)
	_draw_lid_shape(size)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Contenuto che sporge dal bordo del cestino dritto.
func _draw_peeking(rng: RandomNumberGenerator, size: Vector2) -> void:
	var rim := -size.y
	var half := size.x / 2.0 - 10.0
	if contents == "bulbs":
		for i in 4:
			var x := lerpf(-half, half, i / 3.0) + rng.randf_range(-5, 5)
			var tilt := rng.randf_range(-40, 40) + (180.0 if rng.randf() < 0.25 else 0.0)
			var xform := DeadBulb.grounded_transform(tilt, BULB_SCALE * rng.randf_range(0.9, 1.1), Vector2(x, rim + 24))
			DeadBulb.draw_bulb(self, xform, ["cracked", "off", "burnt", "shattered"][i], "x" if i % 2 == 0 else "none", rng.randi())
		return
	_draw_bag_corner(Vector2(-half * 0.4, rim + 6), 22.0, rng)
	for i in 3:
		var x := lerpf(-half, half, i / 2.0) + rng.randf_range(-6, 6)
		_draw_paper(Vector2(x, rim - rng.randf_range(2, 12)), rng.randf_range(11, 15), rng)
	if kind == "basket":
		# Nel cestino di rete il contenuto si vede anche attraverso.
		for i in 3:
			_draw_paper(Vector2(rng.randf_range(-half, half) * 0.7, rim + 26 + i * 16), rng.randf_range(10, 14), rng)


## Contenuto rovesciato a terra davanti all'apertura.
func _draw_spill(rng: RandomNumberGenerator, size: Vector2, side: float) -> void:
	var mouth := side * size.y / 2.0
	if contents == "bulbs":
		for i in 5:
			var x := mouth + side * (10.0 + i * 26.0 + rng.randf_range(-6, 6))
			var tilt := side * rng.randf_range(60, 120) + (180.0 if rng.randf() < 0.3 else 0.0)
			var xform := DeadBulb.grounded_transform(tilt, BULB_SCALE * rng.randf_range(0.9, 1.1), Vector2(x, 0))
			DeadBulb.draw_bulb(self, xform, ["shattered", "cracked", "off", "burnt", "cracked"][i], "x" if i % 2 == 1 else "none", rng.randi())
		return
	_draw_bag_corner(Vector2(mouth - side * 6.0, -14), 20.0, rng)
	for i in 4:
		var radius := rng.randf_range(10, 14)
		_draw_paper(Vector2(mouth + side * (14.0 + i * 24.0 + rng.randf_range(-5, 5)), -radius), radius, rng)
	var can := Vector2(mouth + side * 108.0, -8)
	draw_rect(Rect2(can - Vector2(14, 8), Vector2(28, 16)), CAN)
	draw_line(can + Vector2(-14, -8), can + Vector2(-14, 8), TIN_DARK, 3.0)


## Cartaccia appallottolata: poligono irregolare con qualche piega.
func _draw_paper(center: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	for i in 8:
		points.append(center + Vector2.from_angle(i * TAU / 8.0) * radius * rng.randf_range(0.7, 1.1))
	draw_colored_polygon(points, PAPER)
	for i in 2:
		var a := rng.randf() * TAU
		draw_line(center + Vector2.from_angle(a) * radius * 0.6, center + Vector2.from_angle(a + 2.2) * radius * 0.3, PAPER_DARK, 1.5)


## Angolo di un sacchetto di plastica nera con il nodo.
func _draw_bag_corner(center: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	for i in 10:
		points.append(center + Vector2.from_angle(i * TAU / 10.0) * radius * rng.randf_range(0.8, 1.05))
	draw_colored_polygon(points, PLASTIC)
	draw_line(center + Vector2(-radius * 0.4, -radius * 0.3), center + Vector2(radius * 0.1, -radius * 0.6), PLASTIC_SHINE, 2.5)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-3, -radius * 0.9), center + Vector2(-7, -radius - 10), center + Vector2(4, -radius - 7)
	]), PLASTIC)
