@tool
class_name RailCrate
extends AnimatableBody2D
## Cassa appesa con una catena a un carrello a rulli che scorre su una rotaia
## sotto il soffitto. Ferma finché non viene attivata (es. da un FloorButton),
## poi scorre di "travel" px in orizzontale. Proietta ombre solide e blocca
## la luce delle finestre, come le altre casse.
## L'origine del nodo è il centro della cassa nella posizione di partenza.

@export var size := Vector2(220, 100):
	set(value):
		size = value
		queue_redraw()
## Lunghezza della catena tra il carrello e la cassa.
@export var chain_length := 70.0:
	set(value):
		chain_length = value
		queue_redraw()
## Spostamento orizzontale (px) dalla partenza all'arrivo.
@export var travel := -1000.0:
	set(value):
		travel = value
		queue_redraw()
## Estremi della rotaia (x rispetto alla partenza).
@export var rail_left := -1200.0:
	set(value):
		rail_left = value
		queue_redraw()
@export var rail_right := 250.0:
	set(value):
		rail_right = value
		queue_redraw()
## Lunghezza dei tiranti che appendono la rotaia al soffitto.
@export var hanger_length := 85.0:
	set(value):
		hanger_length = value
		queue_redraw()
## Velocità media (px/s) dello spostamento.
@export var speed := 320.0

const CHAIN_LINK := 18.0
const CHAIN_COLOR := Color(0.45, 0.45, 0.5)
const RAIL := Color(0.3, 0.3, 0.35)
const RAIL_LIGHT := Color(0.5, 0.5, 0.56)
const TROLLEY := Color(0.4, 0.42, 0.46)
const TROLLEY_DARK := Color(0.27, 0.28, 0.32)
const WHEEL := Color(0.62, 0.62, 0.66)
const RAIL_HEIGHT := 14.0
const WHEEL_RADIUS := 11.0
const TROLLEY_WIDTH := 64.0
## Il carrello scende sotto la rotaia di questi px (fino all'attacco della catena).
const TROLLEY_DROP := 20.0
const HANGER_STEP := 320.0

var _start := Vector2.ZERO
## 0 = partenza, 1 = arrivo.
var _progress := 0.0
var _moving := false
var _rail: Node2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("solids")
	add_to_group("casters")
	_start = position
	LevelKit.add_rect_collision(self, size, true)
	# La rotaia resta ferma mentre la cassa scorre: la disegna un nodo a parte,
	# dietro il carrello.
	_rail = Node2D.new()
	_rail.top_level = true
	_rail.show_behind_parent = true
	add_child(_rail)
	_rail.global_position = global_position
	_rail.draw.connect(_draw_rail.bind(_rail))


## Fa partire la cassa verso l'arrivo (una volta sola).
func activate() -> void:
	_moving = true


func get_world_polygon() -> PackedVector2Array:
	return global_transform * LevelKit.rect_points(size)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _moving:
		return
	_progress = move_toward(_progress, 1.0, delta * speed / maxf(absf(travel), 1.0))
	position.x = _start.x + travel * smoothstep(0.0, 1.0, _progress)
	if _progress >= 1.0:
		_moving = false
	queue_redraw()


## Altezza (y locale) del centro della rotaia.
func _rail_y() -> float:
	return -size.y / 2.0 - chain_length - TROLLEY_DROP - RAIL_HEIGHT / 2.0


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_rail(self)
		# Anteprima della posizione d'arrivo.
		var target := Rect2(Vector2(travel, 0) - size / 2.0, size)
		draw_rect(target, Color(LevelKit.WOOD, 0.5), false, 3.0)
	var top := -size.y / 2.0
	for i in int(chain_length / CHAIN_LINK):
		draw_rect(Rect2(-5.0, top - (i + 1) * CHAIN_LINK, 10.0, CHAIN_LINK - 3.0), CHAIN_COLOR, false, 3.0)
	_draw_trolley()
	LevelKit.draw_crate(self, size, false)


## Carrello: due rulli che poggiano sulla rotaia e due piastre che scendono
## fino al gancio della catena.
func _draw_trolley() -> void:
	var rail_y := _rail_y()
	var wheel_y := rail_y - RAIL_HEIGHT / 2.0 - WHEEL_RADIUS
	var bottom := rail_y + RAIL_HEIGHT / 2.0 + TROLLEY_DROP
	var half := TROLLEY_WIDTH / 2.0
	# Rotazione dei rulli in base alla strada fatta.
	var angle := (position.x - _start.x) / WHEEL_RADIUS if not Engine.is_editor_hint() else 0.0
	for x in [-half + WHEEL_RADIUS, half - WHEEL_RADIUS]:
		var center := Vector2(x, wheel_y)
		draw_circle(center, WHEEL_RADIUS, WHEEL)
		draw_arc(center, WHEEL_RADIUS, 0.0, TAU, 16, TROLLEY_DARK, 3.0)
		for k in 2:
			var spoke := Vector2.from_angle(angle + k * PI / 2.0) * (WHEEL_RADIUS - 3.0)
			draw_line(center - spoke, center + spoke, TROLLEY_DARK, 2.0)
	draw_rect(Rect2(-half, wheel_y, TROLLEY_WIDTH, bottom - wheel_y), TROLLEY)
	draw_rect(Rect2(-half, wheel_y, TROLLEY_WIDTH, bottom - wheel_y), TROLLEY_DARK, false, 3.0)
	for x in [-half + WHEEL_RADIUS, half - WHEEL_RADIUS]:
		draw_circle(Vector2(x, wheel_y), 3.5, TROLLEY_DARK)
	# Gancio della catena.
	draw_arc(Vector2(0, bottom + 4.0), 6.0, 0.0, PI, 8, CHAIN_COLOR, 3.0)


## Rotaia con i tiranti verso il soffitto e i fermi alle estremità.
func _draw_rail(canvas: CanvasItem) -> void:
	var y := _rail_y()
	var rect := Rect2(rail_left, y - RAIL_HEIGHT / 2.0, rail_right - rail_left, RAIL_HEIGHT)
	var x := rail_left + 40.0
	while x < rail_right:
		canvas.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y - hanger_length), RAIL, 6.0)
		x += HANGER_STEP
	canvas.draw_rect(rect, RAIL)
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), RAIL_LIGHT, 3.0)
	for end in [rect.position.x, rect.end.x]:
		canvas.draw_rect(Rect2(end - 6.0, y - 20.0, 12.0, 40.0), TROLLEY_DARK)
