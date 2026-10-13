@tool
class_name WallOutlet
extends Node2D
## Interruttore o presa a muro, solo decorativi: niente collisioni né
## ombre. Centrati sul nodo.

@export_enum("switch", "socket", "double_socket") var kind := "switch":
	set(value):
		kind = value
		queue_redraw()

const PLATE := Color(0.44, 0.42, 0.4)
const PLATE_DARK := Color(0.33, 0.31, 0.3)
const ROCKER_TOP := Color(0.39, 0.37, 0.36)
const HOLE := Color(0.14, 0.13, 0.15)
const SOCKET_SIZE := 44.0


func _ready() -> void:
	z_index = -8


func _draw() -> void:
	match kind:
		"switch":
			draw_rect(Rect2(-18, -26, 36, 52), PLATE)
			draw_rect(Rect2(-8, -14, 16, 28), PLATE_DARK)
			draw_rect(Rect2(-8, -14, 16, 12), ROCKER_TOP)
			for y in [-21.0, 21.0]:
				draw_circle(Vector2(0, y), 2.0, PLATE_DARK)
		"socket":
			_draw_sockets(1)
		"double_socket":
			_draw_sockets(2)


## Placca con `count` prese italiane affiancate (tre fori in fila).
func _draw_sockets(count: int) -> void:
	var w := SOCKET_SIZE * count
	draw_rect(Rect2(-w / 2.0, -SOCKET_SIZE / 2.0, w, SOCKET_SIZE), PLATE)
	for k in count:
		var center := Vector2(-w / 2.0 + SOCKET_SIZE * (k + 0.5), 0)
		draw_circle(center, 14.0, PLATE_DARK)
		for dx in [-6.0, 0.0, 6.0]:
			draw_circle(center + Vector2(dx, 0), 2.2, HOLE)
