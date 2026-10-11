@tool
class_name Player
extends CharacterBody2D
## La lampadina: cammina, salta e fa un flash che genera ombre solide.

## Emesso a ogni flash: punto di origine della luce e raggio.
signal flashed(origin: Vector2, radius: float)
## Emesso quando la lampadina va in cortocircuito (acqua).
signal died

const SPEED := 520.0
const GROUND_ACCEL := 4200.0
const AIR_ACCEL := 2600.0
const GRAVITY := 2800.0
const JUMP_VELOCITY := -1250.0
## Gravità extra quando si rilascia il salto presto (salto variabile).
const JUMP_CUT_GRAVITY := 2.5
const MAX_FALL_SPEED := 1800.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.12
const PUSH_SPEED := 230.0
const LIGHT_OFFSET := Vector2(0, -16)
const GLOW_RADIUS := 300.0

const GLASS_COLOR := Color(1.0, 0.95, 0.72)
const FILAMENT_COLOR := Color(1.0, 0.55, 0.12)
const FILAMENT_DIM := Color(0.45, 0.3, 0.2)
const METAL_COLOR := Color(0.62, 0.62, 0.66)
const METAL_DARK := Color(0.38, 0.38, 0.42)
const EYE_COLOR := Color(0.15, 0.1, 0.05)
const DEAD_GLASS := Color(0.45, 0.47, 0.52)
const SPARK_COLOR := Color(0.7, 0.9, 1.0)

@export var flash_radius := 750.0
## Secondi di ricarica tra un flash e l'altro.
@export var flash_cooldown := 2.5

var controls_enabled := true
var dead := false
var _dead_time := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _flash_cooldown := 0.0
var _facing := 1.0
var _squash := Vector2.ONE
var _glow: PointLight2D
var _flash_light: PointLight2D
var _flash_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := CapsuleShape2D.new()
	shape.radius = 30.0
	shape.height = 104.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	# Cammina sui solidi (layer 1) e sulle ombre solide.
	collision_mask = 1 | ShadowSystem.SHADOW_COLLISION_LAYER
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 24.0
	floor_constant_speed = true
	_glow = LevelKit.make_light(self, GLOW_RADIUS, 1.0, true)
	_glow.position = LIGHT_OFFSET
	_flash_light = LevelKit.make_light(self, flash_radius, 0.0, true)
	_flash_light.position = LIGHT_OFFSET
	# Solo il flash si ferma contro i fasci delle finestre.
	_flash_light.shadow_item_cull_mask = 1 | ShadowSystem.BEAM_OCCLUDER_MASK


func light_origin() -> Vector2:
	return global_position + LIGHT_OFFSET


## Cortocircuito: la lampadina si blocca, sfrigola e si spegne.
func die() -> void:
	if dead or not controls_enabled:
		return
	dead = true
	_dead_time = 0.0
	controls_enabled = false
	set_physics_process(false)
	velocity = Vector2.ZERO
	_glow.energy = 0.0
	Sfx.play("death")
	died.emit()


## Ricompare viva in un punto (checkpoint).
func respawn(at: Vector2) -> void:
	dead = false
	collision_layer = 1
	collision_mask = 1 | ShadowSystem.SHADOW_COLLISION_LAYER
	controls_enabled = true
	set_physics_process(true)
	global_position = at
	velocity = Vector2.ZERO
	_flash_cooldown = 0.0
	_squash = Vector2(0.7, 1.3)


## Ricarica del flash: 0 = appena usato, 1 = pronto.
func flash_charge() -> float:
	return 1.0 - clampf(_flash_cooldown / flash_cooldown, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var direction := Input.get_axis("move_left", "move_right") if controls_enabled else 0.0

	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME
	else:
		_jump_buffer -= delta

	if not is_on_floor():
		var gravity := GRAVITY
		if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
			gravity *= JUMP_CUT_GRAVITY
		velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		_squash = Vector2(0.75, 1.25)

	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
	if direction != 0.0:
		_facing = signf(direction)

	var was_on_floor := is_on_floor()
	move_and_slide()
	if not was_on_floor and is_on_floor():
		_squash = Vector2(1.25, 0.8)

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var box := collision.get_collider() as PushBox
		if box and direction != 0.0 and absf(collision.get_normal().x) > 0.7 \
				and signf(direction) == -signf(collision.get_normal().x):
			box.push(direction * PUSH_SPEED)

	_flash_cooldown -= delta
	if controls_enabled and Input.is_action_just_pressed("flash"):
		try_flash()


## Flash se la ricarica è pronta (force lo fa comunque, es. nel menu).
func try_flash(force := false) -> void:
	if _flash_cooldown > 0.0 and not force:
		return
	_flash_cooldown = flash_cooldown
	_squash = Vector2(1.2, 0.85)
	if _flash_tween:
		_flash_tween.kill()
	_flash_light.energy = 2.4
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_light, "energy", 0.0, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sfx.play("flash")
	flashed.emit(light_origin(), flash_radius)


## Animazione di vittoria: la lampadina si avvita nel portalampada.
func enter_socket(target: Vector2) -> Tween:
	controls_enabled = false
	set_physics_process(false)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween()
	tween.tween_property(self, "global_position", target + Vector2(0, -90), 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _squash = Vector2(1.25, 0.8))
	tween.tween_property(_glow, "energy", 1.6, 0.6)
	tween.parallel().tween_property(_glow, "texture_scale", _glow.texture_scale * 5.0, 1.2)
	return tween


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, 12.0 * delta))
	if dead:
		_dead_time += delta
		# Sfarfallio del cortocircuito, poi buio.
		_glow.energy = 1.2 * absf(sin(_dead_time * 40.0)) * maxf(0.0, 1.0 - _dead_time * 2.0)
		queue_redraw()
		return
	# Mentre si ricarica la lampadina è più fioca.
	if controls_enabled:
		_glow.energy = lerpf(0.55, 1.0, flash_charge())
	queue_redraw()


func _draw() -> void:
	# Disegno relativo ai piedi, così lo schiacciamento resta appoggiato a terra.
	draw_set_transform(Vector2(0, 52), 0.0, _squash)
	var glass_center := Vector2(0, -68)
	var glass := DEAD_GLASS if dead else GLASS_COLOR
	draw_circle(glass_center, 38.0, glass)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-27, -46), Vector2(27, -46), Vector2(17, -32), Vector2(-17, -32)
	]), glass)
	draw_polyline(PackedVector2Array([
		Vector2(-9, -34), Vector2(-9, -56), Vector2(-5, -63), Vector2(0, -56),
		Vector2(5, -63), Vector2(9, -56), Vector2(9, -34)
	]), FILAMENT_COLOR.lerp(FILAMENT_DIM, 1.0 - flash_charge()), 3.0)
	draw_rect(Rect2(-17, -34, 34, 26), METAL_COLOR)
	for i in 3:
		draw_line(Vector2(-17, -30 + i * 8), Vector2(17, -27 + i * 8), METAL_DARK, 3.0)
	draw_rect(Rect2(-9, -8, 18, 8), Color(0.2, 0.2, 0.22))
	var eye_x := 7.0 * _facing
	draw_circle(Vector2(eye_x - 11, -80), 5.0, EYE_COLOR)
	draw_circle(Vector2(eye_x + 11, -80), 5.0, EYE_COLOR)
	draw_arc(glass_center, 29.0, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.75), 4.0)
	if dead and _dead_time < 0.6:
		# Scintille a zig-zag attorno al vetro.
		for i in 5:
			var angle := i * TAU / 5.0 + _dead_time * 9.0
			var start := glass_center + Vector2.from_angle(angle) * 42.0
			var mid := start + Vector2.from_angle(angle + 0.8) * 12.0
			var end := start + Vector2.from_angle(angle) * 22.0
			draw_polyline(PackedVector2Array([start, mid, end]), SPARK_COLOR, 3.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
