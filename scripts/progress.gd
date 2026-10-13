extends Node
## Elenco dei livelli e progressi del giocatore (salvati sul dispositivo).

const LEVELS: Array[String] = [
	"res://levels/level_01.tscn",
	"res://levels/level_02.tscn",
	"res://levels/level_03.tscn",
	"res://levels/level_04.tscn",
	"res://levels/level_05.tscn",
	"res://levels/level_06.tscn",
	"res://levels/level_07.tscn",
	"res://levels/level_08.tscn",
]
const SAVE_PATH := "user://progress.cfg"
## Indice del tutorial: non è in LEVELS, quindi non compare nella lista dei
## livelli. Si gioca solo al primo avvio e, una volta finito, mai più.
const TUTORIAL := -1
const TUTORIAL_PATH := "res://levels/level_tutorial.tscn"

## Livello da avviare quando si apre la scena di gioco.
var selected_level := 0
## Se false i progressi non vengono scritti su disco (test automatici).
var persist := true
## Livello avviato con F6 che non è ancora in LEVELS: la scena di gioco carica
## questo al posto di selected_level e i progressi non si salvano.
var test_level := ""

## Indice del livello -> minor numero di flash con cui è stato completato.
var _best_flashes := {}
## Mini lampadine trovate: id -> colore (in ordine di ritrovamento).
var _mini_bulbs := {}
var _tutorial_done := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key in config.get_section_keys("best_flashes") if config.has_section("best_flashes") else []:
		_best_flashes[int(key)] = int(config.get_value("best_flashes", key))
	for key in config.get_section_keys("mini_bulbs") if config.has_section("mini_bulbs") else []:
		_mini_bulbs[key] = config.get_value("mini_bulbs", key)
	_tutorial_done = config.get_value("tutorial", "done", false)


func is_completed(index: int) -> bool:
	return _best_flashes.has(index)


func level_path(index: int) -> String:
	return TUTORIAL_PATH if index == TUTORIAL else LEVELS[index]


## True al primo avvio: tutorial mai finito e nessun livello completato (chi
## aveva già dei progressi prima che esistesse il tutorial non lo vede).
func needs_tutorial() -> bool:
	return not _tutorial_done and _best_flashes.is_empty()


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
	if index == TUTORIAL:
		_tutorial_done = true
		_save()
		return
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
	if _tutorial_done:
		config.set_value("tutorial", "done", true)
	config.save(SAVE_PATH)
