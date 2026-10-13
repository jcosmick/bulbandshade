@tool
class_name Dust
extends Node2D
## Polvere sospesa, solo decorativa: granelli che galleggiano piano dentro
## un rettangolo `size` centrato sul nodo, sfumando verso i bordi in una
## forma ovale (così non si vede dove finisce la zona). Si vedono solo dove
## c'è luce: vicino alla lampadina (materiale "solo luce") e nei fasci delle
## finestre (ridisegnati sopra il fascio, che sta sopra il buio).

@export var size := Vector2(600, 400):
	set(value):
		size = value
		queue_redraw()
## Numero di granelli.
@export_range(1, 300) var amount := 60
## Velocità media dei granelli (px/s).
@export var speed := 12.0

const MOTE := Color(1.0, 0.94, 0.8, 0.8)
const BEAM_MOTE := Color(1.0, 0.97, 0.88, 0.6)
const MIN_RADIUS := 1.2
const MAX_RADIUS := 2.6
## Ampiezza dell'ondeggiamento attorno alla traiettoria (px).
const WOBBLE := 6.0
## Spinta verso l'alto, in frazione di `speed`: la polvere tende a salire piano.
const RISE := 0.3
## Da quale frazione della distanza dal centro al bordo dell'ovale i granelli
## iniziano a sfumare (oltre il bordo dell'ovale spariscono del tutto).
const FADE_START := 0.55
const EDITOR_FRAME := Color(0.9, 0.85, 0.6, 0.6)

var _motes: Array[Dictionary] = []
var _time := 0.0
var _beam_visual: Node2D


func _ready() -> void:
	z_index = -3
	if Engine.is_editor_hint():
		return
	var light_only := CanvasItemMaterial.new()
	light_only.light_mode = CanvasItemMaterial.LIGHT_MODE_LIGHT_ONLY
	material = light_only
	_beam_visual = LevelKit.make_overlay(self, true, 2)
	_beam_visual.draw.connect(_draw_beam_motes)
	for i in amount:
		var drift := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.4, 1.0)
		_motes.append({
			"pos": Vector2(randf_range(-0.5, 0.5) * size.x, randf_range(-0.5, 0.5) * size.y),
			"vel": drift + Vector2(0, -speed * RISE),
			"radius": randf_range(MIN_RADIUS, MAX_RADIUS),
			"phase": randf() * TAU,
		})
	LevelKit.process_on_screen(self, Rect2(-size / 2.0, size))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var half := size / 2.0
	for mote in _motes:
		var pos: Vector2 = mote.pos + mote.vel * delta
		# Chi esce da un lato rientra da quello opposto.
		mote.pos = Vector2(wrapf(pos.x, -half.x, half.x), wrapf(pos.y, -half.y, half.y))
	queue_redraw()
	_beam_visual.queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-size / 2.0, size), EDITOR_FRAME, false, 2.0)
		# Ovale entro cui la polvere è visibile.
		var oval := PackedVector2Array()
		for i in 49:
			oval.append(Vector2.from_angle(TAU * i / 48.0) * size / 2.0)
		draw_polyline(oval, Color(EDITOR_FRAME, 0.3), 2.0)
		draw_string(ThemeDB.fallback_font, -size / 2.0 + Vector2(8, 22), "dust", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, EDITOR_FRAME)
		return
	for mote in _motes:
		var pos := _mote_position(mote)
		draw_circle(pos, mote.radius, _twinkle(MOTE, mote, pos))


## Granelli che cadono dentro un fascio di finestra acceso.
func _draw_beam_motes() -> void:
	var beams: Array[PackedVector2Array] = []
	for window in get_tree().get_nodes_in_group("light_beams"):
		beams.append_array(window.beam_polygons())
	if beams.is_empty():
		return
	for mote in _motes:
		var pos := _mote_position(mote)
		var world := global_transform * pos
		for polygon in beams:
			if Geometry2D.is_point_in_polygon(world, polygon):
				_beam_visual.draw_circle(pos, mote.radius, _twinkle(BEAM_MOTE, mote, pos))
				break


## Posizione con un leggero ondeggiamento, diverso per ogni granello.
func _mote_position(mote: Dictionary) -> Vector2:
	var phase: float = mote.phase
	return mote.pos + Vector2(sin(_time * 0.7 + phase), cos(_time * 0.5 + phase * 1.3)) * WOBBLE


## Ogni granello brilla un po' di più o di meno, come se girasse nella luce,
## e sfuma avvicinandosi al bordo dell'ovale.
func _twinkle(color: Color, mote: Dictionary, pos: Vector2) -> Color:
	var phase: float = mote.phase
	var edge := (pos / (size / 2.0)).length()
	var fade := 1.0 - smoothstep(FADE_START, 1.0, edge)
	return Color(color, color.a * fade * (0.55 + 0.45 * sin(_time * 1.5 + phase * 2.0)))
