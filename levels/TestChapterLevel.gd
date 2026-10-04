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
## julian: his intro CG doesn't play on first entry to the grad commons (marked as seen).
@export var test_run_skip_julian_intro: bool = true

func _ready():
	if GameManager:
		if is_instance_valid(level_state_manager):
			Flags.register_level_state_manager(level_state_manager)

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

func _on_interaction_state_changed(_new_state: int) -> void:
	_refresh_hud()

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
	_apply_hud_visibility(in_play and in_world and not _dialogue_active)

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


func _exit_tree():
	# give other scenes their full verb set back
	if Verbs and not disabled_verb_ids.is_empty():
		Verbs.set_active_scene_verbs(Verbs.unlocked_verb_ids)
	if GameManager and is_instance_valid(level_state_manager):
		if Flags.current_level_state_manager == level_state_manager:
			Flags.register_level_state_manager(null)
			print_rich("[color=yellow]%s: Unregistered its LevelStateManager.[/color]" % name)
