@tool
class_name Checkpoint
extends Area2D
## Punto di ripartenza: dopo un cortocircuito si ricomincia dall'ultimo
## checkpoint toccato. L'origine del nodo va sul pavimento.

signal reached(checkpoint: Checkpoint)

const POLE := Color(0.32, 0.32, 0.36)
const OFF := Color(0.3, 0.28, 0.25)
const ON := Color(1.0, 0.85, 0.45)

var active := false:
	set(value):
		active = value
		if _light:
			_light.energy = 0.7 if active else 0.0
		queue_redraw()
var _light: PointLight2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("checkpoints")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 140)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -70)
	add_child(collision)
	_light = LevelKit.make_light(self, 140.0, 0.0, false)
	_light.position = Vector2(0, -70)
	body_entered.connect(_on_body_entered)


## Dove ricompare la lampadina.
func spawn_position() -> Vector2:
	return global_position + Vector2(0, -52)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not active:
		reached.emit(self)


func _draw() -> void:
	draw_rect(Rect2(-18, -6, 36, 6), POLE)
	draw_rect(Rect2(-3, -60, 6, 56), POLE)
	draw_circle(Vector2(0, -70), 12.0, ON if active else OFF)
	draw_arc(Vector2(0, -70), 12.0, 0.0, TAU, 20, POLE, 3.0)
