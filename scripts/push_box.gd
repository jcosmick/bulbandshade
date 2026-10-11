@tool
class_name PushBox
extends CharacterBody2D
## Cassa che il giocatore può spingere. Proietta ombre solide.

const GRAVITY := 2800.0
const MAX_FALL_SPEED := 1800.0

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


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("solids")
	add_to_group("casters")
	add_to_group("push_boxes")
	_start_position = global_position
	collision_mask = 1 | ShadowSystem.SHADOW_COLLISION_LAYER
	LevelKit.add_rect_collision(self, size, true)


## Riporta la cassa dov'era all'inizio del livello.
func reset() -> void:
	global_position = _start_position
	velocity = Vector2.ZERO
	_push_speed = 0.0
	_settling = true


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
	velocity.x = _push_speed
	_push_speed = 0.0
	move_and_slide()


func _draw() -> void:
	LevelKit.draw_crate(self, size, true)
