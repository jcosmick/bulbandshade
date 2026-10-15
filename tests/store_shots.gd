extends Node
## Screenshot per la pagina dello store (solo sviluppo).
## Uso: Godot --path . res://tests/store_shots.tscn -- --out=<cartella> [--size=1080x1920]
## Si renderizza in un SubViewport, cosi' la dimensione non dipende dal monitor.

var out_dir := "user://store_shots"
var shot_size := Vector2i(1080, 1920)
var vp: SubViewport


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var wh := arg.trim_prefix("--size=").split("x")
			shot_size = Vector2i(int(wh[0]), int(wh[1]))
	vp = SubViewport.new()
	vp.size = shot_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	DirAccess.make_dir_recursive_absolute(out_dir)
	Progress.persist = false
	Progress._best_flashes.clear()
	Progress._mini_bulbs.clear()
	for i in 5:
		Progress.complete_level(i, 3)
	Progress.collect_mini_bulb("red", Color(1, 0.33, 0.36))
	Progress.collect_mini_bulb("green", Color(0.3, 0.9, 0.4))
	_run.call_deferred()


func _run() -> void:
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	vp.add_child(menu)
	await _wait(1.0)
	await _shot("00_menu")
	menu.queue_free()
	var game: Node = load("res://scenes/game.tscn").instantiate()
	vp.add_child(game)
	for i in Progress.LEVELS.size():
		await game.load_level(i)
		await _wait(0.8)
		await _shot("L%d_a_dark" % (i + 1))
		game.player.try_flash(true)
		await _wait(0.12)
		await _shot("L%d_b_flash" % (i + 1))
		await _wait(0.6)
		await _shot("L%d_c_shadows" % (i + 1))
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
