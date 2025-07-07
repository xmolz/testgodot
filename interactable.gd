extends Area2D
class_name Interactable

signal display_dialogue(text: String)
signal self_destruct_requested
signal interaction_processed

# Global/GameManager state requests
signal request_remove_item_from_inventory(item_id_to_remove: String)
signal request_add_item_to_inventory(item_id_to_add: String)
signal request_set_game_flag(flag_name: String, value: bool) # For truly global flags

# NEW: Level-specific state request
signal request_set_level_flag(flag_name: String, value: bool) # <<<< NEW SIGNAL


enum ObjectCategory { OBJECT, CHARACTER }

@export var object_display_name: String = "Object"
@export var object_id: String = ""
@export var verb_actions: Dictionary = {}
# Example for Rusty Key's verb_actions:
# "pickup": {
#   "requires_walk": true,
#   "action_type": "sequence",
#   "steps": [
#     {"action_type": "say_line", "line": "Picked up the %object."},
#     {"action_type": "request_add_item", "item_id": "key_rusty"},
#     {"action_type": "request_set_level_flag", "flag_name": "rusty_key_picked_up", "value": true}, # <<<< ACTION
#     {"action_type": "destroy"}
#   ]
# }

# ... (rest of variables, _ready, mouse handlers, etc. - UNCHANGED) ...
@onready var object_sprite: Sprite2D = $ObjectSprite if has_node("ObjectSprite") else null
@onready var walk_to_point: Marker2D = $WalkToPoint if has_node("WalkToPoint") else null
var _is_mouse_over: bool = false
@export var category: ObjectCategory = ObjectCategory.OBJECT
@export var character_conversation_overlay_scene: PackedScene

func _ready():
	if object_id == "":
		object_id = name + "_" + str(get_instance_id())
		print_rich("[color=yellow]Interactable: '%s' no object_id. Auto-gen: %s[/color]" % [name, object_id])
	if category == ObjectCategory.CHARACTER and character_conversation_overlay_scene == null:
		print_rich("[color=orange]Interactable '%s' (ID: %s): Category CHARACTER but no 'character_conversation_overlay_scene'![/color]" % [object_display_name, object_id])
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	self_destruct_requested.connect(queue_free)
	# Shader setup... (keep your existing shader setup)

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


# Interactable.gd

# ... (other code, signals, variables) ...

# Interactable.gd

# ... (other code, signals, variables) ...

# Interactable.gd

# ... (other code, signals, variables) ...

# You can declare these as member variables if preferred and init in _ready
# var USE_ITEM_VERB: String
# var USE_ON_TARGET_VERB: String
#
# func _ready():
#     USE_ITEM_VERB = GameManager.IMPLICIT_USE_ITEM_VERB_ID if GameManager and GameManager.has("IMPLICIT_USE_ITEM_VERB_ID") else "use_item"
#     USE_ON_TARGET_VERB = GameManager.USE_ON_TARGET_VERB_ID if GameManager and GameManager.has("USE_ON_TARGET_VERB_ID") else "use_on_target"
#     # ... rest of _ready ...

func attempt_interaction(verb_id: String, item_id_used_with: String = ""):
	# --- CORRECTED: Initialize as regular variables ---
	var use_item_verb_actual: String = "use_item" # Default fallback
	var use_on_target_verb_actual: String = "use_on_target" # Default fallback

	if GameManager: # Check if GameManager (autoload) is available
		if GameManager.has_meta("IMPLICIT_USE_ITEM_VERB_ID_CONST"): # Check if the const exists (using a unique meta name to avoid issues with .has for consts)
			use_item_verb_actual = GameManager.IMPLICIT_USE_ITEM_VERB_ID
		elif GameManager.has_method("get_implicit_use_item_verb_id"): # Alternative: getter method
			use_item_verb_actual = GameManager.get_implicit_use_item_verb_id()

		if GameManager.has_meta("USE_ON_TARGET_VERB_ID_CONST"):
			use_on_target_verb_actual = GameManager.USE_ON_TARGET_VERB_ID
		elif GameManager.has_method("get_use_on_target_verb_id"):
			use_on_target_verb_actual = GameManager.get_use_on_target_verb_id()
	# --- END CORRECTION ---

	print_rich("[color=Orchid]--- Interactable '%s': attempt_interaction --- Verb: '%s', ItemID: '%s' (Using actual verbs: IMPLICIT='%s', ON_TARGET='%s')[/color]" % [object_display_name, verb_id, item_id_used_with, use_item_verb_actual, use_on_target_verb_actual])

	if verb_id == "examine" or verb_id == "talk_to":
		interaction_processed.emit()
		print_rich("[color=Orchid]--- End Interactable.attempt_interaction (%s handled by GM) ---[/color]" % verb_id)
		return

	var action_details_to_execute: Dictionary = {}
	var interaction_possible = false

	# Debug print for Burger
	if object_display_name == "Burger":
		print_rich("[color=SkyBlue]Burger verb_actions: %s[/color]" % str(verb_actions))

	if verb_id == use_on_target_verb_actual: # Explicit "Use Item X WITH Target Y"
		print_rich("[color=SkyBlue]Interactable '%s': Handling verb '%s' (USE_ON_TARGET_VERB)[/color]" % [object_display_name, verb_id])
		if verb_actions.has(use_on_target_verb_actual):
			print_rich("[color=SkyBlue]  '%s' found in verb_actions.[/color]" % use_on_target_verb_actual)
			var use_on_target_config: Dictionary = verb_actions[use_on_target_verb_actual]
			print_rich("[color=SkyBlue]  use_on_target_config: %s[/color]" % str(use_on_target_config))

			if item_id_used_with != "" and use_on_target_config.has("item_specific_actions"):
				print_rich("[color=SkyBlue]  Checking item_specific_actions for item_id: '%s'[/color]" % item_id_used_with)
				var item_specifics: Dictionary = use_on_target_config["item_specific_actions"]
				print_rich("[color=SkyBlue]  item_specifics dict: %s[/color]" % str(item_specifics))
				if item_specifics.has(item_id_used_with):
					action_details_to_execute = item_specifics[item_id_used_with]
					interaction_possible = true
					print_rich("[color=Green]  Found item-specific action for '%s'. Details: %s[/color]" % [item_id_used_with, str(action_details_to_execute)])
				else:
					print_rich("[color=Orange]  Item_id '%s' NOT found in item_specific_actions.[/color]" % item_id_used_with)

			if not interaction_possible and use_on_target_config.has("default_item_reaction"):
				action_details_to_execute = use_on_target_config["default_item_reaction"]
				interaction_possible = true
				print_rich("[color=Green]  Using default_item_reaction. Details: %s[/color]" % str(action_details_to_execute))
			elif not interaction_possible and use_on_target_config.has("item_specific_actions"):
				print_rich("[color=Orange]  Item '%s' not specifically handled and no default_item_reaction found for USE_ON_TARGET_VERB, but item_specific_actions key exists.[/color]" % item_id_used_with)
			elif not interaction_possible:
				print_rich("[color=Orange]  No item-specific_actions key and no default_item_reaction key found under USE_ON_TARGET_VERB config.[/color]")
		else:
			print_rich("[color=Red]  Verb '%s' (USE_ON_TARGET_VERB) NOT found in verb_actions for '%s'![/color]" % [use_on_target_verb_actual, object_display_name])

		if not interaction_possible:
			var item_display_name = item_id_used_with
			if GameManager and item_id_used_with != "":
				var item_data = GameManager.get_item_data_by_id(item_id_used_with)
				if item_data: item_display_name = item_data.display_name
			var fail_text = "I can't use the %s with the %s in that particular way." % [item_display_name, object_display_name]
			display_dialogue.emit(fail_text)
			print_rich("[color=Orange]  Emitting fallback dialogue for USE_ON_TARGET_VERB (interaction not possible): %s[/color]" % fail_text)

	elif verb_id == use_item_verb_actual: # Implicit "use_item" (item selected, click on object)
		print_rich("[color=SkyBlue]Interactable '%s': Handling verb '%s' (IMPLICIT_USE_ITEM_VERB)[/color]" % [object_display_name, verb_id])
		if verb_actions.has(use_item_verb_actual):
			var use_item_actions: Dictionary = verb_actions[use_item_verb_actual]
			if item_id_used_with != "" and use_item_actions.has("item_specific_actions"):
				var item_specifics: Dictionary = use_item_actions["item_specific_actions"]
				if item_specifics.has(item_id_used_with):
					action_details_to_execute = item_specifics[item_id_used_with]
					interaction_possible = true
			if not interaction_possible and use_item_actions.has("default_item_reaction"):
				action_details_to_execute = use_item_actions["default_item_reaction"]
				interaction_possible = true

		if not interaction_possible:
			var item_display_name = item_id_used_with
			if GameManager and item_id_used_with != "":
				var item_data = GameManager.get_item_data_by_id(item_id_used_with)
				if item_data: item_display_name = item_data.display_name
			var fail_text = "I can't use the %s with the %s." % [item_display_name, object_display_name]
			display_dialogue.emit(fail_text)
			print_rich("[color=Orange]  Emitting fallback dialogue for IMPLICIT_USE_ITEM_VERB (interaction not possible): %s[/color]" % fail_text)

	else: # Handling any other direct verb (e.g., "pickup")
		print_rich("[color=SkyBlue]Interactable '%s': Handling direct verb '%s'[/color]" % [object_display_name, verb_id])
		if verb_actions.has(verb_id):
			action_details_to_execute = verb_actions[verb_id]
			interaction_possible = true
			print_rich("[color=Green]  Found action for direct verb '%s'. Details: %s[/color]" % [verb_id, str(action_details_to_execute)])
		else:
			print_rich("[color=Orange]  Direct verb '%s' NOT found in verb_actions for '%s'.[/color]" % [verb_id, object_display_name])
			var fail_text = "I can't seem to '%s' the %s." % [verb_id, object_display_name]
			if GameManager:
				var verb_data = GameManager.get_verb_data_by_id(verb_id)
				if verb_data:
					fail_text = "I can't seem to '%s' the %s." % [verb_data.display_text.to_lower(), object_display_name]
			display_dialogue.emit(fail_text)
			print_rich("[color=Orange]  Emitting fallback dialogue for direct verb: %s[/color]" % fail_text)

	if interaction_possible and not action_details_to_execute.is_empty():
		print_rich("[color=LimeGreen]Interactable '%s': About to _execute_action_details with: %s[/color]" % [object_display_name, str(action_details_to_execute)])
		_execute_action_details(action_details_to_execute, item_id_used_with if (verb_id == use_item_verb_actual or verb_id == use_on_target_verb_actual) else "")
	elif interaction_possible and action_details_to_execute.is_empty():
		print_rich("[color=Yellow]Interactable '%s': Interaction was deemed possible for verb '%s', but action_details_to_execute is EMPTY. Check verb_actions data for this verb.[/color]" % [object_display_name, verb_id])
		display_dialogue.emit("Hmm, that doesn't seem right for the %s." % object_display_name)
	elif not interaction_possible and (verb_id == use_item_verb_actual or verb_id == use_on_target_verb_actual or verb_actions.has(verb_id)):
		print_rich("[color=Yellow]Interactable '%s': Interaction NOT possible for verb '%s', and no specific fallback dialogue was triggered earlier. Action details empty. Check verb_actions config.[/color]" % [object_display_name, verb_id])
		pass

	interaction_processed.emit()
	print_rich("[color=Orchid]--- End Interactable.attempt_interaction for '%s' ---[/color]" % object_display_name)

# _execute_action_details function remains the same as your last correct version.
# ... (rest of Interactable.gd) ...

func _execute_action_details(details: Dictionary, item_context_id: String = ""):
	if not details or details.is_empty():
		print_rich("[color=yellow]Interactable '%s': _execute_action_details called with empty details.[/color]" % object_display_name)
		return

	var action_type: String = details.get("action_type", "none")

	match action_type:
		"say_line":
			var line_to_say: String = details.get("line", "Error: 'line' key not found.")
			if "%item" in line_to_say and item_context_id != "" and GameManager:
				var item_data = GameManager.get_item_data_by_id(item_context_id)
				if item_data: line_to_say = line_to_say.replace("%item", item_data.display_name)
			if "%object" in line_to_say:
				line_to_say = line_to_say.replace("%object", object_display_name)
			display_dialogue.emit(line_to_say)
		"destroy":
			var message_on_destroy: String = details.get("message", "")
			if message_on_destroy != "": display_dialogue.emit(message_on_destroy)
			self_destruct_requested.emit()
		"set_game_flag": # For global flags
			var flag_name: String = details.get("flag_name", "")
			var flag_value: bool = details.get("value", true)
			if flag_name != "": request_set_game_flag.emit(flag_name, flag_value) # GameManager handles this
			else: print_rich("[color=red]Interactable '%s': 'set_game_flag' action missing 'flag_name'.[/color]" % object_display_name)

		"request_set_level_flag": # <<<< NEW ACTION TYPE
			var flag_name: String = details.get("flag_name", "")
			var flag_value: bool = details.get("value", true)
			if flag_name != "":
				print_rich("[color=darkcyan]Interactable '%s': Emitting request_set_level_flag: %s = %s[/color]" % [object_display_name, flag_name, flag_value])
				request_set_level_flag.emit(flag_name, flag_value)
			else: print_rich("[color=red]Interactable '%s': 'request_set_level_flag' action missing 'flag_name'.[/color]" % object_display_name)

		"request_remove_item":
			var item_id_to_remove: String = details.get("item_id", "")
			if item_id_to_remove != "": request_remove_item_from_inventory.emit(item_id_to_remove)
			else: print_rich("[color=red]Interactable '%s': 'request_remove_item' action missing 'item_id'.[/color]" % object_display_name)
		"request_add_item":
			var item_id_to_add: String = details.get("item_id", "")
			if item_id_to_add != "": request_add_item_to_inventory.emit(item_id_to_add)
			else: print_rich("[color=red]Interactable '%s': 'request_add_item' action missing 'item_id'.[/color]" % object_display_name)
		"sequence":
			var steps: Array = details.get("steps", [])
			if steps.is_empty():
				print_rich("[color=yellow]Interactable '%s': 'sequence' action has no steps.[/color]" % object_display_name)
			for step_details in steps:
				if step_details is Dictionary:
					_execute_action_details(step_details, item_context_id)
				else:
					print_rich("[color=red]Interactable '%s': Invalid step in sequence: %s[/color]" % [object_display_name, str(step_details)])
		"change_sprite":
			if object_sprite and details.has("new_sprite_resource"):
				var new_tex = details.get("new_sprite_resource")
				if new_tex is Texture2D: object_sprite.texture = new_tex
				else: print_rich("[color=red]Interactable '%s': 'change_sprite' - 'new_sprite_resource' is not a Texture2D.[/color]" % object_display_name)
			else: print_rich("[color=yellow]Interactable '%s': 'change_sprite' action failed (no sprite or no resource).[/color]" % object_display_name)
		"none":
			display_dialogue.emit("I'm not sure what to do.")
		_:
			display_dialogue.emit("Hmm, action_type ('%s') isn't defined properly." % action_type)

# ... (get_walk_to_position, does_verb_require_walk - UNCHANGED from your last correct version) ...
func get_walk_to_position() -> Vector2:
	if walk_to_point: return walk_to_point.global_position
	return global_position

func does_verb_require_walk(verb_id: String, item_data_used: ItemData = null) -> bool:
	var verb_id_for_lookup = verb_id
	const USE_ITEM_VERB_CONST = "use_item"
	if verb_id == USE_ITEM_VERB_CONST:
		verb_id_for_lookup = USE_ITEM_VERB_CONST
	if verb_id_for_lookup == "examine": return false
	if verb_id_for_lookup == "talk_to" and category == ObjectCategory.CHARACTER:
		return true
	if verb_actions.has(verb_id_for_lookup):
		var action_config: Dictionary = verb_actions[verb_id_for_lookup]
		if action_config.has("requires_walk"):
			var walk_flag = action_config["requires_walk"]
			if walk_flag is bool: return walk_flag
			else: print_rich("[color=yellow]Interactable '%s': 'requires_walk' for verb '%s' is not a bool. Defaulting to true.[/color]" % [object_display_name, verb_id_for_lookup]); return true
		if verb_id_for_lookup == USE_ITEM_VERB_CONST: return true
	return true
