extends Node
## Test automatico (solo sviluppo): carica un livello, esegue una soluzione
## scritta a mano simulando gli input e salva screenshot.
## Uso: Godot --path . res://tests/autotest.tscn -- --level=2 --out=<cartella>

## Passi: ["tp", pos] teletrasporto, ["flash"], ["hold", azione] / ["free", azione]
## premi/rilascia, ["jump", secondi] salto tenuto, ["wait", secondi], ["shot", nome],
## ["check", pos] verifica che il giocatore sia vicino a pos (fine di una fase),
## ["walk_to", x] cammina fino alla coordinata x (massimo 2 s),
## ["window_closes", nome] aspetta che la persiana della finestra si chiuda,
## ["drop_lands", nome] aspetta che una goccia del tubo tocchi terra.
const SOLUTIONS := {
	1: [
		["tp", Vector2(200, 1368)], ["wait", 0.3], ["flash"], ["wait", 0.1], ["shot", "flash1"],
		["hold", "move_right"], ["jump", 0.4], ["wait", 0.3], ["jump", 0.2], ["wait", 0.6],
		["free", "move_right"], ["wait", 0.5], ["check", Vector2(770, 948)], ["wait", 1.5],
		["tp", Vector2(985, 948)], ["wait", 0.4], ["flash"], ["wait", 0.1], ["shot", "flash2"],
		["hold", "move_left"], ["jump", 0.4], ["wait", 0.4], ["jump", 0.3], ["wait", 1.2],
	],
	2: [
		["tp", Vector2(230, 1368)], ["wait", 0.3], ["flash"], ["wait", 0.1], ["shot", "flash1"],
		["hold", "move_right"], ["jump", 0.15], ["wait", 0.3], ["free", "move_right"], ["wait", 0.3],
		["check", Vector2(420, 1208)],
		["hold", "move_right"], ["wait", 0.15], ["jump", 0.4], ["wait", 0.8],
		["jump", 0.4], ["wait", 0.6], ["free", "move_right"], ["wait", 0.3],
		["check", Vector2(950, 828)], ["shot", "ledge"], ["wait", 1.0],
		["tp", Vector2(960, 828)], ["wait", 0.3], ["flash"], ["wait", 0.1], ["shot", "flash2"],
		["hold", "move_left"], ["jump", 0.4], ["wait", 0.6], ["jump", 0.4], ["wait", 1.2],
	],
	3: [
		["walk_to", 310.0], ["wait", 0.2], ["shot", "short_circuit"], ["wait", 1.2],
		["check", Vector2(150, 2648)],
		["tp", Vector2(480, 2648)], ["wait", 0.3], ["flash"], ["wait", 0.1], ["shot", "A_flash"],
		["hold", "move_right"], ["jump", 0.4], ["wait", 0.5], ["jump", 0.4], ["wait", 0.6],
		["free", "move_right"], ["wait", 0.3], ["check", Vector2(900, 2228)], ["wait", 2.0],
		["tp", Vector2(985, 2228)], ["window_closes", "WindowB"], ["flash"], ["wait", 0.1], ["shot", "B_flash"],
		["hold", "move_left"], ["jump", 0.4], ["wait", 0.3], ["walk_to", 450.0],
		["hold", "move_left"], ["jump", 0.4], ["wait", 0.3], ["walk_to", 150.0], ["wait", 0.3],
		["check", Vector2(150, 1848)], ["shot", "B_end"],
		["window_opens", "WindowB"], ["wait", 0.05], ["beam_overlap", "WindowB"], ["shot", "B_cut"], ["wait", 1.0],
		["tp", Vector2(200, 1848)], ["window_closes", "WindowB"], ["flash"], ["wait", 0.1], ["shot", "C_flash"],
		["walk_to", 330.0], ["hold", "move_right"], ["jump", 0.4], ["wait", 0.6],
		["walk_to", 850.0], ["wait", 0.3], ["check", Vector2(705, 1468)], ["wait", 2.0],
		["tp", Vector2(990, 1468)], ["wait", 0.3], ["drop_lands", "FaucetD"], ["flash"], ["wait", 0.1],
		["shot", "D_flash"],
		["hold", "move_left"], ["jump", 0.4], ["wait", 0.2], ["walk_to", 530.0],
		["jump", 0.4], ["hold", "move_left"], ["wait", 0.4], ["walk_to", 420.0], ["wait", 0.3],
		["check", Vector2(420, 1068)], ["wait", 2.0],
		["hold", "move_left"], ["jump", 0.4], ["wait", 0.4], ["walk_to", 245.0], ["wait", 0.3],
		["walk_to", 190.0], ["wait", 0.3], ["shot", "E_pushed"], ["flash"], ["wait", 0.1], ["shot", "E_flash"],
		["hold", "move_right"], ["jump", 0.4], ["wait", 0.4], ["jump", 0.4], ["wait", 1.2],
	],
	7: [
		["walk_to", 770.0], ["wait", 0.2], ["flash"], ["wait", 0.1], ["shot", "A_flash"],
		["hold", "move_right"], ["jump", 0.4], ["wait", 0.2], ["jump", 0.4], ["walk_to", 1800.0], ["wait", 0.3],
		["check", Vector2(1800, 2368)], ["shot", "A_end"], ["wait", 2.0],
		["flash"], ["wait", 0.1], ["shot", "B_flash"],
		["hold", "move_right"], ["jump", 0.4], ["wait", 0.2], ["jump", 0.4], ["walk_to", 2500.0], ["wait", 0.3],
		["check", Vector2(2500, 1998)], ["shot", "B_end"],
		["walk_to", 2620.0], ["wait", 3.5], ["shot", "C_crate"],
		["walk_to", 2420.0], ["hold", "move_left"], ["jump", 0.4], ["free", "move_left"], ["wait", 0.5], ["walk_to", 2180.0], ["wait", 0.3],
		["check", Vector2(2180, 1778)], ["wait", 1.0], ["flash"], ["wait", 0.1], ["shot", "C_flash"],
		["hold", "move_left"], ["jump", 0.3], ["wait", 0.3], ["jump", 0.3], ["wait", 0.3], ["jump", 0.4],
		["walk_to", 1350.0], ["wait", 0.5],
	],
	9: [
		# A: ponte d'ombra della cassa sopra la vasca.
		["tp", Vector2(250, 1368)], ["wait", 0.3], ["flash"], ["wait", 0.1], ["shot", "A_flash"],
		["walk_to", 470.0], ["hold", "move_right"], ["jump", 0.3], ["walk_to", 960.0],
		["hold", "move_right"], ["jump", 0.45], ["wait", 0.6], ["free", "move_right"],
		["walk_to", 1520.0], ["wait", 0.3], ["check", Vector2(1520, 1368)], ["shot", "A_end"], ["wait", 2.0],
		# B: vetro, cassa alta e rampa d'ombra fino alla mensola.
		["flash"], ["wait", 0.1], ["shot", "B_flash"],
		["hold", "move_right"], ["jump", 0.3], ["wait", 0.15], ["jump", 0.4], ["walk_to", 1870.0],
		["jump", 0.4], ["hold", "move_right"], ["wait", 0.5], ["jump", 0.4], ["wait", 0.5], ["free", "move_right"],
		["walk_to", 2400.0], ["wait", 0.3], ["check", Vector2(2400, 708)], ["shot", "B_end"], ["wait", 2.0],
		# C: rampa d'ombra della cassa appesa fino all'arrivo.
		["flash"], ["wait", 0.1], ["shot", "C_flash"],
		["hold", "move_right"], ["jump", 0.4], ["wait", 0.2], ["jump", 0.4], ["walk_to", 2940.0],
		["hold", "move_right"], ["jump", 0.4], ["wait", 0.6], ["free", "move_right"], ["walk_to", 3070.0], ["wait", 0.5],
	],
}

var game: Node
var out_dir := "user://autotest"
var level := 1
var _deaths := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--level="):
			level = arg.trim_prefix("--level=").to_int()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Progress.persist = false
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await game.load_level(level - 1)
	game.player.died.connect(func() -> void:
		_deaths += 1
		_log("CORTOCIRCUITO"))
	_run()


func _run() -> void:
	await _wait(0.5)
	await _shot("start")
	for step in SOLUTIONS[level]:
		match step[0]:
			"tp":
				game.player.global_position = step[1]
				game.player.velocity = Vector2.ZERO
			"flash":
				game.player.try_flash()
				_log("flash")
			"hold":
				Input.action_press(step[1])
			"free":
				Input.action_release(step[1])
			"jump":
				Input.action_press("jump")
				await _wait(step[1])
				Input.action_release("jump")
			"wait":
				await _wait(step[1])
			"shot":
				await _shot(step[1])
			"walk_to":
				var target: float = step[1]
				var action := "move_left" if target < game.player.global_position.x else "move_right"
				Input.action_release("move_left")
				Input.action_release("move_right")
				Input.action_press(action)
				var time := 0.0
				while time < 2.0 and absf(game.player.global_position.x - target) > 15.0 and not game.player.dead:
					await get_tree().physics_frame
					time += get_physics_process_delta_time()
				Input.action_release(action)
			"window_closes":
				var window: WindowLight = game.level.get_node(step[1])
				while not window.is_lit():
					await get_tree().physics_frame
				while window.is_lit():
					await get_tree().physics_frame
			"window_opens":
				var window: WindowLight = game.level.get_node(step[1])
				while window.is_lit():
					await get_tree().physics_frame
				while not window.is_lit():
					await get_tree().physics_frame
			"beam_overlap":
				var window: WindowLight = game.level.get_node(step[1])
				var overlap := 0.0
				var count := 0
				for platform in game._shadow_layer.get_children():
					if platform is ShadowPlatform and not platform.is_queued_for_deletion():
						count += 1
						for beam in window.beam_polygons():
							for piece in Geometry2D.intersect_polygons(platform.polygon, beam):
								overlap += ShadowSystem._area(piece)
				print("BEAM %s: ombre=%d sovrapposizione=%.0f px² -> %s" % [step[1], count, overlap, "OK" if overlap < 100.0 else "FALLITO"])
			"drop_lands":
				await game.level.get_node(step[1]).drop_landed
				_log("goccia caduta")
			"check":
				var dist: float = game.player.global_position.distance_to(step[1])
				print("CHECK %s: %s (distanza %.0f)" % [step[1], "OK" if dist < 140.0 else "FALLITO", dist])
	for action in ["move_left", "move_right", "jump"]:
		Input.action_release(action)
	await _wait(2.6)
	await _shot("end")
	print("LEVEL %d WON: %s" % [level, game.won])
	print("CORTOCIRCUITI: %d" % _deaths)
	get_tree().quit()


## Attende registrando la posizione del giocatore ogni 0.1 s.
func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var step := minf(0.1, seconds - elapsed)
		await get_tree().create_timer(step).timeout
		elapsed += step
		_log("")


func _log(tag: String) -> void:
	var p: CharacterBody2D = game.player
	print("%s pos=(%.0f, %.0f) floor=%s" % [tag, p.global_position.x, p.global_position.y, p.is_on_floor()])


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("L%d_%s.png" % [level, name])
	get_viewport().get_texture().get_image().save_png(path)
