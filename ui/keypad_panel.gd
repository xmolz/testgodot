extends CanvasLayer

## Template keypad popup (introduced with the lab corridor door/keypad
## templates). Deliberate differences from elevator_panel.gd:
## - The tree is NEVER paused while this is open (see
##   OpenKeypadPanelAction.gd) so dialogue balloons on CanvasLayer 100 can
##   play over the open keypad (this panel sits on CanvasLayer 50).
##   Player movement is locked instead: the action calls
##   set_can_move(false) on open (movement is POLLED, so the Dim cannot
##   swallow it) and exit_to_world_state() in _close() re-enables it.
## - Styled as a PHYSICAL DEVICE (steel bezel, charcoal body, green LCD),
##   not in the cyan conversation-UI language - it reads as a world object
##   the player leans in on, not an interface.
## The LCD shows MAX_DIGITS fixed slots so the player knows the code
## length up front; the next empty slot doubles as the blinking cursor.
## OK validates against `correct_code`: match → lab_door_unlocked flag, green
## screen, close; mismatch → red flashes and the slots clear. Empty code = locked.

signal panel_closed

const MAX_DIGITS := 8
const SLOT_EMPTY_ALPHA := 0.4
var _slot_box := Vector2(44, 64)   # step 2.431: set in _ready (bigger on mobile)

const COLOR_BEZEL := Color(0.32, 0.33, 0.36, 1.0)
const COLOR_BEZEL_EDGE := Color(0.18, 0.19, 0.21, 1.0)
const COLOR_BODY := Color(0.13, 0.14, 0.16, 1.0)
const COLOR_BODY_EDGE := Color(0.05, 0.05, 0.06, 1.0)
const COLOR_SCREEN_BG := Color(0.04, 0.09, 0.05, 1.0)
const COLOR_SCREEN_EDGE := Color(0.02, 0.04, 0.02, 1.0)
const COLOR_SCREEN_TEXT := Color(0.45, 1.0, 0.6, 1.0)
const COLOR_KEY_BG := Color(0.22, 0.23, 0.26, 1.0)
const COLOR_KEY_BG_HOVER := Color(0.27, 0.28, 0.31, 1.0)
const COLOR_KEY_BG_PRESSED := Color(0.16, 0.17, 0.19, 1.0)
const COLOR_KEY_EDGE := Color(0.09, 0.1, 0.11, 1.0)
const COLOR_KEY_TEXT := Color(0.9, 0.9, 0.9, 1.0)
const COLOR_KEY_CLEAR_TEXT := Color(0.9, 0.55, 0.5, 1.0)
const COLOR_KEY_OK_TEXT := Color(0.55, 0.9, 0.6, 1.0)
const COLOR_ENGRAVED := Color(0.55, 0.57, 0.6, 1.0)
const COLOR_BACK_BG := Color(0.16, 0.17, 0.19, 0.92)
const COLOR_BACK_BG_HOVER := Color(0.22, 0.23, 0.26, 0.95)

const KEY_LAYOUT: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]

var _entered := ""
var _is_resolving := false
var _slots: Array[Label] = []
var _cursor_tween: Tween
var _screen_style: StyleBoxFlat

## The code that opens the lab. Empty = nothing is accepted (every attempt is
## denied). Set it on the KeypadPanel root in the Inspector once the clue
## chain's date is final. Eight digits, MMDDYYYY, like the old 07041776.
@export var correct_code: String = ""
const UNLOCK_FLAG := "lab_door_unlocked"
const DENY_FLASHES := 4

## wrong codes that mean something: the birthdates on the Greene, Ember and Voss portraits.
## the first time one is entered, Fiona (and Layla, if she's following) react over the
## open keypad (dialogue/keypad_attempts.dialogue). MMDDYYYY and DDMMYYYY both count,
## since players read dates both ways. repeats of the same date just get the red flash.
const REACTION_DIALOGUE_PATH := "res://dialogue/keypad_attempts.dialogue"
const REACTION_BALLOON_PATH := "res://conversation/conversationballoon.tscn"
const KNOWN_CODES := {
	"09031962": "greene_birthday", "03091962": "greene_birthday",
	"03141968": "ember_birthday", "14031968": "ember_birthday",
	# voss: his date is painted into voss_portrait.png ("b. 06/28/1971") — update here if the art changes
	"06281971": "voss_birthday", "28061971": "voss_birthday",
	# step 2.264: miescher's nuclein letter, february 26, 1869 (threads of inheritance). its reaction unlocks 4F.
	"02261869": "miescher_discovery", "26021869": "miescher_discovery",
	# step 2.286: more dates from threads of inheritance, the near miss, and the old code (each reacts once).
	"08131844": "miescher_birth", "13081844": "miescher_birth_dm",
	"08261895": "miescher_death", "26081895": "miescher_death_dm",
	"02281953": "double_helix", "28021953": "double_helix_dm",
	"28071896": "la_marr_day_first",
	"07041776": "old_code",
}
const REACTION_FLAGS := {
	"greene_birthday": "keypad_tried_greene_birthday",
	"ember_birthday": "keypad_tried_ember_birthday",
	"voss_birthday": "keypad_tried_voss_birthday",
	"miescher_discovery": "keypad_tried_miescher_discovery",
	"miescher_birth": "keypad_tried_miescher_birth", "miescher_birth_dm": "keypad_tried_miescher_birth",
	"miescher_death": "keypad_tried_miescher_death", "miescher_death_dm": "keypad_tried_miescher_death",
	"double_helix": "keypad_tried_double_helix", "double_helix_dm": "keypad_tried_double_helix",
	"la_marr_day_first": "keypad_tried_la_marr_day_first",
	"old_code": "keypad_tried_old_code",
}
## step 2.280: the right code: after the green flash the keypad closes and this overlay plays
## keypad_lab.dialogue ~ code_correct (celebration, the professor's call).
const CODE_CORRECT_SCENE := "res://conversation/lab_code_correct_advanced_overlay.tscn"
## step 2.269: reactions too long for the open keypad. the keypad closes and this overlay plays the
## title instead (staged, Fiona and Layla facing each other).
const STAGED_REACTIONS := {
	"miescher_discovery": "res://conversation/miescher_keypad_advanced_overlay.tscn",
}
const COMPANION_PRESENT_FLAG := "keypad_companion_present"

@onready var _dim: ColorRect = $Dim
@onready var _center: CenterContainer = $Center
@onready var _bezel: PanelContainer = $Center/DeviceStack/Bezel
@onready var _body: PanelContainer = $Center/DeviceStack/Bezel/Body
@onready var _engraved: Label = $Center/DeviceStack/Bezel/Body/Margin/VBox/EngravedLabel
@onready var _screen: PanelContainer = $Center/DeviceStack/Bezel/Body/Margin/VBox/Screen
@onready var _screen_row: HBoxContainer = $Center/DeviceStack/Bezel/Body/Margin/VBox/Screen/ScreenRow
@onready var _button_grid: GridContainer = $Center/DeviceStack/Bezel/Body/Margin/VBox/ButtonGrid
@onready var _back_button: Button = $Center/DeviceStack/BackButton

func _ready() -> void:
	var key_size := 40
	var slot_size := 52
	var engraved_size := 26
	var back_size := 30
	# step 2.431: a thumb-sized keypad on mobile
	var key_box := Vector2(120, 92)
	var slot_box := Vector2(44, 64)
	if OS.has_feature("mobile"):
		key_size = 64
		slot_size = 76
		engraved_size = 36
		back_size = 44
		key_box = Vector2(176, 136)
		slot_box = Vector2(60, 86)
	_slot_box = slot_box

	_style_device()

	_engraved.add_theme_font_size_override("font_size", engraved_size)
	_engraved.add_theme_color_override("font_color", COLOR_ENGRAVED)

	_build_slots(slot_size)

	# The 3-column key grid is narrower than the LCD; GridContainer
	# left-aligns inside the stretched VBox, so without an explicit
	# shrink-center it reads as off-center under the screen.
	_button_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	for key_label in KEY_LAYOUT:
		var button := Button.new()
		button.text = key_label
		button.custom_minimum_size = key_box
		_style_key(button, key_size, key_label)
		button.pressed.connect(_on_key_pressed.bind(key_label))
		_button_grid.add_child(button)

	_style_back_button(back_size)
	_back_button.pressed.connect(_close)

	_dim.gui_input.connect(_on_dim_gui_input)

	_refresh_screen()
	_play_open_animation()

func _style_device() -> void:
	var bezel_style := StyleBoxFlat.new()
	bezel_style.bg_color = COLOR_BEZEL
	bezel_style.border_color = COLOR_BEZEL_EDGE
	bezel_style.set_border_width_all(2)
	bezel_style.set_corner_radius_all(22)
	bezel_style.set_content_margin_all(8.0)
	bezel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	bezel_style.shadow_size = 16
	bezel_style.shadow_offset = Vector2(0.0, 6.0)
	_bezel.add_theme_stylebox_override("panel", bezel_style)

	var body_style := StyleBoxFlat.new()
	body_style.bg_color = COLOR_BODY
	body_style.border_color = COLOR_BODY_EDGE
	body_style.set_border_width_all(3)
	body_style.set_corner_radius_all(16)
	_body.add_theme_stylebox_override("panel", body_style)

	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = COLOR_SCREEN_BG
	screen_style.border_color = COLOR_SCREEN_EDGE
	screen_style.set_border_width_all(4)
	screen_style.set_corner_radius_all(8)
	screen_style.content_margin_left = 18.0
	screen_style.content_margin_right = 18.0
	screen_style.content_margin_top = 10.0
	screen_style.content_margin_bottom = 10.0
	_screen_style = screen_style
	_screen.add_theme_stylebox_override("panel", screen_style)

func _build_slots(font_size: int) -> void:
	# One fixed-width Label per code digit so the player can see the code
	# length up front. Empty slots render a dim underscore; the next slot
	# to fill blinks at full brightness (the cursor).
	for i in MAX_DIGITS:
		var slot := Label.new()
		slot.text = "_"
		slot.custom_minimum_size = _slot_box
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", font_size)
		slot.add_theme_color_override("font_color", COLOR_SCREEN_TEXT)
		_screen_row.add_child(slot)
		_slots.append(slot)

func _make_key_style(bg: Color, bottom_width: int, top_margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = COLOR_KEY_EDGE
	style.border_width_bottom = bottom_width
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = top_margin
	style.content_margin_bottom = 10.0
	return style

func _style_key(button: Button, font_size: int, key_label: String) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)

	# Thick bottom border fakes key depth; pressing thins it and pushes the
	# label down so the key visually sinks into the body.
	button.add_theme_stylebox_override("normal", _make_key_style(COLOR_KEY_BG, 6, 10.0))
	button.add_theme_stylebox_override("hover", _make_key_style(COLOR_KEY_BG_HOVER, 6, 10.0))
	button.add_theme_stylebox_override("pressed", _make_key_style(COLOR_KEY_BG_PRESSED, 2, 14.0))

	var text_color := COLOR_KEY_TEXT
	if key_label == "C":
		text_color = COLOR_KEY_CLEAR_TEXT
	elif key_label == "OK":
		text_color = COLOR_KEY_OK_TEXT
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color.lightened(0.15))
	button.add_theme_color_override("font_pressed_color", text_color.lightened(0.25))

func _make_back_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = COLOR_BEZEL_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10.0)
	return style

func _style_back_button(font_size: int) -> void:
	# A UI affordance, not a device key: it floats under the bezel so the
	# keypad itself stays a believable physical object.
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.add_theme_font_size_override("font_size", font_size)
	_back_button.add_theme_stylebox_override("normal", _make_back_style(COLOR_BACK_BG))
	_back_button.add_theme_stylebox_override("hover", _make_back_style(COLOR_BACK_BG_HOVER))
	_back_button.add_theme_stylebox_override("pressed", _make_back_style(COLOR_KEY_BG_PRESSED))
	_back_button.add_theme_color_override("font_color", COLOR_KEY_TEXT)
	_back_button.add_theme_color_override("font_hover_color", COLOR_KEY_TEXT.lightened(0.15))
	_back_button.add_theme_color_override("font_pressed_color", COLOR_KEY_TEXT.lightened(0.25))

func _refresh_screen() -> void:
	if _cursor_tween:
		_cursor_tween.kill()
	for i in MAX_DIGITS:
		var slot := _slots[i]
		if i < _entered.length():
			slot.text = _entered[i]
			slot.modulate.a = 1.0
		else:
			slot.text = "_"
			slot.modulate.a = SLOT_EMPTY_ALPHA
	if _entered.length() < MAX_DIGITS:
		var active := _slots[_entered.length()]
		active.modulate.a = 1.0
		_cursor_tween = create_tween()
		_cursor_tween.set_loops()
		_cursor_tween.tween_property(active, "modulate:a", 0.0, 0.05).set_delay(0.55)
		_cursor_tween.tween_property(active, "modulate:a", 1.0, 0.05).set_delay(0.4)

func _play_open_animation() -> void:
	_dim.modulate.a = 0.0
	_center.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.18)
	tween.tween_property(_center, "modulate:a", 1.0, 0.18)

func _on_key_pressed(key_label: String) -> void:
	if _is_resolving:
		return
	# step 2.393: every key clicks, like the conversation keypad (keypad_prop.gd press())
	if SoundManager:
		SoundManager.play_sfx("ui_click")
	match key_label:
		"C":
			_entered = ""
		"OK":
			_submit()
			return
		_:
			if _entered.length() < MAX_DIGITS:
				_entered += key_label
	_refresh_screen()

func _submit() -> void:
	if _entered.is_empty():
		_flash_screen()
		return
	if not correct_code.is_empty() and _entered == correct_code:
		await _flash_granted()
		Flags.set_level_flag(UNLOCK_FLAG, true)
		_is_resolving = false
		_close()
		_start_staged_reaction(CODE_CORRECT_SCENE)
		return
	await _flash_denied()
	var tried: String = _entered
	_entered = ""
	_refresh_screen()
	await _play_attempt_reaction(tried)


func _play_attempt_reaction(code: String) -> void:
	var title: String = KNOWN_CODES.get(code, "")
	if title.is_empty():
		return
	var flag: String = REACTION_FLAGS[title]
	if Flags.get_level_flag(flag):
		return   # already reacted to this date
	Flags.set_level_flag(flag, true)
	# step 2.358: any real date tried (not the old code) opens the elevators (elevator_panel.gd)
	if title != "old_code":
		Flags.set_level_flag("keypad_date_tried", true)
	Flags.set_level_flag(COMPANION_PRESENT_FLAG, _companion_following())
	if STAGED_REACTIONS.has(title):
		_close()
		_start_staged_reaction(STAGED_REACTIONS[title])
		return
	var resource = load(REACTION_DIALOGUE_PATH)
	if resource == null or not DialogueManager:
		return
	_is_resolving = true   # keys and Back stay inert while they talk
	DialogueManager.show_dialogue_balloon_scene(REACTION_BALLOON_PATH, resource, title)
	await DialogueManager.dialogue_ended
	_is_resolving = false


# step 2.269: launches a staged reaction overlay the same way StartConversationAction does.
func _start_staged_reaction(scene_path: String) -> void:
	var packed: PackedScene = load(scene_path)
	if packed == null or not GameManager:
		push_warning("KeypadPanel: staged reaction scene missing: %s" % scene_path)
		return
	GameManager.enter_conversation_state()
	var inst: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(inst)
	GameManager.register_character_conversation(inst)


# true when a companion (Layla) is following the player right now.
func _companion_following() -> bool:
	for follower in get_tree().get_nodes_in_group("companion_followers"):
		if follower.has_method("is_attached") and follower.is_attached():
			return true
	return false


func _flash_denied() -> void:
	# same language as the conversation prop's deny(): red LCD, four flashes, wipe
	_is_resolving = true
	# step 2.393: the wrong-code beep
	if SoundManager:
		SoundManager.play_sfx("incorrect_beep")
	if _cursor_tween:
		_cursor_tween.kill()
	var red := Color(1.0, 0.35, 0.3, 1.0)
	for slot in _slots:
		slot.modulate.a = 1.0
		slot.add_theme_color_override("font_color", red)
	_screen_style.bg_color = Color(0.25, 0.04, 0.04, 1.0)
	for i in DENY_FLASHES:
		_screen_row.modulate.a = 0.25
		await get_tree().create_timer(0.08).timeout
		_screen_row.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.3).timeout
	_screen_style.bg_color = COLOR_SCREEN_BG
	for slot in _slots:
		slot.add_theme_color_override("font_color", COLOR_SCREEN_TEXT)
	_is_resolving = false


func _flash_granted() -> void:
	_is_resolving = true
	if _cursor_tween:
		_cursor_tween.kill()
	for slot in _slots:
		slot.modulate.a = 1.0
	_screen_style.bg_color = Color(0.05, 0.24, 0.09, 1.0)
	if SoundManager:
		SoundManager.play_sfx("door_open_success")   # step 2.393: the lock giving way
	await get_tree().create_timer(0.65).timeout


func _flash_screen() -> void:
	var tween := create_tween()
	tween.tween_property(_screen_row, "modulate:a", 0.15, 0.07)
	tween.tween_property(_screen_row, "modulate:a", 1.0, 0.07)
	tween.tween_property(_screen_row, "modulate:a", 0.15, 0.07)
	tween.tween_property(_screen_row, "modulate:a", 1.0, 0.07)

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close()

func _close() -> void:
	if _is_resolving:
		return
	_is_resolving = true
	if GameManager:
		# Also restores player movement (set_can_move(true)) locked by
		# OpenKeypadPanelAction on the way in.
		GameManager.exit_to_world_state()
	panel_closed.emit()
	queue_free()
