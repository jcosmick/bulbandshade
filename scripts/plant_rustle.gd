class_name PlantRustle
extends Node
## Fruscio di foglie di sottofondo per le piante che la lampadina scosta. Va
## aggiunto come figlio della pianta, che ogni frame chiama `touch()` con la
## velocità della lampadina che la sta toccando.

## Sotto questa velocità (px/s) la lampadina sfiora le foglie senza farle frusciare.
const MIN_SPEED := 60.0
## Velocità a cui il fruscio è al massimo (la corsa della lampadina).
const FULL_SPEED := 520.0
## Volume al massimo: è un suono di fondo, sta sotto ai passi.
const VOLUME_DB := -14.0
## Pausa minima tra due frusci mentre la lampadina attraversa la chioma.
const INTERVAL := 0.28

var _player: AudioStreamPlayer2D
## Istante (ms) prima del quale non si fruscia di nuovo: un timestamp invece
## di un conto alla rovescia, così il nodo non ha bisogno di _process.
var _next_rustle_ms := 0


func _ready() -> void:
	_player = Sfx.make_player_2d("rustle", get_parent())
	# Un fruscio non taglia il precedente: le code si sovrappongono e non si sente il "riavvio".
	_player.max_polyphony = 3


## La lampadina tocca le foglie muovendosi a `speed`: fruscia, se non l'ha appena fatto.
func touch(speed: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_rustle_ms or speed < MIN_SPEED:
		return
	_next_rustle_ms = now + roundi(INTERVAL * randf_range(0.7, 1.5) * 1000.0)
	var strength := clampf(speed / FULL_SPEED, 0.25, 1.0)
	_player.volume_db = VOLUME_DB + linear_to_db(strength) + randf_range(-3.0, 1.0)
	# Passaggi lenti un filo più gravi, come foglie che si piegano appena.
	_player.pitch_scale = lerpf(0.9, 1.0, strength) * randf_range(0.82, 1.18)
	_player.play()
