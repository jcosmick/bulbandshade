@tool
class_name GlassShards
extends Node2D
## Cocci di vetro sparsi a terra, solo decorativi. Quando un flash li
## raggiunge luccicano uno dopo l'altro; se la lampadina ci cammina sopra
## scricchiolano. L'origine è il centro, a y = pavimento.

@export var width := 200.0:
	set(value):
		width = value
		queue_redraw()
@export_range(3, 40) var count := 12:
	set(value):
		count = value
		queue_redraw()
## Cambialo per cocci disposti diversamente.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()

const GLASS := Color(0.58, 0.64, 0.7)
const GLASS_EDGE := Color(0.8, 0.86, 0.92)
const GLINT := Color(1.0, 0.97, 0.88)
## Durata del luccichio di ogni coccio e ritardo massimo tra il primo e l'ultimo.
const GLINT_TIME := 0.45
const GLINT_SPREAD := 0.5
const GLINT_SIZE := 9.0
## Frazione dei cocci che luccicano a ogni flash.
const GLINT_CHANCE := 0.6
const MIN_SPEED := 80.0
const CRUNCH_INTERVAL := 0.3

var _visual: Node2D
## Posizioni dei cocci (uguali a quelle disegnate) e quando inizia il luccichio di ciascuno.
var _shards: Array[Vector2] = []
var _glints: Array[float] = []
var _time := 0.0
var _area: Area2D
var _sound: AudioStreamPlayer2D
var _cooldown := 0.0


func _ready() -> void:
	z_index = -4
	if Engine.is_editor_hint():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	for i in count:
		_shards.append(_shard_position(rng))
		_glints.append(-1.0)
		rng.randf()
		rng.randf()
	_visual = LevelKit.make_overlay(self)
	_visual.material = LevelKit.shared_material(CanvasItemMaterial.BLEND_MODE_ADD)
	_visual.draw.connect(_draw_glints)
	LevelKit.prewarm(_visual)
	var player := LevelKit.find_player(self)
	if player:
		player.flashed.connect(_on_flashed)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 40)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -20)
	_area.add_child(collision)
	add_child(_area)
	_sound = Sfx.make_player_2d("glass", self)
	LevelKit.process_on_screen(self, Rect2(-width / 2.0 - 20, -40, width + 40, 50))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_visual.queue_redraw()
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return
	for body in _area.get_overlapping_bodies():
		var player := body as Player
		if player == null or not player.is_on_floor() or absf(player.velocity.x) < MIN_SPEED:
			continue
		_cooldown = CRUNCH_INTERVAL * randf_range(0.8, 1.4)
		_sound.volume_db = -20.0
		_sound.pitch_scale = randf_range(1.4, 1.7)
		_sound.play()


func _on_flashed(origin: Vector2, radius: float) -> void:
	if origin.distance_to(global_position) > radius:
		return
	for i in _glints.size():
		if randf() < GLINT_CHANCE:
			_glints[i] = _time + randf() * GLINT_SPREAD


func _shard_position(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(-width / 2.0, width / 2.0), -rng.randf_range(1.0, 4.0))


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	for i in count:
		var at := _shard_position(rng)
		var size := rng.randf_range(6.0, 14.0)
		var angle := rng.randf() * TAU
		var shard := PackedVector2Array([
			at + Vector2.from_angle(angle) * size,
			at + Vector2.from_angle(angle + 2.4) * size * 0.5,
			at + Vector2.from_angle(angle + 3.6) * size * 0.7,
		])
		draw_colored_polygon(shard, GLASS)
		draw_line(shard[0], shard[1], GLASS_EDGE, 2.0)


## Stelline a quattro punte che si accendono e si spengono.
func _draw_glints() -> void:
	for i in _shards.size():
		var start := _glints[i]
		if start < 0.0 or _time < start:
			continue
		var t := (_time - start) / GLINT_TIME
		if t >= 1.0:
			_glints[i] = -1.0
			continue
		var strength := sin(t * PI)
		var at := _shards[i]
		var arm := GLINT_SIZE * strength
		var color := Color(GLINT, strength)
		_visual.draw_line(at + Vector2(-arm, 0), at + Vector2(arm, 0), color, 2.0)
		_visual.draw_line(at + Vector2(0, -arm * 1.4), at + Vector2(0, arm * 1.4), color, 2.0)
		_visual.draw_circle(at, 2.5 * strength, color)
