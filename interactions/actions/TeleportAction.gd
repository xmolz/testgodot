class_name TeleportAction
extends Action

@export var target_marker_name: String = ""

func execute(interactable_node: Interactable) -> bool:
	var player = GameManager.player_node
	var transition_layer = GameManager.transition_layer
	
	if not is_instance_valid(player):
		return false
	
	var target_node = SceneDirector.current_game_scene.find_child(target_marker_name, true, false)
	if not target_node:
		push_error("TeleportAction: Marker '%s' not found!" % target_marker_name)
		return false

	# ***************[1. lock player movement (important!)]
	# we don't want them walking away while the door close
	player.set_can_move(false)
	
	# check if we have a transition layer to use
	if is_instance_valid(transition_layer):
		# start the animation sequence
		transition_layer.play_transition_sequence()
		
		# wait here until the doors
		await transition_layer.transition_halfway
		
	# teleport logic (happens while screen is black)
	if GameManager.has_method("player_has_finished_walk_command"):
		GameManager.player_has_finished_walk_command()
	if player.has_method("stop_movement"): 
		player.stop_movement() 
	
	player.global_position = target_node.global_position
	
	var camera = interactable_node.get_viewport().get_camera_2d()
	if camera and camera.has_method("snap_to_target"):
		camera.snap_to_target()
		
	# cleanup
	# if we used the transition,
	if is_instance_valid(transition_layer):
		await transition_layer.transition_finished
	
	# unlock player
	player.set_can_move(true)
	
	return true
