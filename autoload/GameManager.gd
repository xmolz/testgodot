# GameManager.gd
extends Node

const MAIN_GAME_SCENE_PATH = "res://main.tscn"
const INSURANCE_FORM_SCENE = preload("res://ui/insurance_form.tscn")
const JOURNAL_OVERLAY_SCENE = preload("res://ui/journal_overlay.tscn")
const MAIN_MENU_SCENE_PATH = "res://ui/main_menu.tscn"
const INTRO_OVERLAY_SCENE_PATH = "res://conversation/AdvancedConversationOverlay.tscn"
const INTRO_BACKGROUND_ANIMATIONS_PATH = "res://conversation/conversation_backgrounds.tres"
const INTRO_INITIAL_ANIMATION_NAME = "float_loop"
const INTRO_DIALOGUE = preload("res://dialogue/intro.dialogue")
const GAME_OVER_SCENE = preload("res://ui/game_over.tscn")
const DIFFICULTY_SELECT_SCENE = preload("res://ui/difficulty_select_screen.tscn")
const CONVERSATION_BALLOON_SCENE = preload("res://conversation/conversationballoon.tscn")

var _insurance_form_instance: CanvasLayer = null
var _journal_overlay_instance: CanvasLayer = null

# --- Cached Scenes ---
var cached_main_menu_scene: PackedScene = null
var cached_intro_overlay_scene: PackedScene = null
var cached_main_game_scene: PackedScene = null
var _intro_overlay_instance: Node = null

# --- Signals ---
signal verb_changed(new_verb_id: String)
signal sentence_line_updated(text: String)
signal interaction_complete # For VerbUI to reset its state
signal available_verbs_changed(available_verb_data_array: Array[VerbData])
signal new_hint_available(is_available: bool)
signal verb_lock_changed(is_active: bool)

# character conversation ended signal
signal character_conversation_ended(dialogue_resource: DialogueResource)

signal selected_inventory_item_changed(selected_item_data: ItemData)

# --- High-Level Game State Management ---
enum GameState {
	BOOTING,
	LOGO_SPLASH,
	MAIN_MENU,
	DIFFICULTY_SELECT,
	INTRO_CONVERSATION,
	IN_GAME_PLAY,
	PAUSED,
	EXPLANATION,
	CUTSCENE,
	GAME_OVER
}

# --- Interaction Context Management ---
enum InteractionState {
	WORLD,
	CONVERSATION,
	ZOOM_VIEW
}
var current_interaction_state: InteractionState = InteractionState.WORLD

var transition_layer: CanvasLayer = null

var current_game_state: GameState = GameState.BOOTING
var main_game_scene_instance: Node = null
var main_menu_scene_instance: CanvasLayer = null
var pause_menu_ui: CanvasLayer = null
var custom_cursor_instance: CanvasLayer = null
var walk_indicator_instance: Node2D = null
var patreon_world_ui: CanvasLayer = null
var is_mouse_held_for_walk: bool = false
var is_transitioning: bool = false
var is_verb_lock_active: bool = false
var _scan_active: bool = false
var _scan_tween: Tween
var _is_game_over_triggering: bool = false
const ICON_SCAN = preload("res://Icons/magnifying-glass.png")
const ICON_CANCEL = preload("res://Icons/cancel.png")

# --- State Variables ---
var current_verb_id: String = ""
var persisting_verb_id: String = ""
var current_selected_item_data: ItemData = null # "In Hand" / "Selected" item
var hovered_interactable: Interactable = null
var hovered_interactables: Array[Interactable] = []
var player_node: CharacterBody2D

var _is_player_walking: bool = false
var _current_character_conversation_overlay_instance: Node = null

var _mouse_held_timer: float = 0.0
var _potential_hold_walk: bool = false
var _signals_connected_to_interactable: Interactable = null

var current_hint_manager: LevelHintManager = null

# --- Verb Management ---
@export var all_verb_data_resources: Array[VerbData] = []
var unlocked_verb_ids: Array[String] = []
var active_scene_verb_ids: Array[String] = []

# --- Inventory Management ---
@export var all_item_data_resources: Array[ItemData] = []

var current_unread_hint: String = ""
var last_read_hint: String = ""

func _ready():
	print("If I Remember Correctly — v%s" % str(ProjectSettings.get_setting("application/config/version", "unset")))
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	var cursor_scene = load("res://ui/custom_cursor.tscn")
	if cursor_scene and not OS.has_feature("mobile"):
		custom_cursor_instance = cursor_scene.instantiate()
		add_child(custom_cursor_instance)

	var indicator_scene = load("res://ui/walk_indicator.tscn")
	if indicator_scene:
		walk_indicator_instance = indicator_scene.instantiate()
		add_child(walk_indicator_instance)
		walk_indicator_instance.set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)

	# Spawn our Global Transition Layer immediately
	var transition_scene = preload("res://ui/TransitionLayer.tscn")
	transition_layer = transition_scene.instantiate()
	add_child(transition_layer)

	# Spawn our Global Pause Menu (lives on GameManager so it works in all states)
	var pause_scene = preload("res://ui/pause_menu_ui.tscn")
	pause_menu_ui = pause_scene.instantiate()
	add_child(pause_menu_ui)
	pause_menu_ui.scan_cancel_requested.connect(_on_scan_cancel_pressed)

	if DialogueManager:
		DialogueManager.dialogue_started.connect(_on_dialogue_started)

	# Initialize Verbs
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.unlocked_by_default and not verb_data_res.verb_id in unlocked_verb_ids:
			unlocked_verb_ids.append(verb_data_res.verb_id)
	active_scene_verb_ids = unlocked_verb_ids.duplicate()
	_emit_available_verbs_changed_update()

	Inventory.setup(all_item_data_resources)
	Events.item_removed.connect(_on_inventory_item_removed)

	patreon_world_ui = PatreonWorldButton.new()
	add_child(patreon_world_ui)

	# --- DIRECT SCENE RUN CHECK ---
	if current_game_state == GameState.BOOTING:
		var potential_player = get_tree().get_first_node_in_group("player")

		if is_instance_valid(potential_player):

			# 1. Manually assign the player node
			player_node = potential_player

			# 2. Assign the main scene instance (assuming player is a child of the main scene)
			main_game_scene_instance = player_node.get_owner()
			if not is_instance_valid(main_game_scene_instance):
				# Fallback if owner is not set correctly
				main_game_scene_instance = get_tree().get_root().get_child(-1)

			# 3. Manually set the state.
			current_game_state = GameState.IN_GAME_PLAY

			# 4. Ensure the player can move
			if player_node.has_method("set_can_move"):
				player_node.set_can_move(true)

			if is_instance_valid(pause_menu_ui):
				pause_menu_ui.menu_panel.show()

			await get_tree().process_frame
			SoundManager.play_ambience("room_tone_air", -5.0)
			SoundManager.play_ambience("room_tone_electric", -15.0)

func _process(delta):
	# --- FIX 1: Cancel verb lock if player tries to move manually with A/D ---
	if is_verb_lock_active and Input.get_axis("ui_left", "ui_right") != 0:
		cancel_current_action(false)

	# --- FIX 2: Mobile Hold-to-Walk overriding interactable clicks ---
	if _potential_hold_walk and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_mouse_held_for_walk and current_interaction_state == InteractionState.WORLD and current_game_state == GameState.IN_GAME_PLAY:
			_mouse_held_timer += delta
			if _mouse_held_timer > 0.25:
				is_mouse_held_for_walk = true

				if is_instance_valid(player_node) and player_node.get("_interactable_after_walk") != null:
					player_node._interactable_after_walk = null
					player_node._verb_for_interaction = ""
					player_node._item_for_interaction = null
	else:
		_mouse_held_timer = 0.0
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_potential_hold_walk = false

	# --- (Original Logic Continues Below) ---
	if current_game_state == GameState.IN_GAME_PLAY and is_instance_valid(current_hint_manager):
		var evaluated_hint = current_hint_manager.evaluate_hint()
		if evaluated_hint != "" and evaluated_hint != current_unread_hint and evaluated_hint != last_read_hint:
			current_unread_hint = evaluated_hint
			if Settings.assisted_mode:
				new_hint_available.emit(true)

	if is_mouse_held_for_walk:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_mouse_held_for_walk = false
			if is_instance_valid(walk_indicator_instance):
				walk_indicator_instance.hide()

			# Restore the cursor hover state if we stopped walking while currently over an object
			if is_instance_valid(custom_cursor_instance):
				custom_cursor_instance.set_hover_state(hovered_interactable != null)

			# Restore UI text instantly upon release
			update_sentence_line_ui()
		else:
			if current_game_state == GameState.IN_GAME_PLAY and is_instance_valid(player_node):
				var mouse_world_pos = player_node.get_global_mouse_position()

				# Mirror the Hysteresis logic from player.gd
				var is_player_manually_walking = player_node.get("_is_manual_walking")
				var active_deadzone = 20.0 if is_player_manually_walking else 150.0

				if abs(player_node.global_position.x - mouse_world_pos.x) > active_deadzone:
					if is_instance_valid(walk_indicator_instance):
						walk_indicator_instance.global_position = mouse_world_pos
						walk_indicator_instance.show()
				else:
					if is_instance_valid(walk_indicator_instance):
						walk_indicator_instance.hide()

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.is_pressed():

		# --- RIGHT CLICK: Cancel Current Action ---
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if current_verb_id != "" or current_selected_item_data != null:
				cancel_current_action()
				get_viewport().set_input_as_handled()
			return

		# --- LEFT CLICK: Walk to Point / Hold to Walk ---
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_game_state != GameState.IN_GAME_PLAY or current_interaction_state != InteractionState.WORLD:
				return
			if is_transitioning:
				return

			# --- FIX: Register that the click landed in the Game World! ---
			_potential_hold_walk = true

			var mouse_world_pos = player_node.get_global_mouse_position()

			# To fix touch/mouse sync issues, we cast a point exactly where the player clicked
			# to see if an Interactable is underneath. This completely bypasses the hover delay.
			var clicked_interactable = false
			if is_instance_valid(player_node):
				var space_state = player_node.get_world_2d().direct_space_state
				var query = PhysicsPointQueryParameters2D.new()
				query.position = mouse_world_pos
				query.collide_with_areas = true
				query.collide_with_bodies = false
				var intersections = space_state.intersect_point(query)
				for hit in intersections:
					if hit.collider is Interactable:
						clicked_interactable = true
						break

			if clicked_interactable:
				# We clicked an object! DO NOT cancel the verb. DO NOT walk immediately.
				# Just return, and let the Area2D's _input_event catch this click and process it.
				# (If the finger stays down, _potential_hold_walk will upgrade it to continuous movement!)
				return

			# We clicked empty space / the floor.
			# Cancel the verb and drop the item (if any).
			if current_verb_id != "" or current_selected_item_data != null:
				cancel_current_action()

			# Start walking to that point
			if is_instance_valid(player_node) and player_node.has_method("walk_to_point"):
				if _scan_active: _cancel_scan()
				_is_player_walking = true
				is_mouse_held_for_walk = true
				player_node.walk_to_point(mouse_world_pos)
				get_viewport().set_input_as_handled()
				
				
func change_game_state(new_state: GameState):
	if new_state == current_game_state:
		return

	# Wait for the end of the current frame so UI interactions clear
	await get_tree().process_frame

	# =========================================================
	# 1. LEAVING THE OLD STATE (Cleanup)
	# =========================================================
	match current_game_state:
		GameState.MAIN_MENU:
			_cleanup_all_overlays()
			if is_instance_valid(main_menu_scene_instance):
				main_menu_scene_instance.queue_free()
				main_menu_scene_instance = null
		GameState.INTRO_CONVERSATION:
			if new_state == GameState.MAIN_MENU:
				# Destroy the intro overlay if we are aborting to the main menu
				if is_instance_valid(_intro_overlay_instance):
					_intro_overlay_instance.queue_free()
					_intro_overlay_instance = null
		GameState.IN_GAME_PLAY, GameState.PAUSED:
			# When LEAVING the game (e.g. to Menu), stop music and ambience.
			if new_state != GameState.CUTSCENE and new_state != GameState.EXPLANATION and new_state != GameState.PAUSED and new_state != GameState.IN_GAME_PLAY and new_state != GameState.INTRO_CONVERSATION:
				SoundManager.stop_music()
				SoundManager.stop_all_ambience()

			if new_state == GameState.MAIN_MENU:
				_cleanup_all_overlays()
				if is_instance_valid(main_game_scene_instance):
					main_game_scene_instance.queue_free()
					main_game_scene_instance = null

	current_game_state = new_state
	Events.game_state_changed.emit(current_game_state)

	# =========================================================
	# 2. ENTERING THE NEW STATE (Setup)
	# =========================================================
	match current_game_state:
		GameState.MAIN_MENU:
			_is_game_over_triggering = false
			if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()
			if is_instance_valid(main_menu_scene_instance):
				return

			var menu_packed_scene = cached_main_menu_scene
			if not menu_packed_scene:
				# Fallback if testing the scene directly without the Boot loader
				menu_packed_scene = load(MAIN_MENU_SCENE_PATH)
				if not menu_packed_scene:
					return

			main_menu_scene_instance = menu_packed_scene.instantiate()
			main_menu_scene_instance.new_game_requested.connect(_on_main_menu_new_game_requested)
			main_menu_scene_instance.quit_game_requested.connect(_on_main_menu_quit_requested)

			get_tree().root.add_child(main_menu_scene_instance)

		GameState.DIFFICULTY_SELECT:
			var difficulty_screen = DIFFICULTY_SELECT_SCENE.instantiate()
			difficulty_screen.difficulty_chosen.connect(_on_difficulty_chosen)
			get_tree().root.add_child(difficulty_screen)

		GameState.EXPLANATION:
			pass

		GameState.INTRO_CONVERSATION:
			if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()

			if not is_instance_valid(_intro_overlay_instance):
				_start_intro_conversation()

		GameState.IN_GAME_PLAY:
			# --- A. LOADING PHASE ---
			# Only load the scene if it doesn't exist (e.g. fresh boot)
			if not is_instance_valid(main_game_scene_instance):
				var main_packed_scene = cached_main_game_scene
				if not main_packed_scene:
					# Fallback: cache is null (preload failed/skipped, or scene run directly)
					main_packed_scene = load(MAIN_GAME_SCENE_PATH)
					if not main_packed_scene:
						print_rich("[color=red]GameManager Error: Failed to load Main Game Scene.[/color]")
						return

				main_game_scene_instance = main_packed_scene.instantiate()
				get_tree().root.add_child(main_game_scene_instance)
				
				# Play music if we just loaded the game
				# SoundManager.play_music() 
				
				# --- START AMBIENCE FOR MAIN GAME ---
				SoundManager.play_ambience("room_tone_air", -5.0) 
				SoundManager.play_ambience("room_tone_electric", -15.0)

			# --- B. RESTORATION PHASE (Run this EVERY time we enter IN_GAME_PLAY) ---
			
			# 2. Find Player if missing
			if not is_instance_valid(player_node):
				player_node = get_tree().get_first_node_in_group("player")

			# 3. Restore global UI. The scene HUD + input blocker restore
			# themselves in game_ui.gd via Events.game_state_changed.
			if current_interaction_state == InteractionState.WORLD:
				_set_patreon_visible(true)
				if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.show()
			else:
				_set_patreon_visible(false)
				if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()

			# 6. Unlock Player Movement
			if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
				player_node.set_can_move(true)

			# Force the sentence line to refresh in case we had a verb or item selected before pausing
			update_sentence_line_ui()

		GameState.PAUSED:
			update_sentence_line_ui()

		GameState.BOOTING:
			pass
			
		GameState.CUTSCENE:
			# 1. Hide the global UI (scene HUD + blocker handled by game_ui.gd)
			_set_patreon_visible(false)
			if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()
			
			# 3. Stop the Player from moving
			if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
				player_node.set_can_move(false)
				

func select_verb(verb_id_to_select: String):
	# If the player manually selects or toggles a verb, clear any forced sticky state
	persisting_verb_id = ""

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
			new_verb_id = previously_selected_verb_id

	if current_verb_id != new_verb_id:
		current_verb_id = new_verb_id
		verb_changed.emit(current_verb_id)

		# --- Think Verb Interception ---
		if current_verb_id == "think":
			current_verb_id = ""
			verb_changed.emit("")

			if is_instance_valid(current_hint_manager):
				var hint_res = current_hint_manager.hints_dialogue if Settings.assisted_mode else current_hint_manager.hints_adventure_dialogue
				if is_instance_valid(hint_res):
					last_read_hint = current_hint_manager.evaluate_hint()
					new_hint_available.emit(false)

					if not DialogueManager.dialogue_ended.is_connected(restore_world_after_object_dialogue):
						DialogueManager.dialogue_ended.connect(restore_world_after_object_dialogue, CONNECT_ONE_SHOT)

					DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, hint_res, last_read_hint)
			return
		# ------------------------------------------

		# --- QOL FIX: Empty Inventory Give Check ---
		if current_verb_id == "give" and Inventory.is_empty():
			current_verb_id = ""
			verb_changed.emit("")

			if not DialogueManager.dialogue_ended.is_connected(restore_world_after_object_dialogue):
				DialogueManager.dialogue_ended.connect(restore_world_after_object_dialogue, CONNECT_ONE_SHOT)

			var generic_lines = preload("res://dialogue/generic_lines.dialogue")
			DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, generic_lines, "give_empty_inventory")
			return
		# -------------------------------------------

		# If we select a verb that DOES NOT use items, or if we toggle the verb OFF, drop the in-hand item
		if (current_verb_id == "" or (current_verb_id != "use" and current_verb_id != "give")) and current_selected_item_data != null:
			current_selected_item_data = null
			selected_inventory_item_changed.emit(null)

		var verb_data = get_verb_data_by_id(current_verb_id)
		if verb_data and verb_data.requires_target_object and current_verb_id != "walk_to" and current_verb_id != "think":
			_activate_verb_lock(true)
		else:
			_activate_verb_lock(false)

	update_sentence_line_ui()

func select_inventory_item(item_data_to_select: ItemData):
	var previous_verb_id_was_item_compatible = (current_verb_id == "use" or current_verb_id == "give")

	if not item_data_to_select:
		if current_selected_item_data != null:
			current_selected_item_data = null
			selected_inventory_item_changed.emit(null)
		update_sentence_line_ui()
		return

	if current_selected_item_data == item_data_to_select:
		current_selected_item_data = null
		selected_inventory_item_changed.emit(null)
	else:
		current_selected_item_data = item_data_to_select
		selected_inventory_item_changed.emit(current_selected_item_data)

		# If we select an item, but the current verb isn't item-compatible, drop the verb.
		if current_verb_id != "" and not previous_verb_id_was_item_compatible:
			current_verb_id = ""
			verb_changed.emit("")

		# If no verb is selected, default to "use" when picking up an item
		if current_verb_id == "":
			current_verb_id = "use"
			verb_changed.emit("use")

		# --- FIX: Turn on the Verb Lock so the thought bubble and highlights appear! ---
		_activate_verb_lock(true)

	update_sentence_line_ui()

func cancel_current_action(play_sound: bool = true):
	var did_cancel = false

	# If the player right-clicks to cancel, drop the sticky state
	persisting_verb_id = ""

	if current_verb_id != "":
		current_verb_id = ""
		verb_changed.emit("")
		did_cancel = true

	if current_selected_item_data != null:
		current_selected_item_data = null
		selected_inventory_item_changed.emit(null)
		did_cancel = true

	if did_cancel:
		_activate_verb_lock(false)
		update_sentence_line_ui()
		# Play a slightly lower pitched click sound to indicate cancellation
		if play_sound and SoundManager: SoundManager.play_sfx("ui_click")

# --- UI and Interaction Flow ---
func set_hovered_object(interactable: Interactable):
	if not hovered_interactables.has(interactable):
		hovered_interactables.append(interactable)
	_update_top_hovered_object()

func clear_hovered_object(interactable: Interactable = null):
	if interactable and hovered_interactables.has(interactable):
		hovered_interactables.erase(interactable)
	elif interactable == null:
		hovered_interactables.clear()
	_update_top_hovered_object()

func refresh_hovered_object():
	_update_top_hovered_object()

func _update_top_hovered_object():
	# Clean out invalid instances just in case an object was destroyed while hovered
	for i in range(hovered_interactables.size() - 1, -1, -1):
		if not is_instance_valid(hovered_interactables[i]):
			hovered_interactables.remove_at(i)

	# --- TRANSITION OVERRIDE ---
	if hovered_interactables.is_empty() or is_transitioning:
		hovered_interactable = null
		if is_instance_valid(custom_cursor_instance):
			custom_cursor_instance.set_hover_state(false)
		update_sentence_line_ui()
		return

	# Find the top-most interactable
	var top_interactable = hovered_interactables[0]
	for i in range(1, hovered_interactables.size()):
		var candidate = hovered_interactables[i]

		# Safely get effective Z-index (checking parent if needed)
		var top_z = top_interactable.z_index
		if top_z == 0 and top_interactable.get_parent() is Node2D:
			top_z = top_interactable.get_parent().z_index

		var cand_z = candidate.z_index
		if cand_z == 0 and candidate.get_parent() is Node2D:
			cand_z = candidate.get_parent().z_index

		if cand_z > top_z:
			top_interactable = candidate
		elif cand_z == top_z:
			# If Z-index is tied, lower on the screen (higher Y) is in front
			if candidate.global_position.y > top_interactable.global_position.y:
				top_interactable = candidate

	hovered_interactable = top_interactable

	update_sentence_line_ui()

	# --- QOL FIX: Cursor state for incomplete Give ---
	var should_hover_cursor = true
	if current_verb_id == "give" and current_selected_item_data == null:
		should_hover_cursor = false

	if is_instance_valid(custom_cursor_instance) and not is_mouse_held_for_walk:
		custom_cursor_instance.set_hover_state(should_hover_cursor)

func update_sentence_line_ui():
	if is_mouse_held_for_walk or _is_player_walking or current_game_state == GameState.PAUSED or is_transitioning:
		sentence_line_updated.emit("")
		if is_instance_valid(player_node): player_node.hide_thought_bubble()
		return

	var line_text = ""
	var bubble_text = ""

	if current_verb_id != "":
		var verb_data = get_verb_data_by_id(current_verb_id)
		var verb_text = verb_data.display_text if verb_data else current_verb_id

		if current_selected_item_data != null:
			var item_colored = "[color=#33d9ff]%s[/color]" % current_selected_item_data.display_name
			line_text = "%s %s" % [verb_text, item_colored]
			bubble_text = "%s %s on what?" % [verb_text, item_colored]

			if hovered_interactable:
				var preposition = " to " if current_verb_id == "give" else " on "
				var obj_colored = "[color=#33d9ff]%s[/color]" % hovered_interactable.object_display_name
				line_text += preposition + obj_colored
			else:
				var preposition = " to..." if current_verb_id == "give" else " on..."
				line_text += preposition
		else:
			if current_verb_id == "give":
				if hovered_interactable:
					var obj_colored = "[color=#33d9ff]%s[/color]" % hovered_interactable.object_display_name
					line_text = "Give what to %s?" % obj_colored
				else:
					line_text = "Give what? (Select an item)"
				bubble_text = "Give what? (Select an item)"
			else:
				line_text = verb_text
				bubble_text = verb_text + " what?"
				if hovered_interactable:
					var obj_colored = "[color=#33d9ff]%s[/color]" % hovered_interactable.object_display_name
					line_text += " " + obj_colored

	elif hovered_interactable and hovered_interactable.interaction_location == Interactable.InteractionLocation.WORLD:
		var obj_colored = "[color=#33d9ff]%s[/color]" % hovered_interactable.object_display_name
		line_text = "Walk to " + obj_colored

	sentence_line_updated.emit(line_text)

	if is_verb_lock_active and is_instance_valid(player_node) and bubble_text != "" and OS.has_feature("mobile"):
		player_node.show_thought_bubble(bubble_text)
	elif is_instance_valid(player_node):
		player_node.hide_thought_bubble()

func process_interaction_click(interactable_node: Interactable):
	if is_transitioning: return
	if not is_instance_valid(interactable_node): return

	if current_verb_id != "" and current_selected_item_data != null:
		_initiate_interaction_flow(interactable_node, current_verb_id, current_selected_item_data)
	elif current_verb_id != "":
		_initiate_interaction_flow(interactable_node, current_verb_id, null)
	else:
		if interactable_node.interaction_location == Interactable.InteractionLocation.WORLD:
			_initiate_interaction_flow(interactable_node, "walk_to", null)

func _initiate_interaction_flow(interactable_node: Interactable, verb_to_use_id: String, item_data_to_use: ItemData):
	if not is_instance_valid(interactable_node):
		_complete_interaction_cycle(); return

	# --- QOL FIX: Prevent "Give" without an item ---
	if verb_to_use_id == "give" and item_data_to_use == null:
		cancel_current_action(false)

		if not DialogueManager.dialogue_ended.is_connected(restore_world_after_object_dialogue):
			DialogueManager.dialogue_ended.connect(restore_world_after_object_dialogue, CONNECT_ONE_SHOT)

		var generic_lines = preload("res://dialogue/generic_lines.dialogue")
		DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, generic_lines, "give_no_item_selected")
		return
	# -----------------------------------------------

	if interactable_node.has_method("notify_interaction_pending"):
		interactable_node.notify_interaction_pending()

	if is_verb_lock_active:
		_activate_verb_lock(false)

	var walk_needed = true

	if interactable_node.interaction_location == Interactable.InteractionLocation.UI_OVERLAY:
		walk_needed = false
	else:
		if interactable_node.has_method("does_verb_require_walk"):
			walk_needed = interactable_node.does_verb_require_walk(verb_to_use_id, item_data_to_use)
		else:
			walk_needed = true

	var item_name_for_log = "None"
	if item_data_to_use: item_name_for_log = item_data_to_use.display_name

	if walk_needed:
		_is_player_walking = true

		# Force the UI to instantly suppress the action label upon clicking
		update_sentence_line_ui()

		if not is_instance_valid(player_node):
			_perform_actual_interaction(interactable_node, verb_to_use_id, item_data_to_use)
			return
		if player_node.has_method("walk_to_and_interact"):
			var walk_target_pos = interactable_node.get_walk_to_position()
			player_node.walk_to_and_interact(walk_target_pos, interactable_node, verb_to_use_id, item_data_to_use)
		else:
			_perform_actual_interaction(interactable_node, verb_to_use_id, item_data_to_use)
	else:
		if is_instance_valid(player_node) and player_node.has_method("face_target"):
			if interactable_node.interaction_location == Interactable.InteractionLocation.WORLD:
				player_node.face_target(interactable_node.global_position)
		_perform_actual_interaction(interactable_node, verb_to_use_id, item_data_to_use)

func player_has_finished_walk_command():
	_is_player_walking = false
	update_sentence_line_ui()

func player_reached_interaction_target(interactable_node: Interactable, verb_to_use_id: String, item_data_to_use: ItemData):
	if not is_instance_valid(interactable_node):
		_complete_interaction_cycle(); return
	_perform_actual_interaction(interactable_node, verb_to_use_id, item_data_to_use)

func _perform_actual_interaction(interactable_node: Interactable, verb_to_use_id: String, item_in_hand_data: ItemData = null):
	if not is_instance_valid(interactable_node):
		_complete_interaction_cycle(); return

	var item_name_for_log = "None"
	var item_id_for_interaction = ""
	if item_in_hand_data:
		item_name_for_log = item_in_hand_data.display_name
		item_id_for_interaction = item_in_hand_data.item_id

	# --- RECORD ACTION IN HISTORY LOG ---
	var verb_data = get_verb_data_by_id(verb_to_use_id)
	var verb_name = verb_data.display_text if verb_data else verb_to_use_id
	var obj_name = interactable_node.object_display_name
	var itm_name = item_in_hand_data.display_name if item_in_hand_data else ""
	DialogueHistory.add_action(verb_name, obj_name, itm_name)
	# ------------------------------------

	_disconnect_interactable_request_signals()

	_signals_connected_to_interactable = interactable_node

	if not interactable_node.interaction_processed.is_connected(_on_interactable_action_finished):
		interactable_node.interaction_processed.connect(_on_interactable_action_finished)

	interactable_node.attempt_interaction(verb_to_use_id, item_id_for_interaction)

# --- DialogueManager Signal Handlers (Global) ---
func _on_dialogue_started(_resource: Resource):
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)

	# The HUD itself is hidden by game_ui.gd. We only hide the Patreon button here.
	_set_patreon_visible(false)

func restore_world_after_object_dialogue(_resource: Resource):
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		if current_interaction_state == InteractionState.WORLD and current_game_state == GameState.IN_GAME_PLAY:
			player_node.set_can_move(true)

	# Restore the global UI. The scene HUD is handled by game_ui.gd.
	if current_interaction_state != InteractionState.CONVERSATION and current_game_state == GameState.IN_GAME_PLAY:
		_set_patreon_visible(true)

	_complete_interaction_cycle()

func register_character_conversation(overlay: Node):
	_current_character_conversation_overlay_instance = overlay
	if overlay.has_signal("conversation_finished") and not overlay.conversation_finished.is_connected(_on_character_conversation_finished):
		overlay.conversation_finished.connect(_on_character_conversation_finished, CONNECT_ONE_SHOT)

func _on_character_conversation_finished(resource: DialogueResource):
	exit_to_world_state()

	# Do NOT queue_free the overlay here — it cleans itself up
	# via _destroy_and_clear_cache / _cleanup_and_queue_free.
	# Calling queue_free here races with the overlay's own cleanup
	# and prevents texture references from being properly nulled,
	# causing large textures to linger in VRAM until GC collects them.
	_current_character_conversation_overlay_instance = null

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	_complete_interaction_cycle()

	character_conversation_ended.emit(resource)

# --- Interactable Signal Handlers ---
func _on_interactable_action_finished():
	_complete_interaction_cycle()

func _on_inventory_item_removed(item_id: String):
	if current_selected_item_data and current_selected_item_data.item_id == item_id:
		current_selected_item_data = null
		selected_inventory_item_changed.emit(null)

func _disconnect_interactable_request_signals():
	if is_instance_valid(_signals_connected_to_interactable):
		var node_to_disconnect_from = _signals_connected_to_interactable

		if node_to_disconnect_from.interaction_processed.is_connected(_on_interactable_action_finished):
			node_to_disconnect_from.interaction_processed.disconnect(_on_interactable_action_finished)
	_signals_connected_to_interactable = null

func _complete_interaction_cycle():
	_disconnect_interactable_request_signals()
	interaction_complete.emit()
	_activate_verb_lock(false)

	# --- STICKY VERB FIX ---
	if persisting_verb_id != "":
		current_verb_id = persisting_verb_id
		verb_changed.emit(current_verb_id)
	else:
		if current_verb_id != "":
			current_verb_id = ""
			verb_changed.emit("")
		else:
			current_verb_id = ""
	# -----------------------

	if current_selected_item_data:
		current_selected_item_data = null
		selected_inventory_item_changed.emit(null)

	# --- FIX START: Restore Player Control and UI ---
	# Since we removed the unfreeze logic from the individual Dialogue actions,
	# we must ensure the player is un-frozen here, at the absolute end of the chain.
	
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		# Only unfreeze if we are in the normal gameplay state (not a full cutscene/zoom)
		if current_interaction_state == InteractionState.WORLD and current_game_state == GameState.IN_GAME_PLAY:
			player_node.set_can_move(true)

	# Restore UI visibility
	if current_interaction_state != InteractionState.CONVERSATION and current_game_state == GameState.IN_GAME_PLAY:
		_set_patreon_visible(true)

	update_sentence_line_ui()

# The patreon button is global (child of GameManager) so it can't be managed by
# the level's game_ui.gd. It follows the same show/hide rhythm the gameplay HUD
# always had, gated by the dev_cta_completed level flag.
func _set_patreon_visible(show: bool):
	if is_instance_valid(patreon_world_ui):
		patreon_world_ui.visible = Flags.get_level_flag("dev_cta_completed") if show else false

func _activate_verb_lock(active: bool):
	is_verb_lock_active = active
	verb_lock_changed.emit(active)
	if active:
		if _scan_tween: _scan_tween.kill()
		_scan_active = false
		if is_instance_valid(player_node):
			player_node.set_can_move(false)
		if OS.has_feature("mobile"):
			for interactable in get_tree().get_nodes_in_group("interactables"):
				if is_instance_valid(interactable): interactable.force_highlight(true)
		if is_instance_valid(pause_menu_ui):
			pause_menu_ui.set_cancel_mode(true)
	else:
		if is_instance_valid(player_node):
			player_node.hide_thought_bubble()
			player_node.set_can_move(true)
		if OS.has_feature("mobile"):
			for interactable in get_tree().get_nodes_in_group("interactables"):
				if is_instance_valid(interactable): interactable.force_highlight(false)
		if is_instance_valid(pause_menu_ui):
			pause_menu_ui.set_cancel_mode(false)
			pause_menu_ui.set_scan_highlight(false)

func _on_scan_cancel_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	if is_verb_lock_active:
		cancel_current_action(false)
	else:
		if _scan_active:
			_cancel_scan()
		else:
			_scan_active = true
			if is_instance_valid(pause_menu_ui):
				pause_menu_ui.set_scan_highlight(true)

			for interactable in get_tree().get_nodes_in_group("interactables"):
				if is_instance_valid(interactable): interactable.force_highlight(true)

			if _scan_tween: _scan_tween.kill()
			_scan_tween = create_tween()
			_scan_tween.tween_interval(2.0)
			_scan_tween.tween_callback(_cancel_scan)

func is_scan_active() -> bool:
	return _scan_active

func _cancel_scan():
	_scan_active = false
	if _scan_tween: _scan_tween.kill()
	if is_instance_valid(pause_menu_ui):
		pause_menu_ui.set_scan_highlight(false)

	if not (is_verb_lock_active and OS.has_feature("mobile")):
		for interactable in get_tree().get_nodes_in_group("interactables"):
			if is_instance_valid(interactable): interactable.force_highlight(false)

# --- Verb Data and Availability ---

func get_verb_data_by_id(verb_id_to_find: String) -> VerbData:
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.verb_id == verb_id_to_find:
			return verb_data_res
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

		if not active_scene_verb_ids.is_empty() and not verb_id_to_unlock in active_scene_verb_ids:
			active_scene_verb_ids.append(verb_id_to_unlock)

		_emit_available_verbs_changed_update()
	elif not verb_data: print_rich("[color=red]GM: Tried to unlock non-existent verb: '%s'[/color]" % verb_id_to_unlock)
	elif verb_id_to_unlock in unlocked_verb_ids: print_rich("[color=yellow]GM: Verb '%s' already unlocked.[/color]" % verb_id_to_unlock)

func lock_verb(verb_id_to_lock: String):
	if verb_id_to_lock in unlocked_verb_ids:
		unlocked_verb_ids.erase(verb_id_to_lock)

		if verb_id_to_lock in active_scene_verb_ids:
			active_scene_verb_ids.erase(verb_id_to_lock)

		_emit_available_verbs_changed_update()
		if current_verb_id == verb_id_to_lock:
			select_verb("")
	else: print_rich("[color=orange]GM: Tried to lock verb '%s' that was not unlocked or doesn't exist.[/color]" % verb_id_to_lock)

func is_verb_id_currently_active(verb_id_to_check: String) -> bool:
	if not verb_id_to_check in unlocked_verb_ids: return false
	if active_scene_verb_ids.is_empty(): return true
	return active_scene_verb_ids.has(verb_id_to_check)

func force_clear_all_hovered_interactables():
	var interactables_to_clear = hovered_interactables.duplicate()
	hovered_interactables.clear()

	for interactable in interactables_to_clear:
		if is_instance_valid(interactable):
			interactable._on_mouse_exited()

	hovered_interactable = null
	if is_instance_valid(custom_cursor_instance):
		custom_cursor_instance.set_hover_state(false)
	update_sentence_line_ui()

func enter_conversation_state():
	if current_interaction_state == InteractionState.CONVERSATION: return
	current_interaction_state = InteractionState.CONVERSATION

	force_clear_all_hovered_interactables()

	# Scene HUD + input blocker are handled by game_ui.gd via the signal below.
	_set_patreon_visible(false)
	if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()
	Events.interaction_state_changed.emit(current_interaction_state)

func enter_zoom_view_state():
	if current_interaction_state == InteractionState.ZOOM_VIEW: return
	current_interaction_state = InteractionState.ZOOM_VIEW

	force_clear_all_hovered_interactables()

	# Layer juggling for verb/inventory + input blocker live in game_ui.gd now.
	_set_patreon_visible(false)

	if is_instance_valid(player_node):
		player_node.set_can_move(false)

	get_tree().paused = true
	Events.interaction_state_changed.emit(current_interaction_state)

func exit_to_world_state():
	current_interaction_state = InteractionState.WORLD

	# Scene HUD restore + layer reset + blocker are handled by game_ui.gd.
	_set_patreon_visible(true)
	if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.show()

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	get_tree().paused = false
	Events.interaction_state_changed.emit(current_interaction_state)

# This function is called ONLY when the "Close Form" button is pressed.
func _on_insurance_form_closed():

	# Clean up our reference to the form instance. This is important.
	_insurance_form_instance = null

	# Return control to the player and un-pause the game.
	exit_to_world_state()

func start_explanation(data: ExplanationData, root_node_to_search: Node):
	if current_game_state == GameState.EXPLANATION or not is_instance_valid(main_game_scene_instance):
		return

	change_game_state(GameState.EXPLANATION)

	# game_ui.gd hides the HUD (honoring data.exceptions_to_hide) and starts
	# the ExplanationLayer in response to this event.
	if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)

	get_tree().paused = true
	Events.explanation_started.emit(data, root_node_to_search)

func exit_explanation_state():
	if current_game_state != GameState.EXPLANATION:
		return

	get_tree().paused = false

	# Show the main game UI
	_set_patreon_visible(true)
	if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.show()

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	change_game_state(GameState.IN_GAME_PLAY)

func open_insurance_form():
	if is_instance_valid(_insurance_form_instance):
		return

	_insurance_form_instance = INSURANCE_FORM_SCENE.instantiate()

	_insurance_form_instance.form_closed.connect(_on_insurance_form_closed)

	get_tree().root.add_child(_insurance_form_instance)
	_insurance_form_instance.show()
	
	enter_conversation_state()
	get_tree().paused = true

# =========================================================
# RUN-STATE RESET
# Called once per New Game (from _on_main_menu_new_game_requested)
# so a second playthrough in the same session starts clean.
# Intentionally does NOT touch user preferences (text_speed,
# instant_text, dialogue_text_scale, is_auto_playing), the
# cached_* PackedScenes, or is_transitioning (TransitionLayer owns it).
# =========================================================
func reset_run_state():
	# --- Interaction / input transients ---
	_disconnect_interactable_request_signals()
	hovered_interactables.clear()
	hovered_interactable = null
	is_mouse_held_for_walk = false
	_potential_hold_walk = false
	_mouse_held_timer = 0.0
	_is_player_walking = false
	_scan_active = false
	if _scan_tween: _scan_tween.kill()
	current_interaction_state = InteractionState.WORLD
	_is_game_over_triggering = false
	_activate_verb_lock(false)

	# --- Verb & item selection ---
	persisting_verb_id = ""
	if current_verb_id != "":
		current_verb_id = ""
		verb_changed.emit("")
	if current_selected_item_data != null:
		current_selected_item_data = null
		selected_inventory_item_changed.emit(null)

	# --- Inventory ---
	Inventory.reset()

	# --- Global flags & dialogue memory ---
	Flags.reset_run_state()
	DialogueHistory.reset()

	# --- Hints & difficulty (difficulty select re-establishes these) ---
	Settings.assisted_mode = false
	current_unread_hint = ""
	last_read_hint = ""
	new_hint_available.emit(false)

	# --- Verbs: re-derive defaults exactly like _ready() does ---
	unlocked_verb_ids.clear()
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.unlocked_by_default and not verb_data_res.verb_id in unlocked_verb_ids:
			unlocked_verb_ids.append(verb_data_res.verb_id)
	active_scene_verb_ids = unlocked_verb_ids.duplicate()
	_emit_available_verbs_changed_update()

	# --- Sibling autoload run-state (Sergey conversation memory etc.) ---
	if ConversationEventManager and ConversationEventManager.has_method("reset_run_state"):
		ConversationEventManager.reset_run_state()

	# --- Stale references (their owning scenes were freed on quit) ---
	current_hint_manager = null
	_insurance_form_instance = null
	_journal_overlay_instance = null
	_current_character_conversation_overlay_instance = null

func _on_main_menu_new_game_requested():
	if is_instance_valid(transition_layer) and transition_layer.has_method("global_fade_to_black"):
		await transition_layer.global_fade_to_black(0.5)

	reset_run_state()

	change_game_state(GameState.DIFFICULTY_SELECT)

	if is_instance_valid(transition_layer) and transition_layer.has_method("global_fade_from_black"):
		transition_layer.global_fade_from_black(0.5)

func _on_difficulty_chosen(is_assisted: bool):
	Settings.assisted_mode = is_assisted
	Settings.save_settings()
	print_rich("[color=green]GM: Difficulty selected. Assisted Mode = %s[/color]" % str(Settings.assisted_mode))

	unlock_verb("think")

	if is_instance_valid(transition_layer):
		await transition_layer.play_iris_close()

	var difficulty_screen = get_tree().root.get_node_or_null("DifficultySelectScreen")
	if is_instance_valid(difficulty_screen):
		difficulty_screen.queue_free()

	change_game_state(GameState.INTRO_CONVERSATION)

	if is_instance_valid(transition_layer):
		await get_tree().create_timer(0.5).timeout
		transition_layer.play_iris_open()

func _on_main_menu_quit_requested():
	get_tree().quit()

func _start_intro_conversation():

	var intro_overlay_packed_scene = cached_intro_overlay_scene
	if not intro_overlay_packed_scene:
		# Fallback to loading from disk if the cache was somehow cleared
		intro_overlay_packed_scene = load(INTRO_OVERLAY_SCENE_PATH)
		if not intro_overlay_packed_scene:
			print_rich("[color=red]GM Error: Failed to load Intro Overlay Scene at path: %s[/color]" % INTRO_OVERLAY_SCENE_PATH)
			return

	var intro_overlay = intro_overlay_packed_scene.instantiate()
	intro_overlay.is_intro_sequence = true

	# Configure its exported variables from code.
	intro_overlay.dialogue_resource = INTRO_DIALOGUE

	# Connect to its 'conversation_finished' signal.
	intro_overlay.conversation_finished.connect(_on_intro_conversation_finished, CONNECT_ONE_SHOT)

	# Add it to the scene tree so it becomes visible and starts running.
	get_tree().root.add_child(intro_overlay)
	_intro_overlay_instance = intro_overlay

func _on_intro_conversation_finished(_dialogue_resource):
	if is_instance_valid(transition_layer):
		await transition_layer.play_iris_close()

	# AWAIT the state change so the scene actually loads before we try to lock things!
	await change_game_state(GameState.IN_GAME_PLAY)
	_intro_overlay_instance = null

	# --- PREVENT MOVEMENT & UI DURING DARKNESS ---
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)
	_set_patreon_visible(false)
	Events.gameplay_ui_visibility_requested.emit(false)

	if is_instance_valid(transition_layer):
		# Wait 3 full seconds in the dark to let the player hear the environment
		await get_tree().create_timer(3.0).timeout

		# Now open the eyes
		await transition_layer.play_iris_open()

	# --- RESTORE MOVEMENT & UI ---
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)
	_set_patreon_visible(true)
	Events.gameplay_ui_visibility_requested.emit(true)

# --- JOURNAL FUNCTIONS ---
func open_journal():
	if is_instance_valid(_journal_overlay_instance):
		return

	_journal_overlay_instance = JOURNAL_OVERLAY_SCENE.instantiate()
	_journal_overlay_instance.journal_closed.connect(_on_journal_closed)

	get_tree().root.add_child(_journal_overlay_instance)

	# Hide the main UI using the conversation state
	enter_conversation_state()
	get_tree().paused = true

func _on_journal_closed():
	if is_instance_valid(_journal_overlay_instance):
		_journal_overlay_instance.queue_free()
		_journal_overlay_instance = null
		
	# Restore UI and unpause
	exit_to_world_state()

func trigger_game_over(fade_duration: float = 1.5):
	if _is_game_over_triggering:
		return
	_is_game_over_triggering = true

	print_rich("[color=red]GM: Game Over Triggered![/color]")

	# Instantly hide the current dialogue balloon so the player knows their click registered!
	if is_instance_valid(_intro_overlay_instance) and "current_balloon" in _intro_overlay_instance and is_instance_valid(_intro_overlay_instance.current_balloon):
		_intro_overlay_instance.current_balloon.hide()

	# 1. Trigger the GLOBAL fade so it isn't destroyed during cleanup
	if is_instance_valid(transition_layer) and transition_layer.has_method("global_fade_to_black"):
		await transition_layer.global_fade_to_black(fade_duration)
	else:
		await get_tree().create_timer(fade_duration).timeout

	# 2. Change state to stop player input
	change_game_state(GameState.GAME_OVER)

	# 3. Stop all audio aggressively
	if SoundManager:
		if SoundManager.has_method("stop_music"): SoundManager.stop_music()
		if SoundManager.has_method("stop_all_ambience"): SoundManager.stop_all_ambience()

	# 4. Clean up the main game scene if it exists
	if is_instance_valid(main_game_scene_instance):
		main_game_scene_instance.queue_free()
		main_game_scene_instance = null

	# 5. Aggressively hunt down Overlays AND Dialogue Balloons to prevent crashes
	_cleanup_all_overlays()

	# 6. Spawn the Game Over Scene
	var game_over_instance = GAME_OVER_SCENE.instantiate()
	get_tree().root.add_child(game_over_instance)

func quit_to_main_menu_smooth():
	if SoundManager:
		SoundManager.stop_all_audio()
	_cleanup_all_overlays()

	if is_instance_valid(transition_layer) and transition_layer.has_method("global_fade_to_black"):
		await transition_layer.global_fade_to_black(1.0)

	current_interaction_state = InteractionState.WORLD

	change_game_state(GameState.MAIN_MENU)

	if is_instance_valid(transition_layer) and transition_layer.has_method("global_fade_from_black"):
		transition_layer.global_fade_from_black(1.0)

func clear_active_dialogue_balloons(node: Node = null):
	if node == null:
		node = get_tree().root

	for child in node.get_children():
		if "Balloon" in child.name or "conversationballoon" in child.name.to_lower():
			child.queue_free()
		else:
			clear_active_dialogue_balloons(child)

func _cleanup_all_overlays(node: Node = null):
	if node == null:
		node = get_tree().root

	for child in node.get_children():
		if child is CharacterConversationOverlay or child is AdvancedConversationOverlay:
			if "current_balloon" in child and is_instance_valid(child.current_balloon):
				child.current_balloon.queue_free()
			child.queue_free()
		elif child is ObjectZoomOverlay:
			child.queue_free()
		elif "MemoryBoxOverlay" in child.name:
			child.queue_free()
		elif "Balloon" in child.name or "conversationballoon" in child.name.to_lower():
			child.queue_free()
		elif "DialogueHistory" in child.name and child != DialogueHistory:
			child.queue_free()
		else:
			_cleanup_all_overlays(child)

func has_unread_hint() -> bool:
	return current_unread_hint != "" and current_unread_hint != last_read_hint

func refresh_hint_system():
	current_unread_hint = ""
	last_read_hint = ""

	if is_instance_valid(current_hint_manager):
		var evaluated_hint = current_hint_manager.evaluate_hint()
		if evaluated_hint != "":
			current_unread_hint = evaluated_hint
			if Settings.assisted_mode:
				new_hint_available.emit(true)
			else:
				new_hint_available.emit(false)
