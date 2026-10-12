class_name TouchButton
extends TouchScreenButton
## Pulsante touch con icona disegnata (supporta il multitouch).
## Stessa forma dei pulsanti del menu (riquadro con angoli arrotondati di
## UiStyle.box()), oppure tondo se creato con is_round = true.

## Opacità della scheda: i pulsanti in alto stanno sopra il livello.
const FILL_ALPHA := 0.85
const COOLDOWN_SHADE := Color(0, 0, 0, 0.6)
const COOLDOWN_RING := Color(1, 0.88, 0.4, 0.9)
## Pulsazioni al secondo e ingrandimento massimo quando pulsa.
const PULSE_RATE := 1.2
const PULSE_SCALE := 0.12

## Metà del lato del riquadro (o raggio, se tondo).
var radius := 100.0
var circular := false
var icon := ""
## Ricarica del pulsante (1 = pronto). Sotto 1 il pulsante appare scarico.
var progress := 1.0
## Se true il pulsante pulsa con un'onda che si allarga, per suggerire di
## usarlo (es. nel tutorial).
var pulsing := false:
	set(value):
		if value == pulsing:
			return
		pulsing = value
		_pulse_time = 0.0
		scale = Vector2.ONE
		queue_redraw()
var _pulse_time := 0.0
var _icon: Node2D
var _normal_box: StyleBoxFlat
var _pressed_box: StyleBoxFlat


func setup(action_name: StringName, button_radius: float, icon_name: String, slide_to_press := false, is_round := false) -> void:
	action = action_name
	circular = is_round
	radius = button_radius
	icon = icon_name
	passby_press = slide_to_press
	# Stessi colori e forma dei pulsanti del menu (scheda scura, bordo ambrato).
	var fill := Color(UiStyle.CARD, FILL_ALPHA)
	_normal_box = _box(fill, UiStyle.ACCENT.darkened(0.5))
	_pressed_box = _box(fill.lightened(0.15), UiStyle.ACCENT)
	if circular:
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape = circle
	else:
		var square := RectangleShape2D.new()
		square.size = Vector2(radius, radius) * 2.0
		shape = square
	pressed.connect(queue_redraw)
	released.connect(queue_redraw)
	# Senza texture la forma è centrata sull'origine: il nodo sta al centro
	# del pulsante e il riquadro si disegna attorno.
	_icon = Node2D.new()
	_icon.draw.connect(_draw_icon)
	add_child(_icon)


func _process(delta: float) -> void:
	if not pulsing:
		return
	_pulse_time += delta
	scale = Vector2.ONE * (1.0 + PULSE_SCALE * (0.5 - 0.5 * cos(_pulse_time * TAU * PULSE_RATE)))
	queue_redraw()


func _draw() -> void:
	var box := _pressed_box if is_pressed() else _normal_box
	draw_style_box(box, Rect2(-radius, -radius, radius * 2.0, radius * 2.0))
	if pulsing:
		# Onda che parte dal bordo, si allarga e svanisce.
		var phase := fmod(_pulse_time * PULSE_RATE, 1.0)
		var ring := Color(UiStyle.ACCENT, 0.9 * (1.0 - phase))
		var grow := 8.0 + 40.0 * phase
		if circular:
			draw_arc(Vector2.ZERO, radius + grow, 0.0, TAU, 64, ring, 6.0, true)
		else:
			var r := radius + grow
			draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), ring, false, 6.0)


## Scheda di UiStyle; se tonda gli angoli diventano mezzo lato (un cerchio).
func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var result := UiStyle.box(fill, border)
	if circular:
		result.set_corner_radius_all(ceili(radius))
		result.corner_detail = 32
	return result


func set_center(center: Vector2) -> void:
	position = center


## Aggiorna la ricarica; quando torna pronto l'icona fa un piccolo "pop".
func set_progress(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	# Quasi pieno conta come pronto: il residuo float del cooldown (es. 0.99999)
	# altrimenti bloccherebbe il pulsante "scarico" per sempre.
	if is_equal_approx(value, 1.0):
		value = 1.0
	if value == progress or (value < 1.0 and is_equal_approx(value, progress)):
		return
	if value >= 1.0 and progress < 1.0:
		_icon.scale = Vector2(1.35, 1.35)
		_icon.create_tween().tween_property(_icon, "scale", Vector2.ONE, 0.25) 				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	progress = value
	_icon.queue_redraw()


func _draw_icon() -> void:
	var color := UiStyle.TEXT
	var r := radius * 0.4
	match icon:
		"jump":
			_icon.draw_colored_polygon(PackedVector2Array([
				Vector2(0, -r), Vector2(r * 0.9, 0), Vector2(-r * 0.9, 0)
			]), color)
			_icon.draw_rect(Rect2(-r * 0.3, 0, r * 0.6, r * 0.9), color)
		"flash":
			var bolt := PackedVector2Array([
				Vector2(0.2, -1.1), Vector2(-0.6, 0.15), Vector2(-0.05, 0.15),
				Vector2(-0.25, 1.1), Vector2(0.6, -0.2), Vector2(0.05, -0.2)
			])
			for i in bolt.size():
				bolt[i] *= r
			_icon.draw_colored_polygon(bolt, UiStyle.ACCENT)
		"gear":
			Icons.draw(_icon, "gear", Vector2.ZERO, r * 2.3)
	# In ricarica: velo scuro sopra l'icona e anello che si riempie.
	if progress < 1.0:
		var shade := _box(COOLDOWN_SHADE, Color.TRANSPARENT)
		shade.set_border_width_all(0)
		_icon.draw_style_box(shade, Rect2(-radius, -radius, radius * 2.0, radius * 2.0))
		_icon.draw_arc(Vector2.ZERO, radius - 10.0, -PI / 2.0, -PI / 2.0 + TAU * progress,
				48, COOLDOWN_RING, 8.0, true)
