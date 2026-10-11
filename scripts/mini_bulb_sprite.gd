class_name MiniBulbSprite
extends Node2D
## Disegno di una mini lampadina colorata (collezionabile): piccola, con occhi
## grandi e guance rosse. L'origine è il centro del vetro. Ha un bagliore del
## suo colore e un mini flash, usati nel livello e nel menu.

## Distanza dal centro del vetro alla base dell'attacco (i "piedi").
const FEET := 36.0
const GLASS_RADIUS := 20.0
const METAL_COLOR := Color(0.62, 0.62, 0.66)
const METAL_DARK := Color(0.38, 0.38, 0.42)
const EYE_COLOR := Color(0.15, 0.1, 0.05)
const CHEEK_COLOR := Color(1.0, 0.45, 0.5, 0.55)
const GLOW_RADIUS := 110.0
const FLASH_RADIUS := 380.0
## Light mask della mini lampadina: la illumina solo il suo bagliore, così le
## altre luci (la lampadina grande, il suo stesso flash) non la sbiancano.
const OWN_LIGHT_MASK := 2
## Opacità iniziale dell'alone colorato del flash (si vede anche sul nero).
const HALO_ALPHA := 0.5

## Colore della mini lampadina (va impostato prima di aggiungerla alla scena).
var color := Color(1.0, 0.35, 0.35)

var _squash := Vector2.ONE
var _glow: PointLight2D
var _flash_light: PointLight2D
var _flash_tween: Tween
var _halo: Sprite2D


func _ready() -> void:
	light_mask = OWN_LIGHT_MASK
	_glow = LevelKit.make_light(self, GLOW_RADIUS, 0.6, false)
	_glow.color = color.lightened(0.2)
	_glow.range_item_cull_mask = 1 | OWN_LIGHT_MASK
	_flash_light = LevelKit.make_light(self, FLASH_RADIUS, 0.0, false)
	_flash_light.color = color.lightened(0.2)
	# Alone additivo dietro la lampadina: il flash colora anche lo sfondo scuro.
	_halo = Sprite2D.new()
	_halo.texture = LevelKit.light_texture()
	_halo.scale = Vector2.ONE * FLASH_RADIUS / LevelKit.LIGHT_TEXTURE_RADIUS
	_halo.modulate = Color(color, 0.0)
	_halo.show_behind_parent = true
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_halo.material = additive
	add_child(_halo)


## Mini flash del suo colore.
func flash() -> void:
	_squash = Vector2(1.3, 0.75)
	if _flash_tween:
		_flash_tween.kill()
	_flash_light.energy = 2.2
	_halo.modulate.a = HALO_ALPHA
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_light, "energy", 0.0, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.parallel().tween_property(_halo, "modulate:a", 0.0, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sfx.play("mini_flash", -5.0, 0.08)


## Spegne il bagliore (es. mini lampadina già raccolta, mostrata come fantasma).
func set_glow(energy: float) -> void:
	_glow.energy = energy


func squash(amount: Vector2) -> void:
	_squash = amount


func _process(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, 12.0 * delta))
	queue_redraw()


func _draw() -> void:
	draw_bulb(self, color, _squash)


## Disegna la mini lampadina con il centro del vetro in (0, 0). Lo
## schiacciamento resta appoggiato alla base.
static func draw_bulb(item: CanvasItem, tint: Color, squash_scale := Vector2.ONE) -> void:
	item.draw_set_transform(Vector2(0, FEET), 0.0, squash_scale)
	var c := Vector2(0, -FEET)
	var glass := tint.lerp(Color.WHITE, 0.25)
	item.draw_circle(c, GLASS_RADIUS, glass)
	item.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-14, 12), c + Vector2(14, 12), c + Vector2(9, 21), c + Vector2(-9, 21)
	]), glass)
	# Filamento a cuoricino.
	item.draw_polyline(PackedVector2Array([
		c + Vector2(-4, 20), c + Vector2(-4, 13), c + Vector2(-6, 10), c + Vector2(-3, 8),
		c + Vector2(0, 11), c + Vector2(3, 8), c + Vector2(6, 10), c + Vector2(4, 13), c + Vector2(4, 20)
	]), tint.darkened(0.15), 2.0)
	item.draw_rect(Rect2(c + Vector2(-9, 20), Vector2(18, 12)), METAL_COLOR)
	for i in 2:
		item.draw_line(c + Vector2(-9, 23 + i * 5), c + Vector2(9, 25 + i * 5), METAL_DARK, 2.0)
	item.draw_rect(Rect2(c + Vector2(-5, 32), Vector2(10, 4)), Color(0.2, 0.2, 0.22))
	# Faccina: occhi grandi con riflesso, guance e sorriso.
	for side in [-1.0, 1.0]:
		var eye: Vector2 = c + Vector2(7.0 * side, -3)
		item.draw_circle(eye, 4.5, EYE_COLOR)
		item.draw_circle(eye + Vector2(-1.4, -1.6), 1.6, Color.WHITE)
		item.draw_circle(c + Vector2(12.5 * side, 3.5), 3.2, CHEEK_COLOR)
	item.draw_arc(c + Vector2(0, 2), 3.5, PI * 0.15, PI * 0.85, 8, EYE_COLOR, 1.8)
	item.draw_arc(c, 15.0, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.75), 3.0)
	item.draw_set_transform_matrix(Transform2D.IDENTITY)
