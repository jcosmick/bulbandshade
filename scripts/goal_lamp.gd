@tool
class_name GoalLamp
extends Area2D
## Il portalampada di arrivo. L'origine del nodo è il bordo superiore del
## portalampada; la base della lampada poggia 120 px più in basso.

signal reached

## Posizione (rispetto al nodo) del centro della lampadina avvitata.
const SOCKET_OFFSET := Vector2(0, -22)
## Stessa famiglia di colori dei portalampada rotti, ma integro e lucidato.
const METAL := Color(0.3, 0.3, 0.34)
const METAL_DARK := Color(0.21, 0.21, 0.25)
const METAL_LIGHT := Color(0.42, 0.42, 0.47)
const BRASS := Color(0.58, 0.47, 0.27)
const BRASS_DARK := Color(0.36, 0.28, 0.15)
const BRASS_LIGHT := Color(0.76, 0.64, 0.42)
const HOLE := Color(0.06, 0.05, 0.05)

var _hint_light: PointLight2D
var _time := 0.0


func _ready() -> void:
	# Il portalampada sta davanti alla lampadina: quando si avvita, l'attacco
	# a vite sparisce dentro invece di restare appoggiato sopra.
	var front := Node2D.new()
	front.z_index = 1
	front.draw.connect(_draw_socket.bind(front))
	add_child(front, false, Node.INTERNAL_MODE_FRONT)
	if Engine.is_editor_hint():
		return
	# Basta toccare la lampada (dal portalampada alla base) per vincere.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(110, 180)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, 30)
	add_child(collision)
	_hint_light = LevelKit.make_light(self, 170.0, 0.5, false)
	_hint_light.position = Vector2(0, -20)
	body_entered.connect(_on_body_entered)
	# Solo il bagliore pulsante: l'area di arrivo resta sempre attiva.
	LevelKit.process_on_screen(self, Rect2(-170, -190, 340, 340))


func socket_position() -> Vector2:
	return global_position + SOCKET_OFFSET


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_hint_light.energy = 0.45 + 0.2 * sin(_time * 2.5)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		reached.emit()


func _draw() -> void:
	# Base a disco con il bordo superiore illuminato.
	draw_rect(Rect2(-48, 108, 96, 12), METAL)
	draw_circle(Vector2(-48, 114), 6.0, METAL)
	draw_circle(Vector2(48, 114), 6.0, METAL)
	draw_line(Vector2(-46, 109), Vector2(46, 109), METAL_LIGHT, 2.0)
	draw_rect(Rect2(-18, 102, 36, 7), METAL_DARK)
	# Stelo con il riflesso e un giunto a metà.
	draw_rect(Rect2(-5, 44, 10, 58), METAL)
	draw_line(Vector2(-2, 46), Vector2(-2, 100), METAL_LIGHT, 2.0)
	draw_rect(Rect2(-8, 70, 16, 8), METAL_DARK)
	# Ghiera a cono sotto il portalampada.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-28, 32), Vector2(28, 32), Vector2(14, 46), Vector2(-14, 46)
	]), METAL)
	draw_line(Vector2(-28, 33), Vector2(28, 33), METAL_LIGHT, 2.0)
	# Bocca vista appena dall'alto: sta dietro, la lampadina avvitata la copre.
	draw_rect(Rect2(-22, -3, 44, 6), HOLE)


## Portalampada d'ottone con la bocca in y = 0 (verso l'alto): qui si avvita
## la lampadina. Disegnato da un nodo davanti a lei.
func _draw_socket(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(-25, 4, 50, 28), BRASS)
	canvas.draw_line(Vector2(-17, 8), Vector2(-17, 29), BRASS_LIGHT, 3.0)
	for i in 2:
		canvas.draw_line(Vector2(-25, 14 + i * 8), Vector2(25, 15 + i * 8), BRASS_DARK, 1.5)
	canvas.draw_rect(Rect2(-25, 29, 50, 3), BRASS_DARK)
	# Labbro in cima e la bocca scura.
	canvas.draw_rect(Rect2(-28, 0, 56, 6), BRASS_DARK)
	canvas.draw_line(Vector2(-27, 1), Vector2(27, 1), BRASS_LIGHT, 1.5)
