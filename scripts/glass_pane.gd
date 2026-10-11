@tool
class_name GlassPane
extends StaticBody2D
## Lastra di vetro: solida ma trasparente. Non fa ombra e la luce la attraversa.

@export var size := Vector2(200, 30):
	set(value):
		size = value
		queue_redraw()

const FILL := Color(0.6, 0.85, 1.0, 0.16)
const EDGE := Color(0.75, 0.92, 1.0, 0.75)
const SHINE := Color(1, 1, 1, 0.4)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("solids")
	add_to_group("transparent")
	LevelKit.add_rect_collision(self, size, false)


func get_world_polygon() -> PackedVector2Array:
	return global_transform * LevelKit.rect_points(size)


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, FILL)
	draw_rect(rect, EDGE, false, 3.0)
	# Riflesso lungo il lato più lungo.
	var inset := rect.grow(-7.0)
	if size.x >= size.y:
		draw_line(inset.position, Vector2(inset.position.x + inset.size.x * 0.4, inset.position.y), SHINE, 3.0)
	else:
		draw_line(inset.position, Vector2(inset.position.x, inset.position.y + inset.size.y * 0.4), SHINE, 3.0)
