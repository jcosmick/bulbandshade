extends Node
## Test (solo sviluppo) del "wooom" dei prop in primo piano (parallax_props.gd):
## prop muti, "always" e "once". Carica il livello 9 con alcuni prop di prova
## aggiunti al suo ParallaxFront e messi nelle due liste, poi fa scorrere la
## telecamera avanti, indietro e di nuovo avanti dopo una morte. Ascolta solo
## il lettore del wooom del layer: conta le partenze e le attribuisce al prop
## più vicino al suono (che segue il prop). Stampa "REGOLA <nome>: OK/FALLITO
## (<dettagli>)".
## Uso: Godot --path . res://tests/pass_sound_test.tscn

const LEVEL_INDEX := 8
const LEVEL_PATH := "res://levels/level_09.tscn"
## Copia del livello 9 con i prop di prova e le liste già impostate: le liste
## devono esserci prima del _ready del layer, che decide se creare il lettore.
const TEST_LEVEL := "user://pass_sound_test_level.tscn"
## Altezza dei prop di prova (il livello è alto 1520, la telecamera non sale né scende).
const PROP_Y := 760.0
## Da dove a dove va il punto seguito dalla telecamera, e a che velocità
## (camminando sono ~520 px/s).
const SWEEP_FROM := 600.0
const SWEEP_TO := 7400.0
const FOCUS_SPEED := 700.0
## Prop di prova: nome, x, scostamento verticale, liste. L'ordine conta: a
## parità di x il primo viene controllato per primo, quindi un prop muto
## davanti a uno "always" gli ruberebbe il suono se lo bloccasse.
const PROPS := [
	["Silent", 1200.0, 0.0, []],
	["AlwaysWithSilent", 1200.0, 150.0, ["always"]],
	["Once", 2600.0, 0.0, ["once"]],
	["Both", 4000.0, 0.0, ["always", "once"]],
	["UsedOnce", 5400.0, 0.0, ["once"]],
	["AlwaysWithUsedOnce", 5400.0, 150.0, ["always"]],
	["Always", 6800.0, 0.0, ["always"]],
]

var game: Node
var _results: Array[String] = []


func _ready() -> void:
	Progress.persist = false
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	_run()


func _run() -> void:
	await _test_empty_lists()
	await _test_modes()
	print("--- RIEPILOGO ---")
	var failed := 0
	for line in _results:
		print(line)
		if "FALLITO" in line:
			failed += 1
	print("REGOLE FALLITE: %d su %d" % [failed, _results.size()])
	get_tree().quit()


# --- Regole -----------------------------------------------------------------

## Livello 9 così com'è (liste vuote): il layer non crea nessun lettore.
func _test_empty_lists() -> void:
	Progress.test_level = ""
	await game.load_level(LEVEL_INDEX)
	await _frames(3)
	var layer = game.level.get_node("ParallaxFront")
	var players: Array = layer.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer2D)
	_report("empty_lists_no_player", players.is_empty(), "lettori del wooom sul layer: %d" % players.size())


## Tre passaggi (avanti, indietro, avanti dopo una morte) sui prop di prova.
func _test_modes() -> void:
	_build_test_level()
	Progress.test_level = TEST_LEVEL
	await game.load_level(LEVEL_INDEX)
	Progress.test_level = ""
	await _frames(3)
	var layer = game.level.get_node("ParallaxFront")
	var sound: AudioStreamPlayer2D = null
	for child in layer.get_children():
		if child is AudioStreamPlayer2D:
			sound = child
	var props := {}
	for spec in PROPS:
		props[spec[0]] = layer.find_child(spec[0], true, false)
	if sound == null or props.values().has(null):
		_report("modes_setup", false, "lettore=%s, prop trovati=%s, liste always=%d once=%d" % [
				sound, props, layer.pass_sound_always.size(), layer.pass_sound_once.size()])
		return
	var focus := Node2D.new()
	game.level.add_child(focus)
	focus.global_position = Vector2(SWEEP_FROM, PROP_Y)
	game.camera_focus = focus
	game._camera.position = game._camera_target()
	await _wait(0.5)
	var passes: Array[Dictionary] = []
	passes.append(await _sweep(focus, SWEEP_TO, sound, props))
	passes.append(await _sweep(focus, SWEEP_FROM, sound, props))
	game.player.die()
	var died: bool = game.player.dead
	await _until(func() -> bool: return not game.player.dead and game.player.controls_enabled, 5.0)
	await _wait(0.5)
	passes.append(await _sweep(focus, SWEEP_TO, sound, props))
	var counts := func(prop_name: String) -> Array:
		return passes.map(func(p: Dictionary) -> int: return p.get(prop_name, 0))
	_report("silent_never_plays", counts.call("Silent") == [0, 0, 0],
			"Silent per passaggio: %s" % [counts.call("Silent")])
	_report("always_every_pass", counts.call("Always") == [1, 1, 1],
			"Always per passaggio: %s" % [counts.call("Always")])
	_report("once_only_first", died and counts.call("Once") == [1, 0, 0],
			"Once per passaggio (avanti, indietro, avanti dopo la morte): %s, morte avvenuta=%s" % [counts.call("Once"), died])
	_report("both_lists_is_once", counts.call("Both") == [1, 0, 0],
			"Both per passaggio: %s" % [counts.call("Both")])
	_report("silent_doesnt_block", counts.call("AlwaysWithSilent") == [1, 1, 1],
			"AlwaysWithSilent per passaggio: %s (Silent: %s)" % [counts.call("AlwaysWithSilent"), counts.call("Silent")])
	# Al primo passaggio UsedOnce suona e il cooldown ferma l'altro, poi è come muto.
	_report("used_once_doesnt_block", counts.call("UsedOnce") == [1, 0, 0] and counts.call("AlwaysWithUsedOnce") == [0, 1, 1],
			"UsedOnce: %s, AlwaysWithUsedOnce: %s" % [counts.call("UsedOnce"), counts.call("AlwaysWithUsedOnce")])
	print("INFO partenze per passaggio: %s" % [passes])


# --- Utilità ------------------------------------------------------------------

## Salva in TEST_LEVEL il livello 9 con i prop di prova nel ParallaxFront.
func _build_test_level() -> void:
	var level: Node = load(LEVEL_PATH).instantiate()
	var layer = level.get_node("ParallaxFront")
	var always: Array[Node2D] = []
	var once: Array[Node2D] = []
	for spec in PROPS:
		var prop := Node2D.new()
		prop.name = spec[0]
		prop.position = Vector2(spec[1], PROP_Y + spec[2]) - layer.position
		layer.add_child(prop)
		prop.owner = level
		if "always" in spec[3]:
			always.append(prop)
		if "once" in spec[3]:
			once.append(prop)
	layer.pass_sound_always = always
	layer.pass_sound_once = once
	var scene := PackedScene.new()
	scene.pack(level)
	ResourceSaver.save(scene, TEST_LEVEL)
	level.free()


## Porta il punto seguito dalla telecamera fino a x = `to`, poi aspetta che la
## telecamera si fermi. Restituisce quante volte è partito il wooom per prop.
func _sweep(focus: Node2D, to: float, sound: AudioStreamPlayer2D, props: Dictionary) -> Dictionary:
	var starts := {}
	var was_playing := sound.playing
	var last := Vector2(sound.pitch_scale, sound.volume_db)
	var since_start := INF
	var settle := 1.5
	while settle > 0.0:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		if focus.global_position.x == to:
			settle -= delta
		focus.global_position.x = move_toward(focus.global_position.x, to, FOCUS_SPEED * delta)
		# Ogni play() cambia intonazione e volume: così si vede anche un wooom
		# che ne interrompe uno ancora in corso (playing resta true).
		var now := Vector2(sound.pitch_scale, sound.volume_db)
		var started := now != last or (sound.playing and not was_playing and since_start > 0.1)
		since_start += delta
		if started:
			since_start = 0.0
			var nearest := _nearest(props, sound.global_position)
			starts[nearest] = starts.get(nearest, 0) + 1
		last = now
		was_playing = sound.playing
	return starts


static func _nearest(props: Dictionary, pos: Vector2) -> String:
	var best := ""
	var best_distance := INF
	for prop_name in props:
		var distance: float = props[prop_name].global_position.distance_to(pos)
		if distance < best_distance:
			best_distance = distance
			best = prop_name
	return best


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Aspetta (al massimo "timeout" secondi) che la condizione diventi vera.
func _until(condition: Callable, timeout: float) -> void:
	var time := 0.0
	while not condition.call() and time < timeout:
		await get_tree().physics_frame
		time += get_physics_process_delta_time()


func _report(rule: String, ok: bool, details: String) -> void:
	var line := "REGOLA %s: %s (%s)" % [rule, "OK" if ok else "FALLITO", details]
	print(line)
	_results.append(line)
