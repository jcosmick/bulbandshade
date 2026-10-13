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
## Velocità di caduta minima per il suono di atterraggio e quella del tonfo più forte.
const LAND_SOUND_MIN_SPEED := 450.0
const LAND_SOUND_MAX_SPEED := 1800.0
## Ogni quanti pixel percorsi a terra suona un passo, e sotto che velocità non si cammina.
const STEP_DISTANCE := 120.0
const STEP_MIN_SPEED := 60.0
## Fermo da più di così si riparte da capo (le soste brevi non azzerano il ritmo).
const STEP_IDLE_RESET := 0.15
## Camminata: quanto si solleva e quanto dondola la lampadina a ogni passo.
const WALK_BOB := 7.0
const WALK_TILT := 0.065
## Da ferma: respiro leggero (ampiezza e velocità), sbattere d'occhi e occhiate in giro.
const IDLE_BREATH := 0.022
const IDLE_BREATH_SPEED := 2.4
const BLINK_MIN_INTERVAL := 2.0
const BLINK_MAX_INTERVAL := 5.0
const BLINK_DURATION := 0.14
const LOOK_MIN_INTERVAL := 1.2
const LOOK_MAX_INTERVAL := 3.5
const LOOK_RANGE := Vector2(4.0, 2.5)

const GLASS_COLOR := Color(1.0, 0.95, 0.72)
const FILAMENT_COLOR := Color(1.0, 0.55, 0.12)
const FILAMENT_DIM := Color(0.45, 0.3, 0.2)
const METAL_COLOR := Color(0.62, 0.62, 0.66)
const METAL_DARK := Color(0.38, 0.38, 0.42)
const EYE_COLOR := Color(0.15, 0.1, 0.05)
const DEAD_GLASS := Color(0.45, 0.47, 0.52)
const SPARK_COLOR := Color(0.7, 0.9, 1.0)
## Sfarfallio disattivato per ora (potrebbe spaventare): al suo posto c'è l'affievolimento.
const FLICKER_ENABLED := false
## Ogni tanto la lampadina sfarfalla: intervallo casuale (secondi) tra uno sfarfallio e l'altro.
const FLICKER_MIN_INTERVAL := 20.0
const FLICKER_MAX_INTERVAL := 50.0
## Durate alternate spenta/accesa dello sfarfallio (inizia e finisce spenta).
const FLICKER_PATTERN: Array[float] = [0.07, 0.06, 0.05, 0.12, 0.22]
## Affievolimento: ogni tanto la luce cala un poco, tremola appena e torna normale.
const DIM_MIN_INTERVAL := 12.0
const DIM_MAX_INTERVAL := 30.0
const DIM_DURATION := 1.8
const DIM_DEPTH := 0.25
const DIM_JITTER := 0.05
## Camminando su un'ombra, dai piedi si staccano pallini neri che salgono e spariscono.
const SHADOW_DUST_AMOUNT := 10
const SHADOW_DUST_LIFETIME := 0.55

@export var flash_radius := 750.0
## Secondi di ricarica tra un flash e l'altro.
@export var flash_cooldown := 2.5
## Solo editor: mostra le curve del salto (vedi JumpArc).
@export var show_jump_arc := true:
	set(value):
		show_jump_arc = value
		queue_redraw()

var controls_enabled := true
var dead := false
var _dead_time := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _flash_cooldown := 0.0
var _step_travel := 0.0
var _step_idle := 0.0
var _step_count := 0
## 0 = ferma, 1 = camminata piena (sfuma per non scattare all'avvio e all'arresto).
var _walk_blend := 0.0
var _facing := 1.0
var _squash := Vector2.ONE
var _glow: PointLight2D
var _flash_light: PointLight2D
var _flash_tween: Tween
var _flicker_wait := 0.0
## Tempo dall'inizio dello sfarfallio in corso, negativo se non sta sfarfallando.
var _flicker_time := -1.0
var _flickering_off := false
var _dim_wait := 0.0
## Tempo dall'inizio dell'affievolimento in corso, negativo se la luce è normale.
var _dim_time := -1.0
var _idle_time := 0.0
var _blink_wait := 0.0
## Tempo dall'inizio dell'ammiccamento in corso, negativo se gli occhi sono aperti.
var _blink_time := -1.0
var _look_wait := 0.0
var _look_target := Vector2.ZERO
var _look := Vector2.ZERO
var _shadow_dust: CPUParticles2D


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
	_flicker_wait = randf_range(FLICKER_MIN_INTERVAL, FLICKER_MAX_INTERVAL)
	_dim_wait = randf_range(DIM_MIN_INTERVAL, DIM_MAX_INTERVAL)
	_blink_wait = randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)
	_look_wait = randf_range(LOOK_MIN_INTERVAL, LOOK_MAX_INTERVAL)
	_shadow_dust = _make_shadow_dust()


## Pallini neri ai piedi, come quelli dell'ombra che si sfalda ma più piccoli:
## restano nel mondo (non seguono la lampadina), salgono piano e si rimpiccioliscono.
func _make_shadow_dust() -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.position = Vector2(0, 52)
	dust.local_coords = false
	dust.emitting = false
	dust.amount = SHADOW_DUST_AMOUNT
	dust.lifetime = SHADOW_DUST_LIFETIME
	dust.randomness = 0.5
	dust.lifetime_randomness = 0.4
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(16, 2)
	dust.direction = Vector2.UP
	dust.spread = 25.0
	dust.gravity = Vector2(0, -40)
	dust.initial_velocity_min = 15.0
	dust.initial_velocity_max = 40.0
	dust.texture = ShadowPlatform.circle_texture()
	dust.scale_amount_min = 0.2
	dust.scale_amount_max = 0.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	dust.scale_amount_curve = curve
	dust.color = ShadowPlatform.FILL
	add_child(dust)
	return dust


func light_origin() -> Vector2:
	return global_position + LIGHT_OFFSET


## Cortocircuito: la lampadina si blocca, sfrigola e si spegne.
func die() -> void:
	if dead or not controls_enabled:
		return
	dead = true
	_dead_time = 0.0
	_stop_flicker()
	controls_enabled = false
	set_physics_process(false)
	_shadow_dust.emitting = false
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
		Sfx.play("jump", -3.0, 0.12)

	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
	if direction != 0.0:
		_facing = signf(direction)

	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	var push_velocity := velocity.x
	move_and_slide()
	if not was_on_floor and is_on_floor():
		_squash = Vector2(1.25, 0.8)
		_play_land(fall_speed)
	_update_steps(delta)
	var walking := is_on_floor() and absf(get_real_velocity().x) >= STEP_MIN_SPEED
	_shadow_dust.emitting = walking and _on_shadow()

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var box := collision.get_collider() as PushBox
		if box and direction != 0.0 and absf(collision.get_normal().x) > 0.7 \
				and signf(direction) == -signf(collision.get_normal().x):
			box.push(direction * PUSH_SPEED)
			# Lo slide azzererebbe la velocità contro la cassa: ripartendo da 0
			# la lampadina resterebbe indietro e la spinta andrebbe a scatti.
			velocity.x = push_velocity

	var was_charging := _flash_cooldown > 0.0
	_flash_cooldown -= delta
	if was_charging and _flash_cooldown <= 0.0 and controls_enabled:
		Sfx.play("flash_ready", -14.0, 0.0)
	if controls_enabled and Input.is_action_just_pressed("flash"):
		if _flash_cooldown > 0.0:
			Sfx.play("flash_dud", -6.0, 0.06)
		try_flash()


## Passi: uno ogni STEP_DISTANCE pixel percorsi camminando a terra.
func _update_steps(delta: float) -> void:
	var speed := absf(get_real_velocity().x)
	if is_on_floor() and speed < STEP_MIN_SPEED:
		_step_idle += delta
	if not is_on_floor() or _step_idle > STEP_IDLE_RESET:
		# Ripartendo, il primo passo arriva quasi subito.
		_step_travel = STEP_DISTANCE * 0.8
		_step_idle = 0.0
		return
	if speed < STEP_MIN_SPEED:
		return
	_step_idle = 0.0
	_step_travel += speed * delta
	if _step_travel >= STEP_DISTANCE:
		_step_travel -= STEP_DISTANCE
		_step_count += 1
		Sfx.play("shadow_step" if _on_shadow() else "step", -16.0, 0.08)


## Vero se il pavimento sotto la lampadina è un'ombra solida.
## Le slide collision non bastano: a terra velocity.y è 0 e il pavimento lo tiene
## il floor snap, che non genera collisioni; si prova quindi una discesa a vuoto.
func _on_shadow() -> bool:
	var collision := move_and_collide(-up_direction * floor_snap_length, true)
	if collision == null:
		return false
	var body := collision.get_collider() as CollisionObject2D
	return body != null and body.collision_layer & ShadowSystem.SHADOW_COLLISION_LAYER != 0


## Tonfo di atterraggio: più forte e più grave quanto più si cade veloci.
func _play_land(fall_speed: float) -> void:
	if fall_speed < LAND_SOUND_MIN_SPEED:
		return
	var weight := inverse_lerp(LAND_SOUND_MIN_SPEED, LAND_SOUND_MAX_SPEED, minf(fall_speed, LAND_SOUND_MAX_SPEED))
	Sfx.play("land", lerpf(-14.0, -2.0, weight), 0.06, lerpf(1.1, 0.85, weight))


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
	Sfx.play("flash", 0.0, 0.0)
	flashed.emit(light_origin(), flash_radius)


## Animazione di vittoria: la lampadina si avvita nel portalampada.
func enter_socket(target: Vector2) -> Tween:
	controls_enabled = false
	_stop_flicker()
	set_physics_process(false)
	_shadow_dust.emitting = false
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
	var walking := not dead and is_on_floor() and absf(get_real_velocity().x) >= STEP_MIN_SPEED
	_walk_blend = move_toward(_walk_blend, 1.0 if walking else 0.0, 8.0 * delta)
	if dead:
		_dead_time += delta
		# Sfarfallio del cortocircuito, poi buio.
		_glow.energy = 1.2 * absf(sin(_dead_time * 40.0)) * maxf(0.0, 1.0 - _dead_time * 2.0)
		queue_redraw()
		return
	# Mentre si ricarica la lampadina è più fioca.
	if controls_enabled:
		if FLICKER_ENABLED:
			_update_flicker(delta)
		else:
			_update_dim(delta)
		_glow.energy = 0.0 if _flickering_off else lerpf(0.55, 1.0, flash_charge()) * _dim_factor()
	_update_idle(delta)
	queue_redraw()


## Vita da ferma: respira sempre, sbatte gli occhi e, se non cammina, si guarda attorno.
func _update_idle(delta: float) -> void:
	_idle_time += delta
	if _blink_time >= 0.0:
		_blink_time += delta
		if _blink_time >= BLINK_DURATION:
			_blink_time = -1.0
			# Ogni tanto un doppio ammiccamento.
			_blink_wait = 0.12 if randf() < 0.2 else randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)
	else:
		_blink_wait -= delta
		if _blink_wait <= 0.0:
			_blink_time = 0.0
	var idle := is_on_floor() and _walk_blend == 0.0 and controls_enabled
	if not idle:
		_look_target = Vector2.ZERO
		_look_wait = randf_range(LOOK_MIN_INTERVAL, LOOK_MAX_INTERVAL)
	else:
		_look_wait -= delta
		if _look_wait <= 0.0:
			_look_wait = randf_range(LOOK_MIN_INTERVAL, LOOK_MAX_INTERVAL)
			# Ogni tanto torna a guardare davanti a sé.
			_look_target = Vector2.ZERO if randf() < 0.4 else Vector2(
				randf_range(-LOOK_RANGE.x, LOOK_RANGE.x), randf_range(-LOOK_RANGE.y, LOOK_RANGE.y))
	_look = _look.lerp(_look_target, minf(1.0, 14.0 * delta))


## Apertura degli occhi: 1 = aperti, 0 = chiusi a metà ammiccamento.
func _eye_open() -> float:
	if _blink_time < 0.0:
		return 1.0
	return absf(1.0 - 2.0 * _blink_time / BLINK_DURATION)


func _draw_eye(center: Vector2, radius: float, open: float) -> void:
	if open < 0.2:
		draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), EYE_COLOR, 2.5)
		return
	var points := PackedVector2Array()
	for i in 12:
		var angle := i * TAU / 12.0
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * open))
	draw_colored_polygon(points, EYE_COLOR)


## Sfarfallio casuale: per un attimo la lampadina si spegne e si riaccende.
func _update_flicker(delta: float) -> void:
	if _flicker_time < 0.0:
		_flicker_wait -= delta
		if _flicker_wait <= 0.0:
			_flicker_time = 0.0
		else:
			return
	_flicker_time += delta
	var t := _flicker_time
	for i in FLICKER_PATTERN.size():
		t -= FLICKER_PATTERN[i]
		if t < 0.0:
			_set_flickering_off(i % 2 == 0)
			return
	_set_flickering_off(false)
	_stop_flicker()


func _update_dim(delta: float) -> void:
	if _dim_time < 0.0:
		_dim_wait -= delta
		if _dim_wait <= 0.0:
			_dim_time = 0.0
		return
	_dim_time += delta
	if _dim_time >= DIM_DURATION:
		_dim_time = -1.0
		_dim_wait = randf_range(DIM_MIN_INTERVAL, DIM_MAX_INTERVAL)


## Moltiplicatore della luce: cala dolcemente e risale, con un tremolio appena accennato.
func _dim_factor() -> float:
	if _dim_time < 0.0:
		return 1.0
	var envelope := sin(_dim_time / DIM_DURATION * PI)
	var jitter := sin(_dim_time * 37.0) * sin(_dim_time * 23.0) * DIM_JITTER
	return 1.0 - (DIM_DEPTH + jitter) * envelope


## Spegne/riaccende la luce dello sfarfallio, con lo scatto del filamento a ogni cambio.
func _set_flickering_off(off: bool) -> void:
	if off != _flickering_off:
		Sfx.play("flicker_off" if off else "flicker_on", -12.0, 0.1)
	_flickering_off = off


func _stop_flicker() -> void:
	_flicker_time = -1.0
	_flickering_off = false
	_flicker_wait = randf_range(FLICKER_MIN_INTERVAL, FLICKER_MAX_INTERVAL)


func _draw() -> void:
	# Disegno relativo ai piedi, così lo schiacciamento resta appoggiato a terra.
	# Camminata a tempo coi passi: il suono parte quando la fase torna a 0,
	# cioè con la lampadina giù e inclinata sul "piede" d'appoggio.
	var phase := _step_count + _step_travel / STEP_DISTANCE
	var bob := -absf(sin(phase * PI)) * WALK_BOB * _walk_blend
	var tilt := cos(phase * PI) * WALK_TILT * _walk_blend
	# Respiro: si allunga e si stringe appena, sparisce mentre cammina.
	var breath := sin(_idle_time * IDLE_BREATH_SPEED) * IDLE_BREATH * (1.0 - _walk_blend)
	if dead:
		breath = 0.0
	draw_set_transform(Vector2(0, 52 + bob), tilt, _squash * Vector2(1.0 - breath * 0.6, 1.0 + breath))
	var glass_center := Vector2(0, -68)
	var glass := DEAD_GLASS if dead or _flickering_off else GLASS_COLOR
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
	var eye_center := Vector2(7.0 * _facing, -80) + _look
	var eye_open := 1.0 if dead else _eye_open()
	_draw_eye(eye_center + Vector2(-11, 0), 5.0, eye_open)
	_draw_eye(eye_center + Vector2(11, 0), 5.0, eye_open)
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
	if Engine.is_editor_hint() and show_jump_arc:
		JumpArc.draw_arcs(self, Vector2(0, 52), 400.0)
