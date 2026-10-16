@tool
class_name ZoomTrigger
extends Area2D
## Soglia direzionale dello zoom della telecamera. Quando la lampadina esce
## dall'area, la telecamera passa (con una transizione) allo zoom del lato da
## cui è uscita: zoom_before se è uscita dal lato "prima" (da dove si arriva,
## secondo direction), zoom_after se è uscita dal lato "dopo" (dove si va).
## All'ingresso non succede niente: entrare e uscire dallo stesso lato non
## cambia lo zoom.
## I valori sono moltiplicatori dello zoom base del Game (1.0 = zoom normale).

## Verso di attraversamento: "prima" è il lato da cui si arriva, "dopo" quello
## verso cui si va.
enum Direction {
	## Prima = sinistra, dopo = destra.
	LEFT_TO_RIGHT,
	## Prima = sopra, dopo = sotto.
	TOP_TO_BOTTOM,
	## Prima = destra, dopo = sinistra.
	RIGHT_TO_LEFT,
	## Prima = sotto, dopo = sopra.
	BOTTOM_TO_TOP,
}

## Dimensioni dell'area in pixel (centrata sul nodo).
@export var size := Vector2(200, 1520):
	set(value):
		size = value
		queue_redraw()
		update_configuration_warnings()
## Verso di attraversamento: decide quale lato è "prima" (da dove si arriva) e
## quale "dopo" (dove si va).
@export var direction := Direction.LEFT_TO_RIGHT
## Moltiplicatore dello zoom base uscendo dal lato "prima", cioè tornando
## indietro (1 = zoom normale, < 1 allontana, > 1 avvicina).
@export var zoom_before := 1.0:
	set(value):
		zoom_before = value
		update_configuration_warnings()
## Moltiplicatore dello zoom base uscendo dal lato "dopo", cioè proseguendo
## (1 = zoom normale, < 1 allontana, > 1 avvicina).
@export var zoom_after := 1.0:
	set(value):
		zoom_after = value
		update_configuration_warnings()
## Durata della transizione in secondi (0 = cambio istantaneo).
@export_range(0.0, 5.0, 0.05, "or_greater") var duration := 0.8
## Curva della transizione (vedi Tween.TransitionType): sine è morbida,
## linear costante, le altre più marcate.
@export var transition: Tween.TransitionType = Tween.TRANS_SINE
## Dove la curva accelera: in = parte piano, out = arriva piano, in-out =
## piano a tutti e due i capi (vedi Tween.EaseType).
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT

const EDITOR_COLOR := Color(0.4, 0.8, 1.0, 0.8)
## Viewport di riferimento del progetto, su cui si stimano i warning in editor.
const REFERENCE_VIEW := Vector2(1080, 1920)
const Game := preload("res://scripts/game.gd")


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
	var after: bool
	match direction:
		Direction.LEFT_TO_RIGHT: after = offset.x > 0.0
		Direction.RIGHT_TO_LEFT: after = offset.x < 0.0
		Direction.TOP_TO_BOTTOM: after = offset.y > 0.0
		Direction.BOTTOM_TO_TOP: after = offset.y < 0.0
	game.request_zoom(zoom_after if after else zoom_before, duration, transition, easing)


## Warning in editor (triangolo giallo nell'albero della scena), stimati sulla
## viewport di riferimento meno la striscia dei comandi. Senza un Level
## antenato non si controlla niente.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var level := _level()
	if level == null:
		return warnings
	var rect: Rect2 = level.level_rect
	var area := REFERENCE_VIEW - Vector2(0, Game.CONTROLS_HEIGHT)
	if not Game.scrolls(area, rect):
		warnings.append("Il livello è fisso (sta tutto nello schermo, la telecamera non scorre): qui lo Zoom trigger non fa niente.")
		return warnings
	var base := Game.base_zoom(area, rect)
	for side: Array in [["zoom_before", zoom_before], ["zoom_after", zoom_after]]:
		var multiplier: float = side[1]
		if multiplier <= 0.0:
			continue
		var view := area / (base * multiplier)
		if view.x > rect.size.x + 1.0 or view.y > rect.size.y + 1.0:
			warnings.append("%s = %s fa vedere oltre level_rect: la vista sopra i comandi è circa %d x %d, il livello %d x %d (viewport 1080x1920). A runtime la telecamera si centra sul livello e ai lati resta il nero." % [
					side[0], multiplier, roundi(view.x), roundi(view.y), roundi(rect.size.x), roundi(rect.size.y)])
	return warnings


## Il Level che contiene il trigger, o null.
func _level() -> Level:
	var node := get_parent()
	while node and not node is Level:
		node = node.get_parent()
	return node


## Il Game che possiede la telecamera (risalendo dal livello).
func _game() -> Node:
	var node := get_parent()
	while node and not node.has_method("request_zoom"):
		node = node.get_parent()
	return node


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# Solo il bordo dell'area: i valori si leggono nell'Inspector.
	draw_rect(Rect2(-size / 2.0, size), EDITOR_COLOR, false, 4.0)
