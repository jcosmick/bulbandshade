extends Node
## Effetti sonori (autoload): suona i suoni non posizionali e aggiunge il "tap"
## a ogni pulsante dell'interfaccia. I WAV si rigenerano con sounds/make_sfx.py.

const SOUNDS := {
	"flash": preload("res://sounds/flash.wav"),
	"drip": preload("res://sounds/drip.wav"),
	"death": preload("res://sounds/death.wav"),
	"tap": preload("res://sounds/tap.wav"),
	"victory": preload("res://sounds/victory.wav"),
}
## Pulsanti touch di gioco che hanno già un suono proprio (o nessuno).
const SILENT_ACTIONS := [&"jump", &"flash"]
const POOL_SIZE := 8

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	# Continua a suonare anche col gioco in pausa (pannello impostazioni).
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	player.stream = SOUNDS[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.play()


## Lettore posizionale per suoni che provengono da un punto del livello.
func make_player_2d(sound: String, parent: Node) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.stream = SOUNDS[sound]
	player.max_distance = 1600.0
	player.bus = &"SFX"
	parent.add_child(player)
	return player


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play.bind("tap", -4.0))
	elif node is TouchScreenButton and node.action not in SILENT_ACTIONS:
		node.pressed.connect(play.bind("tap", -4.0))
