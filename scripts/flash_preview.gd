@tool
class_name FlashPreview
extends Node2D
## Gizmo solo per l'editor: mostra le ombre solide che crea un flash fatto da
## qui, con lo stesso calcolo del gioco (ShadowSystem). L'origine del nodo va
## dove sono i piedi della lampadina, come per JumpArc: sul pavimento se il
## flash si fa da fermi, più in alto per un flash a mezz'aria.
## In gioco si elimina da solo, quindi se ne possono lasciare quanti si vuole.
##
## Viola: ombre solide. Bordo verde: lati calpestabili (le ombre si
## attraversano da sotto e si calpestano da sopra). Giallo: fasci delle finestre.

## Raggio del flash (0 = quello del Player del livello).
@export var flash_radius := 0.0:
	set(value):
		flash_radius = value
		_dirty = true
## Considera le finestre aperte (persiane intermittenti comprese).
@export var windows_open := true:
	set(value):
		windows_open = value
		_dirty = true
## Considera le RailCrate già arrivate a fine corsa (dopo il pulsante).
@export var rail_crates_arrived := false:
	set(value):
		rail_crates_arrived = value
		_dirty = true
## Disegna anche le curve del salto da qui.
@export var show_jump_arc := false:
	set(value):
		show_jump_arc = value
		queue_redraw()

const SHADOW_FILL := Color(0.35, 0.2, 0.6, 0.45)
const SHADOW_EDGE := Color(0.7, 0.55, 1.0, 0.9)
const WALKABLE_EDGE := Color(0.4, 1.0, 0.5, 1.0)
const BEAM_FILL := Color(1.0, 0.93, 0.6, 0.12)
const RADIUS_COLOR := Color(1.0, 0.95, 0.7, 0.35)
const BULB_COLOR := Color(1.0, 0.95, 0.7, 0.8)
const BLOCKED_COLOR := Color(1.0, 0.35, 0.3, 0.95)
const DEFAULT_RADIUS := 750.0
## Centro della capsula della lampadina rispetto ai piedi.
const PLAYER_CENTER := Vector2(0, -52)
## Pendenza massima di un lato su cui si cammina (come floor_max_angle del Player).
const WALKABLE_ANGLE := deg_to_rad(55.0)
## Ogni quanto (s) controllare se il livello è cambiato.
const REFRESH := 0.15

var _shadows: Array[PackedVector2Array] = []
var _beams: Array[PackedVector2Array] = []
var _in_beam := false
var _radius := DEFAULT_RADIUS
var _signature := []
var _dirty := true
var _wait := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	z_index = 50


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_wait -= delta
	if _wait > 0.0 and not _dirty:
		return
	_wait = REFRESH
	_refresh()


## Ricalcola le ombre solo se qualcosa nel livello si è mosso o è cambiato.
func _refresh() -> void:
	var root := get_tree().edited_scene_root if is_inside_tree() else null
	if root == null or not root.is_ancestor_of(self):
		return
	_compute(root)


func _compute(root: Node) -> void:
	var solids := {}
	var casters: Array = []
	var transparent: Array = []
	var windows: Array[WindowLight] = []
	var player: Player = null
	var signature := [global_transform, flash_radius, windows_open, rail_crates_arrived]
	for node in _descendants(root):
		if node is Block and node.is_cut():
			continue  # al suo posto contano i pezzi figli
		if node is Block or node is GlassPane or node is PushBox or node is RailCrate:
			var polygon: PackedVector2Array = node.get_world_polygon()
			if node is RailCrate and rail_crates_arrived:
				var shift := Vector2(node.travel, 0.0)
				for i in polygon.size():
					polygon[i] += shift
			solids[node] = polygon
			var casts: bool = (node is Block and node.casts_shadow) or node is PushBox or node is RailCrate
			if casts:
				casters.append(node)
			if node is GlassPane:
				transparent.append(node)
			signature.append_array([polygon, casts])
		elif node is WindowLight and windows_open:
			windows.append(node)
			signature.append_array([node.global_transform, node.opening, node.direction, node.length])
		elif node is Player and player == null:
			player = node
			signature.append(node.flash_radius)
	var rect: Variant = root.get("level_rect")
	signature.append(rect)
	if signature == _signature and not _dirty:
		return
	_signature = signature
	_dirty = false

	_radius = flash_radius
	if _radius <= 0.0:
		_radius = player.flash_radius if player else DEFAULT_RADIUS
	var level_rect: Rect2 = rect if rect is Rect2 else Rect2(-10000, -10000, 20000, 20000)
	var opaque: Array[PackedVector2Array] = []
	for solid in solids:
		if not transparent.has(solid):
			opaque.append(solids[solid])
	_beams.clear()
	var barriers: Array[PackedVector2Array] = []
	var origin := _light_origin()
	for window in windows:
		var polygons := window.compute_beam(opaque)
		_beams.append_array(polygons)
		# Come ShadowSystem._beam_barriers: il fascio in cui si trova la
		# lampadina non fa da barriera.
		if not ShadowSystem._inside_any(origin, polygons):
			barriers.append_array(polygons)
	_in_beam = ShadowSystem._inside_any(origin, _beams)
	_shadows.clear()
	if not _in_beam:
		for polygon in ShadowSystem.shadow_polygons(origin, _radius, level_rect, solids, casters, transparent, _beams, barriers):
			_shadows.append_array(ShadowSystem._sanitize(polygon))
	queue_redraw()


static func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result


## Punto da cui parte la luce del flash: come Player.light_origin().
func _light_origin() -> Vector2:
	return global_position + PLAYER_CENTER + Player.LIGHT_OFFSET


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var light := PLAYER_CENTER + Player.LIGHT_OFFSET
	# Lampadina fantasma: capsula del corpo e vetro.
	draw_rect(Rect2(-30, -104, 60, 104), Color(BULB_COLOR, 0.25), false, 2.0)
	draw_circle(light, 30.0, Color(BULB_COLOR, 0.25))
	draw_arc(light, 30.0, 0.0, TAU, 32, BULB_COLOR, 3.0)
	draw_arc(light, _radius, 0.0, TAU, 96, RADIUS_COLOR, 2.0)

	# Le ombre sono in coordinate del livello.
	draw_set_transform_matrix(global_transform.affine_inverse())
	for beam in _beams:
		draw_colored_polygon(beam, BEAM_FILL)
	for shadow in _shadows:
		draw_colored_polygon(shadow, SHADOW_FILL)
		var closed := shadow.duplicate()
		closed.append(shadow[0])
		draw_polyline(closed, SHADOW_EDGE, 2.0)
		_draw_walkable(shadow)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	var font := ThemeDB.fallback_font
	if _in_beam:
		draw_line(light + Vector2(-24, -24), light + Vector2(24, 24), BLOCKED_COLOR, 5.0)
		draw_line(light + Vector2(-24, 24), light + Vector2(24, -24), BLOCKED_COLOR, 5.0)
		draw_string(font, light + Vector2(40, 8), "dentro un fascio: niente ombre",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, BLOCKED_COLOR)
	else:
		draw_string(font, light + Vector2(40, 8), "flash: %d ombre" % _shadows.size(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, BULB_COLOR)
	if show_jump_arc:
		JumpArc.draw_arcs(self, Vector2.ZERO, 400.0)


## Evidenzia i lati rivolti verso l'alto, cioè quelli su cui si può camminare.
func _draw_walkable(polygon: PackedVector2Array) -> void:
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		if a.distance_to(b) < 8.0:
			continue
		var normal := (b - a).orthogonal().normalized()
		# Normale verso l'esterno del poligono.
		if Geometry2D.is_point_in_polygon((a + b) / 2.0 + normal * 2.0, polygon):
			normal = -normal
		if absf(normal.angle_to(Vector2.UP)) <= WALKABLE_ANGLE:
			draw_line(a, b, WALKABLE_EDGE, 5.0)
