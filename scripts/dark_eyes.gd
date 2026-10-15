@tool
class_name DarkEyes
extends Node2D
## Occhi nel buio: una o più coppie di occhietti che brillano dove la luce non
## arriva, sbattono le palpebre e guardano la lampadina. Quando la lampadina
## si avvicina o fa un flash si chiudono di colpo e spariscono, per poi
## riaprirsi quando si è allontanata. Solo decorativi. L'origine è il centro
## della zona in cui stanno gli occhi.

@export_range(1, 4) var pairs := 1:
	set(value):
		pairs = value
		queue_redraw()
## Grandezza degli occhi: "small" da topo, "big" da qualcosa di più grosso.
@export_enum("small", "big") var size := "small":
	set(value):
		size = value
		queue_redraw()
## Area in cui sono sparse le coppie (se più di una).
@export var spread := Vector2(160, 60):
	set(value):
		spread = value
		queue_redraw()
@export var color := Color(1.0, 0.85, 0.35):
	set(value):
		color = value
		queue_redraw()
## Distanza dalla lampadina sotto cui gli occhi si chiudono (la sua luce
## arriva a circa 300 px).
@export var shy_distance := 380.0
## Se vero la lampadina non interagisce con questo oggetto.
@export var disable_interaction := false
## Cambialo per disporre diversamente le coppie.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()

const EYE_SIZES := {"small": Vector2(5, 3.5), "big": Vector2(11, 6.5)}
const GAPS := {"small": 13.0, "big": 30.0}
## Secondi chiusi prima di poter riaprirsi, dopo essersi spaventati.
const HIDE_TIME := 2.5
const CLOSE_SPEED := 14.0
const OPEN_SPEED := 2.5
const BLINK_MIN := 2.0
const BLINK_MAX := 6.0
const BLINK_DURATION := 0.16
## Quanto si spostano le pupille verso la lampadina (frazione dell'occhio).
const LOOK := 0.35

var _visual: Node2D
var _player: Player
## Per ogni coppia: posizione, apertura (0..1), attesa del prossimo
## ammiccamento e tempo che manca prima di potersi riaprire.
var _eyes: Array[Dictionary] = []


func _ready() -> void:
	z_index = -4
	if Engine.is_editor_hint():
		return
	_visual = LevelKit.make_overlay(self)
	_visual.draw.connect(func() -> void: _draw_eyes(_visual))
	if not disable_interaction:
		_player = LevelKit.find_player(self)
	if _player:
		_player.flashed.connect(_on_flashed)
	for offset in _offsets():
		_eyes.append({"pos": offset, "open": 0.0, "blink": randf_range(BLINK_MIN, BLINK_MAX), "hide": 0.0})
	LevelKit.process_on_screen(self, Rect2(-spread / 2.0 - Vector2(40, 20), spread + Vector2(80, 40)))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for eye in _eyes:
		var world: Vector2 = global_position + eye.pos
		var near := _player != null and (_player.dead or _player.global_position.distance_to(world) < shy_distance)
		if near:
			eye.hide = HIDE_TIME
		eye.hide = maxf(0.0, eye.hide - delta)
		eye.blink -= delta
		if eye.blink < -BLINK_DURATION:
			eye.blink = randf_range(BLINK_MIN, BLINK_MAX)
		var target := 0.0 if eye.hide > 0.0 or eye.blink < 0.0 else 1.0
		var speed := CLOSE_SPEED if target < eye.open else OPEN_SPEED
		eye.open = move_toward(eye.open, target, speed * delta)
	_visual.queue_redraw()


## Un flash le spaventa tutte, anche se la lampadina è lontana.
func _on_flashed(origin: Vector2, radius: float) -> void:
	for eye in _eyes:
		if origin.distance_to(global_position + eye.pos) < radius * 1.3:
			eye.hide = HIDE_TIME * 1.5
			eye.open = minf(eye.open, 0.3)


func _offsets() -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	var result: Array[Vector2] = []
	for i in pairs:
		if pairs == 1:
			result.append(Vector2.ZERO)
		else:
			result.append(Vector2(rng.randf_range(-0.5, 0.5) * spread.x, rng.randf_range(-0.5, 0.5) * spread.y))
	return result


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_eyes(self)


func _draw_eyes(item: CanvasItem) -> void:
	var eye_size: Vector2 = EYE_SIZES[size]
	var gap: float = GAPS[size]
	var list := _eyes
	if Engine.is_editor_hint():
		list = []
		for offset in _offsets():
			list.append({"pos": offset, "open": 1.0})
	for eye in list:
		var open: float = eye.open
		if open <= 0.02:
			continue
		var look := Vector2.ZERO
		if _player:
			look = (_player.global_position - (global_position + eye.pos)).normalized() * eye_size.x * LOOK
		for side in [-1.0, 1.0]:
			var center: Vector2 = eye.pos + Vector2(gap / 2.0 * side, 0)
			_draw_almond(item, center, Vector2(eye_size.x, eye_size.y * open), Color(color, open), side)
			if open > 0.4:
				item.draw_line(center + look + Vector2(0, -eye_size.y * open * 0.8),
						center + look + Vector2(0, eye_size.y * open * 0.8), Color(0, 0, 0, 0.85), maxf(1.5, eye_size.x * 0.25))


## Occhio a mandorla, con l'angolo interno un po' più basso (sguardo cattivo).
func _draw_almond(item: CanvasItem, center: Vector2, half: Vector2, tint: Color, side: float) -> void:
	var points := PackedVector2Array()
	for i in 12:
		var angle := i * TAU / 12.0
		var point := Vector2(cos(angle) * half.x, sin(angle) * half.y)
		point.y += -point.x * side * 0.25
		points.append(center + point)
	item.draw_colored_polygon(points, tint)
