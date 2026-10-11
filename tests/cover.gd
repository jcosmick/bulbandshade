extends Control
## Cover image per itch.io (solo sviluppo): lampadina del menu con titolo.
## Uso: Godot --path . --resolution 1260x1000 res://tests/cover.tscn -- --out=<file.png>

const BULB_SCALE := Vector2(3.0, 3.0)
const MINIS := [Color(1, 0.33, 0.36), Color(0.3, 0.9, 0.4)]

var out_path := "user://cover.png"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var view := get_viewport().get_visible_rect().size
	size = view

	var background := ColorRect.new()
	background.color = Color(0.05, 0.05, 0.08)
	background.size = view
	add_child(background)

	var bulb_home := Vector2(view.x / 2.0, view.y * 0.36)
	var glow := TextureRect.new()
	glow.texture = LevelKit.light_texture()
	glow.modulate = Color(1.0, 0.78, 0.45, 0.32)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(1300, 1300)
	glow.position = bulb_home + Vector2(0, -70) - glow.size / 2.0
	add_child(glow)

	var bulb := Player.new()
	bulb.scale = BULB_SCALE
	add_child(bulb)
	bulb.set_physics_process(false)
	bulb.controls_enabled = false
	bulb.position = bulb_home

	var feet_y := (52.0 - MiniBulbSprite.FEET) * BULB_SCALE.y
	for i in MINIS.size():
		var mini := MiniBulbSprite.new()
		mini.color = MINIS[i]
		mini.scale = BULB_SCALE
		add_child(mini)
		var side := -1.0 if i == 0 else 1.0
		mini.position = bulb_home + Vector2(side * 270.0, feet_y + (-10.0 if i == 0 else 6.0))

	var title := _label("BULB & SHADE", 150, UiStyle.ACCENT)
	title.position = Vector2(0, view.y * 0.64)
	add_child(title)
	var subtitle := _label("Light the way", 56, UiStyle.TEXT_DIM)
	subtitle.position = Vector2(0, view.y * 0.64 + 200)
	add_child(subtitle)

	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	get_tree().quit()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(get_viewport().get_visible_rect().size.x, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
