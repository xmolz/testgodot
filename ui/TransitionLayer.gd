# transitionlayer.gd
extends CanvasLayer

signal transition_halfway 
signal transition_finished

const CHAPTER_PORTAL_SHADER = preload("res://ui/chapter_portal.gdshader")

# portal pacing, as fractions of the total duration passed to play_chapter_portal().
# grow and warp deliberately overlap so it reads as one motion rather than two events.
const PORTAL_GROW_FRACTION: float = 0.40
const PORTAL_WARP_START_FRACTION: float = 0.32
const PORTAL_WARP_FRACTION: float = 0.53
const PORTAL_HOLD_FRACTION: float = 0.15

const PORTAL_HOLD_PROGRESS := 0.85

var _portal_rect: TextureRect = null
var _portal_mat: ShaderMaterial = null
var _portal_active: bool = false

# ----------- portal churn tuning knobs (developer: tune by feel)
const IDLE_SPIN_SPEED: float = 3.0     # was 1.2 — radians/sec at full churn
const IDLE_BREATHE_AMOUNT: float = 0.25  # was 0.15 — periodic wobble amplitude
const IDLE_SWIRL_BOOST: float = 0.30   # extra vortex pull at full churn (0..1)
const IDLE_RAMP_TIME: float = 0.6
const IDLE_FLOW_SPEED: float = 0.07  # uv radius per second of outward wash at full churn
const IDLE_FLOW_MAX: float = 0.45    # cap on total wash. raise for a harder drain.
const PORTAL_SPIKE_THRESHOLD_MS := 50.0

var _idle_strength: float = 0.0
var _idle_target: float = 0.0
var _idle_angle: float = 0.0
var _idle_breathe: float = 0.0
var _idle_flow: float = 0.0
var _debug_phase_tag: String = ""
var _active_balloon: Node = null

var _loading_label: Label = null
var _loading_tween: Tween = null
var _loading_shown_at_ms: int = 0

@onready var left_shutter = get_node_or_null("LeftShutter")
@onready var right_shutter = get_node_or_null("RightShutter")
@onready var iris_rect = get_node_or_null("IrisColorRect")
@onready var global_fade_rect = get_node_or_null("GlobalFadeRect")

func _ready():
	# this layer drives quit/game-over fades while the tree is paused,
	# so it must never pause with the rest of the world.
	process_mode = Node.PROCESS_MODE_ALWAYS
	open_instant()

	_loading_label = Label.new()
	_loading_label.text = "Loading..."
	_loading_label.add_theme_font_override("font", preload("res://Fonts/VarelaRound-Regular.ttf"))
	_loading_label.add_theme_font_size_override("font_size", 36 if not OS.has_feature("mobile") else 48)
	_loading_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_loading_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_loading_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_loading_label.position.y -= 80
	_loading_label.visible = false
	add_child(_loading_label)

func _process(delta: float) -> void:
	if _portal_active and is_instance_valid(_portal_rect) and _portal_mat:
		_idle_strength = move_toward(_idle_strength, _idle_target, delta / IDLE_RAMP_TIME)
		_idle_angle += delta * IDLE_SPIN_SPEED * _idle_strength
		_idle_breathe = sin(_idle_angle * 1.6) * IDLE_BREATHE_AMOUNT * _idle_strength
		_idle_flow = min(_idle_flow + delta * IDLE_FLOW_SPEED * _idle_strength, IDLE_FLOW_MAX)
		_portal_mat.set_shader_parameter("idle_angle", _idle_angle)
		_portal_mat.set_shader_parameter("idle_breathe", _idle_breathe)
		_portal_mat.set_shader_parameter("idle_flow", _idle_flow)
		_portal_mat.set_shader_parameter("idle_strength", _idle_strength)
		_portal_mat.set_shader_parameter("idle_swirl_boost", IDLE_SWIRL_BOOST * _idle_strength)
		
		# Task D Frame-spike watcher. uses the threshold const now: the old 25ms literal
		# printed every single frame of a 30fps session and drowned the log.
		if ChapterLaunchSequence.PORTAL_DEBUG and not _debug_phase_tag.is_empty() and delta * 1000.0 > PORTAL_SPIKE_THRESHOLD_MS:
			print_rich("[color=red][PORTAL SPIKE] %s: %.1f ms[/color]" % [_debug_phase_tag, delta * 1000.0])

func open_instant():
	# if godot runs this before
	if not left_shutter or not right_shutter: return
	
	var viewport_width = get_viewport().get_visible_rect().size.x
	left_shutter.position.x = -left_shutter.size.x
	right_shutter.position.x = viewport_width
	
	if iris_rect and iris_rect.material:
		iris_rect.material.set_shader_parameter("circle_size", 1.5)
		iris_rect.visible = false

# ***************(1. sci-fi door transition (used for teleporting))
func play_transition_sequence():
	if not left_shutter or not right_shutter: return

	_set_gm_transitioning(true)

	var viewport_width = get_viewport().get_visible_rect().size.x
	var center_x = viewport_width / 2.0
	
	SoundManager.play_sfx("door_close")
	
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(left_shutter, "position:x", 0.0, 0.5)
	tween.tween_property(right_shutter, "position:x", center_x, 0.5)
	await tween.finished
	
	emit_signal("transition_halfway")
	
	# 2 second delay while screen is black (1 second longer)
	await get_tree().create_timer(1.2).timeout
	
	SoundManager.play_sfx("door_open")
	
	var open_tween = create_tween().set_parallel(true)
	open_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	open_tween.tween_property(left_shutter, "position:x", -left_shutter.size.x, 0.5)
	open_tween.tween_property(right_shutter, "position:x", viewport_width, 0.5)
	
	await open_tween.finished

	_set_gm_transitioning(false)
	emit_signal("transition_finished")


# ************[2. iris "eye" transitions (used for loading states)]
func play_iris_close(duration: float = 1.0):
	_set_gm_transitioning(true)
	if not iris_rect or not iris_rect.material:
		await get_tree().create_timer(duration).timeout
		emit_signal("transition_halfway")
		return
	
	iris_rect.visible = true
	iris_rect.material.set_shader_parameter("circle_size", 1.5)
	
	var tween = create_tween()
	# tween to -0.1 to completely swallow the soft edge!
	tween.tween_property(iris_rect.material, "shader_parameter/circle_size", -0.1, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	emit_signal("transition_halfway")

func play_iris_open(duration: float = 1.0):
	if not iris_rect or not iris_rect.material:
		await get_tree().create_timer(duration).timeout
		_set_gm_transitioning(false)
		emit_signal("transition_finished")
		return

	iris_rect.visible = true
	iris_rect.material.set_shader_parameter("circle_size", -0.1)

	var tween = create_tween()
	tween.tween_property(iris_rect.material, "shader_parameter/circle_size", 1.5, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished
	iris_rect.visible = false
	_set_gm_transitioning(false)
	emit_signal("transition_finished")

# ----------------------(3. traditional fades (for game over))
func global_fade_to_black(duration: float = 3.0):
	_set_gm_transitioning(true)
	if global_fade_rect:
		global_fade_rect.modulate.a = 0.0
		global_fade_rect.visible = true
		var tween = create_tween()
		tween.tween_property(global_fade_rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
		await tween.finished

func global_fade_from_black(duration: float = 1.0):
	if global_fade_rect:
		var tween = create_tween()
		tween.tween_property(global_fade_rect, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
		await tween.finished
		global_fade_rect.visible = false
	_set_gm_transitioning(false)


func _set_gm_transitioning(is_active: bool):
	if GameManager:
		GameManager.is_transitioning = is_active
		if GameManager.has_method("refresh_hovered_object"):
			GameManager.refresh_hovered_object()
		if GameManager.has_method("update_sentence_line_ui"):
			GameManager.update_sentence_line_ui()

# ************[3. chapter portal (grows the chapter art, then warps it into a portal)]
# awaited directly by its caller, so it deliberately does NOT emit transition_halfway or
# transition_finished — emitting those would wake any unrelated coroutine awaiting them.
func portal_enter(texture: Texture2D, start_rect: Rect2, duration: float = 1.0) -> void:
	_debug_phase_tag = "portal_enter"

	if _portal_active:
		push_warning("TransitionLayer: portal_enter called when already active!")
		return
	
	if texture == null:
		# nothing to grow. fall back to the iris so the caller still gets a transition.
		await play_iris_close(duration * 0.5)
		return

	_portal_active = true
	_set_gm_transitioning(true)

	_idle_strength = 0.0
	_idle_target = 0.0
	_idle_angle = 0.0
	_idle_breathe = 0.0
	_idle_flow = 0.0

	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	_portal_rect = TextureRect.new()
	_portal_rect.name = "ChapterPortalRect"
	_portal_rect.texture = texture
	_portal_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portal_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portal_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# this layer runs while the tree is paused, so the portal node must too.
	_portal_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	_portal_rect.position = start_rect.position
	_portal_rect.size = start_rect.size

	_portal_mat = ShaderMaterial.new()
	_portal_mat.shader = CHAPTER_PORTAL_SHADER
	_portal_mat.set_shader_parameter("progress", 0.0)
	_portal_mat.set_shader_parameter("idle_angle", 0.0)
	_portal_mat.set_shader_parameter("idle_breathe", 0.0)
	_portal_mat.set_shader_parameter("idle_flow", 0.0)
	_portal_mat.set_shader_parameter("idle_strength", 0.0)
	_portal_mat.set_shader_parameter("aspect_correction", Vector2(maxf(vp_size.x, 1.0) / maxf(vp_size.y, 1.0), 1.0))
	_portal_rect.material = _portal_mat

	# begin_pressed fires during input processing, so never add_child directly here.
	add_child.call_deferred(_portal_rect)
	await get_tree().process_frame

	_debug_phase_tag = "portal_rect_added"
	if ChapterLaunchSequence.PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] portal rect added to tree at %d ms[/color]" % Time.get_ticks_msec())

	if not is_instance_valid(_portal_rect):
		_portal_active = false
		_set_gm_transitioning(false)
		return

	# *****************((future audio spot: a rising portal whoosh goes here!))
	# /////////// if soundmanager: soundmanager.play_sfx("portal_open")

	_debug_phase_tag = "grow_started"
	if ChapterLaunchSequence.PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] grow started at %d ms[/color]" % Time.get_ticks_msec())

	# phase a: grow the art from the drawer's rect to fill the screen.
	var grow = create_tween().set_parallel(true).bind_node(_portal_rect)
	grow.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	grow.tween_property(_portal_rect, "position", Vector2.ZERO, duration * PORTAL_GROW_FRACTION)
	grow.tween_property(_portal_rect, "size", vp_size, duration * PORTAL_GROW_FRACTION)
	grow.chain().tween_callback(func():
		_idle_target = 1.0
	)

	# phase b: start the warp before the growth finishes so the two read as one motion.
	await get_tree().create_timer(duration * PORTAL_WARP_START_FRACTION).timeout
	if not is_instance_valid(_portal_rect):
		_portal_active = false
		_set_gm_transitioning(false)
		return

	_debug_phase_tag = "warp_started"
	if ChapterLaunchSequence.PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] warp started at %d ms[/color]" % Time.get_ticks_msec())

	var warp = create_tween().bind_node(_portal_rect)
	warp.tween_property(_portal_mat, "shader_parameter/progress", PORTAL_HOLD_PROGRESS, duration * PORTAL_WARP_FRACTION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await warp.finished

	_debug_phase_tag = "hold_established"
	if ChapterLaunchSequence.PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] hold established at %d ms[/color]" % Time.get_ticks_msec())
	DebugVRAM.snapshot("portal_hold_established")

func portal_exit(duration: float = 0.8) -> void:
	_debug_phase_tag = "portal_exit"
	if ChapterLaunchSequence.PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] portal_exit called at %d ms[/color]" % Time.get_ticks_msec())

	if not is_instance_valid(_portal_rect) or not is_instance_valid(_portal_mat):
		portal_abort()
		return

	_idle_target = 0.0

	var exit_tween = create_tween().bind_node(_portal_rect)
	exit_tween.tween_property(_portal_mat, "shader_parameter/progress", 1.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await exit_tween.finished

	# short hold on the flash. the CG phase's dialogue will start under this.
	await get_tree().create_timer(0.15).timeout

	# ***** TEST SLICE TAIL: fade the flash out and clean up. this whole block gets
	# replaced by the CG hand-off once the conversation scene exists. *****
	if is_instance_valid(_portal_rect):
		var out = create_tween().bind_node(_portal_rect)
		out.tween_property(_portal_rect, "modulate:a", 0.0, 0.4)
		await out.finished

	portal_abort()

func portal_abort() -> void:
	_portal_active = false
	_debug_phase_tag = ""
	if is_instance_valid(_active_balloon):
		_active_balloon.queue_free()
	_active_balloon = null
	# vram discipline: drop every reference to the art before the node frees.
	if is_instance_valid(_portal_rect):
		_portal_rect.texture = null
		_portal_rect.material = null
		_portal_rect.queue_free()
	_portal_rect = null
	_portal_mat = null
	_set_gm_transitioning(false)
	if ChapterLaunchSequence.PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] cleanup done at %d ms[/color]" % Time.get_ticks_msec())
	DebugVRAM.snapshot("portal_exit end")

func portal_fade_abort(fade_duration: float = 0.4) -> void:
	if is_instance_valid(_portal_rect):
		var fade = create_tween().bind_node(_portal_rect)
		fade.tween_property(_portal_rect, "modulate:a", 0.0, fade_duration)
		await fade.finished
	portal_abort()

const PORTAL_MIN_HOLD := 0.8
const CHAPTER_LAUNCH_DIALOGUE_PATH := "res://dialogue/chapter_launch.dialogue"
const CONVERSATION_BALLOON_SCENE := "res://conversation/conversationballoon.tscn"

func play_portal_monologue(dialogue_title: String, preloaded_resource: DialogueResource = null, preloaded_scene: PackedScene = null) -> void:
	if dialogue_title.strip_edges().is_empty():
		await get_tree().create_timer(PORTAL_MIN_HOLD).timeout
		return

	var dialogue_resource = preloaded_resource
	if not dialogue_resource:
		if not ResourceLoader.exists(CHAPTER_LAUNCH_DIALOGUE_PATH):
			push_warning("TransitionLayer: Chapter launch dialogue file not found.")
			await get_tree().create_timer(PORTAL_MIN_HOLD).timeout
			return
		dialogue_resource = load(CHAPTER_LAUNCH_DIALOGUE_PATH)

	if not dialogue_resource or not dialogue_resource.titles.has(dialogue_title):
		push_warning("TransitionLayer: Dialogue title '%s' not found in chapter_launch.dialogue." % dialogue_title)
		await get_tree().create_timer(PORTAL_MIN_HOLD).timeout
		return

	# Spawn the standard balloon
	var balloon_to_use = preloaded_scene if preloaded_scene else CONVERSATION_BALLOON_SCENE
	var balloon = DialogueManager.show_dialogue_balloon_scene(
		balloon_to_use,
		dialogue_resource,
		dialogue_title
	)

	if is_instance_valid(balloon):
		if balloon.get_parent():
			balloon.reparent(self)
		else:
			add_child(balloon)

		balloon.process_mode = Node.PROCESS_MODE_ALWAYS

	_debug_phase_tag = "balloon_shown"
	if ChapterLaunchSequence.PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] balloon shown at %d ms[/color]" % Time.get_ticks_msec())

	await DialogueManager.dialogue_ended

	_debug_phase_tag = "dialogue_ended"
	if ChapterLaunchSequence.PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] dialogue ended at %d ms[/color]" % Time.get_ticks_msec())

	if is_instance_valid(balloon):
		balloon.queue_free()

func show_loading_indicator() -> void:
	if not is_instance_valid(_loading_label): return
	_loading_shown_at_ms = Time.get_ticks_msec()
	_loading_label.move_to_front()
	_loading_label.modulate.a = 1.0
	_loading_label.visible = true
	if _loading_tween: _loading_tween.kill()
	_loading_tween = create_tween().set_loops()
	_loading_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_loading_tween.tween_property(_loading_label, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
	_loading_tween.tween_property(_loading_label, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

func hide_loading_indicator() -> void:
	if not is_instance_valid(_loading_label): return
	# anti-flicker: keep the label up for a beat on very fast loads
	var elapsed = Time.get_ticks_msec() - _loading_shown_at_ms
	if elapsed < 400:
		await get_tree().create_timer((400 - elapsed) / 1000.0).timeout
	if _loading_tween: _loading_tween.kill()
	_loading_label.visible = false
