@tool
class_name MiniBulb
extends Area2D
## Collezionabile: una mini lampadina nascosta nel livello. Toccandola fa una
## piccola animazione e viene salvata; da quel momento appare nel menu accanto
## alla lampadina principale. Se è già stata trovata resta come fantasma.
## L'origine del nodo è il centro del vetro.

signal collected(bulb: MiniBulb)

## Identificativo unico (salvato nei progressi).
@export var id := ""
@export var color := Color(1.0, 0.35, 0.35):
	set(value):
		color = value
		queue_redraw()

var _sprite: MiniBulbSprite
var _time := 0.0
var _taken := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("mini_bulbs")
	_sprite = MiniBulbSprite.new()
	_sprite.color = color
	add_child(_sprite)
	if Progress.has_mini_bulb(id):
		_taken = true
		_sprite.modulate.a = 0.3
		_sprite.set_glow(0.0)
		return
	var shape := CircleShape2D.new()
	shape.radius = 40.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _taken:
		return
	_time += delta
	_sprite.position.y = sin(_time * 2.4) * 6.0


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	set_deferred("monitoring", false)
	Progress.collect_mini_bulb(id, color)
	collected.emit(self)
	_play_collect()


## Saltello con giravolta, mini flash e scintille, poi sparisce verso l'alto.
func _play_collect() -> void:
	_sprite.squash(Vector2(1.3, 0.7))
	var tween := create_tween()
	tween.tween_property(_sprite, "position:y", -90.0, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sprite, "rotation", TAU, 0.35)
	tween.tween_callback(func() -> void:
		_sprite.rotation = 0.0
		_sprite.flash()
		_burst())
	tween.tween_property(_sprite, "scale", Vector2(1.5, 1.5), 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.25)
	tween.tween_property(_sprite, "scale", Vector2.ZERO, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_sprite, "position:y", -160.0, 0.3)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)


func _burst() -> void:
	var sparks := CPUParticles2D.new()
	sparks.position = _sprite.position
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 18
	sparks.lifetime = 0.6
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 300)
	sparks.initial_velocity_min = 180.0
	sparks.initial_velocity_max = 320.0
	sparks.scale_amount_min = 4.0
	sparks.scale_amount_max = 7.0
	sparks.color = color.lightened(0.3)
	add_child(sparks)
	sparks.emitting = true


func _draw() -> void:
	# Nell'editor si vede la mini lampadina; in gioco la disegna lo sprite.
	if Engine.is_editor_hint():
		MiniBulbSprite.draw_bulb(self, color)
