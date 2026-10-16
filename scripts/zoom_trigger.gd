@tool
class_name ZoomTrigger
extends Area2D
## Soglia direzionale dello zoom della telecamera. Quando la lampadina esce
## dall'area, la telecamera passa (con una transizione) allo zoom del lato da
## cui è uscita: zoom_before se è uscita prima (a sinistra o sopra, secondo
## l'asse), zoom_after se è uscita dopo (a destra o sotto). All'ingresso non
## succede niente: entrare e uscire dallo stesso lato non cambia lo zoom.
## I valori sono moltiplicatori dello zoom base del Game (1.0 = zoom normale).

enum Axis { HORIZONTAL, VERTICAL }

## Dimensioni dell'area in pixel (centrata sul nodo).
@export var size := Vector2(200, 1520):
	set(value):
		size = value
		queue_redraw()
## Orizzontale: prima = sinistra, dopo = destra. Verticale: prima = sopra, dopo = sotto.
@export var axis := Axis.HORIZONTAL:
	set(value):
		axis = value
		queue_redraw()
## Moltiplicatore dello zoom base uscendo dal lato "prima" (< 1 allontana, > 1 avvicina).
@export var zoom_before := 1.0:
	set(value):
		zoom_before = value
		queue_redraw()
## Moltiplicatore dello zoom base uscendo dal lato "dopo".
@export var zoom_after := 1.0:
	set(value):
		zoom_after = value
		queue_redraw()
## Durata della transizione in secondi (0 = cambio istantaneo).
@export_range(0.0, 5.0, 0.05, "or_greater") var duration := 0.8
## Curva della transizione (vedi Tween.TransitionType) e il suo easing.
@export var transition: Tween.TransitionType = Tween.TRANS_SINE
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT

const EDITOR_COLOR := Color(0.4, 0.8, 1.0, 0.8)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("zoom_triggers")
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_exited.connect(_on_body_exited)


func _on_body_exited(body: Node2D) -> void:
	if not body is Player:
		return
	var game := _game()
	if game == null:
		return
	var offset := body.global_position - global_position
	var after := (offset.x if axis == Axis.HORIZONTAL else offset.y) > 0.0
	game.request_zoom(zoom_after if after else zoom_before, duration, transition, easing)


## Il Game che possiede la telecamera (risalendo dal livello).
func _game() -> Node:
	var node := get_parent()
	while node and not node.has_method("request_zoom"):
		node = node.get_parent()
	return node


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-size / 2.0, size), EDITOR_COLOR, false, 4.0)
	var sides := "← %s   %s →" if axis == Axis.HORIZONTAL else "↑ %s   %s ↓"
	draw_string(ThemeDB.fallback_font, -size / 2.0 + Vector2(8, 26),
		"zoom " + sides % [zoom_before, zoom_after], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, EDITOR_COLOR)
