@tool
class_name Block
extends StaticBody2D
## Blocco fisso. Se casts_shadow è attivo è una cassa di legno che, quando la
## lampadina fa il flash, proietta un'ombra solida.

## Dimensioni in pixel (il blocco è centrato sul nodo).
@export var size := Vector2(200, 40):
	set(value):
		size = value
		queue_redraw()
@export var casts_shadow := false:
	set(value):
		casts_shadow = value
		queue_redraw()
## Lunghezza della catena disegnata sopra il blocco (0 = nessuna): per le
## casse appese al soffitto. Solo decorativa.
@export var chain_length := 0.0:
	set(value):
		chain_length = value
		queue_redraw()

const CHAIN_LINK := 18.0
const CHAIN_COLOR := Color(0.45, 0.45, 0.5)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("solids")
	if casts_shadow:
		add_to_group("casters")
	LevelKit.add_rect_collision(self, size, casts_shadow)


func get_world_polygon() -> PackedVector2Array:
	return global_transform * LevelKit.rect_points(size)


func _draw() -> void:
	var top := -size.y / 2.0
	for i in int(chain_length / CHAIN_LINK):
		draw_rect(Rect2(-5.0, top - (i + 1) * CHAIN_LINK, 10.0, CHAIN_LINK - 3.0), CHAIN_COLOR, false, 3.0)
	if casts_shadow:
		LevelKit.draw_crate(self, size, false)
	else:
		LevelKit.draw_terrain(self, size)
