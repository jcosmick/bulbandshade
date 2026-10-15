extends PointLight2D
## Luce che si spegne da sola quando la sua energia è 0 (e si riaccende quando
## sale): anche a energia 0 una luce accesa fa calcolare l'illuminazione su
## ogni pixel che tocca, e sui telefoni costa molto (sfondo a tutto schermo).


func _enter_tree() -> void:
	add_to_group(LevelKit.LIGHTS_GROUP)


func _process(_delta: float) -> void:
	var on := energy > 0.0
	if enabled != on:
		enabled = on
