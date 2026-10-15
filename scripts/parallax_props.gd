@tool
extends Node2D
## Layer di prop in primo piano o sullo sfondo. Nell'editor i figli si
## posizionano dentro il livello, nel punto in cui devono passare al centro
## dell'area di gioco: in gioco scorrono di scroll_scale rispetto alla
## telecamera e quando la telecamera è centrata su quel punto sono esattamente
## lì. Se la telecamera non ci arriva (vicino ai bordi del livello) sono lì
## quando la telecamera è ferma al bordo.
##
## Non usa Parallax2D: quello sposta da solo il proprio nodo in base alla
## telecamera e falserebbe le posizioni dei figli.

## Velocità di scorrimento rispetto al livello: sopra 1 = più vicino alla
## telecamera, sotto 1 = più lontano.
@export var scroll_scale := Vector2.ONE
## Se attivo, cambiando scroll_scale.x nell'editor i figli vengono
## ridimensionati in proporzione (da 1.2 a 2.4 diventano grandi il doppio).
## La scale salvata è già quella che si vede in gioco.
@export var scale_with_depth := true
## scroll_scale.x con cui sono state salvate le scale dei figli.
@export_storage var _depth := 1.0

## Posizione nell'editor (locale al layer) di ogni figlio.
var _anchors := {}
## La scena di gioco (game.gd), che conosce telecamera e area di gioco.
var _game: Node
## Solo per il layer in primo piano: stesso buio del gioco, applicato al suo canvas.
var _front_dark: CanvasModulate


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered)
	_reset_z_indices.call_deferred()
	if Engine.is_editor_hint():
		return
	# Dopo game.gd, che sposta la telecamera nel suo _process.
	process_priority = 100
	for child in get_children():
		if child is Node2D:
			_anchors[child] = child.position
	_game = get_parent()
	while _game and not _game.has_method("reachable_view_center"):
		_game = _game.get_parent()
	if z_index >= 50:
		_move_to_front_layer()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_depth_scale()
		return
	if not _game:
		return
	var center: Vector2 = _game.view_center()
	if _front_dark:
		_front_dark.color = _game._darkness.color
	for child in _anchors:
		if is_instance_valid(child):
			var anchor := to_global(_anchors[child])
			var reference: Vector2 = _game.reachable_view_center(anchor)
			child.global_position = anchor + (Vector2.ONE - scroll_scale) * (center - reference)


## L'acqua e gli altri overlay stanno su CanvasLayer 1-2, che coprono qualsiasi
## z_index del mondo: il primo piano deve stare su un layer più alto.
func _move_to_front_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	layer.follow_viewport_enabled = true
	add_child(layer)
	_front_dark = CanvasModulate.new()
	layer.add_child(_front_dark)
	var holder := Node2D.new()
	holder.modulate = modulate
	modulate = Color.WHITE
	layer.add_child(holder)
	for child in _anchors.keys():
		child.reparent(holder, false)
		child.z_index = 0


func _update_depth_scale() -> void:
	if is_equal_approx(scroll_scale.x, _depth):
		return
	if scale_with_depth and _depth > 0.0 and scroll_scale.x > 0.0:
		var ratio := scroll_scale.x / _depth
		for child in get_children():
			if child is Node2D:
				child.scale *= ratio
	_depth = scroll_scale.x


## I prop si mettono da soli uno z_index negativo: qui conta solo quello del
## layer, sia nell'editor sia in gioco.
func _reset_z_indices() -> void:
	for child in get_children():
		if child is Node2D:
			child.z_index = 0


func _on_child_entered(child: Node) -> void:
	if child is Node2D:
		(func(): child.z_index = 0).call_deferred()
