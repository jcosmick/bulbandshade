extends Node
## Benchmark delle prestazioni (solo sviluppo): carica i livelli uno dopo
## l'altro, sposta la lampadina lungo tutto il livello (a zig-zag, righe distanti
## al massimo 700 px) facendo un flash a ogni ricarica, e misura i tempi di frame.
## Con --profile, per ogni livello ripete lo stesso percorso disattivando un
## sistema alla volta (nodi con lo stesso script, luci, particelle, ombre, flash,
## HUD) e riporta quanto si risparmia rispetto al livello completo.
## Con --shake-plants ogni livello si misura una seconda volta tenendo in
## movimento piante e rampicanti inquadrati (come quando li si attraversa).
## Con --play il livello si gioca a mano per `seconds` secondi (comandi
## normali): ogni frame oltre PLAY_SLOW_MS finisce nel log (righe "PERF SLOW")
## con posizione, velocità, tempo dall'ultimo flash e numero di ombre.
## Con --variants=a,b,... ogni livello si misura una volta per variante:
## "base", "no_autolight" (luci sempre accese come prima di AutoLight),
## "no_player_events" (niente sfarfallio né affievolimento della lampadina),
## "no_player_process" (_process del player fermo).
## Con --trace-draw ogni _draw più lento di DRAW_SLOW_MS finisce nel log
## (righe "PERF DRAW") con il nodo che l'ha fatto.
## I frame oltre SPIKE_MS finiscono nel log (righe "PERF SPIKE") con il momento
## e la posizione della lampadina.
## Uso su PC: Godot --path . res://tests/perf_test.tscn -- --levels=1,8 --seconds=20 [--profile]
## Su Android è la scena principale del preset "Android Perf" (feature perf_test):
## gli argomenti si leggono da user://perf/args.txt, i risultati vanno nel log
## (righe "PERF") e in user://perf/results.json.

## Secondi iniziali di ogni misura esclusi (caricamento, shader).
const WARMUP := 1.5
## Budget di un frame a 60 fps, in millisecondi.
const BUDGET_MS := 1000.0 / 60.0
## Frame più lunghi di così vengono registrati uno per uno.
const SPIKE_MS := 100.0
## Gioco libero: frame più lunghi di così vengono registrati (30 fps).
const PLAY_SLOW_MS := 33.0
## --trace-draw: disegni più lenti di così vengono registrati.
const DRAW_SLOW_MS := 15.0
## Script delle piante che --shake-plants tiene in movimento.
const PLANT_SCRIPTS := ["ground_plant.gd", "hanging_vine.gd"]
## Classi native raggruppate nella profilazione (anche senza script).
const NATIVE_GROUPS := ["Light2D", "LightOccluder2D", "GPUParticles2D", "CPUParticles2D", "CanvasModulate"]
## Script che non si possono disattivare: servono al test stesso.
const SKIP_SCRIPTS := ["level.gd", "player.gd", "game.gd", "shadow_system.gd"]

var game: Node
var levels: Array[int] = []
var seconds := 20.0
var profile := false
var shake_plants := false
var play := false
var variants: Array[String] = []
var trace_draw := false
var _variant := ""
var _draw_last_us := 0
var _draw_last_frame := -1
var _draw_last_node: Node
var _draw_slow := []
var _last_flash_ms := -1
var out_dir := "user://perf"
var _results: Array[Dictionary] = []
var _label: Label
var _flashes := true


func _ready() -> void:
	for i in Progress.LEVELS.size():
		levels.append(i + 1)
	var args := Array(OS.get_cmdline_user_args())
	if FileAccess.file_exists(out_dir.path_join("args.txt")):
		args.append_array(FileAccess.get_file_as_string(out_dir.path_join("args.txt")).split(" ", false))
	for raw: String in args:
		var arg := raw.strip_edges()
		if arg.begins_with("--levels="):
			levels.clear()
			for value in arg.trim_prefix("--levels=").split(","):
				levels.append(value.to_int())
		elif arg.begins_with("--seconds="):
			seconds = arg.trim_prefix("--seconds=").to_float()
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg == "--profile":
			profile = true
		elif arg == "--shake-plants":
			shake_plants = true
		elif arg == "--play":
			play = true
		elif arg.begins_with("--variants="):
			for value in arg.trim_prefix("--variants=").split(","):
				variants.append(value)
		elif arg == "--trace-draw":
			trace_draw = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	Progress.persist = false
	AudioServer.set_bus_mute(0, true)
	# Niente cutscene iniziali: la lampadina deve muoversi subito.
	for path in Progress.LEVELS:
		Cutscene._seen[path] = true
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	game = load("res://scenes/game.tscn").instantiate()
	if trace_draw:
		get_tree().node_added.connect(_trace_node)
	add_child(game)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	_label = Label.new()
	_label.position = Vector2(40, 40)
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	overlay.add_child(_label)
	_run()


func _run() -> void:
	_print_device()
	for number in levels:
		if play:
			_results.append(await _play_level(number))
		elif profile:
			_results.append(await _profile_level(number))
		elif not variants.is_empty():
			for variant in variants:
				_variant = variant
				_label.text = "Livello %d: %s" % [number, variant]
				var result := await _measure_level(number, "")
				result.variant = variant
				_print_result(result)
				_results.append(result)
			_variant = ""
		else:
			_label.text = "Livello %d" % number
			var result := await _measure_level(number, "")
			_print_result(result)
			_results.append(result)
			if shake_plants:
				_label.text = "Livello %d: piante in movimento" % number
				result = await _measure_level(number, "", true)
				_print_result(result)
				_results.append(result)
	_save()
	_label.text = "Benchmark finito"
	print("PERF DONE")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


## Gioco libero: il livello si gioca normalmente e si registrano i frame lenti.
func _play_level(number: int) -> Dictionary:
	game.load_level(number - 1)
	var flashes := []
	var on_flash := func(_origin: Vector2, _radius: float) -> void:
		_last_flash_ms = Time.get_ticks_msec()
		flashes.append(snappedf(_last_flash_ms / 1000.0, 0.01))
	var frames := PackedFloat32Array()
	var slow := []
	var start := Time.get_ticks_usec()
	var last := start
	var player: Player = null
	while (last - start) / 1000000.0 < seconds:
		if game.player != player:
			player = game.player
			player.flashed.connect(on_flash)
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var delta := (now - last) / 1000.0
		last = now
		var t := (now - start) / 1000000.0
		_label.text = "Gioco libero L%d: %ds" % [game.level_index + 1, ceili(seconds - t)]
		frames.append(delta)
		if delta <= PLAY_SLOW_MS:
			continue
		var since_flash := (Time.get_ticks_msec() - _last_flash_ms) / 1000.0 if _last_flash_ms >= 0 else -1.0
		var shadows := 0
		for child in game._shadow_layer.get_children():
			if child is ShadowPlatform:
				shadows += 1
		var entry := {
			"t": snappedf(t, 0.01),
			"ms": snappedf(delta, 0.1),
			"level": game.level_index + 1,
			"pos": str(player.global_position.round()),
			"vel": str(player.velocity.round()),
			"since_flash": snappedf(since_flash, 0.01),
			"shadows": shadows,
			"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1),
			"physics_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1),
			"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		}
		slow.append(entry)
		print("PERF SLOW t=%.2f %.0f ms L%d pos=%s vel=%s flash=%.2fs fa ombre=%d process=%.1f physics=%.1f draw=%d" % [
			t, delta, entry.level, entry.pos, entry.vel, since_flash, shadows, entry.process_ms, entry.physics_ms, entry.draw_calls])
	var after_flash := 0
	for entry in slow:
		if entry.since_flash >= 0.0 and entry.since_flash < 1.0:
			after_flash += 1
	var result := {
		"level": number,
		"play": true,
		"frames": frames.size(),
		"fps_avg": frames.size() / (_sum(frames) / 1000.0),
		"frame_ms_avg": _sum(frames) / frames.size(),
		"frame_ms_p95": _percentile(frames, 0.95),
		"frame_ms_p99": _percentile(frames, 0.99),
		"frame_ms_max": _percentile(frames, 1.0),
		"slow_frames": slow.size(),
		"slow_after_flash": after_flash,
		"flashes": flashes.size(),
		"slow": slow,
	}
	print("PERF PLAY L%d fps=%.1f frame avg=%.2f p95=%.2f p99=%.2f max=%.2f ms lenti(>%d ms)=%d di cui entro 1 s da un flash=%d flash=%d" % [
		number, result.fps_avg, result.frame_ms_avg, result.frame_ms_p95, result.frame_ms_p99, result.frame_ms_max,
		PLAY_SLOW_MS, slow.size(), after_flash, flashes.size()])
	return result


## Misura il livello completo, poi una volta per sistema disattivato, poi di
## nuovo completo (per vedere quanto è cambiato il telefono nel frattempo).
func _profile_level(number: int) -> Dictionary:
	game.load_level(number - 1)
	var systems: Array = ["flash", "shadows", "hud"]
	systems.append_array(_groups(game.level).keys())
	var phases: Array[Dictionary] = []
	var total := systems.size() + 2
	_label.text = "Livello %d: completo (1/%d)" % [number, total]
	var base_start := await _measure_level(number, "")
	for i in systems.size():
		_label.text = "Livello %d: senza %s (%d/%d)" % [number, systems[i], i + 2, total]
		phases.append(await _measure_level(number, systems[i]))
	_label.text = "Livello %d: completo (%d/%d)" % [number, total, total]
	var base_end := await _measure_level(number, "")
	var base_frame: float = (base_start.frame_ms_avg + base_end.frame_ms_avg) / 2.0
	var base_cpu: float = (base_start.cpu_ms_avg + base_end.cpu_ms_avg) / 2.0
	print("PERF L%d completo: frame %.2f -> %.2f ms, cpu %.2f -> %.2f ms (inizio -> fine)" % [
		number, base_start.frame_ms_avg, base_end.frame_ms_avg, base_start.cpu_ms_avg, base_end.cpu_ms_avg])
	for phase in phases:
		phase.saved_frame_ms = base_frame - phase.frame_ms_avg
		phase.saved_cpu_ms = base_cpu - phase.cpu_ms_avg
	phases.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.saved_frame_ms > b.saved_frame_ms)
	for phase in phases:
		print("PERF L%d senza %-22s risparmio frame %6.2f ms  cpu %6.2f ms  (nodi %d, draw %.0f)" % [
			number, phase.disabled, phase.saved_frame_ms, phase.saved_cpu_ms, phase.disabled_nodes, phase.draw_calls_avg])
	return {"level": number, "baseline_start": base_start, "baseline_end": base_end, "without": phases}


## Carica il livello, disattiva il sistema indicato ("" = nessuno) e misura.
func _measure_level(number: int, disabled: String, shake := false) -> Dictionary:
	game.load_level(number - 1)
	# Le ombre dei flash precedenti restano in coda fino al frame dopo.
	await get_tree().process_frame
	_flashes = disabled != "flash"
	var disabled_nodes := _disable(disabled)
	var player: Player = game.player
	for name in ["InputSetup", "Progress", "Sfx", "Music", "Settings"]:
		get_tree().root.get_node(name).process_mode = Node.PROCESS_MODE_INHERIT
	game._shadows.process_mode = Node.PROCESS_MODE_INHERIT
	_apply_variant(_variant)
	_draw_slow = []
	# La lampadina viene spostata a mano: niente fisica né collisioni (non muore).
	player.set_physics_process(false)
	player.collision_layer = 0
	player.collision_mask = 0
	game.camera_focus = player
	var path := _sweep_path(game.level.level_rect)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])

	var frames := PackedFloat32Array()
	var cpu := PackedFloat32Array()
	var gpu := PackedFloat32Array()
	var draw_calls := PackedInt32Array()
	var objects := PackedInt32Array()
	var max_nodes := 0
	var elapsed := -WARMUP
	var last := Time.get_ticks_usec()
	var flash_timer := 0.0
	var shake_timer := 0.0
	var spikes := []
	while elapsed < seconds:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var delta := (now - last) / 1000.0
		last = now
		elapsed += delta / 1000.0
		player.global_position = _point_at(path, length * clampf(elapsed / seconds, 0.0, 1.0))
		flash_timer -= delta / 1000.0
		if flash_timer <= 0.0 and _flashes:
			flash_timer = player.flash_cooldown
			player.try_flash(true)
		shake_timer -= delta / 1000.0
		if shake and shake_timer <= 0.0:
			shake_timer = 0.5
			_shake_plants()
		if delta > SPIKE_MS:
			var spike := {"t": snappedf(elapsed, 0.01), "ms": snappedf(delta, 0.1), "pos": str(player.global_position.round())}
			spikes.append(spike)
			print("PERF SPIKE L%d%s%s t=%.2f s %.0f ms pos=%s%s" % [number, " piante" if shake else "", " " + _variant if _variant else "", elapsed, delta, spike.pos, " (riscaldamento)" if elapsed < 0.0 else ""])
		if elapsed < 0.0:
			continue
		var rid := get_viewport().get_viewport_rid()
		frames.append(delta)
		cpu.append((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		objects.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		max_nodes = maxi(max_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_enable_shadows()

	return {
		"level": number,
		"disabled": disabled,
		"shake_plants": shake,
		"spikes": spikes,
		"slow_draws": _draw_slow.duplicate(),
		"disabled_nodes": disabled_nodes,
		"frames": frames.size(),
		"fps_avg": frames.size() / (_sum(frames) / 1000.0),
		"frame_ms_avg": _sum(frames) / frames.size(),
		"frame_ms_p95": _percentile(frames, 0.95),
		"frame_ms_p99": _percentile(frames, 0.99),
		"frame_ms_max": _percentile(frames, 1.0),
		"frames_over_budget_pct": 100.0 * _count_over(frames, BUDGET_MS * 1.2) / frames.size(),
		"cpu_ms_avg": _sum(cpu) / cpu.size(),
		"cpu_ms_p95": _percentile(cpu, 0.95),
		"gpu_ms_avg": _sum(gpu) / gpu.size(),
		"draw_calls_avg": _sum(draw_calls) / draw_calls.size(),
		"draw_calls_max": _percentile(draw_calls, 1.0),
		"objects_max": _percentile(objects, 1.0),
		"nodes_max": max_nodes,
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	}


## Varianti di prova per cercare la causa di un blocco (vedi --variants).
func _apply_variant(variant: String) -> void:
	var player: Player = game.player
	match variant:
		"no_autolight":
			for node in get_tree().root.find_children("*", "PointLight2D", true, false):
				if node.get_script() == LevelKit.AutoLight:
					node.set_process(false)
					node.enabled = true
		"no_player_events":
			player._flicker_wait = INF
			player._dim_wait = INF
		"no_player_process":
			player.set_process(false)
		"off_level":
			for child in game.level.get_children():
				if child != player:
					child.process_mode = Node.PROCESS_MODE_DISABLED
		"off_level_a", "off_level_b":
			# Metà dei figli del livello (in ordine): per dividere la ricerca.
			var children: Array = game.level.get_children().filter(func(c: Node) -> bool: return c != player)
			var half: int = children.size() / 2
			var part: Array = children.slice(0, half) if variant == "off_level_a" else children.slice(half)
			for child: Node in part:
				child.process_mode = Node.PROCESS_MODE_DISABLED
		"off_autoloads":
			for name in ["InputSetup", "Progress", "Sfx", "Music", "Settings"]:
				get_tree().root.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
		"off_shadows":
			game._shadows.process_mode = Node.PROCESS_MODE_DISABLED
		"no_flash":
			_flashes = false
		"flash_light_off":
			# Il flash crea le ombre ma la sua luce resta spenta.
			player._flash_light.set_process(false)
			player._flash_light.enabled = false
		"flash_shadow_off":
			player._flash_light.shadow_enabled = false
		"hide_beams":
			# Il fascio si disegna su un CanvasLayer a parte: nascondere la
			# finestra non basta.
			for beam in get_tree().get_nodes_in_group("light_beams"):
				beam._visual.visible = false
		"bg_off", "bg_no_base", "bg_no_far", "bg_no_near", "bg_no_front":
			_hide_background(variant)


## Varianti "bg_*": nasconde lo sfondo intero o un suo strato. Il fondo (BASE)
## è il nodo stesso, padre degli altri strati: lo si svuota quando la sua
## texture è pronta invece di nasconderlo.
func _hide_background(variant: String) -> void:
	var bg: Node2D = game.level.get_node_or_null("Background")
	if bg == null:
		return
	match variant:
		"bg_off": bg.visible = false
		"bg_no_far": bg._far.visible = false
		"bg_no_near": bg._near.visible = false
		"bg_no_front": bg._front.visible = false
		"bg_no_base":
			while not bg._baked.has(bg.BASE):
				await get_tree().process_frame
			bg._baked_tiles[bg.BASE] = []
			bg.queue_redraw()


## --trace-draw: ogni CanvasItem segnala quando comincia a disegnarsi. Il tempo
## fino al disegno successivo dello stesso frame è (circa) il costo del suo _draw.
func _trace_node(node: Node) -> void:
	if node is CanvasItem:
		node.draw.connect(_on_traced_draw.bind(node))


func _on_traced_draw(node: Node) -> void:
	var now := Time.get_ticks_usec()
	var frame := Engine.get_process_frames()
	if frame == _draw_last_frame and is_instance_valid(_draw_last_node):
		var ms := (now - _draw_last_us) / 1000.0
		if ms > DRAW_SLOW_MS:
			var script: Script = _draw_last_node.get_script()
			var entry := {"ms": snappedf(ms, 0.1), "node": str(_draw_last_node.get_path()), "script": script.resource_path.get_file() if script else _draw_last_node.get_class()}
			_draw_slow.append(entry)
			print("PERF DRAW %.0f ms %s (%s)" % [ms, entry.node, entry.script])
	_draw_last_us = now
	_draw_last_frame = frame
	_draw_last_node = node


## Mette in movimento le piante e i rampicanti inquadrati (gli altri hanno la
## fisica ferma), come se la lampadina li avesse appena scossi.
func _shake_plants() -> void:
	for key in PLANT_SCRIPTS:
		for node: Node in _groups(game.level).get(key, []):
			node._resting = false
			if key == "ground_plant.gd":
				node._part_velocity.resize(node._part_points.size())
				for i in node._part_velocity.size():
					node._part_velocity[i] = randf_range(-0.6, 0.6)
			else:
				for i in node._swing_velocity.size():
					node._swing_velocity[i] = randf_range(-0.6, 0.6)


## Nodi del livello raggruppati per script (o per classe nativa): nome -> nodi.
## Un nodo dentro un altro dello stesso gruppo non si conta (si spegne col padre).
func _groups(root: Node) -> Dictionary:
	var groups := {}
	for node in root.find_children("*", "", true, false):
		var key := _group_key(node)
		if key == "" or node == game.player or game.player.is_ancestor_of(node):
			continue
		var parent := node.get_parent()
		var nested := false
		while parent != root:
			if _group_key(parent) == key:
				nested = true
				break
			parent = parent.get_parent()
		if not nested:
			if not groups.has(key):
				groups[key] = []
			groups[key].append(node)
	return groups


func _group_key(node: Node) -> String:
	var script: Script = node.get_script()
	if script and script.resource_path:
		var file := script.resource_path.get_file()
		return "" if file in SKIP_SCRIPTS else file
	for type in NATIVE_GROUPS:
		if node.is_class(type):
			return type
	return ""


## Spegne un sistema (process e disegno) e restituisce quanti nodi ha toccato.
func _disable(system: String) -> int:
	match system:
		"", "flash":
			return 0
		"shadows":
			game._shadows.process_mode = Node.PROCESS_MODE_DISABLED
			game._shadow_layer.visible = false
			return 1
		"hud":
			for child in game.get_children():
				if child is CanvasLayer and child.layer == 10:
					child.process_mode = Node.PROCESS_MODE_DISABLED
					child.visible = false
			return 1
	var nodes: Array = _groups(game.level).get(system, [])
	for node: Node in nodes:
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is CanvasItem:
			node.visible = false
		if node is Light2D:
			node.enabled = false
	return nodes.size()


## Il sistema delle ombre e l'HUD stanno nella scena di gioco, che resta tra un
## livello e l'altro: vanno riaccesi a mano.
func _enable_shadows() -> void:
	game._shadows.process_mode = Node.PROCESS_MODE_INHERIT
	game._shadow_layer.visible = true
	for child in game.get_children():
		if child is CanvasLayer and child.layer == 10:
			child.process_mode = Node.PROCESS_MODE_INHERIT
			child.visible = true


## Percorso a zig-zag che copre tutto il livello: righe distanti al massimo 700 px.
func _sweep_path(rect: Rect2) -> PackedVector2Array:
	var margin := 120.0
	var area := rect.grow(-margin)
	var rows := maxi(1, ceili(area.size.y / 700.0))
	var path := PackedVector2Array()
	for row in rows + 1:
		var y := area.end.y - area.size.y * row / rows
		var left := Vector2(area.position.x, y)
		var right := Vector2(area.end.x, y)
		if row % 2 == 0:
			path.append_array([left, right])
		else:
			path.append_array([right, left])
	return path


func _point_at(path: PackedVector2Array, distance: float) -> Vector2:
	for i in range(1, path.size()):
		var step := path[i - 1].distance_to(path[i])
		if distance <= step:
			return path[i - 1].lerp(path[i], distance / step if step > 0.0 else 0.0)
		distance -= step
	return path[path.size() - 1]


func _sum(values) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total


func _percentile(values, fraction: float) -> float:
	var sorted := Array(values)
	sorted.sort()
	return sorted[clampi(ceili(fraction * sorted.size()) - 1, 0, sorted.size() - 1)]


func _count_over(values, limit: float) -> int:
	var count := 0
	for value in values:
		if value > limit:
			count += 1
	return count


func _print_result(result: Dictionary) -> void:
	print("PERF L%d%s fps=%.1f frame avg=%.2f p95=%.2f p99=%.2f max=%.2f ms lenti=%.1f%% cpu avg=%.2f p95=%.2f ms gpu=%.2f ms draw=%.0f/%d nodi=%d mem=%.0f MB" % [
		result.level, (" piante" if result.get("shake_plants", false) else "") + (" " + result.variant if result.has("variant") else ""), result.fps_avg, result.frame_ms_avg, result.frame_ms_p95, result.frame_ms_p99,
		result.frame_ms_max, result.frames_over_budget_pct, result.cpu_ms_avg, result.cpu_ms_p95,
		result.gpu_ms_avg, result.draw_calls_avg, result.draw_calls_max, result.nodes_max, result.memory_mb])


func _print_device() -> void:
	print("PERF DEVICE %s" % JSON.stringify(_device_info()))


func _device_info() -> Dictionary:
	return {
		"model": OS.get_model_name(),
		"os": OS.get_name() + " " + OS.get_version(),
		"cpu": OS.get_processor_name(),
		"cores": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"screen": str(DisplayServer.screen_get_size()),
		"refresh_rate": DisplayServer.screen_get_refresh_rate(),
		"seconds_per_level": seconds,
		"profile": profile,
		"date": Time.get_datetime_string_from_system(),
	}


func _save() -> void:
	var file := FileAccess.open(out_dir.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"device": _device_info(), "levels": _results}, "\t"))
	print("PERF SAVED %s" % ProjectSettings.globalize_path(out_dir.path_join("results.json")))
