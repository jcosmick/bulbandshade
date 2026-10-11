@tool
class_name FloorButton
extends Area2D
## Pulsante a pavimento: quando la lampadina ci sale sopra si abbassa e
## attiva il nodo "target" (chiama il suo activate()). Resta premuto.
## L'origine del nodo va sul pavimento.

signal pressed

## Nodo da attivare (deve avere un metodo activate()).
@export var target: NodePath

const BASE := Color(0.32, 0.32, 0.36)
const BASE_LIGHT := Color(0.5, 0.5, 0.56)
const CAP := Color(0.85, 0.22, 0.18)
const CAP_DARK := Color(0.5, 0.12, 0.1)
const LAMP_OFF := Color(0.3, 0.28, 0.25)
const LAMP_ON := Color(0.45, 1.0, 0.5)
const WIDTH := 90.0

var is_pressed := false
var _light: PointLight2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WIDTH - 20.0, 30)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -15)
	add_child(collision)
	# Una lucina rossa che si vede anche al buio, verde quando premuto.
	_light = LevelKit.make_light(self, 120.0, 0.6, false)
	_light.color = CAP
	_light.position = Vector2(0, -20)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_pressed or not body is Player:
		return
	is_pressed = true
	_light.color = LAMP_ON
	Sfx.play("button", -2.0)
	var node := get_node_or_null(target)
	if node and node.has_method("activate"):
		node.activate()
	pressed.emit()
	queue_redraw()


func _draw() -> void:
	var half := WIDTH / 2.0
	var cap_height := 6.0 if is_pressed else 18.0
	draw_rect(Rect2(-half + 14.0, -8.0 - cap_height, WIDTH - 28.0, cap_height), CAP)
	draw_rect(Rect2(-half + 14.0, -8.0 - cap_height, WIDTH - 28.0, 4.0), CAP.lightened(0.3))
	draw_rect(Rect2(-half + 14.0, -8.0 - cap_height, WIDTH - 28.0, cap_height), CAP_DARK, false, 2.0)
	draw_rect(Rect2(-half, -8.0, WIDTH, 8.0), BASE)
	draw_line(Vector2(-half, -8.0), Vector2(half, -8.0), BASE_LIGHT, 2.0)
	# Spia accanto al pulsante.
	draw_rect(Rect2(half + 6.0, -36.0, 6.0, 36.0), BASE)
	draw_circle(Vector2(half + 9.0, -44.0), 8.0, LAMP_ON if is_pressed else LAMP_OFF)
	draw_arc(Vector2(half + 9.0, -44.0), 8.0, 0.0, TAU, 16, BASE, 2.0)
