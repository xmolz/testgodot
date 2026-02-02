class_name TriggerCutsceneAction
extends Action

# The name of the Node in the scene tree that holds the cutscene script.
# Example: "ToiletClogCutscene"
@export var cutscene_node_name: String = ""

func execute(interactable_node: Interactable) -> bool:
	if cutscene_node_name == "":
		push_warning("TriggerCutsceneAction: No cutscene_node_name specified.")
		return true

	# We need to find the node. We assume it's in the current main scene.
	var root = interactable_node.get_tree().current_scene
	
	# Search for the node by name (recursive = true)
	var cutscene_node = root.find_child(cutscene_node_name, true, false)
	
	if cutscene_node and cutscene_node.has_method("start_cutscene"):
		# We DO NOT await this. 
		# Why? Because the Cutscene handles its own state (locking input/UI).
		# If we awaited here, the Interactable system would wait for the cutscene 
		# to end before marking the interaction as "complete". 
		# But the Cutscene switches GameState, which might conflict with Interactable cleanup.
		# It is cleaner to fire-and-forget here, letting the Cutscene take full control.
		cutscene_node.start_cutscene()
	else:
		push_error("TriggerCutsceneAction: Could not find Cutscene Node named '%s' (or it lacks start_cutscene method)." % cutscene_node_name)
		
	return true
