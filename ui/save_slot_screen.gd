extends CanvasLayer

enum Mode { SAVE, LOAD }
var current_mode: Mode = Mode.SAVE

@onready var background_rect = ColorRect.new()
@onready var main_container = VBoxContainer.new()
@onready var title_label = Label.new()
@onready var slots_container = VBoxContainer.new()

var _confirm_canvas: CanvasLayer = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120 # above pause menu (110)
	
	background_rect.color = Color(0, 0, 0, 0.8)
	background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background_rect)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_bottom", 100)
	margin.add_theme_constant_override("margin_left", 200)
	margin.add_theme_constant_override("margin_right", 200)
	add_child(margin)
	
	main_container.add_theme_constant_override("separation", 50)
	margin.add_child(main_container)
	
	title_label.text = "SAVE GAME" if current_mode == Mode.SAVE else "LOAD GAME"
	title_label.add_theme_font_override("font", preload("res://Fonts/VarelaRound-Regular.ttf"))
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	slots_container.add_theme_constant_override("separation", 20)
	main_container.add_child(slots_container)
	
	_refresh_slots()

func _refresh_slots():
	for child in slots_container.get_children():
		child.queue_free()
		
	var can_save = SaveManager.can_save_now(true)
	
	if current_mode == Mode.SAVE and not can_save:
		var warning = Label.new()
		warning.text = "Cannot save right now."
		warning.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		warning.add_theme_font_override("font", preload("res://Fonts/VarelaRound-Regular.ttf"))
		warning.add_theme_font_size_override("font_size", 32)
		warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slots_container.add_child(warning)
	
	var slots = ["autosave", "slot_1", "slot_2", "slot_3"]
	for slot_id in slots:
		var btn = _create_slot_button(slot_id, can_save)
		slots_container.add_child(btn)

func _create_slot_button(slot_id: String, can_save: bool) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 100)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	
	var hover_style = style.duplicate()
	hover_style.border_color = Color(0.2, 0.85, 1.0)
	hover_style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_child(hbox)
	btn.add_child(margin)
	
	var font = preload("res://Fonts/VarelaRound-Regular.ttf")
	
	var name_lbl = Label.new()
	name_lbl.text = "Autosave" if slot_id == "autosave" else "Slot " + slot_id.replace("slot_", "")
	name_lbl.add_theme_font_override("font", font)
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(name_lbl)
	
	var meta = SaveManager.read_meta(slot_id)
	
	var info_lbl = Label.new()
	info_lbl.add_theme_font_override("font", font)
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
			auto_lbl.add_theme_font_override("font", font)
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
			_show_confirm_overlay(slot_id)
		else:
			_execute_save(slot_id)
	elif current_mode == Mode.LOAD:
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
		if GameManager.pause_menu_ui.get_tree().paused:
			GameManager.pause_menu_ui.get_tree().paused = false
	SaveManager.load_from_slot(slot_id)

func _show_confirm_overlay(slot_id: String):
	_confirm_canvas = CanvasLayer.new()
	_confirm_canvas.layer = 150
	
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
	label.text = "Overwrite this save?"
	label.add_theme_font_override("font", preload("res://Fonts/VarelaRound-Regular.ttf"))
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
	
	var font = preload("res://Fonts/VarelaRound-Regular.ttf")
	
	var yes_btn = Button.new()
	yes_btn.text = "YES"
	yes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	yes_btn.add_theme_font_override("font", font)
	yes_btn.add_theme_font_size_override("font_size", 28)
	yes_btn.add_theme_stylebox_override("normal", btn_style)
	yes_btn.add_theme_stylebox_override("hover", btn_hover)
	yes_btn.add_theme_stylebox_override("focus", btn_hover)
	yes_btn.add_theme_stylebox_override("pressed", btn_hover)
	hbox.add_child(yes_btn)
	
	var no_btn = yes_btn.duplicate()
	no_btn.text = "NO"
	hbox.add_child(no_btn)
	
	get_tree().root.add_child(_confirm_canvas)
	
	no_btn.pressed.connect(func():
		if SoundManager: SoundManager.play_sfx("ui_click")
		_confirm_canvas.queue_free()
		_confirm_canvas = null
	)
	
	yes_btn.pressed.connect(func():
		if SoundManager: SoundManager.play_sfx("ui_click")
		_confirm_canvas.queue_free()
		_confirm_canvas = null
		_execute_save(slot_id)
	)

func _input(event):
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		if _confirm_canvas:
			_confirm_canvas.queue_free()
			_confirm_canvas = null
		else:
			queue_free()
		get_viewport().set_input_as_handled()