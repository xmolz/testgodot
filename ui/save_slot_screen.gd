extends CanvasLayer

enum Mode { SAVE, LOAD }
var current_mode: Mode = Mode.SAVE
var allow_mode_switch: bool = true

@onready var background_rect = ColorRect.new()
@onready var margin_container = MarginContainer.new()
@onready var content_panel = PanelContainer.new()
@onready var main_container = VBoxContainer.new()

@onready var title_label = Label.new()
@onready var tab_buttons_container = HBoxContainer.new()
@onready var save_tab_btn = Button.new()
@onready var load_tab_btn = Button.new()

@onready var tab_scroll = ScrollContainer.new()
@onready var scroll_margin = MarginContainer.new()
@onready var slots_container = VBoxContainer.new()

@onready var close_button = Button.new()

var _confirm_canvas: CanvasLayer = null
var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120 # above pause menu (110)
	
	# dimmer backgroundColor matching settings exactly
	background_rect.color = Color(0, 0, 0, 0.9)
	background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background_rect)
	
	# mobile background click close
	if OS.has_feature("mobile"):
		background_rect.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				_on_close_pressed()
		)
		
	# setup margins matching settings exactly
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin_left_right = 120 if OS.has_feature("mobile") else 320
	var margin_top_bottom = 60 if OS.has_feature("mobile") else 80
	margin_container.add_theme_constant_override("margin_left", margin_left_right)
	margin_container.add_theme_constant_override("margin_right", margin_left_right)
	margin_container.add_theme_constant_override("margin_top", margin_top_bottom)
	margin_container.add_theme_constant_override("margin_bottom", margin_top_bottom)
	add_child(margin_container)
	
	# setup content panel stylebox matching settings ContentPanel exactly
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color(0.05, 0.05, 0.05, 0.6)
	content_style.border_width_left = 3
	content_style.border_width_top = 3
	content_style.border_width_right = 3
	content_style.border_width_bottom = 3
	content_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
	content_style.corner_radius_top_left = 10
	content_style.corner_radius_top_right = 10
	content_style.corner_radius_bottom_right = 10
	content_style.corner_radius_bottom_left = 10
	content_style.content_margin_left = 30
	content_style.content_margin_top = 30
	content_style.content_margin_right = 30
	content_style.content_margin_bottom = 30
	content_panel.add_theme_stylebox_override("panel", content_style)
	margin_container.add_child(content_panel)
	
	main_container.add_theme_constant_override("separation", 25)
	content_panel.add_child(main_container)
	
	# title label matching settings Title exactly
	title_label.text = "SAVE / LOAD"
	title_label.add_theme_font_override("font", custom_font)
	title_label.add_theme_font_size_override("font_size", 72 if OS.has_feature("mobile") else 48)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	# tab buttons setup
	tab_buttons_container.add_theme_constant_override("separation", 28)
	tab_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_child(tab_buttons_container)
	
	save_tab_btn.text = "SAVE"
	save_tab_btn.pressed.connect(func(): _switch_mode(Mode.SAVE))
	tab_buttons_container.add_child(save_tab_btn)
	
	load_tab_btn.text = "LOAD"
	load_tab_btn.pressed.connect(func(): _switch_mode(Mode.LOAD))
	tab_buttons_container.add_child(load_tab_btn)
	
	if not allow_mode_switch:
		save_tab_btn.visible = false
	
	var sep = HSeparator.new()
	main_container.add_child(sep)
	
	# Scroll area matching settings ScrollContainer
	tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(tab_scroll)
	
	# scrollbar styling matching settings VScrollBar exactly
	var vbar = tab_scroll.get_v_scroll_bar()
	vbar.custom_minimum_size.x = 24 if OS.has_feature("mobile") else 12

	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color(0.1, 0.12, 0.15, 1.0)
	track_style.corner_radius_top_left = 4
	track_style.corner_radius_top_right = 4
	track_style.corner_radius_bottom_left = 4
	track_style.corner_radius_bottom_right = 4

	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = Color(0.2, 0.85, 1.0, 0.9)
	grabber_style.corner_radius_top_left = 4
	grabber_style.corner_radius_top_right = 4
	grabber_style.corner_radius_bottom_left = 4
	grabber_style.corner_radius_bottom_right = 4

	var grabber_hl = grabber_style.duplicate()
	grabber_hl.bg_color = Color(0.2, 0.85, 1.0, 1.0)

	vbar.add_theme_stylebox_override("scroll", track_style)
	vbar.add_theme_stylebox_override("scroll_focus", track_style)
	vbar.add_theme_stylebox_override("grabber", grabber_style)
	vbar.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	vbar.add_theme_stylebox_override("grabber_pressed", grabber_hl)
	
	var scroll_margin_val = 40 if OS.has_feature("mobile") else 24
	scroll_margin.add_theme_constant_override("margin_right", scroll_margin_val)
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.add_child(scroll_margin)
	
	slots_container.add_theme_constant_override("separation", 20)
	slots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(slots_container)
	
	if OS.has_feature("mobile"):
		tab_scroll.scroll_deadzone = 24
		
	# close button matching settings exactly
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	close_button.custom_minimum_size.y = 110 if OS.has_feature("mobile") else 0
	main_container.add_child(close_button)
	
	_switch_mode(current_mode, false)

func _switch_mode(mode: Mode, play_sound: bool = true):
	if play_sound and SoundManager:
		SoundManager.play_sfx("ui_click")
		
	current_mode = mode
	
	_style_tab_button(save_tab_btn, current_mode == Mode.SAVE)
	_style_tab_button(load_tab_btn, current_mode == Mode.LOAD)
	
	_refresh_slots()

func _style_tab_button(btn: Button, is_active: bool):
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.anti_aliasing = false
	style.content_margin_top = 18 if OS.has_feature("mobile") else 12
	style.content_margin_bottom = 18 if OS.has_feature("mobile") else 12
	# the stylebox never set horizontal padding, so SAVE/LOAD sat flush against the pill edges.
	style.content_margin_left = 48 if OS.has_feature("mobile") else 32
	style.content_margin_right = 48 if OS.has_feature("mobile") else 32

	var tab_size = int(30 * (1.5 if OS.has_feature("mobile") else 1.0))
	btn.add_theme_font_override("font", custom_font)
	btn.add_theme_font_size_override("font_size", tab_size)

	if is_active:
		style.bg_color = Color(0.2, 0.85, 1.0, 1.0)
		btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.1, 1.0) if OS.has_feature("mobile") else Color.BLACK)
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
		btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.6, 0.6, 0.6, 1.0) if OS.has_feature("mobile") else Color.WHITE)

	_apply_button_styles(btn, style, style, style, style)

func _apply_button_styles(btn: Button, normal_sb: StyleBox, hover_sb: StyleBox, pressed_sb: StyleBox, disabled_sb: StyleBox) -> void:
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", normal_sb if OS.has_feature("mobile") else hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("hover_pressed", pressed_sb)
	btn.add_theme_stylebox_override("disabled", disabled_sb)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _refresh_slots():
	for child in slots_container.get_children():
		child.queue_free()
		
	var can_save = SaveManager.can_save_now(true)
	
	if current_mode == Mode.SAVE and not can_save:
		var warning = Label.new()
		warning.text = "Cannot save right now."
		warning.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		warning.add_theme_font_override("font", custom_font)
		warning.add_theme_font_size_override("font_size", 32)
		warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slots_container.add_child(warning)
	
	var slots = ["autosave", "slot_1", "slot_2", "slot_3"]
	for slot_id in slots:
		var btn = _create_slot_button(slot_id, can_save)
		slots_container.add_child(btn)
		
	# style CloseButton
	close_button.add_theme_font_override("font", custom_font)
	close_button.add_theme_font_size_override("font_size", 46 if OS.has_feature("mobile") else 28)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_top = 25 if OS.has_feature("mobile") else 10
	btn_normal.content_margin_bottom = 25 if OS.has_feature("mobile") else 10
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.0)
	btn_normal.anti_aliasing = false

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.9)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.8)

	_apply_button_styles(close_button, btn_normal, btn_hover, btn_hover, btn_normal)
	close_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	close_button.add_theme_color_override("font_hover_color", Color(0.8, 0.8, 0.8, 1.0) if OS.has_feature("mobile") else Color.WHITE)
	close_button.add_theme_color_override("font_pressed_color", Color.WHITE)

func _create_slot_button(slot_id: String, can_save: bool) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 100)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# style of buttons matching the rethemed specification
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.0)
	btn_normal.anti_aliasing = false
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.9)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.8)
	
	var btn_disabled = btn_normal.duplicate()
	btn_disabled.bg_color = Color(0.12, 0.12, 0.12, 0.5)
	
	_apply_button_styles(btn, btn_normal, btn_hover, btn_hover, btn_disabled)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_child(hbox)
	btn.add_child(margin)
	
	var name_lbl = Label.new()
	name_lbl.text = "Autosave" if slot_id == "autosave" else "Slot " + slot_id.replace("slot_", "")
	name_lbl.add_theme_font_override("font", custom_font)
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(name_lbl)
	
	var meta = SaveManager.read_meta(slot_id)
	
	var info_lbl = Label.new()
	info_lbl.add_theme_font_override("font", custom_font)
	info_lbl.add_theme_font_size_override("font_size", 20)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	
	if meta.is_empty():
		info_lbl.text = "— Empty —"
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if current_mode == Mode.LOAD or (current_mode == Mode.SAVE and slot_id == "autosave"):
			btn.disabled = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		var time_dict = Time.get_datetime_dict_from_unix_time(meta.get("timestamp_unix", 0))
		var time_str = "%04d-%02d-%02d %02d:%02d" % [time_dict.year, time_dict.month, time_dict.day, time_dict.hour, time_dict.minute]
		
		var play_secs = int(meta.get("playtime_seconds", 0))
		var play_str = "%d:%02d" % [play_secs / 3600, (play_secs % 3600) / 60]
		
		info_lbl.text = "%s  •  %s  •  %s" % [time_str, meta.get("location_label", "Unknown"), play_str]
	
	hbox.add_child(info_lbl)
	
	if current_mode == Mode.SAVE:
		if slot_id == "autosave":
			btn.disabled = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
			var auto_lbl = Label.new()
			auto_lbl.text = "(Autosave disabled)"
			auto_lbl.add_theme_font_override("font", custom_font)
			auto_lbl.add_theme_font_size_override("font_size", 16)
			auto_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			hbox.add_child(auto_lbl)
		elif not can_save:
			btn.disabled = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
			
	btn.pressed.connect(func(): _on_slot_pressed(slot_id, not meta.is_empty()))
	
	return btn

func _on_slot_pressed(slot_id: String, has_data: bool):
	if SoundManager: SoundManager.play_sfx("ui_click")
	
	if current_mode == Mode.SAVE:
		if has_data:
			_show_confirm_overlay("Overwrite this save?", func(): _execute_save(slot_id))
		else:
			_execute_save(slot_id)
	elif current_mode == Mode.LOAD:
		if allow_mode_switch:
			# Loading mid-game is destructive; confirm it.
			_show_confirm_overlay("Load this save? Unsaved progress will be lost.", func(): _execute_load(slot_id))
		else:
			# Loading from main menu directly, no confirmation required.
			_execute_load(slot_id)

func _execute_save(slot_id: String):
	var success = SaveManager.save_to_slot(slot_id)
	if success:
		NotificationManager.add_notification("Game Saved.")
		_refresh_slots()
	else:
		NotificationManager.add_notification("Failed to save game.")

func _execute_load(slot_id: String):
	queue_free()
	if GameManager.pause_menu_ui:
		GameManager.pause_menu_ui.menu_panel.hide()
		GameManager.pause_menu_ui.overlay.hide()
		if GameManager.pause_menu_ui.has_method("reset_pause_snapshot"):
			GameManager.pause_menu_ui.reset_pause_snapshot()
		if GameManager.pause_menu_ui.get_tree().paused:
			GameManager.pause_menu_ui.get_tree().paused = false
	SaveManager.load_from_slot(slot_id)

func _show_confirm_overlay(message: String, on_yes: Callable):
	_confirm_canvas = CanvasLayer.new()
	# UI layering contract: 128 is reserved for the custom cursor. All other CanvasLayers must stay <= 125.
	_confirm_canvas.layer = 125
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_canvas.add_child(overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var panel = PanelContainer.new()
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
	panel.add_theme_stylebox_override("panel", confirm_bg)
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	margin.add_child(vbox)
	
	var label = Label.new()
	label.text = message
	label.add_theme_font_override("font", custom_font)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn_style.content_margin_top = 15
	btn_style.content_margin_bottom = 15
	btn_style.content_margin_left = 40
	btn_style.content_margin_right = 40
	btn_style.border_width_left = 3
	btn_style.border_width_top = 3
	btn_style.border_width_right = 3
	btn_style.border_width_bottom = 3
	btn_style.border_color = Color.WHITE
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.9)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 1.0)
	
	var yes_btn = Button.new()
	yes_btn.text = "YES"
	yes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	yes_btn.add_theme_font_override("font", custom_font)
	yes_btn.add_theme_font_size_override("font_size", 28)
	yes_btn.add_theme_stylebox_override("normal", btn_style)
	yes_btn.add_theme_stylebox_override("hover", btn_hover)
	yes_btn.add_theme_stylebox_override("focus", btn_hover)
	yes_btn.add_theme_stylebox_override("pressed", btn_hover)
	hbox.add_child(yes_btn)
	
	var no_btn = yes_btn.duplicate()
	no_btn.text = "NO"
	hbox.add_child(no_btn)
	
	add_child(_confirm_canvas)
	
	no_btn.pressed.connect(func():
		if SoundManager: SoundManager.play_sfx("ui_click")
		_confirm_canvas.queue_free()
		_confirm_canvas = null
	)
	
	yes_btn.pressed.connect(func():
		if SoundManager: SoundManager.play_sfx("ui_click")
		_confirm_canvas.queue_free()
		_confirm_canvas = null
		on_yes.call()
	)

func _on_close_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	queue_free()

func _input(event):
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		if _confirm_canvas:
			_confirm_canvas.queue_free()
			_confirm_canvas = null
		else:
			queue_free()
		get_viewport().set_input_as_handled()
