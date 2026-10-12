@tool
class_name FlashHint
extends Area2D
## Zona di suggerimento (tutorial): mentre la lampadina è qui dentro, con il
## flash carico, il pulsante del flash pulsa. Smette appena fa un flash; se
## esce e rientra (es. dopo essere caduta in acqua) ricomincia.

@export var size := Vector2(240, 180):
	set(value):
		size = value
		queue_redraw()

const EDITOR_COLOR := Color(1.0, 0.85, 0.3, 0.25)

## True finché il pulsante del flash deve pulsare.
var active := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("flash_hints")
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(func(body: Node2D) -> void:
		if body is Player:
			active = true)
	body_exited.connect(func(body: Node2D) -> void:
		if body is Player:
			active = false)
	var player := get_parent().get_node_or_null("Player") as Player
	if player:
		player.flashed.connect(func(_origin: Vector2, _radius: float) -> void: active = false)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-size / 2.0, size), EDITOR_COLOR)
		draw_string(ThemeDB.fallback_font, -size / 2.0 + Vector2(8, 26), "flash hint",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(EDITOR_COLOR, 0.9))
