class_name LevelKit
extends RefCounted
## Funzioni condivise: forme di collisione, luci e disegno degli elementi.

const WOOD := Color(0.66, 0.45, 0.25)
const WOOD_DARK := Color(0.40, 0.25, 0.13)
const TERRAIN := Color(0.25, 0.23, 0.28)
const TERRAIN_EDGE := Color(0.42, 0.39, 0.46)
const LIGHT_COLOR := Color(1.0, 0.86, 0.6)
## Raggio (px) della texture della luce a texture_scale = 1.
const LIGHT_TEXTURE_RADIUS := 128.0
## Le luci create qui si spengono da sole quando la loro energia è 0.
const AutoLight := preload("res://scripts/auto_light.gd")
## Gruppo di tutte le luci create qui (le AutoLight vi entrano da sole).
const LIGHTS_GROUP := &"auto_lights"

static var _light_texture: Texture2D
## Materiali condivisi da tutto il gioco (vedi shared_material).
static var _materials := {}


static func rect_points(size: Vector2) -> PackedVector2Array:
	var h := size / 2.0
	return PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)
	])


## Aggiunge al corpo una collisione rettangolare centrata e, se richiesto,
## un occluder che blocca la luce (ombre visive).
static func add_rect_collision(body: CollisionObject2D, size: Vector2, occluder: bool) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	if occluder:
		var polygon := OccluderPolygon2D.new()
		polygon.polygon = rect_points(size)
		# Solo i lati in ombra bloccano la luce: l'oggetto resta illuminato.
		polygon.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
		var light_occluder := LightOccluder2D.new()
		light_occluder.occluder = polygon
		body.add_child(light_occluder)


static func light_texture() -> Texture2D:
	if _light_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.45, Color(1, 1, 1, 0.55))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 256
		texture.height = 256
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		_light_texture = texture
	return _light_texture


static func make_light(parent: Node, radius: float, energy: float, shadows: bool) -> PointLight2D:
	var light: PointLight2D = AutoLight.new()
	light.texture = light_texture()
	light.texture_scale = radius / LIGHT_TEXTURE_RADIUS
	light.energy = energy
	light.enabled = energy > 0.0
	light.color = LIGHT_COLOR
	light.shadow_enabled = shadows
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	parent.add_child(light)
	return light


## Materiale con questa fusione e modalità di luce, uno solo per tutto il gioco.
## Lo shader di un materiale si compila la prima volta che si disegna (sui
## telefoni anche mezzo secondo) e Godot lo butta quando nessun materiale lo
## usa più: con materiali nuovi per ogni oggetto si ricompilerebbe a ogni
## livello caricato.
static func shared_material(blend: CanvasItemMaterial.BlendMode, light_mode := CanvasItemMaterial.LIGHT_MODE_NORMAL) -> CanvasItemMaterial:
	var key := Vector2i(blend, light_mode)
	if not _materials.has(key):
		var material := CanvasItemMaterial.new()
		material.blend_mode = blend
		material.light_mode = light_mode
		_materials[key] = material
	return _materials[key]


## Fa compilare subito lo shader con cui si disegna `item` (il suo materiale,
## nel suo stesso layer): per qualche frame un figlio disegna un pixel quasi
## trasparente al centro dello schermo. Così la compilazione avviene mentre il
## livello si carica e non la prima volta che l'oggetto entra nell'inquadratura.
## Con free_item, alla fine libera anche `item` (un supporto creato apposta).
static func prewarm(item: CanvasItem, frames := 3, free_item := false) -> void:
	var probe := Node2D.new()
	probe.use_parent_material = true
	probe.draw.connect(func() -> void:
		var center := probe.get_global_transform_with_canvas().affine_inverse() * (probe.get_viewport_rect().size / 2.0)
		probe.draw_rect(Rect2(center, Vector2.ONE), Color(1, 1, 1, 0.004)))
	item.add_child(probe, false, Node.INTERNAL_MODE_BACK)
	# item può non essere ancora nell'albero (prewarm chiamato prima di
	# add_child): il main loop invece c'è sempre.
	var tree := Engine.get_main_loop() as SceneTree
	for i in frames:
		await tree.process_frame
		if not is_instance_valid(probe):
			return
		probe.queue_redraw()
	probe.queue_free()
	if free_item and is_instance_valid(item):
		item.queue_free()


## Margine (px) attorno allo schermo entro cui un elemento conta già come
## visibile: si rimette in moto un attimo prima di entrare nell'inquadratura.
const ON_SCREEN_MARGIN := 96.0


## Ferma _process e _physics_process di `node` finché `rect` (in coordinate
## locali di node: tutto ciò che disegna) è fuori dall'inquadratura, così gli
## elementi lontani dalla telecamera non costano nulla. Ferma solo gli script:
## collisioni e aree restano attive. Da usare solo per animazioni che possono
## congelarsi senza conseguenze sul gioco (non per timer, casse in caduta e
## simili). Va chiamata in _ready, solo in gioco.
static func process_on_screen(node: Node2D, rect: Rect2) -> void:
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = rect.grow(ON_SCREEN_MARGIN)
	notifier.screen_entered.connect(func() -> void: _set_processing(node, true))
	notifier.screen_exited.connect(func() -> void: _set_processing(node, false))
	node.add_child(notifier, false, Node.INTERNAL_MODE_BACK)
	# Parte fermo: se è inquadrato screen_entered arriva al primo frame.
	_set_processing(node, false)


static func _set_processing(node: Node, on: bool) -> void:
	node.set_process(on)
	node.set_physics_process(on)


## Nodo di disegno su un layer sopra il buio della stanza (l'acqua e la luce
## delle finestre devono vedersi sempre). Con follow_owner disegna nelle
## coordinate locali di owner, altrimenti in coordinate del livello.
## Va chiamata in _ready, quando la posizione di owner è già definitiva.
## Layer 1 = come le ombre solide; layer 2 = sopra le ombre (pericoli, acqua).
static func make_overlay(owner: Node2D, follow_owner := true, layer_index := 1) -> Node2D:
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	layer.follow_viewport_enabled = true
	owner.add_child(layer)
	var canvas := Node2D.new()
	if follow_owner:
		canvas.transform = owner.global_transform
	layer.add_child(canvas)
	return canvas


## Cassa di legno: gli oggetti di legno sono quelli che creano ombre solide.
static func draw_crate(item: CanvasItem, size: Vector2, braced: bool) -> void:
	var rect := Rect2(-size / 2.0, size)
	item.draw_rect(rect, WOOD)
	var plank := size.y / 3.0
	for i in range(1, 3):
		var y := rect.position.y + plank * i
		item.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), WOOD_DARK, 3.0)
	if braced:
		var inset := rect.grow(-10.0)
		item.draw_line(inset.position, inset.end, WOOD_DARK, 8.0)
		item.draw_line(Vector2(inset.position.x, inset.end.y), Vector2(inset.end.x, inset.position.y), WOOD_DARK, 8.0)
	item.draw_rect(rect.grow(-4.0), WOOD_DARK, false, 8.0)


static func draw_terrain(item: CanvasItem, size: Vector2) -> void:
	var rect := Rect2(-size / 2.0, size)
	item.draw_rect(rect, TERRAIN)
	item.draw_rect(Rect2(rect.position, Vector2(size.x, minf(6.0, size.y))), TERRAIN_EDGE)


## La lampadina del livello che contiene `node` (null fuori da un livello).
## Va chiamata in _ready o dopo, quando il livello è già nell'albero.
static func find_player(node: Node) -> Player:
	var parent := node.get_parent()
	while parent != null and not parent is Level:
		parent = parent.get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("Player") as Player
