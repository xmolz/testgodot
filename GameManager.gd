# GameManager.gd
extends Node

const MAIN_GAME_SCENE_PATH = "res://main.tscn"
const INSURANCE_FORM_SCENE = preload("res://insurance_form.tscn")
const JOURNAL_OVERLAY_SCENE = preload("res://journal_overlay.tscn") # <--- ADD THIS 
const MAIN_MENU_SCENE_PATH = "res://main_menu.tscn"
# --- ADD THIS LINE ---
# Make sure this path is correct for your project structure!
# In Boot.gd - CUT THESE LINES
const INTRO_OVERLAY_SCENE_PATH = "res://AdvancedConversationOverlay.tscn"
const INTRO_BACKGROUND_ANIMATIONS_PATH = "res://conversation_backgrounds.tres"
const INTRO_INITIAL_ANIMATION_NAME = "float_loop"
const FORM_DIALOGUE = preload("res://form_related_dialogue.dialogue")
const INTRO_DIALOGUE = preload("res://dialogue/intro.dialogue")
const GAME_OVER_SCENE = preload("res://game_over.tscn")
const DIFFICULTY_SELECT_SCENE = preload("res://difficulty_select_screen.tscn")
const CONVERSATION_BALLOON_SCENE = preload("res://conversationballoon.tscn")

var _insurance_form_instance: CanvasLayer = null # To keep track of the form
var _journal_overlay_instance: CanvasLayer = null # <--- ADD THIS

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
signal item_picked_up(item_name: String)
signal notification_requested(message: String)
signal new_hint_available(is_available: bool)
signal verb_lock_changed(is_active: bool)
signal auto_forward_toggled(is_on: bool)

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
	DIFFICULTY_SELECT,
	INTRO_CONVERSATION,
	IN_GAME_PLAY,
	PAUSED,
	EXPLANATION,
	CUTSCENE, # <--- Add this line
	GAME_OVER
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
var journal_button_ui: CanvasLayer = null # <--- ADD THIS LINE
var inventory_ui: CanvasLayer = null
var insurance_form_button_ui: CanvasLayer = null
var explanation_layer: CanvasLayer = null
var transition_layer: CanvasLayer = null


# --- END of Interaction Context Management ---
# 2. Create a variable to hold the current state.
var current_game_state: GameState = GameState.BOOTING

# 3. Reference to your main game scene instance.
#    The Boot.gd script will set this reference for us later.
var main_game_scene_instance: Node = null
var main_menu_scene_instance: CanvasLayer = null
# --- END of High-Level Game State Management ---
var pause_menu_ui: CanvasLayer = null
var input_blocker_layer: CanvasLayer = null
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
# --- Dialogue History ---
const MAX_HISTORY_LOGS = 100
var dialogue_history: Array[Dictionary] = []

func add_dialogue_history_line(lookup_name: String, display_name: String, text: String):
	dialogue_history.append({
		"type": "line",
		"lookup_name": lookup_name,
		"display_name": display_name,
		"text": text
	})
	if dialogue_history.size() > MAX_HISTORY_LOGS:
		dialogue_history.pop_front()

func add_dialogue_history_choice(lookup_name: String, display_name: String, options: Array[String], selected_index: int):
	dialogue_history.append({
		"type": "choice",
		"lookup_name": lookup_name,
		"display_name": display_name,
		"options": options,
		"selected_index": selected_index
	})
	if dialogue_history.size() > MAX_HISTORY_LOGS:
		dialogue_history.pop_front()

func add_dialogue_history_action(verb_name: String, object_name: String, item_name: String = ""):
	dialogue_history.append({
		"type": "action",
		"verb": verb_name,
		"object": object_name,
		"item": item_name
	})
	if dialogue_history.size() > MAX_HISTORY_LOGS:
		dialogue_history.pop_front()

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
#var debug_fps_label: Label = null
var _signals_connected_to_interactable: Interactable = null # Tracks interactable for signal cleanup

var current_level_state_manager: LevelStateManager = null # For current level's state
var current_hint_manager: LevelHintManager = null



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
var assisted_mode: bool = false
var current_unread_hint: String = ""
var last_read_hint: String = ""
var visited_dialogue_responses: Dictionary = {} # Tracks clicked dialogue options

# --- Global Settings ---
var text_speed: float = 0.02 # Seconds per character (lower is faster)
var instant_text: bool = false
var dialogue_text_scale: float = 1.0

var is_auto_playing: bool = false:
	set(val):
		is_auto_playing = val
		auto_forward_toggled.emit(val)

var auto_time_delay: float = 0.486

func set_bus_volume(bus_name: String, linear_val: float):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))

func get_bus_volume(bus_name: String) -> float:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	return 1.0


# In GameManager.gd

# In GameManager.gd

func _ready():
	#print_rich("[color=cyan]GM: GameManager is Ready! Starting initialization...[/color]")
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Create a debug FPS counter
	#var fps_canvas = CanvasLayer.new()
	#fps_canvas.layer = 128 # Put it above absolutely everything
	#debug_fps_label = Label.new()
	#debug_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 15)
	#debug_fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	#debug_fps_label.offset_right = -20
	#debug_fps_label.offset_top = 20
	#debug_fps_label.add_theme_font_size_override("font_size", 24)
	#debug_fps_label.add_theme_color_override("font_color", Color.GREEN)
	#debug_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	#debug_fps_label.add_theme_constant_override("outline_size", 4)
	#fps_canvas.add_child(debug_fps_label)
	#add_child(fps_canvas)

	var cursor_scene = load("res://custom_cursor.tscn")
	if cursor_scene and not OS.has_feature("mobile"):
		custom_cursor_instance = cursor_scene.instantiate()
		add_child(custom_cursor_instance)

	var indicator_scene = load("res://walk_indicator.tscn")
	if indicator_scene:
		walk_indicator_instance = indicator_scene.instantiate()
		add_child(walk_indicator_instance)
		walk_indicator_instance.set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)

	# Spawn our Global Transition Layer immediately
	var transition_scene = preload("res://TransitionLayer.tscn")
	transition_layer = transition_scene.instantiate()
	add_child(transition_layer)

	# Spawn our Global Pause Menu (lives on GameManager so it works in all states)
	var pause_scene = preload("res://pause_menu_ui.tscn")
	pause_menu_ui = pause_scene.instantiate()
	add_child(pause_menu_ui)

	if DialogueManager:
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
		#print_rich("[color=green]GM: Connected to DialogueManager.dialogue_started.[/color]")
	else:
		pass
		#print_rich("[color=red]GM: DialogueManager (Autoload) not found. Dialogue events won't control player movement.[/color]")

	# Initialize Verbs
	#print_rich("[color=aqua]GM: Initializing verbs...[/color]")
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.unlocked_by_default and not verb_data_res.verb_id in unlocked_verb_ids:
			unlocked_verb_ids.append(verb_data_res.verb_id)
			#print_rich("  [color=gray]GM: Unlocked default verb: %s[/color]" % verb_data_res.verb_id)
	active_scene_verb_ids = unlocked_verb_ids.duplicate()
	_emit_available_verbs_changed_update()
	#print_rich("[color=green]GM: Verbs initialized. %s default verbs unlocked.[/color]" % unlocked_verb_ids.size())

	# Initialize Item Data Map
	#print_rich("[color=aqua]GM: Initializing item data map...[/color]")
	if all_item_data_resources.is_empty():
		pass
		#print_rich("[color=yellow]GM: 'all_item_data_resources' array is empty. No items loaded from Inspector.[/color]")
	else:
		pass
		#print_rich("[color=gray]GM: Found %s item resources in 'all_item_data_resources'.[/color]" % all_item_data_resources.size())

	for item_data_res in all_item_data_resources:
		if item_data_res and item_data_res.item_id != "":
			if not _item_data_map.has(item_data_res.item_id):
				_item_data_map[item_data_res.item_id] = item_data_res
				#print_rich("  [color=gray]GM: Mapped item: ID='%s', Name='%s'[/color]" % [item_data_res.item_id, item_data_res.display_name])
			else:
				pass
				#print_rich("[color=red]GM: Duplicate item_id found in all_item_data_resources: '%s'. Overwriting in map is problematic.[/color]" % item_data_res.item_id)
		elif item_data_res and item_data_res.item_id == "":
			pass
			#print_rich("[color=orange]GM: ItemData resource '%s' found with EMPTY item_id. It cannot be used by ID.[/color]" % item_data_res.resource_path if item_data_res else "UNKNOWN")
		elif not item_data_res:
			pass
			#print_rich("[color=yellow]GM: Found a null entry in 'all_item_data_resources'. Please check Inspector.[/color]")

	#print_rich("[color=green]GM: Item data map initialized. %s items mapped.[/color]" % _item_data_map.size())
	#print_rich("[color=cyan]GM: GameManager initialization complete.[/color]")

	_create_world_patreon_button()

	# --- DIRECT SCENE RUN CHECK ---
	if current_game_state == GameState.BOOTING:
		var potential_player = get_tree().get_first_node_in_group("player")

		if is_instance_valid(potential_player):
			#print_rich("[color=purple]GM: Direct scene run detected (player found on boot).[/color]")
			#print_rich("[color=purple]GM: Manually setting state to IN_GAME_PLAY and assigning nodes.[/color]")

			# 1. Manually assign the player node
			player_node = potential_player

			# 2. Assign the main scene instance (assuming player is a child of the main scene)
			main_game_scene_instance = player_node.get_owner()
			if not is_instance_valid(main_game_scene_instance):
				# Fallback if owner is not set correctly
				main_game_scene_instance = get_tree().get_root().get_child(-1)

			# Find and assign the UI nodes now that the main scene is confirmed to exist.
			_find_and_assign_ui_nodes()

			#print_rich("[color=green]GM: Found player: %s[/color]" % player_node.name)
			#print_rich("[color=green]GM: Assigned main scene: %s[/color]" % main_game_scene_instance.name)

			# 3. Manually set the state.
			current_game_state = GameState.IN_GAME_PLAY

			# 4. Ensure the player can move
			if player_node.has_method("set_can_move"):
				player_node.set_can_move(true)

			if is_instance_valid(pause_menu_ui):
				pause_menu_ui.menu_panel.show()

			# --- THIS IS THE FIX ---
			# We wait one frame to ensure the Scene Tree and AudioServer are fully stable
			# before trying to create and play the audio player.
			await get_tree().process_frame
			#print_rich("[color=purple]GM: Starting music/ambience now...[/color]")
			
			# Music is currently commented out as per your request
			# SoundManager.play_music()
			
			# --- START AMBIENCE FOR TEST SCENE ---
			SoundManager.play_ambience("room_tone_air", -5.0) 
			SoundManager.play_ambience("room_tone_electric", -15.0)

		else:
			pass
			# This Else block is new - it warns you if the Player Group is missing
			#print_rich("[color=red]GM: Direct run detected, BUT no node in group 'player' was found.[/color]")
			#print_rich("[color=red]GM: Music did not start because the initialization block was skipped.[/color]")
			#print_rich("[color=red]GM: Please select your Player node -> Node Tab -> Groups -> Add 'player'.[/color]")

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
			if assisted_mode:
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
				
				
# Replace the entire existing function with this one.
# In GameManager.gd
# Replace the entire existing function with this one.
func change_game_state(new_state: GameState):
	if new_state == current_game_state:
		return

	# Wait for the end of the current frame so UI interactions clear
	await get_tree().process_frame

	# =========================================================
	# 1. LEAVING THE OLD STATE (Cleanup)
	# =========================================================
# =========================================================
	# 1. LEAVING THE OLD STATE (Cleanup)
	# =========================================================
	match current_game_state:
		GameState.MAIN_MENU:
			_cleanup_all_overlays()
			if is_instance_valid(main_menu_scene_instance):
				#print_rich("[color=yellow]GM: Cleaning up Main Menu scene.[/color]")
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

				# Aggressively clear UI references so they don't persist into the Main Menu
				verb_ui = null
				inventory_ui = null
				insurance_form_button_ui = null
				journal_button_ui = null
				# pause_menu_ui is global, don't null it
				explanation_layer = null
				input_blocker_layer = null

	#print_rich("[color=yellow]GameManager: Changing state from %s to %s[/color]" % [GameState.keys()[current_game_state], GameState.keys()[new_state]])
	current_game_state = new_state

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
			#print_rich("[color=green]GM: Main Menu scene loaded and initialized.[/color]")

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
				# Replace: var main_packed_scene = load(MAIN_GAME_SCENE_PATH)
				var main_packed_scene = cached_main_game_scene
				if not main_packed_scene:
					#print_rich("[color=red]GameManager Error: Failed to load Main Game Scene.[/color]")
					return

				main_game_scene_instance = main_packed_scene.instantiate()
				get_tree().root.add_child(main_game_scene_instance)
				_find_and_assign_ui_nodes()
				
				# Play music if we just loaded the game
				# SoundManager.play_music() 
				
				# --- START AMBIENCE FOR MAIN GAME ---
				SoundManager.play_ambience("room_tone_air", -5.0) 
				SoundManager.play_ambience("room_tone_electric", -15.0)

			# --- B. RESTORATION PHASE (Run this EVERY time we enter IN_GAME_PLAY) ---
			
			# 1. Ensure UI nodes are found (in case of re-linking)
			if not is_instance_valid(verb_ui): _find_and_assign_ui_nodes()

			# 2. Find Player if missing
			if not is_instance_valid(player_node):
				player_node = get_tree().get_first_node_in_group("player")

			# 3. Restore Main UI Visibility
			if current_interaction_state == InteractionState.WORLD:
				if is_instance_valid(verb_ui): verb_ui.visible = true
				if is_instance_valid(inventory_ui): inventory_ui.visible = true
				if is_instance_valid(journal_button_ui): journal_button_ui.visible = true
				if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.show()
				if is_instance_valid(insurance_form_button_ui):
					var should_be_visible = get_current_level_flag("insurance_button_unlocked")
					insurance_form_button_ui.visible = should_be_visible
			else:
				if is_instance_valid(verb_ui): verb_ui.visible = false
				if is_instance_valid(inventory_ui): inventory_ui.visible = false
				if is_instance_valid(journal_button_ui): journal_button_ui.visible = false
				if is_instance_valid(insurance_form_button_ui): insurance_form_button_ui.visible = false
				if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()

			# 5. Unblock Input (Remove the gray blocker)
			if is_instance_valid(input_blocker_layer):
				input_blocker_layer.visible = false

			# 6. Unlock Player Movement
			if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
				player_node.set_can_move(true)

			# Force the sentence line to refresh in case we had a verb or item selected before pausing
			update_sentence_line_ui()

			#print_rich("[color=green]GM: IN_GAME_PLAY state active. UI restored, Player unlocked.[/color]")

		GameState.PAUSED:
			update_sentence_line_ui()

		GameState.BOOTING:
			pass
			
		GameState.CUTSCENE:
			# 1. Hide the UI
			if is_instance_valid(verb_ui): verb_ui.visible = false
			if is_instance_valid(inventory_ui): inventory_ui.visible = false
			if is_instance_valid(insurance_form_button_ui): insurance_form_button_ui.visible = false
			if is_instance_valid(journal_button_ui): journal_button_ui.visible = false # <--- ADD THIS LINE
			if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()
			
			# 2. Block Input (Clicking on things in the world)
			if is_instance_valid(input_blocker_layer):
				input_blocker_layer.visible = true
				
			# 3. Stop the Player from moving
			if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
				player_node.set_can_move(false)
				
			#print_rich("[color=Plum]GM: Entered CUTSCENE state. UI hidden, Input blocked.[/color]")

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
				var hint_res = current_hint_manager.hints_dialogue if assisted_mode else current_hint_manager.hints_adventure_dialogue
				if is_instance_valid(hint_res):
					last_read_hint = current_hint_manager.evaluate_hint()
					new_hint_available.emit(false)

					if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended_for_object_dialogue):
						DialogueManager.dialogue_ended.connect(_on_dialogue_ended_for_object_dialogue, CONNECT_ONE_SHOT)

					DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, hint_res, last_read_hint)
			return
		# ------------------------------------------

		# --- QOL FIX: Empty Inventory Give Check ---
		if current_verb_id == "give" and player_inventory.is_empty():
			current_verb_id = ""
			verb_changed.emit("")

			if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended_for_object_dialogue):
				DialogueManager.dialogue_ended.connect(_on_dialogue_ended_for_object_dialogue, CONNECT_ONE_SHOT)

			var generic_lines = preload("res://generic_lines.dialogue")
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
		#print_rich("[color=red]GM: _initiate_interaction_flow called with invalid interactable_node.[/color]")
		_complete_interaction_cycle(); return

	# --- QOL FIX: Prevent "Give" without an item ---
	if verb_to_use_id == "give" and item_data_to_use == null:
		cancel_current_action(false)

		if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended_for_object_dialogue):
			DialogueManager.dialogue_ended.connect(_on_dialogue_ended_for_object_dialogue, CONNECT_ONE_SHOT)

		var generic_lines = preload("res://generic_lines.dialogue")
		DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, generic_lines, "give_no_item_selected")
		return
	# -----------------------------------------------

	# --- NEW LINE ADDED HERE ---
	# Tell the object (Aida) that an interaction is coming so she can stop walking immediately
	if interactable_node.has_method("notify_interaction_pending"):
		interactable_node.notify_interaction_pending()
	# ---------------------------

	if is_verb_lock_active:
		_activate_verb_lock(false)

	var walk_needed = true

	if interactable_node.interaction_location == Interactable.InteractionLocation.UI_OVERLAY:
		walk_needed = false
	else:
		if interactable_node.has_method("does_verb_require_walk"):
			walk_needed = interactable_node.does_verb_require_walk(verb_to_use_id, item_data_to_use)
		else:
			#print_rich("[color=yellow]GM: Interactable '%s' no 'does_verb_require_walk'. Assuming walk needed.[/color]" % interactable_node.name)
			walk_needed = true

	var item_name_for_log = "None"
	if item_data_to_use: item_name_for_log = item_data_to_use.display_name
	#print_rich("[color=aqua]GM: Initiating flow: Verb '%s' on '%s' with item '%s'. Requires walk: %s[/color]" % [verb_to_use_id, interactable_node.object_display_name, item_name_for_log, str(walk_needed)])

	if walk_needed:
		# --- THIS IS THE FIX ---
		# Set the lock flag to true before telling the player to walk.
		_is_player_walking = true

		# Force the UI to instantly suppress the action label upon clicking
		update_sentence_line_ui()

		if not is_instance_valid(player_node):
			#print_rich("[color=red]GM: Player node not set or invalid. Interacting immediately (if possible).[/color]")
			_perform_actual_interaction(interactable_node, verb_to_use_id, item_data_to_use)
			return
		if player_node.has_method("walk_to_and_interact"):
			var walk_target_pos = interactable_node.get_walk_to_position()
			player_node.walk_to_and_interact(walk_target_pos, interactable_node, verb_to_use_id, item_data_to_use)
		else:
			#print_rich("[color=orange]GM: Player '%s' no 'walk_to_and_interact'. Interacting immediately.[/color]" % player_node.name)
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
	update_sentence_line_ui()


func player_reached_interaction_target(interactable_node: Interactable, verb_to_use_id: String, item_data_to_use: ItemData):
	#print_rich("[color=aqua]GM: Player has reached target '%s'. Performing interaction.[/color]" % interactable_node.object_display_name if is_instance_valid(interactable_node) else "[color=red]INVALID TARGET[/color]")
	if not is_instance_valid(interactable_node):
		#print_rich("[color=red]GM: Player reached target, but interactable is no longer valid. Aborting interaction.[/color]")
		_complete_interaction_cycle(); return
	_perform_actual_interaction(interactable_node, verb_to_use_id, item_data_to_use)

func _perform_actual_interaction(interactable_node: Interactable, verb_to_use_id: String, item_in_hand_data: ItemData = null):
	if not is_instance_valid(interactable_node):
		#print_rich("[color=red]GM: _perform_actual_interaction called with invalid interactable_node.[/color]")
		_complete_interaction_cycle(); return

	var item_name_for_log = "None"
	var item_id_for_interaction = ""
	if item_in_hand_data:
		item_name_for_log = item_in_hand_data.display_name
		item_id_for_interaction = item_in_hand_data.item_id

	#print_rich("[color=aqua]GM: Performing actual interaction: Verb '%s' on '%s' with 'in-hand' item: '%s' (ID: '%s')[/color]" % [verb_to_use_id, interactable_node.object_display_name, item_name_for_log, item_id_for_interaction])

	# --- RECORD ACTION IN HISTORY LOG ---
	var verb_data = get_verb_data_by_id(verb_to_use_id)
	var verb_name = verb_data.display_text if verb_data else verb_to_use_id
	var obj_name = interactable_node.object_display_name
	var itm_name = item_in_hand_data.display_name if item_in_hand_data else ""
	add_dialogue_history_action(verb_name, obj_name, itm_name)
	# ------------------------------------

	_disconnect_interactable_request_signals()

	_signals_connected_to_interactable = interactable_node
	#print_rich("[color=gray]GM: Connecting signals to Interactable: %s for non-dialogue interaction.[/color]" % interactable_node.name)

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
		#print_rich("[color=darkcyan]GM: Connecting Interactable's request_set_level_flag to GM.set_current_level_flag[/color]")
		interactable_node.request_set_level_flag.connect(set_current_level_flag)

	interactable_node.attempt_interaction(verb_to_use_id, item_id_for_interaction)

# --- DialogueManager Signal Handlers (Global) ---
func _on_dialogue_started(_resource: Resource):
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)

	# Hide the main UI whenever any dialogue line appears.
	# This handles both in-world dialogue and character conversations.
	if is_instance_valid(verb_ui):
		verb_ui.visible = false
	if is_instance_valid(inventory_ui):
		inventory_ui.visible = false
	if is_instance_valid(journal_button_ui):
		journal_button_ui.visible = false
	if is_instance_valid(insurance_form_button_ui):
		insurance_form_button_ui.visible = false
	if is_instance_valid(patreon_world_ui):
		patreon_world_ui.visible = false


func _on_dialogue_ended_for_object_dialogue(_resource: Resource):
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		if current_interaction_state == InteractionState.WORLD and current_game_state == GameState.IN_GAME_PLAY:
			player_node.set_can_move(true)

	# Restore the main UI as long as we are NOT in a full-screen conversation.
	# This now correctly handles both the WORLD and the ZOOM_VIEW states.
	if current_interaction_state != InteractionState.CONVERSATION and current_game_state == GameState.IN_GAME_PLAY:
		if is_instance_valid(verb_ui):
			verb_ui.visible = true
		if is_instance_valid(inventory_ui):
			inventory_ui.visible = true
		if is_instance_valid(journal_button_ui):
			journal_button_ui.visible = true
		if is_instance_valid(insurance_form_button_ui):
			var should_be_visible = get_current_level_flag("insurance_button_unlocked")
			insurance_form_button_ui.visible = should_be_visible
		if is_instance_valid(patreon_world_ui):
			patreon_world_ui.visible = get_current_level_flag("dev_cta_completed")

	_complete_interaction_cycle()

# Replace the entire existing function with this one.
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
func _on_interactable_display_dialogue_console(text: String):
	pass
	#print_rich("[color=yellow]GM (via Interactable Console): %s[/color]" % text)

func _on_interactable_action_finished():
	#print_rich("[color=aqua]GM: Interactable action finished. Completing interaction cycle.[/color]")
	_complete_interaction_cycle()

func _disconnect_interactable_request_signals():
	if is_instance_valid(_signals_connected_to_interactable):
		var node_to_disconnect_from = _signals_connected_to_interactable
		#print_rich("[color=gray]GM: Disconnecting signals from Interactable: %s[/color]" % node_to_disconnect_from.name)

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
			#print_rich("[color=gray]GM: Disconnecting Interactable's request_set_level_flag from GM.set_current_level_flag[/color]")
			node_to_disconnect_from.request_set_level_flag.disconnect(set_current_level_flag)
	else:
		if _signals_connected_to_interactable != null:
			pass
			#print_rich("[color=yellow]GM: Tried to disconnect signals, but _signals_connected_to_interactable was invalid.[/color]")

	_signals_connected_to_interactable = null

func _complete_interaction_cycle():
	#print_rich("[color=cyan]GM: Interaction cycle fully complete. Resetting state.[/color]")
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

	# Restore UI visibility (Verbs, Inventory, Journal, Form)
	if current_interaction_state != InteractionState.CONVERSATION and current_game_state == GameState.IN_GAME_PLAY:
		if is_instance_valid(verb_ui):
			verb_ui.visible = true
		if is_instance_valid(inventory_ui):
			inventory_ui.visible = true
		if is_instance_valid(journal_button_ui):
			journal_button_ui.visible = true
		if is_instance_valid(insurance_form_button_ui):
			var should_be_visible = get_current_level_flag("insurance_button_unlocked")
			insurance_form_button_ui.visible = should_be_visible
	# --- FIX END ---

	update_sentence_line_ui()


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
		cancel_current_action()
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

func _cancel_scan():
	_scan_active = false
	if _scan_tween: _scan_tween.kill()
	if is_instance_valid(pause_menu_ui):
		pause_menu_ui.set_scan_highlight(false)

	if not (is_verb_lock_active and OS.has_feature("mobile")):
		for interactable in get_tree().get_nodes_in_group("interactables"):
			if is_instance_valid(interactable): interactable.force_highlight(false)


# --- LevelStateManager Registration & Flag Handling ---
func register_level_state_manager(lsm: LevelStateManager):
	current_level_state_manager = lsm
	if is_instance_valid(lsm):
		#print_rich("[color=LawnGreen]GM: Registered LevelStateManager: %s (from scene: %s)[/color]" % [lsm.name, lsm.get_parent().name if lsm.get_parent() else "N/A"])
		if lsm.has_method("print_initial_flags"):
			lsm.print_initial_flags()
	else:
		if lsm == null:
			pass
			#print_rich("[color=yellow]GM: LevelStateManager unregistered (set to null).[/color]")
		else:
			pass
			#print_rich("[color=orange]GM: Attempted to register invalid LevelStateManager instance.[/color]")

func set_current_level_flag(flag_name: String, value: bool):
	if is_instance_valid(current_level_state_manager):
		#print_rich("[color=darkcyan]GM: Routing to LevelStateManager to set flag: %s = %s[/color]" % [flag_name, value])
		current_level_state_manager.set_level_flag(flag_name, value)
	else:
		pass
		#print_rich("[color=orange]GM: No current LevelStateManager to set level flag '%s'. This might be an error if a level flag was intended.[/color]" % flag_name)

func get_current_level_flag(flag_name: String) -> bool:
	if is_instance_valid(current_level_state_manager):
		return current_level_state_manager.get_level_flag(flag_name)
	return false


# --- Verb Data and Availability ---
# In GameManager.gd

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
		#print_rich("[color=green]GM: Unlocked verb: %s[/color]" % verb_id_to_unlock)
	elif not verb_data: print_rich("[color=red]GM: Tried to unlock non-existent verb: '%s'[/color]" % verb_id_to_unlock)
	elif verb_id_to_unlock in unlocked_verb_ids: print_rich("[color=yellow]GM: Verb '%s' already unlocked.[/color]" % verb_id_to_unlock)

func lock_verb(verb_id_to_lock: String):
	if verb_id_to_lock in unlocked_verb_ids:
		unlocked_verb_ids.erase(verb_id_to_lock)

		if verb_id_to_lock in active_scene_verb_ids:
			active_scene_verb_ids.erase(verb_id_to_lock)

		_emit_available_verbs_changed_update()
		#print_rich("[color=yellow]GM: Locked verb: %s[/color]" % verb_id_to_lock)
		if current_verb_id == verb_id_to_lock:
			select_verb("")
	else: print_rich("[color=orange]GM: Tried to lock verb '%s' that was not unlocked or doesn't exist.[/color]" % verb_id_to_lock)

func is_verb_id_currently_active(verb_id_to_check: String) -> bool:
	if not verb_id_to_check in unlocked_verb_ids: return false
	if active_scene_verb_ids.is_empty(): return true
	return active_scene_verb_ids.has(verb_id_to_check)


# --- Inventory Management Functions ---
func add_item_to_inventory(item_id_to_add: String):
	#print_rich("[color=aqua]GM: Attempting add_item_to_inventory for ID: '%s'[/color]" % item_id_to_add)
	var item_data = get_item_data_by_id(item_id_to_add)
	if not item_data:
		#print_rich("[color=red]GM: add_item_to_inventory - FAILED. ItemData for id '%s' is null after lookup.[/color]" % item_id_to_add)
		return

	if not item_data.is_stackable and has_item(item_id_to_add):
		#print_rich("[color=yellow]GM: Item '%s' (Name: %s, non-stackable) already in inventory. Not adding duplicate.[/color]" % [item_id_to_add, item_data.display_name])
		return

	player_inventory.append(item_data)
	inventory_updated.emit(player_inventory.duplicate())
	#print_rich("[color=green]GM: Successfully added item '%s' (Name: %s) to inventory. Player now has %s items.[/color]" % [item_id_to_add, item_data.display_name, player_inventory.size()])
	show_notification("Picked up: " + item_data.display_name)

func remove_item_from_inventory(item_id_to_remove: String):
	#print_rich("[color=aqua]GM: Attempting remove_item_from_inventory for ID: '%s'[/color]" % item_id_to_remove)
	var item_data_ref = get_item_data_by_id(item_id_to_remove)
	if not item_data_ref:
		#print_rich("[color=red]GM: remove_item_from_inventory - FAILED. ItemData for id '%s' not found in master list.[/color]" % item_id_to_remove)
		return

	var item_found_and_removed = false
	for i in range(player_inventory.size() - 1, -1, -1):
		var item_data_in_inv: ItemData = player_inventory[i]
		if item_data_in_inv.item_id == item_id_to_remove:
			player_inventory.remove_at(i)
			item_found_and_removed = true
			#print_rich("[color=green]GM: Removed item '%s' (Name: %s) from inventory.[/color]" % [item_id_to_remove, item_data_in_inv.display_name])

			if current_selected_item_data and current_selected_item_data.item_id == item_id_to_remove:
				current_selected_item_data = null
				selected_inventory_item_changed.emit(null)

			inventory_updated.emit(player_inventory.duplicate())
			if not item_data_ref.is_stackable: break

	if not item_found_and_removed:
		pass
		#print_rich("[color=yellow]GM: Tried to remove item_id '%s' (Name: %s), but it was not found in player's inventory.[/color]" % [item_id_to_remove, item_data_ref.display_name])

func has_item(item_id_to_check: String) -> bool:
	for item_data_in_inv in player_inventory:
		if item_data_in_inv.item_id == item_id_to_check:
			return true
	return false

func get_item_data_by_id(item_id_to_find: String) -> ItemData:
	if _item_data_map.has(item_id_to_find):
		return _item_data_map[item_id_to_find]

	#print_rich("[color=orange]GM: get_item_data_by_id - ItemData for id '%s' NOT FOUND in _item_data_map.[/color]" % item_id_to_find)
	#print_rich("  [color=gray]GM: Current _item_data_map keys: %s[/color]" % str(_item_data_map.keys()))
	#print_rich("  [color=gray]GM: Make sure '%s' is the exact item_id in your .tres file AND that .tres file is in 'all_item_data_resources' in GameManager Inspector.[/color]" % item_id_to_find)
	return null

func get_player_inventory() -> Array[ItemData]:
	return player_inventory.duplicate()


# --- Game Flag Management (Global) ---
func set_game_flag(flag_name: String, value: bool):
	if game_flags.get(flag_name, !value) == value:
		return
	game_flags[flag_name] = value
	#print_rich("[color=green]GM: GLOBAL Flag set: '%s' = %s[/color]" % [flag_name, str(value)])

func get_game_flag(flag_name: String) -> bool:
	return game_flags.get(flag_name, false)

# ADD THESE THREE NEW FUNCTIONS

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
	#print_rich("[color=Plum]GM: Entering CONVERSATION state.[/color]")
	current_interaction_state = InteractionState.CONVERSATION

	force_clear_all_hovered_interactables()

	# --- DEBUGGING STEP ---
	# Let's see if the GameManager can actually see your button node.
	#print("Attempting to hide button UI. Node is: ", insurance_form_button_ui)
	# --- END DEBUGGING STEP ---

	# Show the blocker on layer 1 to stop clicks to the world (layer 0)
	if is_instance_valid(input_blocker_layer):
		input_blocker_layer.visible = true

	# Hide the game UI
	if is_instance_valid(verb_ui): verb_ui.visible = false
	if is_instance_valid(inventory_ui): inventory_ui.visible = false
	if is_instance_valid(insurance_form_button_ui): insurance_form_button_ui.visible = false
	if is_instance_valid(journal_button_ui): journal_button_ui.visible = false # <--- ADD THIS LINE
	if is_instance_valid(patreon_world_ui): patreon_world_ui.visible = false
	if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()

func enter_zoom_view_state():
	if current_interaction_state == InteractionState.ZOOM_VIEW: return
	#print_rich("[color=Plum]GM: Entering ZOOM_VIEW state.[/color]")
	current_interaction_state = InteractionState.ZOOM_VIEW

	force_clear_all_hovered_interactables()

	# ... (existing code for input blocker and UI layers) ...
	if is_instance_valid(input_blocker_layer):
		input_blocker_layer.visible = true
	if is_instance_valid(verb_ui):
		verb_ui.layer = 3
		verb_ui.visible = true
	if is_instance_valid(inventory_ui):
		inventory_ui.layer = 3
		inventory_ui.visible = true
	if is_instance_valid(patreon_world_ui):
		patreon_world_ui.visible = false

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
	#print_rich("[color=Plum]GM: Exiting overlay, returning to WORLD state.[/color]")
	current_interaction_state = InteractionState.WORLD

	if is_instance_valid(input_blocker_layer):
		input_blocker_layer.visible = false
	if is_instance_valid(verb_ui):
		verb_ui.layer = 1
		verb_ui.visible = true
	if is_instance_valid(inventory_ui):
		inventory_ui.layer = 1
		inventory_ui.visible = true
	if is_instance_valid(journal_button_ui): # <--- ADD THIS BLOCK
		journal_button_ui.visible = true     # <---
	if is_instance_valid(patreon_world_ui):
		patreon_world_ui.visible = get_current_level_flag("dev_cta_completed")
	if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.show()

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
		#print_rich("[color=red]GM: Cannot find UI nodes because main_game_scene_instance is not valid.[/color]")
		return

	# Tell Godot to look INSIDE the main scene for these nodes using their Unique Scene Names.
	verb_ui = main_game_scene_instance.get_node_or_null("%VerbUI_CanvasLayer")
	inventory_ui = main_game_scene_instance.get_node_or_null("%InventoryUI_CanvasLayer")
	insurance_form_button_ui = main_game_scene_instance.get_node_or_null("%InsuranceFormButtonUI")
	journal_button_ui = main_game_scene_instance.get_node_or_null("%JournalButtonUI") # <--- NEW
	input_blocker_layer = main_game_scene_instance.get_node_or_null("%InputBlockerLayer")
	explanation_layer = main_game_scene_instance.get_node_or_null("%ExplanationLayer")
	# pause_menu_ui is now spawned globally in GameManager._ready()

	if is_instance_valid(pause_menu_ui):
		if not pause_menu_ui.scan_cancel_requested.is_connected(_on_scan_cancel_pressed):
			pause_menu_ui.scan_cancel_requested.connect(_on_scan_cancel_pressed)

	# --- Verification Logging ---
	if is_instance_valid(verb_ui):
		pass
		#print_rich("[color=green]GM: Successfully found and assigned VerbUI.[/color]")
	else:
		pass
		#print_rich("[color=red]GM: FAILED to find VerbUI.[/color]")

	if is_instance_valid(inventory_ui):
		pass
		#print_rich("[color=green]GM: Successfully found and assigned InventoryUI.[/color]")
	else:
		pass
		#print_rich("[color=red]GM: FAILED to find InventoryUI.[/color]")

	if is_instance_valid(insurance_form_button_ui):
		#print_rich("[color=green]GM: Successfully found and assigned InsuranceFormButtonUI.[/color]")
		if not insurance_form_button_ui.form_button_pressed.is_connected(_on_insurance_form_button_pressed):
			insurance_form_button_ui.form_button_pressed.connect(_on_insurance_form_button_pressed)
	else:
		pass
		#print_rich("[color=red]GM: FAILED to find InsuranceFormButtonUI.[/color]")

	# --- JOURNAL VALIDATION ---
	if is_instance_valid(journal_button_ui):
		#print_rich("[color=green]GM: Successfully found and assigned JournalButtonUI.[/color]")
		# Connect the signal from the button to the GameManager!
		if not journal_button_ui.journal_button_pressed.is_connected(_on_journal_button_pressed):
			journal_button_ui.journal_button_pressed.connect(_on_journal_button_pressed)
		else:
			pass
			#print_rich("[color=red]GM: FAILED to find JournalButtonUI.[/color]")
	# --------------------------

	if is_instance_valid(input_blocker_layer):
		pass
		#print_rich("[color=green]GM: Successfully found and assigned InputBlockerLayer.[/color]")
	else:
		pass
		#print_rich("[color=red]GM: FAILED to find InputBlockerLayer.[/color]")

	if is_instance_valid(explanation_layer):
		#print_rich("[color=green]GM: Successfully found and assigned ExplanationLayer.[/color]")
		if not explanation_layer.explanation_finished.is_connected(exit_explanation_state):
			explanation_layer.explanation_finished.connect(exit_explanation_state)
	else:
		pass
		#print_rich("[color=red]GM: FAILED to find ExplanationLayer.[/color]")
		
func _on_form_field_submitted(field_id: String, value):
	#print_rich("[color=Cyan]GM: Received submission for field '%s' with value: %s[/color]" % [field_id, value])

	match field_id:
		"first_name":
			var regex = RegEx.new()
			regex.compile("(?i)^\\s*fiona\\s*$") 
			
			if regex.search(value):
				# --- CHANGED AUDIO LINE ---
				if SoundManager: SoundManager.play_sfx("form_correct_input")
				
				if is_instance_valid(_insurance_form_instance):
					_insurance_form_instance.lock_field("first_name", "FIONA")
				
				var balloon = DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, FORM_DIALOGUE, "first_name_correct")
				if is_instance_valid(balloon): balloon.process_mode = Node.PROCESS_MODE_ALWAYS
				
				set_game_flag("first_name_correct", true)
				
			else:
				# --- CHANGED AUDIO LINE ---
				if SoundManager: SoundManager.play_sfx("form_incorrect_input")

				var formatted_wrong_name = _format_wrong_name(value)
				var temp_state = {"wrong_name": formatted_wrong_name}
				var balloon = DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, FORM_DIALOGUE, "first_name_incorrect", [temp_state])
				if is_instance_valid(balloon): balloon.process_mode = Node.PROCESS_MODE_ALWAYS

		_:
			# Catch-all for unimplemented fields (Middle Name, Last Name, DOB, etc.)
			if SoundManager: SoundManager.play_sfx("form_incorrect_input")
			var balloon = DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, FORM_DIALOGUE, "field_not_ready")
			if is_instance_valid(balloon): balloon.process_mode = Node.PROCESS_MODE_ALWAYS

# This function is called ONLY when the "Close Form" button is pressed.
func _on_insurance_form_closed():
	#print_rich("[color=Yellow]GM: Insurance form was closed by the player.[/color]")

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
		for node_path in data.exceptions_to_hide:
			var node = root_node_to_search.get_node_or_null(node_path)
			if is_instance_valid(node):
				nodes_to_keep_visible.append(node)

	if is_instance_valid(verb_ui) and not verb_ui in nodes_to_keep_visible:
		verb_ui.hide()

	if is_instance_valid(inventory_ui) and not inventory_ui in nodes_to_keep_visible:
		inventory_ui.hide()
		
	# --- FIX: Hide the journal button as well ---
	if is_instance_valid(journal_button_ui) and not journal_button_ui in nodes_to_keep_visible:
		journal_button_ui.hide()
	# --------------------------------------------
	if is_instance_valid(pause_menu_ui) and not pause_menu_ui in nodes_to_keep_visible:
		pause_menu_ui.menu_panel.hide()

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

	#print_rich("[color=Plum]GM: Exiting EXPLANATION, returning to IN_GAME_PLAY state.[/color]")

	get_tree().paused = false

	# Show the main game UI
	if is_instance_valid(verb_ui): verb_ui.visible = true
	if is_instance_valid(inventory_ui): inventory_ui.visible = true
	
	# --- FIX: Ensure the Journal comes back after the explanation finishes ---
	if is_instance_valid(journal_button_ui): journal_button_ui.visible = true
	# -----------------------------------------------------------------------
	if is_instance_valid(patreon_world_ui):
		patreon_world_ui.visible = get_current_level_flag("dev_cta_completed")
	if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.show()

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
# This function runs when the main UI button (on the game screen) is pressed.
func _on_insurance_form_button_pressed():
	if is_instance_valid(_insurance_form_instance):
		return

	#print_rich("[color=LawnGreen]GM: Opening insurance form...[/color]")
	_insurance_form_instance = INSURANCE_FORM_SCENE.instantiate()

	_insurance_form_instance.field_submitted.connect(_on_form_field_submitted)
	_insurance_form_instance.form_closed.connect(_on_insurance_form_closed)
	
	# --- ADD THIS LINE ---
	_insurance_form_instance.form_submit_requested.connect(_on_form_submit_requested)
	# ---------------------

	get_tree().root.add_child(_insurance_form_instance)
	_insurance_form_instance.show()
	
	enter_conversation_state()
	get_tree().paused = true
# This function receives data from ANY "OK" button on the form.
func show_notification(message: String):
	notification_requested.emit(message)


func _on_main_menu_new_game_requested():
	if is_instance_valid(transition_layer) and transition_layer.has_method("global_fade_to_black"):
		await transition_layer.global_fade_to_black(0.5)

	change_game_state(GameState.DIFFICULTY_SELECT)

	if is_instance_valid(transition_layer) and transition_layer.has_method("global_fade_from_black"):
		transition_layer.global_fade_from_black(0.5)

func _on_difficulty_chosen(is_assisted: bool):
	assisted_mode = is_assisted
	print_rich("[color=green]GM: Difficulty selected. Assisted Mode = %s[/color]" % str(assisted_mode))

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
	#print_rich("[color=LawnGreen]GM: 'Quit Game' requested. Closing application.[/color]")
	get_tree().quit()


func _start_intro_conversation():
	#print_rich("[color=yellow]GM: Starting intro sequence...[/color]")

	var intro_overlay_packed_scene = cached_intro_overlay_scene
	if not intro_overlay_packed_scene:
		# Fallback to loading from disk if the cache was somehow cleared
		intro_overlay_packed_scene = load(INTRO_OVERLAY_SCENE_PATH)
		if not intro_overlay_packed_scene:
			print_rich("[color=red]GM Error: Failed to load Intro Overlay Scene at path: %s[/color]" % INTRO_OVERLAY_SCENE_PATH)
			return

	var intro_overlay = intro_overlay_packed_scene.instantiate()
	# --- ADD THIS LINE ---
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
	if is_instance_valid(verb_ui): verb_ui.hide()
	if is_instance_valid(inventory_ui): inventory_ui.hide()
	if is_instance_valid(journal_button_ui): journal_button_ui.hide()
	if is_instance_valid(insurance_form_button_ui): insurance_form_button_ui.hide()

	if is_instance_valid(transition_layer):
		# Wait 3 full seconds in the dark to let the player hear the environment
		await get_tree().create_timer(3.0).timeout

		# Now open the eyes
		await transition_layer.play_iris_open()

	# --- RESTORE MOVEMENT & UI ---
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)
	if is_instance_valid(verb_ui): verb_ui.show()
	if is_instance_valid(inventory_ui): inventory_ui.show()
	if is_instance_valid(journal_button_ui): journal_button_ui.show()
	if is_instance_valid(insurance_form_button_ui):
		insurance_form_button_ui.visible = get_current_level_flag("insurance_button_unlocked")

# --- JOURNAL FUNCTIONS ---
func _on_journal_button_pressed():
	if is_instance_valid(_journal_overlay_instance):
		return

	#print_rich("[color=LawnGreen]GM: Opening Journal...[/color]")

	_journal_overlay_instance = JOURNAL_OVERLAY_SCENE.instantiate()
	_journal_overlay_instance.journal_closed.connect(_on_journal_closed)

	get_tree().root.add_child(_journal_overlay_instance)

	# Hide the main UI using the conversation state
	enter_conversation_state()
	get_tree().paused = true

func _on_journal_closed():
	#print_rich("[color=Yellow]GM: Journal closed.[/color]")
	if is_instance_valid(_journal_overlay_instance):
		_journal_overlay_instance.queue_free()
		_journal_overlay_instance = null
		
	# Restore UI and unpause
	exit_to_world_state()

func _format_wrong_name(raw_name: String) -> String:
	var clean = raw_name.strip_edges().to_lower()
	if clean.length() == 0:
		return "..." # If they just submitted a blank box
	elif clean.length() <= 2:
		# e.g., "bo" -> "Bo..."
		return clean.substr(0, 1).to_upper() + clean.substr(1) + "..."
	else:
		# e.g., "joanna" -> "Jo...anna"
		# First letter uppercase, second letter lowercase, dots, then the rest
		var part1 = clean.substr(0, 1).to_upper() + clean.substr(1, 1)
		var part2 = clean.substr(2)
		return part1 + "..." + part2

# --- ADD THIS TO THE BOTTOM OF GameManager.gd ---
func _on_form_submit_requested():
	# Check all 6 flags. If they haven't gotten one correct, it defaults to false.
	var f_name = get_game_flag("first_name_correct")
	var m_name = get_game_flag("middle_name_correct")
	var l_name = get_game_flag("last_name_correct")
	var dob = get_game_flag("dob_correct")
	var phone = get_game_flag("phone_number_correct")
	var account = get_game_flag("account_number_correct")
	
	if f_name and m_name and l_name and dob and phone and account:
		# Success! (Likely unreachable in the demo, but good practice to include)
		#print_rich("[color=Green]GM: Form completely correct![/color]")
		# Play a success sound
		if SoundManager: SoundManager.play_sfx("form_correct_input")
		var balloon = DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, FORM_DIALOGUE, "complete_submit")
		if is_instance_valid(balloon): balloon.process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		# Incomplete/Incorrect (Demo behavior)
		#print_rich("[color=Orange]GM: Form incomplete or incorrect.[/color]")
		# Play an error sound
		if SoundManager: SoundManager.play_sfx("form_incorrect_input")
		var balloon = DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, FORM_DIALOGUE, "incomplete_submit")
		if is_instance_valid(balloon): balloon.process_mode = Node.PROCESS_MODE_ALWAYS

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
		elif "DialogueHistory" in child.name:
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
			if assisted_mode:
				new_hint_available.emit(true)
			else:
				new_hint_available.emit(false)

func _create_world_patreon_button():
	patreon_world_ui = CanvasLayer.new()
	patreon_world_ui.layer = 1
	add_child(patreon_world_ui)

	var btn = Button.new()
	patreon_world_ui.add_child(btn)

	var tex = load("res://Icons/patreon_logo.png")
	if tex:
		var img = tex.get_image()
		if img:
			img.resize(48, 48, Image.INTERPOLATE_BILINEAR)
			tex = ImageTexture.create_from_image(img)
		btn.icon = tex

	btn.text = " Support on Patreon"
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_constant_override("h_separation", 10)
	btn.add_theme_font_override("font", preload("res://Fonts/VarelaRound-Regular.ttf"))
	btn.add_theme_font_size_override("font_size", 20)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.6)
	btn_normal.corner_radius_top_left = 10
	btn_normal.corner_radius_top_right = 10
	btn_normal.corner_radius_bottom_left = 10
	btn_normal.corner_radius_bottom_right = 10
	btn_normal.content_margin_left = 15
	btn_normal.content_margin_right = 20
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.0)

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.8)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.8)

	btn.add_theme_stylebox_override("normal", btn_normal)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("focus", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_hover)

	btn.position = Vector2(20, 20)
	if OS.has_feature("mobile"):
		btn.position = Vector2(40, 40)
		btn.add_theme_font_size_override("font_size", 28)

	btn.pressed.connect(func():
		if SoundManager and SoundManager.has_method("play_sfx"): SoundManager.play_sfx("ui_click")
		OS.shell_open("https://patreon.com")
	)

	patreon_world_ui.hide()
