class_name TeleportAction
extends Action

@export var target_marker_name: String = ""

func execute(interactable_node: Interactable) -> bool:
	var player = GameManager.player_node
	var transition_layer = GameManager.transition_layer # Grab the layer
	
	if not is_instance_valid(player):
		return false
	
	var target_node = GameManager.main_game_scene_instance.find_child(target_marker_name, true, false)
	if not target_node:
		push_error("TeleportAction: Marker '%s' not found!" % target_marker_name)
		return false

	# 1. Lock Player Movement (Important!)
	# We don't want them walking away while the door closes
	player.set_can_move(false) # Or whatever function locks your player input
	
	# 2. Check if we have a transition layer to use
	if is_instance_valid(transition_layer):
		# Start the animation sequence
		transition_layer.play_transition_sequence()
		
		# WAIT here until the doors are fully closed (black screen)
		await transition_layer.transition_halfway
		
	# 3. Teleport Logic (Happens while screen is black)
	if GameManager.has_method("player_has_finished_walk_command"):
		GameManager.player_has_finished_walk_command()
	if player.has_method("stop_movement"): 
		player.stop_movement() 
	
	player.global_position = target_node.global_position
	
	var camera = interactable_node.get_viewport().get_camera_2d()
	if camera and camera.has_method("snap_to_target"):
		camera.snap_to_target()
		
	# 4. Cleanup
	# If we used the transition, we wait for it to finish opening
	if is_instance_valid(transition_layer):
		await transition_layer.transition_finished
	
	# Unlock player
	player.set_can_move(true)
	
	return true
