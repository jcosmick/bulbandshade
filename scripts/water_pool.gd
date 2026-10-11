@tool
class_name WaterPool
extends Area2D
## Pozzanghera: se la lampadina la tocca va in cortocircuito.

@export var size := Vector2(300, 16):
	set(value):
		size = value
		queue_redraw()

const WATER := Color(0.2, 0.45, 0.9, 0.8)
const SURFACE := Color(0.6, 0.85, 1.0, 0.9)

var _visual: Node2D
var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	# Disegnata sopra il buio, così l'acqua si vede sempre.
	_visual = LevelKit.make_overlay(self, true, 2)
	_visual.draw.connect(_draw_water.bind(_visual))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_visual.queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.die()


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_water(self)


func _draw_water(canvas: CanvasItem) -> void:
	var rect := Rect2(-size / 2.0, size)
	canvas.draw_rect(rect, WATER)
	var wave := PackedVector2Array()
	var x := rect.position.x
	while x <= rect.end.x:
		wave.append(Vector2(x, rect.position.y + sin(x * 0.05 + _time * 3.0) * 2.0))
		x += 10.0
	canvas.draw_polyline(wave, SURFACE, 3.0)
