extends Node
## Test end-to-end (solo sviluppo) degli Zoom trigger: istanzia game.tscn con
## un livello di test dedicato (tests/levels/), fa attraversare i trigger alla
## lampadina e osserva solo quello che vede il giocatore: visible_world_rect()
## e uno screenshot per caso. Stampa "CASO <nome>: OK/FALLITO (<dettagli>)".
## Il moltiplicatore di zoom osservato è la larghezza della vista a zoom 1.0
## (presa subito dopo il caricamento) divisa per quella attuale.
## Gira in finestra (non --headless: gli screenshot servono un renderer vero).
## Uso: Godot --path . --fixed-fps 60 res://tests/zoom_test.tscn -- --out=<cartella> [--baseline=<cartella>] [--only=<nome>]
## --only esegue solo i casi il cui nome contiene <nome> (es. --only=level_09).
## Con --baseline gli screenshot di level_09 si confrontano pixel per pixel con
## quelli della cartella indicata (fatti prima di una modifica). Anche a parità di codice
## due esecuzioni differiscono di qualche decina di pixel in punti isolati (animazioni
## casuali): si tollera fino a MAX_NOISE_PX pixel per screenshot. Uno spostamento o
## uno zoom diverso della telecamera ne cambia centinaia di migliaia.
## Per aggiungere un caso: scrivere una funzione _case_<nome>() e metterla in CASES.

const ZOOM_LEVEL := "res://tests/levels/zoom_test_level.tscn"
const FIXED_LEVEL := "res://tests/levels/zoom_fixed_level.tscn"
const WIDE_LEVEL := "res://tests/levels/zoom_wide_level.tscn"
const LEVEL_09 := "res://levels/level_09.tscn"
## Finestra 9:16: la viewport visibile è esattamente 1080x1920.
const WINDOW_SIZE := Vector2i(540, 960)
## Altezza dei piedi della lampadina sul pavimento alto del livello di test.
const FLOOR_Y := 1368.0
## Dove ricompare la lampadina: inizio del livello di test e CheckpointZoom.
const START_SPAWN := Vector2(300, 1368)
const CHECKPOINT_SPAWN := Vector2(2000, 1368)
## Tolleranza sul moltiplicatore osservato.
const EPS := 0.005
## Più lungo della durata di default dei trigger (0.8 s).
const SETTLE := 1.1
## Pixel diversi tollerati per screenshot nel confronto con --baseline.
const MAX_NOISE_PX := 500

var game: Node
var out_dir := "user://zoom_test"
var baseline_dir := ""
var only := ""
var _results: Array[String] = []
## Larghezza di visible_world_rect() a moltiplicatore 1.0.
var _base_width := 0.0
## Se non null, ogni frame (dopo la telecamera) ci si aggiunge il moltiplicatore.
var _samples: Variant = null

var CASES: Array[Callable] = [
	_case_exit_after_side,
	_case_exit_before_side,
	_case_same_side,
	_case_second_trigger_mid_tween,
	_case_zero_duration,
	_case_vertical_axis,
	_case_fixed_level_ignores,
	_case_restart_resets,
	_case_cutscene_holds,
	_case_cutscene_last_wins,
	_case_cutscene_restart,
	_case_cutscene_respawn,
	_case_checkpoint_respawn,
	_case_respawn_without_checkpoint,
	_case_checkpoint_mid_tween,
	_case_restart_after_checkpoint,
	_case_level_09_unchanged,
	_case_beyond_level_centered,
]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--baseline="):
			baseline_dir = arg.trim_prefix("--baseline=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Dopo la telecamera del Game e i props in parallasse.
	process_priority = 1000
	get_window().size = WINDOW_SIZE
	await get_tree().process_frame
	await get_tree().process_frame
	Progress.persist = false
	# Primo caricamento (game._ready): ogni caso poi carica il suo livello.
	Progress.test_level = LEVEL_09
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	_run()


func _run() -> void:
	for case in CASES:
		if only.is_empty() or only in case.get_method():
			await case.call()
	print("--- RIEPILOGO ---")
	var failed := 0
	for line in _results:
		print(line)
		if "FALLITO" in line:
			failed += 1
	print("CASI FALLITI: %d su %d" % [failed, _results.size()])
	get_tree().quit()


func _process(_delta: float) -> void:
	if _samples != null and game and game.level:
		_samples.append(_multiplier())


# --- Casi ---------------------------------------------------------------------

func _case_exit_after_side() -> void:
	await _fresh()
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _wait(SETTLE)
	var m := _multiplier()
	_report("exit_after_side", _near(m, 1.25), "zoom_after 1.25, osservato %.3f" % m)
	await _shot("exit_after_side")


func _case_exit_before_side() -> void:
	await _fresh()
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _wait(SETTLE)
	var after := _multiplier()
	await _cross(Vector2(1550, FLOOR_Y), Vector2(1300, FLOOR_Y))
	await _wait(SETTLE)
	var m := _multiplier()
	_report("exit_before_side", _near(after, 1.25) and _near(m, 1.0),
			"dopo %.3f, tornando indietro %.3f (zoom_before 1.0)" % [after, m])
	await _shot("exit_before_side")


func _case_same_side() -> void:
	await _fresh()
	# Entra da sinistra ed esce a sinistra: resta 1.0.
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1300, FLOOR_Y))
	await _wait(SETTLE)
	var left := _multiplier()
	# Passato il trigger, entra da destra ed esce a destra: resta 1.25.
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _wait(SETTLE)
	await _cross(Vector2(1550, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _wait(SETTLE)
	var right := _multiplier()
	_report("same_side", _near(left, 1.0) and _near(right, 1.25),
			"dentro e fuori a sinistra %.3f, a destra %.3f" % [left, right])
	await _shot("same_side")


func _case_second_trigger_mid_tween() -> void:
	await _fresh()
	_samples = []
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _wait(0.3)
	var mid := _multiplier()
	await _cross(Vector2(2450, FLOOR_Y), Vector2(2700, FLOOR_Y))
	await _wait(SETTLE)
	var samples: Array = _samples
	_samples = null
	var monotonic := true
	var max_step := 0.0
	for i in range(1, samples.size()):
		var step: float = samples[i] - samples[i - 1]
		if step < -0.0001:
			monotonic = false
		max_step = maxf(max_step, absf(step))
	var m := _multiplier()
	var ok := mid > 1.01 and mid < 1.24 and monotonic and max_step < 0.05 and _near(m, 1.6)
	_report("second_trigger_mid_tween", ok,
			"a metà %.3f, %d campioni, monotono=%s, passo massimo %.4f, finale %.3f (atteso 1.6)" % [
			mid, samples.size(), monotonic, max_step, m])
	await _shot("second_trigger_mid_tween")


func _case_zero_duration() -> void:
	await _fresh()
	await _tp(Vector2(3450, FLOOR_Y))
	await _frames(3)
	await _tp(Vector2(3700, FLOOR_Y))
	await _frames(2)
	await get_tree().process_frame
	var m := _multiplier()
	_report("zero_duration", _near(m, 1.4), "durata 0, subito dopo l'uscita %.3f (atteso 1.4)" % m)
	await _shot("zero_duration")


func _case_vertical_axis() -> void:
	await _fresh()
	# Dentro il trigger (y 1700-1900), poi sotto: lato "dopo".
	await _cross(Vector2(5000, 1800), Vector2(5000, 2100))
	await _wait(SETTLE)
	var below := _multiplier()
	# Di nuovo dentro, poi sopra, sulla mensola: lato "prima".
	await _cross(Vector2(5000, 1800), Vector2(5000, 1588))
	await _wait(SETTLE)
	var above := _multiplier()
	_report("vertical_axis", _near(below, 1.3) and _near(above, 1.0),
			"uscita sotto %.3f (atteso 1.3), uscita sopra %.3f (atteso 1.0)" % [below, above])
	await _shot("vertical_axis")


func _case_fixed_level_ignores() -> void:
	await _fresh(FIXED_LEVEL)
	var follow: bool = game._follow
	await _cross(Vector2(520, FLOOR_Y), Vector2(800, FLOOR_Y))
	await _wait(SETTLE)
	var m := _multiplier()
	_report("fixed_level_ignores", not follow and _near(m, 1.0),
			"telecamera che segue=%s, dopo il trigger %.3f (atteso 1.0)" % [follow, m])
	await _shot("fixed_level_ignores")


func _case_restart_resets() -> void:
	await _fresh()
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _wait(SETTLE)
	var before := _multiplier()
	await _press("restart")
	await _until(func() -> bool: return not get_tree().paused, 10.0)
	await _frames(3)
	var m := _multiplier()
	_report("restart_resets", _near(before, 1.25) and _near(m, 1.0),
			"prima del restart %.3f, dopo %.3f (atteso 1.0)" % [before, m])
	await _shot("restart_resets")


## Durante una cutscene (camera_focus impostato, come fa Cutscene) un trigger
## attraversato non cambia lo zoom; al rilascio parte il tween verso il suo target.
func _case_cutscene_holds() -> void:
	await _fresh()
	_start_cutscene()
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _wait(SETTLE)
	var during := _multiplier()
	game.camera_focus = null
	await _wait(0.3)
	var mid := _multiplier()
	await _wait(SETTLE)
	var m := _multiplier()
	_report("cutscene_holds", _near(during, 1.0) and mid > 1.01 and mid < 1.24 and _near(m, 1.25),
			"durante la cutscene %.3f (atteso 1.0), 0.3 s dopo %.3f, finale %.3f (atteso 1.25)" % [
			during, mid, m])
	await _shot("cutscene_holds")


## Più trigger attraversati durante la cutscene: al rilascio vale l'ultimo.
func _case_cutscene_last_wins() -> void:
	await _fresh()
	_start_cutscene()
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _cross(Vector2(2450, FLOOR_Y), Vector2(2700, FLOOR_Y))
	await _wait(SETTLE)
	var during := _multiplier()
	game.camera_focus = null
	await _wait(SETTLE)
	var m := _multiplier()
	_report("cutscene_last_wins", _near(during, 1.0) and _near(m, 1.6),
			"durante la cutscene %.3f (atteso 1.0), dopo il rilascio %.3f (atteso 1.6, l'ultimo)" % [
			during, m])
	await _shot("cutscene_last_wins")


## Restart durante una cutscene con una richiesta in attesa: si riparte da 1.0
## e la richiesta non si applica dopo.
func _case_cutscene_restart() -> void:
	await _fresh()
	_start_cutscene()
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _press("restart")
	await _until(func() -> bool: return not get_tree().paused, 10.0)
	await _frames(3)
	var right_after := _multiplier()
	await _wait(SETTLE)
	var m := _multiplier()
	_report("cutscene_restart", _near(right_after, 1.0) and _near(m, 1.0),
			"subito dopo il restart %.3f, %.1f s dopo %.3f (atteso 1.0)" % [right_after, SETTLE, m])
	await _shot("cutscene_restart")


## Il respawn scarta la richiesta in attesa: al rilascio della cutscene lo zoom
## non cambia.
func _case_cutscene_respawn() -> void:
	await _fresh()
	_start_cutscene()
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	game.player.die()
	await _wait(game.RESPAWN_DELAY + 0.3)
	game.camera_focus = null
	await _wait(SETTLE)
	var m := _multiplier()
	_report("cutscene_respawn", _near(m, 1.0),
			"dopo il respawn e il rilascio %.3f (atteso 1.0, nessun checkpoint)" % m)
	await _shot("cutscene_respawn")


## Zoom 1.25 (ZoomA), checkpoint, zoom 1.6 (ZoomB), morte: al respawn la vista
## è a 1.25 dal primo frame disegnato.
func _case_checkpoint_respawn() -> void:
	await _fresh()
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _wait(SETTLE)
	await _reach_checkpoint()
	await _cross(Vector2(2450, FLOOR_Y), Vector2(2700, FLOOR_Y))
	await _wait(SETTLE)
	var before := _multiplier()
	var first := await _die_and_respawn(CHECKPOINT_SPAWN)
	var m := _multiplier()
	_report("checkpoint_respawn", _near(before, 1.6) and _near(first, 1.25) and _near(m, 1.25),
			"prima della morte %.3f, primo frame dopo il respawn %.3f, poi %.3f (atteso 1.25)" % [before, first, m])
	await _shot("checkpoint_respawn")


## Zoom senza checkpoint, poi morte: si rinasce a 1.0.
func _case_respawn_without_checkpoint() -> void:
	await _fresh()
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _wait(SETTLE)
	var before := _multiplier()
	var first := await _die_and_respawn(START_SPAWN)
	_report("respawn_without_checkpoint", _near(before, 1.25) and _near(first, 1.0),
			"prima della morte %.3f, primo frame dopo il respawn %.3f (atteso 1.0)" % [before, first])
	await _shot("respawn_without_checkpoint")


## Checkpoint toccato a metà della transizione verso 1.25: si salva il target.
func _case_checkpoint_mid_tween() -> void:
	await _fresh()
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _wait(0.2)
	await _reach_checkpoint()
	var mid := _multiplier()
	await _cross(Vector2(2450, FLOOR_Y), Vector2(2700, FLOOR_Y))
	await _wait(SETTLE)
	var first := await _die_and_respawn(CHECKPOINT_SPAWN)
	_report("checkpoint_mid_tween", mid > 1.01 and mid < 1.24 and _near(first, 1.25),
			"al checkpoint %.3f (a metà), primo frame dopo il respawn %.3f (atteso 1.25)" % [mid, first])
	await _shot("checkpoint_mid_tween")


## Checkpoint a 1.25, restart: si riparte da 1.0, anche morendo subito dopo.
func _case_restart_after_checkpoint() -> void:
	await _fresh()
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	await _wait(SETTLE)
	await _reach_checkpoint()
	await _press("restart")
	await _until(func() -> bool: return not get_tree().paused, 10.0)
	await _frames(3)
	var after_restart := _multiplier()
	var first := await _die_and_respawn(START_SPAWN)
	_report("restart_after_checkpoint", _near(after_restart, 1.0) and _near(first, 1.0),
			"dopo il restart %.3f, primo frame dopo il respawn %.3f (atteso 1.0)" % [after_restart, first])
	await _shot("restart_after_checkpoint")


## Regressione: senza trigger level_09 si vede come prima. Gli screenshot si
## confrontano con quelli di --baseline, se c'è.
func _case_level_09_unchanged() -> void:
	await _fresh(LEVEL_09)
	var details: Array[String] = []
	var identical := true
	for x in [200, 2000, 4100, 6200, 8000]:
		await _tp(Vector2(x, 1368))
		await _frames(30)
		var shot_name := "level_09_x%d" % x
		await _shot(shot_name)
		if baseline_dir:
			var diff := _diff_pixels(shot_name)
			details.append("x%d: %d px diversi" % [x, diff])
			if diff < 0 or diff > MAX_NOISE_PX:
				identical = false
	if baseline_dir:
		_report("level_09_unchanged", identical, ", ".join(details))
	else:
		_report("level_09_unchanged", true, "solo screenshot, senza --baseline nessun confronto")


## Zoom-out 0.7 in un livello alto 1800: la vista sopra i controlli (circa
## 2171 di altezza) supera level_rect in verticale e deve stare centrata, con
## bande nere uguali sopra e sotto. In orizzontale (3000 di larghezza) no.
func _case_beyond_level_centered() -> void:
	await _fresh(WIDE_LEVEL)
	await _cross(Vector2(1450, FLOOR_Y), Vector2(1700, FLOOR_Y))
	# Oltre al tween, si lascia arrivare l'inseguimento morbido della telecamera.
	await _wait(SETTLE + 1.0)
	var m := _multiplier()
	var view: Rect2 = game.visible_world_rect()
	var rect: Rect2 = game.level.level_rect
	# Fascia dei controlli in unità del mondo (la viewport è larga 1080).
	var controls: float = game.CONTROLS_HEIGHT * view.size.x / get_viewport().get_visible_rect().size.x
	var top := rect.position.y - view.position.y
	var bottom := (view.end.y - controls) - rect.end.y
	var inside_x := view.position.x >= rect.position.x - 0.5 and view.end.x <= rect.end.x + 0.5
	var ok := _near(m, 0.7) and top > 1.0 and absf(top - bottom) < 1.0 and inside_x
	_report("beyond_level_centered", ok,
			"zoom %.3f (atteso 0.7), banda sopra %.1f, banda sotto %.1f, x %.0f-%.0f dentro il livello=%s" % [
			m, top, bottom, view.position.x, view.end.x, inside_x])
	await _shot("beyond_level_centered")


# --- Utilità ------------------------------------------------------------------

## Inizia una "cutscene": la telecamera segue un nodo fermo dove sta la lampadina.
func _start_cutscene() -> void:
	var focus := Node2D.new()
	game.level.add_child(focus)
	focus.global_position = game.player.global_position
	game.camera_focus = focus


## Porta la lampadina sul checkpoint del livello di test (tra ZoomA e ZoomB).
func _reach_checkpoint() -> void:
	await _tp(CHECKPOINT_SPAWN)
	await _frames(3)


## Fa morire la lampadina e aspetta che ricompaia in `spawn`. Restituisce il
## moltiplicatore del primo frame disegnato con la lampadina già lì.
func _die_and_respawn(spawn: Vector2) -> float:
	var first := [-1.0]
	var sample := func() -> void:
		if first[0] < 0.0 and game.player.global_position.distance_to(spawn) < 1.0:
			first[0] = _multiplier()
	RenderingServer.frame_pre_draw.connect(sample)
	game.player.die()
	await _until(func() -> bool: return first[0] >= 0.0, 3.0)
	RenderingServer.frame_pre_draw.disconnect(sample)
	await _frames(3)
	return first[0]


## Ricarica da zero il livello indicato e misura la vista a moltiplicatore 1.0.
func _fresh(path := ZOOM_LEVEL) -> void:
	for action in ["move_left", "move_right", "jump", "flash", "restart", "menu"]:
		Input.action_release(action)
	Progress.test_level = path
	await game.load_level(0)
	await _frames(3)
	_base_width = game.visible_world_rect().size.x


## Moltiplicatore di zoom visto dal giocatore.
func _multiplier() -> float:
	return _base_width / game.visible_world_rect().size.x


static func _near(value: float, expected: float) -> bool:
	return absf(value - expected) < EPS


## Fa entrare la lampadina nel trigger in `inside` e la fa uscire in `outside`.
func _cross(inside: Vector2, outside: Vector2) -> void:
	await _tp(inside)
	await _frames(3)
	await _tp(outside)
	await _frames(3)


func _tp(pos: Vector2) -> void:
	game.player.global_position = pos
	game.player.velocity = Vector2.ZERO
	game.player.snap_interpolation()
	if game._follow:
		game._focus_y = pos.y
		game._camera.position = game._camera_target()


## Preme e rilascia un'azione (vedi rules_test.gd: la pressione deve arrivare
## prima dei _process dei nodi).
func _press(action: String) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(condition: Callable, timeout: float) -> void:
	var time := 0.0
	while not condition.call() and time < timeout:
		await get_tree().process_frame
		time += get_process_delta_time()


func _report(case_name: String, ok: bool, details: String) -> void:
	var line := "CASO %s: %s (%s)" % [case_name, "OK" if ok else "FALLITO", details]
	print(line)
	_results.append(line)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("Z_%s.png" % shot_name))


## Pixel diversi tra lo screenshot appena fatto e quello di --baseline
## (-1 se manca o ha un'altra dimensione).
func _diff_pixels(shot_name: String) -> int:
	var file := "Z_%s.png" % shot_name
	var a := Image.load_from_file(out_dir.path_join(file))
	var b := Image.load_from_file(baseline_dir.path_join(file))
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	if a.get_data() == b.get_data():
		return 0
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count
