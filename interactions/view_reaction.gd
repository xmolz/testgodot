extends Node
## step 2.197: plays a one-off dialogue a moment after a view opens, when a related view was
## seen first. Add as a child of a close-up content scene or a zoom overlay.
## Opening this view always sets seen_flag. If other_seen_flag is already true and
## reaction_done_flag is not, the reaction plays once and reaction_done_flag is set.
## All flags are level flags.

const BALLOON_SCENE_PATH := "res://conversation/conversationballoon.tscn"

@export var seen_flag: String = ""
@export var other_seen_flag: String = ""
@export var reaction_done_flag: String = ""
@export var dialogue_resource: DialogueResource
@export var dialogue_title: String = ""
## seconds to wait after the view opens, so its fade-in finishes first
@export var delay: float = 0.45


func _ready() -> void:
	var should_play := false
	if not other_seen_flag.is_empty() and not reaction_done_flag.is_empty():
		should_play = Flags.get_level_flag(other_seen_flag) and not Flags.get_level_flag(reaction_done_flag)
	if not seen_flag.is_empty():
		Flags.set_level_flag(seen_flag, true)
	if not should_play or dialogue_resource == null or dialogue_title.is_empty():
		return
	Flags.set_level_flag(reaction_done_flag, true)
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	# zoom views pause the tree, so the balloon must keep running (same as ui/insurance_form.gd).
	var balloon = DialogueManager.show_dialogue_balloon_scene(BALLOON_SCENE_PATH, dialogue_resource, dialogue_title)
	if is_instance_valid(balloon):
		balloon.process_mode = Node.PROCESS_MODE_ALWAYS
