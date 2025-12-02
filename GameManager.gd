# GameManager.gd
extends Node

const MAIN_GAME_SCENE_PATH = "res://main.tscn"
const INSURANCE_FORM_SCENE = preload("res://insurance_form.tscn")
const MAIN_MENU_SCENE_PATH = "res://main_menu.tscn"
# --- ADD THIS LINE ---
# Make sure this path is correct for your project structure!
# In Boot.gd - CUT THESE LINES
const INTRO_OVERLAY_SCENE_PATH = "res://CharacterConversationOverlay.tscn"
const INTRO_DIALOGUE_FILE_PATH = "res://dialogue/npcs/faye.dialogue"
const INTRO_BACKGROUND_ANIMATIONS_PATH = "res://conversation_backgrounds.tres"
const INTRO_INITIAL_ANIMATION_NAME = "float_loop"

var _insurance_form_instance: CanvasLayer = null # To keep track of the form
# --- Signals ---
signal verb_changed(new_verb_id: String)
signal sentence_line_updated(text: String)
signal interaction_complete # For VerbUI to reset its state
signal available_verbs_changed(available_verb_data_array: Array[VerbData])
signal item_picked_up(item_name: String)
signal notification_requested(message: String)

# character conversation ended signal
signal character_conversation_ended(dialogue_resource: DialogueResource)

# Inventory Signals
signal inventory_updated(inventory_items: Array[ItemData])
signal selected_inventory_item_changed(selected_item_data: ItemData) # "In Hand" / "Selected"

# --- High-Level Game State Management ---
# 1. Define the game states using an enum for clarity and safety.
# In GameManager.gd
# In GameManager.gd
enum GameState {
	BOOTING,
	LOGO_SPLASH,
	MAIN_MENU,
	INTRO_CONVERSATION,
	IN_GAME_PLAY,
	PAUSED,
	EXPLANATION # Add this new state
}



# --- Interaction Context Management ---
# This enum tracks what the player is currently focused on.
enum InteractionState {
	WORLD,
	CONVERSATION,
	ZOOM_VIEW
}
var current_interaction_state: InteractionState = InteractionState.WORLD

# These references are crucial. We need to tell the GameManager where the UI nodes are.
# IMPORTANT: Verify these paths match the node structure in your main game scene!
# These references are crucial. We link them in the Inspector.
var verb_ui: CanvasLayer = null
var inventory_ui: CanvasLayer = null
var insurance_form_button_ui: CanvasLayer = null
var explanation_layer: CanvasLayer = null


# --- END of Interaction Context Management ---
# 2. Create a variable to hold the current state.
var current_game_state: GameState = GameState.BOOTING

# 3. Reference to your main game scene instance.
#    The Boot.gd script will set this reference for us later.
var main_game_scene_instance: Node = null
var main_menu_scene_instance: Control = null
# --- END of High-Level Game State Management ---
var input_blocker_layer: CanvasLayer = null
# --- State Variables ---
var current_verb_id: String = ""
var current_selected_item_data: ItemData = null # "In Hand" / "Selected" item
var hovered_interactable: Interactable = null
var player_node: CharacterBody2D

var _is_player_walking: bool = false
var _current_character_conversation_overlay_instance: CharacterConversationOverlay = null
var _signals_connected_to_interactable: Interactable = null # Tracks interactable for signal cleanup

var current_level_state_manager: LevelStateManager = null # For current level's state



# --- Verb Management ---
@export var player_examine_lines: DialogueResource
@export var player_talk_to_lines: DialogueResource
@export var all_verb_data_resources: Array[VerbData] = []
var unlocked_verb_ids: Array[String] = []
var active_scene_verb_ids: Array[String] = []

# --- Inventory Management ---
@export var all_item_data_resources: Array[ItemData] = []
var player_inventory: Array[ItemData] = []
var _item_data_map: Dictionary = {} # item_id -> ItemData




# --- Game Flags (Global) ---
var game_flags: Dictionary = {} # For flags that persist across levels

# --- Verb ID Constants ---

const IMPLICIT_USE_ITEM_VERB_ID: String = "use_item" # BACK TO "use_item"
const USE_ON_TARGET_VERB_ID: String = "use_on_target" # BACK TO "use_on_target"
# --- NEW CONSTANT ---
const WALK_TO_VERB_ID: String = "walk_to"


func _ready():
	print_rich("[color=cyan]GM: GameManager is Ready! Starting initialization...[/color]")
	if DialogueManager:
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
		print_rich("[color=green]GM: Connected to DialogueManager.dialogue_started.[/color]")
	else:
		print_rich("[color=red]GM: DialogueManager (Autoload) not found. Dialogue events won't control player movement.[/color]")

	# Initialize Verbs
	print_rich("[color=aqua]GM: Initializing verbs...[/color]")
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.unlocked_by_default and not verb_data_res.verb_id in unlocked_verb_ids:
			unlocked_verb_ids.append(verb_data_res.verb_id)
			print_rich("  [color=gray]GM: Unlocked default verb: %s[/color]" % verb_data_res.verb_id)
	active_scene_verb_ids = unlocked_verb_ids.duplicate()
	_emit_available_verbs_changed_update()
	print_rich("[color=green]GM: Verbs initialized. %s default verbs unlocked.[/color]" % unlocked_verb_ids.size())

	# Initialize Item Data Map
	print_rich("[color=aqua]GM: Initializing item data map...[/color]")
	if all_item_data_resources.is_empty():
		print_rich("[color=yellow]GM: 'all_item_data_resources' array is empty. No items loaded from Inspector.[/color]")
	else:
		print_rich("[color=gray]GM: Found %s item resources in 'all_item_data_resources'.[/color]" % all_item_data_resources.size())

	for item_data_res in all_item_data_resources:
		if item_data_res and item_data_res.item_id != "":
			if not _item_data_map.has(item_data_res.item_id):
				_item_data_map[item_data_res.item_id] = item_data_res
				print_rich("  [color=gray]GM: Mapped item: ID='%s', Name='%s'[/color]" % [item_data_res.item_id, item_data_res.display_name])
			else:
				print_rich("[color=red]GM: Duplicate item_id found in all_item_data_resources: '%s'. Overwriting in map is problematic.[/color]" % item_data_res.item_id)
		elif item_data_res and item_data_res.item_id == "":
			print_rich("[color=orange]GM: ItemData resource '%s' found with EMPTY item_id. It cannot be used by ID.[/color]" % item_data_res.resource_path if item_data_res else "UNKNOWN")
		elif not item_data_res:
			print_rich("[color=yellow]GM: Found a null entry in 'all_item_data_resources'. Please check Inspector.[/color]")

	print_rich("[color=green]GM: Item data map initialized. %s items mapped.[/color]" % _item_data_map.size())
	print_rich("[color=cyan]GM: GameManager initialization complete.[/color]")
	if current_game_state == GameState.BOOTING:
		var potential_player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(potential_player):
			print_rich("[color=purple]GM: Direct scene run detected (player found on boot).[/color]")
			print_rich("[color=purple]GM: Manually setting state to IN_GAME_PLAY and assigning nodes.[/color]")

			# 1. Manually assign the player node
			player_node = potential_player

			# 2. Assign the main scene instance (assuming player is a child of the main scene)
			main_game_scene_instance = player_node.get_owner()
			if not is_instance_valid(main_game_scene_instance):
				# Fallback if owner is not set correctly
				main_game_scene_instance = get_tree().get_root().get_child(-1)

			# Find and assign the UI nodes now that the main scene is confirmed to exist.
			_find_and_assign_ui_nodes()

			print_rich("[color=green]GM: Found player: %s[/color]" % player_node.name)
			print_rich("[color=green]GM: Assigned main scene: %s[/color]" % main_game_scene_instance.name)

			# 3. Manually set the state. We don't call change_game_state() because
			#    that would try to load the scene again.
			current_game_state = GameState.IN_GAME_PLAY

			# 4. Ensure the player can move
			if player_node.has_method("set_can_move"):
				player_node.set_can_move(true)


# --- NEW FUNCTION ---
# This function captures mouse clicks that haven't been handled by any UI elements or Interactables.
# In GameManager.gd

func _unhandled_input(event: InputEvent):
	# The initial check for _is_player_walking has been removed.

	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()):
		return

	if current_game_state != GameState.IN_GAME_PLAY or current_interaction_state != InteractionState.WORLD:
		return

	if current_verb_id != "" or current_selected_item_data != null or hovered_interactable != null:
		return

	if is_instance_valid(player_node) and player_node.has_method("walk_to_point"):
		# Set the lock flag to true before telling the player to walk.
		# This is still important so that hover events are blocked correctly.
		_is_player_walking = true
		player_node.walk_to_point(player_node.get_global_mouse_position())


# Replace the entire existing function with this one.
# In GameManager.gd
# Replace the entire existing function with this one.
func change_game_state(new_state: GameState):
	if new_state == current_game_state:
		return

	# --- THIS IS THE FIX ---
	# Wait for the end of the current frame before doing anything else.
	# This gives the engine a chance to redraw the UI (like un-pressing a button)
	# before we start a heavy loading operation that will cause a pause.
	await get_tree().process_frame
	# --- END OF FIX ---

	match current_game_state:
		GameState.MAIN_MENU:
			if is_instance_valid(main_menu_scene_instance):
				print_rich("[color=yellow]GM: Cleaning up Main Menu scene.[/color]")
				main_menu_scene_instance.queue_free()
				main_menu_scene_instance = null
		GameState.IN_GAME_PLAY:
			pass

	print_rich("[color=yellow]GameManager: Changing state from %s to %s[/color]" % [GameState.keys()[current_game_state], GameState.keys()[new_state]])
	current_game_state = new_state

	match current_game_state:
		GameState.MAIN_MENU:
			if is_instance_valid(main_menu_scene_instance):
				return

			var menu_packed_scene = load(MAIN_MENU_SCENE_PATH)
			if not menu_packed_scene:
				print_rich("[color=red]GameManager Error: Failed to load Main Menu Scene.[/color]")
				return

			main_menu_scene_instance = menu_packed_scene.instantiate()
			main_menu_scene_instance.new_game_requested.connect(_on_main_menu_new_game_requested)
			main_menu_scene_instance.quit_game_requested.connect(_on_main_menu_quit_requested)

			get_tree().root.add_child(main_menu_scene_instance)
			print_rich("[color=green]GM: Main Menu scene loaded and initialized.[/color]")

		GameState.EXPLANATION:
			pass

		GameState.INTRO_CONVERSATION:
			_start_intro_conversation()

		GameState.IN_GAME_PLAY:
			if is_instance_valid(main_game_scene_instance):
				return

			var main_packed_scene = load(MAIN_GAME_SCENE_PATH)
			if not main_packed_scene:
				print_rich("[color=red]GameManager Error: Failed to load Main Game Scene.[/color]")
				return

			main_game_scene_instance = main_packed_scene.instantiate()
			get_tree().root.add_child(main_game_scene_instance)
			_find_and_assign_ui_nodes()

			if not is_instance_valid(player_node):
				player_node = get_tree().get_first_node_in_group("player")
				if not is_instance_valid(player_node):
					print_rich("[color=red]GM: Player node not found in group 'player' or is invalid![/color]")
				else:
					print_rich("[color=green]GM: Found player: %s[/color]" % player_node.name)

			if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
				player_node.set_can_move(true)

		GameState.PAUSED:
			pass

		GameState.BOOTING:
			pass
func select_verb(verb_id_to_select: String):
	var previously_selected_verb_id = current_verb_id
	var new_verb_id = ""

	if current_verb_id == verb_id_to_select:
		new_verb_id = ""
	else:
		var is_selectable = false
		for verb_data in get_currently_displayable_verbs():
			if verb_data.verb_id == verb_id_to_select:
				is_selectable = true; break
		if verb_id_to_select == "" or is_selectable:
			new_verb_id = verb_id_to_select
		else:
			print_rich("[color=orange]GM: Attempted to select unavailable verb: %s[/color]" % verb_id_to_select)
			new_verb_id = previously_selected_verb_id

	if current_verb_id != new_verb_id:
		current_verb_id = new_verb_id
		verb_changed.emit(current_verb_id)

		if current_verb_id != "" and current_verb_id != USE_ON_TARGET_VERB_ID and current_selected_item_data != null:
			print_rich("[color=lightblue]GM: Verb '%s' selected, previously 'in-hand' item '%s' deselected.[/color]" % [current_verb_id, current_selected_item_data.display_name])
			current_selected_item_data = null
			selected_inventory_item_changed.emit(null)
		elif current_verb_id == USE_ON_TARGET_VERB_ID and current_selected_item_data != null:
			print_rich("[color=lightblue]GM: Verb '%s' selected, keeping 'in-hand' item: '%s'[/color]" % [current_verb_id, current_selected_item_data.display_name])
		elif current_verb_id == "" and previously_selected_verb_id == USE_ON_TARGET_VERB_ID and current_selected_item_data != null:
			print_rich("[color=lightblue]GM: Verb '%s' deselected, also deselecting 'in-hand' item '%s'[/color]" % [previously_selected_verb_id, current_selected_item_data.display_name])
			current_selected_item_data = null
			selected_inventory_item_changed.emit(null)

	update_sentence_line_ui()
	print_rich("[color=cyan]GM STATE: Verb='%s', Item='%s'[/color]" % [current_verb_id if current_verb_id else "None", current_selected_item_data.display_name if current_selected_item_data else "None"])

func select_inventory_item(item_data_to_select: ItemData):
	var previous_verb_id_was_use_on_target = (current_verb_id == USE_ON_TARGET_VERB_ID)

	if not item_data_to_select:
		if current_selected_item_data != null:
			var deselected_item_name = current_selected_item_data.display_name
			current_selected_item_data = null
			selected_inventory_item_changed.emit(null)
			print_rich("[color=lightblue]GM: Deselected 'in-hand' item: '%s' (by selecting null)[/color]" % deselected_item_name)
		update_sentence_line_ui()
		print_rich("[color=cyan]GM STATE: Verb='%s', Item='%s'[/color]" % [current_verb_id if current_verb_id else "None", current_selected_item_data.display_name if current_selected_item_data else "None"])
		return

	if current_selected_item_data == item_data_to_select:
		var deselected_item_name = current_selected_item_data.display_name
		current_selected_item_data = null
		selected_inventory_item_changed.emit(null)
		print_rich("[color=lightblue]GM: Deselected 'in-hand' item by re-clicking: '%s'.[/color]" % deselected_item_name)
	else:
		current_selected_item_data = item_data_to_select
		selected_inventory_item_changed.emit(current_selected_item_data)
		print_rich("[color=lightblue]GM: Selected new 'in-hand' item: '%s' (ID: %s)[/color]" % [current_selected_item_data.display_name, current_selected_item_data.item_id])

		if current_verb_id != "" and not previous_verb_id_was_use_on_target:
			print_rich("[color=lightblue]GM: 'In-hand' item selected, previous verb '%s' deselected.[/color]" % current_verb_id)
			current_verb_id = ""
			verb_changed.emit("")
		elif previous_verb_id_was_use_on_target:
			print_rich("[color=lightblue]GM: 'In-hand' item selected, 'Use With' verb ('%s') remains active.[/color]" % USE_ON_TARGET_VERB_ID)

	update_sentence_line_ui()
	print_rich("[color=cyan]GM STATE: Verb='%s', Item='%s'[/color]" % [current_verb_id if current_verb_id else "None", current_selected_item_data.display_name if current_selected_item_data else "None"])


# --- UI and Interaction Flow ---
func set_hovered_object(interactable: Interactable):
	if _is_player_walking:
		return
	hovered_interactable = interactable
	update_sentence_line_ui()

func clear_hovered_object():
	if _is_player_walking:
		return
	hovered_interactable = null
	update_sentence_line_ui()

func update_sentence_line_ui():
	var line_text = ""
	var verb_data_for_use_on_target = get_verb_data_by_id(USE_ON_TARGET_VERB_ID) # Get VerbData for display text

	if current_verb_id == USE_ON_TARGET_VERB_ID:
		# --- Handling for "Use Item With Target" verb ---
		var use_verb_display_text = USE_ON_TARGET_VERB_ID # Fallback
		if verb_data_for_use_on_target:
			use_verb_display_text = verb_data_for_use_on_target.display_text

		var source_item_name = "None Selected"
		if current_selected_item_data:
			source_item_name = current_selected_item_data.display_name

		line_text = "%s: %s" % [use_verb_display_text, source_item_name] # e.g., "Use With: Rusty Key" or "Use With: None Selected"

		if hovered_interactable:
			line_text += " ON " + hovered_interactable.object_display_name # e.g., " ON Burger"
		else:
			line_text += " ON..." # Waiting for target

	elif current_selected_item_data:
		# --- Handling for when an item is selected ("in hand") but NO verb is active (implicit use) ---
		# This is the "Item Name with Target Name" mode.
		line_text = current_selected_item_data.display_name
		if hovered_interactable:
			line_text += " with " + hovered_interactable.object_display_name # e.g., "Rusty Key with Door"
		# else: just the item name, like "Rusty Key" (player is holding it)

	elif current_verb_id != "":
		# --- Handling for other active verbs (Examine, Talk To, Pickup, etc.) ---
		var verb_data = get_verb_data_by_id(current_verb_id)
		var display_verb_text = current_verb_id # Fallback
		if verb_data:
			display_verb_text = verb_data.display_text

		line_text = display_verb_text
		if hovered_interactable:
			line_text += ": " + hovered_interactable.object_display_name # e.g., "Examine: Door"
		else:
			# For verbs that don't strictly require a target (like a generic "Look Around" verb)
			# or when waiting for a target for verbs that do.
			if verb_data and not verb_data.requires_target_object:
				pass # Just the verb display text is enough
			else:
				line_text += ":" # Add colon if no target, like "Examine:"

	# --- MODIFIED BLOCK ---
	# This now checks the object's location before creating the "Walk to" text.
	elif hovered_interactable and hovered_interactable.interaction_location == Interactable.InteractionLocation.WORLD:
		line_text = "Walk to: " + hovered_interactable.object_display_name

	# If line_text is still empty, it means no verb or item is selected, and nothing is hovered.
	# The UI should handle an empty string appropriately (e.g., hide the sentence line label).
	sentence_line_updated.emit(line_text)


func process_interaction_click(interactable_node: Interactable):
	# The initial check for _is_player_walking has been removed.

	if not is_instance_valid(interactable_node):
		print_rich("[color=red]GM: process_interaction_click with null or invalid interactable.[/color]")
		return

	print_rich("[color=aqua]GM: process_interaction_click on '%s'. Current Verb: '%s', Current Item: '%s'[/color]" % [
		interactable_node.object_display_name,
		current_verb_id if current_verb_id else "None",
		current_selected_item_data.display_name if current_selected_item_data else "None"
	])

	if current_verb_id == USE_ON_TARGET_VERB_ID:
		# --- Handling for explicit "Use Item With Target" verb ---
		if current_selected_item_data != null:
			# Both "Use With" verb and a source item are selected. Proceed.
			print_rich("[color=green]GM: Processing 'Use With': Item '%s' ON Target '%s'[/color]" % [current_selected_item_data.display_name, interactable_node.object_display_name])
			_initiate_interaction_flow(interactable_node, USE_ON_TARGET_VERB_ID, current_selected_item_data)
		else:
			# "Use With" verb is active, but no source item selected. Inform player.
			print_rich("[color=orange]GM: Cannot 'Use With' on '%s'. No source item selected from inventory.[/color]" % interactable_node.object_display_name)
			return

	elif current_selected_item_data != null: # No specific verb, but an item is "in hand" (implicit use)
		print_rich("[color=green]GM: Processing implicit item use: Item '%s' with Target '%s'[/color]" % [current_selected_item_data.display_name, interactable_node.object_display_name])
		_initiate_interaction_flow(interactable_node, IMPLICIT_USE_ITEM_VERB_ID, current_selected_item_data)

	elif current_verb_id != "": # A verb (other than "Use With") is selected, no item "in hand"
		print_rich("[color=green]GM: Processing verb: '%s' on Target '%s'[/color]" % [current_verb_id, interactable_node.object_display_name])
		_initiate_interaction_flow(interactable_node, current_verb_id, null)

	else: # No verb and no item selected.
		# The default "Walk to" action should ONLY apply to objects in the main world.
		if interactable_node.interaction_location == Interactable.InteractionLocation.WORLD:
			print_rich("[color=green]GM: Processing default 'Walk to' on Target '%s'[/color]" % interactable_node.object_display_name)
			_initiate_interaction_flow(interactable_node, WALK_TO_VERB_ID, null)
		else:
			# For UI objects, do nothing if no verb/item is selected. This is the desired behavior.
			print_rich("[color=yellow]GM: No verb/item selected for interaction with UI object '%s'. Ignoring click.[/color]" % interactable_node.object_display_name)
			return


func _initiate_interaction_flow(interactable_node: Interactable, verb_to_use_id: String, item_data_to_use: ItemData):
	if not is_instance_valid(interactable_node):
		print_rich("[color=red]GM: _initiate_interaction_flow called with invalid interactable_node.[/color]")
		_complete_interaction_cycle(); return

	var walk_needed = true

	if interactable_node.interaction_location == Interactable.InteractionLocation.UI_OVERLAY:
		walk_needed = false
	else:
		if interactable_node.has_method("does_verb_require_walk"):
			walk_needed = interactable_node.does_verb_require_walk(verb_to_use_id, item_data_to_use)
		else:
			print_rich("[color=yellow]GM: Interactable '%s' no 'does_verb_require_walk'. Assuming walk needed.[/color]" % interactable_node.name)
			walk_needed = true

	var item_name_for_log = "None"
	if item_data_to_use: item_name_for_log = item_data_to_use.display_name
	print_rich("[color=aqua]GM: Initiating flow: Verb '%s' on '%s' with item '%s'. Requires walk: %s[/color]" % [verb_to_use_id, interactable_node.object_display_name, item_name_for_log, str(walk_needed)])

	if walk_needed:
		# --- THIS IS THE FIX ---
		# Set the lock flag to true before telling the player to walk.
		_is_player_walking = true
		if not is_instance_valid(player_node):
			print_rich("[color=red]GM: Player node not set or invalid. Interacting immediately (if possible).[/color]")
			_perform_actual_interaction(interactable_node, verb_to_use_id, item_data_to_use)
			return
		if player_node.has_method("walk_to_and_interact"):
			var walk_target_pos = interactable_node.get_walk_to_position()
			player_node.walk_to_and_interact(walk_target_pos, interactable_node, verb_to_use_id, item_data_to_use)
		else:
			print_rich("[color=orange]GM: Player '%s' no 'walk_to_and_interact'. Interacting immediately.[/color]" % player_node.name)
			_perform_actual_interaction(interactable_node, verb_to_use_id, item_data_to_use)
	else:
		if is_instance_valid(player_node) and player_node.has_method("face_target"):
			if interactable_node.interaction_location == Interactable.InteractionLocation.WORLD:
				player_node.face_target(interactable_node.global_position)
		_perform_actual_interaction(interactable_node, verb_to_use_id, item_data_to_use)

# --- ADD THIS ENTIRE NEW FUNCTION ---
# The player will call this function to "unlock" input once they have stopped moving.
func player_has_finished_walk_command():
	_is_player_walking = false


func player_reached_interaction_target(interactable_node: Interactable, verb_to_use_id: String, item_data_to_use: ItemData):
	print_rich("[color=aqua]GM: Player has reached target '%s'. Performing interaction.[/color]" % interactable_node.object_display_name if is_instance_valid(interactable_node) else "[color=red]INVALID TARGET[/color]")
	if not is_instance_valid(interactable_node):
		print_rich("[color=red]GM: Player reached target, but interactable is no longer valid. Aborting interaction.[/color]")
		_complete_interaction_cycle(); return
	_perform_actual_interaction(interactable_node, verb_to_use_id, item_data_to_use)

func _perform_actual_interaction(interactable_node: Interactable, verb_to_use_id: String, item_in_hand_data: ItemData = null):
	if not is_instance_valid(interactable_node):
		print_rich("[color=red]GM: _perform_actual_interaction called with invalid interactable_node.[/color]")
		_complete_interaction_cycle(); return

	var item_name_for_log = "None"
	var item_id_for_interaction = ""
	if item_in_hand_data:
		item_name_for_log = item_in_hand_data.display_name
		item_id_for_interaction = item_in_hand_data.item_id

	print_rich("[color=aqua]GM: Performing actual interaction: Verb '%s' on '%s' with 'in-hand' item: '%s' (ID: '%s')[/color]" % [verb_to_use_id, interactable_node.object_display_name, item_name_for_log, item_id_for_interaction])

	_disconnect_interactable_request_signals()

	_signals_connected_to_interactable = interactable_node
	print_rich("[color=gray]GM: Connecting signals to Interactable: %s for non-dialogue interaction.[/color]" % interactable_node.name)

	if not interactable_node.display_dialogue.is_connected(_on_interactable_display_dialogue_console):
		interactable_node.display_dialogue.connect(_on_interactable_display_dialogue_console)
	if not interactable_node.interaction_processed.is_connected(_on_interactable_action_finished):
		interactable_node.interaction_processed.connect(_on_interactable_action_finished)
	if interactable_node.has_signal("request_remove_item_from_inventory") and not interactable_node.request_remove_item_from_inventory.is_connected(remove_item_from_inventory):
		interactable_node.request_remove_item_from_inventory.connect(remove_item_from_inventory)
	if interactable_node.has_signal("request_add_item_to_inventory") and not interactable_node.request_add_item_to_inventory.is_connected(add_item_to_inventory):
		interactable_node.request_add_item_to_inventory.connect(add_item_to_inventory)
	if interactable_node.has_signal("request_set_game_flag") and not interactable_node.request_set_game_flag.is_connected(set_game_flag):
		interactable_node.request_set_game_flag.connect(set_game_flag)
	if interactable_node.has_signal("request_set_level_flag") and not interactable_node.request_set_level_flag.is_connected(set_current_level_flag):
		print_rich("[color=darkcyan]GM: Connecting Interactable's request_set_level_flag to GM.set_current_level_flag[/color]")
		interactable_node.request_set_level_flag.connect(set_current_level_flag)

	interactable_node.attempt_interaction(verb_to_use_id, item_id_for_interaction)

# --- DialogueManager Signal Handlers (Global) ---
func _on_dialogue_started(_resource: Resource):
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)

	# --- ADD THIS BLOCK ---
	# Hide the main UI whenever any dialogue line appears.
	# This handles both in-world dialogue and character conversations.
	if is_instance_valid(verb_ui):
		verb_ui.visible = false
	if is_instance_valid(inventory_ui):
		inventory_ui.visible = false


func _on_dialogue_ended_for_object_dialogue(_resource: Resource):
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	# --- THIS IS THE FIX ---
	# Restore the main UI as long as we are NOT in a full-screen conversation.
	# This now correctly handles both the WORLD and the ZOOM_VIEW states.
	if current_interaction_state != InteractionState.CONVERSATION:
		if is_instance_valid(verb_ui):
			verb_ui.visible = true
		if is_instance_valid(inventory_ui):
			inventory_ui.visible = true

	_complete_interaction_cycle()

# Replace the entire existing function with this one.
func _on_character_conversation_finished(resource: DialogueResource):
	# First, perform all the necessary cleanup and state changes.
	exit_to_world_state()

	if _current_character_conversation_overlay_instance:
		_current_character_conversation_overlay_instance.queue_free()
		_current_character_conversation_overlay_instance = null

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	_complete_interaction_cycle()

	# Now, simply announce that a conversation ended, and pass along which one.
	# The Main scene will be listening for this.
	character_conversation_ended.emit(resource)


# --- Interactable Signal Handlers ---
func _on_interactable_display_dialogue_console(text: String):
	print_rich("[color=yellow]GM (via Interactable Console): %s[/color]" % text)

func _on_interactable_action_finished():
	print_rich("[color=aqua]GM: Interactable action finished. Completing interaction cycle.[/color]")
	_complete_interaction_cycle()

func _disconnect_interactable_request_signals():
	if is_instance_valid(_signals_connected_to_interactable):
		var node_to_disconnect_from = _signals_connected_to_interactable
		print_rich("[color=gray]GM: Disconnecting signals from Interactable: %s[/color]" % node_to_disconnect_from.name)

		if node_to_disconnect_from.display_dialogue.is_connected(_on_interactable_display_dialogue_console):
			node_to_disconnect_from.display_dialogue.disconnect(_on_interactable_display_dialogue_console)
		if node_to_disconnect_from.interaction_processed.is_connected(_on_interactable_action_finished):
			node_to_disconnect_from.interaction_processed.disconnect(_on_interactable_action_finished)
		if node_to_disconnect_from.has_signal("request_remove_item_from_inventory") and \
		   node_to_disconnect_from.request_remove_item_from_inventory.is_connected(remove_item_from_inventory):
			node_to_disconnect_from.request_remove_item_from_inventory.disconnect(remove_item_from_inventory)
		if node_to_disconnect_from.has_signal("request_add_item_to_inventory") and \
		   node_to_disconnect_from.request_add_item_to_inventory.is_connected(add_item_to_inventory):
			node_to_disconnect_from.request_add_item_to_inventory.disconnect(add_item_to_inventory)
		if node_to_disconnect_from.has_signal("request_set_game_flag") and \
		   node_to_disconnect_from.request_set_game_flag.is_connected(set_game_flag):
			node_to_disconnect_from.request_set_game_flag.disconnect(set_game_flag)
		if node_to_disconnect_from.has_signal("request_set_level_flag") and \
		   node_to_disconnect_from.request_set_level_flag.is_connected(set_current_level_flag):
			print_rich("[color=gray]GM: Disconnecting Interactable's request_set_level_flag from GM.set_current_level_flag[/color]")
			node_to_disconnect_from.request_set_level_flag.disconnect(set_current_level_flag)
	else:
		if _signals_connected_to_interactable != null:
			print_rich("[color=yellow]GM: Tried to disconnect signals, but _signals_connected_to_interactable was invalid.[/color]")

	_signals_connected_to_interactable = null

func _complete_interaction_cycle():
	print_rich("[color=cyan]GM: Interaction cycle fully complete. Resetting state.[/color]")
	_disconnect_interactable_request_signals()
	interaction_complete.emit()

	current_verb_id = ""
	if current_selected_item_data:
		current_selected_item_data = null
		selected_inventory_item_changed.emit(null)

	update_sentence_line_ui()


# --- LevelStateManager Registration & Flag Handling ---
func register_level_state_manager(lsm: LevelStateManager):
	current_level_state_manager = lsm
	if is_instance_valid(lsm):
		print_rich("[color=LawnGreen]GM: Registered LevelStateManager: %s (from scene: %s)[/color]" % [lsm.name, lsm.get_parent().name if lsm.get_parent() else "N/A"])
		if lsm.has_method("print_initial_flags"):
			lsm.print_initial_flags()
	else:
		if lsm == null:
			print_rich("[color=yellow]GM: LevelStateManager unregistered (set to null).[/color]")
		else:
			print_rich("[color=orange]GM: Attempted to register invalid LevelStateManager instance.[/color]")

func set_current_level_flag(flag_name: String, value: bool):
	if is_instance_valid(current_level_state_manager):
		print_rich("[color=darkcyan]GM: Routing to LevelStateManager to set flag: %s = %s[/color]" % [flag_name, value])
		current_level_state_manager.set_level_flag(flag_name, value)
	else:
		print_rich("[color=orange]GM: No current LevelStateManager to set level flag '%s'. This might be an error if a level flag was intended.[/color]" % flag_name)

func get_current_level_flag(flag_name: String) -> bool:
	if is_instance_valid(current_level_state_manager):
		return current_level_state_manager.get_level_flag(flag_name)
	return false


# --- Verb Data and Availability ---
# In GameManager.gd

func get_verb_data_by_id(verb_id_to_find: String) -> VerbData:
	var id_for_lookup = verb_id_to_find

	# --- NEW LOGIC: DATA MAPPING ---
	# If the game's internal logic asks for an implicit or target-based "use" verb,
	# we remap it to the single, public "use" verb ID. This ensures that all "use"
	# actions correctly find the data stored in "use_verb.tres".
	if verb_id_to_find == IMPLICIT_USE_ITEM_VERB_ID or verb_id_to_find == USE_ON_TARGET_VERB_ID:
		id_for_lookup = "use"

	# The rest of the function remains the same. It now searches for "use".
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.verb_id == id_for_lookup:
			return verb_data_res

	# If nothing is found, return null as before.
	return null

func get_currently_displayable_verbs() -> Array[VerbData]:
	var displayable_verbs: Array[VerbData] = []
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.verb_id in unlocked_verb_ids:
			if active_scene_verb_ids.is_empty() or verb_data_res.verb_id in active_scene_verb_ids:
				displayable_verbs.append(verb_data_res)
	return displayable_verbs

func _emit_available_verbs_changed_update():
	available_verbs_changed.emit(get_currently_displayable_verbs())

func set_active_scene_verbs(verb_ids_for_scene: Array[String]):
	active_scene_verb_ids = verb_ids_for_scene.duplicate()
	_emit_available_verbs_changed_update()
	if current_verb_id != "" and not is_verb_id_currently_active(current_verb_id):
		select_verb("")

func unlock_verb(verb_id_to_unlock: String):
	var verb_data = get_verb_data_by_id(verb_id_to_unlock)
	if verb_data and not verb_id_to_unlock in unlocked_verb_ids:
		unlocked_verb_ids.append(verb_id_to_unlock)
		_emit_available_verbs_changed_update()
		print_rich("[color=green]GM: Unlocked verb: %s[/color]" % verb_id_to_unlock)
	elif not verb_data: print_rich("[color=red]GM: Tried to unlock non-existent verb: '%s'[/color]" % verb_id_to_unlock)
	elif verb_id_to_unlock in unlocked_verb_ids: print_rich("[color=yellow]GM: Verb '%s' already unlocked.[/color]" % verb_id_to_unlock)

func lock_verb(verb_id_to_lock: String):
	if verb_id_to_lock in unlocked_verb_ids:
		unlocked_verb_ids.erase(verb_id_to_lock)
		_emit_available_verbs_changed_update()
		print_rich("[color=yellow]GM: Locked verb: %s[/color]" % verb_id_to_lock)
		if current_verb_id == verb_id_to_lock:
			select_verb("")
	else: print_rich("[color=orange]GM: Tried to lock verb '%s' that was not unlocked or doesn't exist.[/color]" % verb_id_to_lock)

func is_verb_id_currently_active(verb_id_to_check: String) -> bool:
	if not verb_id_to_check in unlocked_verb_ids: return false
	if active_scene_verb_ids.is_empty(): return true
	return active_scene_verb_ids.has(verb_id_to_check)


# --- Inventory Management Functions ---
func add_item_to_inventory(item_id_to_add: String):
	print_rich("[color=aqua]GM: Attempting add_item_to_inventory for ID: '%s'[/color]" % item_id_to_add)
	var item_data = get_item_data_by_id(item_id_to_add)
	if not item_data:
		print_rich("[color=red]GM: add_item_to_inventory - FAILED. ItemData for id '%s' is null after lookup.[/color]" % item_id_to_add)
		return

	if not item_data.is_stackable and has_item(item_id_to_add):
		print_rich("[color=yellow]GM: Item '%s' (Name: %s, non-stackable) already in inventory. Not adding duplicate.[/color]" % [item_id_to_add, item_data.display_name])
		return

	player_inventory.append(item_data)
	inventory_updated.emit(player_inventory.duplicate())
	print_rich("[color=green]GM: Successfully added item '%s' (Name: %s) to inventory. Player now has %s items.[/color]" % [item_id_to_add, item_data.display_name, player_inventory.size()])
	show_notification("Picked up: " + item_data.display_name)

func remove_item_from_inventory(item_id_to_remove: String):
	print_rich("[color=aqua]GM: Attempting remove_item_from_inventory for ID: '%s'[/color]" % item_id_to_remove)
	var item_data_ref = get_item_data_by_id(item_id_to_remove)
	if not item_data_ref:
		print_rich("[color=red]GM: remove_item_from_inventory - FAILED. ItemData for id '%s' not found in master list.[/color]" % item_id_to_remove)
		return

	var item_found_and_removed = false
	for i in range(player_inventory.size() - 1, -1, -1):
		var item_data_in_inv: ItemData = player_inventory[i]
		if item_data_in_inv.item_id == item_id_to_remove:
			player_inventory.remove_at(i)
			item_found_and_removed = true
			print_rich("[color=green]GM: Removed item '%s' (Name: %s) from inventory.[/color]" % [item_id_to_remove, item_data_in_inv.display_name])

			if current_selected_item_data and current_selected_item_data.item_id == item_id_to_remove:
				current_selected_item_data = null
				selected_inventory_item_changed.emit(null)

			inventory_updated.emit(player_inventory.duplicate())
			if not item_data_ref.is_stackable: break

	if not item_found_and_removed:
		print_rich("[color=yellow]GM: Tried to remove item_id '%s' (Name: %s), but it was not found in player's inventory.[/color]" % [item_id_to_remove, item_data_ref.display_name])

func has_item(item_id_to_check: String) -> bool:
	for item_data_in_inv in player_inventory:
		if item_data_in_inv.item_id == item_id_to_check:
			return true
	return false

func get_item_data_by_id(item_id_to_find: String) -> ItemData:
	if _item_data_map.has(item_id_to_find):
		return _item_data_map[item_id_to_find]

	print_rich("[color=orange]GM: get_item_data_by_id - ItemData for id '%s' NOT FOUND in _item_data_map.[/color]" % item_id_to_find)
	print_rich("  [color=gray]GM: Current _item_data_map keys: %s[/color]" % str(_item_data_map.keys()))
	print_rich("  [color=gray]GM: Make sure '%s' is the exact item_id in your .tres file AND that .tres file is in 'all_item_data_resources' in GameManager Inspector.[/color]" % item_id_to_find)
	return null

func get_player_inventory() -> Array[ItemData]:
	return player_inventory.duplicate()


# --- Game Flag Management (Global) ---
func set_game_flag(flag_name: String, value: bool):
	if game_flags.get(flag_name, !value) == value:
		return
	game_flags[flag_name] = value
	print_rich("[color=green]GM: GLOBAL Flag set: '%s' = %s[/color]" % [flag_name, str(value)])

func get_game_flag(flag_name: String) -> bool:
	return game_flags.get(flag_name, false)

# ADD THESE THREE NEW FUNCTIONS

func enter_conversation_state():
	if current_interaction_state == InteractionState.CONVERSATION: return
	print_rich("[color=Plum]GM: Entering CONVERSATION state.[/color]")
	current_interaction_state = InteractionState.CONVERSATION

	# --- DEBUGGING STEP ---
	# Let's see if the GameManager can actually see your button node.
	print("Attempting to hide button UI. Node is: ", insurance_form_button_ui)
	# --- END DEBUGGING STEP ---

	# Show the blocker on layer 1 to stop clicks to the world (layer 0)
	if is_instance_valid(input_blocker_layer):
		input_blocker_layer.visible = true

	# Hide the game UI
	if is_instance_valid(verb_ui): verb_ui.visible = false
	if is_instance_valid(inventory_ui): inventory_ui.visible = false
	if is_instance_valid(insurance_form_button_ui): insurance_form_button_ui.visible = false

func enter_zoom_view_state():
	if current_interaction_state == InteractionState.ZOOM_VIEW: return
	print_rich("[color=Plum]GM: Entering ZOOM_VIEW state.[/color]")
	current_interaction_state = InteractionState.ZOOM_VIEW

	# ... (existing code for input blocker and UI layers) ...
	if is_instance_valid(input_blocker_layer):
		input_blocker_layer.visible = true
	if is_instance_valid(verb_ui):
		verb_ui.layer = 3
		verb_ui.visible = true
	if is_instance_valid(inventory_ui):
		inventory_ui.layer = 3
		inventory_ui.visible = true

	# --- THIS IS STILL IMPORTANT ---
	# Explicitly disabling player movement prevents weird input bugs on un-pause.
	if is_instance_valid(player_node):
		player_node.set_can_move(false)
	# -----------------------------

	# --- PAUSE THE ENTIRE GAME ---
	# This stops _process and _physics_process for all nodes unless their
	# process_mode is set to "Always".
	get_tree().paused = true
	# -----------------------------

func exit_to_world_state():
	print_rich("[color=Plum]GM: Exiting overlay, returning to WORLD state.[/color]")
	current_interaction_state = InteractionState.WORLD

	if is_instance_valid(input_blocker_layer):
		input_blocker_layer.visible = false
	if is_instance_valid(verb_ui):
		verb_ui.layer = 1
		verb_ui.visible = true
	if is_instance_valid(inventory_ui):
		inventory_ui.layer = 1
		inventory_ui.visible = true

	# --- THIS IS THE FIX (APPLIED HERE AS WELL) ---
	# Check the flag here too, so the button reappears after future conversations.
	if is_instance_valid(insurance_form_button_ui):
		var should_be_visible = get_current_level_flag("insurance_button_unlocked")
		insurance_form_button_ui.visible = should_be_visible
	# --- END OF FIX ---

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	get_tree().paused = false


# In GameManager.gd
# Replace your entire _find_and_assign_ui_nodes function with this one.

# In GameManager.gd
# Replace the entire function.

func _find_and_assign_ui_nodes():
	# Check if we even have a main scene to search in.
	if not is_instance_valid(main_game_scene_instance):
		print_rich("[color=red]GM: Cannot find UI nodes because main_game_scene_instance is not valid.[/color]")
		return

	# Tell Godot to look INSIDE the main scene for these nodes using their Unique Scene Names.
	verb_ui = main_game_scene_instance.get_node_or_null("%VerbUI_CanvasLayer")
	inventory_ui = main_game_scene_instance.get_node_or_null("%InventoryUI_CanvasLayer")
	insurance_form_button_ui = main_game_scene_instance.get_node_or_null("%InsuranceFormButtonUI")
	input_blocker_layer = main_game_scene_instance.get_node_or_null("%InputBlockerLayer")
	explanation_layer = main_game_scene_instance.get_node_or_null("%ExplanationLayer")

	# --- Verification Logging ---
	if is_instance_valid(verb_ui):
		print_rich("[color=green]GM: Successfully found and assigned VerbUI.[/color]")
	else:
		print_rich("[color=red]GM: FAILED to find VerbUI.[/color]")

	if is_instance_valid(inventory_ui):
		print_rich("[color=green]GM: Successfully found and assigned InventoryUI.[/color]")
	else:
		print_rich("[color=red]GM: FAILED to find InventoryUI.[/color]")

	if is_instance_valid(insurance_form_button_ui):
		print_rich("[color=green]GM: Successfully found and assigned InsuranceFormButtonUI.[/color]")
		# --- THIS IS THE CORRECTED LINE ---
		# We now connect to the 'form_button_pressed' signal that your script emits.
		if not insurance_form_button_ui.form_button_pressed.is_connected(_on_insurance_form_button_pressed):
			insurance_form_button_ui.form_button_pressed.connect(_on_insurance_form_button_pressed)
	else:
		print_rich("[color=red]GM: FAILED to find InsuranceFormButtonUI.[/color]")

	if is_instance_valid(input_blocker_layer):
		print_rich("[color=green]GM: Successfully found and assigned InputBlockerLayer.[/color]")
	else:
		print_rich("[color=red]GM: FAILED to find InputBlockerLayer.[/color]")

	if is_instance_valid(explanation_layer):
		print_rich("[color=green]GM: Successfully found and assigned ExplanationLayer.[/color]")
		if not explanation_layer.explanation_finished.is_connected(exit_explanation_state):
			explanation_layer.explanation_finished.connect(exit_explanation_state)
	else:
		print_rich("[color=red]GM: FAILED to find ExplanationLayer.[/color]")
func _on_form_field_submitted(field_id: String, value):
	# Log the incoming data for debugging.
	print_rich("[color=Cyan]GM: Received submission for field '%s' with value: %s[/color]" % [field_id, value])

	# Use a 'match' statement to cleanly handle each field's data.
	match field_id:
		"first_name":
			# --- YOUR GAME LOGIC FOR THE NAME GOES HERE ---
			if value.to_lower() == "jane": # Example correct answer
				print_rich("[color=Green]GM Feedback: That name sounds familiar.[/color]")
				# TODO: Play a 'correct' sound, set a flag, etc.
				# set_game_flag("first_name_correct", true)
			else:
				print_rich("[color=Orange]GM Feedback: That name doesn't seem right...[/color]")
				# TODO: Play an 'incorrect' sound.

		"date_of_birth":
			# --- YOUR GAME LOGIC FOR THE DATE OF BIRTH GOES HERE ---
			if value == "12/05/2003": # Example correct answer
				print_rich("[color=Green]GM Feedback: The date has a certain significance.[/color]")
				# TODO: Play a 'correct' sound, set a flag, etc.
				# set_game_flag("dob_correct", true)
			else:
				print_rich("[color=Orange]GM Feedback: That date means nothing to me.[/color]")
				# TODO: Play an 'incorrect' sound.
# This function is called ONLY when the "Close Form" button is pressed.
func _on_insurance_form_closed():
	print_rich("[color=Yellow]GM: Insurance form was closed by the player.[/color]")

	# Clean up our reference to the form instance. This is important.
	_insurance_form_instance = null

	# Return control to the player and un-pause the game.
	exit_to_world_state()


# Add these new functions to the end of GameManager.gd
# In GameManager.gd
# Replace the entire existing function with this one.

func start_explanation(data: ExplanationData, root_node_to_search: Node):
	if current_game_state == GameState.EXPLANATION or not is_instance_valid(explanation_layer):
		return

	change_game_state(GameState.EXPLANATION)

	# --- THIS IS THE NEW, SMARTER HIDING LOGIC ---
	var nodes_to_keep_visible = []

	# --- THIS IS THE FIX ---
	# A Resource doesn't have a ".has()" method. The correct way to check for a property
	# is using the 'in' keyword.
	if "exceptions_to_hide" in data:
	# --- END OF FIX ---
		for node_path in data.exceptions_to_hide:
			var node = root_node_to_search.get_node_or_null(node_path)
			if is_instance_valid(node):
				nodes_to_keep_visible.append(node)

	if is_instance_valid(verb_ui) and not verb_ui in nodes_to_keep_visible:
		verb_ui.hide()

	if is_instance_valid(inventory_ui) and not inventory_ui in nodes_to_keep_visible:
		inventory_ui.hide()

	if is_instance_valid(insurance_form_button_ui):
		if insurance_form_button_ui in nodes_to_keep_visible:
			insurance_form_button_ui.show()
		else:
			insurance_form_button_ui.hide()
	# --- END OF NEW LOGIC ---

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)

	get_tree().paused = true
	explanation_layer.show_explanation(data, root_node_to_search)

func exit_explanation_state():
	if current_game_state != GameState.EXPLANATION:
		return

	print_rich("[color=Plum]GM: Exiting EXPLANATION, returning to IN_GAME_PLAY state.[/color]")

	get_tree().paused = false

	# Show the main game UI
	if is_instance_valid(verb_ui): verb_ui.visible = true
	if is_instance_valid(inventory_ui): inventory_ui.visible = true

	# --- THIS IS THE FIX ---
	# Instead of just showing the button, check if it has been unlocked.
	if is_instance_valid(insurance_form_button_ui):
		var should_be_visible = get_current_level_flag("insurance_button_unlocked")
		insurance_form_button_ui.visible = should_be_visible
	# --- END OF FIX ---

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	change_game_state(GameState.IN_GAME_PLAY)

# In GameManager.gd
# Add these three missing functions to the end of the script.

# This function runs when the main UI button (on the game screen) is pressed.
func _on_insurance_form_button_pressed():
	# If a form is already open, do nothing. Prevents opening multiple forms.
	if is_instance_valid(_insurance_form_instance):
		return

	print_rich("[color=LawnGreen]GM: Opening insurance form...[/color]")

	# Create a new instance of our form scene.
	_insurance_form_instance = INSURANCE_FORM_SCENE.instantiate()

	# --- CONNECT TO THE NEW SIGNALS ---
	# Connect to the signal that's emitted when ANY "OK" button is pressed.
	_insurance_form_instance.field_submitted.connect(_on_form_field_submitted)
	# Connect to the signal that's emitted ONLY when the "Close Form" button is pressed.
	_insurance_form_instance.form_closed.connect(_on_insurance_form_closed)
	# ----------------------------------

	# Add the form to the main scene tree so it becomes visible.
	get_tree().root.add_child(_insurance_form_instance)

	# The form's own script hides it by default, so we show it now.
	_insurance_form_instance.show()

	# Pause the game world and disable player movement.
	enter_zoom_view_state()

# This function receives data from ANY "OK" button on the form.
func show_notification(message: String):
	notification_requested.emit(message)


func _on_main_menu_new_game_requested():
	print_rich("[color=LawnGreen]GM: 'New Game' requested. Starting intro sequence...[/color]")
	# We simply change the state. The change_game_state function will handle
	# cleaning up the menu and starting the next part of the game.
	change_game_state(GameState.INTRO_CONVERSATION)


func _on_main_menu_quit_requested():
	print_rich("[color=LawnGreen]GM: 'Quit Game' requested. Closing application.[/color]")
	get_tree().quit()


func _start_intro_conversation():
	print_rich("[color=yellow]GM: Starting intro sequence...[/color]")

	var intro_overlay_packed_scene = load(INTRO_OVERLAY_SCENE_PATH)
	if not intro_overlay_packed_scene:
		print_rich("[color=red]GM Error: Failed to load Intro Overlay Scene at path: %s[/color]" % INTRO_OVERLAY_SCENE_PATH)
		return

	var intro_overlay = intro_overlay_packed_scene.instantiate()

	# Configure its exported variables from code.
	intro_overlay.conversation_dialogue_file = load(INTRO_DIALOGUE_FILE_PATH)
	intro_overlay.background_animations = load(INTRO_BACKGROUND_ANIMATIONS_PATH)
	intro_overlay.initial_animation_name = INTRO_INITIAL_ANIMATION_NAME

	# Connect to its 'conversation_finished' signal.
	intro_overlay.conversation_finished.connect(_on_intro_conversation_finished, CONNECT_ONE_SHOT)

	# Add it to the scene tree so it becomes visible and starts running.
	get_tree().root.add_child(intro_overlay)


func _on_intro_conversation_finished(_dialogue_resource):
	print_rich("[color=yellow]GM: Intro conversation finished. Transitioning to main game...[/color]")
	# The intro is over, so we tell the GameManager to load the main game world.
	change_game_state(GameState.IN_GAME_PLAY)
