@tool
class_name HangingRope
extends Node2D
## Fune appesa, solo decorativa: non regge la lampadina e non fa ombra, ma
## ondeggia quando la lampadina ci passa attraverso. L'origine è il punto
## d'aggancio (es. il bordo inferiore del soffitto).

@export var length := 220.0:
	set(value):
		length = value
		queue_redraw()
## Pezzi della simulazione: più sono, più la fune è morbida.
@export_range(4, 24) var segments := 12:
	set(value):
		segments = value
		queue_redraw()
## Cosa c'è in fondo alla fune.
@export_enum("knot", "hook", "loop") var end_style := "knot":
	set(value):
		end_style = value
		queue_redraw()
@export var thickness := 5.0:
	set(value):
		thickness = value
		queue_redraw()

const GRAVITY := 1800.0
## Smorzamento a ogni passo: più è basso, prima la fune smette di oscillare.
const DAMPING := 0.985
const ITERATIONS := 8
## Quanta velocità della lampadina passa alla fune quando la tocca.
const PUSH_TRANSFER := 0.6
## Capsula della lampadina (vedi player.gd): raggio e metà del tratto dritto.
const PLAYER_RADIUS := 30.0
const PLAYER_HALF_SPINE := 22.0
const ROPE := Color(0.4, 0.33, 0.25)
const ROPE_DARK := Color(0.28, 0.22, 0.17)
const METAL := Color(0.32, 0.32, 0.36)

var _points := PackedVector2Array()
var _previous := PackedVector2Array()
var _area: Area2D


func _ready() -> void:
	z_index = -4
	if Engine.is_editor_hint():
		return
	_points = _rest_points()
	_previous = _points.duplicate()
	# Area che sente la lampadina (layer 1) ovunque la fune possa oscillare.
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length * 2.0, length) + Vector2(4.0, 2.0) * PLAYER_RADIUS * 2.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, length / 2.0)
	_area.add_child(collision)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Integrazione di Verlet: la velocità è la differenza dal passo precedente.
	var fall := Vector2(0, GRAVITY * delta * delta)
	for i in range(1, _points.size()):
		var current := _points[i]
		_points[i] = current + (current - _previous[i]) * DAMPING + fall
		_previous[i] = current
	_push_by_player(delta)
	var rest := length / segments
	for k in ITERATIONS:
		_points[0] = Vector2.ZERO
		for i in segments:
			var offset := _points[i + 1] - _points[i]
			var distance := offset.length()
			if distance < 0.001:
				continue
			var correction := offset * (distance - rest) / distance
			if i == 0:
				_points[i + 1] -= correction
			else:
				_points[i] += correction * 0.5
				_points[i + 1] -= correction * 0.5
	queue_redraw()


## Spinge fuori dalla capsula della lampadina i punti della fune e passa loro
## parte della sua velocità.
func _push_by_player(delta: float) -> void:
	for body in _area.get_overlapping_bodies():
		var player := body as Player
		if player == null:
			continue
		var center := to_local(player.global_position)
		var top := center + Vector2(0, -PLAYER_HALF_SPINE)
		var bottom := center + Vector2(0, PLAYER_HALF_SPINE)
		var reach := PLAYER_RADIUS + thickness / 2.0
		var motion := player.velocity * delta * PUSH_TRANSFER
		for i in range(1, _points.size()):
			var closest := Geometry2D.get_closest_point_to_segment(_points[i], top, bottom)
			var away := _points[i] - closest
			if away.length() >= reach:
				continue
			if away.length() < 0.01:
				away = Vector2(-signf(player.velocity.x) if player.velocity.x != 0.0 else 1.0, 0)
			_points[i] = closest + away.normalized() * reach
			_previous[i] = _points[i] - motion


func _rest_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments + 1:
		points.append(Vector2(0, length * i / segments))
	return points


func _draw() -> void:
	var points := _points if _points.size() == segments + 1 else _rest_points()
	# Piastra e anello d'aggancio.
	draw_rect(Rect2(-10, -4, 20, 8), METAL)
	draw_arc(Vector2(0, 6), 4.0, 0.0, TAU, 12, METAL, 2.5)
	draw_polyline(points, ROPE, thickness, true)
	# Trama intrecciata: trattini obliqui lungo la fune.
	for i in range(1, points.size()):
		var dir := (points[i] - points[i - 1]).normalized()
		var across := Vector2(-dir.y, dir.x) * thickness * 0.5
		var middle := (points[i] + points[i - 1]) / 2.0
		draw_line(middle - across - dir * 2.0, middle + across + dir * 2.0, ROPE_DARK, 1.5)
	var end := points[points.size() - 1]
	var down := (end - points[points.size() - 2]).normalized()
	# Il fondo si disegna in un sistema in cui la fune scende lungo +y.
	draw_set_transform(end, down.angle() - PI / 2.0)
	match end_style:
		"knot":
			draw_circle(Vector2.ZERO, thickness * 1.3, ROPE)
			draw_line(Vector2(-1, 0), Vector2(-3, 12), ROPE, 2.0)
			draw_line(Vector2(1, 0), Vector2(3, 10), ROPE, 2.0)
		"hook":
			draw_line(Vector2.ZERO, Vector2(0, 12), METAL, 4.0)
			draw_arc(Vector2(-8, 12), 8.0, 0.0, PI, 10, METAL, 4.0)
			draw_line(Vector2(-16, 12), Vector2(-16, 7), METAL, 4.0)
		"loop":
			draw_arc(Vector2(0, 12), 12.0, 0.0, TAU, 20, ROPE, thickness)
	draw_set_transform(Vector2.ZERO)
