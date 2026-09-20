class_name OpenCloseupAction
extends Action
## Opens a windowed close-up (ui/closeup_panel.tscn) showing content_scene.
## Mirrors OpenKeypadPanelAction: the tree is never paused; the player is
## locked via conversation state + set_can_move(false), and closeup_panel's
## _close() restores both through GameManager.exit_to_world_state().

const CLOSEUP_PANEL_SCENE_PATH := "res://ui/closeup_panel.tscn"
const IDLE_WAIT_MAX_FRAMES := 240

@export var content_scene: PackedScene


func execute(interactable_node: Interactable) -> Variant:
	if content_scene == null:
		push_warning("OpenCloseupAction: no content_scene set on '%s'." % interactable_node.object_display_name)
		return true
	var packed_scene: PackedScene = load(CLOSEUP_PANEL_SCENE_PATH)
	if not packed_scene:
		push_error("OpenCloseupAction: could not load " + CLOSEUP_PANEL_SCENE_PATH)
		return true
	var tree := interactable_node.get_tree()
	if GameManager:
		GameManager.cancel_current_action(false)
		GameManager.persisting_verb_id = ""
		GameManager.enter_conversation_state()
		if is_instance_valid(GameManager.player_node) and GameManager.player_node.has_method("set_can_move"):
			GameManager.player_node.set_can_move(false)
	var player = GameManager.player_node if GameManager else null
	if is_instance_valid(player) and "current_animation_state" in player:
		var safety := 0
		while player.current_animation_state != "idle" and safety < IDLE_WAIT_MAX_FRAMES:
			await tree.process_frame
			safety += 1
	await tree.create_timer(0.12).timeout
	var instance := packed_scene.instantiate()
	instance.content_scene = content_scene
	tree.root.add_child(instance)
	print_rich("[color=cyan]OpenCloseupAction: opened close-up for '%s'.[/color]" % interactable_node.object_display_name)
	return false
