class_name CutsceneWalker
extends CharacterBody2D
## Mini lampadina guidata da una cutscene: cammina e salta con la stessa fisica
## del giocatore (vedi Player), comandata con direction e jump().
## L'origine è il centro del vetro, come MiniBulbSprite.

## Velocità di caduta minima per il suono di atterraggio.
const LAND_SOUND_MIN_SPEED := 450.0

var color := Color(0.35, 0.6, 1.0)
## -1 sinistra, 0 fermo, 1 destra.
var direction := 0.0
## Se false attraversa tutto (es. mentre entra in scena dall'alto).
var solid := true:
	set(value):
		solid = value
		collision_mask = 1 | ShadowSystem.SHADOW_COLLISION_LAYER if value else 0
var sprite: MiniBulbSprite

var _jump_requested := false
var _time := 0.0


func _ready() -> void:
	var shape := CapsuleShape2D.new()
	shape.radius = 18.0
	shape.height = 56.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	# Dal vetro ai piedi dell'attacco.
	collision.position = Vector2(0, MiniBulbSprite.FEET - 28.0)
	add_child(collision)
	collision_layer = 0
	solid = solid
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 24.0
	floor_constant_speed = true
	z_index = 5
	sprite = MiniBulbSprite.new()
	sprite.color = color
	add_child(sprite)


## Salta appena tocca terra.
func jump() -> void:
	_jump_requested = true


func feet_position() -> Vector2:
	return global_position + Vector2(0, MiniBulbSprite.FEET)


## Spazio che serve per fermarsi dalla velocità attuale.
func stopping_distance() -> float:
	return velocity.x * velocity.x / (2.0 * Player.GROUND_ACCEL)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + Player.GRAVITY * delta, Player.MAX_FALL_SPEED)
	elif _jump_requested:
		_jump_requested = false
		velocity.y = Player.JUMP_VELOCITY
		sprite.squash(Vector2(0.75, 1.25))
		Sfx.play("jump", -8.0, 0.05, 1.5)

	var accel := Player.GROUND_ACCEL if is_on_floor() else Player.AIR_ACCEL
	velocity.x = move_toward(velocity.x, direction * Player.SPEED, accel * delta)

	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	move_and_slide()
	if not was_on_floor and is_on_floor():
		sprite.squash(Vector2(1.25, 0.8))
		if fall_speed > LAND_SOUND_MIN_SPEED:
			Sfx.play("land", -10.0, 0.06, 1.4)


func _process(delta: float) -> void:
	# Camminata: saltella e si inclina nella direzione in cui va.
	_time += delta
	var speed := velocity.x / Player.SPEED
	var bounce := 0.0
	if is_on_floor() and absf(speed) > 0.05:
		bounce = -absf(sin(_time * 16.0)) * 5.0
	sprite.position.y = lerpf(sprite.position.y, bounce, minf(1.0, 20.0 * delta))
	sprite.rotation = lerpf(sprite.rotation, speed * 0.15, minf(1.0, 10.0 * delta))
