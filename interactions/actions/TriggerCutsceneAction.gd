class_name TriggerCutsceneAction
extends Action

# The name of the Node in the scene tree that holds the cutscene script.
# Example: "ToiletClogCutscene"
@export var cutscene_node_name: String = ""

func execute(interactable_node: Interactable) -> Variant:
	if cutscene_node_name == "":
		push_warning("TriggerCutsceneAction: No cutscene_node_name specified.")
		return true

	# --- THE FIX ---
	# Because we load the game dynamically now, get_tree().current_scene might point 
	# to the Boot scene. We must explicitly search the GameManager's main scene instance!
	var root_node = null
	if GameManager and is_instance_valid(GameManager.main_game_scene_instance):
		root_node = GameManager.main_game_scene_instance
	else:
		root_node = interactable_node.get_tree().current_scene
		
	if not root_node:
		push_error("TriggerCutsceneAction: Could not find a valid root scene to search.")
		return true

	# Search for the node by name (recursive = true)
	var cutscene_node = root_node.find_child(cutscene_node_name, true, false)
	
	if cutscene_node and cutscene_node.has_method("start_cutscene"):
		# We DO NOT await this so the interactable system can finish 
		# and hand full control over to the Cutscene state machine.
		cutscene_node.start_cutscene()
	else:
		push_error("TriggerCutsceneAction: Could not find Cutscene Node named '%s' (or it lacks start_cutscene method)." % cutscene_node_name)
		
	return true
