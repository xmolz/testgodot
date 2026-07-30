#region Constants & Signals
# gamemanager.gd
extends Node

const INSURANCE_FORM_SCENE = preload("res://ui/insurance_form.tscn")
const JOURNAL_OVERLAY_SCENE = preload("res://ui/journal_overlay.tscn")
const INTRO_DIALOGUE = preload("res://dialogue/intro.dialogue")
const CONVERSATION_BALLOON_SCENE = preload("res://conversation/conversationballoon.tscn")

var _insurance_form_instance: CanvasLayer = null
var _journal_overlay_instance: CanvasLayer = null

# ***** signals *****
signal verb_changed(new_verb_id: String)
signal sentence_line_updated(text: String)
signal interaction_complete # for verbui to reset its state
signal new_hint_available(is_available: bool)
signal verb_lock_changed(is_active: bool)

# character conversation ended signal
signal character_conversation_ended(dialogue_resource: DialogueResource)

signal selected_inventory_item_changed(selected_item_data: ItemData)

# ***** high-level game state management *****
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

# ***** interaction context management *****
enum InteractionState {
	WORLD,
	CONVERSATION,
	ZOOM_VIEW
}
var current_interaction_state: InteractionState = InteractionState.WORLD

var transition_layer: CanvasLayer = null

var current_game_state: GameState = GameState.BOOTING
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

# ***** state variables *****
var current_verb_id: String = ""
var persisting_verb_id: String = ""
var current_selected_item_data: ItemData = null # "in hand" / "selected" item
var hovered_interactable: Interactable = null
var hovered_interactables: Array[Interactable] = []
var player_node: CharacterBody2D

var _is_player_walking: bool = false
var _current_character_conversation_overlay_instance: Node = null

var _mouse_held_timer: float = 0.0
var _potential_hold_walk: bool = false
var _signals_connected_to_interactable: Interactable = null

var current_hint_manager: LevelHintManager = null

# ***** verb management *****
@export var all_verb_data_resources: Array[VerbData] = []

# ***** inventory management *****
@export var all_item_data_resources: Array[ItemData] = []

var current_unread_hint: String = ""
var last_read_hint: String = ""
#endregion

#region App Shell (Boot)
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

	# spawn our global transition layer immediately
	var transition_scene = preload("res://ui/TransitionLayer.tscn")
	transition_layer = transition_scene.instantiate()
	add_child(transition_layer)

	# spawn our global pause menu (lives on gamemanager so it works in all states)
	var pause_scene = preload("res://ui/pause_menu_ui.tscn")
	pause_menu_ui = pause_scene.instantiate()
	add_child(pause_menu_ui)
	pause_menu_ui.scan_cancel_requested.connect(_on_scan_cancel_pressed)

	if DialogueManager:
		DialogueManager.dialogue_started.connect(_on_dialogue_started)

	# initialize verbs
	Verbs.setup(all_verb_data_resources)
	Verbs.available_verbs_changed.connect(_on_available_verbs_changed)

	Inventory.setup(all_item_data_resources)
	Events.item_removed.connect(_on_inventory_item_removed)

	patreon_world_ui = PatreonWorldButton.new()
	add_child(patreon_world_ui)

	# ***** direct scene run check *****
	if current_game_state == GameState.BOOTING:
		var potential_player = get_tree().get_first_node_in_group("player")

		if is_instance_valid(potential_player):

			# manually assign the player node
			player_node = potential_player

			# assign the main scene instance (assuming player is a child of the main scene)
			SceneDirector.current_game_scene = player_node.get_owner()
			if not is_instance_valid(SceneDirector.current_game_scene):
				# fallback if owner is not set correctly
				SceneDirector.current_game_scene = get_tree().get_root().get_child(-1)

			# manually set the state.
			current_game_state = GameState.IN_GAME_PLAY

			# ensure the player can move
			if player_node.has_method("set_can_move"):
				player_node.set_can_move(true)

			if is_instance_valid(pause_menu_ui):
				pause_menu_ui.menu_panel.show()

			await get_tree().process_frame
			SoundManager.play_ambience("room_tone_air", -5.0)
			SoundManager.play_ambience("room_tone_electric", -15.0)
#endregion

# _process and _unhandled_input mix concerns (hint eval + hold-to-walk) and sit outside top-level regions to avoid moving code.
func _process(delta):
	# ***** fix 1: cancel verb lock if player tries to move manually with a/d *****
	if is_verb_lock_active and Input.get_axis("ui_left", "ui_right") != 0:
		cancel_current_action(false)

	# ***** fix 2: mobile hold-to-walk overriding interactable clicks *****
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

	# ***** (original logic continues below) *****
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

			# restore the cursor hover state if we stopped walking while currently over an object
			if is_instance_valid(custom_cursor_instance):
				custom_cursor_instance.set_hover_state(hovered_interactable != null)

			# restore ui text instantly upon release
			update_sentence_line_ui()
		else:
			if current_game_state == GameState.IN_GAME_PLAY and is_instance_valid(player_node):
				var mouse_world_pos = player_node.get_global_mouse_position()

				# mirror the hysteresis logic from player.gd
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

		# ***** right click: cancel current action *****
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if current_verb_id != "" or current_selected_item_data != null:
				cancel_current_action()
				get_viewport().set_input_as_handled()
			return

		# ***** left click: walk to point / hold to walk *****
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_game_state != GameState.IN_GAME_PLAY or current_interaction_state != InteractionState.WORLD:
				return
			if is_transitioning:
				return

			# find player if missing/freed (e.g., after scene swap)
			if not is_instance_valid(player_node):
				player_node = get_tree().get_first_node_in_group("player")
			if not is_instance_valid(player_node):
				return

			# player is frozen mid-action (e.g. flash animation): ignore world/floor clicks
			if player_node.get("_can_move") == false:
				return

			# ***** fix: register that the click landed in the game world! *****
			_potential_hold_walk = true

			var mouse_world_pos = player_node.get_global_mouse_position()

			# to fix touch/mouse sync issues, we cast a point exactly where the player clicked
			# to see if an interactable is underneath. this completely bypasses the hover delay.
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
				# we clicked an object! do not cancel the verb. do not walk immediately.
				# just return, and let the area2d's _input_event catch this click and process it.
				# (if the finger stays down, _potential_hold_walk will upgrade it to continuous movement!)
				return

			# we clicked empty space / the floor.
			# cancel the verb and drop the item (if any).
			if current_verb_id != "" or current_selected_item_data != null:
				cancel_current_action()

			# start walking to that point
			if is_instance_valid(player_node) and player_node.has_method("walk_to_point"):
				if _scan_active: _cancel_scan()
				_is_player_walking = true
				is_mouse_held_for_walk = true
				player_node.walk_to_point(mouse_world_pos)
				get_viewport().set_input_as_handled()
				
				
#region App Shell (State Machine)
func change_game_state(new_state: GameState):
	if new_state == current_game_state:
		return

	# wait for the end of the current frame so ui interactions clear
	await get_tree().process_frame

	# leaving the old state (cleanup)
	match current_game_state:
		GameState.MAIN_MENU:
			SceneDirector._cleanup_all_overlays()
			SceneDirector.free_main_menu()
		GameState.INTRO_CONVERSATION:
			if new_state == GameState.MAIN_MENU:
				# destroy the intro overlay if we are aborting to the main menu
				SceneDirector.free_intro_overlay()
		GameState.IN_GAME_PLAY, GameState.PAUSED:
			# when leaving the game (e.g. to menu), stop music and ambience.
			if new_state != GameState.CUTSCENE and new_state != GameState.EXPLANATION and new_state != GameState.PAUSED and new_state != GameState.IN_GAME_PLAY and new_state != GameState.INTRO_CONVERSATION:
				SoundManager.stop_music()
				SoundManager.stop_all_ambience()

			if new_state == GameState.MAIN_MENU:
				SceneDirector._cleanup_all_overlays()
				SceneDirector.teardown_game_scene()

	current_game_state = new_state
	Events.game_state_changed.emit(current_game_state)

	# entering the state (setup)
	match current_game_state:
		GameState.MAIN_MENU:
			_is_game_over_triggering = false
			if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()
			var menu = SceneDirector.show_main_menu()
			if is_instance_valid(menu):
				if not menu.new_game_requested.is_connected(_on_main_menu_new_game_requested):
					menu.new_game_requested.connect(_on_main_menu_new_game_requested)
				if not menu.quit_game_requested.is_connected(_on_main_menu_quit_requested):
					menu.quit_game_requested.connect(_on_main_menu_quit_requested)

		GameState.DIFFICULTY_SELECT:
			var screen = SceneDirector.show_difficulty_select()
			if is_instance_valid(screen):
				screen.difficulty_chosen.connect(_on_difficulty_chosen)

		GameState.EXPLANATION:
			pass

		GameState.INTRO_CONVERSATION:
			if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()

			if not is_instance_valid(SceneDirector.intro_overlay):
				SceneDirector.start_intro_overlay(INTRO_DIALOGUE, _on_intro_conversation_finished)

		GameState.IN_GAME_PLAY:
			# ***** a. loading phase *****
			var newly_loaded = SceneDirector.ensure_game_scene()
			if newly_loaded:
				# play music if we just loaded the game
				# soundmanager.play_music()
				
				# ***** start ambience for main game *****
				SoundManager.play_ambience("room_tone_air", -5.0) 
				SoundManager.play_ambience("room_tone_electric", -15.0)

			# ***** b. restoration phase (run this every time we enter in_game_play) *****
			
			# find player if missing
			if not is_instance_valid(player_node):
				player_node = get_tree().get_first_node_in_group("player")

			# restore global ui. the scene hud + input blocker restore
			# themselves in game_ui.gd via events.game_state_changed.
			if current_interaction_state == InteractionState.WORLD:
				_set_patreon_visible(true)
				if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.show()
			else:
				_set_patreon_visible(false)
				if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()

			# unlock player movement
			if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
				player_node.set_can_move(true)

			# force the sentence line to refresh in case we had a verb or item selected before pausing
			update_sentence_line_ui()

		GameState.PAUSED:
			update_sentence_line_ui()

		GameState.BOOTING:
			pass
			
		GameState.CUTSCENE:
			# hide the global ui (scene hud + blocker handled by game_ui.gd)
			_set_patreon_visible(false)
			if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()
			
			# stop the player from moving
			if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
				player_node.set_can_move(false)
#endregion


#region Interaction Engine
#region Verb & Item Selection
func select_verb(verb_id_to_select: String):
	# if the player manually selects or toggles a verb, clear any forced sticky state
	persisting_verb_id = ""

	var previously_selected_verb_id = current_verb_id
	var new_verb_id = ""

	if current_verb_id == verb_id_to_select:
		new_verb_id = ""
	else:
		var is_selectable = false
		for verb_data in Verbs.get_currently_displayable_verbs():
			if verb_data.verb_id == verb_id_to_select:
				is_selectable = true; break
		if verb_id_to_select == "" or is_selectable:
			new_verb_id = verb_id_to_select
		else:
			new_verb_id = previously_selected_verb_id

	if current_verb_id != new_verb_id:
		current_verb_id = new_verb_id
		verb_changed.emit(current_verb_id)

		# ***** think verb interception *****
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
		#

		# ***** qol fix: empty inventory give check *****
		if current_verb_id == "give" and Inventory.is_empty():
			current_verb_id = ""
			verb_changed.emit("")

			if not DialogueManager.dialogue_ended.is_connected(restore_world_after_object_dialogue):
				DialogueManager.dialogue_ended.connect(restore_world_after_object_dialogue, CONNECT_ONE_SHOT)

			var generic_lines = preload("res://dialogue/generic_lines.dialogue")
			DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, generic_lines, "give_empty_inventory")
			return
		#

		# if we select a verb that does not use items, or if we toggle the verb off, drop the in-hand item
		if (current_verb_id == "" or (current_verb_id != "use" and current_verb_id != "give")) and current_selected_item_data != null:
			current_selected_item_data = null
			selected_inventory_item_changed.emit(null)

		var verb_data = Verbs.get_verb_data_by_id(current_verb_id)
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

		# if we select an item, but the current verb isn't item-compatible, drop the verb.
		if current_verb_id != "" and not previous_verb_id_was_item_compatible:
			current_verb_id = ""
			verb_changed.emit("")

		# if no verb is selected, default to "use" when picking up an item
		if current_verb_id == "":
			current_verb_id = "use"
			verb_changed.emit("use")

		# ***** fix: turn on the verb lock so the thought bubble and highlights appear! *****
		_activate_verb_lock(true)

	update_sentence_line_ui()

func cancel_current_action(play_sound: bool = true):
	# while a zoom view forces a sticky verb, the player cannot cancel it
	# (blocks right-click and the a/d verb-lock cancel in _process).
	# overlay cleanup clears persisting_verb_id before calling this, so closing still works.
	if current_interaction_state == InteractionState.ZOOM_VIEW and persisting_verb_id != "":
		return

	var did_cancel = false

	# if the player right-clicks to cancel, drop the sticky state
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
		# play a slightly lower pitched click sound to indicate cancellation
		if play_sound and SoundManager: SoundManager.play_sfx("ui_click")
#endregion


#region Hover Stack
# ***** ui and interaction flow *****
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

func _pick_top_interactable(candidates: Array[Interactable]) -> Interactable:
	if candidates.is_empty():
		return null
	var top_interactable = candidates[0]
	for i in range(1, candidates.size()):
		var candidate = candidates[i]

		# safely get effective z-index (checking parent if needed)
		var top_z = top_interactable.z_index
		if top_z == 0 and top_interactable.get_parent() is Node2D:
			top_z = top_interactable.get_parent().z_index

		var cand_z = candidate.z_index
		if cand_z == 0 and candidate.get_parent() is Node2D:
			cand_z = candidate.get_parent().z_index

		if cand_z > top_z:
			top_interactable = candidate
		elif cand_z == top_z:
			# if z-index is tied, lower on the screen (higher y) is in front
			if candidate.global_position.y > top_interactable.global_position.y:
				top_interactable = candidate
	return top_interactable

func _update_top_hovered_object():
	# clean out invalid instances just in case an object was destroyed while hovered
	for i in range(hovered_interactables.size() - 1, -1, -1):
		if not is_instance_valid(hovered_interactables[i]):
			hovered_interactables.remove_at(i)

	# ***** transition override *****
	if hovered_interactables.is_empty() or is_transitioning:
		hovered_interactable = null
		if is_instance_valid(custom_cursor_instance):
			custom_cursor_instance.set_hover_state(false)
		update_sentence_line_ui()
		return

	hovered_interactable = _pick_top_interactable(hovered_interactables)

	update_sentence_line_ui()

	# ***** qol fix: cursor state for incomplete give *****
	var should_hover_cursor = true
	if current_verb_id == "give" and current_selected_item_data == null:
		should_hover_cursor = false

	if is_instance_valid(custom_cursor_instance) and not is_mouse_held_for_walk:
		custom_cursor_instance.set_hover_state(should_hover_cursor)
#endregion


#region Sentence Line
func update_sentence_line_ui():
	if is_mouse_held_for_walk or _is_player_walking or current_game_state == GameState.PAUSED or is_transitioning:
		sentence_line_updated.emit("")
		if is_instance_valid(player_node): player_node.hide_thought_bubble()
		return

	var line_text = ""
	var bubble_text = ""

	if current_verb_id != "":
		var verb_data = Verbs.get_verb_data_by_id(current_verb_id)
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
#endregion


#region Click Routing & Walk-to-Interact
var _pending_click_candidates: Array[Interactable] = []

func process_interaction_click(interactable_node: Interactable):
	if is_transitioning: return
	if not is_instance_valid(interactable_node): return
	if _pending_click_candidates.is_empty():
		_resolve_pending_click.call_deferred()
	if not _pending_click_candidates.has(interactable_node):
		_pending_click_candidates.append(interactable_node)

func _resolve_pending_click():
	var candidates: Array[Interactable] = []
	for c in _pending_click_candidates:
		if is_instance_valid(c):
			candidates.append(c)
	_pending_click_candidates.clear()
	if candidates.is_empty(): return
	var winner: Interactable = null
	# source of truth: whatever the cursor label is showing
	if is_instance_valid(hovered_interactable) and candidates.has(hovered_interactable):
		winner = hovered_interactable
	else:
		winner = _pick_top_interactable(candidates)  # touch input / no-hover fallback
	_process_interaction_click_resolved(winner)

func _process_interaction_click_resolved(interactable_node: Interactable):
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

	# ***** qol fix: prevent "give" without an item *****
	if verb_to_use_id == "give" and item_data_to_use == null:
		cancel_current_action(false)

		if not DialogueManager.dialogue_ended.is_connected(restore_world_after_object_dialogue):
			DialogueManager.dialogue_ended.connect(restore_world_after_object_dialogue, CONNECT_ONE_SHOT)

		var generic_lines = preload("res://dialogue/generic_lines.dialogue")
		DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, generic_lines, "give_no_item_selected")
		return
	#

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

		# force the ui to instantly suppress the action label upon clicking
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

	# ***** record action in history log *****
	var verb_data = Verbs.get_verb_data_by_id(verb_to_use_id)
	var verb_name = verb_data.display_text if verb_data else verb_to_use_id
	var obj_name = interactable_node.object_display_name
	var itm_name = item_in_hand_data.display_name if item_in_hand_data else ""
	DialogueHistory.add_action(verb_name, obj_name, itm_name)
	#

	_disconnect_interactable_request_signals()

	_signals_connected_to_interactable = interactable_node

	if not interactable_node.interaction_processed.is_connected(_on_interactable_action_finished):
		interactable_node.interaction_processed.connect(_on_interactable_action_finished)

	interactable_node.attempt_interaction(verb_to_use_id, item_id_for_interaction)
#endregion


#region Interaction States
# ***** dialoguemanager signal handlers (global) *****
func _on_dialogue_started(_resource: Resource):
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)

	# the hud itself is hidden by game_ui.gd. we only hide the patreon button here.
	_set_patreon_visible(false)

func restore_world_after_object_dialogue(_resource: Resource):
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		if current_interaction_state == InteractionState.WORLD and current_game_state == GameState.IN_GAME_PLAY:
			player_node.set_can_move(true)

	# restore the global ui. the scene hud is handled by game_ui.gd.
	if current_interaction_state != InteractionState.CONVERSATION and current_game_state == GameState.IN_GAME_PLAY:
		_set_patreon_visible(true)

	_complete_interaction_cycle()

func register_character_conversation(overlay: Node):
	_current_character_conversation_overlay_instance = overlay
	if overlay.has_signal("conversation_finished") and not overlay.conversation_finished.is_connected(_on_character_conversation_finished):
		overlay.conversation_finished.connect(_on_character_conversation_finished, CONNECT_ONE_SHOT)

func _on_character_conversation_finished(resource: DialogueResource):
	exit_to_world_state()

	# do not queue_free the overlay here — it cleans itself up
	# via _destroy_and_clear_cache / _cleanup_and_queue_free.
	# calling queue_free here races with the overlay's own cleanup
	# and prevents texture references from being properly nulled,
	# causing large textures to linger in vram until gc collects them.
	_current_character_conversation_overlay_instance = null

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	_complete_interaction_cycle()

	character_conversation_ended.emit(resource)
#endregion


#region Click Routing & Walk-to-Interact
# ***** interactable signal handlers *****
func _on_interactable_action_finished():
	_complete_interaction_cycle()
#endregion


#region Verb & Item Selection
func _on_inventory_item_removed(item_id: String):
	if current_selected_item_data and current_selected_item_data.item_id == item_id:
		current_selected_item_data = null
		selected_inventory_item_changed.emit(null)

func _on_available_verbs_changed(_available_verbs: Array[VerbData]):
	if current_verb_id != "" and not Verbs.is_verb_id_currently_active(current_verb_id):
		select_verb("")
#endregion


#region Click Routing & Walk-to-Interact
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

	# ***** sticky verb fix *****
	if persisting_verb_id != "":
		current_verb_id = persisting_verb_id
		verb_changed.emit(current_verb_id)
	else:
		if current_verb_id != "":
			current_verb_id = ""
			verb_changed.emit("")
		else:
			current_verb_id = ""
	#

	if current_selected_item_data:
		current_selected_item_data = null
		selected_inventory_item_changed.emit(null)

	# ***** fix start: restore player control and ui *****
	# since we removed the unfreeze logic from the individual dialogue actions,
	# we must ensure the player is un-frozen here, at the absolute end of the chain.
	
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		# only unfreeze if we are in the normal gameplay state (not a full cutscene/zoom)
		if current_interaction_state == InteractionState.WORLD and current_game_state == GameState.IN_GAME_PLAY:
			player_node.set_can_move(true)

	# restore ui visibility
	if current_interaction_state != InteractionState.CONVERSATION and current_game_state == GameState.IN_GAME_PLAY:
		_set_patreon_visible(true)

	_is_player_walking = false
	update_sentence_line_ui()
#endregion


#region UI Utilities
# For some reason the patreon button is global (child of gamemanager) so it can't be managed by
# the level's game_ui.gd. it follows the same show/hide rhythm the gameplay hud
# always had, gated by the dev_cta_completed level flag.
func _set_patreon_visible(show: bool):
	if is_instance_valid(patreon_world_ui):
		patreon_world_ui.visible = Flags.get_level_flag("dev_cta_completed") if show else false
#endregion


#region Verb & Item Selection
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
#endregion


#region Scan
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
#endregion


#region Hover Stack
# ***** verb data and availability (moved to verbs autoload) *****

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
#endregion


#region Interaction States
func enter_conversation_state():
	if current_interaction_state == InteractionState.CONVERSATION: return
	current_interaction_state = InteractionState.CONVERSATION

	force_clear_all_hovered_interactables()

	# scene hud + input blocker are handled by game_ui.gd via the signal below.
	_set_patreon_visible(false)
	if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()
	Events.interaction_state_changed.emit(current_interaction_state)

func enter_zoom_view_state():
	if current_interaction_state == InteractionState.ZOOM_VIEW: return
	current_interaction_state = InteractionState.ZOOM_VIEW

	force_clear_all_hovered_interactables()

	# layer juggling for verb/inventory + input blocker live in game_ui.gd now.
	_set_patreon_visible(false)

	if is_instance_valid(player_node):
		player_node.set_can_move(false)

	get_tree().paused = true
	Events.interaction_state_changed.emit(current_interaction_state)

func exit_to_world_state():
	current_interaction_state = InteractionState.WORLD

	# scene hud restore + layer reset + blocker are handled by game_ui.gd.
	_set_patreon_visible(true)
	if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.show()

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	get_tree().paused = false
	Events.interaction_state_changed.emit(current_interaction_state)

func enter_chapter_state():
	# chapter initialization and state setup completed
	player_node = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player_node):
		push_warning("GameManager: enter_chapter_state() could not find player node in group 'player'.")

	SceneDirector.current_game_scene = get_tree().current_scene
	if not is_instance_valid(SceneDirector.current_game_scene):
		SceneDirector.current_game_scene = get_tree().get_root().get_child(-1)

	current_hint_manager = null
	force_clear_all_hovered_interactables()

	current_interaction_state = InteractionState.WORLD
	
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)
		
	persisting_verb_id = ""
	_is_player_walking = false
	Events.interaction_state_changed.emit(current_interaction_state)
#endregion
#endregion


#region Screen & Overlay Lifecycle
# this function is called only when the "close form" button is pressed.
func _on_insurance_form_closed():

	# clean up our reference to the form instance. this is important.
	_insurance_form_instance = null

	# return control to the player and un-pause the game.
	exit_to_world_state()

func start_explanation(data: ExplanationData, root_node_to_search: Node):
	if current_game_state == GameState.EXPLANATION or not is_instance_valid(SceneDirector.current_game_scene):
		return

	change_game_state(GameState.EXPLANATION)

	# game_ui.gd hides the hud (honoring data.exceptions_to_hide) and starts
	# the explanationlayer in response to this event.
	if is_instance_valid(pause_menu_ui): pause_menu_ui.menu_panel.hide()

	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)

	get_tree().paused = true
	Events.explanation_started.emit(data, root_node_to_search)

func exit_explanation_state():
	if current_game_state != GameState.EXPLANATION:
		return

	get_tree().paused = false

	# show the main game ui
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
#endregion


#region App Shell (Run-State and Quit)
# ***** run-state reset *****
# What this is for: called once per game (from _on_main_menu_new_game_requested)
# so a second playthrough in the same session starts clean.
# intentionally does not touch user preferences (text_speed,
# instant_text, dialogue_text_scale, is_auto_playing), the
# cached_* packedscenes, or is_transitioning (transitionlayer owns it).
func reset_run_state():
	# ***** interaction / input transients *****
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

	# ***** verb & item selection *****
	persisting_verb_id = ""
	if current_verb_id != "":
		current_verb_id = ""
		verb_changed.emit("")
	if current_selected_item_data != null:
		current_selected_item_data = null
		selected_inventory_item_changed.emit(null)

	# ***** inventory *****
	Inventory.reset()

	# ***** global flags & dialogue memory *****
	Flags.reset_run_state()
	DialogueHistory.reset()

	# ***** hints & difficulty (difficulty select re-establishes these) *****
	Settings.assisted_mode = false
	current_unread_hint = ""
	last_read_hint = ""
	new_hint_available.emit(false)

	# ***** verbs: re-derive defaults exactly like _ready() does *****
	Verbs.reset_run_state()

	# ***** sibling autoload run-state (sergey conversation memory etc., all dat crap) *****
	if ConversationEventManager and ConversationEventManager.has_method("reset_run_state"):
		ConversationEventManager.reset_run_state()

	# ***** stale references (their owning scenes were freed on quit) *****
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

	Verbs.unlock_verb("think")

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

func _on_intro_conversation_finished(_dialogue_resource):
	if is_instance_valid(transition_layer):
		await transition_layer.play_iris_close()

	# await the state change so the scene actually loads before we try to lock things!
	await change_game_state(GameState.IN_GAME_PLAY)
	SceneDirector.intro_overlay = null

	# ***** prevent movement & ui during darkness *****
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)
	_set_patreon_visible(false)
	Events.gameplay_ui_visibility_requested.emit(false)

	if is_instance_valid(transition_layer):
		# wait 3 full seconds in the dark to let the player hear the environment
		await get_tree().create_timer(3.0).timeout

		# now open the eyes
		await transition_layer.play_iris_open()

	# ***** restore movement & ui *****
	if is_instance_valid(player_node) and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)
	_set_patreon_visible(true)
	Events.gameplay_ui_visibility_requested.emit(true)
#endregion


#region Screen & Overlay Lifecycle (Journal)
# journal stuff
func open_journal():
	if is_instance_valid(_journal_overlay_instance):
		return

	_journal_overlay_instance = JOURNAL_OVERLAY_SCENE.instantiate()
	_journal_overlay_instance.journal_closed.connect(_on_journal_closed)

	get_tree().root.add_child(_journal_overlay_instance)

	# hide main ui
	enter_conversation_state()
	get_tree().paused = true

func _on_journal_closed():
	if is_instance_valid(_journal_overlay_instance):
		_journal_overlay_instance.queue_free()
		_journal_overlay_instance = null
		
	# restore ui , unpasue
	exit_to_world_state()
#endregion


#region App Shell (Game Over)
func trigger_game_over(fade_duration: float = 1.5):
	if _is_game_over_triggering:
		return
	_is_game_over_triggering = true

	print_rich("[color=red]GM: Game Over Triggered![/color]")

	# hide balloon
	if is_instance_valid(SceneDirector.intro_overlay) and "current_balloon" in SceneDirector.intro_overlay and is_instance_valid(SceneDirector.intro_overlay.current_balloon):
		SceneDirector.intro_overlay.current_balloon.hide()

	# trigger the global fade avoiding destruction during cleanup
	if is_instance_valid(transition_layer) and transition_layer.has_method("global_fade_to_black"):
		await transition_layer.global_fade_to_black(fade_duration)
	else:
		await get_tree().create_timer(fade_duration).timeout

	# change the state, stop player input
	change_game_state(GameState.GAME_OVER)

	# stop all audio
	if SoundManager:
		if SoundManager.has_method("stop_music"): SoundManager.stop_music()
		if SoundManager.has_method("stop_all_ambience"): SoundManager.stop_all_ambience()

	# clean up the main game scene if it exists
	SceneDirector.teardown_game_scene()

	# aggressively hunt down overlays and dialogue balloons to prevent crashes
	SceneDirector._cleanup_all_overlays()

	# 5 ensure the tree is unpaused (form/journal/zoom may have paused it)
	get_tree().paused = false

	# spawn the game over scene
	SceneDirector.show_game_over()

func quit_to_main_menu_smooth():
	if SoundManager:
		SoundManager.stop_all_audio()
	SceneDirector._cleanup_all_overlays()

	if is_instance_valid(transition_layer) and transition_layer.has_method("global_fade_to_black"):
		await transition_layer.global_fade_to_black(1.0)

	# the screen is now black: tear the world down while it is still frozen,
	# then unpause so the main menu is responsive. (mirrors trigger_game_over)
	SceneDirector._cleanup_all_overlays()
	SceneDirector.teardown_game_scene()
	get_tree().paused = false
	current_interaction_state = InteractionState.WORLD

	change_game_state(GameState.MAIN_MENU)

	if is_instance_valid(transition_layer) and transition_layer.has_method("global_fade_from_black"):
		transition_layer.global_fade_from_black(1.0)
#endregion


#region Screen & Overlay Lifecycle
func force_close_tracked_overlays():
	if is_instance_valid(_insurance_form_instance):
		_insurance_form_instance.queue_free()
	_insurance_form_instance = null
	if is_instance_valid(_journal_overlay_instance):
		_journal_overlay_instance.queue_free()
	_journal_overlay_instance = null
#endregion


#region Hints
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
#endregion
