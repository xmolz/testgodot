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

@onready var left_shutter = get_node_or_null("LeftShutter")
@onready var right_shutter = get_node_or_null("RightShutter")
@onready var iris_rect = get_node_or_null("IrisColorRect")
@onready var global_fade_rect = get_node_or_null("GlobalFadeRect")

func _ready():
	# this layer drives quit/game-over fades while the tree is paused,
	# so it must never pause with the rest of the world.
	process_mode = Node.PROCESS_MODE_ALWAYS
	open_instant()

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
	if _portal_active:
		push_warning("TransitionLayer: portal_enter called when already active!")
		return
	
	if texture == null:
		# nothing to grow. fall back to the iris so the caller still gets a transition.
		await play_iris_close(duration * 0.5)
		return

	_portal_active = true
	_set_gm_transitioning(true)

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
	_portal_mat.set_shader_parameter("idle_strength", 0.0)
	_portal_mat.set_shader_parameter("aspect_correction", Vector2(maxf(vp_size.x, 1.0) / maxf(vp_size.y, 1.0), 1.0))
	_portal_rect.material = _portal_mat

	# begin_pressed fires during input processing, so never add_child directly here.
	add_child.call_deferred(_portal_rect)
	await get_tree().process_frame

	if not is_instance_valid(_portal_rect):
		_portal_active = false
		_set_gm_transitioning(false)
		return

	# *****************((future audio spot: a rising portal whoosh goes here!))
	# /////////// if soundmanager: soundmanager.play_sfx("portal_open")

	# phase a: grow the art from the drawer's rect to fill the screen.
	var grow = create_tween().set_parallel(true).bind_node(_portal_rect)
	grow.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	grow.tween_property(_portal_rect, "position", Vector2.ZERO, duration * PORTAL_GROW_FRACTION)
	grow.tween_property(_portal_rect, "size", vp_size, duration * PORTAL_GROW_FRACTION)

	# phase b: start the warp before the growth finishes so the two read as one motion.
	await get_tree().create_timer(duration * PORTAL_WARP_START_FRACTION).timeout
	if not is_instance_valid(_portal_rect):
		_portal_active = false
		_set_gm_transitioning(false)
		return

	var warp = create_tween().bind_node(_portal_rect)
	warp.tween_property(_portal_mat, "shader_parameter/progress", PORTAL_HOLD_PROGRESS, duration * PORTAL_WARP_FRACTION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
	# tween idle_strength 0 -> 1 near the end
	var idle_tween = create_tween().bind_node(_portal_rect)
	idle_tween.tween_property(_portal_mat, "shader_parameter/idle_strength", 1.0, duration * PORTAL_WARP_FRACTION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await warp.finished

func portal_exit(duration: float = 0.8) -> void:
	if not is_instance_valid(_portal_rect) or not is_instance_valid(_portal_mat):
		portal_abort()
		return

	var exit_tween = create_tween().set_parallel(true).bind_node(_portal_rect)
	exit_tween.tween_property(_portal_mat, "shader_parameter/idle_strength", 0.0, duration * 0.5)
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
	# vram discipline: drop every reference to the art before the node frees.
	if is_instance_valid(_portal_rect):
		_portal_rect.texture = null
		_portal_rect.material = null
		_portal_rect.queue_free()
	_portal_rect = null
	_portal_mat = null
	_set_gm_transitioning(false)

const PORTAL_MIN_HOLD := 0.8

func play_portal_monologue(text: String) -> void:
	if text.strip_edges().is_empty():
		await get_tree().create_timer(PORTAL_MIN_HOLD).timeout
		return

	# fullscreen input catcher to swallow clicks/taps
	var catcher = Control.new()
	catcher.name = "PortalMonologueCatcher"
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(catcher)

	# monologue label centered lower-center above portal
	var label = Label.new()
	label.name = "PortalMonologueLabel"
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# style options
	var custom_font = load("res://Fonts/VarelaRound-Regular.ttf")
	if custom_font:
		label.add_theme_font_override("font", custom_font)
	
	var is_mobile = OS.has_feature("mobile")
	label.add_theme_font_size_override("font_size", 38 if is_mobile else 26)
	label.add_theme_color_override("font_color", Color(0.878431, 0.980392, 1.0, 1.0)) # cyan-white
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# shift slightly up so it's lower-center
	label.anchor_top = 0.70
	label.anchor_bottom = 0.85
	label.offset_left = 50
	label.offset_right = -50

	add_child(label)

	var lines = text.split("\n")
	var click_advanced = false
	var skip_requested = false

	# we can connect gui_input on catcher to detect click/taps
	catcher.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			click_advanced = true
	)

	# we can also listen to ui_accept manually
	# wait, can we do a custom input listener? Yes, _unhandled_input works but since catcher is a Control, gui_input is better.
	# We can use a small loop for each line
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue

		if not is_instance_valid(label):
			break

		label.text = ""
		click_advanced = false
		skip_requested = false

		# Typewriter effect
		var chars_to_show = line.length()
		var delay_per_char = 1.0 / 30.0 # ~30 chars per second
		
		for i in range(1, chars_to_show + 1):
			if not is_instance_valid(label):
				return
			if click_advanced or Input.is_action_just_pressed("ui_accept"):
				label.text = line
				click_advanced = false
				skip_requested = true
				break
			label.text = line.left(i)
			await get_tree().create_timer(delay_per_char).timeout

		# Wait for click/tap or ui_accept, OR auto-advance after 3.5s
		if not skip_requested:
			click_advanced = false
			var elapsed = 0.0
			var poll_interval = 0.05
			while elapsed < 3.5:
				if not is_instance_valid(label):
					return
				if click_advanced or Input.is_action_just_pressed("ui_accept"):
					break
				await get_tree().create_timer(poll_interval).timeout
				elapsed += poll_interval

	# Clean up nodes
	if is_instance_valid(label):
		label.queue_free()
	if is_instance_valid(catcher):
		catcher.queue_free()
