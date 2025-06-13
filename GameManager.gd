extends Node

# --- Signals ---
signal verb_changed(new_verb_id: String)
signal sentence_line_updated(text: String)
signal interaction_complete # For VerbUI to reset its state
signal available_verbs_changed(available_verb_data_array: Array[VerbData])

# Inventory Signals
signal inventory_updated(inventory_items: Array[ItemData])
signal selected_inventory_item_changed(selected_item_data: ItemData)

# --- State Variables ---
var current_verb_id: String = ""
var current_selected_item_data: ItemData = null
var hovered_interactable: Interactable = null
var player_node: CharacterBody2D # Should be Player class if you've class_named it

var _current_character_conversation_overlay_instance: CharacterConversationOverlay = null
var _signals_connected_to_interactable: Interactable = null # Tracks interactable for signal cleanup

# --- Verb Management ---
@export var player_examine_lines: DialogueResource
@export var player_talk_to_lines: DialogueResource
@export var all_verb_data_resources: Array[VerbData] = []
var unlocked_verb_ids: Array[String] = []
var active_scene_verb_ids: Array[String] = []

# --- Inventory Management ---
@export var all_item_data_resources: Array[ItemData] = [] # ENSURE key_rusty_item.tres IS DRAGGED HERE IN INSPECTOR
var player_inventory: Array[ItemData] = []
var _item_data_map: Dictionary = {} # item_id -> ItemData

# --- Game Flags ---
var game_flags: Dictionary = {}

# Internal verb ID for using an item on an interactable
const IMPLICIT_USE_ITEM_VERB_ID: String = "use_item"


func _ready():
	print_rich("[color=cyan]GM: GameManager is Ready! Starting initialization...[/color]")
	await get_tree().process_frame # Wait one frame for nodes to be ready

	player_node = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player_node): # More robust check
		print_rich("[color=red]GM: Player node not found in group 'player' or is invalid![/color]")
	else:
		print_rich("[color=green]GM: Found player: %s[/color]" % player_node.name)

	if DialogueManager:
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
		print_rich("[color=green]GM: Connected to DialogueManager.dialogue_started.[/color]")
	else:
		print_rich("[color=red]GM: DialogueManager not found. Dialogue start/end events won't control player movement.[/color]")

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

	# --- FOR TESTING: Add the rusty key to the inventory at start ---
	# IMPORTANT: Replace "key_rusty" with the EXACT item_id from your key_rusty_item.tres file.
	var test_item_id_to_add = "key_rusty"
	print_rich("[color=aqua]GM: Attempting to add test item '%s' to inventory...[/color]" % test_item_id_to_add)
	add_item_to_inventory(test_item_id_to_add)
	# You can add more items here for testing if you have them:
	# add_item_to_inventory("another_item_id_for_testing")

	print_rich("[color=cyan]GM: GameManager initialization complete.[/color]")


# --- Core Functions ---
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

		if current_verb_id != "" and current_selected_item_data != null:
			current_selected_item_data = null
			selected_inventory_item_changed.emit(null)
			# print("GM: Verb selected, inventory item deselected.")

	update_sentence_line_ui()
	# print("GM: Selected verb ID: '%s'" % current_verb_id) # Can be a bit noisy

func select_inventory_item(item_data_to_select: ItemData):
	if not item_data_to_select: # Called when deselecting by clicking empty space or similar
		if current_selected_item_data != null: # Only change if something was selected
			var deselected_item_name = current_selected_item_data.display_name
			current_selected_item_data = null
			selected_inventory_item_changed.emit(null)
			update_sentence_line_ui()
			print_rich("[color=lightblue]GM: Deselected inventory item: '%s' (by selecting null)[/color]" % deselected_item_name)
		return

	if current_selected_item_data == item_data_to_select: # Clicking same item deselects it
		current_selected_item_data = null
		print_rich("[color=lightblue]GM: Deselected inventory item by re-clicking: '%s'[/color]" % item_data_to_select.display_name)
	else:
		current_selected_item_data = item_data_to_select
		print_rich("[color=lightblue]GM: Selected inventory item: '%s' (ID: %s)[/color]" % [current_selected_item_data.display_name, current_selected_item_data.item_id])

		if current_verb_id != "":
			current_verb_id = ""
			verb_changed.emit("")
			# print("GM: Inventory item selected, verb deselected.")

	selected_inventory_item_changed.emit(current_selected_item_data)
	update_sentence_line_ui()

func set_hovered_object(interactable: Interactable):
	hovered_interactable = interactable
	update_sentence_line_ui()

func clear_hovered_object():
	hovered_interactable = null
	update_sentence_line_ui()

func update_sentence_line_ui():
	var line_text = ""
	if current_selected_item_data:
		line_text = current_selected_item_data.display_name
		if hovered_interactable:
			line_text += " with " + hovered_interactable.object_display_name
	elif current_verb_id != "":
		var verb_data = get_verb_data_by_id(current_verb_id)
		var display_verb_text = current_verb_id # Fallback
		if verb_data: display_verb_text = verb_data.display_text

		line_text = display_verb_text
		if hovered_interactable:
			line_text += ": " + hovered_interactable.object_display_name
		else:
			if verb_data and not verb_data.requires_target_object:
				pass # Just the verb display text, e.g., "Look Around"
			else:
				line_text += ":" # Add colon if no target, like "Examine:"

	sentence_line_updated.emit(line_text)

func process_interaction_click(interactable_node: Interactable):
	if not is_instance_valid(interactable_node):
		print_rich("[color=red]GM: process_interaction_click with null or invalid interactable.[/color]")
		return

	if current_selected_item_data:
		# print("GM: Using item '%s' on '%s'." % [current_selected_item_data.display_name, interactable_node.object_display_name])
		_initiate_interaction_flow(interactable_node, IMPLICIT_USE_ITEM_VERB_ID, current_selected_item_data)
	elif current_verb_id != "":
		# print("GM: Using verb '%s' on '%s'." % [current_verb_id, interactable_node.object_display_name])
		_initiate_interaction_flow(interactable_node, current_verb_id, null)
	else:
		print_rich("[color=yellow]GM: No verb or item selected for interaction with '%s'.[/color]" % interactable_node.object_display_name)
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
		# print("GM: Walking required.")
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
		# print("GM: No walk needed.")
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

	print_rich("[color=aqua]GM: Performing actual interaction: Verb '%s' on '%s' with item '%s' (ID: '%s')[/color]" % [verb_to_use_id, interactable_node.object_display_name, item_name_for_log, item_id_for_interaction])

	_disconnect_interactable_request_signals()

	if verb_to_use_id == "examine":
		if not player_examine_lines: print_rich("[color=red]GM: player_examine_lines DialogueResource not set![/color]"); _complete_interaction_cycle(); return
		if DialogueManager: DialogueManager.dialogue_ended.connect(_on_dialogue_ended_for_object_dialogue, CONNECT_ONE_SHOT); DialogueManager.show_dialogue_balloon(player_examine_lines, interactable_node.object_id)
		else: print_rich("[color=red]GM: DialogueManager missing, cannot show examine lines.[/color]"); _complete_interaction_cycle()
		return

	if verb_to_use_id == "talk_to":
		if interactable_node.category == Interactable.ObjectCategory.CHARACTER:
			if not interactable_node.character_conversation_overlay_scene: print_rich("[color=red]GM: Character '%s' no overlay scene![/color]" % interactable_node.object_display_name); _complete_interaction_cycle(); return
			_current_character_conversation_overlay_instance = interactable_node.character_conversation_overlay_scene.instantiate()
			get_tree().root.add_child(_current_character_conversation_overlay_instance)
			if not _current_character_conversation_overlay_instance.conversation_finished.is_connected(_on_character_conversation_finished):
				_current_character_conversation_overlay_instance.conversation_finished.connect(_on_character_conversation_finished)
		else: # Object
			if not player_talk_to_lines: print_rich("[color=red]GM: player_talk_to_lines DialogueResource not set![/color]"); _complete_interaction_cycle(); return
			if DialogueManager: DialogueManager.dialogue_ended.connect(_on_dialogue_ended_for_object_dialogue, CONNECT_ONE_SHOT); DialogueManager.show_dialogue_balloon(player_talk_to_lines, interactable_node.object_id)
			else: print_rich("[color=red]GM: DialogueManager missing, cannot show talk_to lines for object.[/color]"); _complete_interaction_cycle()
		return

	# For all other verbs (including IMPLICIT_USE_ITEM_VERB_ID)
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

	interactable_node.attempt_interaction(verb_to_use_id, item_id_for_interaction)


# --- DialogueManager Signal Handlers (Global) ---
func _on_dialogue_started(_resource: Resource):
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)

func _on_dialogue_ended_for_object_dialogue(_resource: Resource):
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)
	_complete_interaction_cycle()

func _on_character_conversation_finished(_resource: DialogueResource):
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
	else:
		if _signals_connected_to_interactable != null: # It was set but now invalid
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
	var item_data = get_item_data_by_id(item_id_to_add) # This will use the debugged get_item_data_by_id
	if not item_data:
		# get_item_data_by_id already prints a detailed error if not found in map
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
		print_rich("[color=red]GM: remove_item_from_inventory - FAILED. ItemData for id '%s' not found in master list. Cannot determine stackability or display name.[/color]" % item_id_to_remove)
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
				update_sentence_line_ui()
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

	# This is a critical point for debugging item issues.
	print_rich("[color=orange]GM: get_item_data_by_id - ItemData for id '%s' NOT FOUND in _item_data_map.[/color]" % item_id_to_find)
	print_rich("  [color=gray]GM: Current _item_data_map keys: %s[/color]" % str(_item_data_map.keys()))
	print_rich("  [color=gray]GM: Make sure '%s' is the exact item_id in your .tres file AND that .tres file is in 'all_item_data_resources' in GameManager Inspector.[/color]" % item_id_to_find)
	return null

func get_player_inventory() -> Array[ItemData]:
	return player_inventory.duplicate()

# --- Game Flag Management ---
func set_game_flag(flag_name: String, value: bool):
	if game_flags.get(flag_name, !value) == value:
		# print_rich("[color=gray]GM: Flag '%s' already set to %s. No change.[/color]" % [flag_name, str(value)])
		return
	game_flags[flag_name] = value
	print_rich("[color=green]GM: Flag set: '%s' = %s[/color]" % [flag_name, str(value)])

func get_game_flag(flag_name: String) -> bool:
	return game_flags.get(flag_name, false)
