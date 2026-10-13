@tool
class_name Barrel
extends Node2D
## Barile di legno, solo decorativo: niente collisioni né ombre. Disegno
## piatto come le casse ma molto più scuro, perché resta sullo sfondo e non
## si confonde con gli oggetti che proiettano ombre solide. Centrato sul nodo
## come i blocchi.

## Dimensioni in pixel (da in piedi; se lying è attivo larghezza e altezza
## si scambiano).
@export var size := Vector2(90, 120):
	set(value):
		size = value
		queue_redraw()
## Barile sdraiato su un fianco.
@export var lying := false:
	set(value):
		lying = value
		queue_redraw()

const BODY := Color(0.29, 0.22, 0.2)
const BODY_DARK := Color(0.21, 0.16, 0.15)
const HOOP := Color(0.23, 0.23, 0.27)
const HOOP_WIDTH := 8.0


func _ready() -> void:
	z_index = -5


func _draw() -> void:
	if lying:
		draw_set_transform(Vector2.ZERO, PI / 2.0)
	var half := size / 2.0
	draw_rect(Rect2(-half, size), BODY)
	# Doghe.
	for x in [-size.x / 6.0, size.x / 6.0]:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), BODY_DARK, 3.0)
	# Cerchi di ferro.
	for t in [0.22, 0.78]:
		var y := lerpf(-half.y, half.y, t)
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), HOOP, HOOP_WIDTH)
	draw_set_transform(Vector2.ZERO)
