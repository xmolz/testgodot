class_name SlideWipeTeleportAction
extends Action

## Edge-exit teleport with the directional slide wipe. Same contract as
## TeleportAction (lock -> transition -> teleport at halfway -> unlock), but the
## wipe sweeps in the direction of travel: it reads arrow_direction off the exit
## sign that fired it (+1 = the room to the right, -1 = the room to the left).
## Anything without arrow_direction wipes rightward. If the transition layer has
## no play_slide_wipe (older build), it degrades to the shutters.

@export var target_marker_name: String = ""

func execute(interactable_node: Interactable) -> bool:
	var player = GameManager.player_node
	var transition_layer = GameManager.transition_layer

	if not is_instance_valid(player):
		return false

	var target_node = SceneDirector.current_game_scene.find_child(target_marker_name, true, false)
	if not target_node:
		push_error("SlideWipeTeleportAction: Marker '%s' not found!" % target_marker_name)
		return false

	# direction comes from the exit sign, never from this resource: two signs with
	# opposite arrows share one teleport resource (see Resource_tp_bathroom).
	var direction: int = 1
	if is_instance_valid(interactable_node) and "arrow_direction" in interactable_node:
		direction = -1 if int(interactable_node.arrow_direction) < 0 else 1

	# 1. lock the player so they can't wander during the wipe
	player.set_can_move(false)

	var has_layer: bool = is_instance_valid(transition_layer)
	if has_layer and transition_layer.has_method("play_slide_wipe"):
		transition_layer.play_slide_wipe(direction)
		await transition_layer.transition_halfway
	elif has_layer:
		transition_layer.play_transition_sequence()
		await transition_layer.transition_halfway

	# 2. teleport while the screen is covered
	if GameManager.has_method("player_has_finished_walk_command"):
		GameManager.player_has_finished_walk_command()
	if player.has_method("stop_movement"):
		player.stop_movement()

	player.global_position = target_node.global_position

	var camera = interactable_node.get_viewport().get_camera_2d()
	if camera and camera.has_method("snap_to_target"):
		camera.snap_to_target()

	# 3. wait for the reveal, then hand the room over
	if has_layer:
		await transition_layer.transition_finished

	if Events and Events.has_signal("room_changed"):
		Events.room_changed.emit()

	player.set_can_move(true)
	return true
