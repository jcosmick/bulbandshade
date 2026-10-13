@tool
class_name HangingVine
extends Node2D
## Rampicante che pende sotto un bordo, solo decorativo: niente collisioni né
## ombre. Pende sotto una linea lunga `width` che parte dall'origine verso
## destra (come EdgeWeb): mettilo sotto una piattaforma o il soffitto. I tralci
## ondeggiano piano e si scostano quando la lampadina li attraversa.

@export var width := 200.0:
	set(value):
		width = value
		queue_redraw()
## Lunghezza dei tralci più lunghi (i più corti sono circa la metà).
@export var length := 150.0:
	set(value):
		length = value
		queue_redraw()
## Tralci ogni 100 px di bordo.
@export_range(1.0, 8.0, 0.5) var density := 3.5:
	set(value):
		density = value
		queue_redraw()
## Forma delle foglie: edera (tre punte) o a cuore (pothos, più grandi).
@export_enum("ivy", "heart") var leaf_style := "ivy":
	set(value):
		leaf_style = value
		queue_redraw()
## Fiorellini sparsi lungo i tralci.
@export var flowers := false:
	set(value):
		flowers = value
		queue_redraw()
## Cambialo per un rampicante di forma diversa; due istanze con lo stesso
## valore sono identiche.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()

## Molla che riporta il tralcio a piombo e smorzamento dell'oscillazione.
const STIFFNESS := 18.0
const DAMPING := 2.5
## Quanto la velocità della lampadina sposta un tralcio che tocca.
const PUSH := 0.016
const MAX_SWING := 0.7
const IDLE_SPEED := 1.1
const IDLE_AMOUNT := 0.04
## Capsula della lampadina (vedi player.gd): raggio e metà del tratto dritto.
const PLAYER_RADIUS := 30.0
const PLAYER_HALF_SPINE := 22.0
## Distanza tra due foglie lungo un tralcio.
const LEAF_STEP := 13.0
const FLOWER := Color(0.5, 0.33, 0.42)
const FLOWER_CENTER := Color(0.58, 0.5, 0.3)
## Sagome delle foglie, con il picciolo nell'origine e la punta in (1, 0).
const IVY := [
	Vector2(0, 0), Vector2(0.2, -0.35), Vector2(0.45, -0.5), Vector2(0.55, -0.25),
	Vector2(1, 0), Vector2(0.55, 0.25), Vector2(0.45, 0.5), Vector2(0.2, 0.35),
]
const HEART := [
	Vector2(0.05, 0), Vector2(-0.05, -0.3), Vector2(0.15, -0.48), Vector2(0.45, -0.45),
	Vector2(0.75, -0.25), Vector2(1, 0), Vector2(0.75, 0.25), Vector2(0.45, 0.45),
	Vector2(0.15, 0.48), Vector2(-0.05, 0.3),
]

var _swing := PackedFloat32Array()
var _swing_velocity := PackedFloat32Array()
var _time := 0.0
var _area: Area2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = -5
	if Engine.is_editor_hint():
		return
	# Area che sente la lampadina (layer 1) ovunque i tralci possano oscillare.
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width + length, length) + Vector2(2.0, 2.0) * (PLAYER_RADIUS + PLAYER_HALF_SPINE)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(width / 2.0, length / 2.0)
	_area.add_child(collision)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var strands := _strands()
	if _swing.size() != strands.size():
		_swing.resize(strands.size())
		_swing_velocity.resize(strands.size())
	var players: Array[Player] = []
	for body in _area.get_overlapping_bodies():
		if body is Player:
			players.append(body)
	for i in strands.size():
		var strand: Dictionary = strands[i]
		var force := -STIFFNESS * _swing[i] - DAMPING * _swing_velocity[i]
		for player in players:
			var p := to_local(player.global_position)
			if p.y + PLAYER_RADIUS + PLAYER_HALF_SPINE < 0.0 or p.y - PLAYER_RADIUS - PLAYER_HALF_SPINE > strand.length:
				continue
			# Dove si trova il tralcio all'altezza della lampadina.
			var x: float = strand.x - sin(_swing[i]) * clampf(p.y, 0.0, strand.length)
			if absf(p.x - x) > PLAYER_RADIUS + 8.0:
				continue
			# Muovendosi in verticale la lampadina scosta i tralci un po' a caso.
			var side := 1.0 if i % 2 == 0 else -1.0
			force -= (player.velocity.x + player.velocity.y * 0.3 * side) * PUSH
		_swing_velocity[i] += force * delta
		_swing[i] = clampf(_swing[i] + _swing_velocity[i] * delta, -MAX_SWING, MAX_SWING)
	queue_redraw()


## Tralci come {x, length, phase}. Rimette il seme, quindi dopo la chiamata
## _rng prosegue sempre dallo stesso punto.
func _strands() -> Array:
	_rng.seed = pattern
	var count := maxi(1, roundi(width / 100.0 * density))
	var list := []
	for i in count:
		var slot := width / count
		list.append({
			x = slot * (i + 0.5) + _rng.randf_range(-0.3, 0.3) * slot,
			length = length * _rng.randf_range(0.45, 1.0),
			phase = _rng.randf() * TAU,
		})
	return list


func _strand_points(strand: Dictionary, swing: float) -> PackedVector2Array:
	var count := maxi(2, int(strand.length / LEAF_STEP))
	var p := Vector2(strand.x, 3.0)
	var points := PackedVector2Array([p])
	for j in count:
		var t := (j + 1.0) / count
		# Si piega di più verso la punta e serpeggia un poco.
		var heading: float = PI / 2.0 + swing * (0.5 + 0.8 * t) + sin(t * 5.0 + strand.phase) * 0.15
		p += Vector2.from_angle(heading) * strand.length / count
		points.append(p)
	return points


func _draw() -> void:
	var strands := _strands()
	var shape := PackedVector2Array(IVY if leaf_style == "ivy" else HEART)
	var leaf_size := 13.0 if leaf_style == "ivy" else 17.0
	var colors := [GroundPlant.LEAF, GroundPlant.LEAF_LIGHT, GroundPlant.LEAF_DARK]
	# Fusto principale lungo il bordo.
	var edge := PackedVector2Array()
	var edge_count := maxi(1, int(width / 20.0))
	for k in edge_count + 1:
		edge.append(Vector2(width * k / edge_count, 3.0 + sin(k * 1.7 + pattern) * 2.5))
	draw_polyline(edge, GroundPlant.STEM, 3.0, true)
	for i in strands.size():
		var strand: Dictionary = strands[i]
		var swing := (_swing[i] if i < _swing.size() else 0.0) + sin(_time * IDLE_SPEED + strand.phase) * IDLE_AMOUNT
		var points := _strand_points(strand, swing)
		draw_polyline(points, GroundPlant.STEM, 2.0, true)
		for j in range(1, points.size()):
			var t := float(j) / (points.size() - 1)
			var dir := (points[j] - points[j - 1]).normalized()
			var side := 1.0 if j % 2 == 0 else -1.0
			var size := leaf_size * lerpf(1.0, 0.6, t) * _rng.randf_range(0.85, 1.15)
			_draw_leaf(shape, points[j], dir.angle() + side * 0.9, size, colors[_rng.randi() % colors.size()])
			if flowers and _rng.randf() < 0.18:
				_draw_flower(points[j] + Vector2(-dir.y, dir.x) * side * -5.0)
	# Ciuffo di foglie lungo il bordo che copre gli attacchi dei tralci.
	var tuft := 0.0
	while tuft < width:
		var angle := PI / 2.0 + _rng.randf_range(-1.3, 1.3)
		_draw_leaf(shape, Vector2(tuft, 4.0), angle, leaf_size * _rng.randf_range(0.8, 1.1), colors[_rng.randi() % colors.size()])
		tuft += _rng.randf_range(8.0, 14.0)


func _draw_leaf(shape: PackedVector2Array, at: Vector2, angle: float, size: float, color: Color) -> void:
	var xform := Transform2D(angle, Vector2(size, size), 0.0, at)
	draw_colored_polygon(xform * shape, color)
	draw_line(at, xform * Vector2(0.8, 0), GroundPlant.VEIN, 1.0)


func _draw_flower(at: Vector2) -> void:
	for k in 5:
		draw_circle(at + Vector2.from_angle(k * TAU / 5.0) * 3.0, 2.6, FLOWER)
	draw_circle(at, 1.8, FLOWER_CENTER)
