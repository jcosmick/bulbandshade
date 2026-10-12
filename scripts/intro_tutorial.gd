@tool
extends Cutscene
## Intro del tutorial: una mini lampadina blu cade dall'alto, cammina fino alla
## cassa e fa un flash che crea un'ombra sopra l'acqua. Poi sale sulla cassa,
## corre sull'ombra e, a telecamera ferma, salta via fuori dall'inquadratura.
## Infine arriva (cadendo dall'alto) la lampadina del giocatore e si gioca.
## Punti e linee sono in coordinate del livello; nell'editor si vedono in blu.

## Da dove cade la mini lampadina (sopra il soffitto, fuori schermo).
@export var enter_from := Vector2(420, -60):
	set(value):
		enter_from = value
		queue_redraw()
## Punto in cui si ferma a fare il flash (conta solo la x).
@export var flash_point := Vector2(740, 1384):
	set(value):
		flash_point = value
		queue_redraw()
## Superata questa x la telecamera si ferma.
@export var camera_lock_x := 1100.0:
	set(value):
		camera_lock_x = value
		queue_redraw()
## Superata questa x salta via dall'ombra.
@export var jump_off_x := 1400.0:
	set(value):
		jump_off_x = value
		queue_redraw()
@export var color := Color(0.35, 0.6, 1.0)
## Da quanto in alto cade la lampadina del giocatore quando arriva.
@export var player_drop := 900.0

## Altezza della luce del giocatore sopra i piedi: il flash parte da lì, così
## l'ombra è identica a quella che farà il giocatore nello stesso punto.
const PLAYER_LIGHT_HEIGHT := 68.0
const GIZMO_COLOR := Color(0.35, 0.6, 1.0, 0.8)

var _walker: CutsceneWalker


func _play() -> void:
	var player: Player = game.player
	player.visible = false
	player.set_physics_process(false)
	_walker = CutsceneWalker.new()
	_walker.color = color
	# Attraversa il soffitto mentre entra.
	_walker.solid = false
	add_child(_walker)
	_walker.global_position = enter_from
	game.camera_focus = _walker

	await wait_until(func() -> bool: return _walker.global_position.y > 160.0)
	_walker.solid = true
	await wait_until(_walker.is_on_floor)
	await wait(0.5)
	await _walk_to(flash_point.x)
	await wait(0.5)
	_flash()
	await wait(0.7)

	# Sale sulla cassa e corre sull'ombra.
	_walker.direction = 1.0
	_walker.jump()
	await wait_until(func() -> bool: return _walker.global_position.x > camera_lock_x)
	var lock := Node2D.new()
	add_child(lock)
	lock.global_position = _walker.global_position
	game.camera_focus = lock
	await wait_until(func() -> bool: return _walker.global_position.x > jump_off_x)
	_walker.jump()
	await wait_until(_walker_out_of_view, 3.0)
	_walker.queue_free()

	await wait(0.5)
	# La telecamera torna dove arriverà il giocatore.
	game.camera_focus = null
	await wait(0.9)


## Cammina e si ferma (frenando come il giocatore) alla x indicata.
func _walk_to(x: float) -> void:
	var dir := signf(x - _walker.global_position.x)
	_walker.direction = dir
	await wait_until(func() -> bool:
		return (_walker.global_position.x + dir * _walker.stopping_distance() - x) * dir >= 0.0)
	_walker.direction = 0.0
	await wait_until(func() -> bool: return absf(_walker.velocity.x) < 1.0, 1.0)


func _flash() -> void:
	_walker.sprite.squash(Vector2(1.3, 0.75))
	_walker.sprite.flash()
	var origin := _walker.feet_position() + Vector2(0, -PLAYER_LIGHT_HEIGHT)
	game.cutscene_flash(origin, game.player.flash_radius)


func _walker_out_of_view() -> bool:
	return not game.visible_world_rect().grow(40.0).has_point(_walker.global_position)


func _end() -> void:
	var player: Player = game.player
	# Il giocatore arriva cadendo dall'alto sul punto di partenza.
	player.global_position += Vector2(0, -player_drop)
	player.visible = true
	player.set_physics_process(true)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(to_local(enter_from), 14.0, GIZMO_COLOR, false, 3.0)
	draw_circle(to_local(flash_point), 14.0, GIZMO_COLOR, false, 3.0)
	draw_dashed_line(to_local(enter_from), to_local(flash_point), GIZMO_COLOR, 2.0, 10.0)
	draw_string(ThemeDB.fallback_font, to_local(flash_point) + Vector2(-30, -24), "flash",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, GIZMO_COLOR)
	for spec in [[camera_lock_x, "camera ferma"], [jump_off_x, "salto"]]:
		var top := to_local(Vector2(spec[0], 0))
		draw_dashed_line(top, top + Vector2(0, 1520), GIZMO_COLOR, 2.0, 16.0)
		draw_string(ThemeDB.fallback_font, top + Vector2(8, 140), spec[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, GIZMO_COLOR)
