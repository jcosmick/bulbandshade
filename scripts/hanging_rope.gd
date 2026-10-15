@tool
class_name HangingRope
extends Node2D
## Fune appesa, solo decorativa: non regge la lampadina e non fa ombra, ma
## ondeggia quando la lampadina ci passa attraverso. L'origine è il punto
## d'aggancio (es. il bordo inferiore del soffitto).
## Con `kind` diventa una catena (tintinna quando la si tocca) o un cavo
## elettrico strappato, con il rame scoperto in fondo che fa scintille.

@export_enum("rope", "chain", "cable") var kind := "rope":
	set(value):
		kind = value
		queue_redraw()

@export var length := 220.0:
	set(value):
		length = value
		queue_redraw()
## Pezzi della simulazione: più sono, più la fune è morbida.
@export_range(4, 24) var segments := 12:
	set(value):
		segments = value
		queue_redraw()
## Cosa c'è in fondo alla fune ("knot" sulla catena è un lucchetto; il cavo
## finisce sempre con il rame sfilacciato). "hanged": una lampadina spenta
## appesa per il collo al cappio.
@export_enum("knot", "hook", "loop", "hanged") var end_style := "knot":
	set(value):
		end_style = value
		queue_redraw()
@export var thickness := 5.0:
	set(value):
		thickness = value
		queue_redraw()
## Solo cavo: scintille dal rame scoperto a intervalli casuali (oltre a quelle
## che fa quando la lampadina lo tocca).
@export var sparking := true
## Spinta di una corrente d'aria (px/s²): la fune dondola piano da sola.
## 0 = ferma finché la lampadina non la tocca.
@export var sway := 0.0
## Se vero la lampadina non la sposta (per le funi nei layer di parallasse,
## che non stanno dove passa la lampadina).
@export var disable_interaction := false

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
const CHAIN := Color(0.36, 0.36, 0.4)
const CHAIN_DARK := Color(0.22, 0.22, 0.25)
const CABLE := Color(0.12, 0.12, 0.13)
const CABLE_SHINE := Color(0.28, 0.28, 0.3)
const COPPER := Color(0.75, 0.46, 0.22)
## Lunghezza di una maglia della catena, in rapporto allo spessore.
const LINK_RATIO := 2.6
## Secondi minimi tra due suoni (catena) o due scintille (cavo) al tocco.
const TOUCH_COOLDOWN := 0.35
const SPARK_INTERVAL := Vector2(2.0, 7.0)
## Lampadina impiccata: punto del collo (coordinate dei piedi di DeadBulb)
## stretto dal cappio. Periodo (secondi) della corrente d'aria.
const NECK_Y := -40.0
const SWAY_PERIOD := 5.5

var _points := PackedVector2Array()
var _previous := PackedVector2Array()
var _area: Area2D
var _sound: AudioStreamPlayer2D
var _touch_cooldown := 0.0
var _spark_wait := 0.0
var _time := 0.0


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
	if kind == "chain":
		_sound = Sfx.make_player_2d("can", self)
	_spark_wait = randf_range(SPARK_INTERVAL.x, SPARK_INTERVAL.y)
	# Ogni fune parte da un punto diverso della corrente: non dondolano insieme.
	_time = randf() * SWAY_PERIOD
	LevelKit.process_on_screen(self, Rect2(-length, 0, length * 2.0, length))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Integrazione di Verlet: la velocità è la differenza dal passo precedente.
	_time += delta
	var fall := Vector2(sin(_time * TAU / SWAY_PERIOD) * sway, GRAVITY) * delta * delta
	for i in range(1, _points.size()):
		var current := _points[i]
		_points[i] = current + (current - _previous[i]) * DAMPING + fall
		_previous[i] = current
	_touch_cooldown = maxf(0.0, _touch_cooldown - delta)
	if kind == "cable" and sparking:
		_spark_wait -= delta
		if _spark_wait <= 0.0:
			_spark_wait = randf_range(SPARK_INTERVAL.x, SPARK_INTERVAL.y)
			SparkBurst.spawn(self, _points[segments], randf_range(0.3, 0.8))
	if not disable_interaction:
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
		var touched := false
		for i in range(1, _points.size()):
			var closest := Geometry2D.get_closest_point_to_segment(_points[i], top, bottom)
			var away := _points[i] - closest
			if away.length() >= reach:
				continue
			if away.length() < 0.01:
				away = Vector2(-signf(player.velocity.x) if player.velocity.x != 0.0 else 1.0, 0)
			_points[i] = closest + away.normalized() * reach
			_previous[i] = _points[i] - motion
			touched = true
		if touched:
			_on_touched(player.velocity.length())


## La lampadina l'ha toccata: la catena tintinna, il cavo fa scintille.
func _on_touched(speed: float) -> void:
	if _touch_cooldown > 0.0 or speed < 60.0 or kind == "rope":
		return
	_touch_cooldown = TOUCH_COOLDOWN * randf_range(0.8, 1.5)
	var strength := clampf(speed / Player.SPEED, 0.3, 1.0)
	if kind == "chain":
		_sound.volume_db = -14.0 + linear_to_db(strength)
		# Maglie di ferro pesanti: più gravi del barattolo.
		_sound.pitch_scale = randf_range(0.55, 0.7)
		_sound.play()
	else:
		SparkBurst.spawn(self, _points[segments], strength)


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
	match kind:
		"chain":
			_draw_chain(points)
		"cable":
			draw_polyline(points, CABLE, thickness, true)
			for i in range(1, points.size(), 2):
				var dir := (points[i] - points[i - 1]).normalized()
				var side := Vector2(-dir.y, dir.x) * thickness * 0.25
				draw_line(points[i - 1] + side, points[i] + side, CABLE_SHINE, 1.0)
		_:
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
	if kind == "cable":
		# Guaina strappata e fili di rame aperti a ventaglio.
		draw_rect(Rect2(-thickness * 0.7, -3, thickness * 1.4, 4), CABLE_SHINE)
		for x in [-3.0, -1.0, 1.0, 3.0]:
			draw_line(Vector2(x * 0.5, 0), Vector2(x * 1.8, 9 + absf(x)), COPPER, 1.5)
		draw_set_transform(Vector2.ZERO)
		return
	var color := METAL if kind == "chain" else ROPE
	match end_style:
		"knot":
			if kind == "chain":
				# Lucchetto in fondo alla catena.
				draw_arc(Vector2(0, 6), 5.0, PI, TAU, 8, CHAIN, 3.0)
				draw_rect(Rect2(-8, 6, 16, 14), CHAIN_DARK)
				draw_circle(Vector2(0, 12), 2.0, Color(0.08, 0.08, 0.09))
			else:
				draw_circle(Vector2.ZERO, thickness * 1.3, ROPE)
				draw_line(Vector2(-1, 0), Vector2(-3, 12), ROPE, 2.0)
				draw_line(Vector2(1, 0), Vector2(3, 10), ROPE, 2.0)
		"hook":
			draw_line(Vector2.ZERO, Vector2(0, 12), METAL, 4.0)
			draw_arc(Vector2(-8, 12), 8.0, 0.0, PI, 10, METAL, 4.0)
			draw_line(Vector2(-16, 12), Vector2(-16, 7), METAL, 4.0)
		"loop":
			draw_arc(Vector2(0, 12), 12.0, 0.0, TAU, 20, color, thickness)
		"hanged":
			_draw_hanged(Transform2D(down.angle() - PI / 2.0, end))
	draw_set_transform(Vector2.ZERO)


## Lampadina spenta appesa per il collo: il vetro (la testa) sta sopra il
## cappio, un po' reclinato, e l'attacco pende sotto. `base` è il sistema del
## fondo della fune (che scende lungo +y).
func _draw_hanged(base: Transform2D) -> void:
	# Ogni lampadina ha la testa reclinata in modo diverso (fisso per posizione).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(position)
	var head_tilt := rng.randf_range(0.12, 0.35) * (1.0 if rng.randf() < 0.5 else -1.0)
	var bulb := base * Transform2D(head_tilt, Vector2.ZERO) * Transform2D(0.0, Vector2(0, -NECK_Y))
	DeadBulb.draw_bulb(self, bulb, "off", "x", rng.randi())
	# Il cappio stretto attorno al collo e il nodo di lato.
	draw_set_transform_matrix(base * Transform2D(0.0, Vector2(1.0, 0.35), 0.0, Vector2.ZERO))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 20, ROPE_DARK, thickness * 1.6)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 20, ROPE, thickness)
	draw_set_transform_matrix(base)
	draw_circle(Vector2(-16, -3), thickness * 1.2, ROPE_DARK)


## Maglie lungo la catena, alternate: una vista di fronte (anello) e una di
## taglio (barretta), come si vede una catena vera.
func _draw_chain(points: PackedVector2Array) -> void:
	var link := thickness * LINK_RATIO
	var travelled := 0.0
	var index := 0
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var span := a.distance_to(b)
		var dir := (b - a) / maxf(span, 0.001)
		while travelled <= span:
			var center := a + dir * travelled
			if index % 2 == 0:
				draw_set_transform(center, dir.angle(), Vector2(1.0, 0.55))
				draw_arc(Vector2.ZERO, link * 0.6, 0.0, TAU, 12, CHAIN, thickness * 0.55)
				draw_set_transform(Vector2.ZERO)
			else:
				draw_line(center - dir * link * 0.6, center + dir * link * 0.6, CHAIN_DARK, thickness * 0.7)
			travelled += link * 0.85
			index += 1
		travelled -= span
