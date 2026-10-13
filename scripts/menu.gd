extends Control
## Menu iniziale: titolo, lampadina animata, "Gioca" e selezione dei livelli.

const GAME_SCENE := "res://scenes/game.tscn"
const BACKGROUND := Color(0.05, 0.05, 0.08)
## Raggio (px) attorno alla lampadina entro cui un tocco la fa lampeggiare.
const BULB_TAP_RADIUS := 140.0
## Raggio del tocco sulle mini lampadine (hanno la precedenza sulla grande).
const MINI_TAP_RADIUS := 70.0
const BULB_SCALE := Vector2(2.2, 2.2)
## Distanza orizzontale dal centro della prima mini lampadina e tra le altre.
const MINI_FIRST_X := 210.0
const MINI_STEP_X := 130.0
const MINIS_PER_ROW := 6
const GLOW := Color(1.0, 0.78, 0.45, 0.28)
const GLOW_SIZE := 1100.0
## Lato del pulsante ingranaggio (impostazioni) e distanza dai bordi.
const GEAR_SIZE := 130.0
const GEAR_MARGIN := 40.0
## Spostamento (px) della lista oltre il quale un tocco su un livello è uno scorrimento.
const SCROLL_TAP_SLOP := 12.0

var _bulb: Player
var _minis: Array[MiniBulbSprite] = []
var _glow: TextureRect
var _spacer: Control
var _settings: SettingsPanel
var _gear: Button
var _scroll: ScrollContainer
var _scroll_at_press := 0.0
var _bulb_home := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	theme = UiStyle.button_theme()

	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)

	# Alone caldo dietro la lampadina.
	_glow = TextureRect.new()
	_glow.texture = LevelKit.light_texture()
	_glow.modulate = GLOW
	_glow.size = Vector2(GLOW_SIZE, GLOW_SIZE)
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)

	# La lampadina del gioco, ferma e ingrandita: la sua luce illumina il menu.
	_bulb = Player.new()
	_bulb.scale = BULB_SCALE
	add_child(_bulb)
	_bulb.set_physics_process(false)
	_bulb.controls_enabled = false

	# Le mini lampadine trovate nei livelli, ai lati di quella grande.
	var found := Progress.mini_bulbs()
	for id in found:
		var mini := MiniBulbSprite.new()
		mini.color = found[id]
		mini.scale = BULB_SCALE
		add_child(mini)
		_minis.append(mini)

	var column := VBoxContainer.new()
	column.set_anchors_preset(PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 28)
	add_child(column)

	_spacer = Control.new()
	column.add_child(_spacer)
	column.add_child(_label("BULB & SHADE", 120, UiStyle.ACCENT))
	column.add_child(_label("Light the way", 44, UiStyle.TEXT_DIM))

	# Primo avvio: solo "Play", che fa partire il tutorial; la lista dei
	# livelli compare quando il tutorial è finito.
	var tutorial := Progress.needs_tutorial()
	var play := Button.new()
	var next := Progress.TUTORIAL if tutorial else Progress.next_level()
	play.text = "Play" if tutorial or (next == 0 and not Progress.is_completed(0)) else "Continue · level %d" % (next + 1)
	play.custom_minimum_size = Vector2(620, 150)
	play.add_theme_font_size_override("font_size", 60)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_start_level.bind(next))
	column.add_child(play)

	if tutorial:
		# Tiene la firma in fondo come quando c'è la lista.
		var filler := Control.new()
		filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(filler)
	else:
		_add_level_list(column)

	# Firma in fondo, con un piccolo margine dal bordo inferiore.
	var credits := _label("made with love by jcosmick", 26, UiStyle.TEXT_DIM.darkened(0.2))
	column.add_child(credits)
	var bottom_margin := Control.new()
	bottom_margin.custom_minimum_size = Vector2(0, 4)
	column.add_child(bottom_margin)

	# Ingranaggio in alto a destra: apre le impostazioni (aggiunto dopo la
	# griglia, così i pulsanti dei livelli restano i primi nell'albero).
	var gear := Button.new()
	gear.custom_minimum_size = Vector2(GEAR_SIZE, GEAR_SIZE)
	gear.size = gear.custom_minimum_size
	gear.tooltip_text = "Settings"
	var gear_icon := _icon("gear", GEAR_SIZE * 0.62)
	gear_icon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	gear.add_child(gear_icon)
	gear.pressed.connect(func() -> void: _settings.open())
	add_child(gear)
	_gear = gear

	_settings = SettingsPanel.new()
	add_child(_settings)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_time += delta
	_bulb.position = _bulb_home + Vector2(0, sin(_time * 1.6) * 14.0)
	_glow.modulate.a = GLOW.a * (0.85 + 0.15 * sin(_time * 1.6))
	for i in _minis.size():
		_minis[i].position = _mini_home(i) + Vector2(0, sin(_time * 2.2 + i * 1.3) * 8.0)


func _input(event: InputEvent) -> void:
	# Toccando la lampadina parte il flash (anche col mouse, emulato come tocco).
	var touch := event as InputEventScreenTouch
	if not touch or not touch.pressed:
		return
	# Con le impostazioni aperte i tocchi vanno solo al pannello.
	if _settings.visible:
		return
	for mini in _minis:
		if touch.position.distance_to(mini.position) <= MINI_TAP_RADIUS:
			mini.flash()
			return
	if touch.position.distance_to(_bulb.light_origin()) <= BULB_TAP_RADIUS:
		_bulb.try_flash(true)


## Posto della mini lampadina "index": alternate a sinistra e a destra della
## grande, con la base alla stessa altezza; dopo 6 si riparte una fila sopra.
func _mini_home(index: int) -> Vector2:
	var slot := index % MINIS_PER_ROW
	var row := floorf(index / float(MINIS_PER_ROW))
	var side := -1.0 if slot % 2 == 0 else 1.0
	var x := side * (MINI_FIRST_X + MINI_STEP_X * floorf(slot / 2.0))
	var feet_y := (52.0 - MiniBulbSprite.FEET) * BULB_SCALE.y
	return _bulb_home + Vector2(x, feet_y - row * 170.0)


func _notification(what: int) -> void:
	# Tasto "indietro" di Android dal menu: chiude le impostazioni se sono
	# aperte, altrimenti chiude il gioco.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _settings and _settings.handle_back():
			return
		get_tree().quit()


func _layout() -> void:
	# Sui telefoni più lunghi tutto scende un po', per non lasciare il vuoto in basso.
	var view := get_viewport().get_visible_rect().size
	var top := maxf(0.0, (view.y - 1920.0) / 2.0)
	_gear.position = Vector2(view.x - GEAR_SIZE - GEAR_MARGIN, GEAR_MARGIN)
	_bulb_home = Vector2(view.x / 2.0, top + 380)
	_glow.position = _bulb_home + Vector2(0, -60) - _glow.size / 2.0
	_spacer.custom_minimum_size = Vector2(0, top + 660)


func _start_level(index: int) -> void:
	Progress.selected_level = index
	get_tree().change_scene_to_file(GAME_SCENE)


func _add_level_list(column: VBoxContainer) -> void:
	column.add_child(_label("Levels", 48, UiStyle.TEXT))
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 30)
	center.add_child(grid)
	for i in Progress.LEVELS.size():
		grid.add_child(_level_card(i))


## Avvia il livello solo se è stato un tocco e non uno scorrimento della lista.
func _on_card_pressed(index: int) -> void:
	if absf(_scroll.scroll_vertical - _scroll_at_press) > SCROLL_TAP_SLOP:
		return
	_start_level(index)


func _level_card(index: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(300, 340)
	var unlocked := Progress.is_unlocked(index)
	card.disabled = not unlocked
	# PASS: il trascinamento col dito arriva anche alla ScrollContainer.
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	if unlocked:
		card.button_down.connect(func() -> void: _scroll_at_press = _scroll.scroll_vertical)
		card.pressed.connect(_on_card_pressed.bind(index))
	var info := _level_info(index)

	var content := VBoxContainer.new()
	content.set_anchors_preset(PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	var color := UiStyle.TEXT if unlocked else UiStyle.TEXT_DIM.darkened(0.3)
	content.add_child(_label("%d" % (index + 1), 34, UiStyle.ACCENT if unlocked else color))
	content.add_child(_icon("lock" if not unlocked else info.icon, 130.0))
	content.add_child(_label(info.name if unlocked else "Locked", 34, color))

	# Riga del record: fulmine + minor numero di flash (vuota se non completato).
	var record := HBoxContainer.new()
	record.alignment = BoxContainer.ALIGNMENT_CENTER
	record.custom_minimum_size = Vector2(0, 44)
	record.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Progress.is_completed(index):
		record.add_child(_icon("bolt", 40.0))
		record.add_child(_label("%d" % Progress.best_flashes(index), 34, UiStyle.ACCENT))
	content.add_child(record)
	return card


func _icon(icon: String, size: float) -> Control:
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(size, size)
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(func() -> void: Icons.draw(canvas, icon, canvas.size / 2.0, size))
	return canvas


## Nome (senza il numero iniziale) e icona del livello.
func _level_info(index: int) -> Dictionary:
	var level: Level = load(Progress.LEVELS[index]).instantiate()
	var parts := level.level_name.split("·", false, 1)
	var info := {"name": parts[parts.size() - 1].strip_edges(), "icon": level.icon}
	level.free()
	return info


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

