@tool
class_name NeonLight
extends Node2D
## Plafoniera al neon appesa al soffitto che sfarfalla: illumina un po' la
## stanza ma non tocca le ombre solide (quelle le crea solo il flash). Solo
## decorativa. L'origine è il punto d'aggancio sul soffitto.
## "flicker": quasi sempre accesa, ogni tanto vacilla.
## "broken": quasi sempre spenta, ogni tanto prova a riaccendersi.
## "steady": sempre accesa, fissa, senza sfarfallii.
## "dead": spenta, con il tubo rotto.

@export_enum("flicker", "broken", "steady", "dead") var mode := "flicker":
	set(value):
		mode = value
		queue_redraw()
## Lunghezza della plafoniera.
@export var length := 170.0:
	set(value):
		length = value
		queue_redraw()
## Lunghezza dei cavetti che la reggono (0 = attaccata al soffitto).
@export var hang := 40.0:
	set(value):
		hang = value
		queue_redraw()
## Un cavetto si è staccato: la plafoniera pende da un lato.
@export var dangling := false:
	set(value):
		dangling = value
		queue_redraw()
@export var light_radius := 380.0
## Ombre della luce del neon: più belle ma costano (attenzione su mobile).
@export var shadows := false
## Sfasa gli sfarfallii, per non avere tutti i neon sincronizzati.
@export var phase := 0.0

const HOUSING := Color(0.36, 0.37, 0.4)
const HOUSING_DARK := Color(0.24, 0.25, 0.28)
const CORD := Color(0.2, 0.2, 0.22)
const TUBE_ON := Color(0.88, 0.97, 1.0)
const TUBE_OFF := Color(0.42, 0.45, 0.5)
const LIGHT := Color(0.78, 0.92, 1.0)
const ENERGY := 0.75
const DANGLE_ANGLE := 1.15
## Durate (secondi) degli sfarfallii: spenta, accesa, spenta, ...
const STUTTER := [0.05, 0.04, 0.09, 0.03, 0.14, 0.06]
const FLICKER_WAIT := Vector2(1.5, 6.0)
const BROKEN_WAIT := Vector2(2.5, 7.0)

var _visual: Node2D
var _light: PointLight2D
var _on := true
## Tempi dello sfarfallio in corso (vuoto se stabile) e attesa del prossimo.
var _pattern: Array[float] = []
var _step_time := 0.0
var _wait := 0.0
var _sound_on: AudioStreamPlayer2D
var _sound_off: AudioStreamPlayer2D


func _ready() -> void:
	z_index = -6
	if Engine.is_editor_hint():
		return
	_on = mode == "flicker" or mode == "steady"
	var center := _tube_center()
	if mode != "dead":
		_light = LevelKit.make_light(self, light_radius, ENERGY if _on else 0.0, shadows)
		_light.color = LIGHT
		_light.position = center
		_sound_on = Sfx.make_player_2d("flicker_on", self)
		_sound_off = Sfx.make_player_2d("flicker_off", self)
		for sound in [_sound_on, _sound_off]:
			sound.position = center
			sound.volume_db = -14.0
	# Il tubo acceso sta sopra il buio, come le finestre.
	_visual = LevelKit.make_overlay(self)
	_visual.draw.connect(func() -> void:
		if _on:
			_draw_tube(_visual, TUBE_ON))
	_wait = _next_wait() + phase
	var reach := length + hang
	LevelKit.process_on_screen(self, Rect2(-reach, -10, reach * 2.0, reach + 20.0))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or mode == "dead" or mode == "steady":
		return
	if _pattern.is_empty() and _step_time <= 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_start_stutter()
		return
	_step_time -= delta
	while _step_time <= 0.0 and not _pattern.is_empty():
		_set_on(not _on)
		_step_time += _pattern.pop_front()
	if _pattern.is_empty() and _step_time <= 0.0:
		# Fine dello sfarfallio: torna allo stato di riposo.
		_set_on(mode == "flicker")
		_wait = _next_wait()


func _start_stutter() -> void:
	_pattern.clear()
	var steps := randi_range(3, STUTTER.size())
	for i in steps:
		_pattern.append(STUTTER[i] * randf_range(0.6, 1.6))
	# Il guasto a volte tiene la luce accesa un attimo prima di rimollare.
	if mode == "broken":
		_pattern.append(randf_range(0.2, 0.9))
	_step_time = 0.0


func _next_wait() -> float:
	var range_ := FLICKER_WAIT if mode == "flicker" else BROKEN_WAIT
	return randf_range(range_.x, range_.y)


func _set_on(value: bool) -> void:
	if value == _on:
		return
	_on = value
	_light.energy = ENERGY * randf_range(0.8, 1.0) if value else 0.0
	(_sound_on if value else _sound_off).play()
	_visual.queue_redraw()
	queue_redraw()


## Trasformazione della plafoniera: centrata sotto i cavetti, o appesa a un
## cavetto solo e ruotata se dangling.
func _fixture_transform() -> Transform2D:
	if dangling:
		var pivot := Vector2(-length / 2.0 + 12.0, hang)
		return Transform2D(DANGLE_ANGLE, pivot) * Transform2D(0.0, Vector2(length / 2.0 - 12.0, 0))
	return Transform2D(0.0, Vector2(0, hang))


func _tube_center() -> Vector2:
	return _fixture_transform() * Vector2(0, 10)


func _draw() -> void:
	var half := length / 2.0
	# Cavetti (o uno solo) e la plafoniera.
	var left := Vector2(-half + 12.0, 0)
	draw_line(left, left + Vector2(0, hang), CORD, 2.0)
	if not dangling:
		draw_line(Vector2(half - 12.0, 0), Vector2(half - 12.0, hang), CORD, 2.0)
	else:
		# Il cavetto spezzato penzola dal soffitto.
		draw_line(Vector2(half - 12.0, 0), Vector2(half - 10.0, hang * 0.5), CORD, 2.0)
	draw_set_transform_matrix(_fixture_transform())
	draw_rect(Rect2(-half, -4, length, 10), HOUSING)
	draw_line(Vector2(-half, 6), Vector2(half, 6), HOUSING_DARK, 2.0)
	for x in [-half + 4.0, half - 10.0]:
		draw_rect(Rect2(x, 4, 6, 12), HOUSING_DARK)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if not _on or Engine.is_editor_hint():
		_draw_tube(self, TUBE_ON if Engine.is_editor_hint() and mode != "dead" else TUBE_OFF)


func _draw_tube(item: CanvasItem, color: Color) -> void:
	var half := length / 2.0 - 10.0
	item.draw_set_transform_matrix(_fixture_transform())
	if mode == "dead":
		# Tubo spezzato: manca un pezzo, con le punte di vetro.
		var gap := half * 0.3
		item.draw_line(Vector2(-half, 10), Vector2(gap - 8.0, 10), color, 7.0)
		item.draw_line(Vector2(gap + 14.0, 10), Vector2(half, 10), color, 7.0)
		item.draw_colored_polygon(PackedVector2Array([
			Vector2(gap - 8.0, 6.5), Vector2(gap - 1.0, 9.0), Vector2(gap - 8.0, 13.5)
		]), color)
	else:
		item.draw_line(Vector2(-half, 10), Vector2(half, 10), color, 7.0)
		if color == TUBE_ON:
			item.draw_line(Vector2(-half, 10), Vector2(half, 10), Color(TUBE_ON, 0.18), 18.0)
	item.draw_set_transform_matrix(Transform2D.IDENTITY)
