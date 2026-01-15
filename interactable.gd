extends Area2D
class_name Interactable

signal display_dialogue(text: String)
signal self_destruct_requested
signal interaction_processed

# Global/GameManager state requests
signal request_remove_item_from_inventory(item_id_to_remove: String)
signal request_add_item_to_inventory(item_id_to_add: String)
signal request_set_game_flag(flag_name: String, value: bool)
signal request_set_level_flag(flag_name: String, value: bool)
signal interaction_pending # Fired when the player clicks, but is still walking over

enum ObjectCategory { OBJECT, CHARACTER }
# --- NEW ENUM TO DEFINE WHERE THE INTERACTABLE EXISTS ---
enum InteractionLocation { WORLD, UI_OVERLAY }


@export var object_display_name: String = "Object"
@export var object_id: String = ""
@export var state_flag_id: String = ""
@export var category: ObjectCategory = ObjectCategory.OBJECT
# --- NEW EXPORT VARIABLE FOR THE LOCATION CONTEXT ---
@export var interaction_location: InteractionLocation = InteractionLocation.WORLD


# --- THE NEW SYSTEM IS NOW THE ONLY SYSTEM ---
@export var interactions: Array[InteractionResponse] = [preload("res://interactions/actions/DefaultExamineResponse.tres")]

@onready var object_sprite: Sprite2D = get_parent().get_node_or_null("ObjectSprite")
@onready var walk_to_point: Marker2D = $WalkToPoint if has_node("WalkToPoint") else null
var _is_mouse_over: bool = false

@export var character_conversation_overlay_scene: PackedScene
@export var object_zoom_overlay_scene: PackedScene


func _ready():
	if not state_flag_id.is_empty():
		if GameManager.get_current_level_flag(state_flag_id):
			get_parent().queue_free()
			return

	if object_id == "":
		object_id = name + "_" + str(get_instance_id())
		print_rich("[color=yellow]Interactable: '%s' no object_id. Auto-gen: %s[/color]" % [name, object_id])
	if category == ObjectCategory.CHARACTER and character_conversation_overlay_scene == null:
		print_rich("[color=orange]Interactable '%s' (ID: %s): Category CHARACTER but no 'character_conversation_overlay_scene'![/color]" % [object_display_name, object_id])
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	self_destruct_requested.connect(queue_free)

func _on_mouse_entered():
	_is_mouse_over = true
	if GameManager: GameManager.set_hovered_object(self)
	if object_sprite and object_sprite.material is ShaderMaterial and object_sprite.material.get_shader_parameter("enable_outline")!=null:
		object_sprite.material.set_shader_parameter("enable_outline", true)

func _on_mouse_exited():
	_is_mouse_over = false
	if GameManager: GameManager.clear_hovered_object()
	if object_sprite and object_sprite.material is ShaderMaterial and object_sprite.material.get_shader_parameter("enable_outline")!=null:
		object_sprite.material.set_shader_parameter("enable_outline", false)

func _on_input_event(_v: Viewport, event: InputEvent, _sidx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if GameManager: GameManager.process_interaction_click(self)

# --- FULLY REFACTORED CORE LOGIC ---
func attempt_interaction(verb_id: String, item_id_used_with: String = ""):
	# --- FIX: NORMALIZE "USE" VERBS ---
	# If GameManager sends "use_item" (because you have an item selected),
	# we treat it as "use" so you can simply type "use" in the Inspector.
	var effective_verb_id = verb_id
	if verb_id == "use_item" or verb_id == "use_on_target":
		effective_verb_id = "use"
	# ----------------------------------

	print_rich("[color=Orchid]--- Interactable '%s': attempt_interaction --- Verb: '%s' (Effective: '%s'), ItemID: '%s'[/color]" % [object_display_name, verb_id, effective_verb_id, item_id_used_with])

	# Check for a matching interaction in our resource array.
	for response in interactions:
		if not response or response.verb_id.is_empty():
			continue

		# 1. CHECK AGAINST EFFECTIVE VERB ID
		var verb_matches: bool = (response.verb_id == effective_verb_id)
		
		# 2. CHECK ITEM ID
		var item_matches: bool = (response.required_item_id == item_id_used_with)

		# 3. CHECK FLAG CONDITIONS
		var flag_matches: bool = true 
		if not response.required_flag_id.is_empty():
			# This checks the LevelStateManager via GameManager to see if the flag matches your Inspector setting
			if GameManager:
				flag_matches = (GameManager.get_current_level_flag(response.required_flag_id) == response.required_flag_value)
			else:
				flag_matches = false # Safety check

		# IF ALL CONDITIONS MET:
		if verb_matches and item_matches and flag_matches:
			print_rich("[color=LimeGreen]Found matching InteractionResponse for Verb '%s' and Item '%s' with Flag Condition Met.[/color]" % [effective_verb_id, item_id_used_with])

			# Execute the actions in order
			for action in response.actions_to_perform:
				if action:
					# Await the action execution. 
					# This handles the timing for Dialogue (Wait for close) and Sounds (Wait for finish).
					await action.execute(self)

			# Signal to GameManager that the entire sequence is done.
			# This triggers the "Unfreeze Player" and "Restore UI" logic in GameManager.
			interaction_processed.emit()
			return

	# --- FALLBACK LOGIC (If no match found above) ---
	
	if GameManager:
		# Use the original verb_id for fallback lookup (or effective, depending on your fallback setup)
		var verb_data = GameManager.get_verb_data_by_id(verb_id) 
		if is_instance_valid(verb_data) and is_instance_valid(verb_data.fallback_dialogue_file):
			print_rich("[color=Goldenrod]No match found. Calling FallbackManager.[/color]")
			if FallbackManager:
				FallbackManager.trigger_fallback(verb_data, self.object_id, item_id_used_with)
			return

	# Final safety net if no fallback is configured
	print_rich("[color=Red]No interaction response and no fallback file found for verb '%s'.[/color]" % verb_id)
	display_dialogue.emit("I can't seem to do that.")
	interaction_processed.emit()

func get_walk_to_position() -> Vector2:
	if walk_to_point: return walk_to_point.global_position
	return get_parent().global_position

# --- CORRECTED VERSION OF THIS FUNCTION ---
# This function provides simple, reliable logic for walking.
func does_verb_require_walk(verb_id_to_check: String, item_data_used: ItemData = null) -> bool:
	# 1. "Walk to" always requires walking.
	if verb_id_to_check == "walk_to":
		return true

	# 2. Determine the Item ID we are checking against
	var item_id_checking = ""
	if item_data_used:
		item_id_checking = item_data_used.item_id

	# 3. Search through the interactions array to find the SPECIFIC response that will trigger.
	# We use the exact same matching logic as attempt_interaction() to find the right one.
	for response in interactions:
		if not response: continue

		# Check basic matches
		var verb_matches: bool = (response.verb_id == verb_id_to_check)
		var item_matches: bool = (response.required_item_id == item_id_checking)

		# Check flag matches (Logic matching attempt_interaction)
		var flag_matches: bool = true
		if not response.required_flag_id.is_empty():
			# If a flag ID is specified, we must check it.
			flag_matches = (GameManager.get_current_level_flag(response.required_flag_id) == response.required_flag_value)

		# If we found the valid interaction response that is going to fire:
		if verb_matches and item_matches and flag_matches:
			# Return the custom setting from the Inspector
			return response.requires_walk

	# 4. Fallback defaults if no specific interaction was found in the list.
	# If the specific interaction isn't defined, we fall back to generic rules.
	
	if verb_id_to_check == "examine":
		return false
		
	if verb_id_to_check == "talk_to" and category == ObjectCategory.CHARACTER:
		return true

	# Default safety net: If we don't know what to do, walk to it.
	return true


func notify_interaction_pending():
	interaction_pending.emit()
