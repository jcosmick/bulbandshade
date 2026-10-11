class_name TouchJoystick
extends Node2D
## Joystick virtuale "flottante": appare dove si appoggia il dito dentro la
## zona e muove il giocatore in orizzontale (con intensità analogica).

const RADIUS := 110.0
const KNOB_RADIUS := 48.0
const DEADZONE := 0.15
const RING := Color(1, 1, 1, 0.35)
const BASE := Color(1, 1, 1, 0.06)
const KNOB := Color(1, 0.92, 0.7, 0.75)
const IDLE_ALPHA := 0.45

## Zona dello schermo in cui un tocco attiva il joystick.
var zone := Rect2()
## Dove si mostra il joystick quando nessuno lo tocca.
var rest_position := Vector2.ZERO

var _touch := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and zone.has_point(event.position):
			_touch = event.index
			_origin = event.position
			_knob = Vector2.ZERO
			_apply()
		elif not event.pressed and event.index == _touch:
			release()
	elif event is InputEventScreenDrag and event.index == _touch:
		var offset: Vector2 = event.position - _origin
		# La base segue il dito se esce dal cerchio: si può sempre invertire subito.
		if offset.length() > RADIUS:
			_origin += offset - offset.normalized() * RADIUS
		_knob = (event.position - _origin).limit_length(RADIUS)
		_apply()


func release() -> void:
	_touch = -1
	_knob = Vector2.ZERO
	_apply()


func _apply() -> void:
	var x := _knob.x / RADIUS
	var strength := inverse_lerp(DEADZONE, 1.0, absf(x)) if absf(x) > DEADZONE else 0.0
	Input.action_release("move_left")
	Input.action_release("move_right")
	if strength > 0.0:
		Input.action_press("move_right" if x > 0.0 else "move_left", strength)
	queue_redraw()


func _draw() -> void:
	var active := _touch != -1
	var center := _origin if active else rest_position
	var alpha := 1.0 if active else IDLE_ALPHA
	draw_circle(center, RADIUS, Color(BASE, BASE.a * alpha))
	draw_arc(center, RADIUS, 0.0, TAU, 48, Color(RING, RING.a * alpha), 4.0, true)
	if not active:
		for s: float in [-1.0, 1.0]:
			var tip := center + Vector2(s * (RADIUS - 18.0), 0)
			draw_colored_polygon(PackedVector2Array([
				tip, tip + Vector2(-s * 18.0, -14.0), tip + Vector2(-s * 18.0, 14.0)
			]), Color(RING, RING.a * alpha * 1.5))
	draw_circle(center + _knob, KNOB_RADIUS, Color(KNOB, KNOB.a * alpha))
