class_name UniversalFlashAction
extends Action

const FLASH_DIALOGUE_PATH = "res://dialogue/flash_dialogue.dialogue"

func execute(interactable_node: Interactable) -> Variant:
	var obj_id = interactable_node.object_id
	var player = GameManager.player_node

	var flash_dialogue = load(FLASH_DIALOGUE_PATH)
	if not flash_dialogue:
		push_error("UniversalFlashAction: Could not load flash_dialogue.dialogue!")
		return true

	# 1. Check Unflashables (Plays dialogue, skips animation, ends interaction)
	var unflashable_id = obj_id + "_unflashable"
	if flash_dialogue.titles.has(unflashable_id):
		DialogueManager.show_dialogue_balloon_scene("res://conversationballoon.tscn", flash_dialogue, unflashable_id)
		await DialogueManager.dialogue_ended
		return true

	# Reset the abort flag before starting
	Flags.set_game_flag("abort_flash", false)

	# 2. Check Pre-Flash (Plays dialogue, then continues to animation)
	var pre_id = obj_id + "_pre"
	if flash_dialogue.titles.has(pre_id):
		DialogueManager.show_dialogue_balloon_scene("res://conversationballoon.tscn", flash_dialogue, pre_id)
		await DialogueManager.dialogue_ended

	# Check if the dialogue requested the flash to be aborted
	if Flags.get_game_flag("abort_flash") == true:
		Flags.set_game_flag("abort_flash", false)
		return true

	# 3. Perform Flash Animation
	if is_instance_valid(player):
		if player.has_method("face_target"):
			player.face_target(interactable_node.global_position)

		if player.has_method("set_animation_state"):
			player.set_animation_state("flash")

		# if SoundManager: SoundManager.play_sfx("flashlight_click")

		var anim_duration: float = 1.0
		var anim_player = player.get_node_or_null("AnimationPlayer")
		if anim_player and anim_player.has_animation("flash"):
			anim_duration = anim_player.get_animation("flash").length

		await interactable_node.get_tree().create_timer(anim_duration).timeout

		if player.has_method("set_animation_state"):
			player.set_animation_state("idle")

	# 4. Check Post-Flash (Plays specific post-flash, or defaults to generic)
	var post_id = obj_id + "_post"
	if not flash_dialogue.titles.has(post_id):
		post_id = "default_post"

	if flash_dialogue.titles.has(post_id):
		DialogueManager.show_dialogue_balloon_scene("res://conversationballoon.tscn", flash_dialogue, post_id)
		await DialogueManager.dialogue_ended

	return true
