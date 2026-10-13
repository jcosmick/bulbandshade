@tool
class_name Vent
extends Node2D
## Bocchetta d'aerazione a lamelle, solo decorativa: niente collisioni né
## ombre. Centrata sul nodo.

@export var size := Vector2(140, 70):
	set(value):
		size = value
		queue_redraw()
## Distanza tra una lamella e l'altra.
@export var slat_spacing := 12.0:
	set(value):
		slat_spacing = maxf(value, 4.0)
		queue_redraw()

const FRAME := Color(0.24, 0.24, 0.28)
const FRAME_DARK := Color(0.18, 0.18, 0.21)
const HOLE := Color(0.11, 0.1, 0.13)
const SLAT := Color(0.29, 0.29, 0.34)
const BORDER := 8.0


func _ready() -> void:
	z_index = -8


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, FRAME)
	var inner := rect.grow(-BORDER)
	draw_rect(inner, HOLE)
	var y := inner.position.y + slat_spacing / 2.0
	while y < inner.end.y:
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), SLAT, 5.0)
		y += slat_spacing
	# Viti negli angoli della cornice.
	var bolt := size / 2.0 - Vector2(4, 4)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		draw_circle(corner * bolt, 2.5, FRAME_DARK)
