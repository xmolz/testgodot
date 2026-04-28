extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	$ColorRect/VBoxContainer/CloseButton.pressed.connect(func():
		if SoundManager: SoundManager.play_sfx("ui_click")
		queue_free()
	)

	$ColorRect.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if SoundManager: SoundManager.play_sfx("ui_click")
			queue_free()
	)

func _input(event):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		if SoundManager: SoundManager.play_sfx("ui_click")
		queue_free()
