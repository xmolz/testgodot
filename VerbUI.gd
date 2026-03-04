# VerbUI.gd
extends CanvasLayer

@onready var action_bubble_label: Label = $ActionBubbleLabel
@onready var verb_button_grid: GridContainer = $VerbGridPanel/GridContainer 

var active_verb_buttons: Dictionary = {} 
var all_button_slots: Array[Button] = []

func _ready():
	if verb_button_grid:
		verb_button_grid.columns = 3
	else:
		print_rich("[color=red]VerbUI: VerbButtonGrid node not found! Cannot set columns.[/color]")
		return 

	for child in verb_button_grid.get_children():
		verb_button_grid.remove_child(child) 
		child.queue_free()               

	all_button_slots.clear() 
	active_verb_buttons.clear()

	for i in range(9): 
		var new_button = Button.new()
		new_button.text = "-"
		new_button.disabled = true 
		new_button.name = "VerbSlotButton_" + str(i) 
		new_button.custom_minimum_size = Vector2(100, 30) 
		new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# --- THE FIX: Disable focus so it doesn't get stuck highlighted! ---
		new_button.focus_mode = Control.FOCUS_NONE 
		# -------------------------------------------------------------------

		all_button_slots.append(new_button)
		verb_button_grid.add_child(new_button)

	if GameManager: 
		GameManager.available_verbs_changed.connect(_on_available_verbs_changed)
		GameManager.verb_changed.connect(_on_game_manager_verb_changed)
		GameManager.sentence_line_updated.connect(_on_game_manager_sentence_line_updated)
		GameManager.interaction_complete.connect(_on_interaction_complete)

		if GameManager.has_method("get_currently_displayable_verbs"):
			_on_available_verbs_changed(GameManager.get_currently_displayable_verbs())
		else:
			print_rich("[color=orange]VerbUI: GameManager doesn't have get_currently_displayable_verbs yet.[/color]")

	else:
		print_rich("[color=red]VerbUI: GameManager not found during _ready().[/color]")

	action_bubble_label.visible = false

func _process(_delta: float) -> void: 
	if action_bubble_label.visible:
		action_bubble_label.global_position = get_viewport().get_mouse_position() + Vector2(15, 15)

func _on_available_verbs_changed(available_verb_data_array: Array[VerbData]):
	active_verb_buttons.clear() 

	for i in range(all_button_slots.size()):
		var button_node: Button = all_button_slots[i]

		if button_node.is_connected("pressed", Callable(self, "_on_verb_button_pressed_dynamic")):
			button_node.pressed.disconnect(Callable(self, "_on_verb_button_pressed_dynamic"))

		if i < available_verb_data_array.size():
			var verb_data: VerbData = available_verb_data_array[i]
			if verb_data and is_instance_valid(verb_data): 
				button_node.text = verb_data.display_text
				button_node.disabled = false
				button_node.set_meta("verb_id", verb_data.verb_id)
				button_node.pressed.connect(_on_verb_button_pressed_dynamic.bind(verb_data.verb_id)) 
				active_verb_buttons[verb_data.verb_id] = button_node
			else: 
				button_node.text = "-"
				button_node.disabled = true
				button_node.set_meta("verb_id", "")
		else:
			button_node.text = "-"
			button_node.disabled = true
			button_node.set_meta("verb_id", "") 

	_update_button_selected_visual_state(GameManager.current_verb_id if GameManager else "")

func _on_verb_button_pressed_dynamic(verb_id_pressed: String):
	SoundManager.play_sfx("ui_click", 1.5)

	if GameManager and verb_id_pressed != "":
		GameManager.select_verb(verb_id_pressed)
	else:
		print("VerbUI: GameManager not found or empty verb_id pressed.")

func _on_game_manager_verb_changed(new_verb_id: String): 
	if new_verb_id == "":
		action_bubble_label.visible = false
	else:
		var verb_data = GameManager.get_verb_data_by_id(new_verb_id) if GameManager else null
		if verb_data:
			action_bubble_label.text = verb_data.display_text + ":"
		else:
			action_bubble_label.text = new_verb_id + ":" 
			
		action_bubble_label.reset_size() # <--- Forces the box to shrink to the text size
		action_bubble_label.visible = true
		
	_update_button_selected_visual_state(new_verb_id)

func _on_game_manager_sentence_line_updated(full_sentence: String):
	if GameManager and GameManager.current_verb_id != "":
		action_bubble_label.text = full_sentence
		action_bubble_label.reset_size() # <--- Forces the box to shrink to the text size
		action_bubble_label.visible = true
	else:
		if full_sentence != "":
			action_bubble_label.text = full_sentence
			action_bubble_label.reset_size() # <--- Forces the box to shrink to the text size
			action_bubble_label.visible = true
		else:
			action_bubble_label.visible = false

func _on_interaction_complete(): 
	action_bubble_label.visible = false
	_update_button_selected_visual_state("")

func _update_button_selected_visual_state(selected_verb_id: String): 
	for button_node in all_button_slots: 
		var button_verb_id = button_node.get_meta("verb_id", "") 
		if is_instance_valid(button_node):
			if button_verb_id != "" and button_verb_id == selected_verb_id:
				# Highlight cyan when active
				button_node.modulate = Color(0.2, 0.85, 1.0, 1.0)
			else:
				button_node.modulate = Color(1.0, 1.0, 1.0)
