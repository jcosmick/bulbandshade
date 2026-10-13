class_name ShadowPlatform
extends Node2D
## Disegno di un'ombra solida: si allunga dal flash e si sfalda in
## pallini neri insieme al suo corpo fisico. Stile piatto: solo nero, bordi netti.

const FILL := Color(0.0, 0.0, 0.0, 0.94)
## Tempo in cui l'ombra si allunga dal caster fino al limite del flash.
const APPEAR_TIME := 0.16
## Negli ultimi secondi l'ombra si sfalda per avvisare che sta sparendo.
const WARNING_TIME := 1.0
## Quanto si sfalda al massimo prima di sparire (0 = intera, 1 = tutta).
const MAX_DISSOLVE := 0.8
## Distanza media (px) tra i pallini in cui si spezza l'ombra.
const DOT_CELL := 22.0
## Densità dei pallini neri quando l'ombra sparisce (per px di bordo).
const PUFF_PER_PX := 0.03
## Le ombre di uno stesso flash spariscono insieme: entro questo tempo (ms) un suono
## già partito non si ripete, così ne suona uno solo per flash.
const SOUND_GAP_MS := 100

const SHADER_CODE := """
shader_type canvas_item;

uniform vec2 origin;
uniform float reveal;
uniform float dissolve;
uniform float cell;

varying vec2 world;

void vertex() {
	world = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + vec2(41.3, 17.9)));
}

void fragment() {
	// Comparsa: l'ombra esiste solo fin dove è arrivato il fronte del flash.
	if (distance(world, origin) > reveal) {
		discard;
	}
	// Sfaldamento finale: l'ombra si spezza in pallini sparsi che ondeggiano e
	// si rimpiccioliscono, ognuno col suo ritmo. Si guardano anche le celle
	// vicine perché i pallini spostati possono sconfinare.
	if (dissolve > 0.0) {
		vec2 p = world / cell;
		vec2 base = floor(p);
		// All'inizio i pallini sono grandi e fermi, così l'ombra resta piena.
		float spread = clamp(dissolve * 3.0, 0.0, 1.0);
		bool inside = false;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 id = base + vec2(float(x), float(y));
				vec2 rnd = hash2(id);
				float phase = hash(id + 5.7) * 6.2832;
				vec2 wobble = vec2(sin(TIME * 2.3 + phase), cos(TIME * 1.9 + phase * 1.3)) * 0.12;
				vec2 center = id + 0.5 + ((rnd - 0.5) * 0.6 + wobble) * spread;
				float r = clamp(1.0 - dissolve * (0.6 + 0.8 * hash(id + 2.1)), 0.0, 1.0);
				r *= 0.75 + 0.35 * rnd.x;
				if (length(p - center) < r) {
					inside = true;
				}
			}
		}
		if (!inside) {
			discard;
		}
	}
}
"""

static var _shader: Shader
static var _circle: Texture2D
static var _last_sound_ms := {}

var polygon: PackedVector2Array
var bounds: Rect2
var lifetime := 4.0
var age := 0.0
## Punto da cui è partito il flash che ha creato l'ombra.
var origin := Vector2.ZERO
var _body: Node
var _reveal_from := 0.0
var _reveal_to := 0.0
var _material: ShaderMaterial


func setup(shape: PackedVector2Array, life: float, body: Node, light: Vector2, start_age := 0.0) -> void:
	polygon = shape
	bounds = Rect2(shape[0], Vector2.ZERO)
	_reveal_from = INF
	for v in shape:
		bounds = bounds.expand(v)
		var dist := v.distance_to(light)
		_reveal_from = minf(_reveal_from, dist)
		_reveal_to = maxf(_reveal_to, dist)
	lifetime = life
	age = start_age
	origin = light
	_body = body

	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.set_shader_parameter("origin", origin)
	_material.set_shader_parameter("cell", DOT_CELL)
	material = _material
	_update_material()


## Rimuove l'ombra e il suo corpo fisico.
func dispose() -> void:
	if is_instance_valid(_body):
		_body.queue_free()
	queue_free()


func _process(delta: float) -> void:
	var warning_at := lifetime - WARNING_TIME
	if age < warning_at and age + delta >= warning_at:
		_play_once("shadow_dissolve", -14.0)
	age += delta
	if age >= lifetime:
		_play_once("shadow_puff", -8.0)
		_puff()
		dispose()
		return
	_update_material()


func _update_material() -> void:
	var t := clampf(age / APPEAR_TIME, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - t, 3.0)
	var reveal := lerpf(_reveal_from, _reveal_to + 1.0, ease_out)
	var remaining := lifetime - age
	var dissolve := 0.0
	if remaining < WARNING_TIME:
		dissolve = MAX_DISSOLVE * pow(1.0 - remaining / WARNING_TIME, 1.6)
	_material.set_shader_parameter("reveal", reveal if t < 1.0 else 1.0e7)
	_material.set_shader_parameter("dissolve", dissolve)


func _draw() -> void:
	draw_colored_polygon(polygon, FILL)


## Pallini neri che si staccano dal bordo e si rimpiccioliscono quando
## l'ombra sparisce.
func _puff() -> void:
	var points := PackedVector2Array()
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var count := maxi(1, int(a.distance_to(b) * PUFF_PER_PX))
		for j in count:
			points.append(a.lerp(b, (j + randf()) / count))
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.amount = clampi(points.size(), 6, 60)
	puff.lifetime = 0.45
	puff.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	puff.emission_points = points
	puff.direction = Vector2.UP
	puff.spread = 180.0
	puff.gravity = Vector2(0, -80)
	puff.initial_velocity_min = 20.0
	puff.initial_velocity_max = 50.0
	puff.texture = circle_texture()
	puff.scale_amount_min = 0.5
	puff.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	puff.scale_amount_curve = curve
	puff.color = FILL
	puff.finished.connect(puff.queue_free)
	get_parent().add_child(puff)
	puff.emitting = true


static func _play_once(sound: String, volume_db: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_sound_ms.get(sound, -SOUND_GAP_MS) < SOUND_GAP_MS:
		return
	_last_sound_ms[sound] = now
	Sfx.play(sound, volume_db, 0.06)


## Cerchio pieno (raggio 12 px) dai bordi netti.
static func circle_texture() -> Texture2D:
	if _circle == null:
		var size := 24
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(size, size) / 2.0
		for y in size:
			for x in size:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
				image.set_pixel(x, y, Color(1, 1, 1, clampf(center.x - d, 0.0, 1.0)))
		_circle = ImageTexture.create_from_image(image)
	return _circle
