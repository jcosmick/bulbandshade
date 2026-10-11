@tool
extends Node2D
## Parete di fondo della stanza (solo decorazione, nessuna collisione).

@export var rect := Rect2(0, 0, 1080, 1520):
	set(value):
		rect = value
		queue_redraw()
## Altezza (y) della zoccolatura in legno.
@export var wainscot_y := 1200.0:
	set(value):
		wainscot_y = value
		queue_redraw()

const WALL := Color(0.38, 0.34, 0.42)
const STRIPE := Color(0.34, 0.30, 0.38)
const PANEL := Color(0.30, 0.25, 0.27)
const MOLDING := Color(0.44, 0.37, 0.36)
const STRIPE_STEP := 90.0


func _ready() -> void:
	z_index = -10


func _draw() -> void:
	draw_rect(rect, WALL)
	var x := rect.position.x
	while x < rect.end.x:
		draw_rect(Rect2(x, rect.position.y, STRIPE_STEP / 2.0, wainscot_y - rect.position.y), STRIPE)
		x += STRIPE_STEP
	draw_rect(Rect2(rect.position.x, wainscot_y, rect.size.x, rect.end.y - wainscot_y), PANEL)
	draw_rect(Rect2(rect.position.x, wainscot_y - 6.0, rect.size.x, 12.0), MOLDING)
