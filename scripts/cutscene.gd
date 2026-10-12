@tool
class_name Cutscene
extends Node2D
## Breve scena animata all'apertura di un livello. Va messa nel livello come
## nodo "Intro" (in posizione 0, 0): la scena di gioco la avvia dopo aver
## caricato il livello. Parte solo la prima volta che il livello viene aperto
## (fino alla chiusura del gioco) e non si può saltare.
## Le sottoclassi ridefiniscono _play() (con await wait() / wait_until()) ed _end().

## Emesso a ogni frame di fisica mentre la cutscene è in corso: lo aspettano
## wait() e wait_until(). Se il livello viene chiuso o ricominciato, il nodo
## sparisce e le attese in sospeso vengono semplicemente abbandonate.
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
	await _play()
	_finish()


## Da ridefinire: i passi della cutscene.
func _play() -> void:
	await wait(0.0)


## Da ridefinire: rimette il livello pronto per giocare.
func _end() -> void:
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


func _finish() -> void:
	_running = false
	_end()
	game.camera_focus = null
	game.set_controls_visible(true)
	game.player.controls_enabled = true
	queue_free()

