@tool
class_name WindowLight
extends Node2D
## Finestra da muro che proietta un fascio di luce: dove passa il fascio le
## ombre solide non possono esistere. Muri e casse lo bloccano, il vetro no.
## L'origine del nodo va sulla superficie del muro; l'apertura è lungo l'asse
## verticale del nodo (ruotalo per un lucernario sul soffitto).
## Con on_time e off_time > 0 la persiana si apre e si chiude a ciclo.

@export var opening := 200.0:
	set(value):
		opening = value
		queue_redraw()
## Direzione del fascio (in coordinate del livello).
@export var direction := Vector2(1, 0.5)
## Lunghezza massima del fascio (0 = prosegue finché non incontra un muro).
@export var length := 0.0
## Secondi di luce accesa (0 = sempre accesa).
@export var on_time := 0.0
## Secondi di persiana chiusa.
@export var off_time := 0.0
## Sfasa il ciclo (secondi), per non avere tutte le finestre sincronizzate.
@export var phase := 0.0

const BEAM := Color(1.0, 0.93, 0.75, 0.2)
const WARNING_TIME := 0.7
const FRAME := Color(0.3, 0.25, 0.22)
const GLASS_LIT := Color(0.85, 0.92, 1.0)
const GLASS_DARK := Color(0.12, 0.14, 0.22)
## Pulviscolo a densità fissa: un "tassello" di particelle lungo DUST_TILE px
## ripetuto lungo il fascio e fatto scorrere, come una texture che si muove.
const DUST_TILE := 300.0
## Particelle per pixel quadrato di fascio.
const DUST_DENSITY := 1.0 / 3000.0
const DUST_SPEED := 25.0
## Lunghezza usata quando length = 0: oltre i bordi di qualsiasi livello.
const MAX_LENGTH := 10000.0

var _polygons: Array[PackedVector2Array] = []
var _time := 0.0
var _visual: Node2D
var _dust: Array[Vector2] = []
## Fin dove arriva davvero il fascio (per distribuire il pulviscolo).
var _reach := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("light_beams")
	_time = phase
	_visual = LevelKit.make_overlay(self, false)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_visual.material = material
	_visual.draw.connect(_draw_beam)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for i in maxi(1, roundi(DUST_TILE * opening * DUST_DENSITY)):
		_dust.append(Vector2(rng.randf(), rng.randf()))


## True quando il fascio è acceso (le ombre vengono cancellate).
func is_lit() -> bool:
	if on_time <= 0.0 or off_time <= 0.0:
		return true
	return fmod(_time, on_time + off_time) < on_time


## Parti del fascio che cancellano le ombre (vuoto se la persiana è chiusa).
func beam_polygons() -> Array[PackedVector2Array]:
	return _polygons if is_lit() else ([] as Array[PackedVector2Array])


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var opaque: Array[PackedVector2Array] = []
	for solid in get_tree().get_nodes_in_group("solids"):
		if not solid.is_in_group("transparent"):
			opaque.append(solid.get_world_polygon())
	_polygons = compute_beam(opaque)
	_visual.queue_redraw()
	queue_redraw()


func _front() -> Vector2:
	var axis := global_transform.basis_xform(Vector2.DOWN).normalized()
	var normal := axis.orthogonal()
	return normal if normal.dot(direction) > 0.0 else -normal


## Fascio meno le zone coperte dai solidi opachi (ciascuno estruso lungo la
## luce). Pubblica perché la usa anche l'anteprima nell'editor (FlashPreview).
func compute_beam(opaque: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var dir := direction.normalized()
	var reach := length if length > 0.0 else MAX_LENGTH
	var a := global_transform * Vector2(0, -opening / 2.0)
	var b := global_transform * Vector2(0, opening / 2.0)
	var beams: Array[PackedVector2Array] = [PackedVector2Array([a, b, b + dir * reach, a + dir * reach])]
	var front := ShadowSystem._half_plane(global_position + _front() * 2.0, _front())
	for polygon in opaque:
		for part in Geometry2D.intersect_polygons(polygon, front):
			var swept := part.duplicate()
			for v in part:
				swept.append(v + dir * reach)
			beams = ShadowSystem._subtract(beams, [Geometry2D.convex_hull(swept)])
	_reach = 0.0
	for beam in beams:
		for v in beam:
			_reach = maxf(_reach, (v - a).dot(dir))
	return beams


## Luminosità del fascio disegnato (1 acceso, 0 spento, tremolio d'avviso).
func _intensity() -> float:
	if is_lit():
		return 1.0
	if on_time > 0.0:
		# Avviso: il fascio tremola poco prima di riaccendersi.
		var until_on := on_time + off_time - fmod(_time, on_time + off_time)
		if until_on < WARNING_TIME:
			return 0.25 * absf(sin(until_on * 30.0))
	return 0.0


## True se nelle zone sovrapposte vince il fascio di other (più luminoso, o a
## parità quello creato prima): così le luci si intersecano senza sommarsi.
func _yields_to(other: WindowLight, intensity: float) -> bool:
	var theirs := other._intensity()
	if theirs != intensity:
		return theirs > intensity
	return other.get_instance_id() < get_instance_id()


## Toglie i cutter dai pezzi senza mai produrre buchi: se un cutter cade tutto
## dentro un pezzo, il pezzo viene prima diviso in due lungo il suo centro.
static func _subtract_no_holes(pieces: Array[PackedVector2Array], cutters: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	for cutter in cutters:
		var center := Vector2.ZERO
		for v in cutter:
			center += v
		center /= cutter.size()
		var clipped: Array[PackedVector2Array] = []
		for piece in pieces:
			var halves: Array[PackedVector2Array] = [piece]
			if Geometry2D.clip_polygons(cutter, piece).is_empty() and not Geometry2D.intersect_polygons(piece, cutter).is_empty():
				halves.clear()
				var r := MAX_LENGTH * 4.0
				for side in [r, -r]:
					var half_plane := PackedVector2Array([center + Vector2(0, -r), center + Vector2(side, -r), center + Vector2(side, r), center + Vector2(0, r)])
					halves.append_array(Geometry2D.intersect_polygons(piece, half_plane))
			for half in halves:
				clipped.append_array(Geometry2D.clip_polygons(half, cutter))
		pieces = clipped
	return pieces


func _draw_beam() -> void:
	var intensity := _intensity()
	if intensity <= 0.0:
		return
	var shown := _polygons
	for other in get_tree().get_nodes_in_group("light_beams"):
		if other != self and other is WindowLight and other._intensity() > 0.0 and _yields_to(other, intensity):
			shown = _subtract_no_holes(shown, other._polygons)
	var color := Color(BEAM, BEAM.a * intensity)
	for polygon in shown:
		_visual.draw_colored_polygon(polygon, color)
	# Pulviscolo che fluttua nel fascio.
	var dir := direction.normalized()
	var a := global_transform * Vector2(0, -opening / 2.0)
	var across := global_transform * Vector2(0, opening / 2.0) - a
	var dust_color := Color(1, 1, 0.9, 0.5 * intensity)
	for tile in ceili(_reach / DUST_TILE):
		for d in _dust:
			var along := tile * DUST_TILE + fposmod(d.x * DUST_TILE + _time * DUST_SPEED, DUST_TILE)
			if along > _reach:
				continue
			var point := a + across * d.y + dir * along + Vector2(0, sin(_time + d.x * 20.0) * 6.0)
			for polygon in _polygons:
				if Geometry2D.is_point_in_polygon(point, polygon):
					_visual.draw_circle(point, 2.5, dust_color)
					break


func _draw() -> void:
	var half := opening / 2.0
	var lit := Engine.is_editor_hint() or is_lit()
	draw_rect(Rect2(-24, -half - 10, 24, opening + 20), FRAME)
	draw_rect(Rect2(-18, -half, 14, opening), GLASS_LIT if lit else GLASS_DARK)
	draw_line(Vector2(-11, -half), Vector2(-11, half), FRAME, 4.0)
	draw_line(Vector2(-18, 0), Vector2(-4, 0), FRAME, 4.0)
	if not lit:
		# Persiana chiusa.
		var y := -half
		while y < half:
			draw_line(Vector2(-20, y + 6), Vector2(-2, y + 6), Color(0.45, 0.38, 0.3), 5.0)
			y += 14.0
