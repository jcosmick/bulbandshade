@tool
class_name PushBox
extends CharacterBody2D
## Cassa che il giocatore può spingere. Proietta ombre solide.

const GRAVITY := 2800.0
const MAX_FALL_SPEED := 1800.0
## Accelerazione quando viene spinta e frenata quando la si lascia (px/s²).
const PUSH_ACCEL := 2400.0
const PUSH_FRICTION := 4000.0
## Suono di trascinamento (loop): volume pieno, velocità a cui lo raggiunge
## e velocità di dissolvenza (1/s). Più va piano, più è basso e grave.
const SCRAPE_DB := -8.0
const SCRAPE_FULL_SPEED := 230.0
const SCRAPE_FADE := 6.0

@export var size := Vector2(160, 160):
	set(value):
		size = value
		queue_redraw()

var _push_speed := 0.0
var _start_position := Vector2.ZERO
## Dopo reset() la cassa sta ferma un frame di fisica: chi era al suo posto
## (es. la lampadina che ricompare al checkpoint) viene spostato solo al passo
## di fisica successivo, e la cassa altrimenti verrebbe respinta indietro.
var _settling := false
var _scrape: AudioStreamPlayer2D
var _scrape_amp := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("solids")
	add_to_group("casters")
	add_to_group("push_boxes")
	_start_position = global_position
	collision_mask = 1 | ShadowSystem.SHADOW_COLLISION_LAYER
	LevelKit.add_rect_collision(self, size, true)
	_scrape = Sfx.make_player_2d("push", self)


## Riporta la cassa dov'era all'inizio del livello.
func reset() -> void:
	global_position = _start_position
	velocity = Vector2.ZERO
	_push_speed = 0.0
	_settling = true
	_scrape_amp = 0.0
	_scrape.stop()


## Chiamata dal giocatore ogni frame in cui spinge.
func push(speed: float) -> void:
	_push_speed = speed


func get_world_polygon() -> PackedVector2Array:
	return global_transform * LevelKit.rect_points(size)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _settling:
		_settling = false
		_push_speed = 0.0
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	var accel := PUSH_ACCEL if _push_speed != 0.0 else PUSH_FRICTION
	velocity.x = move_toward(velocity.x, _push_speed, accel * delta)
	_push_speed = 0.0
	move_and_slide()
	_update_scrape(delta)


## Il legno striscia solo mentre la cassa scivola sul pavimento, e segue la sua velocità.
func _update_scrape(delta: float) -> void:
	var speed := absf(get_real_velocity().x) if is_on_floor() else 0.0
	var target := clampf(speed / SCRAPE_FULL_SPEED, 0.0, 1.0)
	_scrape_amp = move_toward(_scrape_amp, target, SCRAPE_FADE * delta)
	if _scrape_amp <= 0.0:
		_scrape.stop()
		return
	_scrape.volume_db = SCRAPE_DB + linear_to_db(_scrape_amp)
	_scrape.pitch_scale = lerpf(0.85, 1.0, _scrape_amp)
	if not _scrape.playing:
		# Ogni spinta riparte da un punto diverso del loop.
		_scrape.play(randf() * _scrape.stream.get_length())


func _draw() -> void:
	LevelKit.draw_crate(self, size, true)
