@tool
extends Node2D
## Parete di fondo della stanza (solo decorazione, nessuna collisione).

## Stile del fondo: stanza con carta da parati, oppure serra con finestroni
## quadrati di vetro smerigliato su un muretto di mattoni. Le piante oltre il
## vetro sono su due piani che scorrono in parallasse quando la telecamera si
## muove (solo in gioco, non nell'editor). Il magazzino ha una parete in
## lamiera e scaffalature su due piani in parallasse, sotto una trave fissa.
## La stanza abbandonata (livelli "dark") ha l'intonaco umido e scrostato,
## la boiserie marcia e, in parallasse, file di lampadine spente appese al
## soffitto, sotto una trave di legno che gocciola.
@export_enum("room", "greenhouse", "warehouse", "abandoned") var style := "room":
	set(value):
		style = value
		_refresh()
@export var rect := Rect2(0, 0, 1080, 1520):
	set(value):
		rect = value
		_refresh()
## Altezza (y) della zoccolatura in legno (nella serra: del muretto; nel
## magazzino: della fascia di cemento con le strisce di pericolo).
@export var wainscot_y := 1200.0:
	set(value):
		wainscot_y = value
		_refresh()
## Solo magazzino: opacità dell'ombra che scaffali e pile proiettano sul muro
## (0 = nessuna ombra, 1 = nera).
@export_range(0.0, 0.2, 0.01) var rack_shadow_opacity := 0.1:
	set(value):
		rack_shadow_opacity = value
		_refresh()
## Solo serra, magazzino e stanza abbandonata: cambialo per avere piante,
## vetri, scaffali, macchie e lampadine disposti diversamente.
@export var pattern := 1:
	set(value):
		pattern = value
		_refresh()

const WALL := Color(0.38, 0.34, 0.42)
const STRIPE := Color(0.34, 0.30, 0.38)
const PANEL := Color(0.30, 0.25, 0.27)
const MOLDING := Color(0.44, 0.37, 0.36)
const STRIPE_STEP := 90.0

## Serra: telaio in ferro, vetro smerigliato più chiaro in alto.
const IRON := Color(0.2, 0.21, 0.24)
const IRON_LIGHT := Color(0.29, 0.3, 0.33)
const GLASS_TOP := Color(0.42, 0.47, 0.46)
const GLASS_BOTTOM := Color(0.31, 0.36, 0.36)
const GLASS_SHINE := Color(1, 1, 1, 0.07)
## Opacità del velo smerigliato davanti alle piante.
const FROST := 0.3
## Sagome sfocate delle piante oltre il vetro: piano lontano (più chiaro) e
## piano vicino (più scuro).
const FOLIAGE_FAR := Color(0.2, 0.29, 0.25)
const FOLIAGE_NEAR := Color(0.09, 0.15, 0.11)
## Quanto ogni piano segue la telecamera (0 = fermo col livello, 1 = fermo
## sullo schermo): più è alto, più il piano sembra lontano.
const PARALLAX_FAR := 0.6
const PARALLAX_NEAR := 0.3
## Magazzino: la parete di lamiera è la cosa più lontana, quindi segue la
## telecamera più degli scaffali.
const PARALLAX_WALL := 0.75
## Magazzino: parete e scaffali lontani sono un solo strato (una texture a
## tutto schermo in meno), che scorre a metà tra le loro velocità di prima.
const PARALLAX_WAREHOUSE_BACK := 0.7
const MORTAR := Color(0.25, 0.21, 0.24)
const BRICK := Color(0.33, 0.23, 0.23)
const BRICK_DARK := Color(0.27, 0.19, 0.2)
const SILL := Color(0.4, 0.38, 0.38)
## Lato del riquadro (vetro + montante) e spessore dei montanti.
const CELL := 150.0
const MULLION := 12.0
## Ogni quanti riquadri c'è un pilastro più spesso.
const COLUMN_EVERY := 3
const COLUMN := 22.0
const BRICK_SIZE := Vector2(52, 22)

## Magazzino: parete in lamiera ondulata con fascia di cemento in basso.
const SHEET := Color(0.27, 0.27, 0.32)
const SHEET_RIB := Color(0.24, 0.24, 0.29)
const SHEET_SEAM := Color(0.2, 0.2, 0.25)
const CONCRETE := Color(0.24, 0.23, 0.26)
## Distanza tra due bande chiare della lamiera (ogni banda è larga la metà).
const RIB_STEP := 140.0
## Scaffalature: sagome piatte un po' più chiare della parete, come viste
## attraverso la polvere; quelle lontane quasi si confondono con la lamiera.
const RACK_FAR := Color(0.29, 0.29, 0.34)
const RACK_NEAR := Color(0.33, 0.33, 0.38)
const GOODS_FAR := Color(0.31, 0.3, 0.34)
const GOODS_NEAR := [Color(0.38, 0.33, 0.31), Color(0.35, 0.31, 0.3), Color(0.36, 0.34, 0.36)]
const RACK_SHADOW_OFFSET := Vector2(14, 10)
## Trave in primo piano (ferma col livello).
const GIRDER := Color(0.17, 0.17, 0.21)
const GIRDER_LIGHT := Color(0.26, 0.26, 0.31)

## Stanza abbandonata: intonaco verdognolo e umido con la carta da parati a
## righe, chiazze di intonaco scrostato, colature d'acqua e umidità che risale.
const DAMP_WALL := Color(0.29, 0.3, 0.28)
const DAMP_STRIPE := Color(0.27, 0.28, 0.26)
const DAMP_PATTERN := Color(0.31, 0.32, 0.3)
const PLASTER := Color(0.33, 0.33, 0.31)
const STAIN := Color(0.17, 0.18, 0.14)
const MOLD := Color(0.17, 0.22, 0.17)
const WALL_CRACK := Color(0.19, 0.19, 0.19)
## Boiserie marcia, con assi mancanti (buco nero dietro).
const ROT_WOOD := Color(0.24, 0.2, 0.18)
const ROT_WOOD_DARK := Color(0.19, 0.16, 0.14)
const VOID := Color(0.08, 0.08, 0.09)
const PLANK := 64.0
## Lampadine spente appese, come sagome appena più scure del muro.
const HANGING_FAR := Color(0.24, 0.25, 0.24)
const HANGING_NEAR := Color(0.21, 0.22, 0.21)
## Trave di legno in alto, fissa col livello.
const BEAM := Color(0.18, 0.15, 0.14)
const BEAM_LIGHT := Color(0.25, 0.21, 0.19)
const BEAM_HEIGHT := 46.0

## In gioco ogni strato di serra e magazzino viene disegnato una volta sola in
## una texture: migliaia di rettangoli e cerchi diventano un solo sprite per
## strato. Risoluzione della texture rispetto al livello, per strato: quelli
## sfocati o lisci reggono bene una risoluzione bassa (meno memoria).
const BAKE_SCALE := {
	"greenhouse": {BASE: 0.25, FAR: 0.4, NEAR: 0.4},
	"warehouse": {BACK: 0.5, NEAR: 0.5},
	"abandoned": {BACK: 0.5, FAR: 0.5, NEAR: 0.5, FRONT: 0.5},
}
## Lato (texel) dei riquadri in cui si dividono le texture degli strati: si
## disegnano solo quelli non vuoti.
const BAKE_TILE := 64
## Lato massimo di una texture (limite sicuro sui telefoni).
const MAX_TEXTURE := 4096.0
## Magazzino e stanza abbandonata: px di fondo lasciati sotto i bordi della
## parete in texture.
const EDGE_OVERLAP := 8.0
## Strati, dal più lontano: il fondo (questo nodo), la parete in parallasse
## del magazzino, il piano lontano, quello vicino, il velo smerigliato della
## serra e il primo piano fisso. Il primo piano della serra (telaio e mattoni)
## resta vettoriale per restare nitido: in texture servirebbe a piena
## risoluzione, troppa memoria.
const BASE := -2
const BACK := -1
const FAR := 0
const NEAR := 1
const FROST_LAYER := 2
const FRONT := 3

var _far: Node2D
var _near: Node2D
var _front: Node2D
## Solo serra: il velo smerigliato davanti alle piante.
var _frost: Node2D
## Solo magazzino: la parete di fondo, in parallasse dietro agli scaffali.
var _back: Node2D
## Strato -> texture già disegnata (vuoto finché non è pronta, o nell'editor;
## null se lo strato è vuoto).
var _baked := {}
## Strato -> parte del fondo coperta dalla texture: solo la zona dove lo
## strato disegna qualcosa (le piante stanno in una fascia vicino al pavimento,
## il resto del rettangolo trasparente costerebbe comunque alla GPU).
var _baked_rect := {}
## Strato -> riquadri non vuoti della texture: [rettangolo nel fondo,
## rettangolo nella texture]. Si disegnano solo quelli (vedi _store_baked).
var _baked_tiles := {}


func _ready() -> void:
	z_index = -10
	# Strati di serra e magazzino, disegnati sopra il fondo in quest'ordine.
	# Interni: non finiscono nella scena salvata.
	_back = _make_layer(BACK)
	_far = _make_layer(FAR)
	_near = _make_layer(NEAR)
	_frost = _make_layer(FROST_LAYER)
	_front = _make_layer(FRONT)
	if not Engine.is_editor_hint() and BAKE_SCALE.has(style):
		_bake.call_deferred()


func _make_layer(which: int) -> Node2D:
	var layer := Node2D.new()
	layer.draw.connect(_draw_layer.bind(which, layer))
	add_child(layer, false, Node.INTERNAL_MODE_FRONT)
	return layer


## Disegna ogni strato in una texture (una SubViewport per strato, aggiornata
## una volta). Finché non sono pronte gli strati si disegnano come sempre.
func _bake() -> void:
	var scales: Dictionary = BAKE_SCALE[style]
	var viewports := {}
	for which: int in scales:
		var factor := minf(scales[which], MAX_TEXTURE / maxf(rect.size.x, rect.size.y))
		var viewport := SubViewport.new()
		viewport.size = Vector2i((rect.size * factor).ceil())
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var canvas := Node2D.new()
		canvas.transform = Transform2D(0.0, Vector2(factor, factor), 0.0, -rect.position * factor)
		canvas.draw.connect(_paint.bind(which, canvas))
		if style == "greenhouse" and (which == FAR or which == NEAR):
			canvas.material = _frost_material()
		viewport.add_child(canvas)
		add_child(viewport, false, Node.INTERNAL_MODE_BACK)
		viewports[which] = viewport
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	# Il disegno sullo sfondo trasparente lascia i colori premoltiplicati per
	# l'alpha: gli sprite li fondono di conseguenza.
	var premultiplied := CanvasItemMaterial.new()
	premultiplied.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	for which: int in viewports:
		var viewport: SubViewport = viewports[which]
		_store_baked(which, viewport.get_texture().get_image())
		viewport.queue_free()
		var layer := _layer(which)
		layer.material = premultiplied
		layer.queue_redraw()
	# Magazzino: ora che la parete è in texture il fondo disegna solo i bordi.
	queue_redraw()
	# Serra: il velo ora è dentro le piante.
	_frost.queue_redraw()


func _layer(which: int) -> CanvasItem:
	match which:
		BACK: return _back
		FAR: return _far
		NEAR: return _near
		FROST_LAYER: return _frost
		FRONT: return _front
	return self


func _refresh() -> void:
	queue_redraw()
	for layer in [_back, _far, _near, _frost, _front]:
		if layer:
			layer.queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or style == "room":
		return
	# Solo in orizzontale: in verticale piante e scaffali si staccherebbero
	# dal pavimento.
	var screen_center := get_viewport().get_canvas_transform().affine_inverse() * (get_viewport_rect().size / 2.0)
	var shift := to_local(screen_center).x - rect.get_center().x
	var back_parallax := PARALLAX_WAREHOUSE_BACK if style == "warehouse" else PARALLAX_WALL
	if style != "greenhouse" and _back.position.x != shift * back_parallax:
		queue_redraw()
	_back.position.x = shift * back_parallax
	_far.position.x = shift * PARALLAX_FAR
	_near.position.x = shift * PARALLAX_NEAR


func _draw() -> void:
	if style == "room":
		_draw_room()
	else:
		_draw_layer(BASE, self)


## Uno strato: la texture se è pronta, altrimenti il disegno vero e proprio.
func _draw_layer(which: int, canvas: CanvasItem) -> void:
	# Serra: il velo è già dentro le texture delle piante (_frost_material).
	if which == FROST_LAYER and style == "greenhouse" and _baked.has(NEAR):
		return
	if _baked.has(which):
		# Riquadri della stessa texture: un solo draw call. Niente clip_uv,
		# così ai bordi tra riquadri il filtro legge i texel vicini come prima.
		for tile: Array in _baked_tiles.get(which, []):
			canvas.draw_texture_rect_region(_baked[which], tile[0], tile[1], Color.WHITE, false, false)
	else:
		_paint(which, canvas)


## Salva lo strato cotto tenendo solo la parte con qualcosa disegnato (più un
## bordo trasparente, così il filtro ai margini resta identico). Ogni pixel
## della texture resta dove era: cambia solo quanto rettangolo si disegna.
func _store_baked(which: int, image: Image) -> void:
	var used := image.get_used_rect()
	if not used.has_area():
		_baked[which] = null
		return
	used = used.grow(2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var texel := rect.size / Vector2(image.get_size())
	var cropped := image.get_region(used)
	_baked[which] = ImageTexture.create_from_image(cropped)
	_baked_rect[which] = Rect2(rect.position + Vector2(used.position) * texel, Vector2(used.size) * texel)
	# Dentro il ritaglio il disegno può essere sparso (scaffali, piante): si
	# tengono solo i riquadri con qualcosa, controllando anche 1 texel attorno
	# perché il filtro ai bordi del riquadro legge i vicini.
	var tiles := []
	var bounds := Rect2i(Vector2i.ZERO, cropped.get_size())
	for y in range(0, cropped.get_height(), BAKE_TILE):
		for x in range(0, cropped.get_width(), BAKE_TILE):
			var tile := Rect2i(x, y, BAKE_TILE, BAKE_TILE).intersection(bounds)
			if cropped.get_region(tile.grow(1).intersection(bounds)).is_invisible():
				continue
			var source := Rect2(tile)
			tiles.append([Rect2(_baked_rect[which].position + source.position * texel, source.size * texel), source])
	_baked_tiles[which] = tiles


## Serra: le piante si cuociono già viste attraverso il velo smerigliato,
## invece di disegnare il velo come strato a tutto schermo sopra di loro. Il
## velo è il vetro di fondo al FROST di opacità: sopra una pianta equivale a
## mescolarne il colore al FROST con quello del vetro alla stessa altezza.
## La parallasse è solo orizzontale e il vetro sfuma solo in verticale, quindi
## il risultato non cambia (a parte le piccole differenze tra una lastra e
## l'altra, sotto l'1%).
func _frost_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float top;
uniform float bottom;
uniform float frost;
uniform vec4 glass_top;
uniform vec4 glass_bottom;
varying float y;

void vertex() {
	y = VERTEX.y;
}

void fragment() {
	if (y >= top && y < bottom) {
		float t = clamp(1.0 - (y - top) / max(bottom - top, 1.0), 0.0, 1.0);
		COLOR.rgb = mix(COLOR.rgb, mix(glass_bottom.rgb, glass_top.rgb, t), frost);
	}
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("top", rect.position.y)
	material.set_shader_parameter("bottom", wainscot_y)
	material.set_shader_parameter("frost", FROST)
	material.set_shader_parameter("glass_top", GLASS_TOP)
	material.set_shader_parameter("glass_bottom", GLASS_BOTTOM)
	return material


## Ogni pixel si colora una volta sola: la parete va solo tra le strisce e
## sopra la zoccolatura (sui telefoni ogni strato a tutto schermo costa).
func _draw_room() -> void:
	if wainscot_y <= rect.position.y or wainscot_y >= rect.end.y:
		draw_rect(rect, WALL)
	var x := rect.position.x
	while x < rect.end.x:
		draw_rect(Rect2(x, rect.position.y, STRIPE_STEP / 2.0, wainscot_y - rect.position.y), STRIPE)
		var wall_x := x + STRIPE_STEP / 2.0
		if wall_x < rect.end.x and wainscot_y > rect.position.y:
			draw_rect(Rect2(wall_x, rect.position.y, minf(STRIPE_STEP / 2.0, rect.end.x - wall_x), minf(wainscot_y, rect.end.y) - rect.position.y), WALL)
		x += STRIPE_STEP
	draw_rect(Rect2(rect.position.x, wainscot_y, rect.size.x, rect.end.y - wainscot_y), PANEL)
	draw_rect(Rect2(rect.position.x, wainscot_y - 6.0, rect.size.x, 12.0), MOLDING)


## Disegna lo strato `which` dello stile attuale su `canvas`.
func _paint(which: int, canvas: CanvasItem) -> void:
	if style == "greenhouse":
		match which:
			BASE: _draw_glass(canvas, 1.0)
			FAR, NEAR: _draw_foliage(canvas, which == NEAR)
			FROST_LAYER: _draw_glass(canvas, FROST)
			FRONT: _draw_front(canvas)
	elif style == "warehouse":
		match which:
			# Riempie i bordi che la parete in parallasse lascia scoperti.
			BASE: _draw_sheet_gap(canvas)
			BACK:
				_draw_sheet_wall(canvas)
				_draw_racks(canvas, false)
			NEAR: _draw_racks(canvas, true)
			FRONT: _draw_girder(canvas)
	elif style == "abandoned":
		match which:
			BASE: _draw_sheet_gap(canvas)
			BACK: _draw_damp_wall(canvas)
			FAR, NEAR: _draw_hanging_bulbs(canvas, which == NEAR)
			FRONT: _draw_beam(canvas)


## Fondo di magazzino e stanza abbandonata: la parete in parallasse (opaca) lo copre tutto tranne
## la striscia che lascia scoperta scorrendo; quando è già in texture si
## disegna solo quella (sui telefoni ogni strato a tutto schermo costa).
func _draw_sheet_gap(canvas: CanvasItem) -> void:
	var color := SHEET if style == "warehouse" else DAMP_WALL
	if not _baked.has(BACK):
		canvas.draw_rect(rect, color)
		return
	# Una striscia per lato, con qualche px sotto la parete: i bordi della
	# texture (a mezza risoluzione) possono essere semitrasparenti.
	var offset := _back.position.x
	var left := minf(maxf(offset, 0.0) + EDGE_OVERLAP, rect.size.x)
	var right := minf(maxf(-offset, 0.0) + EDGE_OVERLAP, rect.size.x)
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y, left, rect.size.y), color)
	canvas.draw_rect(Rect2(rect.end.x - right, rect.position.y, right, rect.size.y), color)
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, EDGE_OVERLAP), color)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - EDGE_OVERLAP, rect.size.x, EDGE_OVERLAP), color)


## Lastre di vetro: sfumatura verticale continua, con piccole differenze tra
## lastre. Disegnate piene come luce di fondo e semitrasparenti come velo.
## Ogni lastra copre anche il montante (che ci va sopra): nelle texture a bassa
## risoluzione i bordi sfumati non lasciano aloni accanto al telaio.
func _draw_glass(canvas: CanvasItem, alpha: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	var top := rect.position.y
	var area := Rect2(rect.position.x, top, rect.size.x, wainscot_y - top)
	var span := maxf(area.size.y, 1.0)
	var y := top
	while y < wainscot_y:
		var x := rect.position.x
		while x < rect.end.x:
			var pane := Rect2(x - MULLION / 2.0, y - MULLION / 2.0, CELL, CELL).intersection(area)
			if pane.has_area():
				var shade := rng.randf_range(-0.025, 0.025)
				var c_top := GLASS_BOTTOM.lerp(GLASS_TOP, 1.0 - (pane.position.y - top) / span)
				var c_bottom := GLASS_BOTTOM.lerp(GLASS_TOP, 1.0 - (pane.end.y - top) / span)
				c_top = c_top.lightened(shade) if shade > 0.0 else c_top.darkened(-shade)
				c_bottom = c_bottom.lightened(shade) if shade > 0.0 else c_bottom.darkened(-shade)
				c_top.a = alpha
				c_bottom.a = alpha
				canvas.draw_polygon(_rect_polygon(pane), PackedColorArray([c_top, c_top, c_bottom, c_bottom]))
			x += CELL
		y += CELL


## Piante dietro il vetro: macchie sfocate (cerchi concentrici trasparenti).
## Restano dentro il fondo: scorrendo escono solo dai lati che la telecamera
## non inquadra.
func _draw_foliage(layer: CanvasItem, near: bool) -> void:
	var color := FOLIAGE_NEAR if near else FOLIAGE_FAR
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern * 2 + (1 if near else 0)
	var size_range := Vector2(90.0, 180.0) if near else Vector2(60.0, 130.0)
	var tall_chance := 0.25 if near else 0.5
	var x := rect.position.x + 60.0 + rng.randf_range(0.0, 80.0)
	while x < rect.end.x - 60.0:
		# Il raggio non supera i bordi del fondo.
		var radius := minf(rng.randf_range(size_range.x, size_range.y), minf(x - rect.position.x, rect.end.x - x))
		var center := Vector2(x, wainscot_y - rng.randf_range(0.0, radius * (0.4 if near else 0.9)))
		for ring in 4:
			layer.draw_circle(center, radius * (1.0 - ring * 0.18), Color(color, 0.18 + ring * 0.1))
		# Ogni tanto una pianta più alta, a ciuffo.
		if rng.randf() < tall_chance:
			var tall := Vector2(x + rng.randf_range(-30.0, 30.0), center.y - radius - rng.randf_range(60.0, 200.0))
			layer.draw_line(tall, Vector2(tall.x, wainscot_y), Color(color, 0.45), 12.0 if near else 8.0)
			for ring in 3:
				layer.draw_circle(tall, radius * (0.55 - ring * 0.12), Color(color, 0.18 + ring * 0.1))
		x += rng.randf_range(130.0, 240.0) if near else rng.randf_range(90.0, 170.0)


## Telaio e muretto davanti al velo smerigliato. Disegnati per tipo (prima
## tutti i rettangoli, poi le linee, poi i cerchi): alternarli spezzerebbe i
## batch del renderer in centinaia di draw call.
func _draw_front(canvas: CanvasItem) -> void:
	var top := rect.position.y
	var glass_bottom := wainscot_y
	# Telaio: pilastri più spessi ogni tanto.
	var col := 0
	var gx := rect.position.x
	while gx <= rect.end.x:
		var width := COLUMN if col % COLUMN_EVERY == 0 else MULLION
		canvas.draw_rect(Rect2(gx - width / 2.0, top, width, glass_bottom - top), IRON)
		gx += CELL
		col += 1
	var gy := top
	while gy <= glass_bottom:
		canvas.draw_rect(Rect2(rect.position.x, gy - MULLION / 2.0, rect.size.x, MULLION), IRON)
		gy += CELL

	# Muretto di mattoni sotto le vetrate, con davanzale.
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	var wall := Rect2(rect.position.x, glass_bottom, rect.size.x, rect.end.y - glass_bottom)
	canvas.draw_rect(wall, MORTAR)
	var row := 0
	var y := wall.position.y
	while y < wall.end.y:
		var bx := wall.position.x - (BRICK_SIZE.x / 2.0 if row % 2 == 1 else 0.0)
		while bx < wall.end.x:
			var brick := Rect2(bx + 2.0, y + 2.0, BRICK_SIZE.x - 4.0, BRICK_SIZE.y - 4.0).intersection(wall)
			if brick.has_area():
				canvas.draw_rect(brick, BRICK.lerp(BRICK_DARK, rng.randf()))
			bx += BRICK_SIZE.x
		y += BRICK_SIZE.y
		row += 1
	canvas.draw_rect(Rect2(rect.position.x, glass_bottom - 8.0, rect.size.x, 16.0), SILL)
	canvas.draw_rect(Rect2(rect.position.x, glass_bottom + 8.0, rect.size.x, 4.0), MORTAR)

	# Profilo chiaro sui pilastri e riflesso in un angolo di ogni lastra: una
	# sola multiline per tipo.
	var profiles := PackedVector2Array()
	var shine_wide := PackedVector2Array()
	var shine_thin := PackedVector2Array()
	col = 0
	gx = rect.position.x
	while gx <= rect.end.x:
		if col % COLUMN_EVERY == 0:
			var lx := gx - COLUMN / 2.0 + 3.0
			# Finisce sul davanzale, che ora è disegnato prima.
			profiles.append_array([Vector2(lx, top), Vector2(lx, glass_bottom - 8.0)])
		gx += CELL
		col += 1
	gy = top
	while gy < glass_bottom:
		gx = rect.position.x
		while gx < rect.end.x:
			var corner := Vector2(gx + MULLION / 2.0 + 10.0, gy + MULLION / 2.0 + 10.0)
			if corner.y + 40.0 < glass_bottom:
				shine_wide.append_array([corner + Vector2(0, 40), corner + Vector2(40, 0)])
				shine_thin.append_array([corner + Vector2(0, 62), corner + Vector2(62, 0)])
			gx += CELL
		gy += CELL
	canvas.draw_multiline(profiles, IRON_LIGHT, 2.0)
	canvas.draw_multiline(shine_wide, GLASS_SHINE, 4.0)
	canvas.draw_multiline(shine_thin, GLASS_SHINE, 2.0)
	# Bulloni agli incroci: tutti con la stessa texture, così stanno in un batch
	# (draw_circle genera decine di vertici per cerchio).
	var bolt := ShadowPlatform.circle_texture()
	gy = top
	while gy < glass_bottom:
		gx = rect.position.x
		while gx < rect.end.x:
			canvas.draw_texture_rect(bolt, Rect2(gx - 4.0, gy - 4.0, 8.0, 8.0), false, IRON_LIGHT)
			gx += CELL
		gy += CELL

## Magazzino: lamiera a bande larghe, giunte orizzontali e fascia di cemento.
func _draw_sheet_wall(canvas: CanvasItem) -> void:
	var top := rect.position.y
	canvas.draw_rect(rect, SHEET)
	var x := rect.position.x
	while x < rect.end.x:
		canvas.draw_rect(Rect2(x, top, minf(RIB_STEP / 2.0, rect.end.x - x), wainscot_y - top), SHEET_RIB)
		x += RIB_STEP
	var y := top + 300.0
	while y < wainscot_y:
		canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), SHEET_SEAM, 4.0)
		y += 300.0
	canvas.draw_rect(Rect2(rect.position.x, wainscot_y, rect.size.x, rect.end.y - wainscot_y), CONCRETE)
	canvas.draw_line(Vector2(rect.position.x, wainscot_y), Vector2(rect.end.x, wainscot_y), SHEET_SEAM, 6.0)


## Scaffalature su un piano, come sagome piatte senza dettagli: quelle
## lontane alte, sottili e quasi del colore della parete; quelle vicine basse e
## robuste, con poche scatole, qualche pila a terra e qualche scala. Restano
## dentro il fondo: scorrendo escono solo dai lati che la telecamera non
## inquadra.
func _draw_racks(canvas: CanvasItem, near: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern * 2 + (1 if near else 0)
	var floor_y := rect.end.y
	var bay := 300.0 if near else 200.0
	var x := rect.position.x + rng.randf_range(40.0, 260.0)
	while true:
		var bays := mini(rng.randi_range(2, 3), int((rect.end.x - 40.0 - x) / bay))
		if bays < 1:
			break
		var levels := rng.randi_range(2, 3)
		if not near:
			var most := clampi(int((floor_y - rect.position.y - 200.0) / 170.0), 2, 7)
			levels = rng.randi_range(most - 1, most)
		_draw_rack(canvas, Vector2(x, floor_y), bays, levels, near, rng)
		x += bays * bay
		# Nello spazio tra uno scaffale e l'altro, a volte una pila o una scala.
		var space := rng.randf_range(180.0, 420.0) if near else rng.randf_range(120.0, 300.0)
		if near and x + space < rect.end.x - 40.0:
			var roll := rng.randf()
			if roll < 0.35:
				_draw_floor_stack(canvas, Vector2(x + space / 2.0, floor_y), rng)
			elif roll < 0.55:
				_draw_ladder(canvas, Vector2(x + space * 0.3, floor_y), rng)
		x += space


## Scaffale di `bays` campate e `levels` ripiani, appoggiato in `base`
## (spigolo in basso a sinistra).
func _draw_rack(canvas: CanvasItem, base: Vector2, bays: int, levels: int, near: bool, rng: RandomNumberGenerator) -> void:
	var bay := 300.0 if near else 200.0
	var gap := 230.0 if near else 170.0
	var upright := 16.0 if near else 8.0
	var beam := 20.0 if near else 8.0
	var color := RACK_NEAR if near else RACK_FAR
	var top := base.y - levels * gap - beam
	canvas.draw_rect(Rect2(Vector2(base.x, top) + RACK_SHADOW_OFFSET, Vector2(bays * bay + upright, base.y - top)), Color(0, 0, 0, rack_shadow_opacity))
	# Merce: a terra e su ogni ripiano, poca e sparsa.
	for level in levels + 1:
		var shelf_y := base.y - level * gap
		var height := gap - beam - 16.0 if level < levels else gap * 0.5
		for b in bays:
			if rng.randf() > (0.15 if level == levels else 0.4):
				continue
			var area := Rect2(base.x + b * bay + upright, shelf_y - height, bay - upright, height)
			_draw_goods(canvas, area, near, rng)
	for b in bays + 1:
		canvas.draw_rect(Rect2(base.x + b * bay, top, upright, base.y - top), color)
	for level in range(1, levels + 1):
		canvas.draw_rect(Rect2(base.x, base.y - level * gap, bays * bay + upright, beam), color)


## Una o due scatole (a volte con una più piccola sopra) appoggiate sul fondo
## di `area`.
func _draw_goods(canvas: CanvasItem, area: Rect2, near: bool, rng: RandomNumberGenerator) -> void:
	var x := area.position.x + rng.randf_range(0.05, 0.3) * area.size.x
	for i in rng.randi_range(1, 2):
		var size := Vector2(rng.randf_range(0.25, 0.4), rng.randf_range(0.4, 0.75)) * area.size
		if x + size.x > area.end.x - 6.0:
			break
		_draw_box(canvas, Rect2(x, area.end.y - size.y, size.x, size.y), near, rng)
		if near and rng.randf() < 0.3:
			var small := size * Vector2(0.7, 0.5)
			_draw_box(canvas, Rect2(x + (size.x - small.x) / 2.0, area.end.y - size.y - small.y, small.x, small.y), near, rng)
		x += size.x + rng.randf_range(6.0, 30.0)


## Scatola piatta: un colore e, vicino, un'ombra sul fondo.
func _draw_box(canvas: CanvasItem, r: Rect2, near: bool, rng: RandomNumberGenerator) -> void:
	var color: Color = GOODS_NEAR[rng.randi() % GOODS_NEAR.size()] if near else GOODS_FAR
	canvas.draw_rect(r, color)
	if near:
		canvas.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * 0.18, r.size.x, r.size.y * 0.18), color.darkened(0.12))


## Pila di scatole a terra, più stretta salendo.
func _draw_floor_stack(canvas: CanvasItem, base: Vector2, rng: RandomNumberGenerator) -> void:
	var width := rng.randf_range(110.0, 170.0)
	var y := base.y
	for i in rng.randi_range(2, 4):
		var height := rng.randf_range(70.0, 110.0)
		var offset := rng.randf_range(-12.0, 12.0)
		var box := Rect2(base.x - width / 2.0 + offset, y - height, width, height)
		canvas.draw_rect(Rect2(box.position + RACK_SHADOW_OFFSET, box.size), Color(0, 0, 0, rack_shadow_opacity))
		_draw_box(canvas, box, true, rng)
		y -= height
		width *= rng.randf_range(0.8, 0.95)


## Scala a pioli appoggiata (sagoma).
func _draw_ladder(canvas: CanvasItem, base: Vector2, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(420.0, 620.0)
	var bottom_l := base
	var bottom_r := base + Vector2(70.0, 0)
	var top_l := base + Vector2(height * 0.18, -height)
	var top_r := top_l + Vector2(56.0, 0)
	canvas.draw_line(bottom_l, top_l, RACK_NEAR, 10.0)
	canvas.draw_line(bottom_r, top_r, RACK_NEAR, 10.0)
	var rungs := int(height / 60.0)
	for i in range(1, rungs):
		var t := float(i) / rungs
		canvas.draw_line(bottom_l.lerp(top_l, t), bottom_r.lerp(top_r, t), RACK_NEAR, 6.0)


## Trave in alto, davanti agli scaffali (disegnata direttamente: è una
## striscia sottile, in texture costerebbe di più).
func _draw_girder(canvas: CanvasItem) -> void:
	var top := rect.position.y
	canvas.draw_rect(Rect2(rect.position.x, top, rect.size.x, 40.0), GIRDER)
	canvas.draw_line(Vector2(rect.position.x, top + 38.0), Vector2(rect.end.x, top + 38.0), GIRDER_LIGHT, 4.0)


## Stanza abbandonata: parete umida in parallasse. Prima tutto ciò che sta
## "sotto" (carta, intonaco, mattoni), poi macchie e crepe sopra.
func _draw_damp_wall(canvas: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern
	var top := rect.position.y
	var wall := Rect2(rect.position.x, top, rect.size.x, wainscot_y - top)
	canvas.draw_rect(rect, DAMP_WALL)
	# Carta da parati: righe larghe e un motivo a rombi, sbiadito.
	var x := rect.position.x
	while x < rect.end.x:
		canvas.draw_rect(Rect2(x, top, minf(STRIPE_STEP / 2.0, rect.end.x - x), wall.size.y), DAMP_STRIPE)
		x += STRIPE_STEP
	var diamonds := PackedVector2Array()
	var dy := top + 70.0
	var row := 0
	while dy < wainscot_y - 40.0:
		var dx := rect.position.x + STRIPE_STEP * (0.75 if row % 2 == 0 else 0.25)
		while dx < rect.end.x:
			var d := [Vector2(dx, dy - 14), Vector2(dx + 9, dy), Vector2(dx, dy + 14), Vector2(dx - 9, dy)]
			for i in 4:
				diamonds.append_array([d[i], d[(i + 1) % 4]])
			dx += STRIPE_STEP
		dy += 90.0
		row += 1
	canvas.draw_multiline(diamonds, DAMP_PATTERN, 2.0)
	# Intonaco scrostato: chiazze irregolari.
	for i in maxi(2, int(rect.size.x * wall.size.y / 260000.0)):
		var center := Vector2(rng.randf_range(wall.position.x, wall.end.x), rng.randf_range(top + 80, wainscot_y - 60))
		var radius := Vector2(rng.randf_range(50, 140), rng.randf_range(35, 90))
		var patch := PackedVector2Array()
		for k in 14:
			var angle := k * TAU / 14.0
			patch.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * rng.randf_range(0.65, 1.1))
		canvas.draw_colored_polygon(patch, PLASTER)
		patch.append(patch[0])
		canvas.draw_polyline(patch, DAMP_STRIPE, 2.0)
	# Colature d'acqua dall'alto e umidità che risale dalla boiserie.
	for i in maxi(2, int(rect.size.x / 260.0)):
		var sx := rng.randf_range(wall.position.x, wall.end.x)
		var width := rng.randf_range(30, 120)
		var length := rng.randf_range(150, minf(700, wall.size.y))
		var clear := Color(STAIN, 0.0)
		var dark := Color(STAIN, rng.randf_range(0.25, 0.45))
		canvas.draw_polygon(PackedVector2Array([
			Vector2(sx, top), Vector2(sx + width, top), Vector2(sx + width * 0.7, top + length), Vector2(sx + width * 0.35, top + length),
		]), PackedColorArray([dark, dark, clear, clear]))
	var damp := PackedVector2Array()
	var damp_colors := PackedColorArray()
	var step := 40.0
	var wx := rect.position.x
	while wx <= rect.end.x + step:
		var rise := rng.randf_range(60, 200)
		damp.append_array([Vector2(wx, wainscot_y - rise), Vector2(wx, wainscot_y)])
		damp_colors.append_array([Color(MOLD, 0.0), Color(MOLD, 0.55)])
		wx += step
	for i in range(0, damp.size() - 2, 2):
		canvas.draw_polygon(PackedVector2Array([damp[i], damp[i + 2], damp[i + 3], damp[i + 1]]),
				PackedColorArray([damp_colors[i], damp_colors[i + 2], damp_colors[i + 3], damp_colors[i + 1]]))
	# Crepe lunghe nell'intonaco.
	for i in maxi(1, int(rect.size.x / 600.0)):
		var crack := PackedVector2Array([Vector2(rng.randf_range(wall.position.x, wall.end.x), rng.randf_range(top, top + wall.size.y * 0.5))])
		var angle := rng.randf_range(PI * 0.3, PI * 0.7)
		for k in rng.randi_range(8, 16):
			angle += rng.randf_range(-0.5, 0.5)
			crack.append(crack[crack.size() - 1] + Vector2.from_angle(angle) * rng.randf_range(14, 30))
		canvas.draw_polyline(crack, WALL_CRACK, 2.5)
	_draw_rotten_wainscot(canvas, rng)


## Boiserie di assi verticali: alcune scurite, alcune spezzate o mancanti.
func _draw_rotten_wainscot(canvas: CanvasItem, rng: RandomNumberGenerator) -> void:
	var area := Rect2(rect.position.x, wainscot_y, rect.size.x, rect.end.y - wainscot_y)
	if not area.has_area():
		return
	canvas.draw_rect(area, ROT_WOOD)
	var x := area.position.x
	while x < area.end.x:
		var plank := Rect2(x, area.position.y, minf(PLANK, area.end.x - x), area.size.y)
		var roll := rng.randf()
		if roll < 0.12:
			# Asse mancante: buio dietro, con il bordo superiore spezzato.
			var stub := rng.randf_range(10, 50)
			canvas.draw_rect(Rect2(plank.position.x + 3, plank.position.y + stub, plank.size.x - 6, plank.size.y - stub), VOID)
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(plank.position.x + 3, plank.position.y + stub), Vector2(plank.end.x - 3, plank.position.y + stub),
				Vector2(plank.end.x - 3, plank.position.y + stub + rng.randf_range(10, 40)),
				Vector2(plank.position.x + plank.size.x * 0.4, plank.position.y + stub + rng.randf_range(4, 18)),
				Vector2(plank.position.x + 3, plank.position.y + stub + rng.randf_range(15, 45)),
			]), ROT_WOOD)
		elif roll < 0.45:
			canvas.draw_rect(plank.grow_individual(-3, 0, -3, 0), ROT_WOOD_DARK)
		canvas.draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), ROT_WOOD_DARK, 3.0)
		x += PLANK
	canvas.draw_rect(Rect2(area.position.x, wainscot_y - 6.0, area.size.x, 12.0), ROT_WOOD_DARK)


## File di lampadine spente appese al soffitto, come sagome: quelle lontane
## piccole, fitte e quasi del colore del muro; quelle vicine più grandi e
## scure. Alcuni fili hanno solo il portalampada vuoto.
func _draw_hanging_bulbs(canvas: CanvasItem, near: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern * 2 + (1 if near else 0)
	var color := HANGING_NEAR if near else HANGING_FAR
	var scale_factor := 0.5 if near else 0.32
	var top := rect.position.y + BEAM_HEIGHT
	var max_drop := minf(wainscot_y - top - 220.0, 620.0 if near else 480.0)
	if max_drop < 80.0:
		return
	var x := rect.position.x + rng.randf_range(40.0, 160.0)
	var cords := PackedVector2Array()
	while x < rect.end.x - 40.0:
		var drop := rng.randf_range(80.0, max_drop)
		var end := Vector2(x, top + drop)
		cords.append_array([Vector2(x, top), end])
		if rng.randf() < 0.2:
			# Solo il portalampada, la lampadina non c'è più.
			canvas.draw_rect(Rect2(end.x - 10.0 * scale_factor * 2.0, end.y, 20.0 * scale_factor * 2.0, 26.0 * scale_factor * 2.0), color)
		else:
			var tilt := rng.randf_range(-0.15, 0.15)
			canvas.draw_set_transform(end, PI + tilt, Vector2.ONE * scale_factor)
			canvas.draw_rect(Rect2(-17, -34, 34, 34), color)
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(-27, -46), Vector2(27, -46), Vector2(17, -32), Vector2(-17, -32)
			]), color)
			canvas.draw_circle(Vector2(0, -68), 38.0, color)
			canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
		x += rng.randf_range(160.0, 320.0) if near else rng.randf_range(70.0, 150.0)
	canvas.draw_multiline(cords, color, 4.0 if near else 2.5)


## Trave di legno sotto il soffitto, con le colature d'umidità che scendono.
func _draw_beam(canvas: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern * 7
	var top := rect.position.y
	canvas.draw_rect(Rect2(rect.position.x, top, rect.size.x, BEAM_HEIGHT), BEAM)
	canvas.draw_line(Vector2(rect.position.x, top + BEAM_HEIGHT - 2.0), Vector2(rect.end.x, top + BEAM_HEIGHT - 2.0), BEAM_LIGHT, 4.0)
	# Venature e spaccature del legno.
	var grain := PackedVector2Array()
	for i in int(rect.size.x / 120.0):
		var gx := rng.randf_range(rect.position.x, rect.end.x)
		var gy := top + rng.randf_range(8, BEAM_HEIGHT - 12)
		grain.append_array([Vector2(gx, gy), Vector2(gx + rng.randf_range(40, 160), gy + rng.randf_range(-3, 3))])
	canvas.draw_multiline(grain, BEAM_LIGHT, 1.5)
	# Colature scure che scendono dalla trave.
	for i in int(rect.size.x / 200.0):
		var sx := rng.randf_range(rect.position.x, rect.end.x)
		var length := rng.randf_range(20, 90)
		canvas.draw_line(Vector2(sx, top + BEAM_HEIGHT), Vector2(sx, top + BEAM_HEIGHT + length), Color(STAIN, 0.5), rng.randf_range(3, 7))
		canvas.draw_circle(Vector2(sx, top + BEAM_HEIGHT + length), 3.5, Color(STAIN, 0.5))


func _rect_polygon(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
