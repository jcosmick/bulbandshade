@tool
class_name DeadBulb
extends Node2D
## Lampadina spenta e rotta, grande come la protagonista: solo decorativa,
## niente collisioni né ombre. L'origine è il punto d'appoggio: va a
## y = pavimento. Con `tilt` si inclina e resta comunque appoggiata a terra.
## Il disegno (draw_bulb) lo usano anche il cestino e il mucchio di lampadine.

@export_enum("off", "cracked", "shattered", "burnt") var state := "cracked":
	set(value):
		state = value
		queue_redraw()
@export_enum("x", "closed", "none") var eyes := "x":
	set(value):
		eyes = value
		queue_redraw()
## Inclinazione in gradi (90 = sdraiata sul fianco destro, 180 = capovolta).
@export_range(-180.0, 180.0, 1.0) var tilt := 0.0:
	set(value):
		tilt = value
		queue_redraw()
## Cambialo per crepe e schegge di forma diversa.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()
## Cocci di vetro sparsi a terra (soprattutto per "shattered").
@export var shards_on_floor := true:
	set(value):
		shards_on_floor = value
		queue_redraw()

const GLASS := Color(0.42, 0.44, 0.49)
const GLASS_EDGE := Color(0.56, 0.6, 0.66)
const SOOT := Color(0.1, 0.09, 0.08, 0.75)
const FILAMENT := Color(0.32, 0.24, 0.18)
const METAL := Color(0.45, 0.45, 0.48)
const METAL_DARK := Color(0.3, 0.3, 0.33)
const RUST := Color(0.38, 0.24, 0.16)
const CONTACT := Color(0.2, 0.2, 0.22)
const CRACK := Color(0.2, 0.21, 0.25)
const EYE := Color(0.13, 0.11, 0.1)
## Geometria della protagonista (vedi player.gd), relativa ai piedi.
const GLASS_CENTER := Vector2(0, -68)
const GLASS_RADIUS := 38.0
## Punti esterni usati per appoggiarla a terra quando è inclinata.
const OUTLINE := [Vector2(-17, -8), Vector2(17, -8), Vector2(-9, 0), Vector2(9, 0)]


func _ready() -> void:
	z_index = -4


func _draw() -> void:
	draw_bulb(self, grounded_transform(tilt, 1.0), state, eyes, pattern)
	if shards_on_floor and state != "off":
		_draw_floor_shards()


## Trasformazione che inclina la lampadina di `degrees` attorno ai piedi e la
## alza quanto serve perché il punto più basso tocchi y = 0.
static func grounded_transform(degrees: float, scale_factor: float, at := Vector2.ZERO) -> Transform2D:
	var xform := Transform2D(deg_to_rad(degrees), Vector2.ONE * scale_factor, 0.0, Vector2.ZERO)
	var lowest := (xform * GLASS_CENTER).y + GLASS_RADIUS * scale_factor
	for point in OUTLINE:
		lowest = maxf(lowest, (xform * point).y)
	xform.origin = at - Vector2(0, lowest)
	return xform


## Disegna una lampadina spenta su `item` con la trasformazione data
## (coordinate dei piedi, come in player.gd). Lascia la trasformazione azzerata.
static func draw_bulb(item: CanvasItem, xform: Transform2D, state_name: String, eyes_style: String, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	item.draw_set_transform_matrix(xform)
	var neck := PackedVector2Array([
		Vector2(-27, -46), Vector2(27, -46), Vector2(17, -32), Vector2(-17, -32)
	])
	if state_name == "shattered":
		_draw_broken_glass(item, rng)
		item.draw_colored_polygon(neck, GLASS)
	else:
		item.draw_circle(GLASS_CENTER, GLASS_RADIUS, GLASS)
		item.draw_colored_polygon(neck, GLASS)
	_draw_filament(item, rng, state_name)
	if state_name == "burnt":
		# Fuliggine dentro il vetro, più densa in cima.
		item.draw_circle(GLASS_CENTER + Vector2(0, -6), 28.0, SOOT)
		item.draw_circle(GLASS_CENTER + Vector2(rng.randf_range(-6, 6), -14), 18.0, Color(SOOT, 0.5))
	# Attacco: lo stesso della protagonista, un po' arrugginito.
	item.draw_rect(Rect2(-17, -34, 34, 26), METAL)
	for i in 3:
		item.draw_line(Vector2(-17, -30 + i * 8), Vector2(17, -27 + i * 8), METAL_DARK, 3.0)
	item.draw_circle(Vector2(rng.randf_range(-12, 12), rng.randf_range(-28, -14)), rng.randf_range(3, 6), RUST)
	item.draw_rect(Rect2(-9, -8, 18, 8), CONTACT)
	if state_name != "shattered":
		if state_name == "cracked":
			_draw_cracks(item, rng)
		_draw_eyes(item, eyes_style)
		var shine := 0.12 if state_name == "burnt" else 0.3
		item.draw_arc(GLASS_CENTER, 29.0, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, shine), 4.0)
	item.draw_set_transform_matrix(Transform2D.IDENTITY)


## Intera e "off": filamento integro ma spento. Le altre: spezzato in due.
static func _draw_filament(item: CanvasItem, rng: RandomNumberGenerator, state_name: String) -> void:
	if state_name == "off":
		item.draw_polyline(PackedVector2Array([
			Vector2(-9, -34), Vector2(-9, -56), Vector2(-5, -63), Vector2(0, -56),
			Vector2(5, -63), Vector2(9, -56), Vector2(9, -34)
		]), FILAMENT, 3.0)
		return
	var droop := rng.randf_range(4, 10)
	item.draw_polyline(PackedVector2Array([
		Vector2(-9, -34), Vector2(-9, -56), Vector2(-5, -63), Vector2(-2, -58 + droop)
	]), FILAMENT, 3.0)
	item.draw_polyline(PackedVector2Array([
		Vector2(9, -34), Vector2(9, -56), Vector2(6, -60 + droop * 0.5), Vector2(3, -52 + droop)
	]), FILAMENT, 3.0)


## Vetro sfondato: resta solo la parte bassa, con il bordo frastagliato.
static func _draw_broken_glass(item: CanvasItem, rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	var start := rng.randf_range(-0.35, 0.1)
	var end := PI - rng.randf_range(-0.35, 0.1)
	for i in 13:
		var angle := lerpf(start, end, i / 12.0)
		points.append(GLASS_CENTER + Vector2.from_angle(angle) * GLASS_RADIUS)
	# Bordo rotto: da sinistra torna a destra con punte di altezza casuale.
	var left := points[points.size() - 1]
	var right := points[0]
	var teeth := 6
	for i in range(1, teeth):
		var x := lerpf(left.x, right.x, float(i) / teeth)
		var base_y := lerpf(left.y, right.y, float(i) / teeth)
		var y := base_y - (rng.randf_range(10, 34) if i % 2 == 1 else rng.randf_range(-4, 8))
		points.append(Vector2(x, y))
	item.draw_colored_polygon(points, GLASS)
	points.append(points[0])
	item.draw_polyline(points.slice(points.size() - teeth - 1), GLASS_EDGE, 2.0)


static func _draw_cracks(item: CanvasItem, rng: RandomNumberGenerator) -> void:
	var impact := GLASS_CENTER + Vector2(rng.randf_range(-16, 16), rng.randf_range(-22, 4))
	for b in rng.randi_range(3, 5):
		var angle := rng.randf() * TAU
		var point := impact
		var line := PackedVector2Array([point])
		for s in rng.randi_range(2, 4):
			angle += rng.randf_range(-0.5, 0.5)
			point += Vector2.from_angle(angle) * rng.randf_range(6, 12)
			if point.distance_to(GLASS_CENTER) > GLASS_RADIUS - 3.0:
				break
			line.append(point)
		if line.size() > 1:
			item.draw_polyline(line, CRACK, 1.8)
	# Un pezzetto mancante vicino al punto d'impatto.
	var chip := impact + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
	item.draw_colored_polygon(PackedVector2Array([
		chip, chip + Vector2(7, 3), chip + Vector2(2, 8)
	]), CRACK)


static func _draw_eyes(item: CanvasItem, style: String) -> void:
	for side in [-1.0, 1.0]:
		var center := Vector2(11.0 * side, -80)
		match style:
			"x":
				item.draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), EYE, 2.5)
				item.draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), EYE, 2.5)
			"closed":
				item.draw_arc(center + Vector2(0, -3), 5.0, PI * 0.15, PI * 0.85, 6, EYE, 2.5)


func _draw_floor_shards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern * 31 + 7
	var count := 6 if state == "shattered" else 2
	for i in count:
		var x := rng.randf_range(-70, 70)
		var size := rng.randf_range(4, 9)
		var angle := rng.randf() * TAU
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, -1) + Vector2.from_angle(angle) * size,
			Vector2(x, -1) + Vector2.from_angle(angle + 2.3) * size * 0.6,
			Vector2(x, -1) + Vector2.from_angle(angle + 3.8) * size * 0.8,
		]), GLASS_EDGE)
