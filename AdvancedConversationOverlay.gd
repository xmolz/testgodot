extends CanvasLayer

@export var dialogue_resource: DialogueResource
@export var start_dialogue_id: String = "start"
@export var character_roster: Array[CharacterProfile] = []

var active_actors: Dictionary = {}

@onready var actor_stage: Control = $ActorStage
@onready var darken_backdrop: ColorRect = $DarkenBackdrop


func _ready():
	DialogueManager.show_dialogue_balloon_scene(
		load("res://conversationballoon.tscn"),
		dialogue_resource,
		start_dialogue_id,
		[self]
	)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_ended(_resource: DialogueResource):
	DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)
	var tween = create_tween()
	tween.tween_property(darken_backdrop, "color:a", 0.0, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


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
