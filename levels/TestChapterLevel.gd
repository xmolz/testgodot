# testchapterlevel.gd — minimal generic level root for chapter launch test.
extends Control

@onready var level_state_manager: LevelStateManager = $LevelStateManager
@onready var verb_ui: CanvasLayer = $VerbUI
@onready var inventory_ui: CanvasLayer = $InventoryUI

var _return_layer: CanvasLayer = null
var _dialogue_active: bool = false
var _zoom_controls_ui: Node = null
# zoom hud config, sent by ObjectZoomOverlay (see _apply_zoom_hud). reset outside zooms.
var _zoom_show_verb_panel: bool = false
var _zoom_show_inventory: bool = false
const HUD_LAYER := 2
const ZOOM_HUD_LAYER := 3

# dev: `think` is unlocked only by difficulty select (new game) or a save load, so a
# direct run of this scene (F6) never has it. mirror Main.gd's force_assisted_mode
# unlock so hints are testable without a full run. no effect on a real launch —
# the verb is already unlocked there and the guard skips the call.
@export var dev_unlock_think_on_direct_run: bool = true

# when true, dialogue response options in this level are a centred column (several actors
# on stage). the main scene has no such property, so its balloons keep the left column.
@export var center_dialogue_responses: bool = true
## verbs hidden from the action panel in this level (other scenes keep their full set).
@export var disabled_verb_ids: Array[String] = ["flash"]

@export_group("Test Run")
## master switch for dev testing. nothing in this group applies unless this is ticked.
## leave it off for real playthroughs; a red TEST RUN tag shows while it's on.
@export var test_run: bool = false
## elevator: 2F/3F/4F travel is free, ignoring the deadline lock (TRAVEL_UNLOCK_FLAG).
@export var test_run_free_elevator: bool = true
## elevator: 4F (faculty offices) is open before the nuclein date has been tried on the lab keypad (faculty_floor_unlocked).
@export var test_run_open_faculty_floor: bool = true
## julian: his intro CG doesn't play on first entry to the grad commons (marked as seen).
@export var test_run_skip_julian_intro: bool = true
## greene's office: its corridor door opens (sets the level flag greene_office_unlocked).
@export var test_run_open_greene_office: bool = true
## supply room: start with the Type-C charger and Layla's phone in the inventory.
@export var test_run_give_charger_and_phone: bool = false
## layla: the wake-up chat after the intro is skipped (marked as seen).
@export var test_run_skip_layla_wake_chat: bool = true
## julian: "Ask him about the keypad password" is offered without the keypad / Jayce prerequisites (sets dev_julian_all_topics).
@export var test_run_julian_all_topics: bool = true
## julian: once play starts, jump fiona and layla to the grad commons so his intro plays (overrides skip_julian_intro).
@export var test_run_play_julian_intro: bool = false
## janitor keycard test: start by Jayce (lab corridor) with everything up to "Ask him about his keycard."
## done (keypad, Jayce and Julian talks, the nuclein date, 4F open, the office-door talk). Greene's office
## stays locked (overrides Open Greene Office) and every janitor-route flag is cleared for a fresh run.
@export var test_run_jayce_keycard_ready: bool = false
## with the preset above: also start with Jayce's camera (locker opened, camera seen). untick to try
## the no-camera "Find another way." version.
@export var test_run_jayce_keycard_with_camera: bool = false
## step 2.399: julian talk test: start next to Julian in the grad commons, with his intro skipped, every
## topic open (the keypad-password one too) and his conversation fresh (his password lead and both
## endings cleared). wins over Play Julian Intro, Jayce Keycard Ready and Lab Code Ready.
@export var test_run_julian_talk_ready: bool = false
## lab code test: start by the lab keypad with everything before the right code done (a janitor route,
## the office unlocked, jayce gone), layla in the chosen mood and chapter memories to match. "off" = unused.
## don't combine with Jayce Keycard Ready.
@export_enum("off", "close", "neutral", "distant") var test_run_lab_code_ready: String = "off"
## with the preset above: which janitor route happened (the car ride reads it).
@export_enum("flashed", "camera", "both") var test_run_lab_code_janitor: String = "flashed"
## with the preset above: the right code before any la marr clue (book, photo, lock screen) was seen.
@export var test_run_lab_code_speedrun: bool = false

@export_group("Ambience")
## step 2.381: the empty-building room tone's volume in dB. 0 plays the file as recorded; positive
## values boost a quiet file (+10 sounds about twice as loud). changes apply live while the game runs.
@export_range(-40.0, 24.0, 0.5, "suffix:dB") var ambience_room_db: float = 0.0:
	set(value):
		ambience_room_db = value
		_update_ambience_live()
## step 2.381: the city-morning-outside layer's volume in dB, same scale as the room tone.
@export_range(-40.0, 24.0, 0.5, "suffix:dB") var ambience_outside_db: float = 0.0:
	set(value):
		ambience_outside_db = value
		_update_ambience_live()
## step 2.406: the skating rink next door, same scale. it plays through the same muffled bus as the city
## outside, so the cutoff below muffles both.
@export_range(-40.0, 24.0, 0.5, "suffix:dB") var ambience_rink_db: float = 0.0:
	set(value):
		ambience_rink_db = value
		_update_ambience_live()
## step 2.381: how muffled the outside layer is: a low-pass cutoff. lower is more muffled.
@export_range(200.0, 8000.0, 50.0, "suffix:Hz") var ambience_outside_cutoff_hz: float = 1500.0:
	set(value):
		ambience_outside_cutoff_hz = value
		_update_ambience_live()
## step 2.381: seconds for both layers to fade in as the level starts.
@export_range(0.0, 10.0, 0.1, "suffix:s") var ambience_fade_in: float = 2.0

func _ready():
	# step 2.380: the university's own ambience, first thing (before any await), so the hub's room tone
	# never starts over it
	_start_university_ambience()
	if GameManager:
		if is_instance_valid(level_state_manager):
			Flags.register_level_state_manager(level_state_manager)
			_setup_chapter_memories()

	# ****************[dev return button]
	# temporary way back to the hub until real chapter content exists. top-left, above the
	# scene hud (layer 2), below overlays.
	var return_layer := CanvasLayer.new()
	return_layer.name = "ReturnLayer"
	return_layer.layer = 5
	add_child(return_layer)
	_return_layer = return_layer

	if test_run:
		var test_tag := Label.new()
		test_tag.name = "TestRunTag"
		test_tag.text = "TEST RUN"
		test_tag.position = Vector2(380, 40)
		test_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		test_tag.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3, 1.0))
		test_tag.add_theme_font_size_override("font_size", 28)
		return_layer.add_child(test_tag)
		print_rich("[color=orange]TestChapterLevel: TEST RUN is on — test overrides active.[/color]")

	var return_btn := Button.new()
	return_btn.name = "ReturnButton"
	return_btn.text = "< Return"
	# zoom +/- panels occupy x 20..190, y 20..100 — sit to their right, same height, same look.
	return_btn.position = Vector2(210, 20)
	return_btn.custom_minimum_size = Vector2(150, 80)
	return_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return_btn.focus_mode = Control.FOCUS_NONE
	var btn_font = load("res://Fonts/VarelaRound-Regular.ttf")
	if btn_font:
		return_btn.add_theme_font_override("font", btn_font)
	return_btn.add_theme_font_size_override("font_size", 26)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0.5)
	btn_style.border_width_left = 3
	btn_style.border_width_top = 3
	btn_style.border_width_right = 3
	btn_style.border_width_bottom = 3
	btn_style.border_color = Color.WHITE
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	return_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 1.0)
	return_btn.add_theme_stylebox_override("hover", btn_hover)
	return_btn.add_theme_stylebox_override("pressed", btn_hover)
	return_btn.pressed.connect(func():
		if ChapterLaunchSequence.is_launching():
			return
		return_btn.disabled = true
		ChapterLaunchSequence.return_to_hub()
	)
	# step 2.404: a dev shortcut back to the hub; release exports (Export With Debug off) don't show it
	return_btn.visible = OS.is_debug_build()
	return_layer.add_child(return_btn)

	# the hub's GameUI node owns the shared zoom controls and dies with the hub, so this
	# level spawns its own set. they connect to the level camera themselves in _ready and
	# show once enter_chapter_state() emits the WORLD interaction state.
	var zoom_ui_packed = load("res://ui/zoom_controls_ui.tscn")
	if zoom_ui_packed:
		_zoom_controls_ui = zoom_ui_packed.instantiate()
		add_child(_zoom_controls_ui)

	# ****************[hud gating]
	# no game_ui in chapters, so nothing hides the scene hud while the intro conversation
	# runs over the level after the wake CG fades. gate it on interaction state instead:
	# hidden through the launch (state stays CONVERSATION from the memory box), shown when
	# enter_chapter_state() emits WORLD. same pattern the zoom controls already use.
	Events.interaction_state_changed.connect(_on_interaction_state_changed)
	Events.game_state_changed.connect(_on_game_state_changed)
	Events.zoom_hud_config_requested.connect(_on_zoom_hud_config_requested)
	# step 2.358: think hints (also re-taken whenever the interaction state changes)
	_ensure_hint_manager()
	# chapters have no game_ui.gd. object-examine balloons never leave the WORLD
	# interaction state, so state gating alone leaves the hud visible under the balloon.
	# mirror game_ui.gd's pattern: any balloon hides the hud, dialogue_ended restores it.
	if DialogueManager:
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_refresh_hud()

	await get_tree().process_frame

	if dev_unlock_think_on_direct_run and GameManager and Verbs:
		if not "think" in Verbs.unlocked_verb_ids:
			Verbs.unlock_verb("think")
			print_rich("[color=yellow]TestChapterLevel: dev unlock of 'think' (direct run).[/color]")
	_apply_disabled_verbs()

	# test run: open dr. greene's office (later the real unlock is the office keypad).
	if test_run_allows("open_greene_office"):
		Flags.set_level_flag("greene_office_unlocked", true)
		Flags.set_level_flag("greene_office_keycard_talk_seen", true)   # step 2.270: no "locked" talk on an open door
	# test run: start with the type-c charger and layla's phone (step 2.204).
	if test_run_allows("give_charger_and_phone"):
		if not Inventory.has_item("type_c_charger") and not Flags.get_level_flag("supply_charger_plugged"):
			Inventory.add_item("type_c_charger")
		if not Inventory.has_item("layla_phone") and not Flags.get_level_flag("supply_phone_charging"):
			Inventory.add_item("layla_phone")
	# test run: skip layla's wake-up chat (step 2.212).
	if test_run_allows("skip_layla_wake_chat"):
		Flags.set_level_flag("dev_skip_layla_wake_chat", true)
	# test run: julian's password topic without its prerequisites (step 2.227).
	if test_run_allows("julian_all_topics"):
		Flags.set_level_flag("dev_julian_all_topics", true)
	# step 2.278: test run, ready to ask jayce for his keycard (flags + a jump to the lab corridor).
	if test_run_allows("jayce_keycard_ready"):
		_dev_setup_jayce_keycard()
	# step 2.283: test run, ready to enter the lab code (per mood)
	if test_run and test_run_lab_code_ready != "off" and not test_run_julian_talk_ready:
		_dev_setup_lab_code_ready(test_run_lab_code_ready)
	# step 2.399: test run, ready to talk to Julian (flags + a jump to his side in the grad commons)
	if test_run_allows("julian_talk_ready"):
		_dev_setup_julian_talk()

	# step 2.227: first arrival in the 3F elevator hub shows a few seconds of "try Examine" tip
	_setup_examine_hint()
	# step 2.274: the janitor leaves his post for the day once he's been dealt with (jayce_gone)
	_setup_jayce_presence()
	# step 2.280: layla waits outside dr. greene's office while fiona goes in alone
	_setup_layla_waiting()
	# step 2.282: after the correct-code scene, the walk-in and the handover to the car ride
	_setup_lab_entry()

	# step 2.236: test run, jump to the grad commons so julian's intro plays
	if test_run_allows("play_julian_intro"):
		_dev_jump_to_grad_commons()

# ---------------------------------------------------------------------------
# step 2.282: once lab_entry_ready is set (end of keypad_lab.dialogue ~ code_correct), fiona and layla
# walk into the lab: fiona walks to the door, it swings open, she steps in, layla after her, it shuts.
# then black, and ChapterLaunchSequence hands over to the car ride (this level is freed first).
const LAB_ENTRY_FLAG := "lab_entry_ready"
const LAB_DOOR_NODE := "LabDoor"
const CAR_SCENE_PATH := "res://levels/car/car_ride_home.tscn"
const LAB_MONOLOGUE_PATH := "res://dialogue/keypad_lab.dialogue"
const LAB_MONOLOGUE_TITLE := "lab_twenty_minutes"
var _lab_walk_in_started: bool = false
# step 2.408: true from the start of the walk-in: the walk-in, the black and the car ride play as a cutscene,
# with no hud and no menu or scan buttons (the hub brings those back when the chapter returns)
var _lab_cutscene: bool = false


func _setup_lab_entry() -> void:
	var lsm = Flags.current_level_state_manager
	if lsm and not lsm.level_flag_changed.is_connected(_on_level_flag_changed_lab_entry):
		lsm.level_flag_changed.connect(_on_level_flag_changed_lab_entry)


func _on_level_flag_changed_lab_entry(changed_flag: String, value: bool) -> void:
	if changed_flag != LAB_ENTRY_FLAG or not value or _lab_walk_in_started:
		return
	if _dialogue_active and DialogueManager:
		if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended_lab_entry):
			DialogueManager.dialogue_ended.connect(_on_dialogue_ended_lab_entry, CONNECT_ONE_SHOT)
		return
	_play_lab_walk_in()


func _on_dialogue_ended_lab_entry(_resource) -> void:
	_play_lab_walk_in.call_deferred()


func _play_lab_walk_in() -> void:
	if _lab_walk_in_started:
		return
	_lab_walk_in_started = true
	_lab_cutscene = true
	_refresh_hud()
	# let the conversation overlay fade away and the world state return
	await get_tree().create_timer(0.7).timeout
	# step 2.408: the world state just brought the menu and scan buttons back; hide them for good
	_refresh_hud()
	if GameManager and is_instance_valid(GameManager.pause_menu_ui):
		GameManager.pause_menu_ui.menu_panel.hide()
	if GameManager and GameManager.has_method("_set_patreon_visible"):
		GameManager._set_patreon_visible(false)
	var player = GameManager.player_node if GameManager else null
	var door = find_child(LAB_DOOR_NODE, true, false)
	if not is_instance_valid(player) or not is_instance_valid(door):
		push_warning("TestChapterLevel: lab walk-in skipped (player or LabDoor missing).")
		return
	if GameManager:
		GameManager.is_transitioning = true   # no clicks or hovers during the walk-in

	# 1. fiona walks to the door (layla follows on her own)
	var walk_point = door.get_node_or_null("WalkToPoint")
	var target: Vector2 = walk_point.global_position if walk_point else door.global_position
	if player.has_method("set_can_move"):
		player.set_can_move(true)
	if player.has_method("walk_to_point"):
		player.walk_to_point(target)
	var waited := 0.0
	while waited < 5.0 and absf(player.global_position.x - target.x) > 24.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if player.has_method("stop_movement"):
		player.stop_movement()
	if player.has_method("set_can_move"):
		player.set_can_move(false)
	await get_tree().create_timer(0.5).timeout   # layla catches up
	if player.has_method("face_target"):
		player.face_target(door.global_position)

	# 2. the sliding double door opens onto darkness (step 2.285)
	var sliding: bool = _build_lab_door_slide(door)
	if SoundManager:
		SoundManager.play_sfx("door_open")
	if sliding:
		var slide_open := create_tween()
		slide_open.tween_method(_set_lab_door_open, 0.0, 1.0, LAB_DOOR_SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await slide_open.finished
	else:
		await get_tree().create_timer(0.3).timeout

	# 3. fiona steps in, then layla
	var step_in := create_tween().set_parallel(true)
	step_in.tween_property(player, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	step_in.tween_property(player, "scale", Vector2(0.94, 0.94), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await step_in.finished
	for follower in get_tree().get_nodes_in_group("companion_followers"):
		var body = follower.get_parent()
		if body is CanvasItem:
			var follow_in := create_tween().set_parallel(true)
			follow_in.tween_property(body, "modulate:a", 0.0, 0.35).set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.6).timeout

	# 4. the sliding door shuts
	if SoundManager:
		SoundManager.play_sfx("door_close")
	if sliding:
		var slide_shut := create_tween()
		slide_shut.tween_method(_set_lab_door_open, 1.0, 0.0, LAB_DOOR_SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await slide_shut.finished
		_clear_lab_door_slide()
	await get_tree().create_timer(0.4).timeout

	# 5. black, then the autoload hands over to the car ride (this level is freed there)
	var tl = GameManager.transition_layer if GameManager else null
	if is_instance_valid(tl):
		await tl.global_fade_to_black(0.8)
	var monologue: DialogueResource = load(LAB_MONOLOGUE_PATH)
	ChapterLaunchSequence.level_to_scene_under_black(CAR_SCENE_PATH, LAB_MONOLOGUE_TITLE, monologue)


# step 2.285: the lab door is a sliding double door, split down the middle. measured on lab_door.png
# (680x1240): the opening inside the frame is x 41..634, y 46..1226; the left panel runs to x 340 (its
# slit line included), the right panel starts at x 337. during the walk-in the art is cut into the two
# panels over a dark opening, and each panel slides into its side of the frame.
const LAB_DOOR_ART_SIZE := Vector2(680, 1240)
const LAB_DOOR_OPENING := Rect2(41, 46, 593, 1180)
const LAB_DOOR_LEFT_PANEL := Rect2(41, 46, 299, 1180)
const LAB_DOOR_RIGHT_PANEL := Rect2(337, 46, 297, 1180)
const LAB_DOOR_SLIDE_TIME := 0.7
var _lab_door_parts: Dictionary = {}


func _build_lab_door_slide(door: Node) -> bool:
	_clear_lab_door_slide()
	var leaf = door.get_node_or_null("ObjectSprite")
	if not (leaf is Sprite2D) or leaf.texture == null or leaf.texture.get_size() != LAB_DOOR_ART_SIZE:
		push_warning("TestChapterLevel: lab door art isn't the measured 680x1240; the door won't slide.")
		return false
	var s: Vector2 = leaf.scale
	var origin: Vector2 = leaf.position - LAB_DOOR_ART_SIZE * 0.5 * s
	var opening := ColorRect.new()
	opening.color = Color(0.03, 0.035, 0.05, 1.0)
	opening.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opening.position = origin + LAB_DOOR_OPENING.position * s
	opening.size = LAB_DOOR_OPENING.size * s
	door.add_child(opening)
	var left := Sprite2D.new()
	var right := Sprite2D.new()
	for panel in [left, right]:
		panel.texture = leaf.texture
		panel.centered = false
		panel.region_enabled = true
		panel.scale = s
		door.add_child(panel)
	_lab_door_parts = {"opening": opening, "left": left, "right": right, "origin": origin, "scale": s}
	_set_lab_door_open(0.0)
	return true


# t = 0 shut, 1 open. what stays visible of each panel is the part nearest the middle, so the slit line
# travels with it and the panel disappears into its side of the frame.
func _set_lab_door_open(t: float) -> void:
	if _lab_door_parts.is_empty():
		return
	var s: Vector2 = _lab_door_parts["scale"]
	var origin: Vector2 = _lab_door_parts["origin"]
	var left: Sprite2D = _lab_door_parts["left"]
	var right: Sprite2D = _lab_door_parts["right"]
	var lw: float = LAB_DOOR_LEFT_PANEL.size.x * (1.0 - t)
	var rw: float = LAB_DOOR_RIGHT_PANEL.size.x * (1.0 - t)
	left.visible = lw >= 1.0
	right.visible = rw >= 1.0
	left.region_rect = Rect2(LAB_DOOR_LEFT_PANEL.end.x - lw, LAB_DOOR_LEFT_PANEL.position.y, lw, LAB_DOOR_LEFT_PANEL.size.y)
	left.position = origin + LAB_DOOR_LEFT_PANEL.position * s
	right.region_rect = Rect2(LAB_DOOR_RIGHT_PANEL.position.x, LAB_DOOR_RIGHT_PANEL.position.y, rw, LAB_DOOR_RIGHT_PANEL.size.y)
	right.position = origin + Vector2(LAB_DOOR_RIGHT_PANEL.end.x - rw, LAB_DOOR_RIGHT_PANEL.position.y) * s


func _clear_lab_door_slide() -> void:
	for key in ["opening", "left", "right"]:
		var node = _lab_door_parts.get(key)
		if is_instance_valid(node):
			node.queue_free()
	_lab_door_parts = {}


# ---------------------------------------------------------------------------
# step 2.280: layla_waiting_outside_office detaches layla's follower so she stays in the corridor; the office
# exit door clears it and she follows fiona again. also on load. step 2.408: it's set as fiona goes through
# the office door (the door's use response), not by the entry talk, so layla follows until fiona goes in.
const LAYLA_WAITING_FLAG := "layla_waiting_outside_office"


func _setup_layla_waiting() -> void:
	var lsm = Flags.current_level_state_manager
	if lsm and not lsm.level_flag_changed.is_connected(_on_level_flag_changed_layla_waiting):
		lsm.level_flag_changed.connect(_on_level_flag_changed_layla_waiting)
	if Flags.get_level_flag(LAYLA_WAITING_FLAG):
		_apply_layla_waiting(true)


func _on_level_flag_changed_layla_waiting(changed_flag: String, value: bool) -> void:
	if changed_flag == LAYLA_WAITING_FLAG:
		_apply_layla_waiting(value)


func _apply_layla_waiting(waiting: bool) -> void:
	var player = GameManager.player_node if GameManager else null
	for follower in get_tree().get_nodes_in_group("companion_followers"):
		if waiting:
			if follower.has_method("detach"):
				follower.detach()
		elif follower.has_method("attach") and follower.has_method("is_attached") and not follower.is_attached() and is_instance_valid(player):
			follower.attach(player)


# ---------------------------------------------------------------------------
# step 2.274: once jayce_gone is set (the janitor routes), the LabGuard node (Jayce in the world)
# is removed. if the flag is set during a dialogue, removal waits until that dialogue ends, so the
# conversation never loses its npc mid-scene. also applied on load.
const JAYCE_NODE_NAME := "LabGuard"
const JAYCE_GONE_FLAG := "jayce_gone"


func _setup_jayce_presence() -> void:
	var lsm = Flags.current_level_state_manager
	if lsm and not lsm.level_flag_changed.is_connected(_on_level_flag_changed_jayce):
		lsm.level_flag_changed.connect(_on_level_flag_changed_jayce)
	_apply_jayce_presence()


func _on_level_flag_changed_jayce(changed_flag: String, _value: bool) -> void:
	if changed_flag == JAYCE_GONE_FLAG:
		_apply_jayce_presence()


func _apply_jayce_presence() -> void:
	if not Flags.get_level_flag(JAYCE_GONE_FLAG):
		return
	if _dialogue_active and DialogueManager:
		# step 2.279: fade him out in the world right away; free him once the dialogue ends.
		var fading = find_child(JAYCE_NODE_NAME, true, false)
		if fading is CanvasItem and not fading.has_meta("jayce_fading"):
			fading.set_meta("jayce_fading", true)
			var fade := create_tween()
			fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			fade.tween_property(fading, "modulate:a", 0.0, 0.6)
		if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended_jayce):
			DialogueManager.dialogue_ended.connect(_on_dialogue_ended_jayce, CONNECT_ONE_SHOT)
		return
	var jayce := find_child(JAYCE_NODE_NAME, true, false)
	if is_instance_valid(jayce):
		jayce.queue_free()


func _on_dialogue_ended_jayce(_resource) -> void:
	_apply_jayce_presence.call_deferred()


# ---------------------------------------------------------------------------
# step 2.227: first-visit Examine tip. the first time the player arrives in the 3F elevator hub
# (near the vending machine), the quiet hint banner shows for a few seconds, silently. once per playthrough.
# step 2.358: the think verb's hints for this level (levels/university_hint_manager.gd). adventure
# mode only for now; assisted mode uses the same file until its own lines are written.
const UniversityHintManagerScript = preload("res://levels/university_hint_manager.gd")
const HINTS_ADVENTURE_PATH := "res://dialogue/hints_university_adventure.dialogue"
var _hint_manager: LevelHintManager = null

func _ensure_hint_manager() -> void:
	if not GameManager:
		return
	if not is_instance_valid(_hint_manager):
		_hint_manager = UniversityHintManagerScript.new()
		_hint_manager.name = "UniversityHintManager"
		var hints = load(HINTS_ADVENTURE_PATH)
		_hint_manager.hints_adventure_dialogue = hints
		_hint_manager.hints_dialogue = hints
		add_child(_hint_manager)
	if GameManager.current_hint_manager != _hint_manager:
		GameManager.current_hint_manager = _hint_manager
		GameManager.refresh_hint_system()

const HintBannerScript = preload("res://conversation/hint_banner.gd")
const EXAMINE_HINT_FLAG := "examine_hint_seen"
const EXAMINE_HINT_TEXT := "Tip: using Examine on objects may reveal important information."
const EXAMINE_HINT_SECONDS := 4.5
const EXAMINE_HINT_ANCHOR := "Hub3FVendingMachine"
const EXAMINE_HINT_REACH := Vector2(900, 500)
var _examine_hint_layer: CanvasLayer = null


func _setup_examine_hint() -> void:
	if not Flags or Flags.get_game_flag(EXAMINE_HINT_FLAG):
		return
	if Events and Events.has_signal("room_changed") and not Events.room_changed.is_connected(_on_room_changed_examine_hint):
		Events.room_changed.connect(_on_room_changed_examine_hint)


func _on_room_changed_examine_hint() -> void:
	if Flags.get_game_flag(EXAMINE_HINT_FLAG):
		return
	var player = GameManager.player_node if GameManager else null
	var anchor = find_child(EXAMINE_HINT_ANCHOR, true, false)
	if not is_instance_valid(player) or not is_instance_valid(anchor):
		return
	var d: Vector2 = (player.global_position - anchor.global_position).abs()
	if d.x > EXAMINE_HINT_REACH.x or d.y > EXAMINE_HINT_REACH.y:
		return
	Flags.set_game_flag(EXAMINE_HINT_FLAG, true)
	_examine_hint_layer = CanvasLayer.new()
	_examine_hint_layer.layer = 95
	add_child(_examine_hint_layer)
	var banner = HintBannerScript.new()
	_examine_hint_layer.add_child(banner)
	banner.flash_hint(EXAMINE_HINT_TEXT, null, EXAMINE_HINT_SECONDS)


# step 2.236 (test run): wait for normal play, then move fiona (and layla) into the grad commons
# and announce the room change, so JulianIntroCutscene starts.
func _dev_jump_to_grad_commons() -> void:
	var waited := 0.0
	while waited < 60.0:
		if GameManager and GameManager.current_game_state == GameManager.GameState.IN_GAME_PLAY and not _dialogue_active:
			break
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(0.3).timeout
	var player = GameManager.player_node if GameManager else null
	var marker = find_child("Floor3CorridorSpawnPoint", true, false)
	if not is_instance_valid(player) or not is_instance_valid(marker):
		push_warning("TestChapterLevel: can't jump to the grad commons (player or Floor3CorridorSpawnPoint missing).")
		return
	if player.has_method("stop_movement"):
		player.stop_movement()
	player.global_position = marker.global_position
	get_tree().call_group("companion_followers", "place_for_teleport", marker)
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("snap_to_target"):
		camera.snap_to_target()
	if Events and Events.has_signal("room_changed"):
		Events.room_changed.emit()
	print_rich("[color=orange]TestChapterLevel: jumped to the grad commons for julian's intro (TEST RUN).[/color]")


# step 2.399 (test run): Julian's conversation from the top, every topic open, standing at his side.
const DEV_JULIAN_TALK_SET_FLAGS := ["julian_intro_seen", "dev_julian_all_topics"]
const DEV_JULIAN_TALK_CLEAR_FLAGS := [
	"julian_password_asked", "julian_refused_help", "julian_nearly_told_truth", "dna_dates_lookup_pending",
]
## how far left of Julian Fiona lands, in px
const DEV_JULIAN_TALK_GAP := 420.0


func _dev_setup_julian_talk() -> void:
	for flag_name in DEV_JULIAN_TALK_SET_FLAGS:
		Flags.set_level_flag(flag_name, true)
	for flag_name in DEV_JULIAN_TALK_CLEAR_FLAGS:
		Flags.set_level_flag(flag_name, false)
	print_rich("[color=orange]TestChapterLevel: ready to talk to Julian (TEST RUN).[/color]")
	_dev_jump_next_to_julian()


# once play starts (as _dev_jump_to_grad_commons), drop fiona a step left of Julian on the grad commons floor,
# with layla a step behind her. a stand-in spawn point is made for the jump and freed after it.
func _dev_jump_next_to_julian() -> void:
	var waited := 0.0
	while waited < 60.0:
		if GameManager and GameManager.current_game_state == GameManager.GameState.IN_GAME_PLAY and not _dialogue_active:
			break
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(0.3).timeout
	var player = GameManager.player_node if GameManager else null
	var entry = find_child("Floor3CorridorSpawnPoint", true, false)
	var julian = find_child("JulianCharacter", true, false)
	if not is_instance_valid(player) or not is_instance_valid(entry) or not is_instance_valid(julian):
		push_warning("TestChapterLevel: can't jump next to Julian (player, Floor3CorridorSpawnPoint or JulianCharacter missing).")
		return
	var spot := Marker2D.new()
	add_child(spot)
	spot.global_position = Vector2(julian.global_position.x - DEV_JULIAN_TALK_GAP, entry.global_position.y)
	var entry_companion = entry.get_node_or_null("CompanionSpawn") as Node2D
	if entry_companion:
		var companion_spot := Marker2D.new()
		companion_spot.name = "CompanionSpawn"
		spot.add_child(companion_spot)
		companion_spot.position = Vector2(-absf(entry_companion.position.x), entry_companion.position.y)
	if player.has_method("stop_movement"):
		player.stop_movement()
	player.global_position = spot.global_position
	get_tree().call_group("companion_followers", "place_for_teleport", spot)
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("snap_to_target"):
		camera.snap_to_target()
	if Events and Events.has_signal("room_changed"):
		Events.room_changed.emit()
	spot.queue_free()
	print_rich("[color=orange]TestChapterLevel: jumped next to Julian (TEST RUN).[/color]")


# step 2.278 (test run): the state just before "Ask him about his keycard.", then a jump to the lab corridor.
const DEV_JAYCE_KEYCARD_DONE_FLAGS := [
	"lab_keypad_interacted", "jayce_introduced", "jayce_date_hint_given",
	"julian_intro_seen", "julian_password_asked", "dna_dates_lookup_pending", "dna_dates_found",
	"miescher_book_date_seen", "keypad_tried_miescher_discovery", "faculty_floor_unlocked",
	"greene_office_keycard_talk_seen", "fiona_said_nine_half", "keypad_date_tried",
]
const DEV_JAYCE_KEYCARD_CLEAR_FLAGS := [
	"greene_office_unlocked", "jayce_keycard_refused", "jayce_gone", "jayce_flashed",
	"jayce_camera_seen", "supply_locker_opened", "greene_office_entry_pending", "layla_waiting_outside_office",
]


func _dev_setup_jayce_keycard() -> void:
	for flag_name in DEV_JAYCE_KEYCARD_DONE_FLAGS:
		Flags.set_level_flag(flag_name, true)
	for flag_name in DEV_JAYCE_KEYCARD_CLEAR_FLAGS:
		Flags.set_level_flag(flag_name, false)
	if Inventory.has_item("jayce_camera"):
		Inventory.remove_item("jayce_camera")
	if test_run_jayce_keycard_with_camera:
		Flags.set_level_flag("supply_locker_opened", true)
		Flags.set_level_flag("jayce_camera_seen", true)
		Inventory.add_item("jayce_camera")
	print_rich("[color=orange]TestChapterLevel: ready to ask Jayce for his keycard (TEST RUN%s).[/color]" % (", with camera" if test_run_jayce_keycard_with_camera else ""))
	_dev_jump_to_marker("LabCorridorSpawnPoint")


# step 2.283 (test run): the state just before the right lab code, for one layla mood.
const DEV_LAB_CODE_MOODS := {
	"close": {"closeness": 4.0, "flags": {
		"layla_asked_about_work": true, "layla_work_comforted": true, "layla_work_reprimanded": false,
		"julian_refused_help": true, "julian_nearly_told_truth": false,
		"layla_gift_given": true, "layla_gift_loved": true, "layla_said_fee": true, "fiona_said_nine_half": true}},
	"neutral": {"closeness": 1.0, "flags": {
		"layla_asked_about_work": true, "layla_work_comforted": true, "layla_work_reprimanded": false,
		"julian_refused_help": true, "julian_nearly_told_truth": false,
		"layla_gift_given": false, "layla_gift_loved": false, "layla_said_fee": false, "fiona_said_nine_half": true}},
	"distant": {"closeness": -2.0, "flags": {
		"layla_asked_about_work": true, "layla_work_comforted": false, "layla_work_reprimanded": true,
		"julian_refused_help": false, "julian_nearly_told_truth": true,
		"layla_gift_given": false, "layla_gift_loved": false, "layla_said_fee": false, "fiona_said_nine_half": false}},
}


func _dev_setup_lab_code_ready(mood: String) -> void:
	for flag_name in DEV_JAYCE_KEYCARD_DONE_FLAGS:
		Flags.set_level_flag(flag_name, true)
	for flag_name in ["greene_office_unlocked", "jayce_gone"]:
		Flags.set_level_flag(flag_name, true)
	for flag_name in ["greene_office_entry_pending", "layla_waiting_outside_office", "lab_entry_ready", "jayce_keycard_refused", "lab_door_unlocked"]:
		Flags.set_level_flag(flag_name, false)
	var flashed: bool = test_run_lab_code_janitor != "camera"
	var camera: bool = test_run_lab_code_janitor != "flashed"
	Flags.set_level_flag("jayce_flashed", flashed)
	Flags.set_level_flag("jayce_camera_seen", camera)
	Flags.set_level_flag("supply_locker_opened", camera)
	# step 2.288: the la marr clues count as seen, unless testing the speedrun version.
	for clue_flag in ["la_marr_book_read", "greene_la_marr_photo_seen", "greene_lockscreen_seen"]:
		Flags.set_level_flag(clue_flag, not test_run_lab_code_speedrun)
	if Inventory.has_item("jayce_camera"):
		Inventory.remove_item("jayce_camera")
	if camera:
		Inventory.add_item("jayce_camera")
	var preset: Dictionary = DEV_LAB_CODE_MOODS.get(mood, DEV_LAB_CODE_MOODS["neutral"])
	var memory: Dictionary = preset["flags"]
	for flag_name in memory:
		Flags.set_level_flag(flag_name, memory[flag_name])
	var target: float = float(preset["closeness"])
	Flags.add_game_counter("layla_closeness", target - Flags.get_game_counter("layla_closeness"))
	# step 2.296: the distant preset carries both hurts, so it's locked; the others aren't.
	Flags.set_game_flag("layla_locked_distant", false)
	if mood == "distant":
		Flags.lock_layla_distant()
	print_rich("[color=orange]TestChapterLevel: ready for the lab code (TEST RUN, %s, janitor: %s).[/color]" % [mood, test_run_lab_code_janitor])
	_dev_jump_to_marker("LabCorridorSpawnPoint")


# test run: wait for normal play, then move fiona (and layla) to a marker and announce the room change.
func _dev_jump_to_marker(marker_name: String) -> void:
	var waited := 0.0
	while waited < 60.0:
		if GameManager and GameManager.current_game_state == GameManager.GameState.IN_GAME_PLAY and not _dialogue_active:
			break
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(0.3).timeout
	var player = GameManager.player_node if GameManager else null
	var marker = find_child(marker_name, true, false)
	if not is_instance_valid(player) or not is_instance_valid(marker):
		push_warning("TestChapterLevel: can't jump to %s (player or marker missing)." % marker_name)
		return
	if player.has_method("stop_movement"):
		player.stop_movement()
	player.global_position = marker.global_position
	get_tree().call_group("companion_followers", "place_for_teleport", marker)
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("snap_to_target"):
		camera.snap_to_target()
	if Events and Events.has_signal("room_changed"):
		Events.room_changed.emit()


func _on_interaction_state_changed(_new_state: int) -> void:
	_refresh_hud()
	# step 2.358: enter_chapter_state() clears the hint manager before it emits WORLD; take it back
	_ensure_hint_manager()

func _on_game_state_changed(_new_state: int) -> void:
	_apply_disabled_verbs()
	_refresh_hud()

func _on_dialogue_started(_resource: Resource) -> void:
	_dialogue_active = true
	_refresh_hud()

func _on_dialogue_ended(_resource: Resource) -> void:
	_dialogue_active = false
	_refresh_hud()

func _refresh_hud() -> void:
	var in_play: bool = GameManager.current_game_state == GameManager.GameState.IN_GAME_PLAY
	var state = GameManager.current_interaction_state
	var in_world: bool = state == GameManager.InteractionState.WORLD
	var in_zoom: bool = state == GameManager.InteractionState.ZOOM_VIEW
	if in_play and in_zoom and not _dialogue_active:
		_apply_zoom_hud()
		return
	if not in_zoom:
		_zoom_show_verb_panel = false
		_zoom_show_inventory = false
	_apply_hud_visibility(in_play and in_world and not _dialogue_active and not _lab_cutscene)

func _apply_hud_visibility(shown: bool) -> void:
	if is_instance_valid(verb_ui):
		verb_ui.layer = HUD_LAYER
		if verb_ui.has_method("set_panel_visible"):
			verb_ui.set_panel_visible(true)
	if is_instance_valid(inventory_ui):
		inventory_ui.layer = HUD_LAYER
	if is_instance_valid(verb_ui):
		verb_ui.visible = shown
	if is_instance_valid(inventory_ui):
		inventory_ui.visible = shown
	if is_instance_valid(_zoom_controls_ui) and _zoom_controls_ui.has_method("set_gameplay_ui_visible"):
		_zoom_controls_ui.set_gameplay_ui_visible(shown)
	if is_instance_valid(_return_layer):
		_return_layer.visible = shown

# zooms (ObjectZoomOverlay, layer 2): keep the verb layer, and with it the action
# bubble, visible above the zoom, honouring the zoom's own panel/inventory config.
# mirrors game_ui.gd's zoom handling in the main scene.
func _apply_zoom_hud() -> void:
	if is_instance_valid(verb_ui):
		verb_ui.layer = ZOOM_HUD_LAYER
		verb_ui.visible = true
		if verb_ui.has_method("set_panel_visible"):
			verb_ui.set_panel_visible(_zoom_show_verb_panel)
	if is_instance_valid(inventory_ui):
		inventory_ui.layer = ZOOM_HUD_LAYER
		inventory_ui.visible = _zoom_show_inventory
	if is_instance_valid(_zoom_controls_ui) and _zoom_controls_ui.has_method("set_gameplay_ui_visible"):
		_zoom_controls_ui.set_gameplay_ui_visible(false)
	if is_instance_valid(_return_layer):
		_return_layer.visible = false

func _on_zoom_hud_config_requested(show_verb_panel: bool, show_inventory: bool) -> void:
	_zoom_show_verb_panel = show_verb_panel
	_zoom_show_inventory = show_inventory
	_refresh_hud()

# test run: true only when the master switch AND the named option (test_run_<option>)
# are both on. other scripts reach this through the current level root.
func test_run_allows(option: String) -> bool:
	if not test_run:
		return false
	# step 2.236: playing julian's intro wins over skipping it
	if option == "skip_julian_intro" and test_run_play_julian_intro:
		return false
	# step 2.399: the julian talk test wins over playing his intro and over the keycard jump
	if test_run_julian_talk_ready and (option == "play_julian_intro" or option == "jayce_keycard_ready"):
		return false
	return get("test_run_" + option) == true


# hides this level's disabled_verb_ids from the action panel. idempotent: it only
# calls into Verbs when a disabled verb is actually still active.
func _apply_disabled_verbs() -> void:
	if disabled_verb_ids.is_empty() or not Verbs:
		return
	var active: Array[String] = Verbs.active_scene_verb_ids.duplicate() if not Verbs.active_scene_verb_ids.is_empty() else Verbs.unlocked_verb_ids.duplicate()
	var changed: bool = Verbs.active_scene_verb_ids.is_empty()
	for verb_id in disabled_verb_ids:
		if verb_id in active:
			active.erase(verb_id)
			changed = true
	if changed:
		Verbs.set_active_scene_verbs(active)


# ****************[chapter memories] step 2.238
# the car ride (and later chapters) can't see this level's flags once it unloads, so the
# flags they react to are mirrored live into game flags as "kb_<flag>" (saved, cross-level).
# add a flag here when a later scene needs to react to it.
const CHAPTER_MEMORY_PREFIX := "kb_"
const CHAPTER_MEMORY_FLAGS: Array[String] = [
	"layla_work_comforted",
	"layla_work_reprimanded",
	"julian_refused_help",
	"julian_nearly_told_truth",
	"layla_gift_given",
	"layla_gift_loved",
	"layla_said_fee",
	"jayce_flashed",
	"jayce_camera_seen",
	"layla_julian_intro_encouraged",
]


func _setup_chapter_memories() -> void:
	if not is_instance_valid(level_state_manager):
		return
	if not level_state_manager.level_flag_changed.is_connected(_on_chapter_memory_flag_changed):
		level_state_manager.level_flag_changed.connect(_on_chapter_memory_flag_changed)
	if not level_state_manager.level_state_restored.is_connected(_sync_chapter_memories):
		level_state_manager.level_state_restored.connect(_sync_chapter_memories)
	_sync_chapter_memories()


# writes every tracked flag (true or false), so a replay of the chapter overwrites the last run's memories
func _sync_chapter_memories() -> void:
	if not is_instance_valid(level_state_manager):
		return
	for flag_name in CHAPTER_MEMORY_FLAGS:
		Flags.set_game_flag(CHAPTER_MEMORY_PREFIX + flag_name, level_state_manager.get_level_flag(flag_name))


func _on_chapter_memory_flag_changed(flag_name: String, new_value: bool) -> void:
	if flag_name in CHAPTER_MEMORY_FLAGS:
		Flags.set_game_flag(CHAPTER_MEMORY_PREFIX + flag_name, new_value)
		print_rich("[color=gray]Chapter memory: %s%s = %s[/color]" % [CHAPTER_MEMORY_PREFIX, flag_name, new_value])


# step 2.380 / 2.381: the university's ambience instead of the hospital hum. an empty-building room tone,
# with a city morning outside under it, muffled as if heard through the windows. the volumes, the muffle
# and the fade-in are the exports in the Inspector's "Ambience" group (top of this file).
const AMBIENCE_ROOM := "uni_empty_room"
const AMBIENCE_OUTSIDE := "uni_city_outside"
const AMBIENCE_RINK := "uni_skating_rink"   # step 2.406

func _start_university_ambience() -> void:
	if not SoundManager:
		return
	SoundManager.level_ambience_active = true
	SoundManager.stop_all_ambience()
	SoundManager.set_muffled_ambience_cutoff(ambience_outside_cutoff_hz)
	SoundManager.play_ambience(AMBIENCE_ROOM, ambience_room_db, "Ambience", ambience_fade_in)
	SoundManager.play_ambience(AMBIENCE_OUTSIDE, ambience_outside_db, SoundManager.MUFFLED_AMBIENCE_BUS_NAME, ambience_fade_in)
	SoundManager.play_ambience(AMBIENCE_RINK, ambience_rink_db, SoundManager.MUFFLED_AMBIENCE_BUS_NAME, ambience_fade_in)

# step 2.381: the export setters call this, so edits in the Remote inspector apply while the game runs.
# skipped while the scene is still loading (not in the tree yet) and once the level's ambience is off.
func _update_ambience_live() -> void:
	if not is_inside_tree() or not SoundManager or not SoundManager.level_ambience_active:
		return
	SoundManager.set_ambience_layer_volume(AMBIENCE_ROOM, ambience_room_db)
	SoundManager.set_ambience_layer_volume(AMBIENCE_OUTSIDE, ambience_outside_db)
	SoundManager.set_ambience_layer_volume(AMBIENCE_RINK, ambience_rink_db)
	SoundManager.set_muffled_ambience_cutoff(ambience_outside_cutoff_hz)

func _exit_tree():
	# step 2.380: the university's ambience ends with the level (back to the hub, or on to the car ride)
	if SoundManager:
		SoundManager.level_ambience_active = false
		SoundManager.stop_all_ambience()
	# step 2.358: let go of this level's hint manager
	if GameManager and is_instance_valid(_hint_manager) and GameManager.current_hint_manager == _hint_manager:
		GameManager.current_hint_manager = null
	# give other scenes their full verb set back
	if Verbs and not disabled_verb_ids.is_empty():
		Verbs.set_active_scene_verbs(Verbs.unlocked_verb_ids)
	if GameManager and is_instance_valid(level_state_manager):
		if Flags.current_level_state_manager == level_state_manager:
			Flags.register_level_state_manager(null)
			print_rich("[color=yellow]%s: Unregistered its LevelStateManager.[/color]" % name)
