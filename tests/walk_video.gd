extends Node
## Video della camminata (solo sviluppo): livello 9, tiene premuto destra.
## Uso: Godot --path . --write-movie out.avi --fixed-fps 60 res://tests/walk_video.tscn

const WALK_SECONDS := 6.0

var _game: Node
var _walking := false
var _time := 0.0


func _ready() -> void:
	get_window().size = Vector2i(720, 1560)
	Progress.persist = false
	Progress.selected_level = 8
	_game = load("res://scenes/game.tscn").instantiate()
	add_child(_game)
	_run.call_deferred()


func _run() -> void:
	while get_tree().paused or _game.player == null:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	Input.action_press("move_right")
	_walking = true
	await get_tree().create_timer(WALK_SECONDS).timeout
	Input.action_release("move_right")
	get_tree().quit()


func _process(delta: float) -> void:
	if not _walking:
		return
	_time += delta
	# Posizione della lampadina sullo schermo: se la telecamera la segue bene resta quasi ferma.
	var screen: Vector2 = _game.player.get_global_transform_with_canvas().origin
	print("t=%.3f screen=(%.2f, %.2f) world_x=%.2f" % [_time, screen.x, screen.y, _game.player.global_position.x])
