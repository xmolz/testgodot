extends CanvasLayer
class_name AdvancedConversationOverlay

signal conversation_finished(dialogue_resource: DialogueResource)
signal first_visuals_ready

@export var dialogue_resource: DialogueResource
@export var start_dialogue_id: String = "start"
@export var character_roster: Array[CharacterProfile] = []
@export var background_aliases: Dictionary = {}
@export var cg_aliases: Dictionary = {}
## step 2.186: scene CGs. alias -> .tscn path. show_scene_cg() instances the scene just above
## the CG layer; dialogue drives it with scene_cg_call().
@export var scene_cg_aliases: Dictionary = {}
## the scene CG currently on screen (null when none).
var scene_cg: Node = null
@export var mental_image_shader: ShaderMaterial

# when false, _ready() will NOT spawn the balloon. the owner must call begin_conversation()
# itself. ChapterLaunchSequence uses this so the dialogue cannot start underneath the portal.
@export var autostart: bool = true

# optional opening visuals, staged before the first line runs. lets the launch pipeline put the
# first CG on screen while the portal flash still hides it, so the art is already there when the
# flash clears. leave empty to skip.
@export var prestage_background: String = ""
@export var prestage_cg: String = ""

# dream haze intensity to arm before the portal flash clears. 0.0 = no dream.
@export var prestage_dream: float = 0.0

# step 2.326: optional room treatment, set per overlay. background_dim multiplies the background picture
# (darker, without the milky look of a grey layer on top); vignette_strength (0..1) darkens the edges of
# the picture. both sit under the characters, so the sprites keep their own colours.
@export var background_dim: Color = Color(1, 1, 1, 1)
@export_range(0.0, 1.0, 0.05) var vignette_strength: float = 0.0

var _conversation_started: bool = false

var active_actors: Dictionary = {}

var _scan_active: bool = false
var _scan_time: float = 0.0
var _scan_tween: Tween

var current_balloon: Node = null

# extra game states appended after self when begin_conversation() spawns the balloon. the
# launch pipeline uses this to expose the wake CG layer's mutations to the dialogue. must be
# set BEFORE begin_conversation() runs.
var extra_game_states: Array = []

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
@onready var dream_haze: ColorRect = $DreamHaze
@onready var eyelid_overlay: ColorRect = $EyelidOverlay

var _dream_mat: ShaderMaterial = null
var _eyelid_mat: ShaderMaterial = null
var _dream_tween: Tween = null
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

# ----------- party staging: protagonist + following companion share one side.
# the companion stands in a back row (outward, behind, smaller, dimmer) and steps
# forward while she is the one speaking. numbers are first guesses — tune by feel.
const PROTAGONIST_ACTOR_ID: String = "Fiona"
const PARTY_BACK_ROW_SCALE: float = 0.86
const PARTY_FRONT_STEP_SCALE: float = 0.94
const PARTY_BACK_ROW_DIM := Color(0.8, 0.8, 0.8, 1.0)
const PARTY_BACK_ROW_OFFSET: float = 230.0   # px outward of the protagonist's slot
const PARTY_STANCE_TIME: float = 0.2
const PARTY_STAGED_FLAG: String = "party_companion_staged"   # level flag dialogues can branch on

var _party_companion_id: String = ""
var _party_companion_front: bool = false
var _party_stance_tween: Tween = null


func _ready():
	if is_instance_valid(darken_backdrop):
		darken_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(solid_background):
		solid_background.mouse_filter = Control.MOUSE_FILTER_STOP

	_shake_rng.randomize()

	# the dream/eyelid materials are scene sub-resources and are shared between instances of
	# this scene, so reset their uniforms explicitly rather than trusting the saved defaults.
	if is_instance_valid(dream_haze):
		_dream_mat = dream_haze.material as ShaderMaterial
		if _dream_mat:
			_dream_mat.set_shader_parameter("amount", 0.0)
		dream_haze.visible = false

	if is_instance_valid(eyelid_overlay):
		_eyelid_mat = eyelid_overlay.material as ShaderMaterial
		if _eyelid_mat:
			_eyelid_mat.set_shader_parameter("openness", 1.0)
		eyelid_overlay.visible = false

	# step 2.326: the room treatment, before anything is shown
	_apply_room_treatment()

	if autostart:
		begin_conversation()

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


# spawns the balloon and starts the dialogue. safe to call twice; the second call is ignored.
func begin_conversation() -> void:
	if _conversation_started:
		return
	_conversation_started = true

	current_balloon = DialogueManager.show_dialogue_balloon_scene(
		preload("res://conversation/conversationballoon.tscn"),
		dialogue_resource,
		start_dialogue_id,
		[self] + extra_game_states
	)

	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	if not DialogueManager.got_dialogue.is_connected(_on_got_dialogue):
		DialogueManager.got_dialogue.connect(_on_got_dialogue)


# puts the opening background/CG on screen instantly, without starting the dialogue.called by
# ChapterLaunchSequence while the portal flash is still opaque, so the flash clears onto a
# fully formed scene with no pop.
func prestage_visuals() -> void:
	if not prestage_background.is_empty():
		await change_background(prestage_background, "none", 0.0)
	if not prestage_cg.is_empty():
		await show_cg(prestage_cg, "none", 0.0)
	if prestage_dream > 0.0:
		await dream_set(prestage_dream, 0.0)
	await get_tree().process_frame


func _process(delta: float):
	_update_actor_skirts()
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
	if is_instance_valid(scene_cg):
		tween.tween_property(scene_cg, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

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

	var tex_path: String = _expression_path(profile, emotion)
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
	rect.pivot_offset = Vector2(tex_size.x * profile.canvas_anchor_x, tex_size.y)

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

	var tex_path: String = _expression_path(profile, emotion)
	if not tex_path.is_empty():
		var tex: Texture2D = await _get_texture_async(tex_path)
		if tex:
			var rect: TextureRect = active_actors[actor_id]
			rect.texture = tex
			_apply_talking(actor_id)   # step 2.401: still mid-line? the new picture talks too


# step 2.267: fast-forward safety (Ctrl held, or quick clicks). an effect or a focus/unfocus that
# started while another was still tweening the same actor used to read the half-finished pose as
# its resting pose, so the actor could stay floating, squashed, oversized or zoomed in. every
# effect tween and the focus/unfocus tween are now tracked, and a new one settles the old first.
var _actor_effect_tweens: Dictionary = {}   # actor_id -> Tween
var _focus_tween: Tween = null


# runs a tween to its end state at once (its callbacks fire), then stops it.
func _finish_tween(t: Tween) -> void:
	if t != null and t.is_valid():
		t.custom_step(1000.0)
	if t != null and t.is_valid():
		t.kill()


func _new_effect_tween(actor_id: String) -> Tween:
	var t := create_tween()
	_actor_effect_tweens[actor_id] = t
	return t


# finishes running effect tweens: one actor's, or everyone's when actor_id is "".
func _settle_actor_effects(actor_id: String = "") -> void:
	for id in _actor_effect_tweens.keys():
		if actor_id == "" or id == actor_id:
			_finish_tween(_actor_effect_tweens[id])
			_actor_effect_tweens.erase(id)


# step 2.415: Layla's hops (the jump and bounce effects) get a little jump sound now and then. a sound on
# every hop got repetitive, so it never plays twice within HOP_SFX_GAP seconds, and each one is pitched a
# touch higher or lower.
const HOP_SFX := "jump_sound_effect"
const HOP_SFX_GAP := 6.0
var _last_hop_sfx_ms: int = -100000

func _hop_sound(actor_id: String) -> void:
	if actor_id != "Layla" or not SoundManager:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_hop_sfx_ms < int(HOP_SFX_GAP * 1000.0):
		return
	_last_hop_sfx_ms = now
	SoundManager.play_sfx(HOP_SFX, randf_range(0.94, 1.08))


func actor_effect(actor_id: String, effect_name: String) -> void:
	if not active_actors.has(actor_id):
		push_warning("AdvancedConversationOverlay: Actor '%s' not found." % actor_id)
		return

	var rect: TextureRect = active_actors[actor_id]

	# step 2.267: let anything still moving this actor land first, so the pose read below is real.
	_settle_actor_effects(actor_id)
	# step 2.375: remembered so a party stance change can tell whether this effect changes her size
	_actor_effect_names[actor_id] = effect_name
	_finish_tween(_focus_tween)
	_focus_tween = null
	_finish_tween(_party_stance_tween)
	if _approach_tweens.has(actor_id):
		_finish_tween(_approach_tweens[actor_id])

	if effect_name == "shock":
		var original_x = rect.position.x
		var base_s = rect.scale
		var peak_s = base_s * 1.05

		var tween = _new_effect_tween(actor_id)
		tween.tween_property(rect, "scale", peak_s, 0.05)
		tween.tween_property(rect, "position:x", original_x + 15.0, 0.025)
		tween.tween_property(rect, "position:x", original_x - 15.0, 0.05)
		tween.tween_property(rect, "position:x", original_x + 10.0, 0.025)
		tween.tween_property(rect, "position:x", original_x - 10.0, 0.025)
		tween.tween_property(rect, "position:x", original_x, 0.025)
		tween.tween_property(rect, "scale", base_s, 0.05)
	elif effect_name == "jump":
		# a hop: feet leave the stage line and land with a small bounce
		_hop_sound(actor_id)   # step 2.415
		var y0: float = rect.position.y
		var t = _new_effect_tween(actor_id)
		t.tween_property(rect, "position:y", y0 - 70.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(rect, "position:y", y0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	elif effect_name == "tremble":
		# fast small side-to-side shiver, ends exactly where it started
		var x0: float = rect.position.x
		var t = _new_effect_tween(actor_id)
		for i in 10:
			t.tween_property(rect, "position:x", x0 + (5.0 if i % 2 == 0 else -5.0), 0.035)
		t.tween_property(rect, "position:x", x0, 0.035)
	elif effect_name == "slump":
		# shoulders drop: squash a little on y (bottom pivot keeps the feet planted), then recover
		var s0: Vector2 = rect.scale
		var t = _new_effect_tween(actor_id)
		# step 2.218: y only, so a turn/flip during the squash is not undone
		t.tween_property(rect, "scale:y", s0.y * 0.955, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(rect, "scale:y", s0.y, 0.7).set_delay(0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif effect_name == "bounce":
		# step 2.216: excited double hop
		_hop_sound(actor_id)   # step 2.415
		var yb: float = rect.position.y
		var tb = _new_effect_tween(actor_id)
		tb.tween_property(rect, "position:y", yb - 45.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tb.tween_property(rect, "position:y", yb, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tb.tween_property(rect, "position:y", yb - 28.0, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tb.tween_property(rect, "position:y", yb, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	elif effect_name == "lean_in":
		# step 2.216: tilt from the feet toward the way she faces, and hold. undo with "upright".
		var facing: float = 1.0 if rect.scale.x >= 0.0 else -1.0
		_actor_tilt(rect, deg_to_rad(LEAN_IN_DEGREES) * facing, 0.3)
	elif effect_name == "upright":
		_actor_tilt(rect, 0.0, 0.3)
	elif effect_name == "shy":
		# step 2.218: re-reads the flip sign every frame, so a turn/flip mid-shrink sticks
		var shy_base := Vector2(absf(rect.scale.x), rect.scale.y)
		var apply_shy := func(f: float) -> void:
			if is_instance_valid(rect):
				var sx: float = -1.0 if rect.scale.x < 0.0 else 1.0
				rect.scale = Vector2(sx * shy_base.x * f, shy_base.y * f)
		var ts = _new_effect_tween(actor_id)
		ts.tween_method(apply_shy, 1.0, 0.97, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		ts.tween_method(apply_shy, 0.97, 1.0, 0.8).set_delay(0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif effect_name == "nod":
		# step 2.216: two small dips on y
		var s_nod: Vector2 = rect.scale
		var tn = _new_effect_tween(actor_id)
		for i in 2:
			tn.tween_property(rect, "scale:y", s_nod.y * 0.982, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tn.tween_property(rect, "scale:y", s_nod.y, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif effect_name == "turn_away" or effect_name == "turn_back":
		# step 2.218: face away from / back toward the middle of the stage. absolute, not a toggle,
		# so repeating it is harmless and it works from either side. sprites face right at scale.x > 0.
		var center_marker = actor_stage.get_node_or_null("SlotCenter")
		var center_x: float = center_marker.position.x if center_marker else 960.0
		var anchor_x: float = rect.position.x + rect.pivot_offset.x
		var toward: float = -1.0 if anchor_x > center_x else 1.0
		var want: float = toward if effect_name == "turn_back" else -toward
		rect.scale = Vector2(absf(rect.scale.x) * want, rect.scale.y)
	else:
		push_warning("actor_effect: unknown effect '%s'." % effect_name)


func actor_walk_in(actor_id: String, emotion: String, slot_name: String, scale_modifier: float = 1.0):
	var profile = get_profile(actor_id)
	if not profile:
		push_warning("Actor profile not found: " + actor_id)
		return

	var tex_path: String = _expression_path(profile, emotion)
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
	rect.pivot_offset = Vector2(tex_size.x * profile.canvas_anchor_x, tex_size.y)

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


# ---------------------------------------------------------------------------
# step 2.326: gentle movement, for people walking into and around a room at an easy pace.
#   actor_stroll_in("Fiona", "base", "center", 2.6)       walks in from the left edge (through a door),
#                                                          fading in over her first steps
#   actor_stroll_in("Layla", "base", "center_left", 2.2, "left", true)   ...flipped (mirrored) from the start,
#                                                          e.g. so she faces the way she walks
#   actor_stroll_to("Fiona", "right", 1.4)                 a few steps to another spot
#   actor_stroll_out("Fiona", "right", 2.0)                walks off that side, fading out at the end
# slots: "left", "center", "right" (the stage markers), "center_left", "center_right", or (step 2.327) a
# number in quotes for a spot across the screen, 0 = left edge to 1 = right edge, e.g. "0.3".
# step 2.333: or "x,y" for a spot across AND down, where her feet (the bottom of her sprite) go: "0.25,0.53".
#   for depth: further back = smaller (size) and higher on screen. size is 1 = her normal height.
#   actor_stroll_in("Fiona", "base", "0.22,0.53", 3.0, "right", true, 0.55, true)   small, behind the
#       background occluder (background_occluder), so the sofa hides her below the line
#   actor_stroll_to("Fiona", "0.5,0.62", 1.6, 0.8)    closer: moves down the screen and grows to 0.8
# each eases in and out, with a slight walking bob, and the dialogue waits until the walk is done.
const STROLL_BOB_PX := 6.0
const STROLL_STEP_SECONDS := 0.5

func _stroll_slot_feet(slot_name: String) -> Vector2:
	# step 2.333: "x,y" - a spot across and down the screen (0..1 each)
	if slot_name.contains(","):
		var parts: PackedStringArray = slot_name.split(",")
		if parts.size() == 2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float():
			var vp: Vector2 = get_viewport().get_visible_rect().size
			return Vector2(vp.x * parts[0].strip_edges().to_float(), vp.y * parts[1].strip_edges().to_float())
	# step 2.327: a number is a spot across the screen: 0 = left edge, 1 = right edge (e.g. "0.3")
	if slot_name.is_valid_float():
		return Vector2(get_viewport().get_visible_rect().size.x * slot_name.to_float(), 1080)
	match slot_name.to_lower():
		"center_right":
			return Vector2(1200, 1080)
		"center_left":
			return Vector2(720, 1080)
	var marker = actor_stage.get_node_or_null("Slot" + slot_name.capitalize())
	if not marker:
		push_warning("Could not find slot marker: Slot" + slot_name.capitalize())
		marker = actor_stage.get_node("SlotCenter")
	return marker.position

func _stroll_bob(rect: Control, base_y: float, duration: float, amplitude: float = STROLL_BOB_PX) -> void:
	var steps: int = maxi(1, int(round(duration / STROLL_STEP_SECONDS)))
	var half: float = duration / float(steps) * 0.5
	var bob := create_tween()
	for i in steps:
		bob.tween_property(rect, "position:y", base_y - amplitude, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		bob.tween_property(rect, "position:y", base_y, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func actor_stroll_in(actor_id: String, emotion: String, slot_name: String, duration: float = 2.4, from_side: String = "left", flipped: bool = false, size: float = 1.0, behind: bool = false) -> void:
	var profile = get_profile(actor_id)
	if not profile:
		push_warning("Actor profile not found: " + actor_id)
		return
	var tex_path: String = _expression_path(profile, emotion)
	if tex_path.is_empty():
		push_warning("Emotion '" + emotion + "' not found for actor: " + actor_id)
		return
	var tex: Texture2D = await _get_texture_async(tex_path)
	if not tex:
		push_warning("Failed to load texture: " + tex_path)
		return

	var rect = TextureRect.new()
	rect.texture = tex
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var tex_size: Vector2 = tex.get_size()
	var base_scale: float = screen_size.y / float(tex_size.y) * profile.default_scale
	var final_scale: float = base_scale * size
	rect.scale = Vector2(-final_scale if flipped else final_scale, final_scale)
	rect.pivot_offset = Vector2(tex_size.x * profile.canvas_anchor_x, tex_size.y)
	rect.set_meta("stroll_base_scale", base_scale)
	actor_stage.add_child(rect)
	active_actors[actor_id] = rect
	# step 2.333: behind everyone else (and behind a background occluder), e.g. walking behind the sofa
	if behind:
		actor_stage.move_child(rect, 0)

	var target_pos: Vector2 = _stroll_slot_feet(slot_name) - rect.pivot_offset
	# start with her feet just past the screen edge she comes in from
	var start_feet_x: float = -120.0 if from_side.to_lower() != "right" else screen_size.x + 120.0
	rect.position = Vector2(start_feet_x - rect.pivot_offset.x, target_pos.y)
	rect.modulate.a = 0.0

	var walk := create_tween().set_parallel(true)
	walk.tween_property(rect, "position:x", target_pos.x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	walk.tween_property(rect, "modulate:a", 1.0, minf(0.7, duration * 0.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_stroll_bob(rect, target_pos.y, duration, STROLL_BOB_PX * size)
	await walk.finished

# step 2.333: size > 0 also grows/shrinks her to that size on the way (closer/further); a spot with no
# height ("left", "0.3") keeps her at her current height on screen.
# step 2.342: easing - "in_out" (default: eases in and out), "linear" (steady pace the whole way, e.g.
# walking on from off-screen and stopping dead - follow with actor_halt), "in" (speeds up, stops dead).
func actor_stroll_to(actor_id: String, slot_name: String, duration: float = 1.4, size: float = -1.0, easing: String = "in_out") -> void:
	if not active_actors.has(actor_id):
		push_warning("Cannot stroll actor, not found on stage: " + actor_id)
		return
	var rect: TextureRect = active_actors[actor_id]
	var feet: Vector2 = _stroll_slot_feet(slot_name)
	if not slot_name.contains(","):
		feet.y = rect.position.y + rect.pivot_offset.y
	var from_pos: Vector2 = rect.position
	var to_pos: Vector2 = feet - rect.pivot_offset
	var from_scale: Vector2 = rect.scale
	var to_scale: Vector2 = from_scale
	var base: float = _stroll_base_scale(actor_id, rect)
	if size > 0.0 and base > 0.0:
		to_scale = Vector2(signf(from_scale.x) * base * size, base * size)
	var steps: int = maxi(1, int(round(duration / STROLL_STEP_SECONDS)))
	var walk := create_tween()
	walk.tween_method(func(k: float):
		if not is_instance_valid(rect):
			return
		var e: float = 0.5 - 0.5 * cos(PI * k)
		if easing == "linear":
			e = k
		elif easing == "in":
			e = 1.0 - cos(PI * 0.5 * k)
		var sc: Vector2 = from_scale.lerp(to_scale, e)
		var bob: float = STROLL_BOB_PX * absf(sc.y) / maxf(base, 0.0001) * absf(sin(PI * k * float(steps)))
		rect.scale = sc
		rect.position = from_pos.lerp(to_pos, e) - Vector2(0.0, bob)
	, 0.0, 1.0, duration)
	await walk.finished

# her normal scale (size 1), from the stroll that brought her in or from her profile
func _stroll_base_scale(actor_id: String, rect: TextureRect) -> float:
	if rect.has_meta("stroll_base_scale"):
		return float(rect.get_meta("stroll_base_scale"))
	var profile = get_profile(actor_id)
	if profile and rect.texture:
		return float(get_viewport().get_visible_rect().size.y) / float(rect.texture.get_height()) * profile.default_scale
	return absf(rect.scale.y)

func actor_stroll_out(actor_id: String, direction: String = "right", duration: float = 2.0) -> void:
	if not active_actors.has(actor_id):
		return
	var rect: TextureRect = active_actors[actor_id]
	active_actors.erase(actor_id)
	var screen_w: float = get_viewport().get_visible_rect().size.x
	var target_feet_x: float = screen_w + 120.0 if direction.to_lower() == "right" else -120.0
	var walk := create_tween().set_parallel(true)
	walk.tween_property(rect, "position:x", target_feet_x - rect.pivot_offset.x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	walk.tween_property(rect, "modulate:a", 0.0, minf(0.7, duration * 0.4)).set_delay(maxf(0.0, duration - minf(0.7, duration * 0.4)))
	_stroll_bob(rect, rect.position.y, duration, STROLL_BOB_PX * absf(rect.scale.y) / maxf(_stroll_base_scale(actor_id, rect), 0.0001))
	await walk.finished
	if is_instance_valid(rect):
		rect.queue_free()

# ---------------------------------------------------------------------------
# step 2.328: seated close shots. stage these under black (fade_to_black, change_background, actor_sit,
# fade_from_black); a seated actor is drawn bigger and lowered so the bottom of the screen cuts her off
# around the waist, with the sofa's backrest behind her.
#   actor_sit("Layla", "base", "0.32", 1.3, 0.35)          zoom 1.3x, the lowest 35% of her below the screen
#   actor_sit("Fiona", "base", "0.68", 1.3, 0.35, true)    ...flipped (mirrored)
#   actor_rise("Fiona", 0.7)                                she stands up (rises by what was hidden)
# spots work like the stroll commands: "left", "center", "right", "center_left", "center_right" or "0.3".
func actor_sit(actor_id: String, emotion: String, spot: String, zoom: float = 1.3, sink: float = 0.35, flipped: bool = false) -> void:
	if active_actors.has(actor_id):
		actor_hide(actor_id)
	var profile = get_profile(actor_id)
	if not profile:
		push_warning("Actor profile not found: " + actor_id)
		return
	var tex_path: String = _expression_path(profile, emotion)
	if tex_path.is_empty():
		push_warning("Emotion '" + emotion + "' not found for actor: " + actor_id)
		return
	var tex: Texture2D = await _get_texture_async(tex_path)
	if not tex:
		push_warning("Failed to load texture: " + tex_path)
		return

	var rect = TextureRect.new()
	rect.texture = tex
	var screen_h: float = float(get_viewport().get_visible_rect().size.y)
	var tex_size: Vector2 = tex.get_size()
	var final_scale: float = screen_h / float(tex_size.y) * profile.default_scale * zoom
	rect.scale = Vector2(-final_scale if flipped else final_scale, final_scale)
	rect.pivot_offset = Vector2(tex_size.x * profile.canvas_anchor_x, tex_size.y)
	actor_stage.add_child(rect)
	active_actors[actor_id] = rect

	# her feet go this far below the bottom of the screen
	var sunk_px: float = tex_size.y * final_scale * clampf(sink, 0.0, 0.9)
	var feet: Vector2 = _stroll_slot_feet(spot)
	rect.position = Vector2(feet.x, feet.y + sunk_px) - rect.pivot_offset
	rect.set_meta("sit_sunk_px", sunk_px)
	rect.modulate.a = 1.0

# step 2.336: to_feet_y (0..1 down the screen, like the "x,y" spots) stops her where her feet reach
# that height instead of rising by everything that was hidden - e.g. to stand level with someone.
func actor_rise(actor_id: String, duration: float = 0.7, to_feet_y: float = -1.0) -> void:
	if not active_actors.has(actor_id):
		push_warning("Cannot raise actor, not found on stage: " + actor_id)
		return
	var rect: TextureRect = active_actors[actor_id]
	var rise_px: float = float(rect.get_meta("sit_sunk_px", 0.0))
	if to_feet_y >= 0.0:
		var feet_now: float = rect.position.y + rect.pivot_offset.y
		rise_px = feet_now - to_feet_y * float(get_viewport().get_visible_rect().size.y)
	if rise_px <= 0.0:
		return
	rect.set_meta("sit_sunk_px", 0.0)
	var up := create_tween()
	up.tween_property(rect, "position:y", rect.position.y - rise_px, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await up.finished

# ---------------------------------------------------------------------------
# step 2.330: framing the background - zoom into part of it and soften it (depth of field).
#   background_view(1.6, 0.615, 0.49, 4.0)          zoom 1.6x on that point (0..1 across, down), 4 px blur, instantly
#   background_view(1.6, 0.615, 0.49, 4.0, 1.2)     ...the same, eased in over 1.2 s
#   background_view()                                back to the whole, sharp picture
# the room tint (background_dim) and the vignette are unaffected.
const BackgroundViewShader = preload("res://conversation/background_view.gdshader")
var _bg_view_mat: ShaderMaterial = null
var _bg_view: Vector4 = Vector4(1.0, 0.5, 0.5, 0.0)  # zoom, centre x, centre y, blur

func background_view(zoom: float = 1.0, center_x: float = 0.5, center_y: float = 0.5, blur_px: float = 0.0, duration: float = 0.0) -> void:
	if not is_instance_valid(background_layer):
		return
	if _bg_view_mat == null:
		_bg_view_mat = ShaderMaterial.new()
		_bg_view_mat.shader = BackgroundViewShader
		background_layer.material = _bg_view_mat
	var target := Vector4(zoom, center_x, center_y, blur_px)
	if duration <= 0.0:
		_set_bg_view(target)
	else:
		var tw := create_tween()
		tw.tween_method(_set_bg_view, _bg_view, target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	if is_equal_approx(zoom, 1.0) and blur_px <= 0.0 and is_instance_valid(background_layer):
		background_layer.material = null
		_bg_view_mat = null

func _set_bg_view(v: Vector4) -> void:
	_bg_view = v
	if _bg_view_mat:
		_bg_view_mat.set_shader_parameter("zoom", v.x)
		_bg_view_mat.set_shader_parameter("center", Vector2(v.y, v.z))
		_bg_view_mat.set_shader_parameter("blur_px", v.w)

# step 2.330: a foreground layer in front of the characters (under the dialogue box), e.g. a table so
# standing poses read as seated. names come from foreground_aliases: a full-screen image with
# transparency (the table at the bottom). step 2.413: the stand-in drawn in code is gone.
#   show_foreground("table")          instantly (stage it under black)
#   show_foreground("table", 0.5)     ...or fading in
#   hide_foreground(0.5)
@export var foreground_aliases: Dictionary = {}
var _foreground: Control = null

func show_foreground(fg_name: String, duration: float = 0.0) -> void:
	if is_instance_valid(_foreground):
		_foreground.queue_free()
		_foreground = null
	var entry = foreground_aliases.get(fg_name, fg_name)
	var node: Control = null
	var source: String = String(entry)
	var tex: Texture2D = await _get_texture_async(source) if ResourceLoader.exists(source) else null
	if tex == null:
		push_warning("show_foreground: no foreground alias or image '%s'." % fg_name)
		return
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tex_aspect: float = float(tex.get_width()) / float(tex.get_height())
	if tex_aspect > vp.x / vp.y + 0.01:
		# step 2.350: a strip wider than the screen - a full-screen drawing with its empty top cropped
		# off - is laid along the bottom of the screen at full width, so it lines up as drawn
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		var holder := Control.new()
		holder.add_child(rect)
		rect.anchor_left = 0.0
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		rect.anchor_top = 1.0 - (vp.x / tex_aspect) / vp.y
		rect.offset_left = 0.0
		rect.offset_right = 0.0
		rect.offset_top = 0.0
		rect.offset_bottom = 0.0
		node = holder
	else:
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		node = rect
	node.name = "Foreground"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(node)
	# right in front of the characters, behind CGs and fades
	move_child(node, actor_stage.get_index() + 1)
	_foreground = node
	# step 2.352: the table props stand on the table, so they come back with it, just in front of it
	if is_instance_valid(_table_props):
		move_child(_table_props, node.get_index() + 1)
		_table_props.visible = true
		_table_props.modulate.a = 1.0
	if duration > 0.0:
		node.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(node, "modulate:a", 1.0, duration)
		if is_instance_valid(_table_props):
			_table_props.modulate.a = 0.0
			tw.tween_property(_table_props, "modulate:a", 1.0, duration)
		await tw.finished

func hide_foreground(duration: float = 0.0) -> void:
	if not is_instance_valid(_foreground):
		return
	var node: Control = _foreground
	_foreground = null
	if duration > 0.0:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(node, "modulate:a", 0.0, duration)
		# step 2.352: the table props on the table go with it
		if is_instance_valid(_table_props):
			tw.tween_property(_table_props, "modulate:a", 0.0, duration)
		await tw.finished
	if is_instance_valid(node):
		node.queue_free()
	if is_instance_valid(_table_props):
		_table_props.visible = false

# ---------------------------------------------------------------------------
# step 2.352: table props - small pictures standing on the table (mugs, a laptop). each is drawn at the size it
# appears on a 3840x2160 reference, so it scales with the screen. they sit in front of the table and the
# characters, follow the camera tilt, and hide and come back with the table (hide_foreground /
# show_foreground). spot "x,y" (0..1 across, down): where the prop stands - the middle of its picture,
# at its lowest visible pixel. size scales it; flipped mirrors it; shadow puts a soft shadow under it.
# showing the same id again replaces it in place (e.g. a laptop opening).
#   do show_table_prop("laptop", "res://Backgrounds/Apartment/laptop_closed.png", "0.5,0.8")
#   do show_table_prop("mug_layla", "res://Backgrounds/Apartment/coffee_mug.png", "0.36,0.79", 1.0, true)
#   do hide_table_prop("mug_fiona")
const PROP_REFERENCE_HEIGHT := 2160.0
var _table_props: Control = null
var _table_prop_nodes: Dictionary = {}
var _table_prop_shadow_tex: GradientTexture2D = null

func _ensure_table_props() -> Control:
	if is_instance_valid(_table_props):
		return _table_props
	_table_props = Control.new()
	_table_props.name = "TableProps"
	_table_props.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_table_props.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_table_props)
	var after: Node = _foreground if is_instance_valid(_foreground) else actor_stage
	move_child(_table_props, after.get_index() + 1)
	# follow a camera tilt that is already on
	_table_props.position.y = _camera_tilt * float(get_viewport().get_visible_rect().size.y)
	_table_props.visible = is_instance_valid(_foreground)
	return _table_props

func show_table_prop(prop_id: String, image_path: String, spot: String, size: float = 1.0, flipped: bool = false, shadow: bool = true) -> void:
	if not ResourceLoader.exists(image_path):
		push_warning("show_table_prop: image not found: " + image_path)
		return
	var tex: Texture2D = await _get_texture_async(image_path)
	if not tex:
		push_warning("show_table_prop: failed to load: " + image_path)
		return
	hide_table_prop(prop_id)
	var props: Control = _ensure_table_props()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k: float = vp.y / PROP_REFERENCE_HEIGHT * size
	var tex_size: Vector2 = tex.get_size()
	var used := Rect2(Vector2.ZERO, tex_size)
	var img: Image = tex.get_image()
	if img:
		used = Rect2(img.get_used_rect())
	# the middle of the canvas, at its lowest visible pixel - so two drawings on the same canvas (a laptop
	# closed and open) swap without moving
	var anchor := Vector2(tex_size.x * 0.5, used.end.y)
	var feet: Vector2 = _stroll_slot_feet(spot)
	var holder := Control.new()
	holder.name = "Prop_" + prop_id
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shadow:
		if _table_prop_shadow_tex == null:
			var grad := Gradient.new()
			grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
			grad.colors = PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.22), Color(0, 0, 0, 0)])
			_table_prop_shadow_tex = GradientTexture2D.new()
			_table_prop_shadow_tex.gradient = grad
			_table_prop_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
			_table_prop_shadow_tex.fill_from = Vector2(0.5, 0.5)
			_table_prop_shadow_tex.fill_to = Vector2(1.0, 0.5)
			_table_prop_shadow_tex.width = 128
			_table_prop_shadow_tex.height = 128
		var sh := TextureRect.new()
		sh.texture = _table_prop_shadow_tex
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sh.stretch_mode = TextureRect.STRETCH_SCALE
		var sw: float = used.size.x * k * 1.05
		var shh: float = maxf(sw * 0.14, 6.0)
		var mid_x: float = (used.position.x + used.size.x * 0.5 - anchor.x) * k * (-1.0 if flipped else 1.0)
		sh.size = Vector2(sw, shh)
		# step 2.353: tucked under the prop (most of it hidden behind the picture, peeking out around the
		# base), not hanging below it
		sh.position = Vector2(feet.x + mid_x - sw * 0.5, feet.y - shh * 0.9)
		holder.add_child(sh)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.pivot_offset = anchor
	pic.scale = Vector2(-k if flipped else k, k)
	pic.position = feet - anchor
	holder.add_child(pic)
	props.add_child(holder)
	_table_prop_nodes[prop_id] = holder
	# step 2.353: nearer props (standing lower on the screen) are drawn in front of farther ones
	holder.set_meta("depth", feet.y)
	var order: Array = props.get_children()
	order.sort_custom(func(a, b): return float(a.get_meta("depth", 0.0)) < float(b.get_meta("depth", 0.0)))
	for i in order.size():
		props.move_child(order[i], i)

func hide_table_prop(prop_id: String) -> void:
	if _table_prop_nodes.has(prop_id):
		var old = _table_prop_nodes[prop_id]
		if is_instance_valid(old):
			old.queue_free()
		_table_prop_nodes.erase(prop_id)

# ---------------------------------------------------------------------------
# step 2.340: lean (tilt) a character around her feet, e.g. peeking around a corner. negative degrees
# tip her top to the left, positive to the right. actor_lean("Fiona", 0.0) straightens her up.
#   do actor_lean("Fiona", -8.0, 0.4)
func actor_lean(actor_id: String, degrees: float, duration: float = 0.4) -> void:
	if not active_actors.has(actor_id):
		push_warning("Cannot lean actor, not found on stage: " + actor_id)
		return
	var rect: Control = active_actors[actor_id]
	if duration <= 0.0:
		rect.rotation_degrees = degrees
		return
	var tw := create_tween()
	tw.tween_property(rect, "rotation_degrees", degrees, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

# step 2.371: a mild, endless wave on an actor - she sways from her base and a slow ripple runs up her,
# as if she's short-circuiting. it keeps going through expression changes, walks and effects until it is
# switched off. strength 1.0 = mild; speed 1.0 = normal; it fades in (and out) over fade seconds.
#   do actor_wobble("Layla")              start
#   do actor_wobble("Layla", 1.6, 1.3)    stronger and faster
#   do actor_wobble("Layla", 0.0)         settle her back (fades out, then the effect is removed)
const ACTOR_WOBBLE_SHADER = preload("res://conversation/actor_wobble.gdshader")

func actor_wobble(actor_id: String, strength: float = 1.0, speed: float = 1.0, fade: float = 0.6) -> void:
	if not active_actors.has(actor_id):
		push_warning("Cannot wobble actor, not found on stage: " + actor_id)
		return
	var rect: CanvasItem = active_actors[actor_id]
	var mat := rect.material as ShaderMaterial
	var has_wobble: bool = mat != null and mat.shader == ACTOR_WOBBLE_SHADER
	if strength <= 0.0:
		if not has_wobble:
			return
		if fade <= 0.0:
			rect.material = null
			return
		var tw_out := create_tween()
		tw_out.tween_property(mat, "shader_parameter/strength", 0.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_out.tween_callback(func() -> void:
			if is_instance_valid(rect) and rect.material == mat:
				rect.material = null)
		return
	if not has_wobble:
		mat = ShaderMaterial.new()
		mat.shader = ACTOR_WOBBLE_SHADER
		mat.set_shader_parameter("strength", 0.0)
		rect.material = mat
	mat.set_shader_parameter("speed", speed)
	if fade <= 0.0:
		mat.set_shader_parameter("strength", strength)
		return
	var tw := create_tween()
	tw.tween_property(mat, "shader_parameter/strength", strength, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# step 2.342: a sudden stop. right after a walk ends abruptly (actor_stroll_to with "linear" or "in"),
# her momentum tips her forward - the way she is facing - then she rocks back and settles.
#   do actor_halt("Fiona")          strength = how far she tips, in degrees
func actor_halt(actor_id: String, strength: float = 7.0) -> void:
	if not active_actors.has(actor_id):
		push_warning("Cannot halt actor, not found on stage: " + actor_id)
		return
	var rect: Control = active_actors[actor_id]
	# facing right (unflipped) = tip to the right (positive degrees); facing left = tip left
	var forward: float = strength if rect.scale.x >= 0.0 else -strength
	var tw := create_tween()
	tw.tween_property(rect, "rotation_degrees", forward, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "rotation_degrees", -forward * 0.3, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(rect, "rotation_degrees", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

# ---------------------------------------------------------------------------
# step 2.343: a smash cut through a white flash. make the cut's changes between the two:
#   do flash_in(0.06)        the screen goes white, fast
#   ...swap the shot...
#   do flash_out(0.3)
func flash_in(duration: float = 0.06, color: Color = Color.WHITE) -> void:
	if not fade_overlay:
		return
	fade_overlay.color = color
	fade_overlay.show()
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, duration)
	await tween.finished

func flash_out(duration: float = 0.3) -> void:
	if not fade_overlay:
		return
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

# step 2.343: any picture as a character on the stage - e.g. a two-person pose drawn as one image with a
# transparent background. placed like actor_sit: spot across ("0.5", or "x,y"), zoom = its height on
# screen relative to the screen's, sink = how much of it (0..0.9) goes below the bottom of the screen.
#   do actor_image("Pair", "res://Backgrounds/CG/layla_fiona_inspection.png", "0.5", 1.1, 0.08)
# remove it again with actor_hide("Pair").
func actor_image(actor_id: String, image_path: String, spot: String = "0.5", zoom: float = 1.0, sink: float = 0.0, flipped: bool = false) -> void:
	if active_actors.has(actor_id):
		actor_hide(actor_id)
	if not ResourceLoader.exists(image_path):
		push_warning("actor_image: image not found: " + image_path)
		return
	var tex: Texture2D = await _get_texture_async(image_path)
	if not tex:
		push_warning("actor_image: failed to load: " + image_path)
		return
	var rect := TextureRect.new()
	rect.texture = tex
	var screen_h: float = float(get_viewport().get_visible_rect().size.y)
	var tex_size: Vector2 = tex.get_size()
	var final_scale: float = screen_h / tex_size.y * zoom
	rect.scale = Vector2(-final_scale if flipped else final_scale, final_scale)
	rect.pivot_offset = Vector2(tex_size.x * 0.5, tex_size.y)
	rect.set_meta("stroll_base_scale", screen_h / tex_size.y)
	actor_stage.add_child(rect)
	active_actors[actor_id] = rect
	var sunk_px: float = tex_size.y * final_scale * clampf(sink, 0.0, 0.9)
	var feet: Vector2 = _stroll_slot_feet(spot)
	rect.position = Vector2(feet.x, feet.y + sunk_px) - rect.pivot_offset
	rect.set_meta("sit_sunk_px", sunk_px)

# step 2.343: a quick pop for impact - she (or the picture) starts `amount` bigger and settles to size.
# wait = false lets the next line run at once (e.g. pop while the flash fades).
func actor_pop(actor_id: String, amount: float = 0.06, duration: float = 0.25, wait: bool = true) -> void:
	if not active_actors.has(actor_id):
		return
	var rect: Control = active_actors[actor_id]
	var size_now: Vector2 = rect.scale
	rect.scale = size_now * (1.0 + amount)
	var tw := create_tween()
	tw.tween_property(rect, "scale", size_now, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if wait:
		await tw.finished

# step 2.343: mood overlays, in front of the characters (and any foreground), under CGs, fades and the
# dialogue box. strength 0 = off, 1 = full, reached over `duration` seconds.
#   do focus_lines(1.0, 0.0)     manga focus lines at the screen edges
#   do focus_lines(0.0, 1.5)     ...fading away
#   do heat_glow(1.0, 0.0)       a pink glow at the edges, pulsing like a heartbeat
const MoodShader = preload("res://conversation/mood_overlay.gdshader")
var _mood: ColorRect = null

func focus_lines(strength: float = 1.0, duration: float = 0.1) -> void:
	await _tween_mood("focus", strength, duration)

func heat_glow(strength: float = 1.0, duration: float = 0.6) -> void:
	await _tween_mood("heat", strength, duration)

func _ensure_mood() -> ColorRect:
	if is_instance_valid(_mood):
		return _mood
	_mood = ColorRect.new()
	_mood.name = "MoodOverlay"
	_mood.color = Color.WHITE
	_mood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mood.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = MoodShader
	_mood.material = mat
	add_child(_mood)
	var after: Node = _foreground if is_instance_valid(_foreground) else actor_stage
	# step 2.352: and in front of any table props
	if is_instance_valid(_table_props):
		after = _table_props
	move_child(_mood, after.get_index() + 1)
	return _mood

func _tween_mood(param: String, value: float, duration: float) -> void:
	var mat: ShaderMaterial = _ensure_mood().material
	# a parameter never set yet reads back as null (its default, 0)
	var current = mat.get_shader_parameter(param)
	var from: float = 0.0 if current == null else float(current)
	if duration <= 0.0:
		mat.set_shader_parameter(param, value)
		return
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter(param, v), from, value, duration)
	await tw.finished

# step 2.348: zoom a character - or an actor_image picture, e.g. one face in a two-person pose - in on a
# point of her picture. zoom = how many times bigger than she was before the first zoom; point_x/point_y =
# where in her picture (0..1 across, down) to zoom on, which lands at screen_x/screen_y (0..1). zoom 1.0
# puts her back exactly as she was. duration 0 = instantly (a cut).
#   do actor_zoom("Pair", 1.8, 0.39, 0.3, 0.4)     push in on the face at that point of the picture
#   do actor_zoom("Pair", 1.0, 0.5, 0.5, 0.0)      straight back out
func actor_zoom(actor_id: String, zoom: float, point_x: float = 0.5, point_y: float = 0.35, duration: float = 0.4, screen_x: float = 0.5, screen_y: float = 0.4) -> void:
	if not active_actors.has(actor_id):
		push_warning("Cannot zoom actor, not found on stage: " + actor_id)
		return
	var rect: TextureRect = active_actors[actor_id]
	if not rect.has_meta("zoom_home"):
		rect.set_meta("zoom_home", {"pos": rect.position, "scale": rect.scale})
	var home: Dictionary = rect.get_meta("zoom_home")
	var target_scale: Vector2 = home["scale"]
	var target_pos: Vector2 = home["pos"]
	var going_home: bool = is_equal_approx(zoom, 1.0)
	if not going_home:
		target_scale = home["scale"] * zoom
		var tex_size: Vector2 = rect.texture.get_size()
		var local: Vector2 = Vector2(tex_size.x * point_x, tex_size.y * point_y)
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var screen_pt: Vector2 = Vector2(vp.x * screen_x, vp.y * screen_y) - actor_stage.position
		# a point p of the picture is drawn at position + pivot + (p - pivot) * scale
		target_pos = screen_pt - rect.pivot_offset - (local - rect.pivot_offset) * target_scale
	if duration <= 0.0:
		rect.scale = target_scale
		rect.position = target_pos
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(rect, "scale", target_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(rect, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tw.finished
	if going_home and is_instance_valid(rect):
		rect.remove_meta("zoom_home")

# ---------------------------------------------------------------------------
# step 2.336: a small camera move. amount > 0 tilts the camera up: the characters and the foreground move
# down the screen by that much (0..1 of the screen height), the zoomed background by background_follow
# of it (less, so it reads as depth). camera_tilt(0.0) puts it back. wait = false lets the next line
# start straight away, e.g. so someone stands up while the camera moves:
#   do camera_tilt(0.09, 0.9, 0.6, false)
#   do actor_rise("Layla", 0.8, 1.12)
# the background only moves while a background_view is on, and never so far that its edge shows.
var _camera_tilt: float = 0.0
var _camera_tilt_tween: Tween

func camera_tilt(amount: float, duration: float = 0.9, background_follow: float = 0.6, wait: bool = true) -> void:
	if not is_instance_valid(actor_stage):
		return
	var vp_h: float = float(get_viewport().get_visible_rect().size.y)
	var from: float = _camera_tilt
	var stage_y0: float = actor_stage.position.y - from * vp_h
	var fg_y0: float = 0.0
	if is_instance_valid(_foreground):
		fg_y0 = _foreground.position.y - from * vp_h
	# step 2.352: the table props on the table move with it
	var props_y0: float = 0.0
	if is_instance_valid(_table_props):
		props_y0 = _table_props.position.y - from * vp_h
	var bg_cy0: float = _bg_view.z + from * background_follow / maxf(_bg_view.x, 1.0)
	if _camera_tilt_tween and _camera_tilt_tween.is_valid():
		_camera_tilt_tween.kill()
	_camera_tilt_tween = create_tween()
	_camera_tilt_tween.tween_method(func(t: float):
		_camera_tilt = t
		if is_instance_valid(actor_stage):
			actor_stage.position.y = stage_y0 + t * vp_h
		if is_instance_valid(_foreground):
			_foreground.position.y = fg_y0 + t * vp_h
		if is_instance_valid(_table_props):
			_table_props.position.y = props_y0 + t * vp_h
		if _bg_view_mat:
			var v: Vector4 = _bg_view
			v.z = bg_cy0 - t * background_follow / maxf(v.x, 1.0)
			_set_bg_view(v)
	, from, amount, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if wait:
		await _camera_tilt_tween.finished

# ---------------------------------------------------------------------------
# step 2.333: depth. background_occluder(line_y) puts a copy of the background's lower part - everything
# below line_y (0..1 down the screen) - among the characters, pixel-identical to the background (same
# zoom/blur, dim and vignette). anyone placed behind it (actor_stroll_in(..., behind = true), or
# actor_to_back) is hidden below that line, e.g. walking behind the sofa with the backrest hiding her legs.
# characters placed after it stand in front of it. clear_background_occluder() removes it.
var _occluder: Control = null

func background_occluder(line_y: float) -> void:
	clear_background_occluder()
	if not is_instance_valid(background_layer) or not is_instance_valid(actor_stage):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var clip := Control.new()
	clip.name = "BackgroundOccluder"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = Vector2(0.0, vp.y * line_y) - actor_stage.position
	clip.size = Vector2(vp.x, vp.y * (1.0 - line_y))
	var copy := TextureRect.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.texture = background_layer.texture
	copy.expand_mode = background_layer.expand_mode
	copy.stretch_mode = background_layer.stretch_mode
	copy.material = background_layer.material
	copy.self_modulate = background_layer.self_modulate
	copy.position = background_layer.position - (clip.position + actor_stage.position)
	copy.size = background_layer.size
	clip.add_child(copy)
	if is_instance_valid(_vignette):
		var vig: Control = _vignette.duplicate()
		copy.add_child(vig)
	actor_stage.add_child(clip)
	actor_stage.move_child(clip, 0)
	_occluder = clip

func clear_background_occluder() -> void:
	if is_instance_valid(_occluder):
		_occluder.queue_free()
	_occluder = null

# step 2.333: draw order among the characters (and the occluder): to_back = behind everyone
func actor_to_back(actor_id: String) -> void:
	if active_actors.has(actor_id):
		actor_stage.move_child(active_actors[actor_id], 0)

func actor_to_front(actor_id: String) -> void:
	if active_actors.has(actor_id):
		actor_stage.move_child(active_actors[actor_id], -1)

# step 2.326: dims the background picture (multiply) and adds a soft vignette over it, under the actors
var _vignette: TextureRect = null

func _apply_room_treatment() -> void:
	if not is_instance_valid(background_layer):
		return
	background_layer.self_modulate = background_dim
	if vignette_strength <= 0.0:
		if is_instance_valid(_vignette):
			_vignette.queue_free()
		return
	if not is_instance_valid(_vignette):
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 1)])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.05, 0.5)
		tex.width = 256
		tex.height = 256
		_vignette = TextureRect.new()
		_vignette.name = "Vignette"
		_vignette.texture = tex
		_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_vignette.stretch_mode = TextureRect.STRETCH_SCALE
		_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		background_layer.add_child(_vignette)
	_vignette.modulate.a = vignette_strength


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


# ---------------------------------------------------------------------------
# step 2.216: closing the distance. actor_approach slides an actor on x until her anchor
# (feet) is `gap` px from the target's, staying on her own side, and draws her in front.
# the first approach remembers where she stood; actor_step_back returns her there.
# e.g. do actor_approach("Layla", "Fiona", 340.0, 0.5) ... do actor_step_back("Layla", 0.8)
const LEAN_IN_DEGREES: float = 3.5
var _approach_home: Dictionary = {}    # actor_id -> position before the first approach
var _approach_tweens: Dictionary = {}  # actor_id -> Tween
var _tilt_tweens: Dictionary = {}      # instance id -> Tween


func actor_approach(actor_id: String, target_id: String, gap: float = 300.0, duration: float = 0.45) -> void:
	if not active_actors.has(actor_id) or not active_actors.has(target_id):
		push_warning("actor_approach: '%s' or '%s' is not on stage." % [actor_id, target_id])
		return
	var rect: TextureRect = active_actors[actor_id]
	var other: TextureRect = active_actors[target_id]
	if not _approach_home.has(actor_id):
		_approach_home[actor_id] = rect.position
	var my_x: float = rect.position.x + rect.pivot_offset.x
	var other_x: float = other.position.x + other.pivot_offset.x
	var side: float = 1.0 if my_x >= other_x else -1.0
	var target_x: float = other_x + side * gap - rect.pivot_offset.x
	actor_stage.move_child(rect, -1)
	_slide_actor_x(actor_id, rect, target_x, duration)


func actor_step_back(actor_id: String, duration: float = 0.5) -> void:
	if not active_actors.has(actor_id) or not _approach_home.has(actor_id):
		return
	var rect: TextureRect = active_actors[actor_id]
	var home: Vector2 = _approach_home[actor_id]
	_approach_home.erase(actor_id)
	_slide_actor_x(actor_id, rect, home.x, duration)


func _slide_actor_x(actor_id: String, rect: TextureRect, target_x: float, duration: float) -> void:
	if _approach_tweens.has(actor_id) and _approach_tweens[actor_id] is Tween and _approach_tweens[actor_id].is_valid():
		_approach_tweens[actor_id].kill()
	var t = create_tween()
	t.tween_property(rect, "position:x", target_x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_approach_tweens[actor_id] = t


func _actor_tilt(rect: TextureRect, target_rotation: float, duration: float) -> void:
	var key: int = rect.get_instance_id()
	if _tilt_tweens.has(key) and _tilt_tweens[key] is Tween and _tilt_tweens[key].is_valid():
		_tilt_tweens[key].kill()
	var t = create_tween()
	t.tween_property(rect, "rotation", target_rotation, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tilt_tweens[key] = t


# step 2.237: a "skirt" under each actor. it repeats the sprite's bottom rows straight down, off-screen,
# so hops, leans and shocks never reveal where the art ends. it is a child of the actor's rect, so it
# moves, tilts, flips, scales, fades and dims with it; it rebuilds only when the texture changes.
const SKIRT_NAME := "_BottomSkirt"
const SKIRT_HEIGHT_RATIO := 0.35
const SKIRT_SAMPLE_ROWS := 2


func _update_actor_skirts() -> void:
	for id in active_actors:
		var rect = active_actors[id]
		if not is_instance_valid(rect) or not (rect is TextureRect) or rect.texture == null:
			continue
		var skirt: TextureRect = rect.get_node_or_null(SKIRT_NAME)
		if skirt == null:
			skirt = TextureRect.new()
			skirt.name = SKIRT_NAME
			skirt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			skirt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			skirt.stretch_mode = TextureRect.STRETCH_SCALE
			skirt.use_parent_material = true
			rect.add_child(skirt)
		var tex: Texture2D = rect.texture
		if skirt.get_meta("source_texture", null) != tex:
			var w: int = tex.get_width()
			var h: int = tex.get_height()
			var strip := AtlasTexture.new()
			strip.atlas = tex
			strip.region = Rect2(0, maxi(0, h - SKIRT_SAMPLE_ROWS), w, mini(SKIRT_SAMPLE_ROWS, h))
			skirt.texture = strip
			skirt.set_meta("source_texture", tex)
		# local coordinates: the actor rect is drawn at its texture's native size
		var native: Vector2 = tex.get_size()
		skirt.position = Vector2(0.0, native.y - 1.0)
		skirt.size = Vector2(native.x, native.y * SKIRT_HEIGHT_RATIO)


func actor_dash_in(actor_id: String, emotion: String, slot_name: String, scale_modifier: float = 1.0):
	var profile = get_profile(actor_id)
	if not profile:
		push_warning("Actor profile not found: " + actor_id)
		return

	var tex_path: String = _expression_path(profile, emotion)
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
	rect.pivot_offset = Vector2(tex_size.x * profile.canvas_anchor_x, tex_size.y)

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
	var tex_path: String = _expression_path(profile, emotion)
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
	rect.pivot_offset = Vector2(tex_size.x * profile.canvas_anchor_x, tex_size.y)
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

# ---------------------------------------------------------------------------
# party staging. one dialogue line replaces the per-side if/else: reads the
# conversation_player_on_left flag (interactable.gd sets it for every CHARACTER on
# interaction_started), stages the protagonist and the NPC on opposite sides with the
# stage's facing convention (sprites face right; whoever stands on the right is
# flipped), then — if a companion is currently following — puts her in the back row
# on our side. sets PARTY_STAGED_FLAG so the dialogue can branch on her presence.
func stage_party(npc_id: String, npc_emotion: String = "base", with_companion: bool = true):
	var on_left: bool = Flags.get_level_flag("conversation_player_on_left") == true
	var our_slot: String = "left" if on_left else "right"
	var npc_slot: String = "right" if on_left else "left"

	await actor_enter(PROTAGONIST_ACTOR_ID, "base", our_slot)
	# empty npc_id: stage the party alone (a prop takes the other side — see prop_enter)
	if not npc_id.is_empty():
		await actor_enter(npc_id, npc_emotion, npc_slot)
		if on_left:
			actor_flip(npc_id, true)
	if not on_left:
		actor_flip(PROTAGONIST_ACTOR_ID, true)

	_party_companion_id = ""
	_party_companion_front = false
	var staged: bool = false
	var companion_id: String = _following_companion_actor_id() if with_companion else ""
	if not companion_id.is_empty() and get_profile(companion_id) != null:
		await actor_enter(companion_id, "base", our_slot)
		if active_actors.has(companion_id):
			var rect: TextureRect = active_actors[companion_id]
			if not on_left:
				actor_flip(companion_id, true)
			# back row. x only: actor_enter's own slide-up tween owns position:y, and the
			# pivot is bottom-anchored so scaling keeps her feet on the stage line.
			rect.position.x += -PARTY_BACK_ROW_OFFSET if on_left else PARTY_BACK_ROW_OFFSET
			rect.scale = _party_scale_for(companion_id, PARTY_BACK_ROW_SCALE, rect.scale.x < 0.0)
			rect.modulate.r = PARTY_BACK_ROW_DIM.r
			rect.modulate.g = PARTY_BACK_ROW_DIM.g
			rect.modulate.b = PARTY_BACK_ROW_DIM.b
			actor_stage.move_child(rect, 0)
			_party_companion_id = companion_id
			staged = true
	Flags.set_level_flag(PARTY_STAGED_FLAG, staged)


# dialogue override for the automatic speaker stance: do actor_stance("Layla", "front").
func actor_stance(actor_id: String, stance: String = "front"):
	if actor_id != _party_companion_id:
		return
	_set_companion_front(stance.to_lower() == "front")


func _apply_speaker_stance(speaker: String) -> void:
	if _party_companion_id.is_empty():
		return
	var speaker_name: String = speaker.strip_edges()
	if speaker_name.is_empty():
		return   # narration: leave the stance alone
	_set_companion_front(speaker_name == _party_companion_id)


func _set_companion_front(front: bool) -> void:
	if _party_companion_id.is_empty() or not active_actors.has(_party_companion_id):
		return
	if front == _party_companion_front:
		return
	if not _original_actor_transforms.is_empty():
		return   # a close-up (actor_focus) owns every transform until unfocus
	if _huddle_active:
		return   # party_huddle owns the companion's transform until party_unhuddle
	_party_companion_front = front

	var rect: TextureRect = active_actors[_party_companion_id]
	var factor: float = PARTY_FRONT_STEP_SCALE if front else PARTY_BACK_ROW_SCALE
	var target_scale: Vector2 = _party_scale_for(_party_companion_id, factor, rect.scale.x < 0.0)
	var target_tint: Color = Color.WHITE if front else PARTY_BACK_ROW_DIM
	actor_stage.move_child(rect, -1 if front else 0)

	if _party_stance_tween and _party_stance_tween.is_valid():
		_party_stance_tween.kill()
	_party_stance_tween = create_tween().set_parallel(true)
	# step 2.375: a size effect (slump, shy, nod, shock) still playing on her owns her size. it ends by
	# putting back the size she had when it started, which left her squashed (wide from the new stance,
	# short from the old one) for as long as she kept talking. the tint changes now; the size follows
	# smoothly once the effect is done.
	if _size_effect_running(_party_companion_id):
		_resize_companion_after_effect()
	else:
		_party_stance_tween.tween_property(rect, "scale", target_scale, PARTY_STANCE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# rgb only — actor_enter's fade-in may still own modulate:a
	_party_stance_tween.tween_property(rect, "modulate:r", target_tint.r, PARTY_STANCE_TIME).set_trans(Tween.TRANS_SINE)
	_party_stance_tween.tween_property(rect, "modulate:g", target_tint.g, PARTY_STANCE_TIME).set_trans(Tween.TRANS_SINE)
	_party_stance_tween.tween_property(rect, "modulate:b", target_tint.b, PARTY_STANCE_TIME).set_trans(Tween.TRANS_SINE)


# step 2.375: actor effects that change an actor's size (the rest move or tilt her).
const SIZE_EFFECTS := ["shock", "slump", "shy", "nod"]
var _actor_effect_names: Dictionary = {}   # actor_id -> the name of her last actor_effect


func _size_effect_running(actor_id: String) -> bool:
	var t = _actor_effect_tweens.get(actor_id)
	if t == null or not t.is_valid() or not t.is_running():
		return false
	return SIZE_EFFECTS.has(_actor_effect_names.get(actor_id, ""))


# step 2.375: once the companion's size effect has finished, ease her to the size of her current stance.
# deferred, so the effect tween is fully done (and a new effect started in the same frame is seen).
func _resize_companion_after_effect() -> void:
	var t = _actor_effect_tweens.get(_party_companion_id)
	if t == null or not t.is_valid():
		return
	if not t.finished.is_connected(_resize_companion_to_stance):
		t.finished.connect(_resize_companion_to_stance, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _resize_companion_to_stance() -> void:
	if _party_companion_id.is_empty() or not active_actors.has(_party_companion_id):
		return
	if not _original_actor_transforms.is_empty() or _huddle_active:
		return   # a close-up or the huddle owns her transform now
	if _size_effect_running(_party_companion_id):
		_resize_companion_after_effect()   # another size effect started meanwhile: wait for that one
		return
	var rect: TextureRect = active_actors[_party_companion_id]
	var factor: float = PARTY_FRONT_STEP_SCALE if _party_companion_front else PARTY_BACK_ROW_SCALE
	var target_scale: Vector2 = _party_scale_for(_party_companion_id, factor, rect.scale.x < 0.0)
	if rect.scale.is_equal_approx(target_scale):
		return
	_finish_tween(_party_stance_tween)
	_party_stance_tween = create_tween()
	_party_stance_tween.tween_property(rect, "scale", target_scale, PARTY_STANCE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _party_scale_for(actor_id: String, factor: float, flipped: bool) -> Vector2:
	var rect: TextureRect = active_actors[actor_id]
	var profile = get_profile(actor_id)
	var default_scale: float = profile.default_scale if profile else 1.0
	var base: float = float(get_viewport().get_visible_rect().size.y) / float(rect.texture.get_size().y) * default_scale * factor
	return Vector2(-base if flipped else base, base)


# the follower that is attached right now, if any. CompanionFollow joins the
# companion_followers group and carries companion_actor_id (default "Layla").
func _following_companion_actor_id() -> String:
	var tree := get_tree()
	if tree == null:
		return ""
	for follower in tree.get_nodes_in_group("companion_followers"):
		if follower.has_method("is_attached") and follower.is_attached():
			var id = follower.get("companion_actor_id")
			if id is String and not id.is_empty():
				return id
	return ""


# ---------------------------------------------------------------------------
# props: scene instances staged beside the actors (a keypad, a note, a phone).
# they live on the ActorStage — above DarkenBackdrop/BackgroundLayer, under the
# balloon — NOT in CinematicContainer, which sits under the backdrop and is meant
# for full-screen cinematics. slot "opposite" = the side the party is not on.
var _props: Dictionary = {}

func prop_enter(prop_name: String, tscn_path: String, slot_name: String = "opposite", y_center: float = 470.0, prop_scale: float = 1.0):
	var scene: PackedScene = load(tscn_path)
	if scene == null:
		push_warning("prop_enter: could not load " + tscn_path)
		return
	var inst: Control = scene.instantiate() as Control
	if inst == null:
		push_warning("prop_enter: root of " + tscn_path + " is not a Control")
		return
	if _props.has(prop_name):
		prop_leave(prop_name)
	actor_stage.add_child(inst)
	_props[prop_name] = inst
	await get_tree().process_frame   # containers need a frame to report size

	var resolved_slot: String = slot_name
	if slot_name == "opposite":
		var on_left: bool = Flags.get_level_flag("conversation_player_on_left") == true
		resolved_slot = "right" if on_left else "left"
	var marker: Marker2D = actor_stage.get_node_or_null("Slot" + resolved_slot.capitalize())
	var cx: float = marker.position.x if marker else actor_stage.get_node("SlotCenter").position.x

	inst.scale = Vector2(prop_scale, prop_scale)
	var half: Vector2 = inst.size * prop_scale * 0.5
	var target := Vector2(cx - half.x, y_center - half.y)
	inst.position = target + Vector2(0.0, 200.0)
	inst.modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(inst, "position:y", target.y, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(inst, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# do prop_call("Keypad", "type_code", "07041776") — awaits coroutines so the next
# line waits for the animation.
func prop_call(prop_name: String, method: String, arg = null):
	var inst = _props.get(prop_name)
	if not is_instance_valid(inst):
		push_warning("prop_call: no prop '%s'." % prop_name)
		return
	if not inst.has_method(method):
		push_warning("prop_call: '%s' has no method '%s'." % [prop_name, method])
		return
	if arg == null:
		await inst.call(method)
	else:
		await inst.call(method, arg)


func prop_leave(prop_name: String) -> void:
	var inst = _props.get(prop_name)
	_props.erase(prop_name)
	if not is_instance_valid(inst):
		return
	var tween = create_tween().set_parallel(true)
	tween.tween_property(inst, "position:y", inst.position.y + 200.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(inst, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(inst.queue_free)


# ---------------------------------------------------------------------------
# huddle: the party talks amongst itself. protagonist steps to centre and turns to
# her companion; the companion leaves the back row for the party's slot, full size,
# facing her; every other actor and every prop slides half out through its own
# screen edge — still visible, so the third party is not forgotten.
# party_unhuddle() restores every transform and z-order it touched.
#   do party_huddle()        # after the keypad fails / when Layla whispers
#   do party_unhuddle()      # as Jayce butts back in
const HUDDLE_TIME: float = 0.45
const HUDDLE_SIDELINE_FRACTION: float = 0.75  # share of the third party's width that leaves the screen
const HUDDLE_PROTAG_SHIFT: float = 200.0      # protagonist stands this far off centre, toward the third party
const HUDDLE_COMPANION_OUTWARD: float = 70.0  # companion stands this far outside the party's slot

var _huddle_active: bool = false
var _huddle_saved: Dictionary = {}   # CanvasItem -> {"pos", "scale", "mod", "index"}
var _huddle_settle_msec: int = 0   # when the running huddle slide ends (party_dismiss waits for it)


func _huddle_remember(node: CanvasItem) -> void:
	_huddle_saved[node] = {
		"pos": node.position,
		"scale": node.scale,
		"mod": node.modulate,
		"index": node.get_index(),
	}


func party_huddle(duration: float = HUDDLE_TIME):
	if _huddle_active:
		return
	if not _original_actor_transforms.is_empty():
		return   # actor_focus owns the stage; unfocus first
	if not active_actors.has(PROTAGONIST_ACTOR_ID):
		return
	_huddle_active = true
	_huddle_settle_msec = Time.get_ticks_msec() + int(duration * 1000.0)
	_huddle_saved.clear()
	if _party_stance_tween and _party_stance_tween.is_valid():
		_party_stance_tween.kill()

	var on_left: bool = Flags.get_level_flag("conversation_player_on_left") == true
	var party_marker: Marker2D = actor_stage.get_node("SlotLeft" if on_left else "SlotRight")
	var center_marker: Marker2D = actor_stage.get_node("SlotCenter")
	var center_x: float = center_marker.position.x
	var tween = create_tween().set_parallel(true)

	# protagonist: centre, facing the companion's side (sprites face right)
	var fiona: TextureRect = active_actors[PROTAGONIST_ACTOR_ID]
	_huddle_remember(fiona)
	var fiona_anchor := Vector2(center_x + (HUDDLE_PROTAG_SHIFT if on_left else -HUDDLE_PROTAG_SHIFT), center_marker.position.y)
	var fiona_target: Vector2 = fiona_anchor - fiona.pivot_offset
	var fiona_scale := Vector2(-absf(fiona.scale.x) if on_left else absf(fiona.scale.x), fiona.scale.y)
	tween.tween_property(fiona, "position", fiona_target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(fiona, "scale", fiona_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	actor_stage.move_child(fiona, -1)

	# companion: out of the back row into the party's slot, full size, facing the protagonist
	if not _party_companion_id.is_empty() and active_actors.has(_party_companion_id):
		var comp: TextureRect = active_actors[_party_companion_id]
		_huddle_remember(comp)
		# companion: out of the back row into the party's slot, full size, facing the protagonist
		var comp_anchor := party_marker.position + Vector2(-HUDDLE_COMPANION_OUTWARD if on_left else HUDDLE_COMPANION_OUTWARD, 0.0)
		var comp_target: Vector2 = comp_anchor - comp.pivot_offset
		var comp_scale: Vector2 = _party_scale_for(_party_companion_id, 1.0, not on_left)
		var comp_tint := Color(1.0, 1.0, 1.0, comp.modulate.a)
		tween.tween_property(comp, "position", comp_target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(comp, "scale", comp_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(comp, "modulate", comp_tint, duration).set_trans(Tween.TRANS_SINE)
		actor_stage.move_child(comp, -1)
		_party_companion_front = true

	# everyone else: half off-screen through the edge they are nearest to
	for id in active_actors:
		if id == PROTAGONIST_ACTOR_ID or id == _party_companion_id:
			continue
		var r: TextureRect = active_actors[id]
		_huddle_remember(r)
		var width: float = r.texture.get_size().x * absf(r.scale.x)
		var anchor_x: float = r.position.x + r.pivot_offset.x
		var dir: float = -1.0 if anchor_x < center_x else 1.0
		tween.tween_property(r, "position:x", r.position.x + dir * width * HUDDLE_SIDELINE_FRACTION, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for prop_name in _props:
		var p = _props[prop_name]
		if not is_instance_valid(p):
			continue
		_huddle_remember(p)
		var p_width: float = p.size.x * absf(p.scale.x)
		var p_anchor_x: float = p.position.x + p_width * 0.5
		var p_dir: float = -1.0 if p_anchor_x < center_x else 1.0
		tween.tween_property(p, "position:x", p.position.x + p_dir * p_width * HUDDLE_SIDELINE_FRACTION, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func party_unhuddle(duration: float = HUDDLE_TIME):
	if not _huddle_active:
		return
	_huddle_active = false
	var tween = create_tween().set_parallel(true)
	# restore transforms
	for node in _huddle_saved:
		if not is_instance_valid(node):
			continue
		var saved: Dictionary = _huddle_saved[node]
		tween.tween_property(node, "position", saved["pos"], duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "scale", saved["scale"], duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "modulate", saved["mod"], duration).set_trans(Tween.TRANS_SINE)
	# restore z-order: lowest saved index first
	var ordered: Array = []
	for node in _huddle_saved:
		if is_instance_valid(node):
			ordered.append(node)
	ordered.sort_custom(func(a, b): return _huddle_saved[a]["index"] < _huddle_saved[b]["index"])
	for node in ordered:
		actor_stage.move_child(node, clampi(_huddle_saved[node]["index"], 0, actor_stage.get_child_count() - 1))
	_huddle_saved.clear()
	_party_companion_front = false


# ---------------------------------------------------------------------------
# dismiss: the third party leaves for good. every actor except the protagonist and
# the companion walks off through the screen edge they're nearest to and is freed;
# props leave too. the party ends up in the huddle layout (it huddles first if it
# isn't already), so the rest of the conversation is just the two of them. there's
# no way back — end the conversation afterwards. awaited by the dialogue, so the
# next line waits until the exit has played.
#   do party_dismiss()       # julian walks off; fiona and layla talk alone
const DISMISS_TIME: float = 0.6

func party_dismiss(duration: float = DISMISS_TIME):
	if not _huddle_active:
		party_huddle()
	# let a huddle that is still sliding the third party sideways finish first
	var delay: float = maxf(0.0, float(_huddle_settle_msec - Time.get_ticks_msec()) / 1000.0)
	var center_x: float = actor_stage.get_node("SlotCenter").position.x
	var leaving: Array = []
	for id in active_actors:
		if id != PROTAGONIST_ACTOR_ID and id != _party_companion_id:
			leaving.append(id)
	var last_tween: Tween = null
	for id in leaving:
		var r: TextureRect = active_actors[id]
		active_actors.erase(id)
		_huddle_saved.erase(r)
		var width: float = r.texture.get_size().x * absf(r.scale.x)
		var anchor_x: float = r.position.x + r.pivot_offset.x
		var dir: float = -1.0 if anchor_x < center_x else 1.0
		var t := create_tween().set_parallel(true)
		t.tween_property(r, "position:x", r.position.x + dir * (width + 300.0), duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_property(r, "modulate:a", 0.0, duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.chain().tween_callback(r.queue_free)
		last_tween = t
	# spread out to a normal two-shot, like the chapter-2 wake scene: the companion takes
	# the party's slot, the protagonist steps into the far slot the third party just left.
	# no companion: the protagonist moves to the centre. plays alongside the exit.
	var on_left: bool = Flags.get_level_flag("conversation_player_on_left") == true
	var party_marker: Marker2D = actor_stage.get_node("SlotLeft" if on_left else "SlotRight")
	var far_marker: Marker2D = actor_stage.get_node("SlotRight" if on_left else "SlotLeft")
	var has_companion: bool = not _party_companion_id.is_empty() and active_actors.has(_party_companion_id)
	var spread: Tween = null
	if active_actors.has(PROTAGONIST_ACTOR_ID):
		spread = create_tween().set_parallel(true)
		var fiona: TextureRect = active_actors[PROTAGONIST_ACTOR_ID]
		var fiona_marker: Marker2D = far_marker if has_companion else actor_stage.get_node("SlotCenter")
		spread.tween_property(fiona, "position", fiona_marker.position - fiona.pivot_offset, duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if has_companion:
			var comp: TextureRect = active_actors[_party_companion_id]
			spread.tween_property(comp, "position", party_marker.position - comp.pivot_offset, duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# the huddle's saved transforms no longer apply
	_huddle_saved.clear()
	for prop_name in _props.keys():
		prop_leave(prop_name)
	if spread:
		await spread.finished
	elif last_tween:
		await last_tween.finished


func hide_dialogue_ui():
	if current_balloon and current_balloon.has_method("set_ui_hidden"):
		current_balloon.set_ui_hidden(true)

func show_dialogue_ui():
	if current_balloon and current_balloon.has_method("set_ui_hidden"):
		current_balloon.set_ui_hidden(false)

# step 2.267: blocks every way of moving the dialogue on (clicks, keys, Ctrl-skip, Skip, Auto, the
# log, un-hiding the box) while a scripted beat plays. always pair with unlock_dialogue_input().
func lock_dialogue_input() -> void:
	if current_balloon and current_balloon.has_method("set_input_locked"):
		current_balloon.set_input_locked(true)

func unlock_dialogue_input() -> void:
	if current_balloon and current_balloon.has_method("set_input_locked"):
		current_balloon.set_input_locked(false)

# step 2.271: the quiet top-of-screen banner (the same one as the first-visit "try Examine" tip),
# from dialogue:  do show_hint_banner("Floor 4F (Faculty Offices) is now accessible.")
# it sits on its own layer under the root, so it outlives this overlay, and frees itself after.
func show_hint_banner(text: String, seconds: float = 4.5) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	get_tree().root.add_child(layer)
	var banner = preload("res://conversation/hint_banner.gd").new()
	layer.add_child(banner)
	banner.flash_hint(text, null, seconds)
	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = seconds + 1.5
	cleanup.timeout.connect(layer.queue_free)
	layer.add_child(cleanup)
	cleanup.start()

var _original_actor_transforms = {}

# screen_x_ratio / screen_y_ratio (step 2.212): where on screen the face lands; 0.5, 0.35 is
# the classic centred close-up. do actor_focus("Layla", 1.6, 0.45, -1.0, 0.3) puts her face at 30%.
func actor_focus(actor_id: String, zoom_modifier: float = 2.0, duration: float = 0.01, face_x_ratio: float = -1.0, screen_x_ratio: float = 0.5, screen_y_ratio: float = 0.35):
	if not active_actors.has(actor_id): return

	# step 2.267: settle effects first (so no half-finished pose gets snapshotted), then take over
	# from any focus/unfocus still running. killing a running unfocus keeps the saved resting poses.
	_settle_actor_effects()
	_finish_tween(_party_stance_tween)
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()

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

	# -1.0 = "use the profile's measured anchor". an explicit ratio from a dialogue still wins.
	# step 2.401: then the profile's own face position (face_x_ratio), then its anchor
	var fx: float = face_x_ratio if face_x_ratio >= 0.0 else (profile.face_x_ratio if profile.face_x_ratio >= 0.0 else profile.canvas_anchor_x)
	var local_face = Vector2(tex_size.x * fx, tex_size.y * profile.face_y_ratio)
	var screen_focus_point = Vector2(screen_size.x * screen_x_ratio, screen_size.y * screen_y_ratio)
	var target_pos = screen_focus_point - rect.pivot_offset - (local_face - rect.pivot_offset) * target_scale

	var tween = create_tween().set_parallel(true)
	_focus_tween = tween
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
	# step 2.267: as in actor_focus: settle effects, then take over from a running focus/unfocus.
	_settle_actor_effects()
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	var tween = create_tween().set_parallel(true)
	_focus_tween = tween
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
	# hide_visual_layers() may have hidden the node earlier in the same conversation
	# (the chapter 2 wake does). re-show it from zero so it fades in instead of popping
	# at whatever alpha it was saved with.
	if alpha > 0.0 and not darken_backdrop.visible:
		darken_backdrop.color.a = 0.0
		darken_backdrop.visible = true
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

	var tex_path: String = _expression_path(profile, emotion)
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
	rect.pivot_offset = Vector2(tex_size.x * profile.canvas_anchor_x, tex_size.y)

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


# ****************************[scene CGs] (step 2.186)
# a scene CG is a whole scene shown where a still CG would be (for example
# conversation/apartment/apartment_phone_shot.tscn). it sits just above CGLayer, so the
# balloon and the overlay's own fades still draw over it. one at a time: showing another
# replaces the current one. hide it before showing a still CG, which would sit under it.
# dialogue:
#   do show_scene_cg("phone_floor", "fade", 0.6)
#   do scene_cg_call("select_contact", [1])
#   do scene_cg_call("focus_pamphlet")
#   do hide_scene_cg("fade", 0.5)
func show_scene_cg(scene_name: String, transition: String = "fade", duration: float = 0.5) -> void:
	var path: String = scene_cg_aliases.get(scene_name, scene_name)
	if not ResourceLoader.exists(path):
		push_warning("show_scene_cg: no scene CG alias or path: " + scene_name)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("show_scene_cg: not a scene: " + path)
		return
	var old := scene_cg
	var node := packed.instantiate()
	if node is Control:
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	move_child(node, (old.get_index() if is_instance_valid(old) else cg_layer.get_index()) + 1)
	scene_cg = node
	if transition == "fade" and duration > 0.0 and node is CanvasItem:
		node.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tween.finished
	if is_instance_valid(old):
		old.queue_free()


func hide_scene_cg(transition: String = "fade", duration: float = 0.5) -> void:
	var node := scene_cg
	scene_cg = null
	if not is_instance_valid(node):
		return
	if transition == "fade" and duration > 0.0 and node is CanvasItem:
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
	if is_instance_valid(node):
		node.queue_free()


## call a method on the current scene CG and wait for it if it takes time (moves, zooms).
func scene_cg_call(method: String, args: Array = []) -> Variant:
	if not is_instance_valid(scene_cg):
		push_warning("scene_cg_call: no scene CG is showing (" + method + ")")
		return null
	if not scene_cg.has_method(method):
		push_warning("scene_cg_call: scene CG has no method " + method)
		return null
	return await scene_cg.callv(method, args)


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


# hard stop for a running shake, callable from dialogue. finite shakes (positive duration)
# are not auto-cancelled by _on_got_dialogue, so a long finite shake + shake_stop() is how a
# shake spans multiple lines.
func shake_stop() -> void:
	_is_shaking = false
	_is_persistent_shake = false
	_ignore_next_got_dialogue_signal = false
	_shake_timer = 0.0
	offset = _camera_offset


func _on_got_dialogue(line: DialogueLine):
	if _ignore_next_got_dialogue_signal:
		_ignore_next_got_dialogue_signal = false
		return
	if _is_persistent_shake:
		_is_shaking = false
		_is_persistent_shake = false
		offset = Vector2.ZERO

	_update_predictive_cache(line)
	_apply_speaker_stance(line.character)
	_update_talking(line)   # step 2.401


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
					var tex_path: String = _expression_path(profile, emotion)
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


# ---------------------------------------------------------------------------
# step 2.365: rigged characters. a profile whose expressions hold "rig_parts" (the parts map written by
# Dev/rig_tools/rig_parts_cutter.gd) and "rig_expressions" (name -> parts list, kept by the rig viewer)
# is drawn from parts: actor_change("Layla", "happy") looks "happy" up and composes that picture. a name
# that isn't in the list is read as part names directly (e.g. "regular o"); "base" falls back to
# "neutral", for older dialogue. only the composed picture is kept in video memory.
const ActorRigComposerScript = preload("res://characters/rig/actor_rig_composer.gd")
var _rig_expression_sets: Dictionary = {}   # expressions file -> {name: parts list}

func _expression_path(profile, emotion: String) -> String:
	var ex: Dictionary = profile.expressions
	var parts_path: String = String(ex.get("rig_parts", ""))
	if parts_path != "":
		return "rig:%s|%s|%s" % [parts_path, String(ex.get("rig_expressions", "")), emotion]
	return ex.get(emotion, "")

func _rig_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var bits: PackedStringArray = path.substr(4).split("|")
	if bits.size() < 3:
		return null
	var parts_path: String = bits[0]
	var ex_path: String = bits[1]
	var emotion: String = bits[2]
	var parts: String = _rig_parts_for(ex_path, emotion)
	var tex: Texture2D = ActorRigComposerScript.compose(parts_path, parts)
	if tex:
		_texture_cache[path] = tex
		_rig_paths[tex.get_instance_id()] = path   # step 2.401: which picture this is (for talking)
	return tex


# a name from the expressions file -> its parts list. a name that isn't in it is already a parts list;
# "base" falls back to "neutral".
func _rig_parts_for(ex_path: String, emotion: String) -> String:
	if not _rig_expression_sets.has(ex_path):
		var data = null
		if ex_path != "" and FileAccess.file_exists(ex_path):
			data = JSON.parse_string(FileAccess.get_file_as_string(ex_path))
		_rig_expression_sets[ex_path] = data if data is Dictionary else {}
	var named: Dictionary = _rig_expression_sets[ex_path]
	if named.has(emotion):
		return String(named[emotion])
	if emotion == "base" and named.has("neutral"):
		return String(named["neutral"])
	return emotion


# ---------------------------------------------------------------------------
# step 2.401: talking mouths (characters/rig/rig_talk.gd). a profile with talk_mouths (Fiona) gets the mouth
# that fits her head added while one of her lines is up (her name, or "Player" for the protagonist; not a
# thought in parentheses or a silent "..."), and taken off again for anyone else's line. the shut and the
# talking picture are kept together, so switching back and forth never builds a picture twice.
const RigTalkScript = preload("res://characters/rig/rig_talk.gd")
var _rig_paths: Dictionary = {}         # composed texture's instance id -> its rig path
var _talking: Dictionary = {}           # actor id -> speaking out loud on the current line
var _talk_shut_paths: Dictionary = {}   # talking picture's path -> its shut picture's path
var _talk_keep: Dictionary = {}         # actor id -> {path: texture}, the pictures in use

func _update_talking(line: DialogueLine) -> void:
	for actor_id in active_actors.keys():
		var profile = get_profile(actor_id)
		if profile == null or profile.talk_mouths.is_empty():
			continue
		_talking[actor_id] = RigTalkScript.is_speaking(actor_id, actor_id == PROTAGONIST_ACTOR_ID, line.character, line.text)
		_apply_talking(actor_id)


func _apply_talking(actor_id: String) -> void:
	if not active_actors.has(actor_id):
		return
	var profile = get_profile(actor_id)
	if profile == null or profile.talk_mouths.is_empty():
		return
	var rect: TextureRect = active_actors[actor_id]
	if rect.texture == null:
		return
	var current: String = String(_rig_paths.get(rect.texture.get_instance_id(), ""))
	if current == "":
		return
	var talking: bool = _talking.get(actor_id, false)
	if talking == _talk_shut_paths.has(current):
		return
	var target: String = ""
	if talking:
		var bits: PackedStringArray = current.substr(4).split("|")
		if bits.size() < 3:
			return
		var open_parts: String = RigTalkScript.talking_parts(bits[0], _rig_parts_for(bits[1], bits[2]), profile.talk_mouths, profile.talk_head_slot)
		if open_parts == "":
			return
		target = "rig:%s|%s|%s" % [bits[0], bits[1], open_parts]
		_talk_shut_paths[target] = current
		_keep_talk_texture(actor_id, current, rect.texture)
	else:
		target = _talk_shut_paths[current]
	var keep: Dictionary = _talk_keep.get(actor_id, {})
	var tex: Texture2D = keep[target] if keep.has(target) else _rig_texture(target)
	if tex == null:
		return
	_keep_talk_texture(actor_id, target, tex)
	rect.texture = tex


# holds on to a few of an actor's pictures (the shut and talking ones in use), out of reach of the
# predictive cache's clean-up
func _keep_talk_texture(actor_id: String, path: String, tex: Texture2D) -> void:
	var keep: Dictionary = _talk_keep.get(actor_id, {})
	if not keep.has(path) and keep.size() >= 4:
		keep.clear()
	keep[path] = tex
	_talk_keep[actor_id] = keep


# ---------------------------------------------------------------------------
# step 2.404: items shown beside a character, not in her hand (characters/rig/held_item.gd): a phone, a
# keycard, a camera. the item is a child of her picture, so it follows her moves, close-ups and dimming,
# and goes when she does.
#   do actor_item("Layla", "phone")     pops in beside her, on the side facing the others, and bobs
#   do actor_item_hide("Layla")         pops away
const HeldItemScript = preload("res://characters/rig/held_item.gd")
var _actor_items: Dictionary = {}   # actor id -> the item showing beside her

func actor_item(actor_id: String, item: String) -> void:
	if not active_actors.has(actor_id):
		return
	actor_item_hide(actor_id)
	var profile = get_profile(actor_id)
	var face := Vector2(0.5, 0.3)
	if profile:
		face = Vector2(profile.face_x_ratio if profile.face_x_ratio >= 0.0 else profile.canvas_anchor_x, profile.face_y_ratio)
	var node = HeldItemScript.new()
	if not node.setup(item, face):
		node.free()
		return
	active_actors[actor_id].add_child(node)
	_actor_items[actor_id] = node


func actor_item_hide(actor_id: String) -> void:
	var node = _actor_items.get(actor_id)
	_actor_items.erase(actor_id)
	if is_instance_valid(node):
		node.leave()


func _get_texture_async(path: String) -> Texture2D:
	if path.is_empty():
		return null
	# step 2.365: a rigged character's picture is composed from parts, not loaded
	if path.begins_with("rig:"):
		return _rig_texture(path)

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


# ---------------------------------------------------------------------------
# dream state
# ---------------------------------------------------------------------------

func _kill_dream_tween() -> void:
	if _dream_tween and _dream_tween.is_valid():
		_dream_tween.kill()
	_dream_tween = null


# ramp the dream haze to a target intensity. duration <= 0.0 snaps instantly.
func dream_set(intensity: float, duration: float = 1.0) -> void:
	if not _dream_mat or not is_instance_valid(dream_haze):
		return

	intensity = clampf(intensity, 0.0, 1.0)
	_kill_dream_tween()

	if intensity > 0.0:
		dream_haze.visible = true

	if duration <= 0.0:
		_dream_mat.set_shader_parameter("amount", intensity)
		dream_haze.visible = intensity > 0.0
		return

	_dream_tween = create_tween()
	_dream_tween.tween_property(_dream_mat, "shader_parameter/amount", intensity, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _dream_tween.finished

	# stop paying for the screen read once it is fully off.
	if intensity <= 0.0 and is_instance_valid(dream_haze):
		dream_haze.visible = false


func dream_enter(intensity: float = 1.0, duration: float = 2.0) -> void:
	await dream_set(intensity, duration)


func dream_exit(duration: float = 1.5) -> void:
	await dream_set(0.0, duration)


# a swell that settles back to wherever the haze already was. awaited, so the line after it
# waits the swell out.
func dream_pulse(peak: float = 1.0, duration: float = 1.2) -> void:
	if not _dream_mat or not is_instance_valid(dream_haze):
		return

	var raw = _dream_mat.get_shader_parameter("amount")
	var base: float = float(raw) if raw != null else 0.0

	_kill_dream_tween()
	dream_haze.visible = true

	_dream_tween = create_tween()
	_dream_tween.tween_property(_dream_mat, "shader_parameter/amount",
		clampf(peak, 0.0, 1.0), duration * 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_dream_tween.tween_property(_dream_mat, "shader_parameter/amount", base, duration * 0.65)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _dream_tween.finished


# ---------------------------------------------------------------------------
# waking up
# ---------------------------------------------------------------------------

# hides every opaque layer so the eyelid can blink open onto whatever sits on a lower canvas
# layer (the wake CG at 70, under this overlay's 75). DreamHaze and EyelidOverlay are
# deliberately left alone: wake_blink() drives both. callable from dialogue.
func hide_visual_layers() -> void:
	for n in ["SolidBackground", "BackgroundLayer", "CGLayer", "MentalImageLayer", "DarkenBackdrop"]:
		var node = get_node_or_null(n)
		if node:
			node.visible = false


# abrupt cut to black, no fade. the eyelid overlay at openness 0.0 IS the blackout, so
# wake_blink() takes over from it with no hand-off and no seam.
func cut_to_black(hold: float = 0.8, residual_haze: float = 0.55) -> void:
	hide_dialogue_ui()

	# any active shake must die here: the eyelid rect is exactly screen-sized, so a shaking
	# CanvasLayer would open a gap at the frame edge during the blink.
	_is_shaking = false
	_is_persistent_shake = false
	_camera_offset = Vector2.ZERO
	offset = Vector2.ZERO

	if _eyelid_mat:
		_eyelid_mat.set_shader_parameter("openness", 0.0)
	if is_instance_valid(eyelid_overlay):
		eyelid_overlay.visible = true

	# the haze stays on low so wake_blink() can fade it out as vision focuses.
	await dream_set(clampf(residual_haze, 0.0, 1.0), 0.0)

	if hold > 0.0:
		await get_tree().create_timer(hold).timeout


# eyelid flutter open. expects the screen to already be black from cut_to_black(), and snaps it
# shut first if it is not. awaited, so the next dialogue line waits for the eye to settle.
func wake_blink(speed: float = 1.0, clear_haze: bool = true) -> void:
	if not _eyelid_mat or not is_instance_valid(eyelid_overlay):
		show_dialogue_ui()
		return

	speed = maxf(speed, 0.1)
	hide_dialogue_ui()
	eyelid_overlay.visible = true

	var raw = _eyelid_mat.get_shader_parameter("openness")
	if raw == null or float(raw) > 0.02:
		_eyelid_mat.set_shader_parameter("openness", 0.0)

	# vision focuses as the lid opens. kept shorter than the lid chain below so it always
	# lands before the haze node is hidden.
	if clear_haze and _dream_mat:
		_kill_dream_tween()
		_dream_tween = create_tween()
		_dream_tween.tween_property(_dream_mat, "shader_parameter/amount", 0.0, 1.5 / speed)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var t := create_tween()
	# first crack, then it falls shut again
	t.tween_property(_eyelid_mat, "shader_parameter/openness", 0.16, 0.30 / speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.10 / speed)
	t.tween_property(_eyelid_mat, "shader_parameter/openness", 0.02, 0.16 / speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_interval(0.14 / speed)
	# second, wider, still heavy
	t.tween_property(_eyelid_mat, "shader_parameter/openness", 0.62, 0.34 / speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_eyelid_mat, "shader_parameter/openness", 0.40, 0.22 / speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# settle open
	t.tween_property(_eyelid_mat, "shader_parameter/openness", 1.0, 0.55 / speed)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished

	if is_instance_valid(eyelid_overlay):
		eyelid_overlay.visible = false
	if clear_haze and is_instance_valid(dream_haze):
		dream_haze.visible = false
	show_dialogue_ui()
