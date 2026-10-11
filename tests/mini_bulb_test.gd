extends Node
## Test delle mini lampadine (solo sviluppo): nel livello 4 la lampadina va
## sulla mini lampadina rossa (screenshot dell'animazione), poi nel menu la
## mini lampadina compare e un tocco le fa fare il mini flash.
## Uso: Godot --path . res://tests/mini_bulb_test.tscn -- --out=<cartella>

var out_dir := "user://autotest"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	# Progressi solo in memoria: il salvataggio vero non viene toccato.
	Progress.persist = false
	Progress._best_flashes.clear()
	Progress._mini_bulbs.clear()
	Progress.selected_level = 3
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(0.5).timeout
	var bulb: MiniBulb = game.level.get_node("MiniBulbRed")
	game.player.global_position = bulb.global_position + Vector2(-150, 0)
	await get_tree().create_timer(0.4).timeout
	await _shot("level_before")
	game.player.global_position = bulb.global_position
	await get_tree().create_timer(0.4).timeout
	await _shot("level_collect")
	await get_tree().create_timer(1.5).timeout
	print("RACCOLTA: ", Progress.has_mini_bulb("level04_red"))
	await _shot("level_after")

	# Livello 5: dalla cima di CrateA salto oltre la pozza, prendo la mini
	# lampadina verde nell'angolo e torno sulla cassa con un salto.
	game.load_level(4)
	await get_tree().create_timer(0.3).timeout
	game.player.global_position = Vector2(1530, 1888)
	await get_tree().create_timer(0.3).timeout
	Input.action_press("move_right")
	await _jump(0.4)
	await get_tree().create_timer(1.2).timeout
	Input.action_release("move_right")
	await get_tree().create_timer(0.3).timeout
	await _shot("level5_collect")
	print("VERDE RACCOLTA: ", Progress.has_mini_bulb("level05_green"), " pos=", game.player.global_position)
	await get_tree().create_timer(1.0).timeout
	Input.action_press("move_left")
	await get_tree().create_timer(0.2).timeout
	await _jump(0.4)
	await get_tree().create_timer(0.5).timeout
	Input.action_release("move_left")
	await get_tree().create_timer(0.5).timeout
	print("RITORNO SULLA CASSA: pos=", game.player.global_position, " viva=", not game.player.dead)
	await _shot("level5_back")

	game.go_to_menu()
	await get_tree().create_timer(0.8).timeout
	var menu := get_tree().current_scene
	print("MINI NEL MENU: ", menu._minis.size())
	await _shot("menu")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	# Il tocco arriva in coordinate della finestra (scalata rispetto al gioco).
	touch.position = get_viewport().get_final_transform() * menu._minis[1].position
	Input.parse_input_event(touch)
	await get_tree().create_timer(0.1).timeout
	await _shot("menu_mini_flash")
	get_tree().quit()


func _jump(hold: float) -> void:
	Input.action_press("jump")
	await get_tree().create_timer(hold).timeout
	Input.action_release("jump")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("mini_%s.png" % name))
