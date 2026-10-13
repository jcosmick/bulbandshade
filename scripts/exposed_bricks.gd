@tool
class_name ExposedBricks
extends Node2D
## Chiazza di muro senza intonaco con i mattoni a vista, solo decorativa.
## Centrata sul nodo; `size` è l'ingombro della chiazza.

@export var size := Vector2(220, 140):
	set(value):
		size = value
		queue_redraw()
## Cambialo per ottenere una chiazza di forma diversa.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()

const MORTAR := Color(0.25, 0.21, 0.24)
const BRICK := Color(0.33, 0.23, 0.23)
const BRICK_DARK := Color(0.27, 0.19, 0.2)
## Bordo dell'intonaco rotto, poco più chiaro della carta da parati.
const PLASTER_EDGE := Color(0.45, 0.41, 0.48)
const BRICK_SIZE := Vector2(52, 22)
const GAP := 4.0
const EDGE_POINTS := 22


func _ready() -> void:
	z_index = -9


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	var patch := PackedVector2Array()
	for i in EDGE_POINTS:
		var angle := TAU * i / EDGE_POINTS
		patch.append(Vector2(cos(angle) * size.x, sin(angle) * size.y) / 2.0 * rng.randf_range(0.72, 1.0))
	draw_colored_polygon(patch, MORTAR)
	var row := 0
	var y := -size.y / 2.0
	while y < size.y / 2.0:
		var x := -size.x / 2.0 - (BRICK_SIZE.x / 2.0 if row % 2 == 1 else 0.0)
		while x < size.x / 2.0:
			var brick := Rect2(x + GAP / 2.0, y + GAP / 2.0, BRICK_SIZE.x - GAP, BRICK_SIZE.y - GAP)
			var color := BRICK.lerp(BRICK_DARK, rng.randf())
			# Solo la parte di mattone che cade dentro la chiazza.
			for piece in Geometry2D.intersect_polygons(_rect_polygon(brick), patch):
				if not Geometry2D.triangulate_polygon(piece).is_empty():
					draw_colored_polygon(piece, color)
			x += BRICK_SIZE.x
		y += BRICK_SIZE.y
		row += 1
	draw_polyline(patch + PackedVector2Array([patch[0]]), PLASTER_EDGE, 3.0, true)


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)
	])
