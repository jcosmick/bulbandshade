class_name ShadowSystem
extends Node
## Trasforma le ombre del flash in piattaforme solide temporanee.

## Durata (secondi) di un'ombra solida.
@export var lifetime := 4.0
## Se true le ombre si attraversano da sotto e si calpestano da sopra.
@export var one_way := true

## Ombre più piccole di quest'area (px²) vengono scartate.
const MIN_AREA := 600.0
## Passo angolare (radianti) dell'arco che chiude il fondo dell'ombra.
const ARC_STEP := 0.08
## Raggio con cui si calcola la zona nascosta dietro muri e sporgenze:
## abbastanza grande da coprire tutto il livello.
const OCCLUSION_RADIUS := 5000.0
## Bit di light mask degli occluder dei fasci: solo la luce del flash li vede,
## così il bagliore della lampadina e le altre luci li attraversano.
const BEAM_OCCLUDER_MASK := 1 << 1
## Margine (px) entro cui la lampadina conta come "dentro" un fascio
## (circa il raggio del vetro).
const BEAM_INSIDE_MARGIN := 30.0
## Layer fisico delle ombre solide (bit 2): il giocatore e le casse ci
## camminano sopra, le gocce d'acqua le attraversano.
const SHADOW_COLLISION_LAYER := 1 << 1

## Nodo che ospita i corpi fisici delle ombre (il livello corrente).
var world: Node
## Layer su cui si disegnano le ombre, non oscurato dal buio della stanza.
var visual_layer: CanvasLayer
var level_rect := Rect2(0, 0, 1080, 1520)
## Origine dell'ultimo flash: decide quali fasci fanno da barriera visiva.
var _flash_origin := Vector2(-INF, -INF)
## Occluder (solo per la luce del flash) allineati ai fasci accesi.
var _beam_occluders: Array[LightOccluder2D] = []


## Flash del giocatore: ombre dalla sua posizione.
## Restituisce false se la lampadina è dentro il fascio di una finestra: in
## piena luce il flash non può creare ombre.
func flash(origin: Vector2, radius: float) -> bool:
	_flash_origin = origin
	_sync_beam_occluders()
	if is_in_beam(origin):
		return false
	_emit(origin, radius)
	return true


## True se il punto è dentro (o a ridosso di) un fascio di luce acceso.
func is_in_beam(point: Vector2) -> bool:
	return _inside_any(point, _beam_polygons())


## Cancella tutte le ombre (es. quando la lampadina ricompare).
func clear() -> void:
	for platform in visual_layer.get_children():
		if platform is ShadowPlatform:
			platform.dispose()


## I fasci di luce delle finestre tagliano le ombre già esistenti (es. quando
## una persiana si apre o una cassa smette di bloccare il fascio).
func _physics_process(_delta: float) -> void:
	_sync_beam_occluders()
	var beams := _beam_polygons()
	if beams.is_empty() or visual_layer == null:
		return
	for platform in visual_layer.get_children():
		if not platform is ShadowPlatform or platform.is_queued_for_deletion():
			continue
		var touched := false
		for beam in beams:
			if _bounds(beam).intersects(platform.bounds):
				touched = true
				break
		if not touched:
			continue
		var area := _area(platform.polygon)
		var original: Array[PackedVector2Array] = [platform.polygon]
		var pieces := _subtract(original, beams)
		var remaining := 0.0
		for piece in pieces:
			remaining += _area(piece)
		if area - remaining < 50.0:
			continue
		platform.dispose()
		for i in pieces.size():
			if _area(pieces[i]) >= MIN_AREA and not _is_hole(i, pieces):
				_spawn(pieces[i], platform.age)


func _beam_polygons() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for beam in get_tree().get_nodes_in_group("light_beams"):
		result.append_array(beam.beam_polygons())
	return result


## Fasci accesi che fanno da barriera per un flash da "origin": la luce del
## flash non li attraversa (ma non li accende né li riflette). Un flash fatto
## dentro un fascio non crea ombre (vedi flash()); qui quel fascio viene solo
## escluso dagli occluder visivi, così il lampo resta visibile.
func _beam_barriers(origin: Vector2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for beam in get_tree().get_nodes_in_group("light_beams"):
		var polygons: Array[PackedVector2Array] = beam.beam_polygons()
		if not _inside_any(origin, polygons):
			result.append_array(polygons)
	return result


static func _inside_any(point: Vector2, polygons: Array[PackedVector2Array]) -> bool:
	for polygon in polygons:
		for grown in Geometry2D.offset_polygon(polygon, BEAM_INSIDE_MARGIN):
			if Geometry2D.is_point_in_polygon(point, grown):
				return true
	return false


## Tiene gli occluder visivi allineati ai fasci che bloccano l'ultimo flash.
## Agiscono solo sulle luci con BEAM_OCCLUDER_MASK nello shadow_item_cull_mask.
func _sync_beam_occluders() -> void:
	if world == null or not is_instance_valid(world):
		return
	var barriers := _beam_barriers(_flash_origin)
	var used := 0
	for polygon in barriers:
		if used >= _beam_occluders.size():
			_beam_occluders.append(null)
		var occluder := _beam_occluders[used]
		if occluder == null or not is_instance_valid(occluder) or occluder.get_parent() != world:
			occluder = LightOccluder2D.new()
			occluder.occluder = OccluderPolygon2D.new()
			occluder.occluder.cull_mode = OccluderPolygon2D.CULL_DISABLED
			occluder.occluder_light_mask = BEAM_OCCLUDER_MASK
			occluder.sdf_collision = false
			world.add_child(occluder)
			_beam_occluders[used] = occluder
		if occluder.occluder.polygon != polygon:
			occluder.occluder.polygon = polygon
		occluder.visible = true
		used += 1
	for i in range(used, _beam_occluders.size()):
		if is_instance_valid(_beam_occluders[i]):
			_beam_occluders[i].visible = false


static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for v in polygon:
		rect = rect.expand(v)
	return rect


## Una sorgente di luce: proietta le ombre dei casters.
func _emit(origin: Vector2, radius: float) -> void:
	var solids := {}
	for solid in get_tree().get_nodes_in_group("solids"):
		solids[solid] = solid.get_world_polygon()
	# I fasci accesi fermano il flash come un muro.
	_cast_shadows(origin, radius, solids, _beam_barriers(origin))


func _cast_shadows(origin: Vector2, radius: float, solids: Dictionary, barriers: Array[PackedVector2Array]) -> void:
	var bounds := LevelKit.rect_points(level_rect.size)
	for i in bounds.size():
		bounds[i] += level_rect.get_center()

	var beams := _beam_polygons()
	# Zona dietro i fasci vista dal flash: project() vuole poligoni convessi.
	var hidden: Array[PackedVector2Array] = []
	for barrier in barriers:
		for part in Geometry2D.decompose_polygon_in_convex(barrier):
			hidden.append_array(project(origin, part, OCCLUSION_RADIUS))
	for caster in get_tree().get_nodes_in_group("casters"):
		var pieces: Array[PackedVector2Array] = []
		for shadow in project(origin, solids[caster], radius):
			pieces.append_array(Geometry2D.intersect_polygons(shadow, bounds))
		pieces = _subtract(pieces, beams)
		pieces = _subtract(pieces, hidden)
		for solid in solids:
			pieces = _subtract(pieces, [solids[solid]])
			# La zona dietro un altro solido non è raggiunta dalla luce:
			# lì l'ombra della cassa non esiste (non attraversa i muri).
			# Il vetro invece lascia passare la luce.
			if solid != caster and not solid.is_in_group("transparent") and not pieces.is_empty():
				pieces = _subtract(pieces, project(origin, solids[solid], OCCLUSION_RADIUS))
		for i in pieces.size():
			if _area(pieces[i]) >= MIN_AREA and not _is_hole(i, pieces):
				_spawn(pieces[i])


## Ombra proiettata da un poligono convesso illuminato da un punto: va dal
## poligono fino al limite del raggio della luce.
static func project(light: Vector2, polygon: PackedVector2Array, radius: float) -> Array[PackedVector2Array]:
	if polygon.size() < 3 or Geometry2D.is_point_in_polygon(light, polygon):
		return []
	var center := Vector2.ZERO
	for v in polygon:
		center += v
	center /= polygon.size()
	var base_angle := (center - light).angle()

	var points := PackedVector2Array()
	var min_angle := INF
	var max_angle := -INF
	var all_inside := true
	for v in polygon:
		var offset := v - light
		var dist := offset.length()
		points.append(v)
		if dist < radius:
			points.append(light + offset / dist * radius)
		else:
			all_inside = false
		var angle := wrapf(offset.angle() - base_angle, -PI, PI)
		min_angle = minf(min_angle, angle)
		max_angle = maxf(max_angle, angle)
	if points.size() == polygon.size():
		return []
	# Arco sul bordo del raggio per un fondo d'ombra arrotondato.
	if all_inside:
		var steps := ceili((max_angle - min_angle) / ARC_STEP)
		for i in range(1, steps):
			var angle := base_angle + lerpf(min_angle, max_angle, float(i) / steps)
			points.append(light + Vector2.from_angle(angle) * radius)

	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	return Geometry2D.clip_polygons(hull, polygon)


## Grande quadrato che copre il semipiano davanti a "origin" in direzione "front".
static func _half_plane(origin: Vector2, front: Vector2) -> PackedVector2Array:
	var side := front.orthogonal() * OCCLUSION_RADIUS
	var ahead := front * OCCLUSION_RADIUS
	return PackedVector2Array([origin - side, origin + side, origin + side + ahead, origin - side + ahead])


static func _subtract(pieces: Array[PackedVector2Array], cutters: Array) -> Array[PackedVector2Array]:
	for cutter in cutters:
		var clipped: Array[PackedVector2Array] = []
		for piece in pieces:
			clipped.append_array(Geometry2D.clip_polygons(piece, cutter))
		pieces = clipped
	return pieces


func _spawn(polygon: PackedVector2Array, age := 0.0) -> void:
	for clean in _sanitize(polygon):
		_spawn_clean(clean, age)


## I ritagli possono lasciare vertici doppi o quasi allineati che Godot non
## riesce a triangolare: li togliamo e, se serve, ricostruiamo il poligono.
static func _sanitize(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var clean := PackedVector2Array()
	for v in polygon:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(v) > 0.5:
			clean.append(v)
	if clean.size() > 1 and clean[0].distance_to(clean[clean.size() - 1]) <= 0.5:
		clean.remove_at(clean.size() - 1)
	var result: Array[PackedVector2Array] = []
	if clean.size() < 3:
		return result
	if not Geometry2D.triangulate_polygon(clean).is_empty():
		result.append(clean)
		return result
	# Ricostruzione: restringi e riallarga di poco per eliminare i difetti.
	for shrunk in Geometry2D.offset_polygon(clean, -1.0):
		for grown in Geometry2D.offset_polygon(shrunk, 1.0):
			if grown.size() >= 3 and not Geometry2D.triangulate_polygon(grown).is_empty():
				result.append(grown)
	return result


func _spawn_clean(polygon: PackedVector2Array, age: float) -> void:
	var collision := CollisionPolygon2D.new()
	collision.polygon = polygon
	collision.one_way_collision = one_way
	collision.one_way_collision_margin = 16.0
	var body := StaticBody2D.new()
	body.collision_layer = SHADOW_COLLISION_LAYER
	body.collision_mask = 0
	body.add_child(collision)
	world.add_child(body)

	var platform := ShadowPlatform.new()
	platform.setup(polygon, lifetime, body, age)
	visual_layer.add_child(platform)


static func _area(polygon: PackedVector2Array) -> float:
	var sum := 0.0
	for i in polygon.size():
		sum += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(sum) / 2.0


## Il ritaglio può restituire "buchi" (un solido tutto dentro l'ombra):
## sono i pezzi contenuti in un altro pezzo.
static func _is_hole(index: int, pieces: Array[PackedVector2Array]) -> bool:
	var center := Vector2.ZERO
	for v in pieces[index]:
		center += v
	center /= pieces[index].size()
	for j in pieces.size():
		if j != index and Geometry2D.is_point_in_polygon(center, pieces[j]):
			return true
	return false
