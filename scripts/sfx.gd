extends Node
## Effetti sonori (autoload): suona i suoni non posizionali e aggiunge il "tap"
## a ogni pulsante dell'interfaccia. I WAV si rigenerano con tools/make_sfx.py.

const SOUNDS := {
	"jump": preload("res://sounds/jump.wav"),
	"land": preload("res://sounds/land.wav"),
	"flash": preload("res://sounds/flash.wav"),
	"flash_ready": preload("res://sounds/flash_ready.wav"),
	"flash_dud": preload("res://sounds/flash_dud.wav"),
	"mini_flash": preload("res://sounds/mini_flash.wav"),
	"collect": preload("res://sounds/collect.wav"),
	"checkpoint": preload("res://sounds/checkpoint.wav"),
	"button": preload("res://sounds/button.wav"),
	"drip": preload("res://sounds/drip.wav"),
	"death": preload("res://sounds/death.wav"),
	"tap": preload("res://sounds/tap.wav"),
	"victory": preload("res://sounds/victory.wav"),
	"push": preload("res://sounds/push.wav"),
	"flicker_off": preload("res://sounds/flicker_off.wav"),
	"flicker_on": preload("res://sounds/flicker_on.wav"),
	"shadow_dissolve": preload("res://sounds/shadow_dissolve.wav"),
	"shadow_puff": preload("res://sounds/shadow_puff.wav"),
	"fan_grind": preload("res://sounds/fan_grind.wav"),
	"fan_air": preload("res://sounds/fan_air.wav"),
}
## Suoni con più varianti: ogni volta ne suona una a caso, mai la stessa due volte di fila.
const ROUND_ROBIN := {
	"step": [
		preload("res://sounds/step_1.wav"),
		preload("res://sounds/step_2.wav"),
		preload("res://sounds/step_3.wav"),
	],
	"shadow_step": [
		preload("res://sounds/shadow_step_1.wav"),
		preload("res://sounds/shadow_step_2.wav"),
		preload("res://sounds/shadow_step_3.wav"),
	],
	"can": [
		preload("res://sounds/can_1.wav"),
		preload("res://sounds/can_2.wav"),
		preload("res://sounds/can_3.wav"),
	],
	"glass": [
		preload("res://sounds/glass_1.wav"),
		preload("res://sounds/glass_2.wav"),
		preload("res://sounds/glass_3.wav"),
	],
	"rustle": [
		preload("res://sounds/rustle_1.wav"),
		preload("res://sounds/rustle_2.wav"),
		preload("res://sounds/rustle_3.wav"),
		preload("res://sounds/rustle_4.wav"),
		preload("res://sounds/rustle_5.wav"),
		preload("res://sounds/rustle_6.wav"),
	],
	"spark": [
		preload("res://sounds/spark_1.wav"),
		preload("res://sounds/spark_2.wav"),
		preload("res://sounds/spark_3.wav"),
	],
}
## Pulsanti touch di gioco che hanno già un suono proprio (o nessuno).
const SILENT_ACTIONS := [&"jump", &"flash"]
const POOL_SIZE := 12
## Suoni che fanno spazio a sé stessi nella musica (ovunque suonino: gioco e menu).
const DUCKING := ["flash"]

var _players: Array[AudioStreamPlayer] = []
var _next := 0
## SOUNDS più un AudioStreamRandomizer per ogni voce di ROUND_ROBIN.
var _streams := SOUNDS.duplicate()


func _ready() -> void:
	# Continua a suonare anche col gioco in pausa (pannello impostazioni).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound in ROUND_ROBIN:
		var randomizer := AudioStreamRandomizer.new()
		randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		# L'intonazione la varia già play().
		randomizer.random_pitch = 1.0
		for stream in ROUND_ROBIN[sound]:
			randomizer.add_stream(-1, stream)
		_streams[sound] = randomizer
	# L'autoload sopravvive al cambio di scena: il tap di "Gioca" non si tronca.
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	get_tree().node_added.connect(_on_node_added)


## Suona un effetto con una leggera variazione di intonazione.
func play(sound: String, volume_db := 0.0, pitch_jitter := 0.05, pitch := 1.0) -> void:
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.play()
	if sound in DUCKING:
		Music.duck_flash()


## Lettore posizionale per suoni che provengono da un punto del livello.
func make_player_2d(sound: String, parent: Node) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.stream = _streams[sound]
	player.max_distance = 1600.0
	player.bus = &"SFX"
	parent.add_child(player)
	return player


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play.bind("tap", -4.0))
	elif node is TouchScreenButton and node.action not in SILENT_ACTIONS:
		node.pressed.connect(play.bind("tap", -4.0))
