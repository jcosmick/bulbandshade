extends Node2D
## Immagini per la pagina itch.io (solo sviluppo): banner, sfondo e sfondo dell'embed.
## Uso: Godot --path . --resolution <L>x<A> res://tests/itch_art.tscn -- --kind=banner|background|embed --out=<file.png>
## Risoluzioni: banner 960x320, background 1920x1080, embed 540x960.

const ROOM := preload("res://scripts/room_background.gd")
const PAGE_BG := Color(0.02, 0.02, 0.035)
const MINIS := [Color(1, 0.33, 0.36), Color(0.3, 0.9, 0.4)]

var kind := "banner"
var out_path := "user://itch_art.png"
var view := Vector2.ZERO
## Casse da disegnare: [centro, lato] e la luce che proietta le loro ombre.
var _crates: Array = []
var _light := Vector2.ZERO
var _floor_y := 0.0
var _fade := true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--kind="):
			kind = arg.trim_prefix("--kind=")
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	view = get_viewport().get_visible_rect().size
	RenderingServer.set_default_clear_color(PAGE_BG)
	var darkness := CanvasModulate.new()
	darkness.color = Color(0.11, 0.11, 0.17)
	add_child(darkness)
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	match kind:
		"banner":
			_floor_y = 270.0
			_add_bulb(Vector2(150, _floor_y), 1.3, 900.0)
			_crates = [[Vector2(330, _floor_y - 50), 100.0]]
			_add_mini(Vector2(55, _floor_y), 0, 1.3)
			var title := _label("BULB & SHADE", 76, UiStyle.ACCENT, ui)
			title.position = Vector2(400, 80)
			title.size.x = 540
			var subtitle := _label("Light the way", 32, UiStyle.TEXT_DIM, ui)
			subtitle.position = Vector2(400, 180)
			subtitle.size.x = 540
		"background":
			_floor_y = 900.0
			_add_bulb(Vector2(190, _floor_y), 1.6, 1100.0)
			_crates = [[Vector2(380, _floor_y - 60), 120.0], [Vector2(1650, _floor_y - 70), 140.0]]
			_add_mini(Vector2(1780, _floor_y), 1, 1.6)
		"embed":
			_floor_y = 0.0
			_fade = false
			var home := Vector2(view.x / 2.0, 270)
			var glow := TextureRect.new()
			glow.texture = LevelKit.light_texture()
			glow.modulate = Color(1.0, 0.78, 0.45, 0.30)
			glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			glow.size = Vector2(700, 700)
			glow.position = home + Vector2(0, -40) - glow.size / 2.0
			ui.add_child(glow)
			var bulb := _make_bulb(1.7)
			bulb.position = home
			ui.add_child(bulb)
			for i in MINIS.size():
				var mini := MiniBulbSprite.new()
				mini.color = MINIS[i]
				mini.scale = Vector2(1.7, 1.7)
				mini.position = home + Vector2((-1 if i == 0 else 1) * 150.0, (52.0 - MiniBulbSprite.FEET) * 1.7)
				ui.add_child(mini)
			var title := _label("BULB & SHADE", 66, UiStyle.ACCENT, ui)
			title.position = Vector2(0, view.y - 250)
			var subtitle := _label("Light the way", 28, UiStyle.TEXT_DIM, ui)
			subtitle.position = Vector2(0, view.y - 160)
	queue_redraw()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	get_tree().quit()


func _draw() -> void:
	if kind == "embed":
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.05, 0.05, 0.08))
		return
	# Parete a righe e zoccolatura, come nelle stanze del gioco.
	draw_rect(Rect2(Vector2.ZERO, view), ROOM.WALL)
	var x := 0.0
	while x < view.x:
		draw_rect(Rect2(x, 0, ROOM.STRIPE_STEP / 2.0, _floor_y - 150.0), ROOM.STRIPE)
		x += ROOM.STRIPE_STEP
	draw_rect(Rect2(0, _floor_y - 150.0, view.x, 150.0), ROOM.PANEL)
	draw_rect(Rect2(0, _floor_y - 156.0, view.x, 12.0), ROOM.MOLDING)
	draw_rect(Rect2(0, _floor_y, view.x, view.y - _floor_y), LevelKit.TERRAIN)
	draw_rect(Rect2(0, _floor_y, view.x, 6.0), LevelKit.TERRAIN_EDGE)
	for crate in _crates:
		_draw_shadow(crate[0], crate[1])
	if kind == "background":
		var top := Color(PAGE_BG, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, view.y - 140), Vector2(view.x, view.y - 140), view, Vector2(0, view.y)]),
			PackedColorArray([top, top, PAGE_BG, PAGE_BG]))
	for crate in _crates:
		draw_set_transform(crate[0])
		LevelKit.draw_crate(self, Vector2(crate[1], crate[1]), false)
		draw_set_transform(Vector2.ZERO)


## Ombra solida della cassa: il lato lontano dalla luce, proiettato all'indietro.
func _draw_shadow(center: Vector2, side: float) -> void:
	var half := side / 2.0
	var away := signf(center.x - _light.x)
	var near_top := center + Vector2(-away * half, -half)
	var far_bottom := center + Vector2(away * half, half)
	var length := 260.0 + side
	var tip := near_top + (near_top - _light).normalized() * length
	var foot := far_bottom + Vector2(away * length * 0.9, 0)
	draw_colored_polygon(PackedVector2Array([near_top, tip, Vector2(tip.x, far_bottom.y), foot, far_bottom]), Color.BLACK)


func _add_bulb(feet: Vector2, bulb_scale: float, radius: float) -> void:
	var bulb := _make_bulb(bulb_scale)
	bulb.position = feet - Vector2(0, 52.0 * bulb_scale)
	add_child(bulb)
	_light = bulb.position + Player.LIGHT_OFFSET * bulb_scale
	var light := LevelKit.make_light(self, radius, 1.1, false)
	light.position = _light


func _make_bulb(bulb_scale: float) -> Player:
	var bulb := Player.new()
	bulb.scale = Vector2(bulb_scale, bulb_scale)
	bulb.controls_enabled = false
	# La fisica va spenta dopo l'ingresso in scena, altrimenti la lampadina cade.
	bulb.ready.connect(bulb.set_physics_process.bind(false))
	return bulb


func _add_mini(feet: Vector2, index: int, bulb_scale: float) -> void:
	var mini := MiniBulbSprite.new()
	mini.color = MINIS[index]
	mini.scale = Vector2(bulb_scale, bulb_scale)
	mini.position = feet - Vector2(0, MiniBulbSprite.FEET * bulb_scale)
	add_child(mini)


func _label(text: String, font_size: int, color: Color, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(view.x, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
