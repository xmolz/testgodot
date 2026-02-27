extends CanvasLayer
class_name CharacterConversationOverlay

signal conversation_finished(dialogue_resource: DialogueResource)

# --- EXPORT VARIABLES ---
@export var conversation_dialogue_file: DialogueResource
@export var background_animations: SpriteFrames
@export var initial_animation_name: String = "float_loop"
@export var scene_character_sprite_texture: Texture2D
# Assign your grayscale_material.tres here in Inspector
@export var mental_image_shader: ShaderMaterial

# --- NEW AUDIO EXPORT ---
@export_group("Audio")
## Assign a name (Key) and an AudioStream (Value) to play in dialogue.
@export var music_tracks: Dictionary[String, AudioStream]

# --- NODE REFERENCES ---
@onready var root_container: Control = $RootContainer
@onready var animated_background: TextureRect = $RootContainer/AnimatedBackground
@onready var character_main_sprite: Sprite2D = $RootContainer/CharacterMainSprite
@onready var background_sprite: Sprite2D = $RootContainer/BackgroundSprite
@onready var mental_image_sprite: Sprite2D = $RootContainer/MentalImageSprite

# --- CINEMATIC NODES ---
# Ensure these exist in your scene inside RootContainer
@onready var cinematic_bg: ColorRect = $RootContainer/CinematicBackground
@onready var cinematic_sprite: AnimatedSprite2D = $RootContainer/CinematicSprite
# [NEW] The button for manual cinematic advancement
@onready var continue_button: Button = $RootContainer/CinematicContinueButton 
@onready var fade_overlay: ColorRect = $RootContainer/FadeOverlay

# --- TWEEN VARIABLES ---
var _background_tween: Tween
var _mental_image_tween: Tween

# --- NEW AUDIO VARIABLE ---
var _music_player: AudioStreamPlayer

# --- SHAKE VARIABLES ---
var _is_shaking: bool = false
var _shake_timer: float = 0.0
var _shake_strength: float = 10.0
var _shake_rng := RandomNumberGenerator.new()
var _is_persistent_shake: bool = false
var _ignore_next_got_dialogue_signal: bool = false

# --- ANIMATION VARIABLES ---
var _current_anim_name: String = ""
var _current_frame_index: int = 0
var _time_since_last_frame: float = 0.0
var _is_playing: bool = false

# --- CINEMATIC STATE ---
# Accessed by the Balloon script to block input
var is_cinematic_lock_active: bool = false
# [NEW] Holds the reference to the active dialogue balloon
var current_balloon: Node = null


func _ready():
	# --- NEW AUDIO SETUP ---
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Slow Music" # Routes it to your Music bus!
	add_child(_music_player)
	# 1. Setup Character Sprite
	if character_main_sprite:
		if scene_character_sprite_texture:
			character_main_sprite.texture = scene_character_sprite_texture
			character_main_sprite.visible = true
		else:
			character_main_sprite.visible = false
	else:
		print_rich("[color=orange]CharacterConversationOverlay: 'CharacterMainSprite' node not found.[/color]")

	# 2. Setup Cinematic Nodes (Hide by default)
	if cinematic_bg: cinematic_bg.hide()
	if cinematic_sprite: cinematic_sprite.hide()
	
	# [NEW] Setup Continue Button
	if continue_button:
		continue_button.hide()
		if not continue_button.pressed.is_connected(_on_cinematic_continue_pressed):
			continue_button.pressed.connect(_on_cinematic_continue_pressed)
	else:
		print_rich("[color=orange]Warning: 'CinematicContinueButton' not found in RootContainer.[/color]")

	# 3. Connect Dialogue Manager Signals
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended_from_manager)
	DialogueManager.got_dialogue.connect(_on_got_dialogue)
	_shake_rng.randomize()

	# 4. Start Background Animation
	if background_animations:
		play_animation(initial_animation_name)
	else:
		print_rich("[color=red]No 'background_animations' (SpriteFrames) assigned![/color]")

	# Ensure mental image sprite is hidden at start
	mental_image_sprite.visible = false

	# 5. Launch Dialogue Balloon & CAPTURE IT
	if conversation_dialogue_file:
		# [UPDATED] We capture the return value into 'current_balloon'
		current_balloon = DialogueManager.show_dialogue_balloon_scene(
			"res://conversationballoon.tscn",
			conversation_dialogue_file,
			"start",
			[self] # Pass 'self' as extra_game_state so balloon can find us
		)
	else:
		print_rich("[color=red]No 'conversation_dialogue_file' assigned![/color]")
		conversation_finished.emit(null)
		_cleanup_and_queue_free()

	if background_sprite:
		# Force the background to align to the top-left corner on startup
		background_sprite.centered = false 
		background_sprite.position = Vector2.ZERO
	if fade_overlay:
		fade_overlay.color = Color.BLACK
		fade_overlay.modulate.a = 0.0 # Start transparent
		fade_overlay.show() # Keep it "visible" but transparent so we can tween it

func _process(delta: float):
	# --- Shake Logic ---
	if _is_shaking:
		if not _is_persistent_shake:
			_shake_timer -= delta
			if _shake_timer <= 0:
				_is_shaking = false
				root_container.position = Vector2.ZERO

		if _is_shaking:
			var offset_x = _shake_rng.randf_range(-_shake_strength, _shake_strength)
			var offset_y = _shake_rng.randf_range(-_shake_strength, _shake_strength)
			root_container.position = Vector2(offset_x, offset_y)

	# --- Animation Logic ---
	if not _is_playing or not background_animations:
		return

	var anim_speed = background_animations.get_animation_speed(_current_anim_name)
	if anim_speed == 0: return

	var frame_count = background_animations.get_frame_count(_current_anim_name)
	var does_loop = background_animations.get_animation_loop(_current_anim_name)
	var time_per_frame = 1.0 / anim_speed
	_time_since_last_frame += delta
	if _time_since_last_frame >= time_per_frame:
		_time_since_last_frame -= time_per_frame
		_current_frame_index += 1
		if _current_frame_index >= frame_count:
			if does_loop: _current_frame_index = 0
			else:
				_current_frame_index = frame_count - 1
				_is_playing = false
		update_frame()


# ---------------------------------------------------------
# NEW: CINEMATIC FUNCTIONS (With Transitions)
# ---------------------------------------------------------

# Arguments:
# 1. animation_name: Name of animation in SpriteFrames
# 2. hide_balloon: If true, hides the text box
# 3. force_one_loop: If true, locks input until loop finishes (not used if using Continue Button)
# 4. transition_effect: "none", "dissolve", or "fade"
func play_cinematic(animation_name: String = "default", hide_balloon: bool = true, force_one_loop: bool = false, transition_effect: String = "none"):
	
	# 1. Setup Initial Visibility based on Effect
	if transition_effect == "dissolve" or transition_effect == "fade":
		# Start invisible so we can fade in
		if cinematic_bg: 
			cinematic_bg.modulate.a = 0.0
			cinematic_bg.show()
		if cinematic_sprite: 
			cinematic_sprite.modulate.a = 0.0
			cinematic_sprite.show()
			cinematic_sprite.play(animation_name)
		
		# Create the Fade-In Tween
		var tween = create_tween().set_parallel(true)
		if cinematic_bg:
			tween.tween_property(cinematic_bg, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
		if cinematic_sprite:
			tween.tween_property(cinematic_sprite, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
			
	else:
		# INSTANT (Default)
		if cinematic_bg: 
			cinematic_bg.modulate.a = 1.0 # Ensure fully visible
			cinematic_bg.show()
		if cinematic_sprite: 
			cinematic_sprite.modulate.a = 1.0 # Ensure fully visible
			cinematic_sprite.show()
			cinematic_sprite.play(animation_name)
	
	# 2. Lock Input (Prevent Spacebar skipping)
	is_cinematic_lock_active = true
	
	# 3. Handle UI Visibility
	if hide_balloon and current_balloon:
		current_balloon.hide() 
	
	if continue_button:
		# If fading in, maybe delay the button slightly? 
		# For now, let's just show it.
		continue_button.show()

# Called when the on-screen "Continue" button is clicked
func _on_cinematic_continue_pressed():
	# 1. Release Lock
	is_cinematic_lock_active = false
	
	# 2. Hide The Button
	if continue_button:
		continue_button.hide()
	
	# 3. SHOW THE BALLOON (This is the key!)
	if current_balloon:
		current_balloon.show() 
		
		# 4. Advance Dialogue Manually
		# This jumps over the "..." line in your dialogue file
		if current_balloon.has_method("next") and current_balloon.dialogue_line:
			current_balloon.next(current_balloon.dialogue_line.next_id)
		else:
			# Fallback
			stop_cinematic()

# Called via dialogue: do ConversationOverlay.stop_cinematic()
# Called via dialogue: do stop_cinematic("dissolve")
func stop_cinematic(transition_effect: String = "none"):
	
	is_cinematic_lock_active = false
	if continue_button: continue_button.hide()
	
	# 1. Handle the Visual Exit
	if transition_effect == "dissolve" or transition_effect == "fade":
		var tween = create_tween().set_parallel(true)
		
		# Fade out
		if cinematic_bg:
			tween.tween_property(cinematic_bg, "modulate:a", 0.0, 0.5)
		if cinematic_sprite:
			tween.tween_property(cinematic_sprite, "modulate:a", 0.0, 0.5)
		
		# Wait for tween to finish before actually hiding logic
		await tween.finished
		
		if cinematic_bg: cinematic_bg.hide()
		if cinematic_sprite: 
			cinematic_sprite.stop()
			cinematic_sprite.hide()
			
	else:
		# INSTANT
		if cinematic_bg: cinematic_bg.hide()
		if cinematic_sprite: 
			cinematic_sprite.stop()
			cinematic_sprite.hide()
	
	# 2. Restore Balloon Visibility
	if current_balloon:
		current_balloon.show()
	
	# 3. Restore Standard Visuals
	if background_sprite: background_sprite.show()
	if character_main_sprite: character_main_sprite.show()
	if animated_background: animated_background.show()
# ---------------------------------------------------------


# --- MENTAL IMAGE FUNCTIONS ---
# Added 'start_scale' parameter at the end (defaults to 1.0)
func start_mental_image(texture_path: String, fade_duration: float = 0.5, tint: Color = Color.WHITE, final_opacity: float = 0.6, start_scale: float = 1.0):
	# 1. Setup Grayscale Shader
	if mental_image_shader:
		root_container.material = mental_image_shader
		root_container.material.set_shader_parameter("strength", 0.0)

	# 2. Setup Ghost Sprite
	var new_texture = load(texture_path)
	if new_texture is Texture2D:
		mental_image_sprite.texture = new_texture

		# Reset Visuals
		var start_modulate = tint
		start_modulate.a = 0.0
		mental_image_sprite.modulate = start_modulate

		# Set Initial Scale
		var initial_vec = Vector2(start_scale, start_scale)
		mental_image_sprite.scale = initial_vec
		mental_image_sprite.visible = true

		# 3. Handle Tweening
		if _mental_image_tween:
			_mental_image_tween.kill()

		_mental_image_tween = create_tween().set_parallel(true)

		# A: Fade in Opacity
		_mental_image_tween.tween_property(mental_image_sprite, "modulate:a", final_opacity, fade_duration)\
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

		# B: Fade in Shader
		if mental_image_shader:
			_mental_image_tween.tween_property(root_container.material, "shader_parameter/strength", 1.0, fade_duration)\
				.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

		# C: The "Infinite" Slow Zoom
		var zoom_amount = 0.5
		var target_scale_vec = Vector2(start_scale + zoom_amount, start_scale + zoom_amount)

		_mental_image_tween.tween_property(mental_image_sprite, "scale", target_scale_vec, 100.0)\
			.set_trans(Tween.TRANS_LINEAR)

		print_rich("[color=lightblue]Starting mental image (Infinite Zoom).[/color]")
	else:
		print_rich("[color=red]Mental Image Error: Failed to load texture at path: " + texture_path + "[/color]")

func stop_mental_image(fade_duration: float = 0.5):
	# 1. Kill any running fade-ins
	if _mental_image_tween:
		_mental_image_tween.kill()

	# 2. Create fade-out tween
	_mental_image_tween = create_tween().set_parallel(true)

	# A: Fade out the Ghost Sprite
	_mental_image_tween.tween_property(mental_image_sprite, "modulate:a", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)

	# B: Fade out the Grayscale Shader
	if root_container.material:
		_mental_image_tween.tween_property(root_container.material, "shader_parameter/strength", 0.0, fade_duration)\
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)

	# 3. Wait for animation to finish
	await _mental_image_tween.finished

	# 4. Cleanup
	mental_image_sprite.visible = false
	root_container.material = null # Remove the shader entirely
	print_rich("[color=lightblue]Mental image fade-out complete.[/color]")


# --- BACKGROUND ZOOM FUNCTIONS ---

# Call this to start the slow zoom on the background.
func start_background_zoom(zoom_amount: float = 0.2, duration: float = 40.0):
	if not background_sprite: return

	# 1. Reset scale to 1.0 (Normal) so it starts fresh
	background_sprite.scale = Vector2.ONE

	# 2. Kill any existing background animation
	if _background_tween:
		_background_tween.kill()

	# 3. Create the tween
	_background_tween = create_tween()

	# 4. Calculate target (Current 1.0 + Amount)
	var target_scale = Vector2(1.0 + zoom_amount, 1.0 + zoom_amount)

	# 5. Animate linearly (steady speed)
	_background_tween.tween_property(background_sprite, "scale", target_scale, duration)\
		.set_trans(Tween.TRANS_LINEAR)

	print_rich("[color=lightblue]Started background zoom.[/color]")


# Call this to smoothly return the background to normal size.
func stop_background_zoom(reset_duration: float = 0.5):
	if not background_sprite: return

	if _background_tween:
		_background_tween.kill()

	_background_tween = create_tween()

	# Tween back to Vector2.ONE (1.0, 1.0)
	_background_tween.tween_property(background_sprite, "scale", Vector2.ONE, reset_duration)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	print_rich("[color=lightblue]Resetting background zoom.[/color]")


# --- GENERAL HELPER FUNCTIONS ---

func _on_got_dialogue(_line: DialogueLine):
	if _ignore_next_got_dialogue_signal:
		_ignore_next_got_dialogue_signal = false
		return
	if _is_persistent_shake:
		_is_shaking = false
		_is_persistent_shake = false
		root_container.position = Vector2.ZERO

func shake(duration: float = 0.4, strength: float = 10.0):
	_shake_strength = strength
	_is_shaking = true
	if duration < 0:
		_is_persistent_shake = true
		_ignore_next_got_dialogue_signal = true
	else:
		_is_persistent_shake = false
		_ignore_next_got_dialogue_signal = false
		_shake_timer = duration

func play_animation(anim_name: String):
	if not background_animations.has_animation(anim_name):
		return
	_current_anim_name = anim_name
	_current_frame_index = 0
	_time_since_last_frame = 0.0
	_is_playing = true
	update_frame()

func update_frame():
	if animated_background and background_animations.has_animation(_current_anim_name):
		var texture = background_animations.get_frame_texture(_current_anim_name, _current_frame_index)
		animated_background.texture = texture

func change_background_animation(animation_name: String):
	play_animation(animation_name)


# --- BACKGROUND SWITCHING LOGIC ---
func change_background_sprite(texture_path: String, effect: String = ""):
	if not background_sprite: return

	# Handle empty path (hide background)
	if texture_path.is_empty():
		background_sprite.visible = false
		return

	var new_texture = load(texture_path)
	if not (new_texture is Texture2D):
		print_rich("[color=red]Error: Could not load texture at: %s[/color]" % texture_path)
		return

	# --- CASE 1: NO EFFECT (Standard Switch) ---
	if effect == "" or effect == "none":
		background_sprite.texture = new_texture
		background_sprite.visible = true
		background_sprite.position = Vector2.ZERO
		return

	# --- CASE 2: DISSOLVE TRANSITION (Cross-fade) ---
	if effect == "dissolve":
		# 1. Create a "Ghost" of the OLD image
		var temp_old_sprite = background_sprite.duplicate()
		root_container.add_child(temp_old_sprite)
		root_container.move_child(temp_old_sprite, background_sprite.get_index() + 1)

		# 2. Ensure Ghost has the old texture and properties
		temp_old_sprite.texture = background_sprite.texture
		temp_old_sprite.position = background_sprite.position
		temp_old_sprite.scale = background_sprite.scale

		# 3. Set the MAIN sprite to the NEW image immediately
		background_sprite.texture = new_texture
		background_sprite.visible = true

		# 4. Tween the Ghost's Opacity to 0
		var fade_duration = 0.5 
		var dissolve_tween = create_tween()
		dissolve_tween.tween_property(temp_old_sprite, "modulate:a", 0.0, fade_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# 5. Cleanup the ghost
		dissolve_tween.tween_callback(temp_old_sprite.queue_free)
		return

	# --- CASE 3: SLIDE TRANSITIONS (Whip Pan) ---

	# 1. Play Sound
	if SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx("swish", 1.0, -5.0)

	# 2. Create Dummy Sprite for the old image
	var temp_old_sprite = background_sprite.duplicate()
	root_container.add_child(temp_old_sprite)
	root_container.move_child(temp_old_sprite, background_sprite.get_index()) # Put BEHIND/Same layer

	temp_old_sprite.texture = background_sprite.texture
	temp_old_sprite.position = Vector2.ZERO
	temp_old_sprite.scale = background_sprite.scale

	# 3. Setup New Sprite
	background_sprite.texture = new_texture
	background_sprite.visible = true

	# 4. Calculate Positions
	var screen_width = get_viewport().get_visible_rect().size.x
	var duration = 0.35

	var new_sprite_start_pos = Vector2.ZERO
	var old_sprite_end_pos = Vector2.ZERO

	if effect == "slide_left":
		new_sprite_start_pos = Vector2(-screen_width, 0)
		old_sprite_end_pos = Vector2(screen_width, 0)

	elif effect == "slide_right":
		new_sprite_start_pos = Vector2(screen_width, 0)
		old_sprite_end_pos = Vector2(-screen_width, 0)

	# 5. Apply positions
	background_sprite.position = new_sprite_start_pos

	# 6. Animate
	var slide_tween = create_tween().set_parallel(true)

	slide_tween.tween_property(background_sprite, "position", Vector2.ZERO, duration)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	slide_tween.tween_property(temp_old_sprite, "position", old_sprite_end_pos, duration)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	# 7. Cleanup
	slide_tween.chain().tween_callback(temp_old_sprite.queue_free)


func _on_dialogue_ended_from_manager(resource: DialogueResource):
	if resource == conversation_dialogue_file:
		conversation_finished.emit(resource)
		_cleanup_and_queue_free()

func _cleanup_and_queue_free():
	if DialogueManager.is_connected("dialogue_ended", _on_dialogue_ended_from_manager):
		DialogueManager.disconnect("dialogue_ended", _on_dialogue_ended_from_manager)
	if DialogueManager.is_connected("got_dialogue", _on_got_dialogue):
		DialogueManager.disconnect("got_dialogue", _on_got_dialogue)
	queue_free()


# NEW FUNCTION: Play a sequence of images with a dissolve effect
func play_dissolve_sequence(image_paths: Array, hold_duration: float = 2.0, fade_duration: float = 1.0):
	if not background_sprite: return

	# Loop through every image path provided in the list
	for i in range(image_paths.size()):
		var texture_path = image_paths[i]
		var new_texture = load(texture_path)

		if not (new_texture is Texture2D):
			print_rich("[color=red]Error loading: %s[/color]" % texture_path)
			continue # Skip this bad image and try the next

		# --- STEP 1: If this is the FIRST image and screen is empty, just show it ---
		if i == 0 and not background_sprite.visible:
			background_sprite.texture = new_texture
			background_sprite.visible = true
			background_sprite.modulate.a = 0.0 # Start invisible

			# Simple fade in for the first image
			var tween = create_tween()
			tween.tween_property(background_sprite, "modulate:a", 1.0, fade_duration)
			await tween.finished

		# --- STEP 2: If we are transitioning from an existing image ---
		else:
			# 1. Create a "Ghost" of the current image
			var temp_old_sprite = background_sprite.duplicate()
			root_container.add_child(temp_old_sprite)
			root_container.move_child(temp_old_sprite, background_sprite.get_index() + 1) # Put ON TOP

			# 2. Setup the "Ghost" properties
			temp_old_sprite.texture = background_sprite.texture
			temp_old_sprite.position = background_sprite.position
			temp_old_sprite.centered = background_sprite.centered
			temp_old_sprite.scale = background_sprite.scale

			# 3. Set the REAL sprite to the NEW image underneath
			background_sprite.texture = new_texture
			background_sprite.visible = true

			# 4. Tween the GHOST to transparent (revealing the new one)
			var tween = create_tween()
			tween.tween_property(temp_old_sprite, "modulate:a", 0.0, fade_duration)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

			# 5. Wait for fade to finish
			await tween.finished
			temp_old_sprite.queue_free() # Delete the ghost

		# --- STEP 3: Wait for the "Hold" time before showing the next one ---
		# We don't wait after the very last image
		if i < image_paths.size() - 1:
			await get_tree().create_timer(hold_duration).timeout
			
# ---------------------------------------------------------
# NEW: FADE FUNCTIONS
# ---------------------------------------------------------

# Called via dialogue: do fade_to_black(1.0)
func fade_to_black(duration: float = 1.0):
	print("--- DEBUG: fade_to_black called! Duration: ", duration, " ---")
	
	if not fade_overlay:
		print("--- ERROR: fade_overlay node is MISSING! Check your Scene Tree. ---")
		return
	
	# 1. Force it to be visible
	fade_overlay.visible = true
	
	# 2. Force it to be on top of EVERYTHING (The Nuclear Option)
	fade_overlay.z_index = 100 
	# If using CanvasLayer, make sure this node is last, or use z_index
	
	# 3. Ensure color is black
	fade_overlay.color = Color.BLACK
	
	# 4. Run the Tween
	print("--- DEBUG: Starting Tween... ---")
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	print("--- DEBUG: Fade complete. ---")
	
# Called via dialogue: do fade_from_black(1.0)
func fade_from_black(duration: float = 1.0):
	if not fade_overlay: return
	
	# Create a tween to fade alpha from Current -> 0.0 (Transparent)
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished

# Instant reset if needed
func clear_fade():
	if fade_overlay:
		fade_overlay.modulate.a = 0.0
		
# ---------------------------------------------------------
# SHOCK SWITCH FUNCTION
# ---------------------------------------------------------

# Called via dialogue: do shock_switch_background("res://face_shock.png", 20.0, Color.WHITE)
# 1. texture_path: The image to switch TO (The realization/shock face)
# 2. shake_power: How hard to shake (20-30 is good for shocks)
# 3. flash_color: Color.WHITE (flashbang) or Color.RED (pain/danger) or Color.TRANSPARENT (just shake)
func shock_switch_background(texture_path: String, shake_power: float = 25.0, flash_color: Color = Color.WHITE):
	# 1. Start the Violence (Shake)
	# We shake for 0.5 seconds so it settles after the switch
	shake(0.5, shake_power)
	
	# 2. The Flash (Masks the transition)
	if fade_overlay:
		# A. Instant Flash ON
		fade_overlay.color = flash_color
		fade_overlay.modulate.a = 0.8 # Not fully opaque, so we see the shake underneath
		fade_overlay.show()
		
		# B. Swap the Sprite BEHIND the flash
		# We use a tiny delay so the swap happens exactly when the flash is brightest
		var timer = get_tree().create_timer(0.05)
		await timer.timeout
		change_background_sprite(texture_path, "none")
		
		# C. Fast Fade Out (The Reveal)
		var tween = create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		# Fallback if no overlay exists
		change_background_sprite(texture_path, "none")

# ---------------------------------------------------------

# ---------------------------------------------------------
# REVEAL SHOCK FUNCTION
# Use this when the screen is ALREADY black and you want to 
# suddenly reveal an image with a flash/shake.
# ---------------------------------------------------------
func reveal_shock_from_black(texture_path: String, shake_power: float = 25.0):
	# 1. Change the sprite BEHIND the darkness
	change_background_sprite(texture_path, "none")
	
	# 2. Start the violence (Shake)
	shake(0.5, shake_power)
	
	if fade_overlay:
		# 3. THE FLASHBANG EFFECT
		# Instantly turn the Black screen into a White Flash
		fade_overlay.color = Color.WHITE
		fade_overlay.modulate.a = 1.0 
		
		# 4. Fade the White Flash away quickly (0.2s) to reveal the image
		var tween = create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		# Fallback if no overlay
		pass
# ---------------------------------------------------------
# NEW: AUDIO FUNCTIONS (Called from .dialogue)
# ---------------------------------------------------------

# Called via dialogue: do play_music("track_name", 1.5)
func play_music(track_name: String, fade_duration: float = 1.0):
	if not music_tracks.has(track_name):
		print_rich("[color=red]ConversationOverlay: Track '%s' not found in inspector list![/color]" % track_name)
		return
		
	var stream = music_tracks[track_name]
	
	# Don't restart the track if it's already playing
	if _music_player.stream == stream and _music_player.playing:
		return
		
	_music_player.stream = stream
	
	if fade_duration > 0.0:
		_music_player.volume_db = -80.0
		_music_player.play()
		var tween = create_tween()
		# Fades up to 0.0 dB (normal volume)
		tween.tween_property(_music_player, "volume_db", 0.0, fade_duration).set_trans(Tween.TRANS_SINE)
	else:
		_music_player.volume_db = 0.0
		_music_player.play()

# Called via dialogue: do stop_music(1.5)
func stop_music(fade_duration: float = 1.0):
	if fade_duration > 0.0:
		var tween = create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(_music_player.stop)
	else:
		_music_player.stop()

func _exit_tree():
	_cleanup_and_queue_free()
