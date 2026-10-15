extends Node
## Impostazioni del giocatore (volume e luminosità), salvate sul dispositivo.
## I volumi sono lineari (0..1) e vengono applicati ai bus audio "Music" e "SFX".

## Cambiata la luminosità della stanza buia (0..1).
signal brightness_changed(value: float)

const SAVE_PATH := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const DEFAULT_VOLUME := 0.8
const DEFAULT_BRIGHTNESS := 0.5

## Se false le impostazioni non vengono scritte su disco (test automatici).
var persist := true

var music_volume := DEFAULT_VOLUME
var sfx_volume := DEFAULT_VOLUME
var brightness := DEFAULT_BRIGHTNESS


func _ready() -> void:
	# Interpolazione fisica attiva nel progetto ma spenta per tutti: la accende
	# solo la lampadina in gioco (game.gd). Il resto si muove in _process e
	# interpolato andrebbe a scatti o in ritardo.
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		music_volume = clampf(float(config.get_value("audio", "music", DEFAULT_VOLUME)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx", DEFAULT_VOLUME)), 0.0, 1.0)
		brightness = clampf(float(config.get_value("video", "brightness", DEFAULT_BRIGHTNESS)), 0.0, 1.0)
	_apply(MUSIC_BUS, music_volume)
	_apply(SFX_BUS, sfx_volume)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply(MUSIC_BUS, music_volume)
	_save()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply(SFX_BUS, sfx_volume)
	_save()


func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.0, 1.0)
	brightness_changed.emit(brightness)
	_save()


## Imposta il volume del bus; a zero il bus viene silenziato del tutto.
func _apply(bus_name: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, value <= 0.0)
	if value > 0.0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(value))


func _save() -> void:
	if not persist:
		return
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("video", "brightness", brightness)
	config.save(SAVE_PATH)
