extends Node2D
## Test (solo sviluppo) del rubinetto che gocciola: le gocce attraversano
## un'ombra solida finta, cadono sul pavimento e mandano in cortocircuito la
## lampadina sotto il rubinetto.
## Uso: Godot --path . res://tests/drip_test.tscn -- --out=<cartella>

const FLOOR_TOP := 1480.0

var out_dir := "user://drip_test"
var _landings := {}
var _died := false
var _camera: Camera2D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bg := ColorRect.new()
	bg.color = Color(0.55, 0.52, 0.58)
	bg.size = Vector2(1080, 1920)
	bg.z_index = -10
	add_child(bg)
	_add_block(Vector2(540, FLOOR_TOP + 20), Vector2(1080, 40))
	_add_block(Vector2(300, 200), Vector2(400, 40))
	_add_block(Vector2(40, 900), Vector2(80, 600))
	_add_block(Vector2(1040, 900), Vector2(80, 600))
	_add_fake_shadow(Rect2(150, 1100, 300, 30))
	# Soffitto: bordo inferiore 220, tubo 80 -> origine a 220 + 45 + 80.
	_add_drip("DripCeiling", Vector2(300, 345), "ceiling", 80.0)
	# Parete sinistra: bordo destro 80, tubo 100 -> origine a 80 + 51 + 100.
	_add_drip("DripLeft", Vector2(231, 800), "wall_left", 100.0)
	# Parete destra: bordo sinistro 1000, tubo 60 -> origine a 1000 - 51 - 60.
	_add_drip("DripRight", Vector2(889, 800), "wall_right", 60.0)
	var player := Player.new()
	player.position = Vector2(889, FLOOR_TOP - 52)
	add_child(player)
	player.died.connect(func() -> void:
		_died = true
		print("PLAYER DIED"))
	_camera = Camera2D.new()
	_camera.position = Vector2(540, 960)
	add_child(_camera)
	_camera.make_current()
	_run()


func _add_block(pos: Vector2, size: Vector2) -> void:
	var block := Block.new()
	block.size = size
	block.position = pos
	add_child(block)


## Ombra solida finta sul layer delle ombre: deve fermare il giocatore ma
## non le gocce.
func _add_fake_shadow(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = ShadowSystem.SHADOW_COLLISION_LAYER
	body.collision_mask = 0
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)])
	var collision := CollisionPolygon2D.new()
	collision.polygon = points
	body.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = points
	visual.color = Color(0.1, 0.1, 0.15, 0.7)
	body.add_child(visual)
	add_child(body)


func _add_drip(drip_name: String, pos: Vector2, mount: String, pipe: float) -> void:
	var drip := WaterDrip.new()
	drip.name = drip_name
	drip.position = pos
	drip.mount = mount
	drip.pipe_length = pipe
	drip.interval = 1.0
	add_child(drip)
	drip.drop_landed.connect(func() -> void:
		var y: float = drip._splashes.back().pos.y + drip.global_position.y
		print("%s landed at y=%.1f (drain at y=%.1f)" % [drip_name, y, drip._landing.y + drip.global_position.y])
		_landings[drip_name] = y)


func _run() -> void:
	await get_tree().create_timer(1.15).timeout
	await _shot("full_forming")
	await get_tree().create_timer(0.5).timeout
	await _shot("full_falling")
	await get_tree().create_timer(1.2).timeout
	await _shot("full")
	_camera.zoom = Vector2(4, 4)
	for target in [Vector2(280, 300), Vector2(170, 780), Vector2(920, 780), Vector2(300, 1470)]:
		_camera.position = target
		await get_tree().create_timer(0.1).timeout
		await _shot("zoom_%d_%d" % [target.x, target.y])
	var ok := _died and _landings.size() == 3
	for key in _landings:
		ok = ok and absf(_landings[key] - FLOOR_TOP) < 2.0 if key != "DripRight" else ok
	print("LANDINGS: ", _landings)
	print("DRIP TEST OK: ", ok)
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
