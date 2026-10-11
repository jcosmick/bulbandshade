@tool
class_name WaterDrip
extends Node2D
## Rubinetto che gocciola: le gocce mandano in cortocircuito la lampadina.
## Attraversano le ombre solide e si fermano solo sulle superfici vere.
## L'origine del nodo è sulla bocca del rubinetto: le gocce nascono a SPAWN.

## Emesso quando una goccia tocca una superficie.
signal drop_landed

## Secondi tra una goccia e l'altra.
@export var interval := 1.2
## Ritardo della prima goccia (per sfasare più rubinetti).
@export var phase := 0.0
## Limite di sicurezza: oltre questa caduta la goccia sparisce.
@export var max_fall := 4000.0:
	set(value):
		max_fall = value
		queue_redraw()
## Dove è fissato il tubo: al soffitto (sopra) o alla parete a sinistra/destra.
@export_enum("ceiling", "wall_left", "wall_right") var mount := "ceiling":
	set(value):
		mount = value
		queue_redraw()
## Lunghezza del tubo dal corpo del rubinetto al punto di fissaggio.
@export var pipe_length := 80.0:
	set(value):
		pipe_length = value
		queue_redraw()

const GRAVITY := 1800.0
## Punto (locale) in cui nasce ogni goccia, appena sotto la bocca.
const SPAWN := Vector2(0, 14)
## Bordo inferiore della bocca del rubinetto.
const LIP_Y := 6.0
## Distanza del centro del corpo dalla bocca (x verso il muro).
const BODY_OFFSET := Vector2(36, -30)
const BODY_RADIUS := 17.0
const SPOUT_RADIUS := 14.0
const SPOUT_WIDTH := 12.0
const PIPE_WIDTH := 14.0
const DROP := Color(0.55, 0.8, 1.0, 0.95)
const PIPE := Color(0.4, 0.42, 0.46)
const PIPE_DARK := Color(0.27, 0.28, 0.32)
const PIPE_LIGHT := Color(0.58, 0.6, 0.65)
const BRASS := Color(0.78, 0.6, 0.28)
const BRASS_DARK := Color(0.52, 0.38, 0.16)
const SPLASH_TIME := 0.3

var _drops: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []
var _timer := 0.0
var _visual: Node2D
## Punto d'arrivo delle gocce (locale), calcolato al primo frame di fisica.
var _landing := Vector2.ZERO
var _has_landing := false
var _sound: AudioStreamPlayer2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_timer = -phase
	_visual = LevelKit.make_overlay(self, true, 2)
	_visual.draw.connect(_draw_drops)
	_sound = Sfx.make_player_2d("drip", self)


func _process(_delta: float) -> void:
	# Nell'editor aggiorna l'anteprima della caduta se si spostano i blocchi.
	if Engine.is_editor_hint():
		queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _has_landing:
		_find_landing()
	_timer += delta
	if _timer >= interval:
		_timer -= interval
		_drops.append({"pos": SPAWN, "vel": 0.0})

	var space := get_world_2d().direct_space_state
	for drop in _drops.duplicate():
		drop.vel += GRAVITY * delta
		var from: Vector2 = global_position + drop.pos
		var to := from + Vector2(0, drop.vel * delta)
		var query := PhysicsRayQueryParameters2D.create(from, to)
		# Solo i solidi veri (layer 1): le ombre solide non fermano l'acqua.
		query.collision_mask = 1
		var hit := space.intersect_ray(query)
		if hit:
			if hit.collider is Player:
				hit.collider.die()
			_splashes.append({"pos": hit.position - global_position, "age": 0.0})
			_drops.erase(drop)
			_sound.global_position = hit.position
			_sound.pitch_scale = randf_range(0.9, 1.1)
			_sound.play()
			drop_landed.emit()
		elif drop.pos.y > max_fall:
			_drops.erase(drop)
		else:
			drop.pos = to - global_position
	for splash in _splashes.duplicate():
		splash.age += delta
		if splash.age > SPLASH_TIME:
			_splashes.erase(splash)
	_visual.queue_redraw()


## Raggio verso il basso dalla bocca: il primo solido vero (non il giocatore
## né le casse spingibili) è dove finisce l'acqua.
func _find_landing() -> void:
	_has_landing = true
	var space := get_world_2d().direct_space_state
	var from := global_position + SPAWN
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, max_fall))
	query.collision_mask = 1
	for i in 8:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			_landing = SPAWN + Vector2(0, max_fall)
			return
		if hit.collider is StaticBody2D:
			_landing = hit.position - global_position
			return
		query.exclude = query.exclude + [hit.rid]


## Nell'editor non c'è fisica: cerca il primo solido sotto la bocca tra i
## nodi della scena che espongono get_world_polygon().
func _editor_landing() -> float:
	var root := owner if owner else get_parent()
	var best := SPAWN.y + max_fall
	if root == null:
		return best
	var from := global_position + SPAWN
	var to := from + Vector2(0, max_fall)
	for body in root.find_children("*", "StaticBody2D", true, false):
		if not body.has_method("get_world_polygon"):
			continue
		var polygon: PackedVector2Array = body.get_world_polygon()
		for i in polygon.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(
					from, to, polygon[i], polygon[(i + 1) % polygon.size()])
			if hit != null:
				best = minf(best, (hit as Vector2).y - global_position.y)
	return best


func _draw_drops() -> void:
	_draw_forming_drop()
	for drop in _drops:
		var p: Vector2 = drop.pos
		_visual.draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -9), p + Vector2(5, 2), p + Vector2(0, 7), p + Vector2(-5, 2)
		]), DROP)
	for splash in _splashes:
		var t: float = splash.age / SPLASH_TIME
		var color := Color(DROP, 1.0 - t)
		for side in [-1.0, 1.0]:
			_visual.draw_line(splash.pos, splash.pos + Vector2(side * 14.0, -10.0) * (0.4 + t), color, 3.0)


## Goccia che si gonfia sulla bocca e si stacca quando parte.
func _draw_forming_drop() -> void:
	var t := clampf(_timer / interval, 0.0, 1.0)
	if t <= 0.0:
		return
	var radius := lerpf(1.5, 5.0, t)
	_visual.draw_circle(Vector2(0, LIP_Y + radius * 0.8), radius, DROP)


func _draw() -> void:
	_draw_pipe()
	_draw_body()
	_draw_handle()
	if Engine.is_editor_hint():
		draw_dashed_line(SPAWN, Vector2(0, _editor_landing()), DROP, 2.0, 12.0)


## Tubo dal corpo al punto di fissaggio, con flangia sul muro/soffitto.
func _draw_pipe() -> void:
	var dir := _mount_dir()
	var body := _body_center()
	var start := body + dir * (BODY_RADIUS - 2.0)
	var end := start + dir * pipe_length
	var side := Vector2(-dir.y, dir.x)
	draw_line(start, end, PIPE, PIPE_WIDTH)
	draw_line(start + side * 4.0, end + side * 4.0, PIPE_LIGHT, 2.0)
	# Raccordo vicino al rubinetto e flangia di fissaggio.
	var joint := start + dir * 10.0
	draw_line(joint - side * 10.0, joint + side * 10.0, PIPE_DARK, 8.0)
	draw_line(end - dir * 3.0 - side * 18.0, end - dir * 3.0 + side * 18.0, PIPE_DARK, 6.0)
	for s in [-1.0, 1.0]:
		draw_circle(end - dir * 3.0 + side * 13.0 * s, 2.5, PIPE_LIGHT)


## Corpo tondo e becco a collo d'oca che curva verso il basso fino alla bocca.
func _draw_body() -> void:
	var body := _body_center()
	var s := _spout_side()
	var bend := Vector2(-s * SPOUT_RADIUS, body.y + SPOUT_RADIUS)
	# Braccio orizzontale, curva e tratto verticale del becco.
	draw_line(body, Vector2(bend.x, body.y), PIPE, SPOUT_WIDTH)
	var from_angle := -PI / 2.0
	var to_angle := 0.0 if s > 0.0 else -PI
	draw_arc(bend, SPOUT_RADIUS, from_angle, to_angle, 12, PIPE, SPOUT_WIDTH)
	draw_line(Vector2(0, bend.y), Vector2(0, LIP_Y - 5.0), PIPE, SPOUT_WIDTH)
	draw_arc(bend, SPOUT_RADIUS + SPOUT_WIDTH / 2.0 - 2.0, from_angle, to_angle, 12, PIPE_LIGHT, 2.0)
	draw_rect(Rect2(-9, LIP_Y - 7.0, 18, 7), PIPE_DARK)
	# Corpo della valvola.
	draw_circle(body, BODY_RADIUS, PIPE)
	draw_arc(body, BODY_RADIUS - 5.0, PI * 1.1, PI * 1.6, 8, PIPE_LIGHT, 3.0)
	draw_arc(body, BODY_RADIUS, 0.0, TAU, 24, PIPE_DARK, 3.0)


## Manopola d'ottone a croce sopra il corpo; se il tubo va al soffitto è un
## volantino sul davanti.
func _draw_handle() -> void:
	var body := _body_center()
	if mount == "ceiling":
		draw_circle(body, 11.0, BRASS_DARK)
		draw_arc(body, 11.0, 0.0, TAU, 20, BRASS, 4.0)
		draw_line(body + Vector2(-10, 0), body + Vector2(10, 0), BRASS, 3.0)
		draw_line(body + Vector2(0, -10), body + Vector2(0, 10), BRASS, 3.0)
		draw_circle(body, 3.5, BRASS)
		return
	var base := body + Vector2(0, -BODY_RADIUS + 2.0)
	var top := base + Vector2(0, -14)
	draw_rect(Rect2(base.x - 7.0, base.y - 6.0, 14, 6), PIPE_DARK)
	draw_line(base, top, BRASS_DARK, 6.0)
	draw_line(top + Vector2(-17, 0), top + Vector2(17, 0), BRASS, 7.0)
	for x in [-17.0, 17.0]:
		draw_circle(top + Vector2(x, 0), 5.0, BRASS)
	draw_circle(top, 5.0, BRASS_DARK)


## Centro del corpo del rubinetto, dal lato del muro rispetto alla bocca.
func _body_center() -> Vector2:
	return Vector2(-_spout_side() * BODY_OFFSET.x, BODY_OFFSET.y)


## +1 se il becco punta verso destra (tubo a sinistra o al soffitto), -1 se
## punta verso sinistra (tubo alla parete destra).
func _spout_side() -> float:
	return -1.0 if mount == "wall_right" else 1.0


func _mount_dir() -> Vector2:
	match mount:
		"wall_left":
			return Vector2.LEFT
		"wall_right":
			return Vector2.RIGHT
	return Vector2.UP
