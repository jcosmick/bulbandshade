@tool
class_name SackPile
extends Node2D
## Pila di sacchi di juta, solo decorativa: niente collisioni né ombre.
## L'origine è la base al centro: appoggiata va a y = pavimento.

## File di sacchi: la fila in basso ne ha `rows`, ogni fila sopra uno in meno.
@export_range(1, 5) var rows := 3:
	set(value):
		rows = value
		queue_redraw()
@export var sack_size := Vector2(100, 44):
	set(value):
		sack_size = value
		queue_redraw()

const BURLAP := Color(0.31, 0.27, 0.22)
const BURLAP_DARK := Color(0.22, 0.19, 0.16)
## Piccole variazioni di tono da un sacco all'altro (+ schiarisce, - scurisce).
const TINTS := [0.0, 0.04, -0.04, 0.02, -0.02]
## Quanto ogni fila affonda in quella sotto (frazione dell'altezza).
const ROW_OVERLAP := 0.18


func _ready() -> void:
	z_index = -5


func _draw() -> void:
	var index := 0
	for row in rows:
		var count := rows - row
		var y := -sack_size.y / 2.0 - row * sack_size.y * (1.0 - ROW_OVERLAP)
		for i in count:
			var x := (i - (count - 1) / 2.0) * sack_size.x * 0.96
			_draw_sack(Vector2(x, y), TINTS[index % TINTS.size()], index % 2 == 0)
			index += 1


## Sacco con gli angoli smussati, cucitura e legatura su un lato.
func _draw_sack(center: Vector2, tint: float, tie_right: bool) -> void:
	var h := sack_size / 2.0
	var c := minf(h.y * 0.6, h.x * 0.4)
	var shape := PackedVector2Array([
		Vector2(-h.x + c, -h.y), Vector2(h.x - c, -h.y), Vector2(h.x, -h.y + c), Vector2(h.x, h.y - c),
		Vector2(h.x - c, h.y), Vector2(-h.x + c, h.y), Vector2(-h.x, h.y - c), Vector2(-h.x, -h.y + c),
	])
	var color := BURLAP.lightened(tint) if tint > 0.0 else BURLAP.darkened(-tint)
	draw_colored_polygon(Transform2D(0.0, center) * shape, color)
	var seam_y := center.y - h.y * 0.1
	draw_dashed_line(Vector2(center.x - h.x + c, seam_y), Vector2(center.x + h.x - c, seam_y), BURLAP_DARK, 2.0, 6.0)
	var tie_x := center.x + (1.0 if tie_right else -1.0) * (h.x - c * 0.8)
	draw_line(Vector2(tie_x, center.y - h.y * 0.7), Vector2(tie_x, center.y + h.y * 0.7), BURLAP_DARK, 4.0)
