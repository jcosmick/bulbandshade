@tool
class_name Mirror
extends Node2D
## Specchio da muro: quando il flash lo raggiunge lampeggia a sua volta e crea
## ombre dalla sua posizione. La faccia riflettente guarda verso l'alto del
## nodo: rotazione 0 = verso l'alto, 90 = verso destra, -90 = verso sinistra.
## L'origine del nodo va sulla superficie del muro.

@export var length := 160.0:
	set(value):
		length = value
		queue_redraw()
@export var flash_radius := 750.0

## Distanza davanti allo specchio da cui parte la sua luce.
const EMIT_OFFSET := 8.0
const FRAME := Color(0.36, 0.28, 0.2)
const SURFACE := Color(0.72, 0.8, 0.88)
const SHINE := Color(1, 1, 1, 0.8)

var _light: PointLight2D
var _light_tween: Tween
var _glow := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("mirrors")
	_light = PointLight2D.new()
	_light.texture = LevelKit.half_light_texture()
	_light.texture_scale = flash_radius / LevelKit.LIGHT_TEXTURE_RADIUS
	_light.energy = 0.0
	_light.color = LevelKit.LIGHT_COLOR
	_light.shadow_enabled = true
	_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	# Come il flash, anche la luce dello specchio si ferma ai fasci delle finestre.
	_light.shadow_item_cull_mask = 1 | ShadowSystem.BEAM_OCCLUDER_MASK
	_light.position = Vector2(0, -EMIT_OFFSET)
	add_child(_light)


## Direzione verso cui guarda la faccia riflettente.
func normal() -> Vector2:
	return global_transform.basis_xform(Vector2.UP).normalized()


func emit_point() -> Vector2:
	return global_transform * Vector2(0, -EMIT_OFFSET)


## Punti della superficie usati per capire se il flash colpisce lo specchio.
func sample_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for t in [-0.4, 0.0, 0.4]:
		points.append(global_transform * Vector2(length * t, -2.0))
	return points


func flash() -> void:
	_glow = 1.0
	if _light_tween:
		_light_tween.kill()
	_light.energy = 2.0
	_light_tween = create_tween()
	_light_tween.tween_property(_light, "energy", 0.0, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _glow <= 0.0:
		return
	_glow = maxf(0.0, _glow - delta * 1.5)
	queue_redraw()


func _draw() -> void:
	var half := length / 2.0
	draw_rect(Rect2(-half - 8.0, -6.0, length + 16.0, 18.0), FRAME)
	draw_rect(Rect2(-half, -6.0, length, 8.0), SURFACE)
	draw_line(Vector2(-half + 10.0, -4.0), Vector2(-half + length * 0.3, -4.0), SHINE, 2.0)
	if _glow > 0.0:
		draw_rect(Rect2(-half, -10.0, length, 12.0), Color(1, 0.95, 0.8, _glow))
