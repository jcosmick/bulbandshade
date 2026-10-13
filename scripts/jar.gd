@tool
class_name Jar
extends Node2D
## Barattolo decorativo che la lampadina calcia camminandoci contro: non la
## blocca e non fa ombra, ma viene spinto, saltella e può cadere su un
## fianco. I barattoli si possono impilare: ognuno fa da appoggio agli altri
## (ma non alla lampadina). Quando la lampadina riparte torna al suo posto.
## L'origine è la base: appoggiato va a y = pavimento (o sulla cima di un
## altro barattolo).

@export_enum("jar", "can", "bottle") var kind := "jar":
	set(value):
		kind = value
		queue_redraw()

## Layer dei corpi dei barattoli: lo vedono solo gli altri barattoli, non la
## lampadina né le gocce.
const JAR_LAYER := 1 << 2
const SIZES := {"jar": Vector2(31, 41), "can": Vector2(29, 36), "bottle": Vector2(22, 55)}
## Intonazione del colpo: barattolo e bottiglia usano lo stesso suono di vetro.
const SOUND_PITCH := {"jar": 0.92, "can": 1.0, "bottle": 1.12}
const GRAVITY := 2400.0
const MAX_FALL_SPEED := 1800.0
const FRICTION := 1500.0
## Frazione della velocità della lampadina trasmessa al barattolo, e calcio minimo.
const KICK := 0.9
const MIN_KICK := 180.0
## Velocità minima verso il barattolo per calciarlo camminando.
const KICK_THRESHOLD := 60.0
## Velocità di caduta della lampadina oltre la quale atterrarci sopra lo calcia.
const STOMP_SPEED := 300.0
const HOP_MIN := 250.0
const HOP_MAX := 420.0
const SPIN_MIN := 6.0
const SPIN_MAX := 14.0
## Rimbalzo contro i muri e sul pavimento quando cade forte.
const BOUNCE := 0.35
const BOUNCE_SPEED := 500.0
## Rientro dai bordi della base dei raggi che cercano l'appoggio.
const EDGE_INSET := 2.0
## Velocità con cui scivola giù un barattolo appoggiato solo su un bordo.
const TIP_SPEED := 90.0
## Un barattolo che ne urta un altro gli passa questa frazione della velocità.
const NUDGE := 0.8
## Oltre questa caduta dal punto di partenza il barattolo sparisce.
const MAX_DROP := 4000.0

const GLASS := Color(0.3, 0.35, 0.4)
const GLASS_LIGHT := Color(0.4, 0.46, 0.52)
const CONTENT := Color(0.27, 0.22, 0.22)
const LID := Color(0.33, 0.31, 0.29)
const TIN := Color(0.36, 0.35, 0.37)
const TIN_DARK := Color(0.25, 0.24, 0.27)
const LABEL := Color(0.38, 0.25, 0.23)
const BOTTLE := Color(0.2, 0.29, 0.23)
const BOTTLE_LIGHT := Color(0.28, 0.38, 0.3)

var _velocity := Vector2.ZERO
var _angle := 0.0
var _spin := 0.0
var _grounded := true
var _start_position := Vector2.ZERO
var _area: Area2D
var _body: StaticBody2D
var _body_shape: RectangleShape2D
var _body_collision: CollisionShape2D
var _sound: AudioStreamPlayer2D


func _ready() -> void:
	z_index = -4
	if Engine.is_editor_hint():
		return
	add_to_group("jars")
	_start_position = global_position
	# Area che sente la lampadina (layer 1) senza bloccarla.
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = _size() + Vector2(8, 4)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -_size().y / 2.0)
	_area.add_child(collision)
	add_child(_area)
	# Corpo su cui si appoggiano gli altri barattoli impilati.
	_body = StaticBody2D.new()
	_body.collision_layer = JAR_LAYER
	_body.collision_mask = 0
	_body_shape = RectangleShape2D.new()
	_body_collision = CollisionShape2D.new()
	_body_collision.shape = _body_shape
	_body.add_child(_body_collision)
	add_child(_body)
	_update_body()
	_sound = Sfx.make_player_2d("can" if kind == "can" else "glass", self)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_check_kick()
	if _grounded and _velocity == Vector2.ZERO:
		# Fermo: ricade solo se sparisce il pavimento (es. un'ombra solida).
		if _is_stable(_probe_ground(-2.0, 4.0)):
			return
		_grounded = false
	_velocity.y = minf(_velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	_move_horizontal(delta)
	_move_vertical(delta)
	if _grounded:
		_velocity.x = move_toward(_velocity.x, 0.0, FRICTION * delta)
	else:
		_angle += _spin * delta
	if global_position.y > _start_position.y + MAX_DROP:
		set_physics_process(false)
		hide()
	_update_body()
	queue_redraw()


## Riporta il barattolo dov'era all'inizio del livello, dritto e fermo.
func reset() -> void:
	global_position = _start_position
	_velocity = Vector2.ZERO
	_angle = 0.0
	_spin = 0.0
	_grounded = true
	set_physics_process(true)
	show()
	_update_body()
	queue_redraw()


## Spinta ricevuta da un altro barattolo che gli finisce contro.
func nudge(speed: float) -> void:
	_velocity = Vector2(speed, -HOP_MIN * 0.5)
	_spin = signf(speed) * SPIN_MIN
	_grounded = false


## Il corpo segue l'ingombro attuale (in piedi o sdraiato).
func _update_body() -> void:
	_body_shape.size = _half_extent() * 2.0
	_body_collision.position = Vector2(0, -_center_height())


## La lampadina lo calcia se ci cammina contro o ci atterra sopra.
func _check_kick() -> void:
	for body in _area.get_overlapping_bodies():
		var player := body as Player
		if player == null or player.dead:
			continue
		var dir := signf(global_position.x - player.global_position.x)
		if dir == 0.0:
			dir = 1.0
		var toward := player.velocity.x * dir
		if toward < KICK_THRESHOLD and player.velocity.y < STOMP_SPEED:
			continue
		var target := maxf(absf(player.velocity.x) * KICK, MIN_KICK)
		# Già lanciato via in quella direzione: non ricalciarlo a ogni frame.
		if _velocity.x * dir >= target * 0.8:
			continue
		_velocity = Vector2(target * dir, -randf_range(HOP_MIN, HOP_MAX))
		_spin = dir * randf_range(SPIN_MIN, SPIN_MAX)
		_grounded = false
		_play_sound(1.0)


func _move_horizontal(delta: float) -> void:
	if _velocity.x == 0.0:
		return
	var side := signf(_velocity.x)
	var half := _half_extent().x
	var middle := global_position + Vector2(0, -_center_height())
	var hit := _ray(middle, middle + Vector2(_velocity.x * delta + side * half, 0))
	if hit.is_empty():
		global_position.x += _velocity.x * delta
		return
	global_position.x = hit.position.x - side * half
	var other := (hit.collider as Node).get_parent() as Jar
	if other != null:
		# Urta un altro barattolo: lo spinge e rallenta.
		other.nudge(_velocity.x * NUDGE)
		_velocity.x *= 1.0 - NUDGE
		_play_sound(0.6)
		return
	_velocity.x *= -BOUNCE
	_spin *= -0.5
	_play_sound(0.6)


func _move_vertical(delta: float) -> void:
	var dy := _velocity.y * delta
	if dy <= 0.0:
		global_position.y += dy
		_grounded = false
		return
	var probe := _probe_ground(-4.0, dy + 1.0)
	var hit: Dictionary = probe.hit
	if hit.is_empty():
		global_position.y += dy
		_grounded = false
		return
	global_position.y = hit.position.y
	if _velocity.y > BOUNCE_SPEED:
		_velocity.y *= -BOUNCE
		_spin *= 0.6
		_play_sound(0.8)
		return
	if not _is_stable(probe):
		# Appoggiato solo su un bordo: si inclina e scivola dal lato libero.
		var side := 1.0 if probe.left else -1.0
		_velocity = Vector2(side * maxf(absf(_velocity.x), TIP_SPEED), 0.0)
		_spin = side * SPIN_MIN
		_grounded = false
		return
	if not _grounded:
		# Resta dritto, capovolto o sdraiato: l'orientamento più vicino a come è caduto.
		_angle = snappedf(_angle, PI / 2.0)
		_play_sound(0.5)
	_velocity.y = 0.0
	_grounded = true


## Raggi verso il basso dal bordo sinistro, dal centro e dal bordo destro
## della base (tra from_dy e to_dy): restituisce l'appoggio più alto e quali
## raggi l'hanno trovato. Così un barattolo a cavallo di due sotto non cade
## nello spazio in mezzo.
func _probe_ground(from_dy: float, to_dy: float) -> Dictionary:
	var half := _half_extent().x - EDGE_INSET
	var best := {}
	var found: Array[bool] = []
	for x in [-half, 0.0, half]:
		var base := global_position + Vector2(x, 0)
		var hit := _ray(base + Vector2(0, from_dy), base + Vector2(0, to_dy), true)
		found.append(not hit.is_empty())
		if not hit.is_empty() and (best.is_empty() or hit.position.y < best.position.y):
			best = hit
	return {"hit": best, "left": found[0], "center": found[1], "right": found[2]}


## Sta in equilibrio se è appoggiato al centro o su entrambi i bordi.
func _is_stable(probe: Dictionary) -> bool:
	return probe.center or (probe.left and probe.right)


## Raggio sui solidi, sulle ombre solide e sugli altri barattoli, ignorando
## la lampadina. Con from_inside un barattolo messo un po' dentro a quello
## sotto lo trova lo stesso (e ne risale fuori), invece di attraversarlo.
func _ray(from: Vector2, to: Vector2, from_inside := false) -> Dictionary:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
			from, to, 1 | ShadowSystem.SHADOW_COLLISION_LAYER | JAR_LAYER, [_body.get_rid()])
	query.hit_from_inside = from_inside
	for i in 4:
		var hit := space.intersect_ray(query)
		if hit.is_empty() or not hit.collider is Player:
			return hit
		query.exclude = query.exclude + [hit.rid]
	return {}


func _play_sound(strength: float) -> void:
	_sound.volume_db = linear_to_db(strength) - 6.0
	# Vetro: la bottiglia, più sottile, suona più acuta del barattolo. I colpi deboli
	# suonano un filo più gravi, come un oggetto che vibra meno.
	var pitch: float = SOUND_PITCH[kind] * lerpf(0.94, 1.0, strength)
	_sound.pitch_scale = pitch * randf_range(0.95, 1.05)
	_sound.play()


func _size() -> Vector2:
	return SIZES[kind]


## Quanto è alto il centro sopra la base: cambia se il barattolo è sdraiato.
func _center_height() -> float:
	return lerpf(_size().y, _size().x, absf(sin(_angle))) / 2.0


## Mezze dimensioni dell'ingombro attuale (in piedi o sdraiato).
func _half_extent() -> Vector2:
	var s := _size()
	var lying := absf(sin(_angle))
	return Vector2(lerpf(s.x, s.y, lying), lerpf(s.y, s.x, lying)) / 2.0


func _draw() -> void:
	var s := _size()
	var h := s / 2.0
	draw_set_transform(Vector2(0, -_center_height()), _angle)
	match kind:
		"jar":
			draw_rect(Rect2(-h.x, -h.y + 6.0, s.x, s.y - 6.0), GLASS)
			draw_rect(Rect2(-h.x + 3.0, 0.0, s.x - 6.0, h.y - 3.0), CONTENT)
			draw_line(Vector2(-h.x + 5.0, -h.y + 10.0), Vector2(-h.x + 5.0, h.y - 6.0), GLASS_LIGHT, 3.0)
			draw_rect(Rect2(-h.x + 2.0, -h.y, s.x - 4.0, 7.0), LID)
		"can":
			draw_rect(Rect2(-h, s), TIN)
			draw_rect(Rect2(-h.x, -h.y + 7.0, s.x, s.y - 14.0), LABEL)
			draw_line(Vector2(-h.x, -h.y + 1.5), Vector2(h.x, -h.y + 1.5), TIN_DARK, 3.0)
			draw_line(Vector2(-h.x, h.y - 1.5), Vector2(h.x, h.y - 1.5), TIN_DARK, 3.0)
		"bottle":
			var shoulder := -h.y + 18.0
			draw_rect(Rect2(-h.x, shoulder, s.x, s.y - 18.0), BOTTLE)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-h.x, shoulder), Vector2(h.x, shoulder),
				Vector2(h.x / 2.0 + 1.0, shoulder - 8.0), Vector2(-h.x / 2.0 - 1.0, shoulder - 8.0),
			]), BOTTLE)
			draw_rect(Rect2(-h.x / 2.0, -h.y, s.x / 2.0, 11.0), BOTTLE)
			draw_line(Vector2(-h.x + 4.0, shoulder + 4.0), Vector2(-h.x + 4.0, h.y - 5.0), BOTTLE_LIGHT, 3.0)
	draw_set_transform(Vector2.ZERO)
