@tool
class_name GhostBulb
extends Node2D
## Lampadina fantasma: una sagoma pallida e trasparente, grande come la
## protagonista, che si vede solo per un attimo quando un flash la raggiunge.
## Gli occhi seguono sempre la lampadina. Solo decorativa.
## L'origine è dove starebbero i piedi (la coda sfuma verso il basso).

## Secondi in cui resta visibile dopo un flash, prima di svanire.
@export var visible_time := 1.2
## Secondi per svanire.
@export var fade_time := 1.6
## Visibilità minima a riposo (0 = invisibile finché non arriva un flash).
@export_range(0.0, 0.3, 0.01) var idle_alpha := 0.0
## Se vero, dopo essere stata vista una volta non torna più.
@export var only_once := false

const BODY := Color(0.72, 0.85, 1.0, 0.45)
const OUTLINE := Color(0.85, 0.94, 1.0, 0.8)
const EYE := Color(0.03, 0.04, 0.08, 0.95)
const PUPIL := Color(0.9, 0.97, 1.0, 0.9)
const MAX_ALPHA := 0.9
const FADE_IN := 0.12
const HOVER := 6.0
const HOVER_SPEED := 1.3
## Quanto si spostano le pupille verso la lampadina.
const LOOK := 2.5

var _visual: Node2D
var _player: Player
var _alpha := 0.0
var _time := 0.0
var _tween: Tween
var _seen := false


func _ready() -> void:
	z_index = -4
	if Engine.is_editor_hint():
		return
	_alpha = idle_alpha
	# Sopra il buio: quando appare deve "brillare" anche se il flash è già finito.
	_visual = LevelKit.make_overlay(self)
	_visual.draw.connect(func() -> void: _draw_ghost(_visual))
	_player = LevelKit.find_player(self)
	if _player:
		_player.flashed.connect(_on_flashed)
	LevelKit.process_on_screen(self, Rect2(-60, -140, 120, 160))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if _alpha > 0.0:
		_visual.queue_redraw()


func _on_flashed(origin: Vector2, radius: float) -> void:
	if _seen and only_once:
		return
	if origin.distance_to(global_position + Vector2(0, -68)) > radius:
		return
	_seen = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_alpha", MAX_ALPHA, FADE_IN)
	_tween.tween_interval(visible_time)
	_tween.tween_property(self, "_alpha", 0.0 if only_once else idle_alpha, fade_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_visual.queue_redraw)


func _draw() -> void:
	if Engine.is_editor_hint():
		_alpha = 0.6
		_draw_ghost(self)


func _draw_ghost(item: CanvasItem) -> void:
	if _alpha <= 0.0:
		return
	var a := _alpha
	var bob := sin(_time * HOVER_SPEED) * HOVER
	var wave := _time * 3.0
	item.draw_set_transform(Vector2(0, bob))
	var glass := Vector2(0, -68)
	# Vetro e collo, poi al posto dell'attacco una coda ondulata che sfuma.
	var outline := PackedVector2Array()
	for i in 21:
		var angle := lerpf(PI * 0.78, PI * 2.22, i / 20.0)
		outline.append(glass + Vector2.from_angle(angle) * 38.0)
	outline.append(Vector2(17, -32))
	for i in 7:
		var t := i / 6.0
		var x := lerpf(17.0, -17.0, t)
		outline.append(Vector2(x, -6 + sin(wave + t * TAU) * 5.0 - (6.0 if i % 2 == 1 else 0.0)))
	outline.append(Vector2(-17, -32))
	item.draw_colored_polygon(outline, Color(BODY, BODY.a * a))
	outline.append(outline[0])
	item.draw_polyline(outline, Color(OUTLINE, OUTLINE.a * a), 2.5)
	# Filamento appena accennato e occhi vuoti che guardano la lampadina.
	item.draw_polyline(PackedVector2Array([
		Vector2(-9, -34), Vector2(-9, -56), Vector2(-5, -63), Vector2(0, -56),
		Vector2(5, -63), Vector2(9, -56), Vector2(9, -34)
	]), Color(OUTLINE, 0.35 * a), 2.0)
	var look := Vector2.ZERO
	if _player:
		look = (_player.global_position - global_position).normalized() * LOOK
	for side in [-1.0, 1.0]:
		var eye := Vector2(11.0 * side, -80)
		item.draw_circle(eye, 7.0, Color(EYE, EYE.a * a))
		item.draw_circle(eye + look, 2.0, Color(PUPIL, PUPIL.a * a))
	item.draw_set_transform_matrix(Transform2D.IDENTITY)
