@tool
class_name WaterPool
extends Area2D
## Pozzanghera: se la lampadina la tocca va in cortocircuito.

@export var size := Vector2(300, 16):
	set(value):
		size = value
		queue_redraw()

## Toni smorzati come il resto della stanza: verde-azzurro torbido che si
## scurisce verso il fondo, con il pelo dell'acqua più chiaro.
const WATER := Color(0.24, 0.39, 0.45, 0.9)
const DEEP := Color(0.13, 0.2, 0.26, 0.95)
const SURFACE := Color(0.56, 0.71, 0.73, 0.95)
const SPLASH_AMOUNT := 28
const SPLASH_LIFETIME := 0.7

var _visual: Node2D
var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	# Disegnata sopra il buio, così l'acqua si vede sempre.
	_visual = LevelKit.make_overlay(self, true, 2)
	_visual.draw.connect(_draw_water.bind(_visual))
	# Solo le onde: l'area che fa morire la lampadina resta sempre attiva.
	LevelKit.process_on_screen(self, Rect2(-size / 2.0, size))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_visual.queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_splash(body.global_position.x)
		body.die()


## Schizzo di gocce dove la lampadina tocca l'acqua: partono verso l'alto
## a ventaglio, ricadono e si rimpiccioliscono. Sta sull'overlay, sopra il buio.
func _splash(global_x: float) -> void:
	var drops := CPUParticles2D.new()
	var x := clampf(to_local(Vector2(global_x, global_position.y)).x, -size.x / 2.0, size.x / 2.0)
	drops.position = Vector2(x, -size.y / 2.0)
	drops.one_shot = true
	drops.explosiveness = 0.9
	drops.amount = SPLASH_AMOUNT
	drops.lifetime = SPLASH_LIFETIME
	drops.lifetime_randomness = 0.4
	drops.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drops.emission_rect_extents = Vector2(24, 2)
	drops.direction = Vector2.UP
	drops.spread = 40.0
	drops.gravity = Vector2(0, 1400)
	drops.initial_velocity_min = 250.0
	drops.initial_velocity_max = 550.0
	drops.texture = ShadowPlatform.circle_texture()
	drops.scale_amount_min = 0.25
	drops.scale_amount_max = 0.6
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.3))
	drops.scale_amount_curve = curve
	var colors := Gradient.new()
	colors.set_color(0, SURFACE)
	colors.set_color(1, Color(WATER, 0.0))
	drops.color_ramp = colors
	drops.finished.connect(drops.queue_free)
	_visual.add_child(drops)
	drops.emitting = true


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_water(self)


func _draw_water(canvas: CanvasItem) -> void:
	var rect := Rect2(-size / 2.0, size)
	# Il corpo dell'acqua segue l'onda: niente stacco tra superficie e riempimento.
	var wave := PackedVector2Array()
	var x := rect.position.x
	while x < rect.end.x:
		wave.append(Vector2(x, _wave_y(rect, x)))
		x += 10.0
	wave.append(Vector2(rect.end.x, _wave_y(rect, rect.end.x)))
	var body := wave.duplicate()
	body.append(rect.end)
	body.append(Vector2(rect.position.x, rect.end.y))
	var colors := PackedColorArray()
	colors.resize(wave.size())
	colors.fill(WATER)
	colors.append_array([DEEP, DEEP])
	canvas.draw_polygon(body, colors)
	canvas.draw_polyline(wave, SURFACE, 3.0)


func _wave_y(rect: Rect2, x: float) -> float:
	return rect.position.y + sin(x * 0.05 + _time * 3.0) * 2.0
