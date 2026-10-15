class_name LoadingScreen
extends Control
## Schermata nera che copre il livello mentre si carica: la scena si legge in
## un thread e i primi frame (compilazione degli shader, sfondi in texture,
## prewarm) avvengono qui sotto, a gioco fermo, invece che mentre si gioca.

## Secondi della dissolvenza in uscita.
const FADE_TIME := 0.25

var _label: Label
var _bolt: Control
var _time := 0.0
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Blocca i tocchi sui comandi finché il livello non è pronto.
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var background := ColorRect.new()
	background.color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	_bolt = Control.new()
	_bolt.custom_minimum_size = Vector2(96, 96)
	_bolt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bolt.draw.connect(func() -> void: Icons.draw(_bolt, "bolt", _bolt.size / 2.0, 96.0))
	box.add_child(_bolt)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 44)
	_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.custom_minimum_size = Vector2(260, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label)
	_update_text()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_bolt.modulate.a = 0.55 + 0.45 * sin(_time * 4.0)
	_update_text()


func _update_text() -> void:
	_label.text = "Loading" + ".".repeat(int(_time * 3.0) % 4)


## Copre subito lo schermo, senza dissolvenza.
func show_now() -> void:
	if _tween:
		_tween.kill()
	modulate.a = 1.0
	_time = 0.0
	visible = true


## Dissolvenza in uscita, poi si nasconde.
func fade_out() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(hide)
