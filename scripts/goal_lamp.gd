@tool
class_name GoalLamp
extends Area2D
## Il portalampada di arrivo. L'origine del nodo è il bordo superiore del
## portalampada; la base della lampada poggia 120 px più in basso.

signal reached

## Posizione (rispetto al nodo) del centro della lampadina avvitata.
const SOCKET_OFFSET := Vector2(0, -22)
const METAL := Color(0.3, 0.3, 0.34)
const BRASS := Color(0.72, 0.58, 0.3)
const BRASS_DARK := Color(0.45, 0.35, 0.16)

var _hint_light: PointLight2D
var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Basta toccare la lampada (dal portalampada alla base) per vincere.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(110, 180)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, 30)
	add_child(collision)
	_hint_light = LevelKit.make_light(self, 170.0, 0.5, false)
	_hint_light.position = Vector2(0, -20)
	body_entered.connect(_on_body_entered)


func socket_position() -> Vector2:
	return global_position + SOCKET_OFFSET


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_hint_light.energy = 0.45 + 0.2 * sin(_time * 2.5)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		reached.emit()


func _draw() -> void:
	draw_rect(Rect2(-48, 108, 96, 12), METAL)
	draw_circle(Vector2(-48, 114), 6.0, METAL)
	draw_circle(Vector2(48, 114), 6.0, METAL)
	draw_rect(Rect2(-6, 30, 12, 80), METAL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, 30), Vector2(30, 30), Vector2(18, 44), Vector2(-18, 44)
	]), METAL)
	draw_rect(Rect2(-27, 0, 54, 32), BRASS)
	draw_rect(Rect2(-20, 0, 40, 9), Color(0.08, 0.07, 0.06))
	for i in 2:
		draw_line(Vector2(-27, 15 + i * 9), Vector2(27, 15 + i * 9), BRASS_DARK, 3.0)
