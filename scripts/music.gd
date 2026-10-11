extends Node
## Musica di sottofondo (autoload): la canzoncina in loop su tutte le scene.
## Il WAV si rigenera con sounds/make_sfx.py.

const SONG := preload("res://sounds/music.wav")
const VOLUME_DB := -6.0
## Di quanto si abbassa la musica mentre suona un jingle (es. la vittoria).
const DUCK_DB := -18.0

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.stream = SONG
	_player.bus = &"Music"
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_player.play()


## Abbassa la musica per qualche secondo, poi la riporta su piano piano.
func duck(seconds: float) -> void:
	var tween := _player.create_tween()
	tween.tween_property(_player, "volume_db", VOLUME_DB + DUCK_DB, 0.15)
	tween.tween_interval(seconds)
	tween.tween_property(_player, "volume_db", VOLUME_DB, 1.0)
