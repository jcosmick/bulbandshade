@tool
class_name WaterBasin
extends Node2D
## Vasca d'acqua contenuta in un solo nodo: fondo, due sponde e la pozza
## dentro. Genera da sé i Block e il WaterPool (anche nell'editor, come
## anteprima): non vanno salvati nella scena, si ricreano a ogni caricamento.
## L'origine è il centro del bordo superiore delle sponde: per una fossa nel
## pavimento metti y = pavimento, per una vasca appoggiata y = pavimento - size.y.

## Taglia da sola i Block di terreno che attraversa (es. il pavimento): non
## serve spezzarli a mano. Le casse, i blocchi con ombra e quelli appesi non si
## tagliano. Nell'editor il buco segue la vasca quando la sposti.
@export var cut_floor := true:
	set(value):
		cut_floor = value
		_update_cut()
## Larghezza esterna e profondità (dal bordo delle sponde al sotto del fondo).
@export var size := Vector2(600, 120):
	set(value):
		size = value
		_rebuild()
## Spessore delle sponde laterali.
@export var wall_thickness := 40.0:
	set(value):
		wall_thickness = value
		_rebuild()
## Spessore del fondo.
@export var bottom_thickness := 20.0:
	set(value):
		bottom_thickness = value
		_rebuild()
## Distanza tra il bordo delle sponde e la superficie dell'acqua.
@export var freeboard := 25.0:
	set(value):
		freeboard = value
		_rebuild()
## Togli una sponda quando la vasca è incastrata accanto a un pavimento che
## fa già da parete.
@export var left_wall := true:
	set(value):
		left_wall = value
		_rebuild()
@export var right_wall := true:
	set(value):
		right_wall = value
		_rebuild()

const PART_META := &"water_basin_part"

## Blocchi tagliati ora e firma dell'ultimo taglio (per non rifarlo a vuoto).
var _cut: Array[Block] = []
var _cut_signature := []


func _ready() -> void:
	_rebuild()
	_update_cut()
	set_process(Engine.is_editor_hint())


## Nell'editor ricontrolla il taglio: la vasca o il pavimento possono essersi
## spostati.
func _process(_delta: float) -> void:
	_update_cut()


func _exit_tree() -> void:
	# A gioco si scarica tutto il livello: richiudere i buchi non serve.
	if not Engine.is_editor_hint():
		return
	for block in _cut:
		if is_instance_valid(block):
			block.remove_hole(self)
	_cut.clear()
	_cut_signature = []


## Rettangolo della vasca nel livello: è il buco che apre nel pavimento.
func cut_rect() -> Rect2:
	return Rect2(global_position + Vector2(-size.x / 2.0, 0.0), size)


## Rettangolo occupato dall'acqua, in coordinate locali.
func water_rect() -> Rect2:
	var left := -size.x / 2.0 + (wall_thickness if left_wall else 0.0)
	var right := size.x / 2.0 - (wall_thickness if right_wall else 0.0)
	var top := freeboard
	var bottom := size.y - bottom_thickness
	return Rect2(left, top, maxf(right - left, 0.0), maxf(bottom - top, 0.0))


func _rebuild() -> void:
	if not is_inside_tree():
		return
	# Via i pezzi vecchi (anche quelli copiati da un Ctrl+D nell'editor).
	for child in get_children():
		if child.has_meta(PART_META):
			remove_child(child)
			child.queue_free()
	var water := water_rect()
	_add_block("Bottom", Vector2(0.0, size.y - bottom_thickness / 2.0), Vector2(size.x, bottom_thickness))
	var wall_size := Vector2(wall_thickness, size.y - bottom_thickness)
	var wall_y := wall_size.y / 2.0
	if left_wall:
		_add_block("WallLeft", Vector2(-size.x / 2.0 + wall_thickness / 2.0, wall_y), wall_size)
	if right_wall:
		_add_block("WallRight", Vector2(size.x / 2.0 - wall_thickness / 2.0, wall_y), wall_size)
	if water.size.x > 0.0 and water.size.y > 0.0:
		var pool := WaterPool.new()
		pool.name = "Water"
		pool.size = water.size
		pool.position = water.get_center()
		_add_part(pool)


func _add_block(part_name: String, center: Vector2, block_size: Vector2) -> void:
	if block_size.x <= 0.0 or block_size.y <= 0.0:
		return
	var block := Block.new()
	block.name = part_name
	block.size = block_size
	block.position = center
	_add_part(block)


## I pezzi non hanno owner: l'editor non li mostra nell'albero e non li salva.
func _add_part(part: Node2D) -> void:
	part.set_meta(PART_META, true)
	add_child(part)


func _update_cut() -> void:
	if not is_inside_tree():
		return
	var hole := cut_rect()
	var targets: Array[Block] = []
	if cut_floor:
		for block in _cuttable_blocks(get_parent()):
			if block.global_rect().intersects(hole):
				targets.append(block)
	var signature := [hole]
	for block in targets:
		signature.append_array([block, block.global_position, block.size])
	if signature == _cut_signature:
		return
	_cut_signature = signature
	for block in _cut:
		if is_instance_valid(block) and not targets.has(block):
			block.remove_hole(self)
	for block in targets:
		block.set_hole(self, hole)
	_cut = targets


## Block di terreno nel ramo di "node", esclusi i pezzi generati (della vasca
## o dei blocchi già tagliati) e le altre vasche.
func _cuttable_blocks(node: Node) -> Array[Block]:
	var result: Array[Block] = []
	for child in node.get_children():
		if child == self or child is WaterBasin or child.has_meta(PART_META) or child.has_meta(Block.PIECE_META):
			continue
		if child is Block:
			if child.type == Block.Type.CONCRETE and not child.casts_shadow and child.chain_length <= 0.0 and is_zero_approx(child.global_rotation):
				result.append(child)
			continue
		result.append_array(_cuttable_blocks(child))
	return result
