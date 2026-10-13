@tool
class_name Cobweb
extends Node2D
## Ragnatela d'angolo, solo decorativa: niente collisioni né ombre.
## L'origine è l'angolo (es. dove il soffitto incontra la parete): la tela si
## apre verso l'interno della stanza.

@export_enum("top_left", "top_right", "bottom_left", "bottom_right") var corner := "top_left":
	set(value):
		corner = value
		queue_redraw()
## Distanza massima della tela dall'angolo.
@export var radius := 110.0:
	set(value):
		radius = value
		queue_redraw()
## Fili che partono dall'angolo (i due esterni corrono lungo i muri).
@export_range(3, 9) var threads := 5:
	set(value):
		threads = value
		queue_redraw()
## Giri di filo tra un raggio e l'altro.
@export_range(1, 8) var rings := 4:
	set(value):
		rings = value
		queue_redraw()
## Lunghezza del filo da cui pende un ragnetto (0 = nessun ragno).
@export var spider_drop := 0.0:
	set(value):
		spider_drop = value
		queue_redraw()

const THREAD := Color(0.86, 0.86, 0.92, 0.45)
const SPIDER := Color(0.12, 0.1, 0.12)
## Quanto i giri di filo si incurvano verso l'angolo.
const SAG := 0.82


func _ready() -> void:
	z_index = -5


func _draw() -> void:
	var tips: Array[Vector2] = []
	for i in threads:
		var angle := PI / 2.0 * i / (threads - 1)
		# Lunghezze leggermente irregolari, sempre uguali tra un avvio e l'altro.
		var length := radius * (0.82 + 0.18 * (0.5 + 0.5 * sin(i * 2.7 + 1.3)))
		var tip := _flip(Vector2(cos(angle), sin(angle)) * length)
		tips.append(tip)
		draw_line(Vector2.ZERO, tip, THREAD, 1.5, true)
	for r in rings:
		var t := float(r + 1) / (rings + 1)
		for i in threads - 1:
			_draw_sagging(tips[i] * t, tips[i + 1] * t)
	if spider_drop > 0.0:
		_draw_spider(tips[int(threads / 2.0)] * 0.55)


## Filo tra due raggi, incurvato verso l'angolo (curva di Bézier quadratica).
func _draw_sagging(a: Vector2, b: Vector2) -> void:
	var control := (a + b) / 2.0 * SAG
	var curve := PackedVector2Array()
	for step in 6:
		var t := step / 5.0
		curve.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	draw_polyline(curve, THREAD, 1.2, true)


## Ragnetto appeso a un filo che scende dritto dal punto della tela.
func _draw_spider(anchor: Vector2) -> void:
	var body := anchor + Vector2(0, spider_drop)
	draw_line(anchor, body, THREAD, 1.2, true)
	for side in [-1.0, 1.0]:
		for leg in 4:
			var root := body + Vector2(side * 3.0, leg * 2.0 - 3.0)
			var knee := root + Vector2(side * 6.0, -4.0 + leg * 2.0)
			var foot := knee + Vector2(side * 3.0, 5.0 + leg)
			draw_polyline(PackedVector2Array([root, knee, foot]), SPIDER, 1.5, true)
	draw_circle(body, 5.0, SPIDER)
	draw_circle(body + Vector2(0, -6), 3.0, SPIDER)


## Ribalta un punto del quadrante in alto a sinistra verso l'angolo scelto.
func _flip(point: Vector2) -> Vector2:
	var sx := -1.0 if corner.ends_with("right") else 1.0
	var sy := -1.0 if corner.begins_with("bottom") else 1.0
	return Vector2(point.x * sx, point.y * sy)
