@tool
class_name Block
extends StaticBody2D
## Blocco fisso: cemento o cassa di legno (type). Se casts_shadow è attivo,
## quando la lampadina fa il flash proietta un'ombra solida.

enum Type { CONCRETE, BOX }

## Dimensioni in pixel (il blocco è centrato sul nodo).
@export var size := Vector2(200, 40):
	set(value):
		size = value
		queue_redraw()
		if is_cut():
			_refresh_cut()
## Aspetto del blocco: terreno di cemento o cassa di legno.
@export var type := Type.CONCRETE:
	set(value):
		type = value
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
const PIECE_META := &"block_piece"

## Buchi fatti da altri nodi (es. WaterBasin): nodo che taglia -> Rect2 nel
## livello. Un blocco tagliato non disegna e non collide più: al suo posto ci
## sono dei Block figli (i pezzi intorno ai buchi), generati e mai salvati.
var _holes := {}
var _layer := 1


func _ready() -> void:
	if Engine.is_editor_hint():
		# Pezzi copiati da un Ctrl+D: li rigenera chi taglia.
		if not is_cut():
			_free_pieces()
		return
	_layer = collision_layer
	LevelKit.add_rect_collision(self, size, casts_shadow)
	_set_solid(not is_cut())


func get_world_polygon() -> PackedVector2Array:
	if is_cut():
		return PackedVector2Array()
	return global_transform * LevelKit.rect_points(size)


## Rettangolo occupato nel livello (blocchi non ruotati).
func global_rect() -> Rect2:
	return Rect2(global_position - size / 2.0, size)


func is_cut() -> bool:
	return not _holes.is_empty()


## Apre (o sposta) il buco di "cutter": rect è in coordinate del livello.
func set_hole(cutter: Node, rect: Rect2) -> void:
	_holes[cutter] = rect
	_refresh_cut()


func remove_hole(cutter: Node) -> void:
	if _holes.erase(cutter):
		_refresh_cut()


func _refresh_cut() -> void:
	_free_pieces()
	queue_redraw()
	if not Engine.is_editor_hint() and is_node_ready():
		_set_solid(not is_cut())
	if not is_cut() or not is_inside_tree():
		return
	var pieces: Array[Rect2] = [Rect2(-size / 2.0, size)]
	for hole: Rect2 in _holes.values():
		var local := Rect2(to_local(hole.position), hole.size)
		var next: Array[Rect2] = []
		for piece in pieces:
			next.append_array(_subtract(piece, local))
		pieces = next
	for piece in pieces:
		if piece.size.x < 1.0 or piece.size.y < 1.0:
			continue
		var block := Block.new()
		block.size = piece.size
		block.position = piece.get_center()
		block.set_meta(PIECE_META, true)
		add_child(block)


## rect meno hole: prima le colonne intere a sinistra e a destra (così il
## bordo chiaro in cima resta continuo), poi quel che resta sopra e sotto.
static func _subtract(rect: Rect2, hole: Rect2) -> Array[Rect2]:
	if not rect.intersects(hole):
		return [rect]
	var clip := rect.intersection(hole)
	var result: Array[Rect2] = []
	result.append(Rect2(rect.position.x, rect.position.y, clip.position.x - rect.position.x, rect.size.y))
	result.append(Rect2(clip.end.x, rect.position.y, rect.end.x - clip.end.x, rect.size.y))
	result.append(Rect2(clip.position.x, rect.position.y, clip.size.x, clip.position.y - rect.position.y))
	result.append(Rect2(clip.position.x, clip.end.y, clip.size.x, rect.end.y - clip.end.y))
	return result.filter(func(r: Rect2) -> bool: return r.size.x > 0.0 and r.size.y > 0.0)


func _free_pieces() -> void:
	for child in get_children():
		if child.has_meta(PIECE_META):
			remove_child(child)
			child.queue_free()


func _set_solid(solid: bool) -> void:
	collision_layer = _layer if solid else 0
	if solid:
		add_to_group("solids")
		if casts_shadow:
			add_to_group("casters")
	else:
		remove_from_group("solids")
		remove_from_group("casters")


func _draw() -> void:
	if is_cut():
		return
	var top := -size.y / 2.0
	for i in int(chain_length / CHAIN_LINK):
		draw_rect(Rect2(-5.0, top - (i + 1) * CHAIN_LINK, 10.0, CHAIN_LINK - 3.0), CHAIN_COLOR, false, 3.0)
	if type == Type.BOX:
		LevelKit.draw_crate(self, size, false)
	else:
		LevelKit.draw_terrain(self, size)
