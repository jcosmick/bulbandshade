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
## Lunghezza usata quando length = 0: oltre i bordi di qualsiasi livello.
const MAX_LENGTH := 10000.0

## Fascio e pulviscolo: il pulviscolo lo disegna lo shader (una particella per
## cella di DUST_CELL px, circa una ogni 3000 px quadrati, che scorre lungo il
## fascio e ondeggia in verticale), così il fascio si ridisegna solo quando
## cambiano la forma o la luminosità e non a ogni tick.
const SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add;

uniform vec2 origin;
uniform vec2 dir = vec2(1.0, 0.0);
uniform vec2 across = vec2(0.0, 1.0);
uniform float intensity = 1.0;

const float DUST_CELL = 55.0;
const float DUST_SPEED = 25.0;
const float DUST_RADIUS = 2.5;
const float WOBBLE = 6.0;

varying highp vec2 world;

void vertex() {
	world = VERTEX;
}

vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

void fragment() {
	highp vec2 rel = world - origin;
	// Il pulviscolo ripete ogni 64 celle: TIME resta piccolo anche su mobile.
	highp float flow = mod(TIME * DUST_SPEED, DUST_CELL * 64.0);
	highp vec2 q = vec2(dot(rel, dir) - flow, dot(rel, across));
	vec2 id = floor(q / DUST_CELL);
	vec2 f = q - id * DUST_CELL;
	vec2 h = hash2(vec2(mod(id.x, 64.0), id.y) + 7.0);
	// Centro lontano dal bordo della cella quanto basta per l'ondeggiamento.
	float margin = DUST_RADIUS + WOBBLE + 0.5;
	vec2 center = margin + h * (DUST_CELL - 2.0 * margin);
	center += vec2(dir.y, across.y) * sin(TIME + h.x * 20.0) * WOBBLE;
	float dust = clamp(DUST_RADIUS + 0.5 - length(f - center), 0.0, 1.0) * 0.5 * intensity;
	COLOR = vec4(COLOR.rgb * COLOR.a + vec3(1.0, 1.0, 0.9) * dust, 1.0);
}
"""

static var _shader: Shader
## Poligoni dei solidi opachi letti una volta per tick di fisica e condivisi da
## tutte le finestre (_opaque_frame è il tick a cui si riferiscono).
static var _opaque_cache: Array[PackedVector2Array] = []
static var _opaque_frame := -1

var _polygons: Array[PackedVector2Array] = []
var _time := 0.0
var _visual: Node2D
var _material: ShaderMaterial
## Il fascio si ricalcola solo quando cambiano i solidi o la finestra stessa:
## quasi sempre è tutto fermo e il risultato sarebbe identico.
var _last_opaque: Array[PackedVector2Array] = []
var _last_transform := Transform2D()
var _computed := false
## Cresce a ogni ricalcolo: gli altri fasci capiscono se la forma è cambiata.
var _version := 0
## Parti disegnate (il fascio meno quelli che vincono le sovrapposizioni) e la
## chiave con cui sono state calcolate.
var _shown: Array[PackedVector2Array] = []
var _shown_key := []
var _drawn_lit := true
## Stato con cui è stato disegnato il fascio (vedi _physics_process).
var _redraw_state := []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("light_beams")
	_time = phase
	_visual = LevelKit.make_overlay(self, false)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_visual.material = _material
	_visual.draw.connect(_draw_beam)
	LevelKit.prewarm(_visual)


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
	var opaque := _opaque_polygons()
	if not _computed or opaque != _last_opaque or global_transform != _last_transform:
		_polygons = compute_beam(opaque)
		_last_opaque = opaque
		_last_transform = global_transform
		_computed = true
		_version += 1
	# Il pulviscolo si muove nello shader: il fascio si ridisegna solo se
	# cambiano la forma, la luminosità (anche durante il tremolio d'avviso) o un
	# fascio che si sovrappone.
	var state := [_version, _intensity()]
	for other in get_tree().get_nodes_in_group("light_beams"):
		if other != self:
			state.append_array([other._version, other._intensity() > 0.0])
	if state != _redraw_state:
		_redraw_state = state
		_visual.queue_redraw()
	if is_lit() != _drawn_lit:
		queue_redraw()


## Poligoni dei solidi opachi in questo tick (vedi _opaque_cache).
func _opaque_polygons() -> Array[PackedVector2Array]:
	var frame := Engine.get_physics_frames()
	if frame != _opaque_frame:
		_opaque_frame = frame
		_opaque_cache = []
		for solid in get_tree().get_nodes_in_group("solids"):
			if not solid.is_in_group("transparent"):
				_opaque_cache.append(solid.get_world_polygon())
	return _opaque_cache


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
	# Striscia del fascio: tra le rette per a e b parallele alla direzione, fino
	# a `reach`. Un solido che ne sta tutto fuori non la tocca nemmeno estruso
	# lungo la luce: si scarta senza le operazioni sui poligoni.
	var across := dir.orthogonal()
	var side_min := minf(across.dot(a), across.dot(b)) - 1.0
	var side_max := maxf(across.dot(a), across.dot(b)) + 1.0
	var far_end := maxf(dir.dot(a), dir.dot(b)) + reach + 1.0
	for polygon in opaque:
		if polygon.size() < 3 or not _crosses_strip(polygon, across, side_min, side_max, dir, far_end):
			continue
		for part in Geometry2D.intersect_polygons(polygon, front):
			var swept := part.duplicate()
			for v in part:
				swept.append(v + dir * reach)
			beams = ShadowSystem._subtract(beams, [Geometry2D.convex_hull(swept)])
	return beams


## False se polygon sta tutto da un lato della striscia del fascio o tutto
## oltre la sua fine (proiezioni sugli assi across e dir).
static func _crosses_strip(polygon: PackedVector2Array, across: Vector2, side_min: float, side_max: float, dir: Vector2, far_end: float) -> bool:
	var lo := INF
	var hi := -INF
	var nearest := INF
	for v in polygon:
		var side := across.dot(v)
		lo = minf(lo, side)
		hi = maxf(hi, side)
		nearest = minf(nearest, dir.dot(v))
	return hi >= side_min and lo <= side_max and nearest <= far_end


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
	# Il ritaglio con i fasci che vincono le sovrapposizioni si rifà solo se è
	# cambiato qualcosa (forme o fasci che vincono), non a ogni frame.
	var winners: Array[WindowLight] = []
	var key := [_version]
	for other in get_tree().get_nodes_in_group("light_beams"):
		if other != self and other is WindowLight and other._intensity() > 0.0 and _yields_to(other, intensity):
			winners.append(other)
			key.append_array([other.get_instance_id(), other._version])
	if key != _shown_key:
		_shown = _polygons
		for other in winners:
			_shown = _subtract_no_holes(_shown, other._polygons)
		_shown_key = key
	# Pulviscolo (nello shader): assi del fascio a partire dal bordo `a`.
	var a := global_transform * Vector2(0, -opening / 2.0)
	_material.set_shader_parameter("origin", a)
	_material.set_shader_parameter("dir", direction.normalized())
	_material.set_shader_parameter("across", (global_transform * Vector2(0, opening / 2.0) - a).normalized())
	_material.set_shader_parameter("intensity", intensity)
	var color := Color(BEAM, BEAM.a * intensity)
	for polygon in _shown:
		_visual.draw_colored_polygon(polygon, color)


func _draw() -> void:
	var half := opening / 2.0
	var lit := Engine.is_editor_hint() or is_lit()
	_drawn_lit = lit
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
