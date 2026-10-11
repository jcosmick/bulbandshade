@tool
class_name JumpArc
extends Node2D
## Gizmo solo per l'editor: disegna dove arriva un salto partendo da qui.
## L'origine del nodo va sul pavimento (dove appoggiano i piedi). In gioco
## si elimina da solo, quindi se ne possono lasciare quanti si vuole nei livelli.
##
## Linea gialla: salto pieno con rincorsa. Linea azzurra: salto da fermo.
## Le curve seguono i piedi: il corpo sporge di circa 30 px per lato.

## Quanto scendere sotto il punto di partenza prima di interrompere le curve.
@export var fall_depth := 400.0:
	set(value):
		fall_depth = value
		queue_redraw()

const RUN_COLOR := Color(1.0, 0.85, 0.3, 0.9)
const STAND_COLOR := Color(0.5, 0.8, 1.0, 0.75)
const APEX_COLOR := Color(1.0, 0.85, 0.3, 0.45)
const STEP := 1.0 / 60.0
const MAX_STEPS := 240


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()


func _draw() -> void:
	draw_arcs(self, Vector2.ZERO, fall_depth)


## Posizioni dei piedi (relative alla partenza) frame per frame, con la stessa
## fisica di Player: direction = -1 o 1, run_start = parte già alla velocità massima.
static func trajectory(direction: float, run_start: bool, depth: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var pos := Vector2.ZERO
	var velocity := Vector2(direction * Player.SPEED if run_start else 0.0, Player.JUMP_VELOCITY)
	# Il frame del salto è ancora a terra: accelerazione da terra, niente gravità.
	velocity.x = move_toward(velocity.x, direction * Player.SPEED, Player.GROUND_ACCEL * STEP)
	pos += velocity * STEP
	points.append(pos)
	for i in MAX_STEPS:
		velocity.y = minf(velocity.y + Player.GRAVITY * STEP, Player.MAX_FALL_SPEED)
		velocity.x = move_toward(velocity.x, direction * Player.SPEED, Player.AIR_ACCEL * STEP)
		pos += velocity * STEP
		points.append(pos)
		if pos.y > depth:
			break
	return points


static func draw_arcs(canvas: CanvasItem, origin: Vector2, depth: float) -> void:
	var apex := 0.0
	for direction in [-1.0, 1.0]:
		for run_start in [false, true]:
			var points := trajectory(direction, run_start, depth)
			for i in points.size():
				points[i] += origin
				apex = minf(apex, points[i].y - origin.y)
			canvas.draw_polyline(points, RUN_COLOR if run_start else STAND_COLOR, 3.0, true)
	var reach := 260.0
	canvas.draw_dashed_line(origin + Vector2(-reach, apex), origin + Vector2(reach, apex), APEX_COLOR, 2.0, 12.0)
	canvas.draw_string(ThemeDB.fallback_font, origin + Vector2(-reach, apex - 8.0),
		"salto max %d px" % roundi(-apex), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, APEX_COLOR)
