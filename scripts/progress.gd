extends Node
## Elenco dei livelli e progressi del giocatore (salvati sul dispositivo).

const LEVELS: Array[String] = [
	"res://levels/level_01.tscn",
	"res://levels/level_02.tscn",
	"res://levels/level_03.tscn",
	"res://levels/level_04.tscn",
	"res://levels/level_05.tscn",
	"res://levels/level_06.tscn",
]
const SAVE_PATH := "user://progress.cfg"

## Livello da avviare quando si apre la scena di gioco.
var selected_level := 0
## Se false i progressi non vengono scritti su disco (test automatici).
var persist := true

## Indice del livello -> minor numero di flash con cui è stato completato.
var _best_flashes := {}
## Mini lampadine trovate: id -> colore (in ordine di ritrovamento).
var _mini_bulbs := {}


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key in config.get_section_keys("best_flashes") if config.has_section("best_flashes") else []:
		_best_flashes[int(key)] = int(config.get_value("best_flashes", key))
	for key in config.get_section_keys("mini_bulbs") if config.has_section("mini_bulbs") else []:
		_mini_bulbs[key] = config.get_value("mini_bulbs", key)


func is_completed(index: int) -> bool:
	return _best_flashes.has(index)


## Un livello è giocabile se è il primo o se il precedente è stato completato.
func is_unlocked(index: int) -> bool:
	return index == 0 or is_completed(index - 1)


func best_flashes(index: int) -> int:
	return _best_flashes.get(index, -1)


## Primo livello non ancora completato (o l'ultimo, se sono tutti finiti).
func next_level() -> int:
	for i in LEVELS.size():
		if not is_completed(i):
			return i
	return LEVELS.size() - 1


func complete_level(index: int, flashes: int) -> void:
	if is_completed(index) and _best_flashes[index] <= flashes:
		return
	_best_flashes[index] = flashes
	_save()


func has_mini_bulb(id: String) -> bool:
	return _mini_bulbs.has(id)


## Mini lampadine trovate: id -> colore.
func mini_bulbs() -> Dictionary:
	return _mini_bulbs


func collect_mini_bulb(id: String, color: Color) -> void:
	if has_mini_bulb(id):
		return
	_mini_bulbs[id] = color
	_save()


func _save() -> void:
	if not persist:
		return
	var config := ConfigFile.new()
	for key in _best_flashes:
		config.set_value("best_flashes", str(key), _best_flashes[key])
	for key in _mini_bulbs:
		config.set_value("mini_bulbs", key, _mini_bulbs[key])
	config.save(SAVE_PATH)
