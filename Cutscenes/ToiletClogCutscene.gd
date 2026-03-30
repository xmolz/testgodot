extends Cutscene

# --- REFERENCES ---
@export_group("Actors")
@export var aida_npc: CharacterBody2D
@export var player: CharacterBody2D

@export_group("Objects")
@export var toilet_interactable: Interactable 

@export_group("Locations")
@export var main_room_door_pos: Marker2D 
@export var player_spawn_pos: Marker2D 
@export var bathroom_entry_pos: Marker2D 
@export var toilet_fix_pos: Marker2D 
@export var main_room_return_pos: Marker2D

@export_group("Dialogue")
@export var aida_scold_dialogue: DialogueResource
@export var scold_dialogue_start_id: String = "AIda" # Updated to match your inspector
# --- NEW: Added the player's checkpoint ID here ---
@export var player_monologue_start_id: String = "Player" 

@export_group("Settings")
@export var fix_duration: float = 25.0 

func _execution_steps():
	print_rich("[color=magenta][Time: %s] Cutscene START.[/color]" % Time.get_ticks_msec())
	
	# --- STEP 0: PRE-SETUP ---
	GameManager.set_current_level_flag("aida_fixing_toilet", true)
	
	var aida_mover = aida_npc.get_node_or_null("MovementController")
	if aida_mover: aida_mover.pause_movement()
	
	# Teleport Aida to waiting spot
	aida_npc.global_position = main_room_door_pos.global_position
	aida_npc.visible = true 
	
	# Face Aida
	var target_x = 0.0
	if player_spawn_pos: target_x = player_spawn_pos.global_position.x
	elif player: target_x = player.global_position.x
	if target_x < aida_npc.global_position.x:
		if aida_npc.has_node("Sprite"): aida_npc.get_node("Sprite").flip_h = true
	else:
		if aida_npc.has_node("Sprite"): aida_npc.get_node("Sprite").flip_h = false

	# Wait for fade-in
	await get_tree().create_timer(1.0).timeout

	# Face Player
	if player and player.has_method("face_target"):
		player.face_target(aida_npc.global_position)

	# --- STEP 1: AIDA DIALOGUE ---
	if aida_scold_dialogue:
		DialogueManager.show_dialogue_balloon_scene("res://conversationballoon.tscn", aida_scold_dialogue, scold_dialogue_start_id)
		await DialogueManager.dialogue_ended
	
	# --- STEP 2: ENTER BATHROOM ---
	if SoundManager: 
		SoundManager.play_sfx("door_open")
	
	await get_tree().create_timer(0.2).timeout # Wait a split second to hear the door open
	aida_npc.visible = false 
	
	if SoundManager: 
		SoundManager.play_sfx("door_close")
		
	await get_tree().create_timer(0.3).timeout # Finish the original 0.5 second pause
	
	# --- NEW STEP 2.5: PLAYER MONOLOGUE ---
	# Right after Aida disappears and we wait half a second, the player talks.
	if aida_scold_dialogue and not player_monologue_start_id.is_empty():
		DialogueManager.show_dialogue_balloon_scene("res://conversationballoon.tscn", aida_scold_dialogue, player_monologue_start_id)
		await DialogueManager.dialogue_ended
	
	# Move Aida to her actual working position
	aida_npc.global_position = bathroom_entry_pos.global_position
	aida_npc.visible = true
	
	# EARLY RELEASE (Player regains control here, while Aida works in the background)
	print_rich("[color=magenta][Time: %s] Releasing Player Control.[/color]" % Time.get_ticks_msec())
	GameManager.change_game_state(GameManager.GameState.IN_GAME_PLAY)
	
	# --- BACKGROUND LOGIC ---
	
	# --- STEP 3: WALK TO TOILET ---
	if aida_mover:
		await aida_mover.move_to_position_async(toilet_fix_pos.global_position, 5.0, 10.0)
	
	# --- STEP 4: PLAY FIX ANIMATION ---
	var anim_player = aida_npc.get_node_or_null("AnimationPlayer")
	if anim_player and anim_player.has_animation("fix_toilet"):
		anim_player.play("fix_toilet")
		await get_tree().create_timer(fix_duration).timeout
		anim_player.play("idle")
	else:
		await get_tree().create_timer(5.0).timeout
	
	# --- STEP 5: UNCLOG TOILET ---
	if toilet_interactable:
		GameManager.set_current_level_flag("toilet_clogged", false)
		GameManager.set_current_level_flag("toilet_has_paper", false)
		
		var toilet_root = toilet_interactable.get_parent()
		if toilet_root and toilet_root.has_method("change_state"):
			toilet_root.change_state(0) 
	
	# --- STEP 6: LEAVE BATHROOM ---
	if aida_mover:
		await aida_mover.move_to_position_async(bathroom_entry_pos.global_position)
	
	aida_npc.visible = false
	await get_tree().create_timer(0.5).timeout
	
	# Teleport to Main Room Return Pos
	aida_npc.global_position = main_room_return_pos.global_position
	aida_npc.visible = true
	
	# ### MOVED FLAG RESET HERE ###
	GameManager.set_current_level_flag("aida_fixing_toilet", false)
	# ---------------------------
	
	# --- STEP 7: RETURN TO PATROL ---
	print_rich("[color=magenta][Time: %s] Aida returning to desk...[/color]" % Time.get_ticks_msec())
	
	if aida_mover:
		if aida_mover.has_method("set_target_waypoint_index"):
			aida_mover.set_target_waypoint_index(0)
			
		aida_mover.resume_movement()
		
	# Reset Busy Flag
	GameManager.set_current_level_flag("aida_fixing_toilet", false)
	
	print_rich("[color=magenta][Time: %s] Cutscene Script Complete.[/color]" % Time.get_ticks_msec())
