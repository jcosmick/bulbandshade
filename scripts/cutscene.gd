@tool
class_name Cutscene
extends Node2D
## Breve scena animata all'apertura di un livello. Va messa nel livello come
## nodo "Intro" (in posizione 0, 0): la scena di gioco la avvia dopo aver
## caricato il livello. Parte solo la prima volta che il livello viene aperto
## (fino alla chiusura del gioco) e si salta con un tocco, salto o flash.
## Le sottoclassi ridefiniscono _play() (con await wait() / wait_until()) ed _end().

## Emesso a ogni frame di fisica mentre la cutscene è in corso: lo aspettano
## wait() e wait_until(). Se la cutscene viene saltata o il livello chiuso,
## il nodo sparisce e le attese in sospeso vengono semplicemente abbandonate.
signal _tick(delta: float)

## Livelli di cui la cutscene è già stata vista.
static var _seen := {}

## La scena di gioco (game.gd).
var game: Node
var _running := false


## Avvia la cutscene, o la scarta se è già stata vista.
func start(game_scene: Node) -> void:
	var key := owner.scene_file_path if owner else ""
	if _seen.has(key):
		queue_free()
		return
	_seen[key] = true
	game = game_scene
	_running = true
	game.player.controls_enabled = false
	game.set_controls_visible(false)
	_add_skip_hint()
	await _play()
	_finish(false)


## Da ridefinire: i passi della cutscene.
func _play() -> void:
	await wait(0.0)


## Da ridefinire: rimette il livello pronto per giocare. skipped = saltata a metà.
func _end(_skipped: bool) -> void:
	pass


## Aspetta un certo numero di secondi (si ferma con il gioco in pausa).
func wait(seconds: float) -> void:
	while seconds > 0.0:
		seconds -= await _tick


## Aspetta che condition restituisca true, al massimo timeout secondi.
func wait_until(condition: Callable, timeout := 8.0) -> void:
	while not condition.call() and timeout > 0.0:
		timeout -= await _tick


func _physics_process(delta: float) -> void:
	if _running:
		_tick.emit(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	var tap: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed
	if tap or event.is_action_pressed("jump") or event.is_action_pressed("flash"):
		get_viewport().set_input_as_handled()
		_finish(true)


func _finish(skipped: bool) -> void:
	if not _running:
		return
	_running = false
	_end(skipped)
	game.camera_focus = null
	game.set_controls_visible(true)
	game.player.controls_enabled = true
	queue_free()


func _add_skip_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var label := Label.new()
	label.text = "Tap to skip"
	label.add_theme_font_size_override("font_size", 36)
	label.modulate.a = 0.6
	layer.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 60)
