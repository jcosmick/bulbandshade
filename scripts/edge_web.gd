@tool
class_name EdgeWeb
extends Node2D
## Ragnatela lungo un bordo, solo decorativa: pende sotto una linea lunga
## `width` che parte dall'origine verso destra. Mettila sotto il bordo di una
## piattaforma o del soffitto; ruotata di 180° si appoggia sopra un bordo.

@export var width := 160.0:
	set(value):
		width = value
		queue_redraw()
## Quanto scende la tela sotto il bordo.
@export var depth := 36.0:
	set(value):
		depth = value
		queue_redraw()
## Cambialo per ottenere una tela di forma diversa.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()

## Distanza indicativa tra due punti d'attacco della tela.
const ANCHOR_STEP := 45.0
const LAYERS := 3


func _ready() -> void:
	z_index = -5


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	var count := maxi(2, int(width / ANCHOR_STEP))
	var anchors := PackedVector2Array()
	for i in count + 1:
		var jitter := 0.0 if i == 0 or i == count else rng.randf_range(-8.0, 8.0)
		anchors.append(Vector2(width * i / count + jitter, 0))
	for layer in LAYERS:
		var sag := depth * (0.35 + 0.3 * layer)
		for i in count:
			# Qualche buco nei giri più bassi.
			if layer > 0 and rng.randf() < 0.25:
				continue
			_draw_sagging(anchors[i], anchors[i + 1], sag * rng.randf_range(0.7, 1.1))
	for i in range(1, count):
		draw_line(anchors[i], anchors[i] + Vector2(rng.randf_range(-4.0, 4.0), depth * 0.9), Cobweb.THREAD, 1.2, true)
	# Un paio di fili sfilacciati che penzolano.
	for k in 2:
		var x := rng.randf_range(0.2, 0.8) * width
		var tip := Vector2(x + rng.randf_range(-6.0, 6.0), depth * rng.randf_range(1.2, 1.6))
		draw_line(Vector2(x, depth * 0.6), tip, Cobweb.THREAD, 1.0, true)


## Filo tra due attacchi che si incurva verso il basso di `sag`.
func _draw_sagging(a: Vector2, b: Vector2, sag: float) -> void:
	var control := (a + b) / 2.0 + Vector2(0, sag * 2.0)
	var curve := PackedVector2Array()
	for step in 8:
		var t := step / 7.0
		curve.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	draw_polyline(curve, Cobweb.THREAD, 1.2, true)
