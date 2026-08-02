# sprite_conversation_test.gd — dev-only harness for the two-character conversation layout.
# protagonist parks on the left, everyone else enters from the right, says a line or two, leaves.
#
# deliberately does NOT use AdvancedConversationOverlay: that one normalises every sprite to the
# screen height, which is exactly the thing being eyeballed here. sprites are drawn at native
# resolution x one shared multiplier so relative sizes stay honest. press F to flip into the
# production fit-to-height behaviour and compare.
extends Control

const DIALOGUE_PATH := "res://Dev/sprite_test.dialogue"
const PROFILE_DIR := "res://Dev/test_profiles/"

# actor_id -> profile filename. order here is also the readout order.
const PROFILES := {
	"Protag": "protag_test.tres",
	"Alyssa": "alyssa_test.tres",
	"Troy": "troy_test.tres",
	"Professor": "professor_test.tres",
	"Layla": "layla_test.tres",
	"Julian": "julian_test.tres",
}

# stage geometry, 1920x1080 design viewport. bottom-center anchored.
const LEFT_X := 520.0
const RIGHT_X := 1400.0
const BASELINE_Y := 1080.0
const OFFSCREEN_PUSH := 900.0
const SLIDE_TIME := 0.35

# backdrops to cycle: neutral gray, black, white, magenta (magenta exposes matte fringing).
const BACKDROPS := [
	Color(0.18, 0.18, 0.2, 1.0),
	Color(0.0, 0.0, 0.0, 1.0),
	Color(1.0, 1.0, 1.0, 1.0),
	Color(0.85, 0.15, 0.6, 1.0),
]

# one multiplier applied to every sprite equally, so relative sizes stay honest.
# drag it in the inspector on the scene root, then F6. also live-adjustable with - / = at runtime.
# 0.5 puts a 1740px sprite at 870px, comfortably inside the 1080 viewport.
@export_range(0.05, 2.0, 0.01) var global_scale: float = 0.5:
	set(value):
		global_scale = value
		_reapply_all()

var fit_mode: bool = false
var _base_scale: float = 0.5

# whoever parks on the left for the whole run. must match an actor_id in PROFILES.
@export var left_actor: String = "Julian"

# mirror everyone who enters from the right so they face the anchor. turn this off if the source
# art already faces left.
@export var flip_right_slot: bool = true

# per-character multipliers, stacked on top of global_scale. 1.0 = no change.
@export_range(0.05, 2.0, 0.01) var layla_scale: float = 1.0:
	set(value):
		layla_scale = value
		_reapply_all()

@export_range(0.05, 2.0, 0.01) var protag_scale: float = 1.0:
	set(value):
		protag_scale = value
		_reapply_all()

var _textures: Dictionary = {}      # actor_id -> Texture2D
var _char_scales: Dictionary = {}   # actor_id -> profile.default_scale
var _actors: Dictionary = {}        # actor_id -> TextureRect (on stage right now)
var _slots: Dictionary = {}         # actor_id -> slot x
var _flipped: Dictionary = {}       # actor_id -> bool

var _stage: Control
var _backdrop: ColorRect
var _readout: Label
var _balloon: Node = null
var _backdrop_index: int = 0


func _ready() -> void:
	_base_scale = global_scale
	_build_ui()
	_load_profiles()
	_start_run()


# ****************************[setup]
func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.color = BACKDROPS[_backdrop_index]
	add_child(_backdrop)

	_stage = Control.new()
	_stage.name = "Stage"
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_readout = Label.new()
	_readout.name = "Readout"
	_readout.position = Vector2(24, 20)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono := load("res://RobotoMono-VariableFont_wght.ttf")
	if mono:
		_readout.add_theme_font_override("font", mono)
	_readout.add_theme_font_size_override("font_size", 18)
	_readout.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7, 1.0))
	_readout.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_readout.add_theme_constant_override("outline_size", 6)
	add_child(_readout)


func _load_profiles() -> void:
	for actor_id in PROFILES.keys():
		var path: String = PROFILE_DIR + PROFILES[actor_id]
		if not ResourceLoader.exists(path):
			push_warning("sprite test: missing profile %s" % path)
			continue
		var profile = load(path)
		if profile == null:
			push_warning("sprite test: could not load profile %s" % path)
			continue
		var tex_path: String = String(profile.expressions.get("base", ""))
		if tex_path.is_empty() or not ResourceLoader.exists(tex_path):
			push_warning("sprite test: missing texture for %s (%s)" % [actor_id, tex_path])
			continue
		var tex: Texture2D = load(tex_path)
		if tex == null:
			push_warning("sprite test: could not load texture %s" % tex_path)
			continue
		_textures[actor_id] = tex
		_char_scales[actor_id] = float(profile.default_scale)
		print("sprite test: %s  native %dx%d" % [actor_id, int(tex.get_size().x), int(tex.get_size().y)])


func _start_run() -> void:
	for id in _actors.keys():
		var r = _actors[id]
		if is_instance_valid(r):
			r.queue_free()
	_actors.clear()
	_slots.clear()
	_flipped.clear()

	# left_actor is permanent furniture on the left
	var p := _spawn(left_actor, LEFT_X)
	if p:
		p.modulate.a = 1.0

	if is_instance_valid(_balloon):
		_balloon.queue_free()
		_balloon = null

	var dlg = load(DIALOGUE_PATH)
	if dlg == null:
		push_warning("sprite test: could not load %s" % DIALOGUE_PATH)
	else:
		_balloon = DialogueManager.show_dialogue_balloon_scene(
			preload("res://conversation/conversationballoon.tscn"),
			dlg,
			"start",
			[self]
		)

	_refresh_readout()


# ****************************[mutations called from the dialogue file]
func enter_right(actor_id: String) -> void:
	if _actors.has(actor_id):
		return
	var r := _spawn(actor_id, RIGHT_X, flip_right_slot)
	if r == null:
		return
	var target_x: float = r.position.x
	r.position.x = target_x + OFFSCREEN_PUSH
	r.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(r, "position:x", target_x, SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(r, "modulate:a", 1.0, SLIDE_TIME)
	_refresh_readout()


func leave_right(actor_id: String) -> void:
	if not _actors.has(actor_id):
		return
	var r: TextureRect = _actors[actor_id]
	_actors.erase(actor_id)
	_slots.erase(actor_id)
	_flipped.erase(actor_id)
	if not is_instance_valid(r):
		_refresh_readout()
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(r, "position:x", r.position.x + OFFSCREEN_PUSH, SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(r, "modulate:a", 0.0, SLIDE_TIME)
	t.chain().tween_callback(r.queue_free)
	_refresh_readout()


# ****************************[sprite plumbing]
func _spawn(actor_id: String, slot_x: float, flipped: bool = false) -> TextureRect:
	if not _textures.has(actor_id):
		push_warning("sprite test: no texture loaded for %s" % actor_id)
		return null
	var tex: Texture2D = _textures[actor_id]
	var r := TextureRect.new()
	r.name = actor_id
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# bottom-center pivot, same convention as AdvancedConversationOverlay
	r.pivot_offset = Vector2(tex.get_size().x * 0.5, tex.get_size().y)
	_stage.add_child(r)
	_actors[actor_id] = r
	_slots[actor_id] = slot_x
	_flipped[actor_id] = flipped
	_apply_transform(actor_id)
	return r


func _scale_for(actor_id: String) -> float:
	if not _textures.has(actor_id):
		return global_scale
	var tex: Texture2D = _textures[actor_id]
	var s: float = global_scale * float(_char_scales.get(actor_id, 1.0)) * _actor_multiplier(actor_id)
	if fit_mode:
		# production behaviour: normalise every sprite to the viewport height first
		var screen_h: float = float(get_viewport_rect().size.y)
		s *= screen_h / float(tex.get_size().y)
	return s

func _actor_multiplier(actor_id: String) -> float:
	match actor_id:
		"Layla":
			return layla_scale
		"Protag":
			return protag_scale
		_:
			return 1.0


func _apply_transform(actor_id: String) -> void:
	if not _actors.has(actor_id):
		return
	var r: TextureRect = _actors[actor_id]
	if not is_instance_valid(r):
		return
	var s: float = _scale_for(actor_id)
	# negative x mirrors about the bottom-center pivot, so the slot position is unaffected
	var sx: float = -s if bool(_flipped.get(actor_id, false)) else s
	r.scale = Vector2(sx, s)
	var slot_x: float = float(_slots.get(actor_id, LEFT_X))
	r.position = Vector2(slot_x, BASELINE_Y) - r.pivot_offset


func _reapply_all() -> void:
	for id in _actors.keys():
		_apply_transform(id)
	_refresh_readout()


# ****************************[readout]
func _refresh_readout() -> void:
	if not is_instance_valid(_readout):
		return
	var screen_h: float = float(get_viewport_rect().size.y)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("MODE %s   GLOBAL SCALE %.2f   viewport %dx%d" % [
		("FIT-TO-HEIGHT (production)" if fit_mode else "NATIVE PX"),
		global_scale,
		int(get_viewport_rect().size.x),
		int(screen_h)
	])
	lines.append("- / =  scale    0  reset    F  mode    B  backdrop    R  restart")
	lines.append("per-actor: Layla x%.2f   Protag x%.2f   (inspector only)" % [layla_scale, protag_scale])
	lines.append("")
	for actor_id in PROFILES.keys():
		if not _textures.has(actor_id):
			lines.append("%s  MISSING" % actor_id)
			continue
		var tex: Texture2D = _textures[actor_id]
		var s: float = _scale_for(actor_id)
		var drawn_h: float = tex.get_size().y * s
		var mark: String = "*" if _actors.has(actor_id) else " "
		lines.append("%s %s  native %dx%d   x%.2f   drawn h %d px   %d%% of screen" % [
			mark,
			actor_id,
			int(tex.get_size().x),
			int(tex.get_size().y),
			_actor_multiplier(actor_id),
			int(round(drawn_h)),
			int(round(drawn_h / screen_h * 100.0))
		])
	_readout.text = "\n".join(lines)


# ****************************[dev keys]
# uses _input, not _unhandled_input: the balloon swallows unhandled input by design.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return

	match k.keycode:
		KEY_EQUAL, KEY_KP_ADD:
			global_scale = min(global_scale + 0.05, 4.0)
			_reapply_all()
		KEY_MINUS, KEY_KP_SUBTRACT:
			global_scale = max(global_scale - 0.05, 0.05)
			_reapply_all()
		KEY_0, KEY_KP_0:
			global_scale = _base_scale
			_reapply_all()
		KEY_F:
			fit_mode = not fit_mode
			_reapply_all()
		KEY_B:
			_backdrop_index = (_backdrop_index + 1) % BACKDROPS.size()
			if is_instance_valid(_backdrop):
				_backdrop.color = BACKDROPS[_backdrop_index]
		KEY_R:
			_start_run()
		_:
			return
	get_viewport().set_input_as_handled()
