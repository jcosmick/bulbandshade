class_name SparkBurst
extends Node2D
## Scintille elettriche da un filo scoperto: un lampo azzurro brevissimo,
## qualche scintilla che cade e lo sfrigolio. Si crea con SparkBurst.spawn()
## e si toglie da sola a fine effetto.

const COLOR := Color(0.75, 0.92, 1.0)
const LIGHT_COLOR := Color(0.6, 0.8, 1.0)
const LIGHT_RADIUS := 170.0
const LIFETIME := 0.55


## Scintille in `at` (coordinate locali di parent). strength 0..1 scala
## quantità, velocità, lampo e volume.
static func spawn(parent: Node2D, at: Vector2, strength := 1.0) -> void:
	var burst := SparkBurst.new()
	burst.position = at
	parent.add_child(burst)
	burst._start(clampf(strength, 0.2, 1.0))


func _start(strength: float) -> void:
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.85
	sparks.amount = int(5 + 11 * strength)
	sparks.lifetime = LIFETIME
	sparks.direction = Vector2.DOWN
	sparks.spread = 75.0
	sparks.gravity = Vector2(0, 900)
	sparks.initial_velocity_min = 60.0 * strength
	sparks.initial_velocity_max = 260.0 * strength
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(COLOR, 0.0))
	sparks.color_ramp = fade
	sparks.color = COLOR
	add_child(sparks)
	sparks.emitting = true
	var light := LevelKit.make_light(self, LIGHT_RADIUS * lerpf(0.6, 1.0, strength), 1.6 * strength, false)
	light.color = LIGHT_COLOR
	var tween := create_tween()
	tween.tween_property(light, "energy", 0.0, 0.18)
	var sound := Sfx.make_player_2d("spark", self)
	sound.volume_db = -8.0 + linear_to_db(strength)
	sound.pitch_scale = randf_range(0.9, 1.15)
	sound.play()
	get_tree().create_timer(LIFETIME + 0.6).timeout.connect(queue_free)
