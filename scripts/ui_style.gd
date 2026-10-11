class_name UiStyle
extends RefCounted
## Colori e stile dei pulsanti condivisi da menu, impostazioni e interfaccia di gioco.

const TEXT := Color(1.0, 0.95, 0.85)
const TEXT_DIM := Color(0.6, 0.58, 0.55)
const ACCENT := Color(1.0, 0.82, 0.45)
const CARD := Color(0.13, 0.12, 0.16)
const CARD_LOCKED := Color(0.08, 0.08, 0.1)


## Tema dei pulsanti: scheda scura con bordo ambrato che si accende al tocco.
static func button_theme() -> Theme:
	var result := Theme.new()
	result.set_stylebox("normal", "Button", box(CARD, ACCENT.darkened(0.5)))
	result.set_stylebox("hover", "Button", box(CARD.lightened(0.08), ACCENT))
	result.set_stylebox("pressed", "Button", box(CARD.lightened(0.15), ACCENT))
	result.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	result.set_stylebox("disabled", "Button", box(CARD_LOCKED, CARD))
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_color("font_pressed_color", "Button", ACCENT)
	result.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.3))
	return result


static func box(fill: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(4)
	result.set_corner_radius_all(28)
	result.set_content_margin_all(20)
	return result
