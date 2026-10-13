@tool
class_name Fan
extends Node2D
## Ventola da muro in una cornice quadrata, solo decorativa: niente
## collisioni né ombre, in gioco le pale girano piano. Centrata sul nodo.
## Il suono segue la rotazione: la lamiera ronza piano (più acuta con più
## giri) e l'aria smossa soffia piano a ogni passaggio di pala.

## Raggio delle pale (la cornice è un po' più grande).
@export var radius := 56.0:
	set(value):
		radius = value
		queue_redraw()
## Giri al secondo (negativo = senso antiorario, 0 = ferma).
@export var speed := 0.6:
	set(value):
		speed = value
		_update_sound()
@export_range(2, 8) var blades := 4:
	set(value):
		blades = value
		queue_redraw()

const FRAME := Color(0.24, 0.24, 0.28)
const FRAME_DARK := Color(0.18, 0.18, 0.21)
const HOLE := Color(0.11, 0.1, 0.13)
const BLADE := Color(0.31, 0.31, 0.36)
const GRILLE := Color(0.21, 0.21, 0.25)
## Spazio tra le pale e il bordo della cornice.
const FRAME_MARGIN := 12.0
## Giri al secondo a cui i suoni hanno la loro intonazione originale.
const SOUND_SPEED := 0.6
## Quanto cala l'aria tra un passaggio di pala e l'altro (0 = soffio costante).
const AIR_PULSE := 0.06
## Distanza oltre la quale la ventola non si sente: è solo d'atmosfera.
const SOUND_DISTANCE := 1400.0

var _angle := 0.0
var _grind: AudioStreamPlayer2D
var _air: AudioStreamPlayer2D
var _air_db := 0.0


func _ready() -> void:
	z_index = -8
	if Engine.is_editor_hint():
		return
	_grind = _make_player("fan_grind")
	_air = _make_player("fan_air")
	_update_sound()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or speed == 0.0:
		return
	_angle = wrapf(_angle + TAU * speed * delta, 0.0, TAU)
	# Soffio quando una pala passa davanti alla griglia: il volume dell'aria segue l'angolo.
	var pulse := 0.5 + 0.5 * cos(_angle * blades)
	_air.volume_db = _air_db + linear_to_db(lerpf(1.0 - AIR_PULSE, 1.0, pulse))
	queue_redraw()


func _make_player(sound: String) -> AudioStreamPlayer2D:
	var player := Sfx.make_player_2d(sound, self)
	player.max_distance = SOUND_DISTANCE
	return player


## Intonazione e volume seguono la velocità: più giri, ronzio più acuto e più aria.
func _update_sound() -> void:
	if _grind == null:
		return
	if speed == 0.0:
		_grind.stop()
		_air.stop()
		return
	var ratio := absf(speed) / SOUND_SPEED
	# Anche le ventole lente si devono sentire: il volume cala poco sotto la velocità di riferimento.
	var level := linear_to_db(clampf(ratio, 0.7, 1.3))
	_grind.pitch_scale = clampf(sqrt(ratio), 0.6, 1.8)
	_grind.volume_db = level - 28.0
	_air.pitch_scale = clampf(sqrt(ratio), 0.7, 1.6)
	_air_db = level - 23.0
	if not _grind.playing:
		# Partenza in un punto a caso del loop: più ventole non suonano all'unisono.
		_grind.play(randf() * _grind.stream.get_length())
		_air.play(randf() * _air.stream.get_length())


func _draw() -> void:
	var half := radius + FRAME_MARGIN
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), FRAME)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		draw_circle(corner * (half - 7.0), 3.0, FRAME_DARK)
	draw_circle(Vector2.ZERO, radius, HOLE)
	var blade := PackedVector2Array([
		Vector2(8, -5), Vector2(radius * 0.6, -14), Vector2(radius - 6.0, -8),
		Vector2(radius - 6.0, 6), Vector2(radius * 0.6, 10), Vector2(8, 5),
	])
	for i in blades:
		draw_colored_polygon(Transform2D(_angle + TAU * i / blades, Vector2.ZERO) * blade, BLADE)
	draw_circle(Vector2.ZERO, 10.0, FRAME)
	draw_circle(Vector2.ZERO, 4.0, FRAME_DARK)
	# Griglia di protezione davanti alle pale.
	for r in [radius * 0.45, radius * 0.8]:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, GRILLE, 2.0)
	draw_line(Vector2(-radius, 0), Vector2(radius, 0), GRILLE, 2.0)
	draw_line(Vector2(0, -radius), Vector2(0, radius), GRILLE, 2.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, FRAME_DARK, 4.0)
