class_name TriggerCutsceneAction
extends Action

# the name of the node
# example: "toiletclogcutscene"
@export var cutscene_node_name: String = ""

func execute(interactable_node: Interactable) -> Variant:
	if cutscene_node_name == "":
		push_warning("TriggerCutsceneAction: No cutscene_node_name specified.")
		return true

	# ***************[the fix]
	# because we load the game
	# to the boot scene. we
	var root_node = null
	if GameManager and is_instance_valid(SceneDirector.current_game_scene):
		root_node = SceneDirector.current_game_scene
	else:
		root_node = interactable_node.get_tree().current_scene
		
	if not root_node:
		push_error("TriggerCutsceneAction: Could not find a valid root scene to search.")
		return true

	# search for the node by name (recursive = true)
	var cutscene_node = root_node.find_child(cutscene_node_name, true, false)
	
	if cutscene_node and cutscene_node.has_method("start_cutscene"):
		# we do not await this
		# and hand full control over
		cutscene_node.start_cutscene()
	else:
		push_error("TriggerCutsceneAction: Could not find Cutscene Node named '%s' (or it lacks start_cutscene method)." % cutscene_node_name)
		
	return true
