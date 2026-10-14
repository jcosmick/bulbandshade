@tool
class_name TrashBags
extends Node2D
## Sacchi della spazzatura neri, ammucchiati: solo decorativi, niente
## collisioni né ombre. Se la lampadina ci passa contro si schiacciano un poco
## e frusciano. L'origine è la base al centro: va a y = pavimento.

@export_range(1, 5) var count := 3:
	set(value):
		count = value
		queue_redraw()
## Dimensione del sacco più grande.
@export var bag_size := Vector2(110, 90):
	set(value):
		bag_size = value
		queue_redraw()
## Cambialo per sacchi di forma e disposizione diverse.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()

const PLASTIC := Color(0.13, 0.13, 0.15)
const PLASTIC_DARK := Color(0.08, 0.08, 0.1)
const SHINE := Color(0.34, 0.35, 0.4)
const TIE := Color(0.5, 0.3, 0.12)
## Quanto si schiacciano al passaggio della lampadina, e quanto in fretta tornano su.
const SQUISH := 0.12
const SPRING := 9.0

var _area: Area2D
var _rustle: PlantRustle
var _squish := 0.0
## Da che parte è arrivata la lampadina (i sacchi si piegano dall'altra).
var _lean := 0.0


func _ready() -> void:
	z_index = -5
	if Engine.is_editor_hint():
		return
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(bag_size.x * (0.6 + count * 0.5), bag_size.y)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -bag_size.y / 2.0)
	_area.add_child(collision)
	add_child(_area)
	_rustle = PlantRustle.new()
	add_child(_rustle)
	LevelKit.process_on_screen(self, Rect2(-shape.size.x / 2.0, -bag_size.y * 1.6, shape.size.x, bag_size.y * 1.6))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := 0.0
	for body in _area.get_overlapping_bodies():
		var player := body as Player
		if player == null:
			continue
		var speed := player.velocity.length()
		_rustle.touch(speed)
		target = clampf(speed / Player.SPEED, 0.3, 1.0)
		_lean = signf(global_position.x - player.global_position.x)
	var previous := _squish
	_squish = move_toward(_squish, target, delta * SPRING * (1.0 if target > _squish else 0.5))
	if not is_equal_approx(previous, _squish):
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	# Sacchi in fila a terra; con 3 o più, uno appoggiato sopra in mezzo.
	var bottom := mini(count, 3)
	var spacing := bag_size.x * 0.72
	var slots: Array[Vector3] = []
	for i in bottom:
		slots.append(Vector3((i - (bottom - 1) / 2.0) * spacing, 0.0, rng.randf_range(0.8, 1.0)))
	for i in count - bottom:
		var x := (i - (count - bottom - 1) / 2.0) * spacing
		slots.append(Vector3(x, -bag_size.y * 0.55, rng.randf_range(0.65, 0.8)))
	for slot in slots:
		_draw_bag(Vector2(slot.x, slot.y), bag_size * slot.z, rng)


## Sacco gonfio con il collo legato in cima. `base` è il punto d'appoggio.
func _draw_bag(base: Vector2, size: Vector2, rng: RandomNumberGenerator) -> void:
	var squash := Vector2(1.0 + _squish * SQUISH, 1.0 - _squish * SQUISH)
	var lean := _lean * _squish * 0.08
	draw_set_transform(base, lean, squash)
	var h := size / 2.0
	var center := Vector2(0, -h.y)
	var points := PackedVector2Array()
	var steps := 18
	for i in steps:
		var angle := i * TAU / steps
		var wobble := rng.randf_range(0.9, 1.05)
		var point := Vector2(cos(angle) * h.x, sin(angle) * h.y) * wobble
		# Fondo schiacciato a terra e spalle che salgono verso il collo.
		point.y = minf(point.y, h.y * 0.92)
		if point.y < 0.0:
			point.x *= lerpf(1.0, 0.7, -point.y / h.y)
		points.append(center + point)
	draw_colored_polygon(points, PLASTIC)
	# Pieghe della plastica tirata dal contenuto.
	for i in 3:
		var from := center + Vector2(rng.randf_range(-h.x, h.x) * 0.5, rng.randf_range(-h.y, h.y) * 0.4)
		draw_line(from, from + Vector2(rng.randf_range(-14, 14), rng.randf_range(10, 22)), PLASTIC_DARK, 2.5)
	draw_arc(center + Vector2(-h.x * 0.25, -h.y * 0.15), h.x * 0.5, PI * 1.1, PI * 1.4, 6, SHINE, 3.0)
	# Collo legato e le due orecchie del nodo.
	var neck := center + Vector2(0, -h.y * 0.95)
	draw_colored_polygon(PackedVector2Array([
		neck + Vector2(-9, 8), neck + Vector2(9, 8), neck + Vector2(4, -4), neck + Vector2(-4, -4)
	]), PLASTIC)
	draw_line(neck + Vector2(-5, 0), neck + Vector2(5, 0), TIE, 3.0)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			neck + Vector2(0, -3), neck + Vector2(side * 16, -16), neck + Vector2(side * 6, -18)
		]), PLASTIC)
	draw_set_transform_matrix(Transform2D.IDENTITY)
