class_name PlayerFlashAction
extends Action

@export var sound_effect: String = ""

func execute(interactable_node: Interactable) -> Variant:
	var player = GameManager.player_node

	if is_instance_valid(player):
		if player.has_method("set_can_move"):
			player.set_can_move(false)

		if player.has_method("face_target"):
			player.face_target(interactable_node.global_position)

		if player.has_method("set_animation_state"):
			player.set_animation_state("flash")

		if sound_effect != "" and SoundManager:
			SoundManager.play_sfx(sound_effect)

		var anim_duration: float = 1.0
		var anim_player = player.get_node_or_null("AnimationPlayer")
		if anim_player and anim_player.has_animation("flash"):
			anim_duration = anim_player.get_animation("flash").length

		await interactable_node.get_tree().create_timer(anim_duration).timeout

		if player.has_method("set_animation_state"):
			player.set_animation_state("idle")

	if is_instance_valid(player) and player.has_method("set_can_move"):
		if GameManager.current_interaction_state == GameManager.InteractionState.WORLD and GameManager.current_game_state == GameManager.GameState.IN_GAME_PLAY:
			player.set_can_move(true)

	return true
