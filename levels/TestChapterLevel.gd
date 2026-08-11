# testchapterlevel.gd — minimal generic level root for chapter launch test.
extends Control

@onready var level_state_manager: LevelStateManager = $LevelStateManager
@onready var verb_ui: CanvasLayer = $VerbUI
@onready var inventory_ui: CanvasLayer = $InventoryUI

var _return_layer: CanvasLayer = null
var _dialogue_active: bool = false

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
		add_child(zoom_ui_packed.instantiate())

	# ****************[hud gating]
	# no game_ui in chapters, so nothing hides the scene hud while the intro conversation
	# runs over the level after the wake CG fades. gate it on interaction state instead:
	# hidden through the launch (state stays CONVERSATION from the memory box), shown when
	# enter_chapter_state() emits WORLD. same pattern the zoom controls already use.
	Events.interaction_state_changed.connect(_on_interaction_state_changed)
	# chapters have no game_ui.gd. object-examine balloons never leave the WORLD
	# interaction state, so state gating alone leaves the hud visible under the balloon.
	# mirror game_ui.gd's pattern: any balloon hides the hud, dialogue_ended restores it.
	if DialogueManager:
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_refresh_hud()

	await get_tree().process_frame

func _on_interaction_state_changed(_new_state: int) -> void:
	_refresh_hud()

func _on_dialogue_started(_resource: Resource) -> void:
	_dialogue_active = true
	_refresh_hud()

func _on_dialogue_ended(_resource: Resource) -> void:
	_dialogue_active = false
	_refresh_hud()

func _refresh_hud() -> void:
	_apply_hud_visibility(GameManager.current_interaction_state == GameManager.InteractionState.WORLD and not _dialogue_active)

func _apply_hud_visibility(shown: bool) -> void:
	if is_instance_valid(verb_ui):
		verb_ui.visible = shown
	if is_instance_valid(inventory_ui):
		inventory_ui.visible = shown
	if is_instance_valid(_return_layer):
		_return_layer.visible = shown

func _exit_tree():
	if GameManager and is_instance_valid(level_state_manager):
		if Flags.current_level_state_manager == level_state_manager:
			Flags.register_level_state_manager(null)
			print_rich("[color=yellow]%s: Unregistered its LevelStateManager.[/color]" % name)
