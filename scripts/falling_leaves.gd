class_name FallingLeaves
extends Node2D
## Foglioline che si staccano da un rampicante scosso dalla lampadina e cadono
## ondeggiando. Va aggiunto come figlio del rampicante: le foglie stanno nelle
## sue coordinate locali. Lavora solo finché c'è qualche foglia in aria.

## Sagoma della foglia, con il picciolo nell'origine e la punta in (1, 0).
const SHAPE := [
	Vector2(0, 0), Vector2(0.25, -0.3), Vector2(0.6, -0.32),
	Vector2(1, 0), Vector2(0.6, 0.32), Vector2(0.25, 0.3),
]
## Velocità di caduta (px/s) e quanto ci mette a raggiungerla.
const FALL_SPEED := 55.0
const DRAG := 2.5
const GRAVITY := 260.0
## Ondeggiamento orizzontale mentre cade: ampiezza (px/s) e frequenza.
const FLUTTER := 45.0
const FLUTTER_SPEED := 3.2
## Durata della caduta prima di sparire (s); a terra resta un po' e sfuma.
const LIFETIME := 2.6
const GROUND_TIME := 0.8
const FADE := 0.5
const MAX_LEAVES := 14

## Quota del pavimento in coordinate locali (le foglie ci si posano);
## INF se non c'è un pavimento noto e le foglie sfumano cadendo.
var floor_y := INF
var leaf_shape := PackedVector2Array(SHAPE)

var _leaves: Array[Dictionary] = []


func _ready() -> void:
	set_physics_process(false)


## Stacca una foglia in `at` (coordinate locali), spinta da `push` (px/s).
func spawn(at: Vector2, push: Vector2, size: float, color: Color) -> void:
	if _leaves.size() >= MAX_LEAVES:
		return
	_leaves.append({
		pos = at,
		vel = push * 0.35 + Vector2(randf_range(-20.0, 20.0), randf_range(-40.0, -10.0)),
		angle = randf() * TAU,
		spin = randf_range(-3.0, 3.0),
		phase = randf() * TAU,
		size = size * randf_range(0.8, 1.15),
		color = color,
		age = 0.0,
		landed = -1.0,
	})
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	for i in range(_leaves.size() - 1, -1, -1):
		var leaf: Dictionary = _leaves[i]
		leaf.age += delta
		if leaf.landed >= 0.0:
			leaf.landed += delta
			if leaf.landed > GROUND_TIME + FADE:
				_leaves.remove_at(i)
			continue
		if leaf.age > LIFETIME + FADE:
			_leaves.remove_at(i)
			continue
		var vel: Vector2 = leaf.vel
		vel.y = minf(vel.y + GRAVITY * delta, FALL_SPEED)
		vel.x = lerpf(vel.x, 0.0, minf(1.0, DRAG * delta))
		leaf.vel = vel
		var flutter := sin(leaf.age * FLUTTER_SPEED + leaf.phase)
		var pos: Vector2 = leaf.pos + (vel + Vector2(flutter * FLUTTER, 0)) * delta
		leaf.angle += (leaf.spin + flutter * 1.5) * delta
		if pos.y >= floor_y - 2.0:
			pos.y = floor_y - 2.0
			# Si posa di piatto.
			leaf.angle = 0.0 if cos(leaf.angle) >= 0.0 else PI
			leaf.landed = 0.0
		leaf.pos = pos
	queue_redraw()
	if _leaves.is_empty():
		set_physics_process(false)


func _draw() -> void:
	for leaf in _leaves:
		var alpha := 1.0
		if leaf.landed >= 0.0:
			alpha = clampf(1.0 - (leaf.landed - GROUND_TIME) / FADE, 0.0, 1.0)
		else:
			alpha = clampf(1.0 - (leaf.age - LIFETIME) / FADE, 0.0, 1.0)
		var size: float = leaf.size
		# Girando su se stessa la foglia si vede di taglio: la si schiaccia.
		var squash := 0.5
		if leaf.landed < 0.0:
			squash = 0.35 + 0.65 * absf(sin(leaf.age * FLUTTER_SPEED * 0.7 + leaf.phase))
		var xform := Transform2D(leaf.angle, Vector2(size, size * squash), 0.0, leaf.pos)
		var color: Color = leaf.color
		draw_colored_polygon(xform * leaf_shape, Color(color, color.a * alpha))
		draw_line(leaf.pos, xform * Vector2(0.8, 0), Color(GroundPlant.VEIN, alpha), 1.0)
