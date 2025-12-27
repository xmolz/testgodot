extends CanvasLayer
signal explanation_finished
# --- Node References ---
@onready var color_rect: ColorRect = $ColorRect
@onready var explanation_label: Label = $PanelContainer/VBoxContainer/ExplanationLabel
@onready var next_button: Button = $PanelContainer/VBoxContainer/NextButton

# --- State Variables ---
var current_explanation_data: ExplanationData = null
var current_line_index: int = 0

func _ready():
	next_button.pressed.connect(_on_next_button_pressed)
	hide()

func show_explanation(data: ExplanationData, root_node: Node):
	if not data or data.explanation_lines.is_empty():
		print("Error: Invalid or empty explanation data provided.")
		return

	await get_tree().process_frame

	var target_node: Node = root_node.get_node_or_null(data.target_node_path)

	if is_instance_valid(target_node) and target_node is CanvasItem:
		# --- THIS IS THE KEY FIX ---
		# We now calculate the visual center of the node, not just its origin.
		# A CanvasItem has a 'size' from its get_rect() method.
		var node_size = target_node.get_rect().size
		var center_position = target_node.global_position + (node_size / 2.0)
		# --- END OF FIX ---

		var target_screen_pos: Vector2

		# If it's a UI element, its calculated center is already in screen space.
		if target_node is Control:
			target_screen_pos = center_position

		# If it's a world-space element, we convert the calculated center to screen space.
		elif target_node is Node2D:
			target_screen_pos = get_viewport().get_canvas_transform().affine_inverse() * center_position

		else:
			print_rich("[color=orange]Explanation Warning: Target node is an unsupported visual type. Defaulting to center.[/color]")
			target_screen_pos = get_viewport().get_visible_rect().size / 2

		update_spotlight_position(target_screen_pos)
	else:
		print_rich("[color=orange]Explanation Warning: Target node not found. Defaulting to screen center.[/color]")
		update_spotlight_position(get_viewport().get_visible_rect().size / 2)

	current_explanation_data = data
	current_line_index = 0

	_update_display()
	show()

func hide_explanation():
	current_explanation_data = null
	hide()
	# This new line tells anyone listening (our GameManager) that we are done.
	explanation_finished.emit()

# Replace your existing _on_next_button_pressed function to ensure the signal is emitted correctly.


func update_spotlight_position(pos: Vector2):
	if color_rect.material is ShaderMaterial:
		color_rect.material.set_shader_parameter("hole_position", pos)

func _update_display():
	explanation_label.text = current_explanation_data.explanation_lines[current_line_index]

	if current_line_index == current_explanation_data.explanation_lines.size() - 1:
		next_button.text = "Finish"
	else:
		next_button.text = "Next"

func _on_next_button_pressed():
	current_line_index += 1

	if current_line_index >= current_explanation_data.explanation_lines.size():
		# Instead of just hiding, we call our new function that also emits the signal.
		hide_explanation()
	else:
		_update_display()
