# GameManager.gd
extends Node

const MAIN_GAME_SCENE_PATH = "res://main.tscn"
# --- Signals ---
signal verb_changed(new_verb_id: String)
signal sentence_line_updated(text: String)
signal interaction_complete # For VerbUI to reset its state
signal available_verbs_changed(available_verb_data_array: Array[VerbData])

# Inventory Signals
signal inventory_updated(inventory_items: Array[ItemData])
signal selected_inventory_item_changed(selected_item_data: ItemData) # "In Hand" / "Selected"

# --- High-Level Game State Management ---
# 1. Define the game states using an enum for clarity and safety.
# In GameManager.gd
enum GameState {
	BOOTING,
	LOGO_SPLASH,            # <-- NEW STATE
	INTRO_CONVERSATION,
	IN_GAME_PLAY,
	PAUSED
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
var verb_ui: CanvasLayer = null
var inventory_ui: CanvasLayer = null

# --- END of Interaction Context Management ---
# 2. Create a variable to hold the current state.
var current_game_state: GameState = GameState.BOOTING

# 3. Reference to your main game scene instance.
#    The Boot.gd script will set this reference for us later.
var main_game_scene_instance: Node = null
# --- END of High-Level Game State Management ---
var input_blocker_layer: CanvasLayer = null
# --- State Variables ---
var current_verb_id: String = ""
var current_selected_item_data: ItemData = null # "In Hand" / "Selected" item
var hovered_interactable: Interactable = null
var player_node: CharacterBody2D

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
const IMPLICIT_USE_ITEM_VERB_ID: String = "use_item" # For direct item click on interactable
const USE_ON_TARGET_VERB_ID: String = "use_on_target" # For "Use Item X WITH Y" verb


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

func change_game_state(new_state: GameState):
	# Don't do anything if we are already in the target state.
	if new_state == current_game_state:
		return

	# Print a clear log message for debugging.
	# GameState.keys()[current_game_state] gets the string name of the enum value.
	print_rich("[color=yellow]GameManager: Changing state from %s to %s[/color]" % [GameState.keys()[current_game_state], GameState.keys()[new_state]])
	current_game_state = new_state

	# This 'match' statement is like a big 'if/elif/else' block.
	# It handles what to do when we ENTER a new state.
	match current_game_state:
		GameState.INTRO_CONVERSATION:
			# When the intro starts, we want to make sure the main game is hidden
			# and that player input is disabled.
			if is_instance_valid(main_game_scene_instance):
				main_game_scene_instance.visible = false

			# Disable player movement (you already have similar logic elsewhere)
			if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
				player_node.set_can_move(false)

		GameState.IN_GAME_PLAY:
			# If the main scene already exists for some reason, we're done.
			if is_instance_valid(main_game_scene_instance):
				return

			# 1. Load the main game scene resource
			var main_packed_scene = load(MAIN_GAME_SCENE_PATH)
			if not main_packed_scene:
				print_rich("[color=red]GameManager Error: Failed to load Main Game Scene.[/color]")
				return

			# 2. Instantiate it
			main_game_scene_instance = main_packed_scene.instantiate()

			# 3. Find the Boot node to add the scene to the tree
			var boot_node = get_tree().root.get_node("Boot")
			if not is_instance_valid(boot_node):
				print_rich("[color=red]GameManager Error: Could not find 'Boot' node in scene tree to add main scene.[/color]")
				# Fallback to adding to root, but this is not ideal
				get_tree().root.add_child(main_game_scene_instance)
			else:
				boot_node.add_child(main_game_scene_instance)

			_find_and_assign_ui_nodes()
			# 4. Initialize the player (this logic can stay the same)
			if not is_instance_valid(player_node):
				player_node = get_tree().get_first_node_in_group("player")
				if not is_instance_valid(player_node):
					print_rich("[color=red]GM: Player node not found in group 'player' or is invalid![/color]")
				else:
					print_rich("[color=green]GM: Found player: %s[/color]" % player_node.name)

			if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
				player_node.set_can_move(true)
			# --- PASTE THE CODE HERE AND ADD A CHECK ---
			# We only need to find the player node once.
			if not is_instance_valid(player_node):
				player_node = get_tree().get_first_node_in_group("player")
				if not is_instance_valid(player_node):
					print_rich("[color=red]GM: Player node not found in group 'player' or is invalid![/color]")
				else:
					print_rich("[color=green]GM: Found player: %s[/color]" % player_node.name)

			# Enable player movement
			if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
				player_node.set_can_move(true)

		GameState.PAUSED:
			# We can add logic for a pause menu here later.
			# For example: get_tree().paused = true
			pass

		GameState.BOOTING:
			# This is the initial state, not much to do here as Boot.gd handles it.
			pass

# --- Core Functions: Verb and Item Selection (MODIFIED FOR USE_ON_TARGET_VERB_ID) ---
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
	hovered_interactable = interactable
	update_sentence_line_ui()

func clear_hovered_object():
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

	# If line_text is still empty, it means no verb or item is selected, and nothing is hovered.
	# The UI should handle an empty string appropriately (e.g., hide the sentence line label).
	sentence_line_updated.emit(line_text)
	# Optional: print for debugging sentence line changes
	# print_rich("[color=DarkTurquoise]GM UI: Sentence line updated to: '%s'[/color]" % line_text if line_text else "[color=DarkTurquoise]GM UI: Sentence line cleared[/color]")

func process_interaction_click(interactable_node: Interactable):
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
			# Optionally, emit a signal here for a UI to display this message to the player
			# display_game_message.emit("Select an item from inventory to use with that.")
			# For now, we just log it and do nothing further with the interaction.
			# We don't complete the interaction cycle here as the player might want to select an item next.
			# The sentence line UI should already reflect "Use With: None Selected ON [Target]".
			return

	elif current_selected_item_data != null: # No specific verb, but an item is "in hand" (implicit use)
		print_rich("[color=green]GM: Processing implicit item use: Item '%s' with Target '%s'[/color]" % [current_selected_item_data.display_name, interactable_node.object_display_name])
		_initiate_interaction_flow(interactable_node, IMPLICIT_USE_ITEM_VERB_ID, current_selected_item_data)

	elif current_verb_id != "": # A verb (other than "Use With") is selected, no item "in hand"
		print_rich("[color=green]GM: Processing verb: '%s' on Target '%s'[/color]" % [current_verb_id, interactable_node.object_display_name])
		_initiate_interaction_flow(interactable_node, current_verb_id, null)

	else: # No verb and no item selected.
		print_rich("[color=yellow]GM: No verb or item selected for interaction with '%s'.[/color]" % interactable_node.object_display_name)
		# Optionally, you could make this default to an "examine" action on the interactable_node
		# e.g., _initiate_interaction_flow(interactable_node, "examine", null)
		return

func _initiate_interaction_flow(interactable_node: Interactable, verb_to_use_id: String, item_data_to_use: ItemData):
	if not is_instance_valid(interactable_node):
		print_rich("[color=red]GM: _initiate_interaction_flow called with invalid interactable_node.[/color]")
		_complete_interaction_cycle(); return

	var walk_needed = true
	if interactable_node.has_method("does_verb_require_walk"):
		walk_needed = interactable_node.does_verb_require_walk(verb_to_use_id, item_data_to_use)
	else:
		print_rich("[color=yellow]GM: Interactable '%s' no 'does_verb_require_walk'. Assuming walk needed.[/color]" % interactable_node.name)

	var item_name_for_log = "None"
	if item_data_to_use: item_name_for_log = item_data_to_use.display_name
	print_rich("[color=aqua]GM: Initiating flow: Verb '%s' on '%s' with item '%s'. Requires walk: %s[/color]" % [verb_to_use_id, interactable_node.object_display_name, item_name_for_log, str(walk_needed)])

	if walk_needed:
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
			player_node.face_target(interactable_node.global_position)
		_perform_actual_interaction(interactable_node, verb_to_use_id, item_data_to_use)

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

	if verb_to_use_id == "examine":
		if not player_examine_lines: print_rich("[color=red]GM: player_examine_lines DialogueResource not set![/color]"); _complete_interaction_cycle(); return
		if DialogueManager: DialogueManager.dialogue_ended.connect(_on_dialogue_ended_for_object_dialogue, CONNECT_ONE_SHOT); DialogueManager.show_dialogue_balloon(player_examine_lines, interactable_node.object_id)
		else: print_rich("[color=red]GM: DialogueManager missing, cannot show examine lines.[/color]"); _complete_interaction_cycle()
		return

	if verb_to_use_id == "talk_to":
		if interactable_node.category == Interactable.ObjectCategory.CHARACTER:
			if not interactable_node.character_conversation_overlay_scene: print_rich("[color=red]GM: Character '%s' (ID: %s) has no 'character_conversation_overlay_scene'![/color]" % [interactable_node.object_display_name, interactable_node.object_id]); _complete_interaction_cycle(); return

			enter_conversation_state() # Tell GM to hide the main UI

			_current_character_conversation_overlay_instance = interactable_node.character_conversation_overlay_scene.instantiate()
			get_tree().root.add_child(_current_character_conversation_overlay_instance)
			if not _current_character_conversation_overlay_instance.conversation_finished.is_connected(_on_character_conversation_finished):
				_current_character_conversation_overlay_instance.conversation_finished.connect(_on_character_conversation_finished)
		else:
			if not player_talk_to_lines: print_rich("[color=red]GM: player_talk_to_lines DialogueResource not set![/color]"); _complete_interaction_cycle(); return
			if DialogueManager: DialogueManager.dialogue_ended.connect(_on_dialogue_ended_for_object_dialogue, CONNECT_ONE_SHOT); DialogueManager.show_dialogue_balloon(player_talk_to_lines, interactable_node.object_id)
			else: print_rich("[color=red]GM: DialogueManager missing, cannot show talk_to lines for object.[/color]"); _complete_interaction_cycle()
		return

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

func _on_character_conversation_finished(_resource: DialogueResource):
	exit_to_world_state()

	if _current_character_conversation_overlay_instance:
		_current_character_conversation_overlay_instance.queue_free()
		_current_character_conversation_overlay_instance = null

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	_complete_interaction_cycle()
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
func get_verb_data_by_id(verb_id_to_find: String) -> VerbData:
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.verb_id == verb_id_to_find: return verb_data_res
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

	# Show the blocker on layer 1 to stop clicks to the world (layer 0)
	if is_instance_valid(input_blocker_layer):
		input_blocker_layer.visible = true

	# Hide the game UI
	if is_instance_valid(verb_ui): verb_ui.visible = false
	if is_instance_valid(inventory_ui): inventory_ui.visible = false

func enter_zoom_view_state():
	if current_interaction_state == InteractionState.ZOOM_VIEW: return
	print_rich("[color=Plum]GM: Entering ZOOM_VIEW state.[/color]")
	current_interaction_state = InteractionState.ZOOM_VIEW

	# Show the blocker on layer 1 to stop clicks to the world (layer 0)
	if is_instance_valid(input_blocker_layer):
		input_blocker_layer.visible = true

	# Move the game UI to layer 3 so it's on top of the overlay (which will be on layer 2)
	if is_instance_valid(verb_ui):
		verb_ui.layer = 3
		verb_ui.visible = true
	if is_instance_valid(inventory_ui):
		inventory_ui.layer = 3
		inventory_ui.visible = true

func exit_to_world_state():
	print_rich("[color=Plum]GM: Exiting overlay, returning to WORLD state.[/color]")
	current_interaction_state = InteractionState.WORLD

	# Hide the blocker
	if is_instance_valid(input_blocker_layer):
		input_blocker_layer.visible = false

	# Restore the game UI to its default layer 1
	if is_instance_valid(verb_ui):
		verb_ui.layer = 1
		verb_ui.visible = true
	if is_instance_valid(inventory_ui):
		inventory_ui.layer = 1
		inventory_ui.visible = true
func _find_and_assign_ui_nodes():
	# Check if we even have a main scene to search in.
	if not is_instance_valid(main_game_scene_instance):
		print_rich("[color=red]GM: Cannot find UI nodes because main_game_scene_instance is not valid.[/color]")
		return

	# Tell Godot to look INSIDE the main scene for these nodes.
	verb_ui = main_game_scene_instance.get_node_or_null("%VerbUI_CanvasLayer")
	inventory_ui = main_game_scene_instance.get_node_or_null("%InventoryUI_CanvasLayer")

	if is_instance_valid(verb_ui):
		print_rich("[color=green]GM: Successfully found and assigned VerbUI.[/color]")
	else:
		print_rich("[color=red]GM: FAILED to find VerbUI. Check it has a Unique Name and is named 'VerbUI_CanvasLayer' in main.tscn.[/color]")

	if is_instance_valid(inventory_ui):
		print_rich("[color=green]GM: Successfully found and assigned InventoryUI.[/color]")
	else:
		print_rich("[color=red]GM: FAILED to find InventoryUI. Check it has a Unique Name and its name is 'InventoryUI_CanvasLayer' in main.tscn.[/color]")
	input_blocker_layer = main_game_scene_instance.get_node_or_null("%InputBlockerLayer")
	if is_instance_valid(input_blocker_layer):
		print_rich("[color=green]GM: Successfully found and assigned InputBlockerLayer.[/color]")
	else:
		print_rich("[color=red]GM: FAILED to find InputBlockerLayer.[/color]")
