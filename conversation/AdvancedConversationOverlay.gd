extends CanvasLayer
class_name AdvancedConversationOverlay

signal conversation_finished(dialogue_resource: DialogueResource)
signal first_visuals_ready

@export var dialogue_resource: DialogueResource
@export var start_dialogue_id: String = "start"
@export var character_roster: Array[CharacterProfile] = []
@export var background_aliases: Dictionary = {}
@export var cg_aliases: Dictionary = {}
@export var mental_image_shader: ShaderMaterial

var active_actors: Dictionary = {}

var _scan_active: bool = false
var _scan_time: float = 0.0
var _scan_tween: Tween

var current_balloon: Node = null

# ****************************[shake variables]
var _is_shaking: bool = false
var _shake_timer: float = 0.0
var _shake_strength: float = 10.0
var _shake_rng := RandomNumberGenerator.new()
var _is_persistent_shake: bool = false
var _ignore_next_got_dialogue_signal: bool = false
var is_intro_sequence: bool = false
var _camera_offset: Vector2 = Vector2.ZERO

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
var patreon_btn: Button = null
var _mental_image_tween: Tween

# *********************[predictive preloader]
var _texture_cache: Dictionary = {}
var _loading_paths: Dictionary = {}
var _discard_when_loaded: Dictionary = {}
var _has_emitted_ready: bool = false
const LOOKAHEAD_DEPTH: int = 20


func _ready():
	if is_instance_valid(darken_backdrop):
		darken_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(solid_background):
		solid_background.mouse_filter = Control.MOUSE_FILTER_STOP

	current_balloon = DialogueManager.show_dialogue_balloon_scene(
		preload("res://conversation/conversationballoon.tscn"),
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
		continue_button.add_theme_font_size_override("font_size", 46 if OS.has_feature("mobile") else 32)

		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.85)
		btn_normal.corner_radius_top_left = 6
		btn_normal.corner_radius_top_right = 6
		btn_normal.corner_radius_bottom_left = 6
		btn_normal.corner_radius_bottom_right = 6
		btn_normal.content_margin_left = 50 if OS.has_feature("mobile") else 35
		btn_normal.content_margin_right = 50 if OS.has_feature("mobile") else 35
		btn_normal.content_margin_top = 25 if OS.has_feature("mobile") else 15
		btn_normal.content_margin_bottom = 25 if OS.has_feature("mobile") else 15

		continue_button.reset_size()

		# anchor to top-left so it
		continue_button.anchor_left = 0.0
		continue_button.anchor_right = 0.0
		continue_button.anchor_top = 0.0
		continue_button.anchor_bottom = 0.0
		continue_button.grow_horizontal = Control.GROW_DIRECTION_END
		continue_button.grow_vertical = Control.GROW_DIRECTION_END

		# add safe padding from the absolute edges
		continue_button.offset_left = 50 if OS.has_feature("mobile") else 30
		continue_button.offset_top = 50 if OS.has_feature("mobile") else 30
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
		# wavy style movement
		var offset_x = sin(_scan_time * 4.0) * 4.0
		var offset_y = cos(_scan_time * 3.0) * 4.0
		cg_layer.position = Vector2(offset_x, offset_y)

	# *************************[shake logic]
	if _is_shaking:
		if not _is_persistent_shake:
			_shake_timer -= delta
			if _shake_timer <= 0:
				_is_shaking = false
				offset = _camera_offset

		if _is_shaking:
			var offset_x = _shake_rng.randf_range(-_shake_strength, _shake_strength)
			var offset_y = _shake_rng.randf_range(-_shake_strength, _shake_strength)
			offset = _camera_offset + Vector2(offset_x, offset_y)


func _on_dialogue_ended(resource: DialogueResource):
	# guard: another balloon's dialogue ending
	if resource != dialogue_resource:
		return
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

	# ensure the node deletes itself and clears texture cache
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

	# scale calculation
	var screen_height = float(get_viewport().get_visible_rect().size.y)
	var tex_size = tex.get_size()

	# base scale makes the image exactly as tall as the screen
	var base_scale = screen_height / float(tex_size.y)
	var final_scale = base_scale * profile.default_scale

	rect.scale = Vector2(final_scale, final_scale)

	# set bottom-center pivot
	rect.pivot_offset = Vector2(tex_size.x / 2.0, tex_size.y)

	actor_stage.add_child(rect)
	active_actors[actor_id] = rect

	# find target marker
	var marker_name = "Slot" + slot_name.capitalize()
	var marker = actor_stage.get_node_or_null(marker_name)
	if not marker:
		push_warning("Could not find slot marker: " + marker_name)
		marker = actor_stage.get_node("SlotCenter")

	# position rect on marker
	# subtract raw pivot_offset
	var target_pos = marker.position - rect.pivot_offset

	# slide up animation setup
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
		var peak_s = base_s * 1.05

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

	# determine starting x position based on slot
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
	var target_base_pos: Vector2

	# calculate center offsets dynamically
	if target_slot_name.to_lower() == "center_right":
		target_base_pos = Vector2(1200, 1080)
	elif target_slot_name.to_lower() == "center_left":
		target_base_pos = Vector2(720, 1080)
	else:
		# fallback to standard markers
		var marker_name = "Slot" + target_slot_name.capitalize()
		var marker = actor_stage.get_node_or_null(marker_name)
		if not marker:
			push_warning("Could not find slot marker: " + marker_name)
			marker = actor_stage.get_node("SlotCenter")
		target_base_pos = marker.position

	# calculate target position
	var target_pos = target_base_pos - rect.pivot_offset

	# slide tween
	var tween = create_tween()
	tween.tween_property(rect, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func actor_flip(actor_id: String, is_flipped: bool = true):
	if not active_actors.has(actor_id):
		push_warning("Cannot flip actor, not found on stage: " + actor_id)
		return

	var rect: TextureRect = active_actors[actor_id]
	var current_scale = rect.scale

	# flip texture horizontally
	# prevent double flip
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
	# overshoot spring effect
	# short snap duration
	tween.tween_property(rect, "position:x", target_pos.x, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func actor_peek_in(actor_id: String, emotion: String, side: String = "right"):
	var profile = get_profile(actor_id)
	if not profile: return
	var tex_path: String = profile.expressions.get(emotion, "")
	if tex_path.is_empty(): return
	var tex: Texture2D = await _get_texture_async(tex_path)
	if not tex: return

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

	var marker_name = "Slot" + side.capitalize()
	var marker = actor_stage.get_node_or_null(marker_name)
	if not marker: marker = actor_stage.get_node("SlotCenter")

	var target_pos = marker.position - rect.pivot_offset

	if side.to_lower() == "right":
		rect.rotation_degrees = -12.0
		# hide bottom cutoff
		rect.position = Vector2(target_pos.x + 800.0, target_pos.y + 250.0)
		rect.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(rect, "position:x", target_pos.x + 350.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		rect.rotation_degrees = 12.0
		# hide bottom cutoff
		rect.position = Vector2(target_pos.x - 800.0, target_pos.y + 250.0)
		rect.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(rect, "position:x", target_pos.x - 350.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func actor_enter_from_peek(actor_id: String, target_slot_name: String, duration: float = 0.5):
	if not active_actors.has(actor_id): return
	var rect: TextureRect = active_actors[actor_id]
	var marker_name = "Slot" + target_slot_name.capitalize()
	var marker = actor_stage.get_node_or_null(marker_name)
	if not marker: return

	var target_pos = marker.position - rect.pivot_offset
	var tween = create_tween().set_parallel(true)
	tween.tween_property(rect, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(rect, "rotation_degrees", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func hide_dialogue_ui():
	if current_balloon and current_balloon.has_method("set_ui_hidden"):
		current_balloon.set_ui_hidden(true)

func show_dialogue_ui():
	if current_balloon and current_balloon.has_method("set_ui_hidden"):
		current_balloon.set_ui_hidden(false)

var _original_actor_transforms = {}

func actor_focus(actor_id: String, zoom_modifier: float = 2.0, duration: float = 0.01, face_x_ratio: float = 0.5):
	if not active_actors.has(actor_id): return

	if _original_actor_transforms.is_empty():
		for id in active_actors:
			var r = active_actors[id]
			_original_actor_transforms[id] = {"pos": r.position, "scale": r.scale}

	var rect: TextureRect = active_actors[actor_id]
	actor_stage.move_child(rect, -1)

	var profile = get_profile(actor_id)
	var tex_size = rect.texture.get_size()
	var screen_size = get_viewport().get_visible_rect().size

	var base_scale = screen_size.y / float(tex_size.y)
	var target_scale_mag = base_scale * profile.default_scale * zoom_modifier
	var target_scale = Vector2(target_scale_mag, target_scale_mag)
	if rect.scale.x < 0: target_scale.x = -target_scale.x

	var local_face = Vector2(tex_size.x * face_x_ratio, tex_size.y * 0.2)
	var screen_focus_point = Vector2(screen_size.x * 0.5, screen_size.y * 0.35)
	var target_pos = screen_focus_point - rect.pivot_offset - (local_face - rect.pivot_offset) * target_scale

	var tween = create_tween().set_parallel(true)
	var is_smash_cut = duration <= 0.05

	if is_smash_cut:
		rect.scale = target_scale
		rect.position = target_pos
		rect.modulate = Color.WHITE
	else:
		tween.tween_property(rect, "scale", target_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(rect, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(rect, "modulate", Color.WHITE, duration)

	if is_instance_valid(background_layer):
		tween.tween_property(background_layer, "modulate", Color(0.2, 0.2, 0.2, 1.0), duration)

	for id in active_actors:
		if id != actor_id:
			var other_rect = active_actors[id]
			if _original_actor_transforms.has(id):
				var orig = _original_actor_transforms[id]
				var target_other_scale = orig["scale"]

				if sign(other_rect.scale.x) != sign(target_other_scale.x):
					target_other_scale.x = -target_other_scale.x

				if is_smash_cut:
					other_rect.scale = target_other_scale
					other_rect.position = orig["pos"]
					other_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
				else:
					tween.tween_property(other_rect, "scale", target_other_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					tween.tween_property(other_rect, "position", orig["pos"], duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					tween.tween_property(other_rect, "modulate", Color(1.0, 1.0, 1.0, 0.0), duration)

func actor_unfocus_all(duration: float = 0.2):
	var tween = create_tween().set_parallel(true)
	var is_smash_cut = duration <= 0.05

	if is_instance_valid(background_layer):
		tween.tween_property(background_layer, "modulate", Color.WHITE, duration)

	for id in active_actors:
		var rect: TextureRect = active_actors[id]
		if _original_actor_transforms.has(id):
			var orig = _original_actor_transforms[id]
			var target_scale = orig["scale"]
			if sign(rect.scale.x) != sign(target_scale.x):
				target_scale.x = -target_scale.x

			if is_smash_cut:
				rect.scale = target_scale
				rect.position = orig["pos"]
				rect.modulate = Color.WHITE
			else:
				tween.tween_property(rect, "scale", target_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(rect, "position", orig["pos"], duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(rect, "modulate", Color.WHITE, duration)
		elif is_smash_cut:
			rect.modulate = Color.WHITE

	if is_smash_cut:
		_original_actor_transforms.clear()
	else:
		tween.chain().tween_callback(func(): _original_actor_transforms.clear())

func set_backdrop_darkness(alpha: float = 0.6, duration: float = 0.5):
	if not is_instance_valid(darken_backdrop): return
	var tween = create_tween()
	tween.tween_property(darken_backdrop, "color:a", alpha, duration)


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
		# use top-left layout
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
		tween.tween_property(background_layer, "position:x", 0.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost, "position:x", old_end_x, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

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

	# ******************[slide transitions n shi]
	if transition in ["slide_left", "slide_right"]:
		if SoundManager and SoundManager.has_method("play_sfx"):
			SoundManager.play_sfx("swish", 1.0, -5.0)

		var slide_tween = create_tween().set_parallel(true)
		var screen_width = get_viewport().get_visible_rect().size.x

		var new_start_x = 0.0
		var old_end_x = 0.0

		if transition == "slide_left":
			new_start_x = -screen_width
			old_end_x = screen_width
		elif transition == "slide_right":
			new_start_x = screen_width
			old_end_x = -screen_width

		# optional slide out ghost
		if cg_layer.texture != null:
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

			slide_tween.tween_property(ghost, "position:x", old_end_x, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			slide_tween.chain().tween_callback(ghost.queue_free)

		# setup sprite
		cg_layer.texture = new_texture
		cg_layer.modulate.a = 1.0
		cg_layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		cg_layer.size = get_viewport().get_visible_rect().size
		cg_layer.position.x = new_start_x

		slide_tween.tween_property(cg_layer, "position:x", 0.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		slide_tween.chain().tween_callback(func():
			if is_instance_valid(cg_layer):
				cg_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		)

	# ************************[fade transition)
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

	# ********************[instant transition]
	else:
		cg_layer.texture = new_texture
		cg_layer.position = Vector2.ZERO
		cg_layer.modulate.a = 1.0

func hide_cg(transition: String = "fade", duration: float = 0.5):
	if transition in ["slide_left", "slide_right"]:
		var screen_width = get_viewport().get_visible_rect().size.x
		var target_x = 0.0

		if transition == "slide_left":
			target_x = -screen_width
		elif transition == "slide_right":
			target_x = screen_width

		var tween = create_tween()
		tween.tween_property(cg_layer, "position:x", target_x, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			cg_layer.texture = null
			cg_layer.position = Vector2.ZERO
			cg_layer.modulate.a = 0.0
		)
	elif transition == "fade":
		var tween = create_tween()
		tween.tween_property(cg_layer, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func(): cg_layer.texture = null)
	else:
		cg_layer.modulate.a = 0.0
		cg_layer.texture = null


func start_tech_scan():
	_scan_active = true
	_scan_time = 0.0

	# center pivot and scale
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

	# reset image visuals
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
			# fade in first image
			cg_layer.texture = new_texture
			var tween = create_tween()
			tween.tween_property(cg_layer, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tween.finished
		else:
			# crossfade cg
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

	# use cover mode
	mental_image_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mental_image_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# lock to screen bounds
	mental_image_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mental_image_layer.texture = new_texture

	# center pivot
	mental_image_layer.pivot_offset = screen_size / 2.0

	# force scale to 1.0
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

	# fade in opacity and color
	_mental_image_tween.tween_property(mental_image_layer, "modulate:a", final_opacity, fade_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# fade the world to grayscale
	if mat:
		_mental_image_tween.tween_property(mat, "shader_parameter/strength", 1.0, fade_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# c: the "infinite" slow zoom
	# since we forced the scale to 1.0, we just tween up to 1.5
	var target_scale_vec = Vector2(1.5, 1.5)

	_mental_image_tween.tween_property(mental_image_layer, "scale", target_scale_vec, 100.0)\
		.set_trans(Tween.TRANS_LINEAR)


func stop_mental_image(fade_duration: float = 0.5):
	if _mental_image_tween:
		_mental_image_tween.kill()

	_mental_image_tween = create_tween().set_parallel(true)

	# fade out the ghost sprite
	_mental_image_tween.tween_property(mental_image_layer, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)

	# fade out the grayscale shader
	if background_layer.material:
		_mental_image_tween.tween_property(background_layer.material, "shader_parameter/strength", 0.0, fade_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)

	await _mental_image_tween.finished

	# cleanup
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


# *************************[predictive preloader subsystem]

func _update_predictive_cache(line: DialogueLine):
	var needed_paths: Dictionary = {}
	_collect_upcoming_paths(line.next_id, LOOKAHEAD_DEPTH, needed_paths, {})

	# garbage collect unused cached textures
	var to_remove: Array = []
	for path in _texture_cache:
		if not needed_paths.has(path):
			to_remove.append(path)
	for path in to_remove:
		_texture_cache.erase(path)
		if _loading_paths.has(path):
			_discard_when_loaded[path] = true
			_loading_paths.erase(path)

	# poll and clean discarded paths
	_poll_discard_queue()

	# request background thread preloading
	for path in needed_paths:
		if not _texture_cache.has(path) and not _loading_paths.has(path):
			if ResourceLoader.exists(path):
				_loading_paths[path] = true
				ResourceLoader.load_threaded_request(path)

	if not _has_emitted_ready:
		_has_emitted_ready = true
		get_tree().create_timer(0.2).timeout.connect(func(): first_visuals_ready.emit())


func _poll_discard_queue():
	var completed: Array = []
	for path in _discard_when_loaded:
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# fetch and discard
			var _discard = ResourceLoader.load_threaded_get(path)
			completed.append(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			completed.append(path)
	for path in completed:
		_discard_when_loaded.erase(path)


func _collect_upcoming_paths(line_id: String, depth: int, out_paths: Dictionary, visited: Dictionary):
	if depth <= 0:
		return
	if line_id in ["end", "end!", "", null]:
		return
	if visited.has(line_id):
		return
	visited[line_id] = true

	# handle stacked ids
	var base_id: String = line_id.split("|")[0]
	if base_id.is_empty() or not dialogue_resource.lines.has(base_id):
		return

	var data: Dictionary = dialogue_resource.lines[base_id]

	# extract texture paths
	if data.type == &"mutation" and data.has("mutation"):
		_extract_paths_from_mutation(data.mutation, out_paths)

	# parse response branches
	if data.has("responses"):
		for resp_id in data.responses:
			if dialogue_resource.lines.has(resp_id):
				var resp_data: Dictionary = dialogue_resource.lines[resp_id]
				if resp_data.has("next_id"):
					_collect_upcoming_paths(resp_data.next_id, depth - 1, out_paths, visited)

	# parse condition branches
	if data.has("next_sibling_id") and not data.next_sibling_id.is_empty():
		_collect_upcoming_paths(data.next_sibling_id, depth - 1, out_paths, visited)
	if data.has("next_id_after") and not data.next_id_after.is_empty():
		_collect_upcoming_paths(data.next_id_after, depth - 1, out_paths, visited)

	# parse next id
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
		"actor_enter", "actor_change", "actor_walk_in", "actor_dash_in", "actor_show", "actor_peek_in":
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
	# skip closing tokens
	if arg_tokens[0].type in [&"parens_close", &"bracket_close", &"brace_close"]:
		return ""
	if arg_tokens[0].type == &"string":
		return arg_tokens[0].value
	return ""


func _get_texture_async(path: String) -> Texture2D:
	if path.is_empty():
		return null

	# already in cache
	if _texture_cache.has(path):
		return _texture_cache[path]

	# a threaded load was already in progress
	if _loading_paths.has(path):
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		
		# re-check cache immediately after awaiting
		if _texture_cache.has(path):
			return _texture_cache[path]
			
		# fetch exactly once
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var tex: Texture2D = ResourceLoader.load_threaded_get(path)
			_texture_cache[path] = tex
			_loading_paths.erase(path)
			return tex

	# start threaded load
	if ResourceLoader.exists(path):
		_loading_paths[path] = true
		ResourceLoader.load_threaded_request(path)
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
			
		if _texture_cache.has(path):
			return _texture_cache[path]
			
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var tex: Texture2D = ResourceLoader.load_threaded_get(path)
			_texture_cache[path] = tex
			_loading_paths.erase(path)
			return tex

	# fallback sync load
	var tex: Texture2D = load(path)
	if tex:
		_texture_cache[path] = tex
	return tex


func _destroy_and_clear_cache():
	# release texture references
	if is_instance_valid(background_layer): background_layer.texture = null
	if is_instance_valid(cg_layer): cg_layer.texture = null
	if is_instance_valid(mental_image_layer): mental_image_layer.texture = null

	# clear preload cache
	_texture_cache.clear()
	_loading_paths.clear()

	# delay intro destruction
	if is_intro_sequence:
		await get_tree().create_timer(2.0).timeout

	if is_instance_valid(current_balloon):
		current_balloon.queue_free()

	# delete node to flush vram
	queue_free()
	DebugVRAM.snapshot("ACO destroyed")

# *********************[engine-driven cinematic functions]
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

	# get sizes for centering
	var screen_size = Vector2(1920, 1080)
	if is_inside_tree():
		screen_size = get_viewport().get_visible_rect().size

	var tex_size = _intro_silhouette.texture.get_size()
	var centered_pos = (screen_size - tex_size) / 2.0

	# center pivot for scaling
	_intro_silhouette.pivot_offset = tex_size / 2.0

	# ***********************[scale control]
	# scale adjustment
	_intro_silhouette.scale = Vector2(0.45, 0.45)

	# invisible start offset
	_intro_silhouette.modulate.a = 0.0
	_intro_silhouette.position = centered_pos + Vector2(0, 50)

	cinematic_container.add_child(_intro_silhouette)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(_intro_silhouette, "modulate:a", 1.0, 3.0)
	# slide up to center
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

# ***************************[cinematic & fade functions]

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
	# show cg with aliases
	await show_cg(cg_alias_name, "none", 0.0)
	shake(0.5, shake_power)
	if fade_overlay:
		fade_overlay.color = Color.WHITE
		fade_overlay.modulate.a = 1.0
		fade_overlay.show()
		var tween = create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(fade_overlay.hide)

func actor_tackle(attacker_id: String, target_id: String):
	if not active_actors.has(attacker_id) or not active_actors.has(target_id): return

	var attacker: TextureRect = active_actors[attacker_id]
	var target: TextureRect = active_actors[target_id]
	var orig_attacker_pos = attacker.position

	var dir = sign(target.position.x - attacker.position.x)
	if dir == 0: dir = 1.0

	actor_stage.move_child(attacker, -1)

	var tween = create_tween()

	# anticipation wind up
	tween.tween_property(attacker, "position:x", orig_attacker_pos.x - (dir * 60.0), 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# fast strike lunge
	var hit_pos = target.position.x - (dir * 80.0)
	tween.tween_property(attacker, "position:x", hit_pos, 0.1)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# ***********************[3. the impact]
	tween.tween_callback(func():
		shake(0.2, 25.0)
		active_actors.erase(target_id)

		var target_fly = create_tween().set_parallel(true)

		# knockback
		target_fly.tween_property(target, "position:x", target.position.x + (dir * 800.0), 0.5)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

		# fall out of frame
		target_fly.tween_property(target, "position:y", target.position.y + 300.0, 0.5)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		# knock down tilt
		target_fly.tween_property(target, "rotation_degrees", dir * 90.0, 0.5)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

		target_fly.chain().tween_callback(target.queue_free)
	)

	# ***************************[4. follow-through & recovery]
	tween.tween_interval(0.3)

	# step back to origin
	tween.tween_property(attacker, "position:x", orig_attacker_pos.x, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func show_patreon_button():
	if is_instance_valid(patreon_btn): return

	var tex = load("res://Icons/patreon_logo.png")
	if not tex:
		push_warning("Could not load Patreon logo at res://Icons/patreon_logo.png")
		return

	# set icon width
	var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")

	patreon_btn = Button.new()
	patreon_btn.text = " Support on Patreon"
	patreon_btn.icon = tex
	patreon_btn.add_theme_constant_override("icon_max_width", 96)
	patreon_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	patreon_btn.add_theme_constant_override("h_separation", 18)

	# apply styles
	patreon_btn.add_theme_font_override("font", custom_font)
	patreon_btn.add_theme_font_size_override("font_size", 44 if OS.has_feature("mobile") else 36)
	patreon_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	patreon_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	patreon_btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	# build theme boxes
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	btn_normal.corner_radius_top_left = 12
	btn_normal.corner_radius_top_right = 12
	btn_normal.corner_radius_bottom_left = 12
	btn_normal.corner_radius_bottom_right = 12
	btn_normal.content_margin_left = 25
	btn_normal.content_margin_right = 35
	btn_normal.content_margin_top = 15
	btn_normal.content_margin_bottom = 15
	btn_normal.border_width_left = 3
	btn_normal.border_width_top = 3
	btn_normal.border_width_right = 3
	btn_normal.border_width_bottom = 3
	btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.0)

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.95)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.9)

	patreon_btn.add_theme_stylebox_override("normal", btn_normal)
	patreon_btn.add_theme_stylebox_override("hover", btn_hover)
	patreon_btn.add_theme_stylebox_override("focus", btn_hover)
	patreon_btn.add_theme_stylebox_override("pressed", btn_hover)

	# recalculate size
	patreon_btn.reset_size()

	# hover juice
	patreon_btn.mouse_entered.connect(func():
		var t = create_tween()
		t.tween_property(patreon_btn, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_SINE)
	)
	patreon_btn.mouse_exited.connect(func():
		var t = create_tween()
		t.tween_property(patreon_btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)
	)

	# *******************[click action]
	patreon_btn.pressed.connect(func():
		if SoundManager and SoundManager.has_method("play_sfx"):
			SoundManager.play_sfx("ui_click")
		OS.shell_open(PatreonWorldButton.PATREON_URL)
	)

	# **********************[critical fix: add to the dialogue balloon so it sits on layer 100!]
	if is_instance_valid(current_balloon):
		current_balloon.add_child(patreon_btn)
	else:
		$RootContainer.add_child(patreon_btn)

	# wait for layout pass
	await get_tree().process_frame

	# center pivot
	patreon_btn.pivot_offset = patreon_btn.size / 2.0

	# drop animation
	var screen_size = get_viewport().get_visible_rect().size
	var drop_y_factor: float = 0.58 if OS.has_feature("mobile") else 0.5
	var target_pos = Vector2(screen_size.x * 0.28 - (patreon_btn.size.x / 2.0), screen_size.y * drop_y_factor - (patreon_btn.size.y / 2.0))
	var start_pos = target_pos - Vector2(0, 1000)

	patreon_btn.position = start_pos

	var tween = create_tween()
	tween.tween_property(patreon_btn, "position", target_pos, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func hide_patreon_button():
	if is_instance_valid(patreon_btn):
		var tween = create_tween()
		tween.tween_property(patreon_btn, "position:y", patreon_btn.position.y + 1000, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_callback(patreon_btn.queue_free)

func center_patreon_button_and_keep_alive():
	if not is_instance_valid(patreon_btn): return

	var screen_size = get_viewport().get_visible_rect().size
	# horizontal and vertical alignment
	var target_pos = Vector2(screen_size.x * 0.5 - (patreon_btn.size.x / 2.0), screen_size.y * 0.65 - (patreon_btn.size.y / 2.0))

	var tween = create_tween()
	tween.tween_property(patreon_btn, "position", target_pos, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# rename for memory box reference
	patreon_btn.name = "PersistentPatreonBtn"

	# reparent to memory box
	var memory_box = get_parent()
	if is_instance_valid(memory_box):
		patreon_btn.reparent(memory_box, true)
		# null reference to prevent leak
		patreon_btn = null
