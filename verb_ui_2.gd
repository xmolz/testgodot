# VerbUI.gd
# Refactored to manage a permanent, fixed set of 9 buttons.
extends CanvasLayer

# --- NODE REFERENCES ---
@onready var action_bubble_label: Label = %ActionBubbleLabel
@onready var verb_button_grid: GridContainer = %VerbGridContainer

# --- SCRIPT STATE ---
# An array to hold our 9 permanent button nodes.
var verb_buttons_array: Array[Button] = []
# An array to store the verb_id currently assigned to each button index.
var current_verb_ids: Array[String] = []
# A dictionary to quickly find a button by its verb_id for visual updates.
var active_verb_buttons: Dictionary = {} # Key: verb_id (String), Value: Button node


# --- GODOT BUILT-IN FUNCTIONS ---

func _ready():
	# --- NEW SETUP LOGIC ---
	# 1. Get all 9 buttons from the grid and store them.
	verb_buttons_array = verb_button_grid.get_children() as Array[Button]

	# Safety check
	if verb_buttons_array.size() != 9:
		printerr("VerbUI Error: Expected exactly 9 buttons in the GridContainer.")
		return

	# 2. Connect the 'pressed' signal for each button ONCE.
	for i in range(verb_buttons_array.size()):
		var button: Button = verb_buttons_array[i]
		# We bind the button's index (0-8) so we know which one was clicked.
		button.pressed.connect(_on_verb_button_pressed.bind(i))

	# Initialize the verb IDs array.
	current_verb_ids.resize(9)
	current_verb_ids.fill("")
	# --- END OF NEW SETUP ---

	# Connect to GameManager signals (this is unchanged)
	GameManager.available_verbs_changed.connect(_on_available_verbs_changed)
	GameManager.verb_changed.connect(_on_game_manager_verb_changed)
	GameManager.sentence_line_updated.connect(_on_game_manager_sentence_line_updated)
	GameManager.interaction_complete.connect(_on_interaction_complete)

	action_bubble_label.visible = false
	# Initially update the buttons to their default state
	_on_available_verbs_changed([])


func _process(_delta):
	if action_bubble_label.visible:
		action_bubble_label.global_position = get_viewport().get_mouse_position() + Vector2(15, 15)


# --- SIGNAL HANDLERS ---

func _on_available_verbs_changed(available_verb_data_array: Array[VerbData]):
	# --- COMPLETELY REWRITTEN LOGIC ---
	# This function no longer creates/deletes nodes. It just updates the 9 existing ones.

	active_verb_buttons.clear()

	for i in range(verb_buttons_array.size()): # Loop 0 through 8
		var button: Button = verb_buttons_array[i]

		# Is there a verb available for this button slot?
		if i < available_verb_data_array.size():
			var verb_data: VerbData = available_verb_data_array[i]
			button.text = verb_data.display_text
			button.disabled = false
			# Store the mapping for this active button
			current_verb_ids[i] = verb_data.verb_id
			active_verb_buttons[verb_data.verb_id] = button
		else:
			# This button slot has no verb; set it to a disabled, default state.
			button.text = "-"
			button.disabled = true
			current_verb_ids[i] = ""

	_update_button_selected_visual_state(GameManager.current_verb_id)


func _on_verb_button_pressed(button_index: int):
	# We receive the index (0-8) of the button that was pressed.
	var verb_id_pressed = current_verb_ids[button_index]

	# Only process the click if it's an active verb (not a disabled "-" button).
	if not verb_id_pressed.is_empty():
		GameManager.select_verb(verb_id_pressed)


# The rest of the functions work with the 'active_verb_buttons' dictionary,
# which is still being updated correctly, so they don't need to change.

func _on_game_manager_verb_changed(new_verb_id: String):
	if new_verb_id.is_empty():
		action_bubble_label.visible = false
	else:
		var verb_data = GameManager.get_verb_data_by_id(new_verb_id)
		action_bubble_label.text = verb_data.display_text + ":" if verb_data else new_verb_id + ":"
		action_bubble_label.visible = true

	_update_button_selected_visual_state(new_verb_id)


func _on_game_manager_sentence_line_updated(full_sentence: String):
	if not GameManager.current_verb_id.is_empty():
		action_bubble_label.text = full_sentence
		action_bubble_label.visible = true
	else:
		action_bubble_label.visible = false


func _on_interaction_complete():
	action_bubble_label.visible = false
	_update_button_selected_visual_state("")


func _update_button_selected_visual_state(selected_verb_id: String):
	for verb_id in active_verb_buttons:
		var button_node: Button = active_verb_buttons[verb_id]
		if is_instance_valid(button_node):
			button_node.modulate = Color.SKY_BLUE if verb_id == selected_verb_id else Color.WHITE
