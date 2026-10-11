extends Node2D
## Gestisce livelli, telecamera, buio della stanza, interfaccia e controlli touch.

const MENU_SCENE := "res://scenes/menu.tscn"
## Altezza della fascia in basso riservata ai pulsanti touch.
const CONTROLS_HEIGHT := 400.0
const DARK := Color(0.11, 0.11, 0.17)
const LIT := Color(0.95, 0.9, 0.82)
## Secondi tra il cortocircuito e la ricomparsa al checkpoint.
const RESPAWN_DELAY := 1.0
## Velocità con cui la telecamera raggiunge la lampadina (livelli grandi).
const CAMERA_FOLLOW_SPEED := 8.0
## Larghezza di livello mostrata sullo schermo nei livelli grandi.
const VIEW_WIDTH := 1080.0

var level_index := 0
var level: Level
var player: Player
var goal: GoalLamp
var flash_count := 0
var won := false

var _camera: Camera2D
var _darkness: CanvasModulate
var _shadow_layer: CanvasLayer
var _shadows: ShadowSystem
var _controls_bg: ColorRect
var _joystick: TouchJoystick
var _buttons := {}
var _settings: SettingsPanel
var _flash_box: HBoxContainer
var _flash_label: Label
var _win_panel: Control
var _win_stats: Label
var _next_button: Button
var _light_tween: Tween
var _spawn_point := Vector2.ZERO
var _checkpoint: Checkpoint
## True nei livelli più grandi dello schermo: la telecamera segue la lampadina.
var _follow := false


func _ready() -> void:
	_darkness = CanvasModulate.new()
	add_child(_darkness)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	# Le ombre solide stanno su un layer a parte, così il buio non le copre.
	_shadow_layer = CanvasLayer.new()
	_shadow_layer.layer = 1
	_shadow_layer.follow_viewport_enabled = true
	add_child(_shadow_layer)
	_shadows = ShadowSystem.new()
	_shadows.visual_layer = _shadow_layer
	add_child(_shadows)
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	load_level(Progress.selected_level)


func load_level(index: int) -> void:
	level_index = index
	won = false
	flash_count = 0
	if level:
		remove_child(level)
		level.queue_free()
	for platform in _shadow_layer.get_children():
		platform.queue_free()

	level = load(Progress.LEVELS[index]).instantiate()
	add_child(level)
	player = level.get_node("Player")
	goal = level.get_node("Goal")
	player.flashed.connect(_on_player_flashed)
	player.died.connect(_on_player_died)
	goal.reached.connect(_on_goal_reached)
	_spawn_point = player.global_position
	_checkpoint = null
	for checkpoint in get_tree().get_nodes_in_group("checkpoints"):
		checkpoint.reached.connect(_on_checkpoint_reached)
	_shadows.world = level
	_shadows.level_rect = level.level_rect
	_joystick.release()

	if _light_tween:
		_light_tween.kill()
	_darkness.color = DARK
	_win_panel.visible = false
	_settings.set_level(level.level_name)
	_update_flash_label()
	_layout()


func _process(delta: float) -> void:
	_buttons["flash"].set_progress(player.flash_charge())
	if Input.is_action_just_pressed("settings"):
		_open_settings()
		return
	if Input.is_action_just_pressed("menu"):
		go_to_menu()
		return
	if Input.is_action_just_pressed("restart"):
		load_level(level_index)
		return
	if _follow:
		_camera.position = _camera.position.lerp(_camera_target(), 1.0 - exp(-CAMERA_FOLLOW_SPEED * delta))


func _on_checkpoint_reached(checkpoint: Checkpoint) -> void:
	if _checkpoint:
		_checkpoint.active = false
	_checkpoint = checkpoint
	checkpoint.active = true
	Sfx.play("checkpoint", -4.0, 0.0)
	_spawn_point = checkpoint.spawn_position()


func _on_player_died() -> void:
	var dead_level := level
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if level != dead_level or won:
		return
	_shadows.clear()
	for box in get_tree().get_nodes_in_group("push_boxes"):
		box.reset()
	player.respawn(_spawn_point)
	if _follow:
		_camera.position = _camera_target()


func _on_player_flashed(origin: Vector2, radius: float) -> void:
	flash_count += 1
	_update_flash_label()
	_shadows.flash(origin, radius)


func _on_goal_reached() -> void:
	if won:
		return
	won = true
	var tween := player.enter_socket(goal.socket_position())
	await tween.finished
	Sfx.play("victory", 0.0, 0.0)
	Music.duck(1.6)
	_light_tween = create_tween()
	_light_tween.tween_property(_darkness, "color", LIT, 1.2)
	_light_tween.tween_callback(_show_win_panel)


func _show_win_panel() -> void:
	var last := level_index == Progress.LEVELS.size() - 1
	var best := Progress.best_flashes(level_index)
	Progress.complete_level(level_index, flash_count)
	_win_stats.text = "Flashes used: %d" % flash_count
	if best >= 0:
		_win_stats.text += "  ·  record: %d" % mini(best, flash_count)
	_next_button.text = "Play again" if last else "Next"
	_win_panel.visible = true


func _on_next_pressed() -> void:
	# Dopo l'ultimo livello il pulsante è "Play again".
	load_level(mini(level_index + 1, Progress.LEVELS.size() - 1))


## Apre le impostazioni e mette in pausa il gioco finché restano aperte.
func _open_settings() -> void:
	_joystick.release()
	get_tree().paused = true
	_settings.open()


func go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _notification(what: int) -> void:
	# Tasto "indietro" di Android: torna al menu.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _settings and _settings.handle_back():
			return
		go_to_menu()


func _update_flash_label() -> void:
	_flash_label.text = "%d" % flash_count


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	_controls_bg = ColorRect.new()
	_controls_bg.color = Color(0, 0, 0, 0.35)
	_controls_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_controls_bg)

	_joystick = TouchJoystick.new()
	hud.add_child(_joystick)

	for spec in [
		["jump", 125.0, "jump"],
		["flash", 105.0, "flash"],
		["settings", 56.0, "gear"],
	]:
		var button := TouchButton.new()
		# Il flash resta tondo, gli altri hanno la forma dei pulsanti del menu.
		button.setup(spec[0], spec[1], spec[2], false, spec[0] == "flash")
		hud.add_child(button)
		_buttons[spec[0]] = button

	# Contatore dei flash: fulmine (come nel menu) + numero.
	_flash_box = HBoxContainer.new()
	_flash_box.add_theme_constant_override("separation", 8)
	_flash_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_flash_box)
	var bolt := Control.new()
	bolt.custom_minimum_size = Vector2(48, 48)
	bolt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bolt.draw.connect(func() -> void: Icons.draw(bolt, "bolt", bolt.size / 2.0, 48.0))
	_flash_box.add_child(bolt)
	_flash_label = _make_label(_flash_box, 40)
	_flash_label.add_theme_color_override("font_color", UiStyle.ACCENT)

	_win_panel = Control.new()
	_win_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_panel.theme = UiStyle.button_theme()
	hud.add_child(_win_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 30)
	center.add_child(box)
	var title := _make_label(box, 72)
	title.text = "Level complete!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_stats = _make_label(box, 44)
	_win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	var menu_button := Button.new()
	menu_button.text = "Menu"
	menu_button.custom_minimum_size = Vector2(300, 130)
	menu_button.add_theme_font_size_override("font_size", 56)
	menu_button.pressed.connect(go_to_menu)
	row.add_child(menu_button)
	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(360, 130)
	_next_button.add_theme_font_size_override("font_size", 56)
	_next_button.pressed.connect(_on_next_pressed)
	row.add_child(_next_button)
	_win_panel.visible = false

	# Sopra a tutto, anche al pannello di vittoria; funziona col gioco in pausa.
	_settings = SettingsPanel.new()
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings.closed.connect(func() -> void: get_tree().paused = false)
	_settings.restart_requested.connect(func() -> void: load_level(level_index))
	_settings.home_requested.connect(go_to_menu)
	hud.add_child(_settings)


func _make_label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## Inquadra il livello nello spazio sopra i controlli e posiziona l'interfaccia.
## Con aspect "expand" i telefoni più allungati mostrano più spazio in verticale.
func _layout() -> void:
	if level == null:
		return
	var view := get_viewport().get_visible_rect().size
	var area := Vector2(view.x, view.y - CONTROLS_HEIGHT)
	var rect := level.level_rect
	var zoom := minf(area.x / rect.size.x, area.y / rect.size.y)
	# Livello più alto dello schermo: si adatta in larghezza e la telecamera
	# segue la lampadina.
	# Livelli più grandi dello schermo (più alti, o più larghi di 1080 px):
	# si mostra sempre una larghezza di 1080 px e la telecamera segue la
	# lampadina in entrambe le direzioni.
	var width := minf(rect.size.x, VIEW_WIDTH)
	_follow = rect.size.x > VIEW_WIDTH + 1.0 or rect.size.y * (area.x / width) > area.y + 1.0
	if _follow:
		zoom = area.x / width
	_camera.zoom = Vector2(zoom, zoom)
	var level_top := 0.0
	if _follow:
		_camera.position = _camera_target()
	else:
		# Il centro del livello va al centro dell'area sopra i controlli.
		_camera.position = rect.get_center() - (area / 2.0 - view / 2.0) / zoom
		level_top = (area.y - rect.size.y * zoom) / 2.0
	_controls_bg.position = Vector2(0, area.y)
	_controls_bg.size = Vector2(view.x, CONTROLS_HEIGHT)
	var row := area.y + CONTROLS_HEIGHT / 2.0
	# Joystick: tutta la metà sinistra dello schermo, anche sopra il livello.
	_joystick.zone = Rect2(0, level_top + 160, view.x / 2.0, view.y - level_top - 160)
	_joystick.rest_position = Vector2(220, row)
	_joystick.queue_redraw()
	_buttons["jump"].set_center(Vector2(view.x - 160, row + 20))
	_buttons["flash"].set_center(Vector2(view.x - 410, row + 50))
	_buttons["settings"].set_center(Vector2(view.x - 80, level_top + 80))
	_flash_box.position = Vector2(40, level_top + 52)


## Posizione della telecamera che tiene la lampadina al centro dell'area di
## gioco (sopra i controlli) senza mostrare oltre i bordi del livello.
func _camera_target() -> Vector2:
	var view := get_viewport().get_visible_rect().size / _camera.zoom
	var controls := CONTROLS_HEIGHT / _camera.zoom.y
	var rect := level.level_rect
	var target := player.global_position + Vector2(0, controls / 2.0)
	target.x = clampf(target.x, rect.position.x + view.x / 2.0, maxf(rect.position.x + view.x / 2.0, rect.end.x - view.x / 2.0))
	target.y = clampf(target.y, rect.position.y + view.y / 2.0, rect.end.y + controls - view.y / 2.0)
	return target
