extends Node
## Musica di sottofondo (autoload): la canzoncina in loop su tutte le scene.
## Il WAV si rigenera con sounds/make_sfx.py.

const SONG := preload("res://sounds/music.wav")
const VOLUME_DB := -6.0
## Di quanto si abbassa la musica mentre suona un jingle (es. la vittoria).
const DUCK_DB := -18.0
## Duck "spettrale" a ogni flash: invece di abbassare tutta la musica scava solo le
## frequenze dove sta il flash (accordo 700-1400 Hz, luccichii fino a 3 kHz). Bassi e
## alti restano, così anche sugli altoparlanti del telefono non si sente un "buco".
## Bande di AudioEffectEQ6 (32, 100, 320, 1000, 3200, 10000 Hz) -> dB al massimo del duck.
const FLASH_DUCK_BANDS := {2: -2.0, 3: -6.0, 4: -4.0}
const FLASH_DUCK_ATTACK := 0.03
const FLASH_DUCK_HOLD := 0.15
const FLASH_DUCK_RELEASE := 0.5

var _player: AudioStreamPlayer
## EQ sul bus Music, separato dal volume del player (jingle) e del bus (impostazioni).
var _flash_eq := AudioEffectEQ6.new()
var _flash_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.stream = SONG
	_player.bus = &"Music"
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_player.play()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(_player.bus), _flash_eq)


## Abbassa la musica per qualche secondo, poi la riporta su piano piano.
func duck(seconds: float) -> void:
	var tween := _player.create_tween()
	tween.tween_property(_player, "volume_db", VOLUME_DB + DUCK_DB, 0.15)
	tween.tween_interval(seconds)
	tween.tween_property(_player, "volume_db", VOLUME_DB, 1.0)


## Fa spazio al flash nella musica e la riporta com'era in mezzo secondo.
func duck_flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_duck, 0.0, 1.0, FLASH_DUCK_ATTACK)
	_flash_tween.tween_interval(FLASH_DUCK_HOLD)
	_flash_tween.tween_method(_set_flash_duck, 1.0, 0.0, FLASH_DUCK_RELEASE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## depth: 0 = musica intatta, 1 = duck pieno.
func _set_flash_duck(depth: float) -> void:
	for band in FLASH_DUCK_BANDS:
		_flash_eq.set_band_gain_db(band, FLASH_DUCK_BANDS[band] * depth)
