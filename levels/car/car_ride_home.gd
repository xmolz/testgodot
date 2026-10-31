# car_ride_home.gd - the real car ride home (step 2.282). a production copy of Dev/car_ride_test.gd.
extends Control
## step 2.229-2.232: car ride test scene (dev). Fiona drives Layla's car home; the outside scrolls past
## the semi-transparent windows, the car vibrates and bumps now and then, and a dialogue plays over it.
## open this scene and run it with F6.
## dev keys (chosen so they don't clash with the dialogue balloon):
##   B = bump, [ / ] = slower / faster, T = cycle day / golden hour / night, V = show the window split.
## dialogue hooks (the scene is passed to the dialogue as a game state):
##   do car_darkness()               screen to black at once (the balloon stays on top)
##   do car_reveal(1.5)              fade the black away over 1.5 s
##   do car_bump(1.0)                a bump; 0.5 small, 1.5 big
##   do car_speed(0.0, 1.5)          ease the driving speed to 0 (a red light) over 1.5 s; 1.0 = cruising
##   do car_think_begin()            Fiona drifts into thought: a very slow push-in on her face, the dream
##                                   CG fading in as a faint mental image, and a light dream haze
##   do car_think_end(0.8)           snap out of it: zoom back out, the memory and the haze fade away
##   do car_fiona("sideways smile")  step 2.299: switch Fiona's eyes / mouth / pose by option name, with a
##                                   short crossfade; "default" puts all of them back (levels/car/car_rig.gd)
##   do car_closeup()                step 2.305: a quick fade through black to a close-up of Fiona's face,
##                                   for her inner moments. car_closeup(0.4) = seconds per half of the fade
##   do car_closeup_end()            fade back to the normal view. car_closeup_end(0.4) = same
##                                   (step 2.307: car_fiona() changes asked for during a fade never play
##                                   mid-cut: going in, they happen while the screen is black, so the
##                                   close-up opens on the new face; coming out, they wait until the
##                                   normal view has faded back in)
##   do car_layla_closeup()          step 2.388: a slow push-in on Layla's face (no fade), for her own
##                                   moments; car_layla_closeup_end() eases back out. (seconds optional)
##   do car_layla_mood(warm, distant) step 2.388: car_layla(warm), or car_layla(distant) when Layla is
##                                   distant (layla_closeness below 0)

const SHADER_PATH := "res://levels/car/car_ride.gdshader"
const MEMORY_SHADER_PATH := "res://levels/car/car_memory_overlay.gdshader"
const HAZE_SHADER_PATH := "res://ui/dream_haze.gdshader"
## step 2.397: the freeway loop under the whole ride
const ROAD_SOUND_PATH := "res://Sfx/freeway_ambience.ogg"
const BALLOON_PATH := "res://conversation/conversationballoon.tscn"
const CAR_RIG_SCRIPT := preload("res://levels/car/car_rig.gd")

@export_file("*.png", "*.webp", "*.jpg") var car_image_path: String = "res://Backgrounds/Car/car_interior.png"
## step 2.299: the layered car art (base + Fiona's parts) made by Dev/car_test/car_parts_cutter.gd.
## when it's missing, the scene falls back to the single image in car_image_path.
@export_file("*.json") var car_parts_path: String = "res://Backgrounds/Car/parts/car_parts.json"
@export_enum("day", "golden", "night") var time_of_day: String = "day"
## start on a black screen (the dialogue reveals the car with car_reveal)
@export var start_dark: bool = true

@export_group("Dialogue")
@export var play_dialogue: bool = true
@export_file("*.dialogue") var dialogue_path: String = "res://dialogue/car_ride_home.dialogue"
@export var dialogue_title: String = "start"
## seconds before the first line
@export var dialogue_delay: float = 1.0
## centre the dialogue choices, like the test level (read by conversationballoon.gd)
@export var center_dialogue_responses: bool = true

@export_group("Test memories (dev)")
## fakes Layla's mood and the chapter memories before the dialogue starts.
## untick to use the real game flags (e.g. when arriving from the university level).
@export var test_memories: bool = false
## dev only: the on-screen key help (B bump, [ ] speed, T light, V split) and those keys.
@export var show_dev_keys: bool = false
@export_enum("close", "neutral", "distant") var test_mood: String = "close"
@export_enum("not asked", "comforted", "reprimanded") var test_work: String = "comforted"
@export_enum("refused help", "nearly told") var test_julian: String = "refused help"
@export_enum("none", "other snack", "protein bar") var test_snack: String = "protein bar"
## Layla already called Fiona "Fee" at the vending machine (only happens when close + protein bar)
@export var test_said_fee: bool = true
## the janitor route: what Fiona did to get past Jayce (flash him / see his camera / both)
@export_enum("none", "flashed", "camera", "both") var test_janitor: String = "flashed"

@export_group("Thinking (push-in + memory)")
## Fiona's face in the car art, as a fraction of the screen (after the overscan)
@export var fiona_face: Vector2 = Vector2(0.25, 0.40)
## where her face ends up on screen at the end of the push-in
@export var think_frame: Vector2 = Vector2(0.40, 0.42)
@export var think_zoom: float = 1.6
## seconds for the full push-in (very slow on purpose)
@export var think_seconds: float = 18.0
@export_file("*.png", "*.jpg", "*.webp") var memory_image_path: String = "res://Backgrounds/CG/at_the_door.png"
## how visible the memory gets (0..1). keep it low: a mental image, not a cut
@export var memory_opacity: float = 0.3
@export var memory_fade_in: float = 6.0
## dream haze strength while thinking (0..1)
@export var think_haze: float = 0.4
## step 2.305: car_closeup() cuts to Fiona's face at this zoom (2 is about the art's full detail at 1080p)
@export var closeup_zoom: float = 2.2
## where her face sits on screen in the close-up (fractions of the screen)
@export var closeup_frame: Vector2 = Vector2(0.5, 0.45)
## seconds for each half of the fade cut (out to black, then back in)
@export var closeup_fade: float = 0.25
## step 2.388: car_layla_closeup() pushes in on Layla's face: where her face sits in the normal view
## (fractions of the screen), where it ends up, how far in, and how long the push takes
@export var layla_face: Vector2 = Vector2(0.56, 0.43)
@export var layla_frame: Vector2 = Vector2(0.5, 0.45)
@export var layla_zoom: float = 1.8
@export var layla_zoom_seconds: float = 1.2

@export_group("Scenery layers (empty = placeholder)")
## wide, horizontally seamless images, fitted to the screen height. mid and near need transparent skies.
@export var far_texture: Texture2D
@export var mid_texture: Texture2D
@export var near_texture: Texture2D

@export_group("Motion")
## speeds in screen widths per second at cruising speed (step 2.230: half of 2.229's, the chosen value)
@export var far_speed: float = 0.01
@export var mid_speed: float = 0.08
@export var near_speed: float = 0.65
## where the left windows end and the right window begins (fraction of the screen width)
@export_range(0.0, 1.0, 0.001) var split_x: float = 0.463
## total smear width of the near layer at cruising speed (screen-height units); scales with speed
@export var near_blur: float = 0.07
@export var vibration_px: float = 0.6
## bump strength; 10 is a normal pothole
@export var bump_strength: float = 10.0
## seconds between random bumps (min, max). 0,0 = no random bumps
@export var bump_every: Vector2 = Vector2(3.0, 7.0)
## the car art is scaled up this much so its edges never show during a bump
@export var overscan: float = 1.03
@export var show_split: bool = false

@export_group("Road sound")
## step 2.397: the freeway loop (ROAD_SOUND_PATH) under the whole ride, on the Ambience bus. its volume at
## cruising speed, in dB. it's read every frame, so it can be changed while the scene runs.
@export var road_db: float = 0.0
## how much quieter it gets as the car slows to a stop (dB, eased along with car_speed)
@export var road_stopped_db: float = -12.0
## its pitch with the car stopped (1.0 at cruising speed): the engine and tyres winding down
@export_range(0.5, 1.0, 0.01) var road_stopped_pitch: float = 0.85
## how much quieter it gets while Fiona daydreams (dB). it sinks as she drifts off and comes back as
## she snaps out of it (with the bump, on the distant ride)
@export var road_daydream_db: float = -9.0
## seconds it takes to rise at the start, under the black before the car is revealed
@export var road_fade_in: float = 3.0

# per time of day: car tint, sky, and the placeholder shapes' colours
const LOOKS := {
	"day": {
		"tint": Color(1, 1, 1), "sky_top": Color(0.62, 0.76, 0.91), "sky_bottom": Color(0.87, 0.91, 0.95),
		"skyline_col": Color(0.71, 0.78, 0.84), "bldg_back_col": Color(0.66, 0.70, 0.77), "bldg_col": Color(0.55, 0.59, 0.66),
		"window_col": Color(0.38, 0.45, 0.58), "lit_col": Color(1.0, 0.85, 0.55), "hill_col": Color(0.50, 0.62, 0.53),
		"tree_col": Color(0.27, 0.42, 0.32), "trunk_col": Color(0.30, 0.24, 0.20), "pole_col": Color(0.25, 0.25, 0.28),
		"road_col": Color(0.36, 0.36, 0.38), "lit_amount": 0.0,
	},
	"golden": {
		"tint": Color(1.0, 0.9, 0.8), "sky_top": Color(0.95, 0.72, 0.48), "sky_bottom": Color(0.97, 0.86, 0.7),
		"skyline_col": Color(0.85, 0.66, 0.55), "bldg_back_col": Color(0.72, 0.58, 0.55), "bldg_col": Color(0.58, 0.47, 0.46),
		"window_col": Color(0.45, 0.35, 0.38), "lit_col": Color(1.0, 0.82, 0.5), "hill_col": Color(0.55, 0.50, 0.36),
		"tree_col": Color(0.33, 0.30, 0.20), "trunk_col": Color(0.25, 0.18, 0.14), "pole_col": Color(0.22, 0.18, 0.17),
		"road_col": Color(0.33, 0.28, 0.27), "lit_amount": 0.2,
	},
	"night": {
		"tint": Color(0.55, 0.58, 0.78), "sky_top": Color(0.08, 0.1, 0.2), "sky_bottom": Color(0.16, 0.18, 0.31),
		"skyline_col": Color(0.13, 0.15, 0.25), "bldg_back_col": Color(0.12, 0.13, 0.21), "bldg_col": Color(0.10, 0.11, 0.17),
		"window_col": Color(0.14, 0.16, 0.24), "lit_col": Color(1.0, 0.82, 0.5), "hill_col": Color(0.08, 0.10, 0.12),
		"tree_col": Color(0.05, 0.07, 0.08), "trunk_col": Color(0.05, 0.05, 0.06), "pole_col": Color(0.05, 0.05, 0.07),
		"road_col": Color(0.09, 0.09, 0.11), "lit_amount": 0.55,
	},
}
const LOOK_ORDER := ["day", "golden", "night"]

var _world: Control          # scenery + car art; this is what the push-in zooms
var _bg: ColorRect
var _mat: ShaderMaterial
var _car: Control            # the car art: the rig below, or the single image (fallback)
var _rig: Control            # levels/car/car_rig.gd; null when falling back to the single image
var _split_line: ColorRect
var _memory: TextureRect     # the dream CG, faint, over the world (not zoomed)
var _memory_mat: ShaderMaterial
var _haze: ColorRect         # ui/dream_haze.gdshader, reads the screen underneath
var _haze_mat: ShaderMaterial
var _black: ColorRect
var _scroll := 0.0
var _speed := 1.0
var _speed_tween: Tween
var _think_t := 0.0
var _cut_busy := false       # step 2.306: a close-up fade cut is running
var _cut_queue: Array = []   # car_fiona() calls held until it finishes: [spec, seconds]
var _think_tween: Tween
var _layla_tween: Tween      # step 2.388: the push-in on Layla's face
var _layla_t := 0.0
var _fx_tween: Tween
var _black_tween: Tween
var _vib_t := 0.0
var _bump_y := 0.0
var _bump_v := 0.0
var _next_bump := 3.0
# step 2.397: the road sound
var _road: AudioStreamPlayer
var _road_fade := 0.0          # 0..1: rises at the start of the ride, falls with car_end
var _road_fade_tween: Tween
var _road_dream_db := 0.0      # 0, or road_daydream_db while Fiona daydreams
var _road_dream_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_world = Control.new()
	_world.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	_bg.material = _mat
	_world.add_child(_bg)

	_make_car()

	_split_line = ColorRect.new()
	_split_line.color = Color(1.0, 0.3, 0.55, 0.9)
	_split_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_split_line)

	_memory = TextureRect.new()
	_memory.set_anchors_preset(Control.PRESET_FULL_RECT)
	_memory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_memory.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_memory.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(memory_image_path):
		_memory.texture = load(memory_image_path)
	else:
		push_warning("car_ride_test: no memory image at %s." % memory_image_path)
	_memory_mat = ShaderMaterial.new()
	_memory_mat.shader = load(MEMORY_SHADER_PATH)
	_memory_mat.set_shader_parameter("opacity", 0.0)
	_memory.material = _memory_mat
	_memory.visible = false
	add_child(_memory)

	_haze = ColorRect.new()
	_haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = load(HAZE_SHADER_PATH)
	_haze_mat.set_shader_parameter("amount", 0.0)
	_haze.material = _haze_mat
	_haze.visible = false
	add_child(_haze)

	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.color = Color(0, 0, 0, 1.0 if start_dark else 0.0)
	add_child(_black)

	if show_dev_keys:
		var help := Label.new()
		help.text = "B bump   [ ] speed   T light   V split"
		help.position = Vector2(16, 12)
		help.mouse_filter = Control.MOUSE_FILTER_IGNORE
		help.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		help.add_theme_constant_override("outline_size", 4)
		add_child(help)

	_apply_layers()
	_apply_look()
	_schedule_bump()
	_start_road_sound()   # step 2.397

	if play_dialogue:
		get_tree().create_timer(dialogue_delay).timeout.connect(_start_dialogue)


func _start_dialogue() -> void:
	if not ResourceLoader.exists(dialogue_path):
		push_warning("car_ride_test: no dialogue at %s." % dialogue_path)
		return
	_apply_test_memories()
	var res = load(dialogue_path)
	DialogueManager.show_dialogue_balloon_scene(BALLOON_PATH, res, dialogue_title, [self])


# step 2.238: dev-only stand-ins for the mood and the "kb_" chapter memories the dialogue reads.
func _apply_test_memories() -> void:
	if not test_memories:
		return
	var target: float = 4.0
	match test_mood:
		"neutral":
			target = 1.0
		"distant":
			target = -1.0
	Flags.add_game_counter("layla_closeness", target - Flags.get_game_counter("layla_closeness"))
	Flags.set_game_flag("kb_layla_work_comforted", test_work == "comforted")
	Flags.set_game_flag("kb_layla_work_reprimanded", test_work == "reprimanded")
	Flags.set_game_flag("kb_julian_refused_help", test_julian == "refused help")
	Flags.set_game_flag("kb_julian_nearly_told_truth", test_julian == "nearly told")
	Flags.set_game_flag("kb_layla_gift_given", test_snack != "none")
	Flags.set_game_flag("kb_layla_gift_loved", test_snack == "protein bar")
	Flags.set_game_flag("kb_layla_said_fee", test_said_fee)
	Flags.set_game_flag("kb_jayce_flashed", test_janitor == "flashed" or test_janitor == "both")
	Flags.set_game_flag("kb_jayce_camera_seen", test_janitor == "camera" or test_janitor == "both")
	print_rich("[color=orange]car_ride_test: test memories on — mood %s, work %s, julian %s, snack %s, fee %s[/color]" % [test_mood, test_work, test_julian, test_snack, test_said_fee])


# --- dialogue hooks ---------------------------------------------------------

func car_darkness() -> void:
	if _black_tween and _black_tween.is_valid():
		_black_tween.kill()
	_black.color.a = 1.0


func car_reveal(seconds: float = 1.5) -> void:
	if _black_tween and _black_tween.is_valid():
		_black_tween.kill()
	_black_tween = create_tween()
	_black_tween.tween_property(_black, "color:a", 0.0, maxf(0.01, seconds)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# end of the ride: fade to black, then hand back to the memory box.
func car_end(seconds: float = 2.0) -> void:
	# step 2.405: and the music
	if SoundManager:
		SoundManager.fade_out_music(maxf(0.01, seconds))
	# step 2.397: the road sound fades with the picture
	if _road_fade_tween and _road_fade_tween.is_valid():
		_road_fade_tween.kill()
	_road_fade_tween = create_tween()
	_road_fade_tween.tween_property(self, "_road_fade", 0.0, maxf(0.01, seconds)).set_trans(Tween.TRANS_SINE)
	if _black_tween and _black_tween.is_valid():
		_black_tween.kill()
	_black_tween = create_tween()
	_black_tween.tween_property(_black, "color:a", 1.0, maxf(0.01, seconds)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# step 2.308: reaching the end of the ride finishes the chapter (unlocking the next one), then back to the box
	_black_tween.tween_callback(func():
		ChapterLaunchSequence.complete_active_chapter()
		ChapterLaunchSequence.return_to_hub())


func car_bump(strength: float = 1.0) -> void:
	bump(strength)
	# step 2.392: the road thump, scaled to the bump: full volume at 1.0, about -6 dB at 0.5. only the
	# dialogue's bumps thump; the random bumps while driving stay silent.
	if SoundManager:
		SoundManager.play_sfx("road_thump", 1.0, linear_to_db(clampf(strength, 0.1, 1.5)))


func car_speed(target: float = 1.0, seconds: float = 1.2) -> void:
	if _speed_tween and _speed_tween.is_valid():
		_speed_tween.kill()
	_speed_tween = create_tween()
	_speed_tween.tween_property(self, "_speed", maxf(0.0, target), maxf(0.01, seconds)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# step 2.299: Fiona's eyes / mouth / pose by option name, e.g. car_fiona("sideways open_happy hand_up").
# the names are the option parts of the art files (4_fiona_eyes @sideways.png -> sideways); "default"
# puts all of them back. does nothing on the single-image fallback.
func car_fiona(spec: String, seconds: float = -1.0) -> void:
	# step 2.306: during a close-up fade cut, changes wait until the cut has faded back in
	if _cut_busy:
		_cut_queue.append([spec, seconds])
		return
	if _rig:
		_rig.apply(spec, "fiona_", seconds)


# step 2.383: Layla's eyes / brows / mouth (and later her pose) by option name, the same way as
# car_fiona(), e.g. car_layla("closed open_happy"). the names are the option parts of her art files
# (4_layla_eyes @Backgrounds\Car\source\4_layla_eyes@closed.png -> closed); "default" puts all of hers back. held during a fade cut, too.
func car_layla(spec: String, seconds: float = -1.0) -> void:
	if _cut_busy:
		_cut_queue.append([spec, seconds, "layla_"])
		return
	if _rig:
		_rig.apply(spec, "layla_", seconds)


# step 2.388: car_layla(warm), or car_layla(distant) when Layla is distant (closeness below 0). for cues
# every mood shares, like her face as the ride starts.
func car_layla_mood(warm: String, distant: String, seconds: float = -1.0) -> void:
	car_layla(warm if Flags.get_game_counter("layla_closeness") >= 0 else distant, seconds)


# step 2.388: a slow push-in on Layla's face (no fade), and back out. seconds < 0 = layla_zoom_seconds.
# a car_closeup() (Fiona's fade cut) replaces it.
func car_layla_closeup(seconds: float = -1.0) -> void:
	_push_layla(1.0, seconds)


func car_layla_closeup_end(seconds: float = -1.0) -> void:
	_push_layla(0.0, seconds)


func _push_layla(target: float, seconds: float) -> void:
	if _layla_tween and _layla_tween.is_valid():
		_layla_tween.kill()
	var s: float = maxf(0.01, layla_zoom_seconds if seconds < 0.0 else seconds)
	_layla_tween = create_tween()
	_layla_tween.tween_method(_set_layla_push, _layla_t, target, s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_layla_push(t: float) -> void:
	_layla_t = t
	_frame_world(lerpf(1.0, layla_zoom, t), layla_frame, t, layla_face)


# Fiona drifts into thought: a very slow push-in on her face, the dream CG fading in as a faint
# mental image, and a light dream haze over everything (the balloon stays clear on its own layer).
func car_think_begin() -> void:
	_tween_road_dream(road_daydream_db, memory_fade_in)   # step 2.397: the road sinks as she drifts off
	if _think_tween and _think_tween.is_valid():
		_think_tween.kill()
	_think_tween = create_tween()
	_think_tween.tween_method(_set_think, _think_t, 1.0, maxf(0.01, think_seconds * (1.0 - _think_t))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	_memory.visible = true
	_haze.visible = true
	_fx_tween = create_tween().set_parallel(true)
	_fx_tween.tween_method(func(v): _memory_mat.set_shader_parameter("opacity", v),
		float(_memory_mat.get_shader_parameter("opacity")), memory_opacity, memory_fade_in).set_trans(Tween.TRANS_SINE)
	_fx_tween.tween_method(func(v): _haze_mat.set_shader_parameter("amount", v),
		float(_haze_mat.get_shader_parameter("amount")), think_haze, memory_fade_in).set_trans(Tween.TRANS_SINE)


# step 2.305: a quick fade through black to a close-up of Fiona's face, for her inner moments.
# seconds is each half of the fade (< 0 = closeup_fade). car_closeup_end() fades back to the normal view.
func car_closeup(seconds: float = -1.0) -> void:
	_fade_cut(true, seconds)


func car_closeup_end(seconds: float = -1.0) -> void:
	_fade_cut(false, seconds)


func _fade_cut(close: bool, seconds: float) -> void:
	var half: float = maxf(0.01, closeup_fade if seconds < 0.0 else seconds)
	if _think_tween and _think_tween.is_valid():
		_think_tween.kill()
	if _layla_tween and _layla_tween.is_valid():   # step 2.388
		_layla_tween.kill()
	if _black_tween and _black_tween.is_valid():
		_black_tween.kill()
	_black_tween = create_tween()
	_black_tween.tween_property(_black, "color:a", 1.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_black_tween.tween_callback(func():
		_think_t = 0.0
		_layla_t = 0.0   # step 2.388
		if close:
			_frame_world(closeup_zoom, closeup_frame, 1.0)
			# step 2.307: going in, her change happens while the screen is black
			_finish_cut(0.0)
		else:
			_frame_world(1.0, closeup_frame, 0.0)
	)
	_black_tween.tween_property(_black, "color:a", 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_black_tween.tween_callback(_finish_cut)
	_cut_busy = true


# step 2.306: play Fiona's changes that were held during a fade cut. fade < 0 keeps each change's own
# crossfade (after fading back out of a close-up); 0 swaps instantly (behind the black, going in).
func _finish_cut(fade: float = -1.0) -> void:
	_cut_busy = false
	var queued: Array = _cut_queue.duplicate()
	_cut_queue.clear()
	for q in queued:
		# step 2.383: entries from car_layla() carry "layla_" as a third item
		if q.size() > 2 and q[2] == "layla_":
			car_layla(q[0], fade if fade >= 0.0 else q[1])
		else:
			car_fiona(q[0], fade if fade >= 0.0 else q[1])


# snap out of it: everything stops, the camera pulls back out, the memory and the haze fade away.
func car_think_end(seconds: float = 0.8) -> void:
	var s: float = maxf(0.01, seconds)
	_tween_road_dream(0.0, s)   # step 2.397: and comes back as she snaps out of it
	if _think_tween and _think_tween.is_valid():
		_think_tween.kill()
	_think_tween = create_tween()
	_think_tween.tween_method(_set_think, _think_t, 0.0, s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	_fx_tween = create_tween().set_parallel(true)
	_fx_tween.tween_method(func(v): _memory_mat.set_shader_parameter("opacity", v),
		float(_memory_mat.get_shader_parameter("opacity")), 0.0, s * 0.6)
	_fx_tween.chain().tween_callback(func():
		_memory.visible = false
		_haze.visible = false
	)


# --- internals --------------------------------------------------------------

# step 2.397: the freeway loop under the ride, on the Ambience bus. _process sets its volume and pitch from
# the car's speed every frame; it goes when the scene does.
func _start_road_sound() -> void:
	if not ResourceLoader.exists(ROAD_SOUND_PATH):
		push_warning("car_ride_home: no road sound at %s." % ROAD_SOUND_PATH)
		return
	var stream = load(ROAD_SOUND_PATH)
	if stream is AudioStreamOggVorbis:
		stream.loop = true   # it loops even if the import's Loop box was left unticked
	_road = AudioStreamPlayer.new()
	_road.stream = stream
	_road.bus = "Ambience"
	_road.process_mode = Node.PROCESS_MODE_ALWAYS   # keeps going under the pause menu, like other ambience
	_road.volume_db = -80.0
	add_child(_road)
	_road.play()
	_road_fade_tween = create_tween()
	_road_fade_tween.tween_property(self, "_road_fade", 1.0, maxf(0.01, road_fade_in)).set_trans(Tween.TRANS_SINE)


func _update_road_sound() -> void:
	if _road == null:
		return
	var moving: float = clampf(_speed, 0.0, 1.0)
	_road.volume_db = road_db + lerpf(road_stopped_db, 0.0, moving) + _road_dream_db + linear_to_db(maxf(_road_fade, 0.0001))
	_road.pitch_scale = lerpf(road_stopped_pitch, 1.0, moving)


func _tween_road_dream(target_db: float, seconds: float) -> void:
	if _road_dream_tween and _road_dream_tween.is_valid():
		_road_dream_tween.kill()
	_road_dream_tween = create_tween()
	_road_dream_tween.tween_property(self, "_road_dream_db", target_db, maxf(0.01, seconds)).set_trans(Tween.TRANS_SINE)

# step 2.299: the layered car art (car_rig.gd), or the old single image when the parts aren't there.
func _make_car() -> void:
	if FileAccess.file_exists(car_parts_path):
		_rig = CAR_RIG_SCRIPT.new()
		_rig.manifest_path = car_parts_path
		_rig.overscan = overscan
		_world.add_child(_rig)
		if _rig.loaded:
			_car = _rig
			return
		_rig.queue_free()
		_rig = null
	push_warning("car_ride_home: no layered car art at %s; using the single image." % car_parts_path)
	var image := TextureRect.new()
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(car_image_path):
		image.texture = load(car_image_path)
	else:
		push_warning("car_ride_test: no car image at %s (set car_image_path)." % car_image_path)
	_world.add_child(image)
	image.resized.connect(func(): image.pivot_offset = image.size * 0.5)
	image.pivot_offset = image.size * 0.5
	image.scale = Vector2(overscan, overscan)
	_car = image

# t = 0: normal framing. t = 1: zoomed in by think_zoom with Fiona's face moved to think_frame.
func _set_think(t: float) -> void:
	_think_t = t
	_frame_world(lerpf(1.0, think_zoom, t), think_frame, t)


# zoom the world by s, moving Fiona's face from where it sits toward frame (fractions of the screen) by t.
# used by the thinking push-in and by the close-up (step 2.305).
func _frame_world(s: float, frame: Vector2, t: float, anchor: Vector2 = Vector2(-1.0, -1.0)) -> void:
	# step 2.388: anchor = whose face to frame (fractions of the screen); Fiona's when not given
	var face: Vector2 = (fiona_face if anchor.x < 0.0 else anchor) * size
	var target: Vector2 = face.lerp(frame * size, t)
	var pos: Vector2 = target - face * s
	# never let the world's edges into view
	pos.x = clampf(pos.x, size.x - size.x * s, 0.0)
	pos.y = clampf(pos.y, size.y - size.y * s, 0.0)
	_world.scale = Vector2(s, s)
	_world.position = pos


func _apply_layers() -> void:
	_mat.set_shader_parameter("use_far", far_texture != null)
	_mat.set_shader_parameter("use_mid", mid_texture != null)
	_mat.set_shader_parameter("use_near", near_texture != null)
	if far_texture:
		_mat.set_shader_parameter("far_tex", far_texture)
	if mid_texture:
		_mat.set_shader_parameter("mid_tex", mid_texture)
	if near_texture:
		_mat.set_shader_parameter("near_tex", near_texture)


func _apply_look() -> void:
	var look: Dictionary = LOOKS.get(time_of_day, LOOKS["day"])
	_car.modulate = look["tint"]
	for key in look:
		if key != "tint":
			_mat.set_shader_parameter(key, look[key])


func _schedule_bump() -> void:
	if bump_every.y <= 0.0:
		_next_bump = INF
	else:
		_next_bump = randf_range(bump_every.x, bump_every.y)


func bump(strength: float = 1.0) -> void:
	_bump_v += 38.0 * bump_strength * strength


func _process(delta: float) -> void:
	_scroll += delta * _speed
	_update_road_sound()   # step 2.397
	_mat.set_shader_parameter("scroll_time", _scroll)
	_mat.set_shader_parameter("far_speed", far_speed)
	_mat.set_shader_parameter("mid_speed", mid_speed)
	_mat.set_shader_parameter("near_speed", near_speed)
	_mat.set_shader_parameter("split_x", split_x)
	_mat.set_shader_parameter("near_blur", near_blur * clampf(_speed, 0.0, 2.0))
	if size.y > 0.0:
		_mat.set_shader_parameter("screen_aspect", size.x / size.y)

	# random bumps while moving
	if _speed > 0.05:
		_next_bump -= delta
		if _next_bump <= 0.0:
			bump(randf_range(0.6, 1.2))
			_schedule_bump()

	# spring back from a bump
	_bump_v += (-_bump_y * 180.0 - _bump_v * 14.0) * delta
	_bump_y += _bump_v * delta

	# constant road/engine vibration, scaled by speed
	_vib_t += delta
	var amt: float = vibration_px * minf(1.0, _speed)
	var vib := Vector2(
		(sin(_vib_t * 37.0) + sin(_vib_t * 23.0)) * 0.5 * amt,
		(sin(_vib_t * 41.0) * 0.6 + sin(_vib_t * 17.0) * 0.4) * amt)
	if _rig:
		_rig.offset = vib + Vector2(0.0, _bump_y)
	else:
		_car.position = vib + Vector2(0.0, _bump_y)
	if size.y > 0.0:
		_mat.set_shader_parameter("bump_shift", -_bump_y * 0.35 / size.y)

	_split_line.visible = show_split
	if show_split:
		_split_line.position = Vector2(size.x * split_x - 2.0, 0.0)
		_split_line.size = Vector2(4.0, size.y)


func _unhandled_input(event: InputEvent) -> void:
	if not show_dev_keys: return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_B:
			bump(1.0)
		KEY_BRACKETLEFT:
			car_speed(_speed - 0.25, 0.3)
		KEY_BRACKETRIGHT:
			car_speed(minf(2.0, _speed + 0.25), 0.3)
		KEY_T:
			time_of_day = LOOK_ORDER[(LOOK_ORDER.find(time_of_day) + 1) % LOOK_ORDER.size()]
			_apply_look()
		KEY_V:
			show_split = not show_split
