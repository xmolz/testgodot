extends CanvasLayer

signal conversation_finished(dialogue_resource: DialogueResource)

@export var dialogue_resource: DialogueResource
@export var start_dialogue_id: String = "start"
@export var character_roster: Array[CharacterProfile] = []
@export var background_aliases: Dictionary = {} # String -> Texture2D
@export var cg_aliases: Dictionary = {} # String -> Texture2D
@export var mental_image_shader: ShaderMaterial

var active_actors: Dictionary = {}

var _scan_active: bool = false
var _scan_time: float = 0.0
var _scan_tween: Tween

# --- SHAKE VARIABLES ---
var _is_shaking: bool = false
var _shake_timer: float = 0.0
var _shake_strength: float = 10.0
var _shake_rng := RandomNumberGenerator.new()
var _is_persistent_shake: bool = false
var _ignore_next_got_dialogue_signal: bool = false

@onready var actor_stage: Control = $ActorStage
@onready var darken_backdrop: ColorRect = $DarkenBackdrop
@onready var background_layer: TextureRect = $BackgroundLayer
@onready var cg_layer: TextureRect = $CGLayer
@onready var mental_image_layer: TextureRect = $MentalImageLayer
var _mental_image_tween: Tween


func _ready():
	DialogueManager.show_dialogue_balloon_scene(
		load("res://conversationballoon.tscn"),
		dialogue_resource,
		start_dialogue_id,
		[self]
	)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.got_dialogue.connect(_on_got_dialogue)
	_shake_rng.randomize()


func _process(delta: float):
	if _scan_active:
		_scan_time += delta
		# Creates a smooth, undulating figure-8 "wavy" movement instead of a violent shake
		var offset_x = sin(_scan_time * 4.0) * 4.0
		var offset_y = cos(_scan_time * 3.0) * 4.0
		cg_layer.position = Vector2(offset_x, offset_y)

	# --- Shake Logic ---
	if _is_shaking:
		if not _is_persistent_shake:
			_shake_timer -= delta
			if _shake_timer <= 0:
				_is_shaking = false
				offset = Vector2.ZERO # Reset CanvasLayer offset

		if _is_shaking:
			var offset_x = _shake_rng.randf_range(-_shake_strength, _shake_strength)
			var offset_y = _shake_rng.randf_range(-_shake_strength, _shake_strength)
			offset = Vector2(offset_x, offset_y) # Shake the entire CanvasLayer


func _on_dialogue_ended(_resource: DialogueResource):
	DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)
	if DialogueManager.got_dialogue.is_connected(_on_got_dialogue):
		DialogueManager.got_dialogue.disconnect(_on_got_dialogue)

	# Notify the GameManager that the conversation is over so it restores UI and Player movement
	conversation_finished.emit(dialogue_resource)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(darken_backdrop, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(background_layer, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(actor_stage, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(cg_layer, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(mental_image_layer, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(queue_free)


func get_profile(id: String) -> CharacterProfile:
	for profile in character_roster:
		if profile.actor_id == id:
			return profile
	return null


func actor_enter(actor_id: String, emotion: String, slot_name: String):
	var profile = get_profile(actor_id)
	if not profile:
		push_warning("Actor profile not found: " + actor_id)
		return

	var tex = profile.expressions.get(emotion)
	if not tex:
		push_warning("Emotion '" + emotion + "' not found for actor: " + actor_id)
		return

	var rect = TextureRect.new()
	rect.texture = tex

	# 1. Calculate the Dynamic Scale safely using floats
	var screen_height = float(get_viewport().get_visible_rect().size.y)
	var tex_size = tex.get_size()

	# Base scale makes the image exactly as tall as the screen
	var base_scale = screen_height / float(tex_size.y)
	var final_scale = base_scale * profile.default_scale

	rect.scale = Vector2(final_scale, final_scale)

	# 2. Set the pivot to the bottom-center of the UNSCALED image
	rect.pivot_offset = Vector2(tex_size.x / 2.0, tex_size.y)

	actor_stage.add_child(rect)
	active_actors[actor_id] = rect

	# 3. Find the target marker
	var marker_name = "Slot" + slot_name.capitalize()
	var marker = actor_stage.get_node_or_null(marker_name)
	if not marker:
		push_warning("Could not find slot marker: " + marker_name)
		marker = actor_stage.get_node("SlotCenter")

	# 4. Position the Rect so its pivot sits exactly on the marker
	# Since position is unscaled in Godot, we just subtract the raw pivot_offset
	var target_pos = marker.position - rect.pivot_offset

	# 5. Animation setup (Start 200 pixels lower and transparent)
	rect.position = Vector2(target_pos.x, target_pos.y + 200.0)
	rect.modulate.a = 0.0

	var tween = create_tween().set_parallel(true)
	tween.tween_property(rect, "position:y", target_pos.y, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func actor_leave(actor_id: String) -> void:
	if not active_actors.has(actor_id):
		push_warning("AdvancedConversationOverlay: Actor '%s' not found." % actor_id)
		return

	var rect: TextureRect = active_actors[actor_id]
	active_actors.erase(actor_id)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(rect, "position:y", rect.position.y + 200.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(rect, "modulate:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(rect.queue_free)


func actor_change(actor_id: String, emotion: String) -> void:
	if not active_actors.has(actor_id):
		return

	var profile = get_profile(actor_id)
	if not profile:
		return

	var tex = profile.expressions.get(emotion)
	if tex:
		var rect: TextureRect = active_actors[actor_id]
		rect.texture = tex


func actor_effect(actor_id: String, effect_name: String) -> void:
	if not active_actors.has(actor_id):
		push_warning("AdvancedConversationOverlay: Actor '%s' not found." % actor_id)
		return

	var rect: TextureRect = active_actors[actor_id]

	if effect_name == "shock":
		var original_x = rect.position.x
		var base_s = rect.scale
		var peak_s = base_s * 1.05 # Scale up by 5% relatively

		var tween = create_tween()
		tween.tween_property(rect, "scale", peak_s, 0.05)
		tween.tween_property(rect, "position:x", original_x + 15.0, 0.025)
		tween.tween_property(rect, "position:x", original_x - 15.0, 0.05)
		tween.tween_property(rect, "position:x", original_x + 10.0, 0.025)
		tween.tween_property(rect, "position:x", original_x - 10.0, 0.025)
		tween.tween_property(rect, "position:x", original_x, 0.025)
		tween.tween_property(rect, "scale", base_s, 0.05)


func actor_walk_in(actor_id: String, emotion: String, slot_name: String, scale_modifier: float = 1.0):
	var profile = get_profile(actor_id)
	if not profile:
		push_warning("Actor profile not found: " + actor_id)
		return

	var tex = profile.expressions.get(emotion)
	if not tex:
		push_warning("Emotion '" + emotion + "' not found for actor: " + actor_id)
		return

	var rect = TextureRect.new()
	rect.texture = tex

	var screen_height = float(get_viewport().get_visible_rect().size.y)
	var tex_size = tex.get_size()
	var base_scale = screen_height / float(tex_size.y)
	var final_scale = base_scale * profile.default_scale * scale_modifier

	rect.scale = Vector2(final_scale, final_scale)
	rect.pivot_offset = Vector2(tex_size.x / 2.0, tex_size.y)

	actor_stage.add_child(rect)
	active_actors[actor_id] = rect

	var marker_name = "Slot" + slot_name.capitalize()
	var marker = actor_stage.get_node_or_null(marker_name)
	if not marker:
		push_warning("Could not find slot marker: " + marker_name)
		marker = actor_stage.get_node("SlotCenter")

	var target_pos = marker.position - rect.pivot_offset

	# Determine starting X position based on slot
	var start_x = target_pos.x
	if slot_name.to_lower() == "left":
		start_x = target_pos.x - 1500.0 # Start far off-screen left
	elif slot_name.to_lower() == "right":
		start_x = target_pos.x + 1500.0 # Start far off-screen right
	else:
		start_x = target_pos.x - 1500.0 # Default slide from left

	rect.position = Vector2(start_x, target_pos.y)
	rect.modulate.a = 1.0 # Fully visible, just off-screen

	var tween = create_tween()
	tween.tween_property(rect, "position:x", target_pos.x, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func actor_walk_out(actor_id: String, direction: String = "left"):
	if not active_actors.has(actor_id):
		return

	var rect: TextureRect = active_actors[actor_id]
	active_actors.erase(actor_id)

	var target_x = rect.position.x
	if direction.to_lower() == "right":
		target_x += 1500.0
	else:
		target_x -= 1500.0

	var tween = create_tween()
	tween.tween_property(rect, "position:x", target_x, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(rect.queue_free)


func actor_move(actor_id: String, target_slot_name: String, duration: float = 0.5):
	if not active_actors.has(actor_id):
		push_warning("Cannot move actor, not found on stage: " + actor_id)
		return

	var rect: TextureRect = active_actors[actor_id]

	# Find the new target marker
	var marker_name = "Slot" + target_slot_name.capitalize()
	var marker = actor_stage.get_node_or_null(marker_name)
	if not marker:
		push_warning("Could not find slot marker: " + marker_name)
		return

	# Calculate the exact target position (matching the math in actor_enter)
	var target_pos = marker.position - rect.pivot_offset

	# Create a smooth tween to slide them over
	var tween = create_tween()
	tween.tween_property(rect, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func actor_flip(actor_id: String, is_flipped: bool = true):
	if not active_actors.has(actor_id):
		push_warning("Cannot flip actor, not found on stage: " + actor_id)
		return

	var rect: TextureRect = active_actors[actor_id]
	var current_scale = rect.scale

	# To flip a TextureRect, we make the X scale negative.
	# We use abs() to ensure we don't accidentally flip it twice if called repeatedly.
	if is_flipped:
		rect.scale = Vector2(-abs(current_scale.x), current_scale.y)
	else:
		rect.scale = Vector2(abs(current_scale.x), current_scale.y)


func actor_dash_in(actor_id: String, emotion: String, slot_name: String, scale_modifier: float = 1.0):
	var profile = get_profile(actor_id)
	if not profile:
		push_warning("Actor profile not found: " + actor_id)
		return

	var tex = profile.expressions.get(emotion)
	if not tex:
		push_warning("Emotion '" + emotion + "' not found for actor: " + actor_id)
		return

	var rect = TextureRect.new()
	rect.texture = tex

	var screen_height = float(get_viewport().get_visible_rect().size.y)
	var tex_size = tex.get_size()
	var base_scale = screen_height / float(tex_size.y)
	var final_scale = base_scale * profile.default_scale * scale_modifier

	rect.scale = Vector2(final_scale, final_scale)
	rect.pivot_offset = Vector2(tex_size.x / 2.0, tex_size.y)

	actor_stage.add_child(rect)
	active_actors[actor_id] = rect

	var marker_name = "Slot" + slot_name.capitalize()
	var marker = actor_stage.get_node_or_null(marker_name)
	if not marker:
		marker = actor_stage.get_node("SlotCenter")

	var target_pos = marker.position - rect.pivot_offset

	var start_x = target_pos.x
	if slot_name.to_lower() == "left":
		start_x = target_pos.x - 1500.0
	elif slot_name.to_lower() == "right":
		start_x = target_pos.x + 1500.0
	else:
		start_x = target_pos.x - 1500.0

	rect.position = Vector2(start_x, target_pos.y)
	rect.modulate.a = 1.0

	var tween = create_tween()
	# TRANS_BACK creates the "overshoot and settle" spring effect.
	# A shorter duration (0.4s) makes it feel fast and energetic.
	tween.tween_property(rect, "position:x", target_pos.x, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func change_background(bg_name: String, transition: String = "fade", duration: float = 0.5):
	if bg_name.is_empty():
		background_layer.texture = null
		return

	var new_texture: Texture2D = null

	# Check if it's an alias first, otherwise try loading it as a raw path (fallback)
	if background_aliases.has(bg_name):
		new_texture = background_aliases[bg_name]
	elif ResourceLoader.exists(bg_name):
		new_texture = load(bg_name)

	if not new_texture:
		push_warning("Could not find background alias or path: " + bg_name)
		return

	if transition in ["slide_left", "slide_right"] and background_layer.texture != null:
		if SoundManager and SoundManager.has_method("play_sfx"):
			SoundManager.play_sfx("swish", 1.0, -5.0)

		var ghost = TextureRect.new()
		ghost.texture = background_layer.texture
		ghost.expand_mode = background_layer.expand_mode
		ghost.stretch_mode = background_layer.stretch_mode
		# Temporarily use Top-Left so the layout engine doesn't fight the position tween
		ghost.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		ghost.size = background_layer.size
		ghost.position = background_layer.position
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE

		background_layer.get_parent().add_child(ghost)
		background_layer.get_parent().move_child(ghost, background_layer.get_index())

		background_layer.texture = new_texture
		background_layer.modulate.a = 1.0

		background_layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		background_layer.size = get_viewport().get_visible_rect().size

		var screen_width = background_layer.size.x
		var new_start_x = 0.0
		var old_end_x = 0.0

		if transition == "slide_left":
			new_start_x = -screen_width
			old_end_x = screen_width
		elif transition == "slide_right":
			new_start_x = screen_width
			old_end_x = -screen_width

		background_layer.position.x = new_start_x

		var tween = create_tween().set_parallel(true)
		tween.tween_property(background_layer, "position:x", 0.0, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost, "position:x", old_end_x, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

		tween.chain().tween_callback(ghost.queue_free)
		tween.tween_callback(func():
			if is_instance_valid(background_layer):
				background_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		)

	elif transition == "fade" and background_layer.texture != null and background_layer.modulate.a > 0.0:
		var ghost = TextureRect.new()
		ghost.texture = background_layer.texture
		ghost.expand_mode = background_layer.expand_mode
		ghost.stretch_mode = background_layer.stretch_mode
		ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE

		background_layer.get_parent().add_child(ghost)
		background_layer.get_parent().move_child(ghost, background_layer.get_index() + 1)

		background_layer.texture = new_texture
		background_layer.modulate.a = 1.0

		var tween = create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(ghost.queue_free)
	else:
		background_layer.texture = new_texture
		background_layer.position = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(background_layer, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func actor_show(actor_id: String, emotion: String, slot_name: String):
	var profile = get_profile(actor_id)
	if not profile:
		push_warning("Actor profile not found: " + actor_id)
		return

	var tex = profile.expressions.get(emotion)
	if not tex:
		push_warning("Emotion '" + emotion + "' not found for actor: " + actor_id)
		return

	var rect = TextureRect.new()
	rect.texture = tex

	var screen_height = float(get_viewport().get_visible_rect().size.y)
	var tex_size = tex.get_size()
	var base_scale = screen_height / float(tex_size.y)
	var final_scale = base_scale * profile.default_scale

	rect.scale = Vector2(final_scale, final_scale)
	rect.pivot_offset = Vector2(tex_size.x / 2.0, tex_size.y)

	actor_stage.add_child(rect)
	active_actors[actor_id] = rect

	var marker_name = "Slot" + slot_name.capitalize()
	var marker = actor_stage.get_node_or_null(marker_name)
	if not marker:
		marker = actor_stage.get_node("SlotCenter")

	rect.position = marker.position - rect.pivot_offset
	rect.modulate.a = 1.0


func actor_hide(actor_id: String) -> void:
	if not active_actors.has(actor_id):
		return
	var rect: TextureRect = active_actors[actor_id]
	active_actors.erase(actor_id)
	rect.queue_free()


func show_cg(cg_name: String, transition: String = "fade", duration: float = 0.5):
	var new_texture: Texture2D = null

	if cg_aliases.has(cg_name):
		new_texture = cg_aliases[cg_name]
	elif ResourceLoader.exists(cg_name):
		new_texture = load(cg_name)

	if not new_texture:
		push_warning("Could not find CG alias or path: " + cg_name)
		return

	# --- SLIDE TRANSITIONS ---
	if transition in ["slide_left", "slide_right"] and cg_layer.texture != null:
		if SoundManager and SoundManager.has_method("play_sfx"):
			SoundManager.play_sfx("swish", 1.0, -5.0)

		var ghost = TextureRect.new()
		ghost.texture = cg_layer.texture
		ghost.expand_mode = cg_layer.expand_mode
		ghost.stretch_mode = cg_layer.stretch_mode
		ghost.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		ghost.size = get_viewport().get_visible_rect().size
		ghost.position = Vector2.ZERO
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE

		cg_layer.get_parent().add_child(ghost)
		cg_layer.get_parent().move_child(ghost, cg_layer.get_index())

		cg_layer.texture = new_texture
		cg_layer.modulate.a = 1.0

		cg_layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		cg_layer.size = get_viewport().get_visible_rect().size

		var screen_width = cg_layer.size.x
		var new_start_x = 0.0
		var old_end_x = 0.0

		if transition == "slide_left":
			new_start_x = -screen_width
			old_end_x = screen_width
		elif transition == "slide_right":
			new_start_x = screen_width
			old_end_x = -screen_width

		cg_layer.position.x = new_start_x

		var tween = create_tween().set_parallel(true)
		tween.tween_property(cg_layer, "position:x", 0.0, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost, "position:x", old_end_x, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

		tween.chain().tween_callback(ghost.queue_free)
		tween.chain().tween_callback(func():
			if is_instance_valid(cg_layer):
				cg_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		)

	# --- FADE TRANSITION ---
	elif transition == "fade":
		if cg_layer.texture != null and cg_layer.modulate.a > 0.0:
			var ghost = TextureRect.new()
			ghost.texture = cg_layer.texture
			ghost.expand_mode = cg_layer.expand_mode
			ghost.stretch_mode = cg_layer.stretch_mode
			ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE

			cg_layer.get_parent().add_child(ghost)
			cg_layer.get_parent().move_child(ghost, cg_layer.get_index() + 1)

			cg_layer.texture = new_texture
			cg_layer.modulate.a = 1.0

			var tween = create_tween()
			tween.tween_property(ghost, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_callback(ghost.queue_free)
		else:
			cg_layer.texture = new_texture
			cg_layer.position = Vector2.ZERO
			var tween = create_tween()
			tween.tween_property(cg_layer, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# --- INSTANT TRANSITION ---
	else:
		cg_layer.texture = new_texture
		cg_layer.position = Vector2.ZERO
		cg_layer.modulate.a = 1.0

func hide_cg(transition: String = "fade", duration: float = 0.5):
	if transition == "fade":
		var tween = create_tween()
		tween.tween_property(cg_layer, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Don't null the texture immediately so it doesn't pop out during the fade
	else:
		cg_layer.modulate.a = 0.0
		cg_layer.texture = null


func start_tech_scan():
	_scan_active = true
	_scan_time = 0.0

	# Center the pivot so it scales from the middle, then scale up by 5%
	cg_layer.pivot_offset = cg_layer.size / 2.0
	cg_layer.scale = Vector2(1.05, 1.05)

	if _scan_tween:
		_scan_tween.kill()

	_scan_tween = create_tween().set_loops()
	_scan_tween.tween_property(cg_layer, "modulate", Color(0.6, 0.8, 0.9, 1.0), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_scan_tween.tween_property(cg_layer, "modulate", Color(0.4, 0.5, 0.6, 1.0), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func stop_tech_scan():
	_scan_active = false
	if _scan_tween:
		_scan_tween.kill()

	# Smoothly return the image to its original position, color, and scale
	var tween = create_tween().set_parallel(true)
	tween.tween_property(cg_layer, "position", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(cg_layer, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(cg_layer, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func play_cg_sequence(cg_names: Array, hold_duration: float = 2.0, fade_duration: float = 1.0):
	for i in range(cg_names.size()):
		var cg_name = cg_names[i]
		var new_texture: Texture2D = null

		if cg_aliases.has(cg_name):
			new_texture = cg_aliases[cg_name]
		elif ResourceLoader.exists(cg_name):
			new_texture = load(cg_name)

		if not new_texture:
			push_warning("play_cg_sequence: Could not find CG alias or path: " + cg_name)
			continue

		if i == 0 and cg_layer.modulate.a == 0.0:
			# First image, fading in from nothing
			cg_layer.texture = new_texture
			var tween = create_tween()
			tween.tween_property(cg_layer, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tween.finished
		else:
			# Crossfading from an existing CG
			var ghost = TextureRect.new()
			ghost.texture = cg_layer.texture
			ghost.expand_mode = cg_layer.expand_mode
			ghost.stretch_mode = cg_layer.stretch_mode
			ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE

			cg_layer.get_parent().add_child(ghost)
			cg_layer.get_parent().move_child(ghost, cg_layer.get_index() + 1)

			cg_layer.texture = new_texture
			cg_layer.modulate.a = 1.0

			var tween = create_tween()
			tween.tween_property(ghost, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tween.finished
			ghost.queue_free()

		if i < cg_names.size() - 1:
			await get_tree().create_timer(hold_duration).timeout


func start_mental_image(image_name: String, fade_duration: float = 0.5, tint: Color = Color.WHITE, final_opacity: float = 0.6, start_scale: float = 1.0):
	var new_texture: Texture2D = null

	# Try finding the image in either alias dictionary, fallback to raw path
	if cg_aliases.has(image_name):
		new_texture = cg_aliases[image_name]
	elif background_aliases.has(image_name):
		new_texture = background_aliases[image_name]
	elif ResourceLoader.exists(image_name):
		new_texture = load(image_name)

	if not new_texture:
		push_warning("start_mental_image: Could not find alias or path: " + image_name)
		return

	var screen_size = get_viewport().get_visible_rect().size

	# 1. Use Godot's built-in "Cover" mode so we don't have to do custom math
	mental_image_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mental_image_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# 2. Lock it to the exact bounds of the screen
	mental_image_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mental_image_layer.texture = new_texture

	# 3. Set pivot to the exact center of the screen
	mental_image_layer.pivot_offset = screen_size / 2.0

	# 4. FORCE scale to 1.0 (Ignoring start_scale which was coming in as 0.5 from DialogueManager)
	mental_image_layer.scale = Vector2.ONE
	mental_image_layer.position = Vector2.ZERO

	var start_modulate = tint
	start_modulate.a = 0.0
	mental_image_layer.modulate = start_modulate
	mental_image_layer.visible = true

	var mat = null
	if mental_image_shader:
		mat = mental_image_shader.duplicate()
		mat.set_shader_parameter("strength", 0.0)
		background_layer.material = mat
		actor_stage.material = mat
		cg_layer.material = mat

	if _mental_image_tween:
		_mental_image_tween.kill()

	_mental_image_tween = create_tween().set_parallel(true)

	# Fade in opacity and color
	_mental_image_tween.tween_property(mental_image_layer, "modulate:a", final_opacity, fade_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# Fade the world to grayscale
	if mat:
		_mental_image_tween.tween_property(mat, "shader_parameter/strength", 1.0, fade_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# C: The "Infinite" Slow Zoom
	# Since we forced the scale to 1.0, we just tween up to 1.5
	var target_scale_vec = Vector2(1.5, 1.5)

	_mental_image_tween.tween_property(mental_image_layer, "scale", target_scale_vec, 100.0)\
		.set_trans(Tween.TRANS_LINEAR)


func stop_mental_image(fade_duration: float = 0.5):
	if _mental_image_tween:
		_mental_image_tween.kill()

	_mental_image_tween = create_tween().set_parallel(true)

	# Fade out the Ghost Sprite
	_mental_image_tween.tween_property(mental_image_layer, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)

	# Fade out the Grayscale Shader
	if background_layer.material:
		_mental_image_tween.tween_property(background_layer.material, "shader_parameter/strength", 0.0, fade_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)

	await _mental_image_tween.finished

	# Cleanup
	mental_image_layer.visible = false
	mental_image_layer.texture = null
	mental_image_layer.scale = Vector2.ONE
	background_layer.material = null
	actor_stage.material = null
	cg_layer.material = null


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


func _on_got_dialogue(_line: DialogueLine):
	if _ignore_next_got_dialogue_signal:
		_ignore_next_got_dialogue_signal = false
		return
	if _is_persistent_shake:
		_is_shaking = false
		_is_persistent_shake = false
		offset = Vector2.ZERO
