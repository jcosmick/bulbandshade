@tool
class_name WallCrack
extends Node2D
## Crepa nell'intonaco, solo decorativa. L'origine è il punto da cui parte:
## i rami si allargano verso `direction`.

## Lunghezza massima dei rami principali.
@export var size := 120.0:
	set(value):
		size = value
		queue_redraw()
@export_range(1, 6) var branches := 3:
	set(value):
		branches = value
		queue_redraw()
## Direzione principale in gradi (0 = destra, 90 = giù, -90 = su).
@export_range(-180.0, 180.0, 5.0) var direction := 90.0:
	set(value):
		direction = value
		queue_redraw()
## Apertura a ventaglio dei rami, in gradi.
@export_range(0.0, 360.0, 5.0) var spread := 70.0:
	set(value):
		spread = value
		queue_redraw()
## Cambialo per ottenere una crepa di forma diversa.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()

const CRACK := Color(0.2, 0.17, 0.23)
## Riflesso chiaro sotto la crepa, che la fa sembrare incisa nel muro.
const CRACK_EDGE := Color(0.46, 0.42, 0.5, 0.45)
const STEP := 14.0
const MAX_DEPTH := 2


func _ready() -> void:
	z_index = -9


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	for b in branches:
		var t := 0.5 if branches == 1 else float(b) / (branches - 1)
		var angle := deg_to_rad(direction + lerpf(-spread / 2.0, spread / 2.0, t) + rng.randf_range(-10.0, 10.0))
		_draw_branch(rng, Vector2.ZERO, angle, size * rng.randf_range(0.6, 1.0), 3.0, 0)


## Linea spezzata che si assottiglia; ogni tanto ne nasce un ramo laterale.
func _draw_branch(rng: RandomNumberGenerator, start: Vector2, base_angle: float, length: float, width: float, depth: int) -> void:
	var points := PackedVector2Array([start])
	var angle := base_angle
	var travelled := 0.0
	while travelled < length:
		angle = lerp_angle(angle + rng.randf_range(-0.45, 0.45), base_angle, 0.3)
		var step := minf(STEP * rng.randf_range(0.6, 1.3), length - travelled)
		travelled += step
		points.append(points[points.size() - 1] + Vector2.from_angle(angle) * step)
		if depth < MAX_DEPTH and rng.randf() < 0.18:
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			_draw_branch(rng, points[points.size() - 1], angle + side * rng.randf_range(0.5, 1.0),
					(length - travelled) * 0.6, width * 0.6, depth + 1)
	var relief := Vector2(1.5, 1.5)
	for i in points.size() - 1:
		var w := lerpf(width, 1.0, float(i) / points.size())
		draw_line(points[i] + relief, points[i + 1] + relief, CRACK_EDGE, maxf(w * 0.6, 1.0))
		draw_line(points[i], points[i + 1], CRACK, w)
