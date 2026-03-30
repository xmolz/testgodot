extends Control

signal toggled_visibility(is_dialogue_visible: bool)

var is_dialogue_visible: bool = true

func _draw() -> void:
	# We only draw the red line here now. 
	# The cyan icon is handled automatically by the TextureRect child nodes!
	if is_dialogue_visible:
		var line_width = 3.0
		var padding = 2.0
		draw_line(
			Vector2(padding, size.y - padding),
			Vector2(size.x - padding, padding),
			Color.RED, line_width, true
		)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		is_dialogue_visible = not is_dialogue_visible
		queue_redraw()
		toggled_visibility.emit(is_dialogue_visible)
		get_viewport().set_input_as_handled()

func set_dialogue_visible(visible: bool) -> void:
	is_dialogue_visible = visible
	queue_redraw()
