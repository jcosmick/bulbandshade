@tool
class_name BrokenSocket
extends Node2D
## Portalampada vuoto e rotto: la lampadina non c'è più, restano i fili
## scoperti che ogni tanto fanno scintille. Solo decorativo.
## "ceiling": appeso al soffitto per il filo, l'origine è il punto d'aggancio.
## "wall": su un braccio storto che esce dal muro, l'origine è sul muro.
## "desk": lampada da terra come quella d'arrivo, piegata; l'origine è la base.

@export_enum("ceiling", "wall", "desk") var kind := "ceiling":
	set(value):
		kind = value
		queue_redraw()
## Lunghezza del filo (ceiling) o del braccio (wall).
@export var length := 140.0:
	set(value):
		length = value
		queue_redraw()
## Dondola piano appeso al filo (solo "ceiling"); falso = fermo.
@export var swaying := true
## Scintille dai fili scoperti a intervalli casuali.
@export var sparking := true
## Secondi minimi e massimi tra una scintilla e l'altra.
@export var spark_interval := Vector2(1.5, 6.0)

const BRASS := Color(0.5, 0.41, 0.24)
const BRASS_DARK := Color(0.32, 0.25, 0.13)
const BRASS_LIGHT := Color(0.66, 0.56, 0.36)
const HOLE := Color(0.06, 0.05, 0.05)
const METAL := Color(0.3, 0.3, 0.34)
const CORD := Color(0.16, 0.15, 0.16)
const COPPER := Color(0.75, 0.46, 0.22)
const WIRES := [Color(0.5, 0.18, 0.15), Color(0.2, 0.28, 0.5), Color(0.45, 0.42, 0.2)]
## Altezza del corpo del portalampada: l'origine del suo disegno è la bocca.
const BODY := 30.0
const SWAY := 0.035
const SWAY_SPEED := 1.1

var _time := 0.0
var _spark_wait := 0.0


func _ready() -> void:
	z_index = -6
	if Engine.is_editor_hint():
		return
	_time = randf() * TAU
	_spark_wait = randf_range(spark_interval.x, spark_interval.y)
	LevelKit.process_on_screen(self, Rect2(-length - 60, -160, length * 2.0 + 120, length + 260))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if kind == "ceiling" and swaying:
		queue_redraw()
	if not sparking:
		return
	_spark_wait -= delta
	if _spark_wait <= 0.0:
		# A volte due scintille ravvicinate, come un contatto che sfrigola.
		_spark_wait = randf_range(0.08, 0.2) if randf() < 0.3 else randf_range(spark_interval.x, spark_interval.y)
		SparkBurst.spawn(self, _socket_transform() * Vector2(0, 14), randf_range(0.35, 1.0))


## Trasformazione del portalampada: l'origine è la bocca, il corpo sta verso -y.
func _socket_transform() -> Transform2D:
	var attach: Vector2
	var angle: float
	match kind:
		"ceiling":
			var sway := sin(_time * SWAY_SPEED) * SWAY if swaying else 0.0
			return Transform2D(sway, Vector2.ZERO) * Transform2D(0.0, Vector2(0, length + BODY))
		"wall":
			attach = _arm_points()[2]
			angle = 0.35
		_:
			attach = _stem_points()[2]
			angle = PI + 0.6
	return Transform2D(angle, attach + Vector2(0, BODY).rotated(angle))


func _arm_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(length * 0.6, 6), Vector2(length, 24)])


func _stem_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, -12), Vector2(0, -70), Vector2(22, -104)])


func _draw() -> void:
	var socket := _socket_transform()
	match kind:
		"ceiling":
			draw_rect(Rect2(-12, -4, 24, 8), METAL)
			draw_line(Vector2.ZERO, socket * Vector2(0, -BODY), CORD, 3.0)
		"wall":
			draw_rect(Rect2(-8, -20, 16, 40), METAL)
			draw_polyline(_arm_points(), METAL, 6.0)
		"desk":
			draw_rect(Rect2(-48, -12, 96, 12), METAL)
			draw_circle(Vector2(-48, -6), 6.0, METAL)
			draw_circle(Vector2(48, -6), 6.0, METAL)
			draw_polyline(_stem_points(), METAL, 10.0)
			draw_circle(_stem_points()[1], 6.0, METAL)
	draw_set_transform_matrix(socket)
	_draw_socket()
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Portalampada con la bocca in y = 0 (verso +y), ammaccato, e i fili che pendono fuori.
func _draw_socket() -> void:
	# Cilindro d'ottone con il tappo di metallo e il riflesso, labbro in fondo.
	draw_rect(Rect2(-12, -BODY - 6, 24, 7), METAL)
	draw_rect(Rect2(-17, -BODY, 34, BODY), BRASS)
	draw_line(Vector2(-10, -BODY + 3), Vector2(-10, -6), BRASS_LIGHT, 3.0)
	for i in 2:
		draw_line(Vector2(-17, -BODY + 10 + i * 7), Vector2(17, -BODY + 12 + i * 7), BRASS_DARK, 1.5)
	draw_rect(Rect2(-20, -5, 40, 5), BRASS_DARK)
	draw_rect(Rect2(-13, -2, 26, 4), HOLE)
	# Un pezzo del labbro è saltato via.
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, 0), Vector2(20, 0), Vector2(20, -6), Vector2(14, -3)
	]), HOLE)
	for i in WIRES.size():
		var start := Vector2(-8 + i * 8, -2)
		var bend := start + Vector2((i - 1) * 6, 10 + i * 3)
		var tip := bend + Vector2((i - 1) * 4 + 3, 6)
		draw_polyline(PackedVector2Array([start, bend]), WIRES[i], 3.0)
		# Rame sfilacciato in punta.
		draw_line(bend, tip, COPPER, 1.5)
		draw_line(bend, tip + Vector2(-4, 1), COPPER, 1.2)
