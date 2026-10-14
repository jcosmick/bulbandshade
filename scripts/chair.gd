@tool
class_name Chair
extends Node2D
## Sedia di legno verniciato, solo decorativa: niente collisioni né ombre.
## Può stare dritta o rovesciata; resta comunque appoggiata a terra.
## L'origine è il punto d'appoggio: va a y = pavimento.

@export_enum("standing", "fallen_back", "fallen_front", "on_side") var pose := "fallen_back":
	set(value):
		pose = value
		queue_redraw()
## Schienale a destra invece che a sinistra.
@export var flip := false:
	set(value):
		flip = value
		queue_redraw()
## Una gamba spezzata.
@export var broken_leg := false:
	set(value):
		broken_leg = value
		queue_redraw()

const PAINT := Color(0.3, 0.25, 0.22)
const PAINT_DARK := Color(0.2, 0.16, 0.14)
const CHIPPED := Color(0.42, 0.33, 0.25)
const SEAT_HEIGHT := 56.0
const SEAT_WIDTH := 56.0
const BACK_HEIGHT := 64.0
const LEG := 6.0
## Angolo di ogni posa (in gradi, prima del flip).
const ANGLES := {"standing": 0.0, "fallen_back": -90.0, "fallen_front": 90.0, "on_side": 0.0}


func _ready() -> void:
	z_index = -5


func _draw() -> void:
	var angle := deg_to_rad(ANGLES[pose])
	var mirror := -1.0 if flip else 1.0
	if pose == "standing" and broken_leg:
		# In piedi con la gamba corta: si inclina in avanti sul moncone.
		angle = atan2(SEAT_HEIGHT * 0.45, SEAT_WIDTH - LEG / 2.0)
	var xform := Transform2D(angle * mirror, Vector2(mirror, 1.0), 0.0, Vector2.ZERO)
	if pose == "on_side":
		# Sul fianco: si vede da sotto, schiacciata e un po' inclinata.
		xform = Transform2D(deg_to_rad(8.0) * mirror, Vector2(mirror, 0.55), 0.0, Vector2.ZERO)
	var lowest := -INF
	for point in _outline():
		lowest = maxf(lowest, (xform * point).y)
	xform.origin = Vector2(0, -lowest)
	draw_set_transform_matrix(xform)
	_draw_chair()
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Estremi della sedia dritta, per appoggiarla a terra in ogni posa.
func _outline() -> Array[Vector2]:
	var h := SEAT_WIDTH / 2.0
	var front := -SEAT_HEIGHT * (0.45 if broken_leg else 0.0)
	return [Vector2(-h, 0), Vector2(h, front), Vector2(-h, -SEAT_HEIGHT - BACK_HEIGHT),
			Vector2(-h + LEG, -SEAT_HEIGHT - BACK_HEIGHT), Vector2(h, -SEAT_HEIGHT - 6)]


## Sedia dritta vista di lato, schienale a sinistra; l'origine è tra le gambe a terra.
func _draw_chair() -> void:
	var h := SEAT_WIDTH / 2.0
	# Gamba posteriore che prosegue nello schienale, gamba anteriore.
	draw_rect(Rect2(-h, -SEAT_HEIGHT - BACK_HEIGHT, LEG, SEAT_HEIGHT + BACK_HEIGHT), PAINT)
	var front_length := SEAT_HEIGHT * (0.55 if broken_leg else 1.0)
	draw_rect(Rect2(h - LEG, -SEAT_HEIGHT, LEG, front_length), PAINT)
	if broken_leg:
		# Moncone scheggiato.
		var end := Vector2(h - LEG, -SEAT_HEIGHT + front_length)
		draw_colored_polygon(PackedVector2Array([
			end, end + Vector2(LEG, 0), end + Vector2(LEG * 0.7, 7), end + Vector2(LEG * 0.3, 2),
		]), CHIPPED)
	# Seduta, traversa tra le gambe e pomello in cima allo schienale.
	draw_rect(Rect2(-h, -SEAT_HEIGHT - 6, SEAT_WIDTH, 8), PAINT)
	draw_line(Vector2(-h, -SEAT_HEIGHT + 2), Vector2(h, -SEAT_HEIGHT + 2), PAINT_DARK, 2.0)
	draw_rect(Rect2(-h + LEG, -SEAT_HEIGHT * 0.4, SEAT_WIDTH - LEG * 2.0, 4), PAINT_DARK)
	draw_rect(Rect2(-h - 1, -SEAT_HEIGHT - BACK_HEIGHT - 4, LEG + 2, 6), PAINT_DARK)
	# Vernice scrostata.
	draw_rect(Rect2(-h + 1, -SEAT_HEIGHT - BACK_HEIGHT + 10, 3, 9), CHIPPED)
	draw_rect(Rect2(h - 18, -SEAT_HEIGHT - 6, 10, 3), CHIPPED)
