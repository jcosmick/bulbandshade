extends Cutscene
## Cutscene vera (solo per zoom_test.gd): come intro_tutorial.gd la telecamera
## segue un nodo (camera_focus = se stessa, ferma dove sta la lampadina) finché
## il test non mette `released` a true; poi Cutscene._finish() rilascia
## camera_focus e ridà i comandi.

var released := false


func _play() -> void:
	global_position = game.player.global_position
	game.camera_focus = self
	await wait_until(func() -> bool: return released, 60.0)
