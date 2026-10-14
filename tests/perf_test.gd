extends Node
## Benchmark delle prestazioni (solo sviluppo): carica i livelli uno dopo
## l'altro, sposta la lampadina lungo tutto il livello (a zig-zag, righe distanti
## al massimo 700 px) facendo un flash a ogni ricarica, e misura i tempi di frame.
## Con --profile, per ogni livello ripete lo stesso percorso disattivando un
## sistema alla volta (nodi con lo stesso script, luci, particelle, ombre, flash,
## HUD) e riporta quanto si risparmia rispetto al livello completo.
## Uso su PC: Godot --path . res://tests/perf_test.tscn -- --levels=1,8 --seconds=20 [--profile]
## Su Android è la scena principale del preset "Android Perf" (feature perf_test):
## gli argomenti si leggono da user://perf/args.txt, i risultati vanno nel log
## (righe "PERF") e in user://perf/results.json.

## Secondi iniziali di ogni misura esclusi (caricamento, shader).
const WARMUP := 1.5
## Budget di un frame a 60 fps, in millisecondi.
const BUDGET_MS := 1000.0 / 60.0
## Classi native raggruppate nella profilazione (anche senza script).
const NATIVE_GROUPS := ["Light2D", "LightOccluder2D", "GPUParticles2D", "CPUParticles2D", "CanvasModulate"]
## Script che non si possono disattivare: servono al test stesso.
const SKIP_SCRIPTS := ["level.gd", "player.gd", "game.gd", "shadow_system.gd"]

var game: Node
var levels: Array[int] = []
var seconds := 20.0
var profile := false
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
	DirAccess.make_dir_recursive_absolute(out_dir)
	Progress.persist = false
	AudioServer.set_bus_mute(0, true)
	# Niente cutscene iniziali: la lampadina deve muoversi subito.
	for path in Progress.LEVELS:
		Cutscene._seen[path] = true
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	game = load("res://scenes/game.tscn").instantiate()
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
		if profile:
			_results.append(await _profile_level(number))
		else:
			_label.text = "Livello %d" % number
			var result := await _measure_level(number, "")
			_print_result(result)
			_results.append(result)
	_save()
	_label.text = "Benchmark finito"
	print("PERF DONE")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


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
func _measure_level(number: int, disabled: String) -> Dictionary:
	game.load_level(number - 1)
	# Le ombre dei flash precedenti restano in coda fino al frame dopo.
	await get_tree().process_frame
	_flashes = disabled != "flash"
	var disabled_nodes := _disable(disabled)
	var player: Player = game.player
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
	print("PERF L%d fps=%.1f frame avg=%.2f p95=%.2f p99=%.2f max=%.2f ms lenti=%.1f%% cpu avg=%.2f p95=%.2f ms gpu=%.2f ms draw=%.0f/%d nodi=%d mem=%.0f MB" % [
		result.level, result.fps_avg, result.frame_ms_avg, result.frame_ms_p95, result.frame_ms_p99,
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
