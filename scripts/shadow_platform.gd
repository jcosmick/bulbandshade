class_name ShadowPlatform
extends Node2D
## Disegno di un'ombra solida: appare, si schiarisce, lampeggia e sparisce
## insieme al suo corpo fisico.

const FILL := Color(0.0, 0.0, 0.01, 0.94)
const APPEAR_TIME := 0.08
## Negli ultimi secondi l'ombra lampeggia per avvisare che sta sparendo.
const WARNING_TIME := 1.0

var polygon: PackedVector2Array
var bounds: Rect2
var lifetime := 4.0
var age := 0.0
var _body: Node


func setup(shape: PackedVector2Array, life: float, body: Node, start_age := 0.0) -> void:
	polygon = shape
	bounds = Rect2(shape[0], Vector2.ZERO)
	for v in shape:
		bounds = bounds.expand(v)
	lifetime = life
	age = start_age
	_body = body


## Rimuove l'ombra e il suo corpo fisico.
func dispose() -> void:
	if is_instance_valid(_body):
		_body.queue_free()
	queue_free()


func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		dispose()
		return
	queue_redraw()


func _draw() -> void:
	var remaining := lifetime - age
	var alpha := clampf(age / APPEAR_TIME, 0.0, 1.0)
	if remaining < WARNING_TIME:
		alpha *= lerpf(0.25, 1.0, remaining / WARNING_TIME) * (0.55 + 0.45 * absf(cos(remaining * 10.0)))
	draw_colored_polygon(polygon, Color(FILL, FILL.a * alpha))
