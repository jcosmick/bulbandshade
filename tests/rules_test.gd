extends Node
## Test mirati (solo sviluppo) delle regole di luce, ombre e acqua nel livello 3
## ("Temporale"): ogni regola ricarica il livello, teletrasporta la lampadina
## e stampa "REGOLA <nome>: OK/FALLITO (<dettagli>)", con uno screenshot.
## In fondo alcuni casi limite esplorativi (stesso formato) e il passaggio dal
## menu a un altro livello (va per ultimo: cambia la scena corrente).
## Uso: Godot --path . res://tests/rules_test.tscn -- --out=<cartella>

const LEVEL_INDEX := 2
## Mezza altezza della capsula del giocatore: centro = piede - 52.
const HALF_HEIGHT := 52.0
const FLASH_RADIUS := 750.0
## Posizione iniziale della cassa spingibile della sezione E.
const BOX_START := Vector2(160, 1060)
## Cassa contro il muro sinistro, davanti a WindowE (x 60–160).
const BOX_AT_WALL := Vector2(110, 1060)
## Posto sul LedgeGoal dove parcheggiare la cassa per lasciar passare il fascio.
const BOX_PARKED := Vector2(700, 680)
## Sopra CrateD, sotto il rubinetto.
const CRATE_D_TOP := 1420.0
## Segmento di caduta delle gocce di FaucetD (dalla bocca alla cima di CrateD).
const DRIP_TOP := Vector2(770, 870)
const DRIP_BOTTOM := Vector2(770, 1415)

var game: Node
var out_dir := "user://rules_test"
var _results: Array[String] = []
var _deaths := 0
var _last_death_pos := Vector2.ZERO


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	Progress.persist = false
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	_run()


func _run() -> void:
	await _test_e_floor_shaded_at_start()
	await _test_flash_in_beam()
	await _test_box_blocks_window()
	await _test_beam_is_barrier()
	await _test_drops_through_shadows()
	await _test_drop_kills_player()
	await _test_respawn_resets()
	await _test_respawn_resets("respawn_resets_box_under_player", true)
	await _test_pit_water()
	await _edge_beam_margin()
	await _edge_shadow_under_shutter()
	await _edge_push_box_to_wall()
	await _edge_double_death()
	await _edge_restart_mid_death()
	await _edge_menu_and_other_level()
	print("--- RIEPILOGO ---")
	var failed := 0
	for line in _results:
		print(line)
		if "FALLITO" in line:
			failed += 1
	print("REGOLE FALLITE: %d su %d" % [failed, _results.size()])
	get_tree().quit()


# --- Regole -----------------------------------------------------------------

## Sezione E all'inizio: PushBoxE sta già davanti a WindowE, quindi il fascio
## si ferma sulla cassa e FloorE resta al buio (lì il flash funziona).
func _test_e_floor_shaded_at_start() -> void:
	await _fresh()
	var window: WindowLight = game.level.get_node("WindowE")
	var lit_points: Array[Vector2] = []
	for x in [230.0, 245.0, 420.0]:
		var origin := Vector2(x, 1068.0 - 16.0)
		if game._shadows.is_in_beam(origin):
			lit_points.append(origin)
	_report("e_floor_shaded_at_start", lit_points.is_empty(),
			"fascio WindowE=%s, punti di FloorE nel fascio: %s" % [window.beam_polygons(), lit_points])
	# Flash da x=245 senza spingere la cassa: se crea la rampa, la spinta non serve.
	_tp(Vector2(245, 1068))
	await _wait(0.3)
	game.player.try_flash()
	await _frames(2)
	var ramp := _platforms().filter(func(p: ShadowPlatform) -> bool: return p.bounds.end.x > 500.0)
	print("INFO e_flash_senza_spinta: ombre=%d, pezzi oltre x=500 (rampa)=%d" % [_platforms().size(), ramp.size()])
	await _shot("e_no_push_flash")


## Lampadina nel fascio di WindowE (cassa spostata via): il flash non crea ombre.
func _test_flash_in_beam() -> void:
	await _fresh()
	await _park_box()
	_tp(Vector2(230, 1068))
	await _wait(0.3)
	var origin: Vector2 = game.player.light_origin()
	var inside: bool = game._shadows.is_in_beam(origin)
	var before := _platforms().size()
	game.player.try_flash()
	await _frames(2)
	var after := _platforms().size()
	var direct: bool = game._shadows.flash(origin, FLASH_RADIUS)
	await _frames(2)
	var after_direct := _platforms().size()
	var ok: bool = inside and after == before and after_direct == before and not direct \
			and game.flash_count == 1
	_report("flash_in_beam", ok, "nel fascio=%s ombre %d->%d->%d flash()=%s flash_count=%d" % [
			inside, before, after, after_direct, direct, game.flash_count])
	await _shot("a_flash_in_beam")


## Cassa contro il muro davanti a WindowE: il flash accanto a CrateE crea la
## rampa e nessuna ombra finisce nel fascio.
func _test_box_blocks_window() -> void:
	await _fresh()
	var box: PushBox = game.level.get_node("PushBoxE")
	box.global_position = BOX_AT_WALL
	await _frames(3)
	_tp(Vector2(190, 1068))
	await _wait(0.3)
	var window: WindowLight = game.level.get_node("WindowE")
	var inside: bool = game._shadows.is_in_beam(game.player.light_origin())
	game.player.try_flash()
	await _frames(2)
	var platforms := _platforms()
	var overlap_e := _overlap(platforms, window.beam_polygons())
	var overlap_all := _overlap(platforms, game._shadows._beam_polygons())
	var ramp := platforms.filter(func(p: ShadowPlatform) -> bool: return p.bounds.end.x > 500.0)
	var ok: bool = not inside and platforms.size() > 0 and not ramp.is_empty() and overlap_e < 100.0 and overlap_all < 100.0
	_report("box_blocks_window", ok, "cassa x=%.0f nel fascio=%s ombre=%d rampa=%d sovrapp. WindowE=%.0f tutti=%.0f px²" % [
			box.global_position.x, inside, platforms.size(), ramp.size(), overlap_e, overlap_all])
	await _shot("b_box_blocks_window")


## Dal LedgeD il fascio di WindowD sta tra la lampadina e CrateE: nessuna ombra
## al di là del fascio. Controllo: per ogni ombra, i vertici (spostati di 2 px
## verso il centro) e il centro devono essere visibili dalla lampadina senza
## che il segmento attraversi un fascio acceso; in più nessuna sovrapposizione
## con i fasci e nessuna ombra di CrateE (sopra y=1080).
func _test_beam_is_barrier() -> void:
	await _fresh()
	_tp(Vector2(990, 1468))
	await _wait(0.3)
	var origin: Vector2 = game.player.light_origin()
	game.player.try_flash()
	await _frames(2)
	var platforms := _platforms()
	var barriers: Array[PackedVector2Array] = game._shadows._beam_barriers(origin)
	var beyond := 0
	var samples := 0
	for platform in platforms:
		for point in _samples(platform.polygon):
			samples += 1
			if _crosses(origin, point, barriers):
				beyond += 1
	var overlap := _overlap(platforms, game._shadows._beam_polygons())
	var high := platforms.filter(func(p: ShadowPlatform) -> bool: return p.bounds.position.y < 1080.0)
	var ok: bool = platforms.size() > 0 and beyond == 0 and overlap < 100.0 and high.is_empty()
	_report("beam_is_barrier", ok, "origine=%s ombre=%d campioni=%d oltre il fascio=%d sovrapp.=%.0f px² ombre sopra y=1080: %d" % [
			origin, platforms.size(), samples, beyond, overlap, high.size()])
	await _shot("c_beam_is_barrier")
	# Stesso controllo sul flash della sezione B a persiana chiusa e poi aperta.
	await _fresh()
	_tp(Vector2(985, 2228))
	var window_b: WindowLight = game.level.get_node("WindowB")
	await _until(func() -> bool: return window_b.is_lit(), 8.0)
	var lit_origin := Vector2(700, 2212)
	var lit_ok: bool = game._shadows.flash(lit_origin, FLASH_RADIUS)
	await _frames(2)
	platforms = _platforms()
	barriers = game._shadows._beam_barriers(lit_origin)
	beyond = 0
	for platform in platforms:
		for point in _samples(platform.polygon):
			if _crosses(lit_origin, point, barriers):
				beyond += 1
	overlap = _overlap(platforms, game._shadows._beam_polygons())
	_report("beam_is_barrier_B", lit_ok and beyond == 0 and overlap < 100.0, "WindowB accesa, flash da %s: flash()=%s ombre=%d oltre=%d sovrapp.=%.0f px²" % [
			lit_origin, lit_ok, platforms.size(), beyond, overlap])
	_snap_camera_to(lit_origin)
	await _shot("c_beam_is_barrier_B")


## Rampa d'ombra di CrateD sotto il rubinetto: la goccia la attraversa e
## arriva sulla cima di CrateD.
func _test_drops_through_shadows() -> void:
	await _fresh()
	_tp(Vector2(900, 1468))
	await _wait(0.3)
	var faucet: WaterDrip = game.level.get_node("FaucetD")
	await faucet.drop_landed
	game.player.try_flash()
	await _frames(2)
	var band := PackedVector2Array()
	for platform in _platforms():
		for hit in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([DRIP_TOP, DRIP_BOTTOM]), platform.polygon):
			band.append_array(hit)
	# Le lambda catturano le variabili locali per valore: serve un contenitore.
	var state := {"landed": false}
	faucet.drop_landed.connect(func() -> void: state.landed = true, CONNECT_ONE_SHOT)
	var max_y := 0.0
	var shot_taken := false
	var time := 0.0
	while not state.landed and time < 3.0:
		await get_tree().physics_frame
		time += get_physics_process_delta_time()
		for drop in faucet._drops:
			var y: float = drop.pos.y + faucet.global_position.y
			max_y = maxf(max_y, y)
			if not shot_taken and band.size() >= 2 and y > minf(band[0].y, band[1].y) and y < maxf(band[0].y, band[1].y):
				shot_taken = true
				await _shot("d_drop_in_shadow")
	var splash_y := -1.0
	if not faucet._splashes.is_empty():
		splash_y = faucet._splashes.back().pos.y + faucet.global_position.y
	var drain_y: float = faucet._landing.y + faucet.global_position.y
	var landed: bool = state.landed
	var ok: bool = band.size() >= 2 and landed and absf(splash_y - CRATE_D_TOP) < 2.0 \
			and absf(drain_y - CRATE_D_TOP) < 2.0 and not game.player.dead
	_report("drops_through_shadows", ok, "ombra sul percorso: %s, goccia arrivata=%s a y=%.1f (max y=%.1f), tombino y=%.1f, ombre vive=%d" % [
			band, landed, splash_y, max_y, drain_y, _platforms().size()])
	await _shot("d_drop_landed")


## Lampadina sotto il rubinetto, sulla cima di CrateD: una goccia la manda in
## cortocircuito entro due intervalli.
func _test_drop_kills_player() -> void:
	await _fresh()
	var faucet: WaterDrip = game.level.get_node("FaucetD")
	_tp(Vector2(770, CRATE_D_TOP - HALF_HEIGHT))
	var time := 0.0
	while _deaths == 0 and time < faucet.interval * 2.0 + 1.0:
		await get_tree().physics_frame
		time += get_physics_process_delta_time()
	_report("drop_kills_player", _deaths == 1, "morti=%d dopo %.2f s (intervallo %.1f s), pos=%s" % [
			_deaths, time, faucet.interval, _last_death_pos])
	await _shot("e_drop_kills")
	await _wait(1.2)
	var respawn_ok: bool = not game.player.dead and game.player.global_position.distance_to(game._spawn_point) < 30.0
	_report("drop_kills_respawn", respawn_ok, "ricomparsa a %s (spawn %s)" % [game.player.global_position, game._spawn_point])


## Morte nella sezione E con la cassa spostata e ombre accese: si riparte dal
## CheckpointE, ombre cancellate e cassa al suo posto. Con at_box_start la
## lampadina muore dove la cassa deve tornare (x=190, dopo averla spinta).
func _test_respawn_resets(rule := "respawn_resets", at_box_start := false) -> void:
	await _fresh()
	_tp(Vector2(420, 1068))
	await _wait(0.3)
	var checkpoint: Checkpoint = game.level.get_node("CheckpointE")
	var reached: bool = game._checkpoint == checkpoint
	var box: PushBox = game.level.get_node("PushBoxE")
	# Spinta vera: da x=245 verso sinistra finché la cassa tocca il muro.
	_tp(Vector2(245, 1068))
	await _wait(0.2)
	Input.action_press("move_left")
	await _wait(1.0)
	Input.action_release("move_left")
	await _wait(0.2)
	var pushed_x := box.global_position.x
	game.player.try_flash()
	await _frames(2)
	var shadows_before := _platforms().size()
	if not at_box_start:
		_tp(Vector2(420, 1068))
		await _frames(3)
	var death_pos: Vector2 = game.player.global_position
	game.player.die()
	await _wait(0.3)
	await _shot("f_dead_%s" % rule)
	await _wait(1.0)
	var pos: Vector2 = game.player.global_position
	var ok: bool = reached and shadows_before > 0 and not game.player.dead 			and pos.distance_to(checkpoint.spawn_position()) < 20.0 and _platforms().is_empty() 			and box.global_position.distance_to(BOX_START) < 2.0
	_report(rule, ok, "checkpoint E raggiunto=%s, cassa spinta a x=%.1f, morte a %s, ombre %d->%d, lampadina=%s (atteso %s) viva=%s, cassa=%s (atteso %s)" % [
			reached, pushed_x, death_pos, shadows_before, _platforms().size(), pos, checkpoint.spawn_position(),
			not game.player.dead, box.global_position, BOX_START])
	await _shot("f_respawned_%s" % rule)


## Camminando verso destra dall'inizio si cade in PitWaterStart: cortocircuito
## con la lampadina dentro la buca (piedi sotto il pavimento, y 2700).
func _test_pit_water() -> void:
	await _fresh()
	await _wait(0.3)
	Input.action_press("move_right")
	var time := 0.0
	while _deaths == 0 and time < 3.0:
		await get_tree().physics_frame
		time += get_physics_process_delta_time()
	Input.action_release("move_right")
	var death_pos := _last_death_pos
	await _shot("g_pit_death")
	await _wait(0.3)
	var frozen: bool = game.player.global_position.distance_to(death_pos) < 1.0
	var feet := death_pos.y + HALF_HEIGHT
	var ok: bool = _deaths == 1 and feet > 2700.0 and death_pos.x > 240.0 and death_pos.x < 380.0 and frozen
	_report("pit_water", ok, "morti=%d pos=%s piedi y=%.0f (pavimento 2700, acqua da 2725) ferma=%s" % [
			_deaths, death_pos, feet, frozen])
	await _wait(1.0)
	_report("pit_water_respawn", not game.player.dead and game.player.global_position.distance_to(Vector2(150, 2648)) < 30.0,
			"ricomparsa a %s" % game.player.global_position)


# --- Casi limite esplorativi -------------------------------------------------

## Flash appena dentro/fuori il margine di 30 px dal bordo del fascio di WindowE.
func _edge_beam_margin() -> void:
	await _fresh()
	await _park_box()
	var edge_y := 1010.0 + 0.12 * (230.0 - 60.0)
	var results := {}
	for offset in [0.0, -25.0, -35.0, -60.0]:
		game._shadows.clear()
		await _frames(1)
		results[offset] = game._shadows.flash(Vector2(230, edge_y + offset), FLASH_RADIUS)
	game._shadows.clear()
	var ok: bool = not results[0.0] and not results[-25.0] and results[-35.0] and results[-60.0]
	_report("edge_beam_margin", ok, "bordo y=%.1f; flash() per scostamento: %s" % [edge_y, results])


## Lampadina in piedi su un'ombra quando la persiana di WindowB si apre.
func _edge_shadow_under_shutter() -> void:
	await _fresh()
	var window: WindowLight = game.level.get_node("WindowB")
	_tp(Vector2(985, 2228))
	await _until(func() -> bool: return window.is_lit(), 8.0)
	await _until(func() -> bool: return not window.is_lit(), 8.0)
	# Flash (diretti) da alcuni punti della sezione B finché un'ombra non entra
	# nel fascio spento; poi la lampadina ci sale sopra.
	var stand := Vector2.INF
	var used_origin := Vector2.ZERO
	for origin in [Vector2(300, 2212), Vector2(450, 2212), Vector2(985, 2212), Vector2(200, 1832)]:
		game._shadows.clear()
		await _frames(1)
		game._shadows.flash(origin, FLASH_RADIUS)
		await _frames(1)
		for platform in _platforms():
			for beam in window._polygons:
				for piece in Geometry2D.intersect_polygons(platform.polygon, beam):
					if ShadowSystem._area(piece) > 3000.0 and stand == Vector2.INF:
						var c := _centroid(piece)
						var top := c.y
						while Geometry2D.is_point_in_polygon(Vector2(c.x, top - 2.0), platform.polygon):
							top -= 2.0
						stand = Vector2(c.x, top - HALF_HEIGHT - 1.0)
						used_origin = origin
		if stand != Vector2.INF:
			break
	print("INFO shutter: flash da %s, lampadina in piedi a %s" % [used_origin, stand])
	if stand == Vector2.INF:
		_report("edge_shadow_under_shutter", false, "nessuna ombra dentro il fascio spento di WindowB")
		return
	_tp(stand)
	await _wait(0.2)
	var on_floor: bool = game.player.is_on_floor()
	var y_before: float = game.player.global_position.y
	await _shot("x_on_shadow_closed")
	await _until(func() -> bool: return window.is_lit(), 4.0)
	await _wait(0.4)
	var dy: float = game.player.global_position.y - y_before
	var overlap := _overlap(_platforms(), window.beam_polygons())
	_report("edge_shadow_under_shutter", on_floor and dy > 20.0 and overlap < 100.0, "in piedi su %s (a terra=%s); dopo l'apertura dy=%.0f, sovrapp. ombre/fascio=%.0f px², morti=%d" % [
			stand, on_floor, dy, overlap, _deaths])
	await _shot("x_on_shadow_open")


## Spinge PushBoxE a sinistra a lungo: si ferma contro il muro, non lo attraversa.
func _edge_push_box_to_wall() -> void:
	await _fresh()
	var box: PushBox = game.level.get_node("PushBoxE")
	_tp(Vector2(245, 1068))
	await _wait(0.2)
	Input.action_press("move_left")
	await _wait(1.5)
	Input.action_release("move_left")
	await _wait(0.2)
	var left: float = box.global_position.x - box.size.x / 2.0
	var ok: bool = left >= 59.0 and left < 62.0 and absf(box.global_position.y - BOX_START.y) < 2.0
	_report("edge_push_box_to_wall", ok, "cassa a %s (bordo sinistro %.1f, muro a 60), lampadina a %s" % [
			box.global_position, left, game.player.global_position])
	await _shot("x_box_at_wall")


## Due cortocircuiti di fila: il secondo durante la morte viene ignorato, un
## terzo subito dopo la ricomparsa funziona di nuovo.
func _edge_double_death() -> void:
	await _fresh()
	game.player.die()
	await _wait(0.2)
	game.player.die()
	await _wait(1.0)
	var first_ok: bool = _deaths == 1 and not game.player.dead
	game.player.die()
	await _wait(1.2)
	var ok: bool = first_ok and _deaths == 2 and not game.player.dead and game.player.controls_enabled \
			and game.player.is_physics_processing()
	_report("edge_double_death", ok, "morti=%d viva=%s controlli=%s fisica=%s pos=%s" % [
			_deaths, not game.player.dead, game.player.controls_enabled, game.player.is_physics_processing(),
			game.player.global_position])


## "restart" durante il cortocircuito: il livello riparte pulito e la vecchia
## ricomparsa in sospeso non tocca il nuovo livello.
func _edge_restart_mid_death() -> void:
	await _fresh()
	_tp(Vector2(480, 2648))
	await _wait(0.3)
	game.player.try_flash()
	await _frames(2)
	var old_level: Node = game.level
	game.player.die()
	await _wait(0.3)
	await _press("restart")
	await _wait(1.2)
	var ok: bool = game.level != old_level and not game.player.dead \
			and game.player.global_position.distance_to(Vector2(150, 2648)) < 30.0 \
			and game.flash_count == 0 and _platforms().is_empty()
	_report("edge_restart_mid_death", ok, "nuovo livello=%s viva=%s pos=%s flash=%d ombre=%d" % [
			game.level != old_level, not game.player.dead, game.player.global_position, game.flash_count, _platforms().size()])


## "menu" dalla partita, poi livello 1 dalla griglia, poi di nuovo menu e
## livello 3. Va per ultimo: la scena di gioco viene sostituita.
func _edge_menu_and_other_level() -> void:
	await _fresh()
	Progress._best_flashes.clear()
	Progress.complete_level(0, 3)
	Progress.complete_level(1, 2)
	# Il cambio scena sostituisce la scena corrente: deve essere il gioco
	# (figlio diretto della radice), non questo nodo di test.
	game.reparent(get_tree().root)
	get_tree().current_scene = game
	await _press("menu")
	await _wait(0.5)
	var menu := get_tree().current_scene
	var in_menu := menu != null and menu.has_method("_start_level")
	await _shot("x_menu")
	if not in_menu:
		_report("edge_menu_and_other_level", false, "il tasto menu non ha aperto il menu (scena: %s)" % menu)
		return
	var cards := menu.find_children("*", "Button", true, false)
	cards[1].pressed.emit()
	await _wait(0.8)
	var level_1: Node = get_tree().current_scene
	var name_1: String = level_1.level.level_name if "level" in level_1 else "?"
	await _shot("x_menu_level1")
	await _press("menu")
	await _wait(0.5)
	menu = get_tree().current_scene
	cards = menu.find_children("*", "Button", true, false)
	cards[3].pressed.emit()
	await _wait(0.8)
	var level_3: Node = get_tree().current_scene
	var name_3: String = level_3.level.level_name if "level" in level_3 else "?"
	var follow: bool = level_3._follow if "level" in level_3 else false
	await _shot("x_menu_level3")
	var ok: bool = name_1.begins_with("1") and name_3.begins_with("3") and follow \
			and level_3.flash_count == 0 and not level_3.player.dead
	_report("edge_menu_and_other_level", ok, "livello dal menu: \"%s\", poi \"%s\" (telecamera che segue=%s)" % [
			name_1, name_3, follow])


# --- Utilità ------------------------------------------------------------------

## Ricarica il livello 3 da zero.
func _fresh() -> void:
	for action in ["move_left", "move_right", "jump", "flash", "restart", "menu"]:
		Input.action_release(action)
	await game.load_level(LEVEL_INDEX)
	_deaths = 0
	_connect_player()
	await _frames(3)


func _connect_player() -> void:
	game.player.died.connect(func() -> void:
		_deaths += 1
		_last_death_pos = game.player.global_position
		print("CORTOCIRCUITO a %s" % game.player.global_position))


## Sposta PushBoxE sul LedgeGoal, così il fascio di WindowE arriva su FloorE.
func _park_box() -> void:
	game.level.get_node("PushBoxE").global_position = BOX_PARKED
	await _frames(3)


func _tp(pos: Vector2) -> void:
	game.player.global_position = pos
	game.player.velocity = Vector2.ZERO
	_snap_camera_to(pos)


func _snap_camera_to(pos: Vector2) -> void:
	if game._follow:
		var player_pos: Vector2 = game.player.global_position
		game.player.global_position = pos
		game._camera.position = game._camera_target()
		game.player.global_position = player_pos


## Preme e rilascia un'azione. La pressione avviene nel segnale process_frame,
## prima dei _process dei nodi: così is_action_just_pressed() la vede (dopo un
## timer arriverebbe a _process già fatto e andrebbe persa).
func _press(action: String) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)
	# Dopo un cambio di scena o un restart il giocatore è nuovo.
	await get_tree().process_frame
	if action == "restart":
		_deaths = 0
		_connect_player()


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


func _platforms() -> Array[ShadowPlatform]:
	var result: Array[ShadowPlatform] = []
	for platform in game._shadow_layer.get_children():
		if platform is ShadowPlatform and not platform.is_queued_for_deletion():
			result.append(platform)
	return result


static func _overlap(platforms: Array, beams: Array[PackedVector2Array]) -> float:
	var total := 0.0
	for platform in platforms:
		for beam in beams:
			for piece in Geometry2D.intersect_polygons(platform.polygon, beam):
				total += ShadowSystem._area(piece)
	return total


static func _centroid(polygon: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for v in polygon:
		center += v
	return center / polygon.size()


## Punti campione di un'ombra: i vertici spostati di 2 px verso il centro, più
## il centro se è dentro il poligono.
static func _samples(polygon: PackedVector2Array) -> Array[Vector2]:
	var center := _centroid(polygon)
	var result: Array[Vector2] = []
	for v in polygon:
		var p := v.move_toward(center, 2.0)
		if Geometry2D.is_point_in_polygon(p, polygon):
			result.append(p)
	if Geometry2D.is_point_in_polygon(center, polygon):
		result.append(center)
	return result


## True se il segmento attraversa il bordo di uno dei poligoni.
static func _crosses(from: Vector2, to: Vector2, polygons: Array[PackedVector2Array]) -> bool:
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(to, polygon):
			return true
		for i in polygon.size():
			if Geometry2D.segment_intersects_segment(from, to, polygon[i], polygon[(i + 1) % polygon.size()]) != null:
				return true
	return false


func _report(rule: String, ok: bool, details: String) -> void:
	var line := "REGOLA %s: %s (%s)" % [rule, "OK" if ok else "FALLITO", details]
	print(line)
	_results.append(line)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("R_%s.png" % shot_name))
