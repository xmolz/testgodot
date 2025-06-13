extends Area2D
class_name Interactable

signal display_dialogue(text: String) # For simple text lines from this interactable
signal self_destruct_requested # To tell itself to queue_free
signal interaction_processed # Signals that this interactable has finished its part of an interaction

# NEW Signals: Requests for GameManager to handle
signal request_remove_item_from_inventory(item_id_to_remove: String)
signal request_add_item_to_inventory(item_id_to_add: String)
signal request_set_game_flag(flag_name: String, value: bool)
# You could add more like: signal request_play_sound(sound_name: String), signal request_start_cutscene(cutscene_id: String)

enum ObjectCategory { OBJECT, CHARACTER }

@export var object_display_name: String = "Object"
@export var object_id: String = "" # Unique ID, used for dialogue titles, saving state, etc.
@export var verb_actions: Dictionary = {}
# Example verb_actions structure:
# verb_actions = {
#   "examine": { "requires_walk": false }, # GM handles dialogue
#   "push": { "action_type": "say_line", "line": "It won't budge.", "requires_walk": true },
#   "use_item": { # This is GameManager.IMPLICIT_USE_ITEM_VERB_ID
#       "requires_walk": true,
#       "item_specific_actions": {
#           "key_rusty": {
#               "action_type": "sequence",
#               "steps": [
#                   { "action_type": "say_line", "line": "The rusty key unlocks it!" },
#                   { "action_type": "set_game_flag", "flag_name": "box_unlocked", "value": true },
#                   { "action_type": "request_remove_item", "item_id": "key_rusty" }, # Renamed for clarity
#                   # { "action_type": "change_sprite", "new_sprite_resource": preload("res://open_box.png") } # Example
#                   { "action_type": "destroy" } # Example: if the box disappears after opening
#               ]
#           },
#           "crowbar": { "action_type": "say_line", "line": "The crowbar is too big for this." }
#       },
#       "default_item_reaction": { "action_type": "say_line", "line": "That doesn't seem to work here." }
#   }
# }


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

	# Shader setup (unchanged from your original)
	if object_sprite:
		if not object_sprite.material: object_sprite.material = ShaderMaterial.new()
		if object_sprite.material is ShaderMaterial:
			var existing_shader = object_sprite.material.shader
			var needs_shader = true
			if existing_shader and existing_shader.code.contains("enable_outline"): needs_shader = false
			if needs_shader:
				var shader = Shader.new(); shader.code = """shader_type canvas_item;uniform vec4 outline_color : source_color =vec4(1.0,1.0,1.0,1.0);uniform float outline_width : hint_range(0.0,10.0)=2.0;uniform bool enable_outline=false;void fragment(){vec2 uv=UV;vec4 tc=texture(TEXTURE,uv);if(enable_outline&&tc.a>0.01){float ex=outline_width/float(textureSize(TEXTURE,0).x);float ey=outline_width/float(textureSize(TEXTURE,0).y);float ma=0.0;ma=max(ma,texture(TEXTURE,uv+vec2(ex,0.0)).a);ma=max(ma,texture(TEXTURE,uv+vec2(-ex,0.0)).a);ma=max(ma,texture(TEXTURE,uv+vec2(0.0,ey)).a);ma=max(ma,texture(TEXTURE,uv+vec2(0.0,-ey)).a);ma=max(ma,texture(TEXTURE,uv+vec2(ex,ey)).a);ma=max(ma,texture(TEXTURE,uv+vec2(-ex,ey)).a);ma=max(ma,texture(TEXTURE,uv+vec2(ex,-ey)).a);ma=max(ma,texture(TEXTURE,uv+vec2(-ex,-ey)).a);if(ma>tc.a){COLOR=mix(tc,outline_color,smoothstep(0.0,1.0,ma-tc.a));COLOR.rgb=outline_color.rgb;COLOR.a=max(tc.a,outline_color.a*(ma-tc.a));}else{COLOR=tc;}}else{COLOR=tc;}}"""; object_sprite.material.shader=shader
			if object_sprite.material.get_shader_parameter("enable_outline")!=null: object_sprite.material.set_shader_parameter("enable_outline",false)
			else: print_rich("[color=yellow]Interactable '%s': Shader no 'enable_outline'.[/color]"%name)

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

func attempt_interaction(verb_id: String, item_id_used_with: String = ""):
	print("--- Interactable '%s': attempt_interaction --- Verb: '%s', ItemID: '%s'" % [object_display_name, verb_id, item_id_used_with])

	if verb_id == "examine" or verb_id == "talk_to":
		# These verbs are primarily handled by GameManager for dialogue display.
		# This Interactable might have "requires_walk" defined for them in verb_actions,
		# but the core dialogue logic is in GM.
		# We just signal that the interaction *attempt* has been processed by this node.
		interaction_processed.emit()
		print("--- End Interactable.attempt_interaction (%s handled by GM) ---" % verb_id)
		return

	var action_details_to_execute: Dictionary = {}
	var interaction_possible = false

	# Check if using an item (GameManager.IMPLICIT_USE_ITEM_VERB_ID should be "use_item")
	# If GameManager is an autoload:
	# const USE_ITEM_VERB = GameManager.IMPLICIT_USE_ITEM_VERB_ID if GameManager else "use_item"
	# If GameManager is NOT an autoload, just use the string:
	const USE_ITEM_VERB = "use_item"

	if verb_id == USE_ITEM_VERB:
		if verb_actions.has(USE_ITEM_VERB):
			var use_item_actions: Dictionary = verb_actions[USE_ITEM_VERB]
			if item_id_used_with != "" and use_item_actions.has("item_specific_actions"):
				var item_specifics: Dictionary = use_item_actions["item_specific_actions"]
				if item_specifics.has(item_id_used_with):
					action_details_to_execute = item_specifics[item_id_used_with]
					interaction_possible = true
					# print("Found item-specific action for '%s' with '%s'" % [item_id_used_with, object_display_name])

			if not interaction_possible and use_item_actions.has("default_item_reaction"):
				action_details_to_execute = use_item_actions["default_item_reaction"]
				interaction_possible = true
				# print("Using default item reaction for '%s'" % object_display_name)

		if not interaction_possible:
			# Default "can't use item X with item Y" if no specific or default reaction found
			var item_display_name = item_id_used_with
			if GameManager and item_id_used_with != "": # Try to get the proper display name
				var item_data = GameManager.get_item_data_by_id(item_id_used_with)
				if item_data: item_display_name = item_data.display_name

			var fail_text = "I can't use the %s with the %s." % [item_display_name, object_display_name]
			display_dialogue.emit(fail_text)
	else: # Handling a direct verb (not "use_item")
		if verb_actions.has(verb_id):
			action_details_to_execute = verb_actions[verb_id]
			interaction_possible = true
		else:
			# Standard "I can't verb the object"
			var fail_text = "I can't seem to '%s' the %s." % [verb_id, object_display_name]
			# Try to get verb display name if available
			if GameManager:
				var verb_data = GameManager.get_verb_data_by_id(verb_id)
				if verb_data:
					fail_text = "I can't seem to '%s' the %s." % [verb_data.display_text.to_lower(), object_display_name]
			display_dialogue.emit(fail_text)

	if interaction_possible and not action_details_to_execute.is_empty():
		_execute_action_details(action_details_to_execute, item_id_used_with if verb_id == USE_ITEM_VERB else "")

	interaction_processed.emit() # Always emit this to signal completion from interactable's side
	print("--- End Interactable.attempt_interaction ---")


func _execute_action_details(details: Dictionary, item_context_id: String = ""):
	if not details or details.is_empty():
		print_rich("[color=yellow]Interactable '%s': _execute_action_details called with empty details.[/color]" % object_display_name)
		return

	var action_type: String = details.get("action_type", "none")
	# print("Executing action_type: '%s' for '%s'. Details: %s" % [action_type, object_display_name, str(details)])

	match action_type:
		"say_line":
			var line_to_say: String = details.get("line", "Error: 'line' key not found.")
			# Basic formatting for item/object names
			if "%item" in line_to_say and item_context_id != "" and GameManager:
				var item_data = GameManager.get_item_data_by_id(item_context_id)
				if item_data: line_to_say = line_to_say.replace("%item", item_data.display_name)
			if "%object" in line_to_say:
				line_to_say = line_to_say.replace("%object", object_display_name)
			display_dialogue.emit(line_to_say)
		"destroy": # Destroys this interactable itself
			var message_on_destroy: String = details.get("message", "")
			if message_on_destroy != "": display_dialogue.emit(message_on_destroy)
			self_destruct_requested.emit()
		"set_game_flag":
			var flag_name: String = details.get("flag_name", "")
			var flag_value: bool = details.get("value", true)
			if flag_name != "": request_set_game_flag.emit(flag_name, flag_value)
			else: print_rich("[color=red]Interactable '%s': 'set_game_flag' action missing 'flag_name'.[/color]" % object_display_name)
		"request_remove_item": # Renamed from "remove_item_from_inventory" for clarity in verb_actions
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
					_execute_action_details(step_details, item_context_id) # Pass context along
				else:
					print_rich("[color=red]Interactable '%s': Invalid step in sequence: %s[/color]" % [object_display_name, str(step_details)])
		# Add more action_types here like "play_sound", "change_sprite", "enable_interactable", "disable_interactable"
		"change_sprite": # Example: very basic sprite change
			if object_sprite and details.has("new_sprite_resource"):
				var new_tex = details.get("new_sprite_resource")
				if new_tex is Texture2D:
					object_sprite.texture = new_tex
				else:
					print_rich("[color=red]Interactable '%s': 'change_sprite' - 'new_sprite_resource' is not a Texture2D.[/color]" % object_display_name)
			else:
				print_rich("[color=yellow]Interactable '%s': 'change_sprite' action failed (no sprite or no resource).[/color]" % object_display_name)

		"none":
			# This case might be hit if "action_type" is explicitly "none" or missing
			display_dialogue.emit("I'm not sure what to do.") # Generic fallback
		_:
			display_dialogue.emit("Hmm, action_type ('%s') isn't defined properly for verb '%s'." % [action_type, details.get("verb_id_source", "unknown verb")])


func get_walk_to_position() -> Vector2:
	if walk_to_point: return walk_to_point.global_position
	return global_position

# MODIFIED to accept an optional item_data argument and use verb_id from verb_actions
func does_verb_require_walk(verb_id: String, item_data_used: ItemData = null) -> bool:
	# Default verb_id for lookup in verb_actions
	var verb_id_for_lookup = verb_id

	# If GameManager is an autoload:
	# const USE_ITEM_VERB_CONST = GameManager.IMPLICIT_USE_ITEM_VERB_ID if GameManager else "use_item"
	# If GameManager is NOT an autoload, just use the string:
	const USE_ITEM_VERB_CONST = "use_item"

	if verb_id == USE_ITEM_VERB_CONST:
		verb_id_for_lookup = USE_ITEM_VERB_CONST # Ensure we look up "use_item" in verb_actions

	# Specific overrides
	if verb_id_for_lookup == "examine": return false # Examine usually doesn't require walk
	if verb_id_for_lookup == "talk_to" and category == ObjectCategory.CHARACTER:
		return true # Talking to characters usually requires walking up to them

	# Check verb_actions for the effective verb_id
	if verb_actions.has(verb_id_for_lookup):
		var action_config: Dictionary = verb_actions[verb_id_for_lookup]
		if action_config.has("requires_walk"):
			var walk_flag = action_config["requires_walk"]
			if walk_flag is bool:
				return walk_flag
			else:
				print_rich("[color=yellow]Interactable '%s': 'requires_walk' for verb '%s' is not a bool. Defaulting to true.[/color]" % [object_display_name, verb_id_for_lookup])
				return true

		# If "requires_walk" is not present for this verb_id in verb_actions, decide a default.
		# For "use_item", it's common to require a walk unless specified otherwise.
		if verb_id_for_lookup == USE_ITEM_VERB_CONST:
			# print("Interactable '%s': No 'requires_walk' for 'use_item'. Defaulting to true." % object_display_name)
			return true

	# Default for any other unconfigured verb or if verb_id_for_lookup is not in verb_actions
	# print("Interactable '%s': Verb '%s' not in verb_actions or no specific walk rule. Defaulting to true." % [object_display_name, verb_id_for_lookup])
	return true
