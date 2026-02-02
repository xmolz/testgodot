# VerbUI.gd
extends CanvasLayer

@onready var action_bubble_label: Label = $ActionBubbleLabel
@onready var verb_button_grid: GridContainer = $VerbGridPanel/GridContainer # VERIFY THIS PATH

# This will store references to the actual Button nodes, mapping verb_id to Button
var active_verb_buttons: Dictionary = {} # Key: verb_id (String), Value: Button node
# We'll also keep an ordered list of all 9 button slots for easy iteration
var all_button_slots: Array[Button] = []


func _ready():
	# Ensure GridContainer is set to 3 columns (can also be done in Inspector)
	if verb_button_grid:
		verb_button_grid.columns = 3
	else:
		print_rich("[color=red]VerbUI: VerbButtonGrid node not found! Cannot set columns.[/color]")
		return # Critical error

	# --- Initialize exactly 9 button slots ---
	# First, clear any existing children in the GridContainer from the editor
	for child in verb_button_grid.get_children():
		verb_button_grid.remove_child(child) # Remove from container first
		child.queue_free()               # Then free it

	all_button_slots.clear() # Clear our internal array too
	active_verb_buttons.clear()

	for i in range(9): # Create 9 base buttons
		var new_button = Button.new()
		new_button.text = "-"
		new_button.disabled = true # Start disabled until populated
		new_button.name = "VerbSlotButton_" + str(i) # For debugging
		# Set a minimum size for buttons if they appear too small initially
		new_button.custom_minimum_size = Vector2(100, 30) # Adjust as needed
		# Set size flags to expand within the grid cell
		new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_button.size_flags_vertical = Control.SIZE_EXPAND_FILL

		all_button_slots.append(new_button)
		verb_button_grid.add_child(new_button)
		# Connection will be done when verbs are assigned in _on_available_verbs_changed

	# Connect to GameManager signals
	if GameManager: # Ensure GameManager is available
		GameManager.available_verbs_changed.connect(_on_available_verbs_changed)
		GameManager.verb_changed.connect(_on_game_manager_verb_changed)
		GameManager.sentence_line_updated.connect(_on_game_manager_sentence_line_updated)
		GameManager.interaction_complete.connect(_on_interaction_complete)

		# Request initial verb list from GameManager
		# It will emit available_verbs_changed in its _ready if it's set up after this UI
		# or we can call a function to get current state if GM is already ready.
		if GameManager.has_method("get_currently_displayable_verbs"):
			_on_available_verbs_changed(GameManager.get_currently_displayable_verbs())
		else:
			print_rich("[color=orange]VerbUI: GameManager doesn't have get_currently_displayable_verbs yet.[/color]")

	else:
		print_rich("[color=red]VerbUI: GameManager not found during _ready().[/color]")


	action_bubble_label.visible = false


func _process(_delta: float) -> void: # Unchanged
	if action_bubble_label.visible:
		action_bubble_label.global_position = get_viewport().get_mouse_position() + Vector2(15, 15)


func _on_available_verbs_changed(available_verb_data_array: Array[VerbData]):
	print("VerbUI: Received available verbs: ", available_verb_data_array.size())
	active_verb_buttons.clear() # Clear map of verb_id to button

	# Iterate through our 9 button slots
	for i in range(all_button_slots.size()):
		var button_node: Button = all_button_slots[i]

		# Disconnect any previous pressed signal to avoid multiple connections
		if button_node.is_connected("pressed", Callable(self, "_on_verb_button_pressed_dynamic")):
			button_node.pressed.disconnect(Callable(self, "_on_verb_button_pressed_dynamic"))

		if i < available_verb_data_array.size():
			# This slot gets an active verb
			var verb_data: VerbData = available_verb_data_array[i]
			if verb_data and is_instance_valid(verb_data): # Check if verb_data is valid
				button_node.text = verb_data.display_text
				button_node.disabled = false
				# Store verb_id in button's metadata for easy retrieval, or use the active_verb_buttons map
				button_node.set_meta("verb_id", verb_data.verb_id)
				button_node.pressed.connect(_on_verb_button_pressed_dynamic.bind(verb_data.verb_id)) # Bind verb_id
				active_verb_buttons[verb_data.verb_id] = button_node
				print("VerbUI: Set button %s to verb '%s' (%s)" % [i, verb_data.verb_id, verb_data.display_text])

			else: # Should not happen if GameManager sends valid data
				button_node.text = "-"
				button_node.disabled = true
				button_node.set_meta("verb_id", "")
				print_rich("[color=orange]VerbUI: Invalid VerbData at index %s[/color]" % i)
		else:
			# This slot is a placeholder
			button_node.text = "-"
			button_node.disabled = true
			button_node.set_meta("verb_id", "") # Clear any old verb_id

	_update_button_selected_visual_state(GameManager.current_verb_id if GameManager else "")


# Renamed to avoid conflict if an old _on_verb_button_pressed was connected from editor
# In VerbUI.gd

func _on_verb_button_pressed_dynamic(verb_id_pressed: String):
	# Play the sound 20% faster. Experiment with this value! Try 1.1, 1.3, etc.
	SoundManager.play_sfx("ui_click", 1.5)

	if GameManager and verb_id_pressed != "":
		GameManager.select_verb(verb_id_pressed)
	else:
		print("VerbUI: GameManager not found or empty verb_id pressed.")

func _on_game_manager_verb_changed(new_verb_id: String): # Unchanged from previous version
	if new_verb_id == "":
		action_bubble_label.visible = false
	else:
		var verb_data = GameManager.get_verb_data_by_id(new_verb_id) if GameManager else null
		if verb_data:
			action_bubble_label.text = verb_data.display_text + ":"
			action_bubble_label.visible = true
		else:
			action_bubble_label.text = new_verb_id + ":" # Fallback
			action_bubble_label.visible = true
	_update_button_selected_visual_state(new_verb_id)

# In VerbUI.gd

func _on_game_manager_sentence_line_updated(full_sentence: String):
	# ADD THIS LINE FOR DEBUGGING
	#print("VerbUI received sentence: '", full_sentence, "'")

	if GameManager and GameManager.current_verb_id != "":
		action_bubble_label.text = full_sentence
		action_bubble_label.visible = true
	else:
		# Let's modify this part to handle the "implicit use" case
		if full_sentence != "":
			action_bubble_label.text = full_sentence
			action_bubble_label.visible = true
		else:
			action_bubble_label.visible = false

func _on_interaction_complete(): # Unchanged
	action_bubble_label.visible = false
	_update_button_selected_visual_state("")

func _update_button_selected_visual_state(selected_verb_id: String): # Unchanged
	for button_node in all_button_slots: # Iterate through all_button_slots
		var button_verb_id = button_node.get_meta("verb_id", "") # Get verb_id from metadata
		if is_instance_valid(button_node):
			if button_verb_id != "" and button_verb_id == selected_verb_id:
				button_node.modulate = Color(0.7, 0.7, 1.0)
			else:
				button_node.modulate = Color(1.0, 1.0, 1.0)
