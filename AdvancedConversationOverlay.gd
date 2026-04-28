extends CanvasLayer
class_name AdvancedConversationOverlay

signal conversation_finished(dialogue_resource: DialogueResource)

@export var dialogue_resource: DialogueResource
@export var start_dialogue_id: String = "start"
@export var character_roster: Array[CharacterProfile] = []
@export var background_aliases: Dictionary = {} # String -> String (res:// path)
@export var cg_aliases: Dictionary = {} # String -> String (res:// path)
@export var mental_image_shader: ShaderMaterial

var active_actors: Dictionary = {}

var _scan_active: bool = false
var _scan_time: float = 0.0
var _scan_tween: Tween

var current_balloon: Node = null

# --- SHAKE VARIABLES ---
var _is_shaking: bool = false
var _shake_timer: float = 0.0
var _shake_strength: float = 10.0
var _shake_rng := RandomNumberGenerator.new()
var _is_persistent_shake: bool = false
var _ignore_next_got_dialogue_signal: bool = false
var is_intro_sequence: bool = false

@onready var actor_stage: Control = $ActorStage
@onready var darken_backdrop: ColorRect = $DarkenBackdrop
@onready var background_layer: TextureRect = $BackgroundLayer
@onready var cg_layer: TextureRect = $CGLayer
@onready var mental_image_layer: TextureRect = $MentalImageLayer
@onready var solid_background: ColorRect = $SolidBackground
@onready var cinematic_container: Control = $CinematicContainer
@onready var cinematic_bg: ColorRect = $CinematicBackground
@onready var cinematic_sprite: AnimatedSprite2D = $CinematicSprite
@onready var continue_button: Button = $CinematicContinueButton
@onready var fade_overlay: ColorRect = $FadeOverlay
var _intro_silhouette: TextureRect = null
var _spawned_entities: Dictionary = {}
var is_cinematic_lock_active: bool = false
var _mental_image_tween: Tween

# --- PREDICTIVE PRELOADER ---
var _texture_cache: Dictionary = {}   # String path -> Texture2D
var _loading_paths: Dictionary = {}   # String path -> bool (request sent)
const LOOKAHEAD_DEPTH: int = 20


func _ready():
	if is_instance_valid(darken_backdrop):
		darken_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(solid_background):
		solid_background.mouse_filter = Control.MOUSE_FILTER_STOP

	current_balloon = DialogueManager.show_dialogue_balloon_scene(
		preload("res://conversationballoon.tscn"),
		dialogue_resource,
		start_dialogue_id,
		[self]
	)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.got_dialogue.connect(_on_got_dialogue)
	_shake_rng.randomize()

	if continue_button:
		continue_button.hide()
		if not continue_button.pressed.is_connected(_on_cinematic_continue_pressed):
			continue_button.pressed.connect(_on_cinematic_continue_pressed)

		var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")
		continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		continue_button.add_theme_font_override("font", custom_font)
		continue_button.add_theme_font_size_override("font_size", 24)

		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.85)
		btn_normal.corner_radius_top_left = 6
		btn_normal.corner_radius_top_right = 6
		btn_normal.corner_radius_bottom_left = 6
		btn_normal.corner_radius_bottom_right = 6
		btn_normal.content_margin_left = 25
		btn_normal.content_margin_right = 25
		btn_normal.content_margin_top = 10
		btn_normal.content_margin_bottom = 10
		btn_normal.border_width_left = 2
		btn_normal.border_width_top = 2
		btn_normal.border_width_right = 2
		btn_normal.border_width_bottom = 2
		btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.0)

		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.9)
		btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.8)

		continue_button.add_theme_stylebox_override("normal", btn_normal)
		continue_button.add_theme_stylebox_override("hover", btn_hover)
		continue_button.add_theme_stylebox_override("focus", btn_hover)
		continue_button.add_theme_stylebox_override("pressed", btn_hover)

		continue_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
		continue_button.add_theme_color_override("font_hover_color", Color.WHITE)
		continue_button.add_theme_color_override("font_pressed_color", Color.WHITE)


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

	conversation_finished.emit(dialogue_resource)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(darken_backdrop, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if is_instance_valid(background_layer):
		tween.tween_property(background_layer, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if is_instance_valid(actor_stage):
		tween.tween_property(actor_stage, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if is_instance_valid(cg_layer):
		tween.tween_property(cg_layer, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if is_instance_valid(mental_image_layer):
		tween.tween_property(mental_image_layer, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Ensure the node deletes itself and clears texture cache
	tween.chain().tween_callback(self._destroy_and_clear_cache)


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

	var tex_path: String = profile.expressions.get(emotion, "")
	if tex_path.is_empty():
		push_warning("Emotion '" + emotion + "' not found for actor: " + actor_id)
		return

	var tex: Texture2D = await _get_texture_async(tex_path)
	if not tex:
		push_warning("Failed to load texture: " + tex_path)
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

	var tex_path: String = profile.expressions.get(emotion, "")
	if not tex_path.is_empty():
		var tex: Texture2D = await _get_texture_async(tex_path)
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

	var tex_path: String = profile.expressions.get(emotion, "")
	if tex_path.is_empty():
		push_warning("Emotion '" + emotion + "' not found for actor: " + actor_id)
		return

	var tex: Texture2D = await _get_texture_async(tex_path)
	if not tex:
		push_warning("Failed to load texture: " + tex_path)
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

	var tex_path: String = profile.expressions.get(emotion, "")
	if tex_path.is_empty():
		push_warning("Emotion '" + emotion + "' not found for actor: " + actor_id)
		return

	var tex: Texture2D = await _get_texture_async(tex_path)
	if not tex:
		push_warning("Failed to load texture: " + tex_path)
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

	var resolved_path: String = ""
	if background_aliases.has(bg_name):
		resolved_path = background_aliases[bg_name]
	elif ResourceLoader.exists(bg_name):
		resolved_path = bg_name

	var new_texture: Texture2D = null
	if not resolved_path.is_empty():
		new_texture = await _get_texture_async(resolved_path)

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

	var tex_path: String = profile.expressions.get(emotion, "")
	if tex_path.is_empty():
		push_warning("Emotion '" + emotion + "' not found for actor: " + actor_id)
		return

	var tex: Texture2D = await _get_texture_async(tex_path)
	if not tex:
		push_warning("Failed to load texture: " + tex_path)
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
	var resolved_path: String = ""
	if cg_aliases.has(cg_name):
		resolved_path = cg_aliases[cg_name]
	elif ResourceLoader.exists(cg_name):
		resolved_path = cg_name

	var new_texture: Texture2D = null
	if not resolved_path.is_empty():
		new_texture = await _get_texture_async(resolved_path)

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
		tween.tween_callback(func(): cg_layer.texture = null)
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
		var resolved_path: String = ""
		if cg_aliases.has(cg_name):
			resolved_path = cg_aliases[cg_name]
		elif ResourceLoader.exists(cg_name):
			resolved_path = cg_name

		var new_texture: Texture2D = null
		if not resolved_path.is_empty():
			new_texture = await _get_texture_async(resolved_path)

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
	var resolved_path: String = ""
	if cg_aliases.has(image_name):
		resolved_path = cg_aliases[image_name]
	elif background_aliases.has(image_name):
		resolved_path = background_aliases[image_name]
	elif ResourceLoader.exists(image_name):
		resolved_path = image_name

	var new_texture: Texture2D = null
	if not resolved_path.is_empty():
		new_texture = await _get_texture_async(resolved_path)

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


func _on_got_dialogue(line: DialogueLine):
	if _ignore_next_got_dialogue_signal:
		_ignore_next_got_dialogue_signal = false
		return
	if _is_persistent_shake:
		_is_shaking = false
		_is_persistent_shake = false
		offset = Vector2.ZERO

	_update_predictive_cache(line)


# --- PREDICTIVE PRELOADER SUBSYSTEM ---

func _update_predictive_cache(line: DialogueLine):
	var needed_paths: Dictionary = {}
	_collect_upcoming_paths(line.next_id, LOOKAHEAD_DEPTH, needed_paths, {})

	# GC: drop cached textures that are no longer in the upcoming window
	var to_remove: Array = []
	for path in _texture_cache:
		if not needed_paths.has(path):
			to_remove.append(path)
	for path in to_remove:
		_texture_cache.erase(path)
		_loading_paths.erase(path)

	# Request background-thread loading for new paths
	for path in needed_paths:
		if not _texture_cache.has(path) and not _loading_paths.has(path):
			if ResourceLoader.exists(path):
				_loading_paths[path] = true
				ResourceLoader.load_threaded_request(path)


func _collect_upcoming_paths(line_id: String, depth: int, out_paths: Dictionary, visited: Dictionary):
	if depth <= 0:
		return
	if line_id in ["end", "end!", "", null]:
		return
	if visited.has(line_id):
		return
	visited[line_id] = true

	# Handle stacked IDs (pipe-separated return addresses)
	var base_id: String = line_id.split("|")[0]
	if base_id.is_empty() or not dialogue_resource.lines.has(base_id):
		return

	var data: Dictionary = dialogue_resource.lines[base_id]

	# Extract texture paths from mutation lines
	if data.type == &"mutation" and data.has("mutation"):
		_extract_paths_from_mutation(data.mutation, out_paths)

	# Follow response branches
	if data.has("responses"):
		for resp_id in data.responses:
			if dialogue_resource.lines.has(resp_id):
				var resp_data: Dictionary = dialogue_resource.lines[resp_id]
				if resp_data.has("next_id"):
					_collect_upcoming_paths(resp_data.next_id, depth - 1, out_paths, visited)

	# Follow condition branches
	if data.has("next_sibling_id") and not data.next_sibling_id.is_empty():
		_collect_upcoming_paths(data.next_sibling_id, depth - 1, out_paths, visited)
	if data.has("next_id_after") and not data.next_id_after.is_empty():
		_collect_upcoming_paths(data.next_id_after, depth - 1, out_paths, visited)

	# Follow the main next_id
	if data.has("next_id"):
		var next: String = data.next_id.split("|")[0]
		_collect_upcoming_paths(next, depth - 1, out_paths, visited)


func _extract_paths_from_mutation(mutation: Dictionary, out_paths: Dictionary):
	if not mutation.has("expression"):
		return
	var expression: Array = mutation.expression
	if expression.is_empty():
		return

	var token: Dictionary = expression[0]
	if token.type != &"function":
		return

	var func_name: String = token.function

	match func_name:
		"actor_enter", "actor_change", "actor_walk_in", "actor_dash_in", "actor_show":
			var actor_id: String = _extract_string_arg(token, 0)
			var emotion: String = _extract_string_arg(token, 1)
			if not actor_id.is_empty() and not emotion.is_empty():
				var profile = get_profile(actor_id)
				if profile:
					var tex_path: String = profile.expressions.get(emotion, "")
					if not tex_path.is_empty():
						out_paths[tex_path] = true

		"change_background":
			var bg_name: String = _extract_string_arg(token, 0)
			if not bg_name.is_empty():
				if background_aliases.has(bg_name):
					out_paths[background_aliases[bg_name]] = true
				elif ResourceLoader.exists(bg_name):
					out_paths[bg_name] = true

		"show_cg", "reveal_shock_from_black":
			var cg_name: String = _extract_string_arg(token, 0)
			if not cg_name.is_empty():
				if cg_aliases.has(cg_name):
					out_paths[cg_aliases[cg_name]] = true
				elif ResourceLoader.exists(cg_name):
					out_paths[cg_name] = true

		"start_mental_image":
			var image_name: String = _extract_string_arg(token, 0)
			if not image_name.is_empty():
				if cg_aliases.has(image_name):
					out_paths[cg_aliases[image_name]] = true
				elif background_aliases.has(image_name):
					out_paths[background_aliases[image_name]] = true
				elif ResourceLoader.exists(image_name):
					out_paths[image_name] = true


func _extract_string_arg(token: Dictionary, index: int) -> String:
	if not token.has("value"):
		return ""
	var args: Array = token.value
	if index >= args.size():
		return ""
	var arg_tokens: Array = args[index]
	if arg_tokens.is_empty():
		return ""
	# Skip closing-bracket/paren tokens that _resolve_each also skips
	if arg_tokens[0].type in [&"parens_close", &"bracket_close", &"brace_close"]:
		return ""
	if arg_tokens[0].type == &"string":
		return arg_tokens[0].value
	return ""


func _get_texture_async(path: String) -> Texture2D:
	if path.is_empty():
		return null

	# Already in cache
	if _texture_cache.has(path):
		return _texture_cache[path]

	# A threaded load was already requested by the predictive crawler
	if _loading_paths.has(path):
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		var tex: Texture2D = ResourceLoader.load_threaded_get(path)
		_texture_cache[path] = tex
		_loading_paths.erase(path)
		return tex

	# Not cached and not loading — start a threaded request now
	if ResourceLoader.exists(path):
		ResourceLoader.load_threaded_request(path)
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		var tex: Texture2D = ResourceLoader.load_threaded_get(path)
		_texture_cache[path] = tex
		return tex

	# Fallback to synchronous load
	var tex: Texture2D = load(path)
	if tex:
		_texture_cache[path] = tex
	return tex


func _destroy_and_clear_cache():
	# 1. Sever the nodes' ties to the textures so the reference count drops to 0
	if is_instance_valid(background_layer): background_layer.texture = null
	if is_instance_valid(cg_layer): cg_layer.texture = null
	if is_instance_valid(mental_image_layer): mental_image_layer.texture = null

	# 2. Clear the predictive texture cache
	_texture_cache.clear()
	_loading_paths.clear()

	# 3. Delay destruction if this is the Intro sequence (smooth transition to main world)
	if is_intro_sequence:
		await get_tree().create_timer(2.0).timeout

	if is_instance_valid(current_balloon):
		current_balloon.queue_free()

	# 4. Delete the node (Godot will automatically flush the VRAM now)
	queue_free()

# --- ENGINE-DRIVEN CINEMATIC FUNCTIONS ---
func set_solid_background(hex_color: String, duration: float = 1.0):
	if is_instance_valid(darken_backdrop):
		darken_backdrop.hide()

	var target_color = Color(hex_color)
	if duration <= 0.0:
		solid_background.color = target_color
	else:
		var tween = create_tween()
		tween.tween_property(solid_background, "color", target_color, duration)

func show_intro_silhouette(texture_path: String):
	if _intro_silhouette: return

	var tex = load(texture_path)
	if not tex:
		print_rich("[color=red]Cinematic Error: Could not load texture at path: %s[/color]" % texture_path)
		return

	_intro_silhouette = TextureRect.new()
	_intro_silhouette.texture = tex

	# Get sizes to manually center the image
	var screen_size = Vector2(1920, 1080) # Fallback baseline
	if is_inside_tree():
		screen_size = get_viewport().get_visible_rect().size

	var tex_size = _intro_silhouette.texture.get_size()
	var centered_pos = (screen_size - tex_size) / 2.0

	# Set pivot to the center of the image so scaling shrinks it towards its middle
	_intro_silhouette.pivot_offset = tex_size / 2.0

	# --- SCALE CONTROL ---
	# Adjust this Vector2 to make the silhouette bigger or smaller!
	_intro_silhouette.scale = Vector2(0.45, 0.45)

	# Start invisible and 50 pixels lower than center
	_intro_silhouette.modulate.a = 0.0
	_intro_silhouette.position = centered_pos + Vector2(0, 50)

	cinematic_container.add_child(_intro_silhouette)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(_intro_silhouette, "modulate:a", 1.0, 3.0)
	# Tween up to the true center
	tween.tween_property(_intro_silhouette, "position:y", centered_pos.y, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(self._start_silhouette_float.bind(centered_pos.y))

func _start_silhouette_float(center_y: float):
	var float_tween = create_tween().set_loops()
	float_tween.tween_property(_intro_silhouette, "position:y", center_y - 15.0, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(_intro_silhouette, "position:y", center_y + 15.0, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func spawn_cinematic_entity(entity_name: String, tscn_path: String, screen_x: float, screen_y: float):
	var scene = load(tscn_path)
	if not scene: return
	var instance = scene.instantiate()
	instance.position = Vector2(screen_x, screen_y)
	instance.modulate.a = 0.0
	cinematic_container.add_child(instance)
	_spawned_entities[entity_name] = instance
	create_tween().tween_property(instance, "modulate:a", 1.0, 2.0)

func remove_cinematic_entity(entity_name: String):
	if _spawned_entities.has(entity_name):
		var entity = _spawned_entities[entity_name]
		_spawned_entities.erase(entity_name)
		var tween = create_tween()
		tween.tween_property(entity, "modulate:a", 0.0, 1.5)
		tween.tween_callback(entity.queue_free)

func create_glow_texture(center_color: Color, edge_color: Color, size: int = 256) -> GradientTexture2D:
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([center_color, edge_color])
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = size
	tex.height = size
	return tex

func activate_hope_surround():
	var aura = TextureRect.new()
	aura.texture = create_glow_texture(Color(1.0, 0.6, 0.7, 1.0), Color(1.0, 0.4, 0.6, 0.0), 2000)
	aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aura.material = CanvasItemMaterial.new()
	aura.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aura.modulate = Color(1.0, 1.0, 1.0, 0.0)

	cinematic_container.add_child(aura)
	cinematic_container.move_child(aura, _intro_silhouette.get_index())

	var tween = create_tween()
	tween.tween_property(aura, "modulate:a", 0.6, 2.0)
	var pulse = create_tween().set_loops()
	pulse.tween_property(aura, "scale", Vector2(1.05, 1.05), 2.0).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(aura, "scale", Vector2(0.95, 0.95), 2.0).set_trans(Tween.TRANS_SINE)

# --- CINEMATIC & FADE FUNCTIONS ---

func play_cinematic(animation_name: String = "default", hide_balloon: bool = true, force_one_loop: bool = false, transition_effect: String = "none"):
	if transition_effect == "dissolve" or transition_effect == "fade":
		if cinematic_bg:
			cinematic_bg.modulate.a = 0.0
			cinematic_bg.show()
		if cinematic_sprite:
			cinematic_sprite.modulate.a = 0.0
			cinematic_sprite.show()
			cinematic_sprite.play(animation_name)

		var tween = create_tween().set_parallel(true)
		if cinematic_bg: tween.tween_property(cinematic_bg, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
		if cinematic_sprite: tween.tween_property(cinematic_sprite, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		if cinematic_bg:
			cinematic_bg.modulate.a = 1.0
			cinematic_bg.show()
		if cinematic_sprite:
			cinematic_sprite.modulate.a = 1.0
			cinematic_sprite.show()
			cinematic_sprite.play(animation_name)

	is_cinematic_lock_active = true
	if hide_balloon and current_balloon: current_balloon.hide()
	if continue_button: continue_button.show()

func _on_cinematic_continue_pressed():
	is_cinematic_lock_active = false
	if continue_button: continue_button.hide()

	if current_balloon:
		current_balloon.show()
		if current_balloon.has_method("next") and current_balloon.dialogue_line:
			current_balloon.next(current_balloon.dialogue_line.next_id)
		else:
			stop_cinematic()

func stop_cinematic(transition_effect: String = "none"):
	is_cinematic_lock_active = false
	if continue_button: continue_button.hide()

	if transition_effect == "dissolve" or transition_effect == "fade":
		var tween = create_tween().set_parallel(true)
		if cinematic_bg: tween.tween_property(cinematic_bg, "modulate:a", 0.0, 0.5)
		if cinematic_sprite: tween.tween_property(cinematic_sprite, "modulate:a", 0.0, 0.5)
		await tween.finished

		if cinematic_bg: cinematic_bg.hide()
		if cinematic_sprite:
			cinematic_sprite.stop()
			cinematic_sprite.hide()
	else:
		if cinematic_bg: cinematic_bg.hide()
		if cinematic_sprite:
			cinematic_sprite.stop()
			cinematic_sprite.hide()

	if current_balloon: current_balloon.show()

func fade_to_black(duration: float = 1.0):
	if not fade_overlay: return
	fade_overlay.color = Color.BLACK
	fade_overlay.show()
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func fade_from_black(duration: float = 1.0):
	if not fade_overlay: return
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	fade_overlay.hide()

func reveal_shock_from_black(cg_alias_name: String, shake_power: float = 25.0):
	# Route through show_cg to automatically check the cg_aliases dictionary
	await show_cg(cg_alias_name, "none", 0.0)
	shake(0.5, shake_power)
	if fade_overlay:
		fade_overlay.color = Color.WHITE
		fade_overlay.modulate.a = 1.0
		fade_overlay.show()
		var tween = create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(fade_overlay.hide)
