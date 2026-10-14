extends Node
## Musica di sottofondo (autoload): una canzone in loop, che continua tra una
## scena e l'altra. Ogni livello sceglie la sua (Level.music); il menu torna
## sempre a "main". I WAV si rigenerano con tools/make_sfx.py.

const SONGS := {
	"main": preload("res://sounds/music.wav"),
	"dark": preload("res://sounds/music_dark.wav"),
	"greenhouse": preload("res://sounds/music_greenhouse.wav"),
}
## Secondi di dissolvenza incrociata quando si cambia canzone.
const CROSSFADE := 1.5
const VOLUME_DB := -20.0
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
var _song := "main"
## EQ sul bus Music, separato dal volume del player (jingle) e del bus (impostazioni).
var _flash_eq := AudioEffectEQ6.new()
var _flash_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = _make_player(_song)
	_player.play()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(_player.bus), _flash_eq)


## Passa alla canzone `song` (chiave di SONGS) con una dissolvenza incrociata.
## Se sta già suonando non fa niente: la canzone continua da dov'era.
func play_song(song: String) -> void:
	if song == _song or not SONGS.has(song):
		return
	_song = song
	var old := _player
	var fade_out := old.create_tween()
	fade_out.tween_property(old, "volume_db", -60.0, CROSSFADE)
	fade_out.tween_callback(old.queue_free)
	_player = _make_player(song)
	_player.volume_db = -60.0
	_player.play()
	var fade_in := _player.create_tween()
	fade_in.tween_property(_player, "volume_db", VOLUME_DB, CROSSFADE) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _make_player(song: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = SONGS[song]
	player.bus = &"Music"
	player.volume_db = VOLUME_DB
	add_child(player)
	return player


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
