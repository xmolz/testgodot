class_name OpenKeypadPanelAction
extends Action

const KEYPAD_PANEL_SCENE_PATH := "res://ui/keypad_panel.tscn"
const IDLE_WAIT_MAX_FRAMES := 240

func execute(interactable_node: Interactable) -> Variant:
	var packed_scene: PackedScene = load(KEYPAD_PANEL_SCENE_PATH)
	if not packed_scene:
		push_error("OpenKeypadPanelAction: could not load " + KEYPAD_PANEL_SCENE_PATH)
		return true

	var tree := interactable_node.get_tree()

	if GameManager:
		GameManager.cancel_current_action(false)
		GameManager.persisting_verb_id = ""
		GameManager.enter_conversation_state()
		# enter_conversation_state() does not lock movement in chapters (no
		# game_ui.gd here - known parked issue), and movement is POLLED in
		# player._physics_process (keyboard axis + mouse-hold), so the
		# panel's Dim cannot swallow it. Lock it explicitly, mirroring
		# enter_zoom_view_state(). keypad_panel._close() calls
		# exit_to_world_state(), which re-enables it.
		if is_instance_valid(GameManager.player_node) and GameManager.player_node.has_method("set_can_move"):
			GameManager.player_node.set_can_move(false)

	# DELIBERATE DELTA vs OpenElevatorPanelAction: the keypad does NOT freeze
	# the tree. Dialogue balloons (CanvasLayer 100) must be able to play OVER
	# the open keypad (CanvasLayer 50) in a later phase - e.g. Layla reacting
	# to a wrong code - and a frozen tree would freeze the balloon too. World
	# clicks are swallowed by the panel's full-screen Dim; polled movement is
	# blocked by the set_can_move(false) lock above.
	# We still wait for the player to settle into idle so the panel never
	# pops mid-stride (the lock forces idle within a frame or two).
	var player = GameManager.player_node if GameManager else null
	if is_instance_valid(player) and "current_animation_state" in player:
		var safety := 0
		while player.current_animation_state != "idle" and safety < IDLE_WAIT_MAX_FRAMES:
			await tree.process_frame
			safety += 1
	await tree.create_timer(0.12).timeout

	var instance := packed_scene.instantiate()
	tree.root.add_child(instance)

	print_rich("[color=cyan]OpenKeypadPanelAction: opened keypad panel.[/color]")
	return false
