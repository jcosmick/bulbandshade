@tool
class_name BulbPile
extends Node2D
## Cimitero di lampadine: un mucchio di lampadine spente e rotte buttate a
## terra. Niente collisioni né ombre; se la lampadina ci passa in mezzo i
## vetri tintinnano. L'origine è la base al centro: va a y = pavimento.

@export_range(3, 30) var count := 12:
	set(value):
		count = value
		queue_redraw()
@export var width := 260.0:
	set(value):
		width = value
		queue_redraw()
## Dimensione delle lampadine rispetto alla protagonista.
@export_range(0.25, 1.0, 0.05) var bulb_scale := 0.45:
	set(value):
		bulb_scale = value
		queue_redraw()
## Cambialo per un mucchio disposto diversamente.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()

const STATES := ["off", "cracked", "shattered", "burnt", "cracked", "off"]
const EYES := ["x", "closed", "none", "x"]
## Altezza del mucchio rispetto alla larghezza.
const HEIGHT_RATIO := 0.35
## Velocità minima della lampadina per far tintinnare i vetri, e pausa tra due tintinnii.
const MIN_SPEED := 80.0
const CLINK_INTERVAL := 0.22

var _area: Area2D
var _sound: AudioStreamPlayer2D
var _cooldown := 0.0


func _ready() -> void:
	z_index = -5
	if Engine.is_editor_hint():
		return
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, width * HEIGHT_RATIO + 40.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -shape.size.y / 2.0)
	_area.add_child(collision)
	add_child(_area)
	_sound = Sfx.make_player_2d("glass", self)
	_sound.max_polyphony = 3
	LevelKit.process_on_screen(self, Rect2(-width / 2.0, -width * HEIGHT_RATIO - 60.0, width, width * HEIGHT_RATIO + 60.0))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return
	for body in _area.get_overlapping_bodies():
		var player := body as Player
		if player == null or player.velocity.length() < MIN_SPEED:
			continue
		_cooldown = CLINK_INTERVAL * randf_range(0.7, 1.6)
		var strength := clampf(player.velocity.length() / Player.SPEED, 0.3, 1.0)
		_sound.volume_db = -16.0 + linear_to_db(strength)
		# Lampadine piccole: suonano più acute del barattolo.
		_sound.pitch_scale = randf_range(1.15, 1.45)
		_sound.play()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	var half := width / 2.0
	var height := width * HEIGHT_RATIO
	# Dal basso verso l'alto: quelle in cima coprono quelle sotto.
	for i in count:
		var t := float(i) / maxf(1.0, count - 1)
		var x := rng.randf_range(-half, half) * (1.0 - t * 0.6)
		# Profilo a cupola: più si sta al centro, più il mucchio è alto.
		var top := height * (1.0 - pow(absf(x) / half, 2.0))
		var y := -top * t * rng.randf_range(0.7, 1.0)
		var tilt := rng.randf_range(-180.0, 180.0)
		var size := bulb_scale * rng.randf_range(0.85, 1.1)
		var xform := DeadBulb.grounded_transform(tilt, size, Vector2(x, y))
		DeadBulb.draw_bulb(self, xform, STATES[rng.randi() % STATES.size()],
				EYES[rng.randi() % EYES.size()], rng.randi())
	# Cocci sparsi ai piedi del mucchio.
	for i in int(count / 2.0):
		var x := rng.randf_range(-half * 1.1, half * 1.1)
		var size := rng.randf_range(3, 7)
		var angle := rng.randf() * TAU
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, -1) + Vector2.from_angle(angle) * size,
			Vector2(x, -1) + Vector2.from_angle(angle + 2.3) * size * 0.6,
			Vector2(x, -1) + Vector2.from_angle(angle + 3.8) * size * 0.8,
		]), DeadBulb.GLASS_EDGE)
