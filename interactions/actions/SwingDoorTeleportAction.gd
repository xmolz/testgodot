class_name SwingDoorTeleportAction
extends Action

@export var target_marker_name: String = ""

const OPEN_TIME: float = 0.45
const OPEN_MIN_SCALE: float = 0.1
const STEP_TIME: float = 0.35
const FADE_OUT: float = 0.3
const BLACK_HOLD: float = 0.45
const FADE_IN: float = 0.45
const PLAYER_STEP_SCALE: float = 0.94
const LEAF_SHADE := Color(0.55, 0.5, 0.52, 1)

func execute(interactable_node: Interactable) -> bool:
	var player = GameManager.player_node
	var transition_layer = GameManager.transition_layer
	
	if not is_instance_valid(player):
		return false
	
	var target_node = SceneDirector.current_game_scene.find_child(target_marker_name, true, false)
	if not target_node:
		push_error("SwingDoorTeleportAction: Marker '%s' not found!" % target_marker_name)
		return false

	# 1. Lock player and face target
	player.set_can_move(false)
	player.face_target(interactable_node.global_position)

	# 2. Resolve leaf
	var leaf = interactable_node.get_node_or_null("ObjectSprite")
	if not is_instance_valid(leaf):
		push_warning("SwingDoorTeleportAction: leaf not found, falling back to fade-only.")
		# Fallback to plain TeleportAction behaviour (fade only)
		if is_instance_valid(transition_layer):
			transition_layer.play_transition_sequence()
			await transition_layer.transition_halfway
		
		if GameManager.has_method("player_has_finished_walk_command"):
			GameManager.player_has_finished_walk_command()
		if player.has_method("stop_movement"): 
			player.stop_movement()
			
		player.global_position = target_node.global_position
		
		var camera = interactable_node.get_viewport().get_camera_2d()
		if camera and camera.has_method("snap_to_target"):
			camera.snap_to_target()
			
		if is_instance_valid(transition_layer):
			await transition_layer.transition_finished
			
		if Events and Events.has_signal("room_changed"):
			Events.room_changed.emit()
			
		player.set_can_move(true)
		return true

	# Cache leaf transform and modulate
	var cached_scale = leaf.scale
	var cached_pos = leaf.position
	var cached_modulate = leaf.modulate

	# 3. Open sound and tweens
	_sfx("wood_door_unlock")
	_sfx("wood_door_open")
	
	var half_w = leaf.texture.get_width() * 0.5 * absf(cached_scale.x)
	var door_tween = interactable_node.create_tween().set_parallel(true)
	
	door_tween.tween_method(
		func(s: float):
			leaf.scale.x = cached_scale.x * s
			leaf.position.x = cached_pos.x - half_w * (1.0 - s),
		1.0,
		OPEN_MIN_SCALE,
		OPEN_TIME
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	door_tween.tween_property(leaf, "modulate", LEAF_SHADE, OPEN_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	# 4. Wait 0.1s then player steps
	await interactable_node.get_tree().create_timer(0.1).timeout
	_sfx("step_carpet_1")
	
	var player_tween = player.create_tween().set_parallel(true)
	player_tween.tween_property(player, "modulate:a", 0.0, STEP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	player_tween.tween_property(player, "scale", Vector2(PLAYER_STEP_SCALE, PLAYER_STEP_SCALE), STEP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await player_tween.finished

	# 5. Global fade to black
	if is_instance_valid(transition_layer):
		await transition_layer.global_fade_to_black(FADE_OUT)

	# 6. Under black teleport and restore
	if GameManager.has_method("player_has_finished_walk_command"):
		GameManager.player_has_finished_walk_command()
	if player.has_method("stop_movement"): 
		player.stop_movement()

	player.global_position = target_node.global_position
	
	var camera = interactable_node.get_viewport().get_camera_2d()
	if camera and camera.has_method("snap_to_target"):
		camera.snap_to_target()

	_sfx("wood_door_close")
	
	# Restore leaf and player
	leaf.scale = cached_scale
	leaf.position = cached_pos
	leaf.modulate = cached_modulate
	player.modulate.a = 1.0
	player.scale = Vector2.ONE

	# 7. Black hold and fade in
	await interactable_node.get_tree().create_timer(BLACK_HOLD).timeout
	
	if is_instance_valid(transition_layer):
		await transition_layer.global_fade_from_black(FADE_IN)

	if Events and Events.has_signal("room_changed"):
		Events.room_changed.emit()

	player.set_can_move(true)
	return true

func _sfx(sound_name: String):
	if is_instance_valid(SoundManager) and SoundManager.sfx_library.has(sound_name):
		SoundManager.play_sfx(sound_name)
