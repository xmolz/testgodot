extends Area2D
class_name Interactable

signal display_dialogue(text: String)
signal self_destruct_requested
signal interaction_processed

signal interaction_pending
signal interaction_started

enum ObjectCategory { OBJECT, CHARACTER }
# ************(enum to define where the interactable exists)
enum InteractionLocation { WORLD, UI_OVERLAY }

enum ApproachSide { ANY, LEFT_SIDE, RIGHT_SIDE }

@export var object_display_name: String = "Object":
	get:
		if not introduced_flag_id.is_empty() and not introduced_display_name.is_empty() and Flags.get_level_flag(introduced_flag_id):
			return introduced_display_name
		return object_display_name
## optional second name: once the level flag introduced_flag_id is true (e.g. a
## character has told the player their name), hover text and history show
## introduced_display_name instead. leave both empty to always use object_display_name.
@export var introduced_flag_id: String = ""
@export var introduced_display_name: String = ""

@export var object_id: String = ""
## step 2.203: interactables that overlap in a row (e.g. lockers) share a group name here;
## while one is hovered it is drawn above the others in that group so its whole outline shows.
@export var hover_front_group: StringName = &""
var _hover_rest_index: int = -1
@export var state_flag_id: String = ""
@export var category: ObjectCategory = ObjectCategory.OBJECT
# ------------------------(export variable for the location context)
@export var interaction_location: InteractionLocation = InteractionLocation.WORLD
@export var approach_side: ApproachSide = ApproachSide.ANY
## stop this far (horizontally) from the walk-to point for any verb instead of walking up
## close, and don't walk at all if the player is already within it. for characters, so
## conversations have room. 0 = the usual close approach.
@export var keep_distance: float = 0.0
@export var hover_prefix: String = "Walk to"
# navigation zones set this: the sentence line reads "<hover_prefix> <name>" no
# matter which verb (or item) is selected, because they route every verb to walk_to.
@export var hover_ignores_verb: bool = false

# examine plays where the player stands instead of walking over first
# (used for every object in the grad commons). other verbs are unaffected.
@export var examine_without_walking: bool = false


# ******************(the system is now the only system)
@export var interactions: Array[InteractionResponse] = [preload("res://interactions/actions/DefaultExamineResponse.tres")]

@onready var object_sprite: Sprite2D = _find_object_sprite()
@onready var walk_to_point: Marker2D = $WalkToPoint if has_node("WalkToPoint") else null
var _is_mouse_over: bool = false
var _is_force_highlighted: bool = false
var _outline_material: Material = null

@export var character_conversation_overlay_scene: PackedScene
@export var character_conversation_scene_path: String = ""
@export var object_zoom_overlay_scene: PackedScene


func _ready():
	if not state_flag_id.is_empty():
		if Flags.get_level_flag(state_flag_id):
			get_parent().queue_free()
			return

	if object_id == "":
		object_id = name + "_" + str(get_instance_id())
		print_rich("[color=yellow]Interactable: '%s' no object_id. Auto-gen: %s[/color]" % [name, object_id])
	if category == ObjectCategory.CHARACTER and character_conversation_overlay_scene == null and character_conversation_scene_path.is_empty():
		print_rich("[color=orange]Interactable '%s' (ID: %s): Category CHARACTER but no 'character_conversation_overlay_scene'![/color]" % [object_display_name, object_id])
	add_to_group("interactables")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	self_destruct_requested.connect(queue_free)

	# conversations read which side the player approached from. recorded here for every
	# CHARACTER so a new talkable NPC needs no script of its own (layla_character.gd
	# keeps its older layla_player_on_left flag alongside this one).
	if category == ObjectCategory.CHARACTER:
		interaction_started.connect(_record_player_side)

	# save the material and remove it to save gpu power
	var sprite = _find_object_sprite()
	if sprite and sprite.material:
		_outline_material = sprite.material
		sprite.material = null
	# *****************[auto-inject universal flash verb]
	var has_flash_assigned = false
	for response in interactions:
		if response and response.verb_id == "flash":
			has_flash_assigned = true
			break
			
	if not has_flash_assigned:
		var flash_response = InteractionResponse.new()
		flash_response.verb_id = "flash"
		flash_response.requires_walk = true
		
		var universal_flash = UniversalFlashAction.new()
		flash_response.actions_to_perform.append(universal_flash)
		
		interactions.append(flash_response)
	#

func _on_mouse_entered():
	if GameManager:
		if interaction_location == InteractionLocation.WORLD and GameManager.current_interaction_state != GameManager.InteractionState.WORLD:
			return
		if interaction_location == InteractionLocation.UI_OVERLAY and GameManager.current_interaction_state != GameManager.InteractionState.ZOOM_VIEW:
			return

	_is_mouse_over = true
	_bring_to_front_of_group()
	if GameManager: GameManager.set_hovered_object(self)

	if not OS.has_feature("mobile"):
		if has_node("HoverGlow"):
			get_node("HoverGlow").visible = true

		var sprite = _find_object_sprite()
		if sprite and _outline_material:
			sprite.material = _outline_material
			sprite.material.set_shader_parameter("enable_outline", true)

func _on_mouse_exited():
	_is_mouse_over = false
	_restore_group_order()
	if GameManager: GameManager.clear_hovered_object(self)
	if not OS.has_feature("mobile"):
		if has_node("HoverGlow"): get_node("HoverGlow").visible = false
		var sprite = _find_object_sprite()
		if sprite and not _is_force_highlighted:
			sprite.material = null

func force_highlight(active: bool):
	_is_force_highlighted = active
	var sprite = _find_object_sprite()

	if active:
		if has_node("HoverGlow"): get_node("HoverGlow").visible = true
		if sprite and _outline_material:
			sprite.material = _outline_material
			sprite.material.set_shader_parameter("enable_outline", true)
	else:
		if not _is_mouse_over or OS.has_feature("mobile"):
			if has_node("HoverGlow"): get_node("HoverGlow").visible = false
			if sprite: sprite.material = null

		if not _is_mouse_over:
			if GameManager: GameManager.clear_hovered_object(self)

func _on_input_event(_v: Viewport, event: InputEvent, _sidx: int):
	if GameManager:
		if interaction_location == InteractionLocation.WORLD and GameManager.current_interaction_state != GameManager.InteractionState.WORLD:
			return
		if interaction_location == InteractionLocation.UI_OVERLAY and GameManager.current_interaction_state != GameManager.InteractionState.ZOOM_VIEW:
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if GameManager: GameManager.process_interaction_click(self)

# ********************(fully refactored core logic)
func attempt_interaction(verb_id: String, item_id_used_with: String = ""):
	interaction_started.emit()
	print_rich("[color=Orchid]--- Interactable '%s': attempt_interaction --- Verb: '%s', ItemID: '%s'[/color]" % [object_display_name, verb_id, item_id_used_with])

	for i in range(interactions.size()):
		var response = interactions[i]

		if not response or response.verb_id.is_empty():
			continue

		var verb_matches: bool = (response.verb_id == verb_id)
		var item_matches: bool = (response.required_item_id == item_id_used_with)

		var flag_matches: bool = true
		if not response.required_flag_id.is_empty():
			if GameManager:
				flag_matches = (Flags.get_level_flag(response.required_flag_id) == response.required_flag_value)
			else:
				flag_matches = false

		if verb_matches and item_matches and flag_matches:
			# ///////////////////// check: ensure the match actually has actions
			var has_valid_actions = false
			for action in response.actions_to_perform:
				if action != null:
					has_valid_actions = true
					break

			if not has_valid_actions:
				print_rich("[color=yellow]Match found for '%s', but actions_to_perform is empty. Skipping to fallback.[/color]" % verb_id)
				continue
			# ****************** end check

			print_rich("[color=LimeGreen]Match found at index %s for Verb '%s' and Item '%s'.[/color]" % [i, verb_id, item_id_used_with])

			for action in response.actions_to_perform:
				if action:
					var should_continue = await action.execute(self)

					# if the action explicitly returns
					# this prevents gamemanager from resetting
					if typeof(should_continue) == TYPE_BOOL and should_continue == false:
						return

			interaction_processed.emit()
			return

	# ////////////(fallback logic (if no match found above))
	
	if GameManager:
		# use the original verb_id for
		var verb_data = Verbs.get_verb_data_by_id(verb_id)
		if is_instance_valid(verb_data) and is_instance_valid(verb_data.fallback_dialogue_file):
			print_rich("[color=Goldenrod]No match found. Calling FallbackManager.[/color]")
			if FallbackManager:
				FallbackManager.trigger_fallback(verb_data, self.object_id, item_id_used_with)
			return

	# final safety net if no fallback is configured
	print_rich("[color=Red]No interaction response and no fallback file found for verb '%s'.[/color]" % verb_id)
	display_dialogue.emit("I can't seem to do that.")
	interaction_processed.emit()

func get_walk_to_position() -> Vector2:
	if walk_to_point: return walk_to_point.global_position
	return get_parent().global_position

# ****************(corrected version of this function)
# this function provides simple, reliable
func does_verb_require_walk(verb_id_to_check: String, item_data_used: ItemData = null) -> bool:
	# "walk to" always requires walking.
	if verb_id_to_check == "walk_to":
		return true
	if examine_without_walking and verb_id_to_check == "examine":
		return false

	# determine the item id we are checking against
	var item_id_checking = ""
	if item_data_used:
		item_id_checking = item_data_used.item_id

	# search through the interactions array
	# we use the exact same
	for response in interactions:
		if not response: continue

		# check basic matche
		var verb_matches: bool = (response.verb_id == verb_id_to_check)
		var item_matches: bool = (response.required_item_id == item_id_checking)

		# check flag matches (logic matching attempt_interaction)
		var flag_matches: bool = true
		if not response.required_flag_id.is_empty():
			# if a flag id is specified, we must check it.
			flag_matches = (Flags.get_level_flag(response.required_flag_id) == response.required_flag_value)

		# if we found the valid
		if verb_matches and item_matches and flag_matches:
			# return the custom setting from the inspector
			return response.requires_walk

	# fallback defaults if no specific
	# if the specific interaction isn't
	
	if verb_id_to_check == "examine":
		return false
		
	if verb_id_to_check == "talk_to" and category == ObjectCategory.CHARACTER:
		return true

	# default safety net: if we
	return true


func _record_player_side() -> void:
	if GameManager and is_instance_valid(GameManager.player_node):
		Flags.set_level_flag("conversation_player_on_left", GameManager.player_node.global_position.x < global_position.x)

func notify_interaction_pending():
	interaction_pending.emit()

func _find_object_sprite() -> Sprite2D:
	# check children of the area2d
	if has_node("ObjectSprite"):
		return $ObjectSprite as Sprite2D
	if has_node("Sprite"):
		return $Sprite as Sprite2D
		
	# check siblings (children of the parent)
	var p = get_parent()
	if p:
		if p.has_node("ObjectSprite"):
			return p.get_node("ObjectSprite") as Sprite2D
		if p.has_node("Sprite"):
			return p.get_node("Sprite") as Sprite2D
			
	return null


# step 2.203: hover ordering for hover_front_group (see the export above).
func _bring_to_front_of_group():
	if hover_front_group == &"" or _hover_rest_index >= 0:
		return
	var p := get_parent()
	if p == null:
		return
	_hover_rest_index = get_index()
	var top := _hover_rest_index
	for s in p.get_children():
		if s is Interactable and s.hover_front_group == hover_front_group:
			top = maxi(top, s.get_index())
	if top != _hover_rest_index:
		p.move_child(self, top)


func _restore_group_order():
	if _hover_rest_index < 0:
		return
	var p := get_parent()
	if p and _hover_rest_index < p.get_child_count():
		p.move_child(self, _hover_rest_index)
	_hover_rest_index = -1
