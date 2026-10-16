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
## Solo primo piano: prop che fanno il "wooom" ogni volta che passano davanti
## alla telecamera. I prop che non sono in nessuna delle due liste sono muti.
@export var pass_sound_always: Array[Node2D] = []
## Solo primo piano: prop che fanno il "wooom" solo al primo passaggio (finché
## si resta nel livello, anche dopo una morte). Vince su pass_sound_always.
@export var pass_sound_once: Array[Node2D] = []

## Posizione nell'editor (locale al layer) di ogni figlio.
var _anchors := {}
## La scena di gioco (game.gd), che conosce telecamera e area di gioco.
var _game: Node
## Solo per il layer in primo piano: stesso buio del gioco, applicato al suo canvas.
var _front_dark: CanvasModulate
## Solo primo piano: "wooom" quando un prop sfreccia davanti alla telecamera.
var _pass_sound: AudioStreamPlayer2D
## Il prop che sta facendo il wooom: il suono lo segue (panning da un lato all'altro).
var _pass_target: Node2D
## Distanza orizzontale di ogni prop dal centro dell'inquadratura al frame prima.
var _pass_offsets := {}
var _pass_cooldown := 0.0
## I prop di pass_sound_once che hanno già fatto il loro wooom.
var _pass_played := {}

## Secondo in cui pass_by è al massimo (PASS_PEAK in tools/make_sfx.py): il
## suono parte prima, così il picco cade quando il prop è al centro.
const PASS_PEAK := 0.45
## Velocità sullo schermo (px/s) sotto cui il prop non fa rumore e sopra cui
## lo fa a pieno volume. Camminando la telecamera va a ~520 px/s e un prop a
## profondità 1.8 attraversa lo schermo a ~940 px/s.
const PASS_SPEED := Vector2(400.0, 900.0)
## Oltre questa velocità è un salto della telecamera (respawn), non un passaggio.
const PASS_MAX_SPEED := 4000.0
## Secondi minimi tra due wooom (più lungo di PASS_PEAK: un prop ne fa uno solo).
const PASS_COOLDOWN := 0.6


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
	if scroll_scale.x > 1.0 and not (pass_sound_always.is_empty() and pass_sound_once.is_empty()):
		_pass_sound = Sfx.make_player_2d("pass_by", self)
		# Nessuna attenuazione con la distanza, solo il panning sinistra/destra.
		_pass_sound.attenuation = 0.0
		_pass_sound.max_distance = 100000.0


func _process(delta: float) -> void:
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
	if _pass_sound:
		_update_pass_by(center, delta)


## Fa partire il wooom quando un prop arriverà al centro dell'inquadratura tra
## PASS_PEAK secondi, con volume e intonazione dalla sua velocità sullo schermo.
func _update_pass_by(center: Vector2, delta: float) -> void:
	_pass_cooldown -= delta
	if _pass_sound.playing and is_instance_valid(_pass_target):
		_pass_sound.global_position = _pass_target.global_position
	if delta <= 0.0:
		return
	var view_height: float = _game.visible_world_rect().size.y
	for child in _anchors:
		if not is_instance_valid(child):
			continue
		var offset: float = child.global_position.x - center.x
		var previous: float = _pass_offsets.get(child, offset)
		_pass_offsets[child] = offset
		if _pass_cooldown > 0.0 or not _makes_pass_sound(child):
			continue
		var speed := (offset - previous) / delta
		if absf(speed) < PASS_SPEED.x or absf(speed) > PASS_MAX_SPEED:
			continue
		var arrival := -offset / speed
		if arrival < 0.0 or arrival > PASS_PEAK:
			continue
		# Prop fuori dall'inquadratura in verticale: passa senza farsi sentire.
		if absf(child.global_position.y - center.y) > view_height * 0.75:
			continue
		var strength := clampf(inverse_lerp(PASS_SPEED.x, PASS_SPEED.y, absf(speed)), 0.0, 1.0)
		_pass_target = child
		if child in pass_sound_once:
			_pass_played[child] = true
		_pass_sound.global_position = child.global_position
		_pass_sound.volume_db = -10.0 + linear_to_db(lerpf(0.35, 1.0, strength))
		_pass_sound.pitch_scale = lerpf(0.85, 1.08, strength) * randf_range(0.96, 1.04)
		_pass_sound.play()
		_pass_cooldown = PASS_COOLDOWN


## True se il prop deve ancora farsi sentire: è in pass_sound_always, oppure
## è in pass_sound_once e non ha ancora fatto il suo wooom.
func _makes_pass_sound(child: Node2D) -> bool:
	if child in pass_sound_once:
		return not _pass_played.has(child)
	return child in pass_sound_always


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
