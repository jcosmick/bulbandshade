extends Node
## Temporaneo: screenshot dello sfondo del livello 8 da varie posizioni.

func _ready() -> void:
	for path in Progress.LEVELS:
		Cutscene._seen[path] = true
	Progress.persist = false
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.load_level(7)
	await get_tree().process_frame
	for child in game.level.get_children():
		if child.name != "Background" and child is CanvasItem:
			child.visible = false
	game.player.set_physics_process(false)
	game.player.set_process(false)
	var focus := Node2D.new()
	game.level.add_child(focus)
	game.camera_focus = focus
	var out := OS.get_environment("SHOT_DIR")
	for x in [300, 1100, 1900, 2700, 3500, 3900]:
		focus.global_position = Vector2(x, 900)
		for i in 60:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("bg_%d.png" % x))
	get_tree().quit()
