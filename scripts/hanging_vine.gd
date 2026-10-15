@tool
class_name HangingVine
extends Node2D
## Rampicante che pende sotto un bordo, solo decorativo: niente collisioni né
## ombre. Pende sotto una linea lunga `width` che parte dall'origine verso
## destra (come EdgeWeb): mettilo sotto una piattaforma o il soffitto. I tralci
## stanno fermi e si scostano quando la lampadina li attraversa, perdendo
## qualche foglia.

@export var width := 200.0:
	set(value):
		width = value
		_strands_cache.clear()
		queue_redraw()
## Lunghezza dei tralci più lunghi (i più corti sono circa la metà).
@export var length := 150.0:
	set(value):
		length = value
		_strands_cache.clear()
		queue_redraw()
## Tralci ogni 100 px di bordo.
@export_range(1.0, 8.0, 0.5) var density := 3.5:
	set(value):
		density = value
		_strands_cache.clear()
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
		_strands_cache.clear()
		queue_redraw()
## Se vero la lampadina non interagisce con questo oggetto.
@export var disable_interaction := false

## Molla che riporta il tralcio a piombo e smorzamento dell'oscillazione.
const STIFFNESS := 18.0
const DAMPING := 2.5
## Quanto la velocità della lampadina sposta un tralcio che tocca.
const PUSH := 0.016
const MAX_SWING := 0.7
## Sotto questa oscillazione (e velocità) il tralcio è fermo: si smette di muoverlo.
const REST := 0.0005
## Foglie che cadono per ogni pixel percorso dalla lampadina tra i tralci.
const LEAVES_PER_PX := 1.0 / 80.0
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
var _resting := true
var _area: Area2D
var _falling: FallingLeaves
var _rustle: PlantRustle
var _leaf_budget := 0.0
var _rng := RandomNumberGenerator.new()
## Tralci già calcolati (si svuota quando cambia la forma) e stato di _rng
## subito dopo averli generati, da cui _draw riparte.
var _strands_cache := []
var _rng_after_strands := 0
## Un canvas item del RenderingServer per tralcio, disegnato una volta sola a
## piombo: oscillando si inclina soltanto (vedi _apply_swing). L'ultimo è il
## ciuffo lungo il bordo, sempre fermo, che copre gli attacchi dei tralci.
var _pieces: Array[RID] = []
## Mentre si muove le oscillazioni si mostrano un tick di fisica sì e uno no (30 Hz).
var _skip_tick := false


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
	_falling = FallingLeaves.new()
	_falling.leaf_shape = PackedVector2Array(IVY if leaf_style == "ivy" else HEART)
	add_child(_falling)
	_rustle = PlantRustle.new()
	add_child(_rustle)
	LevelKit.process_on_screen(self, Rect2(-length / 2.0, 0, width + length, length))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for item in _pieces:
			RenderingServer.free_rid(item)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var players: Array[Player] = []
	if not disable_interaction:
		for body in _area.get_overlapping_bodies():
			if body is Player:
				players.append(body)
	# Fermo e senza lampadina vicino: niente da muovere né da ridisegnare.
	if _resting and players.is_empty():
		return
	var strands := _strands()
	if _swing.size() != strands.size():
		_swing.resize(strands.size())
		_swing_velocity.resize(strands.size())
	var moving := false
	var shaken: Array[Vector2] = []
	var shaker: Player
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
			shaken.append(Vector2(x, clampf(p.y, 0.0, strand.length)))
			shaker = player
		_swing_velocity[i] += force * delta
		_swing[i] = clampf(_swing[i] + _swing_velocity[i] * delta, -MAX_SWING, MAX_SWING)
		if absf(_swing[i]) > REST or absf(_swing_velocity[i]) > REST:
			moving = true
	if shaker:
		_drop_leaves(shaken, shaker, delta)
		_rustle.touch(shaker.velocity.length())
	var was_resting := _resting
	_resting = not moving
	if _resting:
		if was_resting:
			return
		_swing.fill(0.0)
		_swing_velocity.fill(0.0)
	else:
		# Ancora in movimento: le oscillazioni si mostrano a 30 Hz. Quando torna
		# a riposo invece subito, così i tralci restano a piombo.
		_skip_tick = not _skip_tick
		if _skip_tick:
			return
	_apply_swing()


## Mostra le oscillazioni attuali: ogni tralcio si inclina attorno al bordo
## (y = 0) e il punto all'altezza y si sposta di -sin(oscillazione) · y, come
## lo cerca _physics_process.
func _apply_swing() -> void:
	for i in mini(_swing.size(), _pieces.size() - 1):
		var swing := _swing[i]
		RenderingServer.canvas_item_set_transform(_pieces[i],
				Transform2D(Vector2.RIGHT, Vector2(-sin(swing), cos(swing)), Vector2.ZERO))


## Tralci come {x, length, phase}, calcolati una volta sola. Dopo la chiamata
## _rng prosegue sempre dallo stesso punto.
func _strands() -> Array:
	if _strands_cache.is_empty():
		_rng.seed = pattern
		var count := maxi(1, roundi(width / 100.0 * density))
		for i in count:
			var slot := width / count
			_strands_cache.append({
				x = slot * (i + 0.5) + _rng.randf_range(-0.3, 0.3) * slot,
				length = length * _rng.randf_range(0.45, 1.0),
				phase = _rng.randf() * TAU,
			})
		_rng_after_strands = _rng.state
	else:
		_rng.state = _rng_after_strands
	return _strands_cache


## Stacca foglie nei punti `shaken` dei tralci, tante quanta strada fa
## `player` tra i tralci.
func _drop_leaves(shaken: Array[Vector2], player: Player, delta: float) -> void:
	_leaf_budget += player.velocity.length() * delta * LEAVES_PER_PX
	while _leaf_budget >= 1.0:
		_leaf_budget -= 1.0
		var at: Vector2 = shaken.pick_random() + Vector2(randf_range(-6.0, 6.0), randf_range(-10.0, 10.0))
		var color: Color = [GroundPlant.LEAF, GroundPlant.LEAF_LIGHT, GroundPlant.LEAF_DARK].pick_random()
		_falling.spawn(at, player.velocity, 11.0 if leaf_style == "ivy" else 14.0, color)


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


## Disegna il rampicante a piombo: il fusto lungo il bordo sul nodo stesso,
## tralci e ciuffo nei pezzi. Si rifà solo quando cambia la forma.
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
	for k in range(strands.size() + 1, _pieces.size()):
		RenderingServer.free_rid(_pieces[k])
	_pieces.resize(strands.size() + 1)
	for k in _pieces.size():
		_pieces[k] = GroundPlant.piece_item(self, _pieces[k], get_canvas_item(), k)
	for i in strands.size():
		var item := _pieces[i]
		var points := _strand_points(strands[i], 0.0)
		RenderingServer.canvas_item_add_polyline(item, points, PackedColorArray([GroundPlant.STEM]), 2.0, true)
		for j in range(1, points.size()):
			var t := float(j) / (points.size() - 1)
			var dir := (points[j] - points[j - 1]).normalized()
			var side := 1.0 if j % 2 == 0 else -1.0
			var size := leaf_size * lerpf(1.0, 0.6, t) * _rng.randf_range(0.85, 1.15)
			_draw_leaf(item, shape, points[j], dir.angle() + side * 0.9, size, colors[_rng.randi() % colors.size()])
			if flowers and _rng.randf() < 0.18:
				_draw_flower(item, points[j] + Vector2(-dir.y, dir.x) * side * -5.0)
	# Ciuffo di foglie lungo il bordo che copre gli attacchi dei tralci.
	var tuft_item := _pieces[strands.size()]
	var tuft := 0.0
	while tuft < width:
		var angle := PI / 2.0 + _rng.randf_range(-1.3, 1.3)
		_draw_leaf(tuft_item, shape, Vector2(tuft, 4.0), angle, leaf_size * _rng.randf_range(0.8, 1.1), colors[_rng.randi() % colors.size()])
		tuft += _rng.randf_range(8.0, 14.0)
	_apply_swing()


func _draw_leaf(item: RID, shape: PackedVector2Array, at: Vector2, angle: float, size: float, color: Color) -> void:
	var xform := Transform2D(angle, Vector2(size, size), 0.0, at)
	RenderingServer.canvas_item_add_polygon(item, xform * shape, PackedColorArray([color]))
	RenderingServer.canvas_item_add_line(item, at, xform * Vector2(0.8, 0), GroundPlant.VEIN, 1.0)


func _draw_flower(item: RID, at: Vector2) -> void:
	for k in 5:
		RenderingServer.canvas_item_add_circle(item, at + Vector2.from_angle(k * TAU / 5.0) * 3.0, 2.6, FLOWER)
	RenderingServer.canvas_item_add_circle(item, at, 1.8, FLOWER_CENTER)
