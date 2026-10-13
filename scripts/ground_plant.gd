@tool
class_name GroundPlant
extends Node2D
## Pianta da serra, solo decorativa: niente collisioni né ombre. Le foglie
## ondeggiano piano e ognuna si piega quando la lampadina la tocca; toccando
## i fusti si muove tutta la chioma che ci sta sopra.
## L'origine è la base al centro: appoggiata va a y = pavimento.

## Specie: palma (areca a più fusti), monstera (foglie forate su un tutore),
## felce (su un trespolo), banano, cactus a colonna (rigido, non ondeggia).
@export_enum("palm", "monstera", "fern", "banana", "cactus") var kind := "palm":
	set(value):
		kind = value
		queue_redraw()
## Altezza indicativa in pixel, vaso compreso (la lampadina è alta circa 104).
@export var height := 320.0:
	set(value):
		height = value
		queue_redraw()
@export_enum("terracotta", "planter", "none") var pot := "terracotta":
	set(value):
		pot = value
		queue_redraw()
@export var pot_width := 110.0:
	set(value):
		pot_width = value
		queue_redraw()
## Cambialo per una pianta di forma diversa; due istanze con lo stesso valore
## sono identiche.
@export var pattern := 1:
	set(value):
		pattern = value
		queue_redraw()

const LEAF := Color(0.16, 0.26, 0.16)
const LEAF_DARK := Color(0.11, 0.19, 0.12)
const LEAF_LIGHT := Color(0.21, 0.31, 0.18)
const VEIN := Color(0.09, 0.15, 0.1)
const STEM := Color(0.2, 0.25, 0.15)
const BARK := Color(0.26, 0.22, 0.16)
const BARK_DARK := Color(0.19, 0.16, 0.12)
const CACTUS := Color(0.19, 0.28, 0.19)
const CACTUS_DARK := Color(0.13, 0.2, 0.14)
const SPIKE := Color(0.42, 0.42, 0.33)
const BLOSSOM := Color(0.5, 0.3, 0.38)
const TERRACOTTA := Color(0.36, 0.22, 0.17)
const TERRACOTTA_DARK := Color(0.27, 0.16, 0.13)
const WOOD := Color(0.29, 0.23, 0.17)
const WOOD_DARK := Color(0.21, 0.16, 0.12)

## Molla che riporta ogni parte a riposo e smorzamento dell'oscillazione.
const STIFFNESS := 40.0
const DAMPING := 8.0
## Quanto la velocità orizzontale della lampadina piega la parte che tocca.
const PUSH := 0.007
const MAX_BEND := 0.12
## Ondeggiamento a riposo, come per un filo d'aria.
const IDLE_SPEED := 1.3
const IDLE_AMOUNT := 0.015

## Capsula della lampadina (vedi player.gd): raggio e metà del tratto dritto.
const PLAYER_RADIUS := 30.0
const PLAYER_HALF_SPINE := 22.0

## Ogni parte che si muove da sola (fusto, foglia, fronda) ha la sua molla e i
## punti in cui la lampadina la tocca, presi dall'ultimo disegno insieme a
## quanto ci si deve avvicinare (`_part_reach`).
var _part_bend := PackedFloat32Array()
var _part_velocity := PackedFloat32Array()
var _part_points: Array[PackedVector2Array] = []
var _part_reach := PackedFloat32Array()
var _part_count := 0
var _time := 0.0
var _area: Area2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = -5
	if Engine.is_editor_hint():
		return
	# Area che sente la lampadina (layer 1) intorno alla pianta; poi si guarda
	# quali parti tocca davvero.
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(height, pot_width) * 1.1, height)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -height / 2.0)
	_area.add_child(collision)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or kind == "cactus":
		return
	_time += delta
	var count := _part_points.size()
	_part_bend.resize(count)
	_part_velocity.resize(count)
	var players: Array[Player] = []
	for body in _area.get_overlapping_bodies():
		if body is Player:
			players.append(body)
	for i in count:
		var force := -STIFFNESS * _part_bend[i] - DAMPING * _part_velocity[i]
		for player in players:
			if _touches(i, to_local(player.global_position)):
				force += player.velocity.x * PUSH
		_part_velocity[i] += force * delta
		_part_bend[i] = clampf(_part_bend[i] + _part_velocity[i] * delta, -MAX_BEND, MAX_BEND)
	queue_redraw()


## La capsula della lampadina centrata in `center` tocca la parte `i`?
func _touches(i: int, center: Vector2) -> bool:
	var top := center + Vector2(0, -PLAYER_HALF_SPINE)
	var bottom := center + Vector2(0, PLAYER_HALF_SPINE)
	var reach := PLAYER_RADIUS + _part_reach[i]
	for point in _part_points[i]:
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, top, bottom)) < reach:
			return true
	return false


## Comincia una nuova parte che si muove da sola e ne restituisce la rotazione:
## piegatura propria più un'oscillazione a riposo (`phase`). `flex` dice
## quanto quella parte è flessibile.
func _sway(phase: float, flex: float) -> float:
	var i := _part_count
	_part_count += 1
	if _part_points.size() <= i:
		_part_points.append(PackedVector2Array())
		_part_reach.append(0.0)
	_part_points[i] = PackedVector2Array()
	var bend := _part_bend[i] if i < _part_bend.size() else 0.0
	return (bend + sin(_time * IDLE_SPEED + phase) * IDLE_AMOUNT) * flex


## Punti dell'ultima parte cominciata in cui la lampadina la tocca, se ci
## arriva a meno di `reach`.
func _touch(points: PackedVector2Array, reach: float) -> void:
	_part_points[_part_count - 1] = points
	_part_reach[_part_count - 1] = reach


func _draw() -> void:
	_rng.seed = pattern
	_part_count = 0
	var pot_height := _pot_height()
	var stand := 0.0
	if kind == "fern" and pot != "none":
		stand = maxf(0.0, height * 0.45 - pot_height)
		_draw_stand(stand)
	_draw_pot(-stand)
	var base := Vector2(0, -stand - pot_height)
	var avail := maxf(40.0, height + base.y)
	match kind:
		"palm":
			_draw_palm(base, avail)
		"monstera":
			_draw_monstera(base, avail)
		"fern":
			_draw_fern(base, avail)
		"banana":
			_draw_banana(base, avail)
		"cactus":
			_draw_cactus(base, avail)
	_part_points.resize(_part_count)
	_part_reach.resize(_part_count)


func _pot_height() -> float:
	match pot:
		"terracotta":
			return pot_width * 0.8
		"planter":
			return pot_width * 0.55
	return 0.0


## Vaso con il fondo a y = `bottom`.
func _draw_pot(bottom: float) -> void:
	var w := pot_width
	var h := _pot_height()
	match pot:
		"terracotta":
			var rim := h * 0.2
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w * 0.45, bottom - h + rim), Vector2(w * 0.45, bottom - h + rim),
				Vector2(w * 0.36, bottom), Vector2(-w * 0.36, bottom),
			]), TERRACOTTA)
			draw_line(Vector2(-w * 0.44, bottom - h + rim + 3.0), Vector2(w * 0.44, bottom - h + rim + 3.0), TERRACOTTA_DARK, 4.0)
			draw_rect(Rect2(-w / 2.0, bottom - h, w, rim), TERRACOTTA.lightened(0.06))
		"planter":
			draw_rect(Rect2(-w / 2.0, bottom - h, w, h), WOOD)
			for k: int in [1, 2]:
				var y := bottom - h * k / 3.0
				draw_line(Vector2(-w / 2.0, y), Vector2(w / 2.0, y), WOOD_DARK, 2.0)
			for x in [-w / 2.0 + 5.0, w / 2.0 - 5.0]:
				draw_line(Vector2(x, bottom - h), Vector2(x, bottom), WOOD_DARK, 10.0)


## Trespolo di legno alto `h` su cui poggia il vaso.
func _draw_stand(h: float) -> void:
	var w := pot_width * 0.8
	draw_line(Vector2(-w * 0.35, -h), Vector2(-w * 0.5, 0), WOOD_DARK, 7.0)
	draw_line(Vector2(w * 0.35, -h), Vector2(w * 0.5, 0), WOOD_DARK, 7.0)
	draw_line(Vector2(-w * 0.43, -h * 0.4), Vector2(w * 0.43, -h * 0.4), WOOD_DARK, 5.0)
	draw_rect(Rect2(-w / 2.0, -h, w, 8.0), WOOD)


func _draw_palm(base: Vector2, avail: float) -> void:
	var canes := 3
	for c in canes:
		var foot := base + Vector2((c - 1) * pot_width * 0.12 + _rng.randf_range(-4.0, 4.0), 0)
		var cane_length := avail * _rng.randf_range(0.35, 0.55)
		var lean := (c - 1) * 0.14 + _rng.randf_range(-0.05, 0.05)
		var phase := _rng.randf() * TAU
		var s := _sway(phase, 0.6)
		var tip := foot + Vector2.from_angle(-PI / 2.0 + lean + s) * cane_length
		_touch(PackedVector2Array([foot.lerp(tip, 0.4), foot.lerp(tip, 0.7), tip]), 6.0)
		draw_line(foot, tip, STEM, 7.0)
		# Anelli lungo il fusto.
		var across := Vector2.from_angle(lean + s) * 4.0
		for r in range(1, int(cane_length / 22.0)):
			var p := foot.lerp(tip, r * 22.0 / cane_length)
			draw_line(p - across, p + across, VEIN, 2.0)
		var fronds := 5
		for f in fronds:
			var angle := lerpf(-PI * 0.92, -PI * 0.08, (f + 0.5) / fronds) + _rng.randf_range(-0.12, 0.12)
			var color: Color = [LEAF, LEAF_LIGHT, LEAF_DARK][_rng.randi() % 3]
			var fs := _sway(phase + f * 1.7, 1.0)
			_draw_frond(tip, angle, s * 1.3 + fs, avail * _rng.randf_range(0.42, 0.52), 1.3, 0.28, 12, color)


func _draw_monstera(base: Vector2, avail: float) -> void:
	# Tutore di muschio a cui la pianta si arrampica.
	var pole := avail * 0.8
	draw_line(base, base + Vector2(0, -pole), BARK, 12.0)
	for k in range(1, int(pole / 18.0)):
		var y := base.y - k * 18.0
		draw_line(Vector2(base.x - 6.0, y), Vector2(base.x + 6.0, y - 5.0), BARK_DARK, 2.0)
	var leaves := 7
	# Prima le foglie più scure (dietro), poi quelle chiare davanti.
	for layer in 2:
		for i in leaves:
			var phase := _rng.randf() * TAU
			var jitter := _rng.randf_range(0.9, 1.05)
			if i % 2 != layer:
				continue
			var side := -1.0 if i % 2 == 0 else 1.0
			var t := float(i) / (leaves - 1)
			var attach := base + Vector2(0, -avail * lerpf(0.05, 0.72, t) * jitter)
			var s := _sway(phase, 0.8)
			var stalk_angle := -PI / 2.0 + side * lerpf(1.1, 0.45, t)
			var stalk := attach + Vector2.from_angle(stalk_angle + s) * avail * 0.16
			draw_line(attach, stalk, STEM, 4.0)
			var length := avail * lerpf(0.42, 0.32, t) * jitter
			var cuts := _even_cuts(24, 4, 3)
			var color := LEAF_DARK if layer == 0 else LEAF
			_draw_split_leaf(stalk, stalk_angle + side * 0.55, s * 1.6, length, length * 0.8, 0.25,
					cuts, cuts, 0.3, 0.2, 1.0, color)


func _draw_fern(base: Vector2, avail: float) -> void:
	var fronds := 14
	var angles := []
	for i in fronds:
		angles.append(lerpf(-PI * 0.97, -PI * 0.03, (i + 0.5) / fronds) + _rng.randf_range(-0.1, 0.1))
	# Prima le fronde di lato (dietro, più scure), poi quelle dritte.
	angles.sort_custom(func(a: float, b: float) -> bool: return absf(cos(a)) > absf(cos(b)))
	for angle: float in angles:
		var upright := 1.0 - absf(cos(angle))
		var length := avail * _rng.randf_range(0.95, 1.15) * (0.7 + 0.5 * upright)
		var s := _sway(_rng.randf() * TAU, 1.0)
		var color := LEAF_DARK.lerp(LEAF_LIGHT, upright)
		_draw_frond(base, angle, s, length, lerpf(1.3, 2.0, upright), 0.12, 16, color)


func _draw_banana(base: Vector2, avail: float) -> void:
	var trunk := avail * 0.42
	var s0 := _sway(_rng.randf() * TAU, 0.4)
	var top := base + Vector2.from_angle(-PI / 2.0 + s0) * trunk
	_touch(PackedVector2Array([base.lerp(top, 0.4), base.lerp(top, 0.7), top]), 12.0)
	_quad(base + Vector2(-14, 0), top + Vector2(-9, 0), top + Vector2(9, 0), base + Vector2(14, 0), STEM.darkened(0.1))
	for x in [-6.0, 0.0, 6.0]:
		draw_line(base + Vector2(x, -4), top + Vector2(x * 0.6, 6), VEIN, 1.5)
	# Foglia nuova ancora arrotolata, dritta in cima.
	var s := _sway(_rng.randf() * TAU, 0.8)
	var furl := top + Vector2.from_angle(-PI / 2.0 + s0 + s) * avail * 0.3
	_touch(PackedVector2Array([top.lerp(furl, 0.5), furl]), 5.0)
	_quad(top + Vector2(-5, 0), furl + Vector2(-1, 0), furl + Vector2(1, 0), top + Vector2(5, 0), LEAF_LIGHT)
	var leaves := 6
	for i in leaves:
		var angle := lerpf(-PI * 0.95, -PI * 0.05, (i + 0.5) / leaves) + _rng.randf_range(-0.1, 0.1)
		var length := avail * _rng.randf_range(0.5, 0.62)
		var ls := _sway(_rng.randf() * TAU, 1.0)
		var color: Color = [LEAF, LEAF_DARK, LEAF_LIGHT][i % 3]
		# Strappi irregolari lungo i bordi, tipici del banano.
		_draw_split_leaf(top, angle, s0 + ls, length, length * 0.3, 0.9,
				_random_cuts(24, 4), _random_cuts(24, 4), 0.1, 0.0, 0.3, color)


func _draw_cactus(base: Vector2, avail: float) -> void:
	var w := pot_width * 0.34
	var h := avail * 0.95
	var arms := 1 + _rng.randi() % 3
	for a in arms:
		var side := -1.0 if (a + pattern) % 2 == 0 else 1.0
		var elbow := base + Vector2(side * (w * 0.5 + w * _rng.randf_range(0.6, 1.1)), -h * _rng.randf_range(0.3, 0.6))
		var arm_top := elbow + Vector2(0, -h * _rng.randf_range(0.18, 0.32))
		var aw := w * 0.7
		draw_line(Vector2(base.x, elbow.y), elbow, CACTUS, aw)
		draw_circle(elbow, aw / 2.0, CACTUS)
		draw_line(elbow, arm_top, CACTUS, aw)
		draw_circle(arm_top, aw / 2.0, CACTUS)
		draw_line(elbow + Vector2(0, -aw * 0.3), arm_top, CACTUS_DARK, 2.0)
		_draw_spikes(elbow, arm_top, aw)
	draw_rect(Rect2(base.x - w / 2.0, base.y - h + w / 2.0, w, h - w / 2.0), CACTUS)
	draw_circle(base + Vector2(0, -h + w / 2.0), w / 2.0, CACTUS)
	for x in [-w / 4.0, 0.0, w / 4.0]:
		draw_line(base + Vector2(x, 0), base + Vector2(x, -h + w * 0.4), CACTUS_DARK, 2.0)
	_draw_spikes(base, base + Vector2(0, -h + w / 2.0), w)
	if pattern % 2 == 1:
		var flower := base + Vector2(0, -h - 2.0)
		for k in 5:
			draw_circle(flower + Vector2.from_angle(-PI / 2.0 + k * TAU / 5.0) * 5.0, 4.0, BLOSSOM)
		draw_circle(flower, 3.0, BLOSSOM.lightened(0.2))


## Spine: piccoli ciuffi chiari lungo i bordi di una colonna da `a` a `b`.
func _draw_spikes(a: Vector2, b: Vector2, w: float) -> void:
	var count := int(a.distance_to(b) / 16.0)
	for k in count:
		var p := a.lerp(b, (k + 0.5) / count)
		for x in [-w / 2.0, w / 2.0]:
			var tuft := p + Vector2(x, 0)
			draw_line(tuft, tuft + Vector2(signf(x) * 5.0, -3.0), SPIKE, 1.0)
			draw_line(tuft, tuft + Vector2(signf(x) * 5.0, 2.0), SPIKE, 1.0)


## Nervatura che parte da `base` verso `angle` e si incurva verso il basso di
## `droop` radianti in totale fino alla punta.
## `sway` ruota tutta la nervatura ma non cambia il verso in cui si incurva,
## che dipende solo da `angle` (a riposo): così la foglia non si ribalta.
func _spine(base: Vector2, angle: float, sway: float, length: float, droop: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array([base])
	var heading := angle + sway
	var turn := droop / steps * (1.0 if cos(angle) >= 0.0 else -1.0)
	var p := base
	for i in steps:
		heading += turn
		p += Vector2.from_angle(heading) * length / steps
		points.append(p)
	return points


## Fronda pennata (palma, felce): rachide curva con foglioline strette ai due
## lati, lunghe `leaflet` volte la fronda.
func _draw_frond(base: Vector2, angle: float, sway: float, length: float, droop: float, leaflet: float, steps: int, color: Color) -> void:
	var spine := _spine(base, angle, sway, length, droop, steps)
	draw_polyline(spine, STEM, 2.5)
	_touch(spine, length * leaflet * 0.6)
	var half := length / steps * 0.45
	for i in range(1, spine.size()):
		var t := float(i) / steps
		var dir := (spine[i] - spine[i - 1]).normalized()
		var size := length * leaflet * sin(PI * (0.25 + 0.75 * t))
		for side: float in [-1.0, 1.0]:
			var out := (Vector2(-dir.y, dir.x) * side + dir * 0.5 + Vector2.DOWN * 0.5).normalized()
			var shade := color.darkened(0.15) if side < 0.0 else color
			_triangle(spine[i] - dir * half, spine[i] + dir * half, spine[i] + out * size, shade)


## Foglia larga a nastro con spacchi ai bordi (monstera, banano). `left_cuts` e
## `right_cuts` sono i tratti della nervatura dove il bordo è tagliato; gli
## spacchi arrivano fino a `inner` della semilarghezza. La larghezza segue
## sin(π·(start + (1-start)·t))^power: `start` > 0 dà una base a cuore.
func _draw_split_leaf(base: Vector2, angle: float, sway: float, length: float, width: float, droop: float,
		left_cuts: Array, right_cuts: Array, inner: float, start: float, power: float, color: Color) -> void:
	var steps := 24
	var spine := _spine(base, angle, sway, length, droop, steps)
	var normals := PackedVector2Array()
	var widths := PackedFloat32Array()
	for i in spine.size():
		var dir := (spine[mini(i + 1, steps)] - spine[maxi(i - 1, 0)]).normalized()
		normals.append(Vector2(-dir.y, dir.x))
		var t := float(i) / steps
		widths.append(width * 0.5 * pow(maxf(0.0, sin(PI * (start + (1.0 - start) * t))), power))
	for i in steps:
		var a := spine[i]
		var b := spine[i + 1]
		var na := normals[i] * widths[i]
		var nb := normals[i + 1] * widths[i + 1]
		_quad(a + na * inner, b + nb * inner, b - nb * inner, a - na * inner, color)
		if not left_cuts.has(i):
			_quad(a - na * inner, a - na, b - nb, b - nb * inner, color)
		if not right_cuts.has(i):
			_quad(a + na * inner, a + na, b + nb, b + nb * inner, color.darkened(0.08))
	draw_polyline(spine, VEIN, 2.0)
	_touch(spine, width * 0.4)


## Spacchi regolari ogni `every` tratti, dal tratto `from` in poi (monstera).
func _even_cuts(steps: int, from: int, every: int) -> Array:
	var cuts := []
	for i in range(from, steps - 2, every):
		cuts.append(i)
	return cuts


## Fino a `count` strappi in punti a caso (banano).
func _random_cuts(steps: int, count: int) -> Array:
	var cuts := []
	for k in count:
		cuts.append(_rng.randi_range(2, steps - 3))
	return cuts


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	draw_primitive(PackedVector2Array([a, b, c, d]), PackedColorArray([color, color, color, color]), PackedVector2Array())


func _triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	draw_primitive(PackedVector2Array([a, b, c]), PackedColorArray([color, color, color]), PackedVector2Array())
