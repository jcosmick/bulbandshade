extends Node
## Registra le azioni di input (tastiera per i test su PC; su telefono le
## stesse azioni vengono premute dai pulsanti touch).


func _enter_tree() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("flash", [KEY_F, KEY_E, KEY_K])
	_add_action("restart", [KEY_R])
	_add_action("menu", [KEY_ESCAPE])
	_add_action("settings", [KEY_O])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("god_mode", [KEY_G])


func _add_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
