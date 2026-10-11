class_name Level
extends Node2D
## Radice di un livello. Deve contenere i nodi "Player" e "Goal".

@export var level_name := "Livello"
## Icona della scheda nel menu: "crate", "glass", "rain", "warehouse", "rail", "factory" (vedi Icons).
@export_enum("crate", "glass", "rain", "warehouse", "rail", "factory") var icon := "crate"
## Area giocabile, usata per inquadrare la telecamera e limitare le ombre.
@export var level_rect := Rect2(0, 0, 1080, 1520)


func _ready() -> void:
	# Avviato da solo (F6 nell'editor): manca game.tscn, cioè telecamera, buio,
	# ombre e comandi. Si riparte dalla scena di gioco su questo livello.
	if get_parent() != get_tree().root:
		return
	var index := Progress.LEVELS.find(scene_file_path)
	if index == -1:
		# Livello in lavorazione, non ancora nell'elenco: si prova senza salvare.
		Progress.test_level = scene_file_path
		Progress.persist = false
	else:
		Progress.selected_level = index
	get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
