class_name SettingsPanel
extends Control
## Pannello "Impostazioni" in sovrimpressione: velo scuro, scheda centrata con i
## cursori del volume (effetti e musica) e il pulsante "Chiudi" (solo icona).
## Si apre con open() e parte nascosto; i cursori cambiano subito il volume e lo salvano.
## In gioco set_level() mostra in alto il nome del livello e i pulsanti per
## tornare al menu e ricominciare il livello.

signal closed
## Premuto "Ricomincia": il pannello si è già chiuso.
signal restart_requested
## Premuto "Menu": il pannello si è già chiuso.
signal home_requested

const TRACK := Color(0.06, 0.06, 0.08)
const SHADE := Color(0, 0, 0, 0.6)
## Diametro (px) del pomello dei cursori e spessore della loro guida.
const GRABBER_SIZE := 72
const TRACK_THICKNESS := 18
const SLIDER_HEIGHT := 96.0
## Larghezza della scheda centrale.
const CARD_WIDTH := 840.0

var _sfx_slider: HSlider
var _music_slider: HSlider
var _level_label: Label
var _restart_button: Button
var _home_button: Button


func _ready() -> void:
	# Anche gli offset vanno azzerati: con le sole ancore il pannello non
	# coprirebbe lo schermo e la scheda finirebbe decentrata.
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = _make_theme()
	# Il pannello blocca i tocchi diretti agli elementi sotto di lui.
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	card.add_child(box)

	_level_label = _label("", 44, UiStyle.TEXT_DIM)
	_level_label.visible = false
	box.add_child(_level_label)
	box.add_child(_label("Settings", 72, UiStyle.ACCENT))
	var line := ColorRect.new()
	line.color = UiStyle.ACCENT.darkened(0.6)
	line.custom_minimum_size = Vector2(0, 3)
	box.add_child(line)
	box.add_child(_spacer(16))
	_sfx_slider = _volume_row(box, "Sound effects", Settings.sfx_volume, Settings.set_sfx_volume)
	box.add_child(_spacer(24))
	_music_slider = _volume_row(box, "Music", Settings.music_volume, Settings.set_music_volume)
	box.add_child(_spacer(40))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 28)
	box.add_child(buttons)
	_home_button = _button("home", _on_home_pressed)
	_home_button.visible = false
	buttons.add_child(_home_button)
	_restart_button = _button("restart", _on_restart_pressed)
	_restart_button.visible = false
	buttons.add_child(_restart_button)
	buttons.add_child(_button("close", close))

	visible = false


func open() -> void:
	# Riallinea cursori e percentuali ai valori salvati.
	_sfx_slider.value = Settings.sfx_volume
	_music_slider.value = Settings.music_volume
	visible = true


## Mostra in alto il nome del livello e i pulsanti "Menu" e "Ricomincia".
func set_level(title: String) -> void:
	_level_label.text = title
	_level_label.visible = true
	_home_button.visible = true
	_restart_button.visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Da chiamare col tasto "indietro": chiude il pannello se è aperto.
## Restituisce true se il tasto è stato usato.
func handle_back() -> bool:
	if not visible:
		return false
	close()
	return true


func _on_restart_pressed() -> void:
	close()
	restart_requested.emit()


func _on_home_pressed() -> void:
	close()
	home_requested.emit()


## Pulsante quadrato con sola icona (vedi Icons).
func _button(icon: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 130)
	button.pressed.connect(on_press)
	var drawing := Control.new()
	drawing.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawing.draw.connect(func() -> void: Icons.draw(drawing, icon, drawing.size / 2.0, 80.0))
	button.add_child(drawing)
	return button


## Riga con nome e percentuale, e sotto il cursore a tutta larghezza.
func _volume_row(parent: Control, title: String, value: float, on_change: Callable) -> HSlider:
	var header := HBoxContainer.new()
	parent.add_child(header)
	var name_label := _label(title, 46, UiStyle.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var percent := _label("", 46, UiStyle.ACCENT)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(percent)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(0, SLIDER_HEIGHT)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(on_change)
	slider.value_changed.connect(func(v: float) -> void: percent.text = "%d%%" % roundi(v * 100.0))
	slider.value = value
	percent.text = "%d%%" % roundi(value * 100.0)
	parent.add_child(slider)
	return slider


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _make_theme() -> Theme:
	var result := UiStyle.button_theme()
	var card := UiStyle.box(UiStyle.CARD, UiStyle.ACCENT.darkened(0.3))
	card.set_content_margin_all(56)
	result.set_stylebox("panel", "PanelContainer", card)

	# Cursori: guida scura, parte piena color accento, pomello tondo e grande.
	result.set_stylebox("slider", "HSlider", _track(TRACK))
	result.set_stylebox("grabber_area", "HSlider", _track(UiStyle.ACCENT.darkened(0.15)))
	result.set_stylebox("grabber_area_highlight", "HSlider", _track(UiStyle.ACCENT))
	result.set_icon("grabber", "HSlider", _circle(UiStyle.ACCENT))
	result.set_icon("grabber_highlight", "HSlider", _circle(UiStyle.ACCENT.lightened(0.3)))
	result.set_icon("grabber_disabled", "HSlider", _circle(UiStyle.TEXT_DIM))
	result.set_constant("center_grabber", "HSlider", 1)
	return result


static func _track(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(ceili(TRACK_THICKNESS / 2.0))
	box.content_margin_top = TRACK_THICKNESS / 2.0
	box.content_margin_bottom = TRACK_THICKNESS / 2.0
	return box


## Cerchio pieno con bordo sfumato (antialias) usato come pomello.
static func _circle(color: Color) -> ImageTexture:
	var image := Image.create_empty(GRABBER_SIZE, GRABBER_SIZE, false, Image.FORMAT_RGBA8)
	var radius := GRABBER_SIZE / 2.0
	var middle := Vector2(radius, radius)
	for y in GRABBER_SIZE:
		for x in GRABBER_SIZE:
			var distance := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(middle)
			var alpha := clampf(radius - 1.0 - distance, 0.0, 1.0)
			# Anello più chiaro sul bordo, per staccare il pomello dalla guida.
			var tint := color.lightened(0.35) if distance > radius - 7.0 else color
			image.set_pixel(x, y, Color(tint, alpha))
	return ImageTexture.create_from_image(image)
