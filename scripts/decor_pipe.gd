@tool
class_name DecorPipe
extends Line2D
## Tubatura solo decorativa: niente collisioni né ombre. Segue `points`
## (coordinate locali) oppure, in modalità gomito, due bracci uniti da una
## curva; ha raccordi lungo i tratti e flange alle estremità, da far toccare
## a muri o soffitto.
## È una Line2D solo per usare l'editor di punti della vista 2D (`points` e
## `width` sono quelli della Line2D): la linea originale è trasparente e il
## tubo lo disegna _draw.

## "path": segue `points`. "elbow": l'origine è il punto d'angolo, da cui
## partono due bracci (`leg_a` verso l'alto, `leg_b` girato di `bend_angle`).
@export_enum("path", "elbow") var shape := "path":
	set(value):
		shape = value
		notify_property_list_changed()
		queue_redraw()
## Gomito: lunghezza del primo braccio, dall'angolo verso l'alto.
@export var leg_a := 260.0:
	set(value):
		leg_a = value
		queue_redraw()
## Gomito: lunghezza del secondo braccio, dall'angolo nella direzione
## data da `bend_angle`.
@export var leg_b := 320.0:
	set(value):
		leg_b = value
		queue_redraw()
## Gomito: di quanti gradi gira il tubo (90 = verso destra, -90 = verso
## sinistra, 45 = in diagonale, 0 = dritto).
@export_range(-180.0, 180.0, 5.0) var bend_angle := 90.0:
	set(value):
		bend_angle = value
		queue_redraw()
## Distanza tra i raccordi lungo i tratti dritti (0 = nessun raccordo).
@export var joint_spacing := 160.0:
	set(value):
		joint_spacing = value
		queue_redraw()
## Flange di fissaggio alle due estremità.
@export var end_flanges := true:
	set(value):
		end_flanges = value
		queue_redraw()
## Volantino d'ottone a metà del tratto più lungo.
@export var valve := false:
	set(value):
		valve = value
		queue_redraw()

const PIPE := Color(0.33, 0.35, 0.39)
const PIPE_DARK := Color(0.21, 0.22, 0.26)
const PIPE_LIGHT := Color(0.48, 0.5, 0.55)
const BRASS := Color(0.66, 0.5, 0.24)
const BRASS_DARK := Color(0.44, 0.32, 0.14)
## I raccordi non si avvicinano più di così a gomiti ed estremità.
const JOINT_MARGIN := 40.0


func _ready() -> void:
	z_index = -6


## Nasconde nell'Inspector i parametri che non servono alla forma scelta.
func _validate_property(property: Dictionary) -> void:
	var elbow_only: bool = property.name in ["leg_a", "leg_b", "bend_angle"]
	if (elbow_only and shape != "elbow") or (property.name == "points" and shape == "elbow"):
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _draw() -> void:
	var path := _path()
	if path.size() < 2:
		return
	for i in path.size() - 1:
		_draw_segment(path[i], path[i + 1])
	for i in range(1, path.size() - 1):
		draw_circle(path[i], width / 2.0, PIPE)
		draw_arc(path[i], width / 2.0 + 1.0, 0.0, TAU, 24, PIPE_DARK, 5.0)
	if end_flanges:
		_draw_flange(path[0], path[1])
		_draw_flange(path[path.size() - 1], path[path.size() - 2])
	if valve:
		_draw_valve(path)


## Punti del tubo: `points`, oppure i due bracci del gomito attorno all'angolo.
func _path() -> PackedVector2Array:
	if shape != "elbow":
		return points
	var dir := Vector2.DOWN.rotated(-deg_to_rad(bend_angle))
	return PackedVector2Array([Vector2(0, -leg_a), Vector2.ZERO, dir * leg_b])


func _draw_segment(a: Vector2, b: Vector2) -> void:
	var dir := (b - a).normalized()
	var side := _light_side(dir)
	draw_line(a, b, PIPE, width)
	draw_line(a + side * width * 0.28, b + side * width * 0.28, PIPE_LIGHT, 3.0)
	draw_line(a - side * width * 0.36, b - side * width * 0.36, PIPE_DARK, 3.0)
	if joint_spacing <= 0.0:
		return
	var length := a.distance_to(b)
	var d := joint_spacing
	while d < length - JOINT_MARGIN:
		if d > JOINT_MARGIN:
			var p := a + dir * d
			draw_line(p - side * (width / 2.0 + 3.0), p + side * (width / 2.0 + 3.0), PIPE_DARK, 9.0)
		d += joint_spacing


## Piastra di fissaggio all'estremità `end`, con due bulloni.
func _draw_flange(end: Vector2, toward: Vector2) -> void:
	var dir := (toward - end).normalized()
	var side := Vector2(-dir.y, dir.x)
	var center := end + dir * 3.0
	var half := width / 2.0 + 9.0
	draw_line(center - side * half, center + side * half, PIPE_DARK, 7.0)
	for s in [-1.0, 1.0]:
		draw_circle(center + side * (half - 4.0) * s, 2.5, PIPE_LIGHT)


## Volantino a metà del tratto più lungo.
func _draw_valve(path: PackedVector2Array) -> void:
	var best := 0
	for i in path.size() - 1:
		if path[i].distance_to(path[i + 1]) > path[best].distance_to(path[best + 1]):
			best = i
	var center := (path[best] + path[best + 1]) / 2.0
	var r := width * 0.55
	draw_circle(center, r + 3.0, PIPE_DARK)
	draw_arc(center, r, 0.0, TAU, 20, BRASS, 4.0)
	draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), BRASS, 3.0)
	draw_line(center + Vector2(0, -r), center + Vector2(0, r), BRASS, 3.0)
	draw_circle(center, 3.5, BRASS_DARK)


## Perpendicolare al tubo rivolta verso l'alto (o a sinistra se il tubo è
## verticale): da lì arriva la luce del riflesso.
func _light_side(dir: Vector2) -> Vector2:
	var side := Vector2(-dir.y, dir.x)
	if side.y > 0.01 or (absf(side.y) <= 0.01 and side.x > 0.0):
		side = -side
	return side
