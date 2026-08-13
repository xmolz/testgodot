class_name OpenElevatorPanelAction
extends Action

const ELEVATOR_PANEL_SCENE_PATH := "res://ui/elevator_panel.tscn"
const IDLE_WAIT_MAX_FRAMES := 240

func execute(interactable_node: Interactable) -> Variant:
	var packed_scene: PackedScene = load(ELEVATOR_PANEL_SCENE_PATH)
	if not packed_scene:
		push_error("OpenElevatorPanelAction: could not load " + ELEVATOR_PANEL_SCENE_PATH)
		return true

	var tree := interactable_node.get_tree()

	if GameManager:
		GameManager.cancel_current_action(false)
		GameManager.persisting_verb_id = ""
		GameManager.enter_conversation_state()

	# The world is input-locked now (conversation state). Before freezing the
	# tree, wait for the player to settle into idle so the pause never
	# catches the walk cycle mid-stride.
	var player = GameManager.player_node if GameManager else null
	if is_instance_valid(player) and "current_animation_state" in player:
		var safety := 0
		while player.current_animation_state != "idle" and safety < IDLE_WAIT_MAX_FRAMES:
			await tree.process_frame
			safety += 1
	await tree.create_timer(0.12).timeout

	var instance := packed_scene.instantiate()
	tree.root.add_child(instance)
	tree.paused = true

	print_rich("[color=cyan]OpenElevatorPanelAction: opened elevator panel.[/color]")
	return false
