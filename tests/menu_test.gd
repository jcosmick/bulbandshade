extends Node
## Test del menu (solo sviluppo): screenshot del menu, poi avvia il livello 2
## dalla griglia e controlla che la partita parta da lì.
## Uso: Godot --path . res://tests/menu_test.tscn -- --out=<cartella>

var out_dir := "user://autotest"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	Progress.persist = false
	# Finto progresso (solo in memoria, il salvataggio vero non viene toccato):
	# livello 1 completato, così il 2 è sbloccato e il 3 bloccato.
	Progress._best_flashes.clear()
	Progress.complete_level(0, 3)
	if "--all" in OS.get_cmdline_user_args():
		Progress.complete_level(1, 2)
	_run.call_deferred()


func _run() -> void:
	# Il menu diventa la scena corrente: quando cambia scena viene sostituito
	# lui, mentre questo nodo di test resta vivo.
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().create_timer(0.8).timeout
	await _shot("menu")
	var cards := menu.find_children("*", "Button", true, false)
	print("PULSANTI: ", cards.map(func(b: Button) -> String: return b.text.replace("\n", " | ")))
	# Pulsanti: [Gioca, livello 1, livello 2, livello 3]
	cards[2].pressed.emit()
	await get_tree().create_timer(0.8).timeout
	var game := get_tree().current_scene
	print("LIVELLO AVVIATO: ", game.level.level_name)
	await _shot("game")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("menu_%s.png" % name))
