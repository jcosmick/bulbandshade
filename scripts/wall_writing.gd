@tool
class_name WallWriting
extends Node2D
## Scritta sul muro, solo decorativa: testo scarabocchiato, tacche per
## contare i giorni o una freccia. Con flash_only è vernice fosforescente:
## invisibile finché un flash non la raggiunge, poi brilla nel buio e svanisce
## piano. L'origine è il centro della scritta.
## Idee per il testo: "LIGHTS OUT", "STAY DARK", "DON'T LOOK BACK",
## "THEY ALL BURNED OUT", "WHO TURNED YOU ON?", "YOU'RE NOT THE FIRST",
## "NOT ALONE", "KEEP SHINING", "HELP".

@export_enum("text", "tally", "arrow") var kind := "text":
	set(value):
		kind = value
		queue_redraw()
@export_multiline var text := "LIGHTS OUT":
	set(value):
		text = value
		queue_redraw()
## "chalk" gesso grigio, "paint" vernice rossa che cola, "scratch" graffi incisi.
@export_enum("chalk", "paint", "scratch") var style := "chalk":
	set(value):
		style = value
		queue_redraw()
@export_range(16, 120) var font_size := 44:
	set(value):
		font_size = value
		queue_redraw()
## Tacche: quante (a gruppi di cinque, l'ultima sbarra le altre quattro).
@export_range(1, 60) var tally := 17:
	set(value):
		tally = value
		queue_redraw()
## Inclinazione in gradi.
@export_range(-45.0, 45.0, 1.0) var tilt := -4.0:
	set(value):
		tilt = value
		queue_redraw()
## Si vede solo dopo un flash, poi svanisce in `glow_time` secondi.
@export var flash_only := false:
	set(value):
		flash_only = value
		queue_redraw()
@export var glow_time := 3.5
## Cambialo per un tremolio diverso delle lettere.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()

const COLORS := {
	"chalk": Color(0.62, 0.6, 0.58, 0.85),
	"paint": Color(0.45, 0.08, 0.07, 0.9),
	"scratch": Color(0.16, 0.14, 0.18, 0.9),
}
## Vernice fosforescente (flash_only): verdina come quella degli orologi.
const GLOW := Color(0.6, 1.0, 0.7)
const SCRATCH_EDGE := Color(0.5, 0.47, 0.52, 0.5)

var _visual: Node2D
var _alpha := 1.0
var _tween: Tween


func _ready() -> void:
	z_index = -9
	if Engine.is_editor_hint() or not flash_only:
		return
	_alpha = 0.0
	_visual = LevelKit.make_overlay(self)
	_visual.draw.connect(func() -> void: _draw_writing(_visual, GLOW))
	var player := LevelKit.find_player(self)
	if player:
		player.flashed.connect(_on_flashed)


func _on_flashed(origin: Vector2, radius: float) -> void:
	if origin.distance_to(global_position) > radius:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_alpha, _alpha, 1.0, 0.15)
	_tween.tween_method(_set_alpha, 1.0, 0.0, glow_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _set_alpha(value: float) -> void:
	_alpha = value
	_visual.queue_redraw()


func _draw() -> void:
	if not flash_only:
		_draw_writing(self, COLORS[style])
	elif Engine.is_editor_hint():
		# Nell'editor si vede, tenue, per poterla posizionare.
		_alpha = 0.45
		_draw_writing(self, GLOW)


func _draw_writing(item: CanvasItem, ink: Color) -> void:
	if _alpha <= 0.0:
		return
	ink = Color(ink, ink.a * _alpha)
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	item.draw_set_transform(Vector2.ZERO, deg_to_rad(tilt))
	match kind:
		"text":
			_draw_text(item, rng, ink)
		"tally":
			_draw_tally(item, rng, ink)
		"arrow":
			_draw_arrow(item, rng, ink)
	item.draw_set_transform_matrix(Transform2D.IDENTITY)


## Lettere una per una, ognuna un po' storta e fuori riga, come scritte a mano.
func _draw_text(item: CanvasItem, rng: RandomNumberGenerator, ink: Color) -> void:
	var font := ThemeDB.fallback_font
	var lines := text.split("\n")
	var line_height := font_size * 1.1
	var base_rotation := deg_to_rad(tilt)
	for l in lines.size():
		var line := lines[l]
		var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := -width / 2.0
		var y := (l - (lines.size() - 1) / 2.0) * line_height + font_size * 0.35
		for c in line.length():
			var ch := line[c]
			var advance := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var jitter := Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-3.0, 3.0))
			var spin := rng.randf_range(-0.12, 0.12)
			var at := Vector2(x, y) + jitter
			var xform := Transform2D(base_rotation, Vector2.ZERO) * Transform2D(spin, at)
			item.draw_set_transform_matrix(xform)
			if style == "scratch":
				item.draw_char(font, Vector2(1.5, 1.5), ch, font_size, SCRATCH_EDGE)
			item.draw_char(font, Vector2.ZERO, ch, font_size, ink)
			if style == "paint" and ch != " " and rng.randf() < 0.35:
				# Colatura di vernice sotto la lettera.
				var drip := Vector2(advance * rng.randf_range(0.2, 0.8), 0)
				var length := rng.randf_range(8, 26)
				item.draw_line(drip, drip + Vector2(0, length), ink, 3.0)
				item.draw_circle(drip + Vector2(0, length), 2.5, ink)
			x += advance
	item.draw_set_transform(Vector2.ZERO, base_rotation)


## Tacche a gruppi di cinque: quattro dritte e una che le sbarra.
func _draw_tally(item: CanvasItem, rng: RandomNumberGenerator, ink: Color) -> void:
	var h := font_size * 1.0
	var step := font_size * 0.28
	var group_gap := font_size * 0.5
	var groups := ceili(tally / 5.0)
	var total := groups * (4 * step + group_gap) - group_gap
	var x := -total / 2.0
	var width := 3.0 if style == "paint" else 2.5
	for g in groups:
		var in_group := mini(5, tally - g * 5)
		var start := x
		for i in mini(in_group, 4):
			var top := Vector2(x + rng.randf_range(-2, 2), -h / 2.0 + rng.randf_range(-3, 3))
			item.draw_line(top, Vector2(x + rng.randf_range(-2, 2), h / 2.0 + rng.randf_range(-3, 3)), ink, width)
			x += step
		if in_group == 5:
			item.draw_line(Vector2(start - step * 0.6, h * 0.3), Vector2(x - step * 0.4, -h * 0.3), ink, width)
		x += group_gap


func _draw_arrow(item: CanvasItem, rng: RandomNumberGenerator, ink: Color) -> void:
	var length := font_size * 2.5
	var width := 4.0 if style == "paint" else 3.0
	var points := PackedVector2Array()
	for i in 6:
		points.append(Vector2(lerpf(-length / 2.0, length / 2.0, i / 5.0), rng.randf_range(-3, 3)))
	item.draw_polyline(points, ink, width)
	var tip := points[points.size() - 1]
	item.draw_line(tip, tip + Vector2(-font_size * 0.5, -font_size * 0.35), ink, width)
	item.draw_line(tip, tip + Vector2(-font_size * 0.5, font_size * 0.4), ink, width)
