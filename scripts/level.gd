class_name Level
extends Node2D
## Radice di un livello. Deve contenere i nodi "Player" e "Goal".

@export var level_name := "Livello"
## Icona della scheda nel menu: "crate", "glass", "rain", "warehouse", "rail", "factory" (vedi Icons).
@export_enum("crate", "glass", "rain", "warehouse", "rail", "factory") var icon := "crate"
## Area giocabile, usata per inquadrare la telecamera e limitare le ombre.
@export var level_rect := Rect2(0, 0, 1080, 1520)
