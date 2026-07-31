extends CanvasLayer

@onready var menu_panel = $MenuPanel
@onready var menu_button = $MenuPanel/MenuButton
@onready var hamburger_lines = [
	$MenuPanel/MarginContainer/VBoxContainer/Line1,
	$MenuPanel/MarginContainer/VBoxContainer/Line2,
	$MenuPanel/MarginContainer/VBoxContainer/Line3
]

@onready var overlay = $Overlay
@onready var bg_button = $Overlay/BackgroundButton
@onready var resume_btn = $Overlay/CenterContainer/VBoxContainer/ResumeButton
@onready var save_load_btn = $Overlay/CenterContainer/VBoxContainer/SaveLoadButton
@onready var history_btn = $Overlay/CenterContainer/VBoxContainer/HistoryButton
@onready var settings_btn = $Overlay/CenterContainer/VBoxContainer/SettingsButton
@onready var controls_btn = $Overlay/CenterContainer/VBoxContainer/ControlsButton
@onready var credits_btn = $Overlay/CenterContainer/VBoxContainer/CreditsButton
@onready var quit_btn = $Overlay/CenterContainer/VBoxContainer/QuitButton

signal scan_cancel_requested

@onready var scan_cancel_panel = $ScanCancelPanel
@onready var scan_cancel_btn = $ScanCancelPanel/MarginContainer/ScanCancelButton

@onready var confirm_overlay = $ConfirmOverlay
@onready var confirm_panel = $ConfirmOverlay/CenterContainer/ConfirmPanel
@onready var confirm_label = $ConfirmOverlay/CenterContainer/ConfirmPanel/MarginContainer/VBoxContainer/Label
@onready var yes_btn = $ConfirmOverlay/CenterContainer/ConfirmPanel/MarginContainer/VBoxContainer/HBoxContainer/YesButton
@onready var no_btn = $ConfirmOverlay/CenterContainer/ConfirmPanel/MarginContainer/VBoxContainer/HBoxContainer/NoButton

var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")
var _was_paused_before_menu: bool = false
var _pre_pause_game_state = null
var _was_menu_visible: bool = false
var _overlay_open_time_ms: int = 0
var _scan_style: StyleBoxFlat = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	menu_panel.hide()
	scan_cancel_panel.hide()
	scan_cancel_btn.texture_normal = preload("res://Icons/magnifying-glass.png")
	overlay.hide()
	confirm_overlay.hide()

	_apply_style()

	menu_button.pressed.connect(toggle_pause)
	if OS.has_feature("mobile"):
		bg_button.pressed.connect(_on_bg_button_pressed)
	else:
		bg_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	$Overlay/CenterContainer/VBoxContainer.mouse_filter = Control.MOUSE_FILTER_STOP
	resume_btn.pressed.connect(toggle_pause)
	save_load_btn.pressed.connect(_on_save_load_pressed)
	history_btn.pressed.connect(_on_history_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	controls_btn.pressed.connect(_on_controls_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)

	quit_btn.pressed.connect(_on_quit_pressed)
	yes_btn.pressed.connect(_on_confirm_yes)
	no_btn.pressed.connect(_on_confirm_no)

# returns the game state the world was in before the pause menu opened,
# or the live state when the menu is closed. the save gate needs this
# because the pause menu itself sets PAUSED + get_tree().paused.
func get_effective_game_state() -> int:
	if _pre_pause_game_state != null:
		return _pre_pause_game_state
	return GameManager.current_game_state

func _process(_delta):
	if is_instance_valid(menu_panel) and is_instance_valid(scan_cancel_panel):
		scan_cancel_panel.visible = menu_panel.visible

func _input(event):
	# handle escape key (toggles pause on and off)
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.is_pressed() and not event.is_echo()):
		if confirm_overlay.visible:
			get_viewport().set_input_as_handled()
			_on_confirm_no()
			return

		if GameManager and (GameManager.current_game_state == GameManager.GameState.IN_GAME_PLAY or GameManager.current_game_state == GameManager.GameState.PAUSED or GameManager.current_game_state == GameManager.GameState.INTRO_CONVERSATION):
			if get_tree().root.has_node("SettingsMenu") or get_tree().root.has_node("DialogueHistoryUI") or get_tree().root.has_node("CreditsMenu") or get_tree().root.has_node("ControlsMenu") or get_tree().root.has_node("SaveSlotScreen"):
				return

			get_viewport().set_input_as_handled()
			toggle_pause()

	# handle right-click (acts as "back"
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		if confirm_overlay.visible:
			get_viewport().set_input_as_handled()
			_on_confirm_no()
			return

		if overlay.visible:
			if get_tree().root.has_node("SettingsMenu") or get_tree().root.has_node("DialogueHistoryUI") or get_tree().root.has_node("CreditsMenu") or get_tree().root.has_node("ControlsMenu") or get_tree().root.has_node("SaveSlotScreen"):
				return

			get_viewport().set_input_as_handled()
			toggle_pause()

func _on_bg_button_pressed():
	if Time.get_ticks_msec() - _overlay_open_time_ms < 300: return
	toggle_pause()

func _on_save_load_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	var slot_scene = load("res://ui/save_slot_screen.tscn")
	if slot_scene:
		var instance = slot_scene.instantiate()
		instance.current_mode = instance.Mode.SAVE
		get_tree().root.add_child(instance)

func toggle_pause():
	if SoundManager: SoundManager.play_sfx("ui_click")

	if overlay.visible:
		overlay.hide()
		if is_instance_valid(menu_panel):
			menu_panel.visible = _was_menu_visible
		get_tree().paused = _was_paused_before_menu
		if GameManager and _pre_pause_game_state != null:
			GameManager.change_game_state(_pre_pause_game_state)
			_pre_pause_game_state = null
	else:
		_was_paused_before_menu = get_tree().paused
		if GameManager:
			_pre_pause_game_state = GameManager.current_game_state
		_was_menu_visible = menu_panel.visible if is_instance_valid(menu_panel) else false
		if is_instance_valid(menu_panel):
			menu_panel.hide()
		overlay.show()
		_overlay_open_time_ms = Time.get_ticks_msec()
		get_tree().paused = true
		if GameManager: GameManager.change_game_state(GameManager.GameState.PAUSED)
		
		# releasing the damn keyboard focus
		var current_focus = get_viewport().gui_get_focus_owner()
		if is_instance_valid(current_focus):
			current_focus.release_focus()
			

func _on_history_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	var log_scene = load("res://ui/dialogue_history_ui.tscn")
	if log_scene: get_tree().root.add_child(log_scene.instantiate())

func _on_settings_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	var settings_scene = load("res://ui/settings_menu.tscn")
	if settings_scene: get_tree().root.add_child(settings_scene.instantiate())

func _on_controls_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	var controls_scene = load("res://ui/controls_menu.tscn")
	if controls_scene: get_tree().root.add_child(controls_scene.instantiate())

func _on_credits_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	var credits_scene = load("res://ui/credits_menu.tscn")
	if credits_scene: get_tree().root.add_child(credits_scene.instantiate())

func _on_quit_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	confirm_overlay.show()

func _on_confirm_yes():
	if SoundManager: SoundManager.play_sfx("ui_click")
	confirm_overlay.hide()
	overlay.hide()
	if GameManager:
		if GameManager.has_method("quit_to_main_menu_smooth"):
			GameManager.quit_to_main_menu_smooth()
		else:
			GameManager.change_game_state(GameManager.GameState.MAIN_MENU)

func _on_confirm_no():
	if SoundManager: SoundManager.play_sfx("ui_click")
	confirm_overlay.hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_system_back_requested()


# android back button / back
# project.godot, so the app no
# mirrors the escape-key behavior in
func _on_system_back_requested() -> void:
	# a confirm dialog is open -> back means "no".
	if is_instance_valid(confirm_overlay) and confirm_overlay.visible:
		_on_confirm_no()
		return

	# a sub-menu is open -> ignore, same as the escape key does.
	if get_tree().root.has_node("SettingsMenu") \
			or get_tree().root.has_node("DialogueHistoryUI") \
			or get_tree().root.has_node("CreditsMenu") \
			or get_tree().root.has_node("ControlsMenu"):
		return

	if not GameManager:
		return

	# on the main menu there
	if GameManager.current_game_state == GameManager.GameState.MAIN_MENU:
		get_tree().quit()
		return

	# in-game states -> toggle the
	if GameManager.current_game_state == GameManager.GameState.IN_GAME_PLAY \
			or GameManager.current_game_state == GameManager.GameState.PAUSED \
			or GameManager.current_game_state == GameManager.GameState.INTRO_CONVERSATION:
		toggle_pause()

func _apply_style():
	# ----------[mobile: scale up the hamburger menu icon]
	if OS.has_feature("mobile"):
		menu_panel.offset_left = -160
		menu_panel.offset_bottom = 130
		var margin = $MenuPanel/MarginContainer
		margin.add_theme_constant_override("margin_top", 25)
		margin.add_theme_constant_override("margin_bottom", 25)
		margin.add_theme_constant_override("margin_left", 25)
		margin.add_theme_constant_override("margin_right", 25)
		for line in hamburger_lines:
			line.custom_minimum_size.y = 8

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_top = 15
	btn_normal.content_margin_bottom = 15
	btn_normal.content_margin_left = 40
	btn_normal.content_margin_right = 40
	btn_normal.border_width_left = 3
	btn_normal.border_width_top = 3
	btn_normal.border_width_right = 3
	btn_normal.border_width_bottom = 3
	btn_normal.border_color = Color.WHITE

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.9)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 1.0)

	var mobile_font_size = 28
	if OS.has_feature("mobile"):
		mobile_font_size = 44
		btn_normal.content_margin_top = 25
		btn_normal.content_margin_bottom = 25
		btn_hover.content_margin_top = 25
		btn_hover.content_margin_bottom = 25

	var buttons = [resume_btn, history_btn, settings_btn, controls_btn, credits_btn, quit_btn, yes_btn, no_btn]
	for btn in buttons:
		btn.add_theme_font_override("font", custom_font)
		btn.add_theme_font_size_override("font_size", mobile_font_size)
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("focus", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_hover)
		btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.5)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color.WHITE
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10

	_scan_style = panel_style.duplicate()
	scan_cancel_panel.add_theme_stylebox_override("panel", _scan_style)

	# desktop defaults
	scan_cancel_panel.offset_left = -190
	scan_cancel_panel.offset_top = 20
	scan_cancel_panel.offset_right = -110
	scan_cancel_panel.offset_bottom = 100

	if OS.has_feature("mobile"):
		scan_cancel_panel.offset_left = -320
		scan_cancel_panel.offset_top = 20
		scan_cancel_panel.offset_right = -180
		scan_cancel_panel.offset_bottom = 130
		var sc_margin = $ScanCancelPanel/MarginContainer
		sc_margin.add_theme_constant_override("margin_top", 25)
		sc_margin.add_theme_constant_override("margin_bottom", 25)
		sc_margin.add_theme_constant_override("margin_left", 25)
		sc_margin.add_theme_constant_override("margin_right", 25)

	var menu_style = panel_style.duplicate()
	menu_panel.add_theme_stylebox_override("panel", menu_style)

	menu_button.mouse_entered.connect(func():
		menu_style.border_color = Color(0.2, 0.85, 1.0, 1.0)
		for line in hamburger_lines: line.color = Color(0.2, 0.85, 1.0, 1.0)
	)
	menu_button.mouse_exited.connect(func():
		menu_style.border_color = Color.WHITE
		for line in hamburger_lines: line.color = Color.WHITE
	)

	scan_cancel_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	scan_cancel_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	scan_cancel_panel.mouse_entered.connect(func():
		if _scan_style.border_color != Color(1.0, 0.3, 0.3, 1.0):
			_set_scan_visuals(Color(0.2, 0.85, 1.0, 1.0), Color(0.2, 0.85, 1.0, 1.0))
	)
	scan_cancel_panel.mouse_exited.connect(func():
		if _scan_style.border_color != Color(1.0, 0.3, 0.3, 1.0):
			if GameManager and GameManager.is_scan_active():
				_set_scan_visuals(Color(0.2, 0.85, 1.0, 1.0), Color(0.2, 0.85, 1.0, 1.0))
			else:
				_set_scan_visuals(Color.WHITE, Color.WHITE)
	)
	scan_cancel_panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			scan_cancel_requested.emit()
	)

	var confirm_bg = StyleBoxFlat.new()
	confirm_bg.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	confirm_bg.border_width_left = 3
	confirm_bg.border_width_top = 3
	confirm_bg.border_width_right = 3
	confirm_bg.border_width_bottom = 3
	confirm_bg.border_color = Color(0.2, 0.85, 1.0, 1.0)
	confirm_bg.corner_radius_top_left = 10
	confirm_bg.corner_radius_top_right = 10
	confirm_bg.corner_radius_bottom_left = 10
	confirm_bg.corner_radius_bottom_right = 10
	confirm_panel.add_theme_stylebox_override("panel", confirm_bg)

	confirm_label.add_theme_font_override("font", custom_font)
	confirm_label.add_theme_font_size_override("font_size", 44 if OS.has_feature("mobile") else 28)
	confirm_label.add_theme_color_override("font_color", Color.WHITE)
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD

	if OS.has_feature("mobile"):
		confirm_label.custom_minimum_size = Vector2(600, 0)

func set_scan_highlight(is_active: bool):
	if is_active:
		_set_scan_visuals(Color(0.2, 0.85, 1.0, 1.0), Color(0.2, 0.85, 1.0, 1.0))
	else:
		_set_scan_visuals(Color.WHITE, Color.WHITE)

func set_cancel_mode(is_cancel: bool):
	if is_cancel:
		scan_cancel_btn.texture_normal = preload("res://Icons/cancel.png")
		_set_scan_visuals(Color(1.0, 0.3, 0.3, 1.0), Color.WHITE)
	else:
		scan_cancel_btn.texture_normal = preload("res://Icons/magnifying-glass.png")
		_set_scan_visuals(Color.WHITE, Color.WHITE)

# single source of truth for
# every code path that changes
func _set_scan_visuals(border_color: Color, icon_color: Color):
	if _scan_style:
		_scan_style.border_color = border_color
	if is_instance_valid(scan_cancel_btn):
		scan_cancel_btn.modulate = icon_color
