# VerbUI.gd
extends CanvasLayer

@onready var action_bubble_label: RichTextLabel = $ActionBubbleLabel
@onready var dynamic_verb_vbox: VBoxContainer = %DynamicVerbVBox

var active_verb_buttons: Dictionary = {}
var all_button_slots: Array[Button] = []
var normal_bubble_style: StyleBoxFlat
var disabled_bubble_style: StyleBoxFlat
var think_pulse_tween: Tween

const PREFERRED_ORDER = ["examine", "use", "talk_to", "pickup"]
const ROW_RECIPES = {
	1: [1],
	2: [1, 1],
	3: [2, 1],
	4: [2, 2],
	5: [3, 2],
	6: [3, 3],
	7: [3, 2, 2],
	8: [3, 3, 2],
	9: [3, 3, 3],
}

func _ready():
	dynamic_verb_vbox.anchor_left = 0.02
	dynamic_verb_vbox.anchor_right = 0.44

	if OS.has_feature("mobile"):
		dynamic_verb_vbox.anchor_top = 0.75
		var tab_panel = dynamic_verb_vbox.get_node("TabPanel")
		tab_panel.offset_top = -50
		tab_panel.offset_right = 190
		tab_panel.get_node("ActionsLabel").add_theme_font_size_override("font_size", 28)
		action_bubble_label.add_theme_font_size_override("normal_font_size", 28)

	# Background panel behind verb buttons
	var verb_grid_panel = Panel.new()
	verb_grid_panel.name = "VerbGridPanel"
	verb_grid_panel.anchor_left = dynamic_verb_vbox.anchor_left
	verb_grid_panel.anchor_top = dynamic_verb_vbox.anchor_top
	verb_grid_panel.anchor_right = dynamic_verb_vbox.anchor_right
	verb_grid_panel.anchor_bottom = dynamic_verb_vbox.anchor_bottom
	verb_grid_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.5)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(1, 1, 1, 1)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	verb_grid_panel.add_theme_stylebox_override("panel", panel_style)

	add_child(verb_grid_panel)
	move_child(verb_grid_panel, dynamic_verb_vbox.get_index())

	dynamic_verb_vbox.add_theme_constant_override("separation", 12)

	if GameManager:
		GameManager.available_verbs_changed.connect(_on_available_verbs_changed)
		GameManager.verb_changed.connect(_on_game_manager_verb_changed)
		GameManager.sentence_line_updated.connect(_on_game_manager_sentence_line_updated)
		GameManager.interaction_complete.connect(_on_interaction_complete)
		GameManager.new_hint_available.connect(_on_new_hint_available)

		if GameManager.has_method("get_currently_displayable_verbs"):
			_on_available_verbs_changed(GameManager.get_currently_displayable_verbs())

	action_bubble_label.visible = false

	action_bubble_label.bbcode_enabled = true
	action_bubble_label.fit_content = true
	action_bubble_label.scroll_active = false
	action_bubble_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	action_bubble_label.add_theme_font_override("normal_font", preload("res://Fonts/VarelaRound-Regular.ttf"))
	action_bubble_label.add_theme_font_size_override("normal_font_size", 24)
	action_bubble_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	action_bubble_label.add_theme_constant_override("shadow_outline_size", 1)

	normal_bubble_style = action_bubble_label.get_theme_stylebox("normal").duplicate()
	disabled_bubble_style = normal_bubble_style.duplicate()
	disabled_bubble_style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	disabled_bubble_style.border_color = Color(0.4, 0.4, 0.4, 0.8)

func _process(_delta: float) -> void:
	if OS.has_feature("mobile"): return
	if action_bubble_label.visible:
		action_bubble_label.global_position = get_viewport().get_mouse_position() + Vector2(15, 15)

func _on_available_verbs_changed(available_verb_data_array: Array[VerbData]):
	active_verb_buttons.clear()
	all_button_slots.clear()

	for child in dynamic_verb_vbox.get_children():
		if child is HBoxContainer:
			child.queue_free()

	# Sort verbs: preferred order first, then the rest
	var sorted_verbs: Array[VerbData] = []
	var remaining: Array[VerbData] = available_verb_data_array.duplicate()
	for preferred_id in PREFERRED_ORDER:
		for verb in remaining:
			if verb.verb_id == preferred_id:
				sorted_verbs.append(verb)
				remaining.erase(verb)
				break
	sorted_verbs.append_array(remaining)

	var count = sorted_verbs.size()
	if count == 0:
		_update_button_selected_visual_state("")
		return

	var recipe = ROW_RECIPES.get(count, _fallback_recipe(count))

	var verb_index = 0
	for row_count in recipe:
		var hbox = HBoxContainer.new()
		hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 12)
		dynamic_verb_vbox.add_child(hbox)

		for j in range(row_count):
			if verb_index >= sorted_verbs.size():
				break
			var verb_data: VerbData = sorted_verbs[verb_index]
			var btn = Button.new()
			btn.text = verb_data.display_text
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			btn.focus_mode = Control.FOCUS_NONE
			btn.set_meta("verb_id", verb_data.verb_id)
			btn.pressed.connect(_on_verb_button_pressed_dynamic.bind(verb_data.verb_id))

			_style_verb_button(btn)
			if not OS.has_feature("mobile"):
				btn.custom_minimum_size = Vector2(100, 30)

			hbox.add_child(btn)
			all_button_slots.append(btn)
			active_verb_buttons[verb_data.verb_id] = btn
			verb_index += 1

	_update_button_selected_visual_state(GameManager.current_verb_id if GameManager else "")

	if GameManager and GameManager.has_method("has_unread_hint"):
		_on_new_hint_available(GameManager.has_unread_hint())

func _fallback_recipe(count: int) -> Array:
	var recipe = []
	var left = count
	while left > 0:
		var row = mini(left, 3)
		recipe.append(row)
		left -= row
	return recipe

func _style_verb_button(btn: Button):
	var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")
	btn.add_theme_font_override("font", custom_font)
	btn.add_theme_font_size_override("font_size", 36 if OS.has_feature("mobile") else 22)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.15, 0.6)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.6, 0.6, 0.6, 0.8)
	normal_style.corner_radius_top_left = 5
	normal_style.corner_radius_top_right = 5
	normal_style.corner_radius_bottom_left = 5
	normal_style.corner_radius_bottom_right = 5

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.25, 0.25, 0.8)
	hover_style.border_color = Color(1, 1, 1, 1)

	var focus_style = StyleBoxEmpty.new()

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("focus", focus_style)

func _on_verb_button_pressed_dynamic(verb_id_pressed: String):
	if SoundManager: SoundManager.play_sfx("ui_click")

	if GameManager and verb_id_pressed != "":
		GameManager.select_verb(verb_id_pressed)

func _on_game_manager_verb_changed(new_verb_id: String):
	if OS.has_feature("mobile"):
		action_bubble_label.visible = false
		_update_button_selected_visual_state(new_verb_id)
		return
	if new_verb_id == "":
		action_bubble_label.visible = false
	else:
		var verb_data = GameManager.get_verb_data_by_id(new_verb_id) if GameManager else null
		if verb_data:
			action_bubble_label.text = verb_data.display_text + ":"
		else:
			action_bubble_label.text = new_verb_id + ":"

		action_bubble_label.reset_size()
		action_bubble_label.visible = true

	_update_button_selected_visual_state(new_verb_id)

func _on_game_manager_sentence_line_updated(full_sentence: String):
	if OS.has_feature("mobile"):
		action_bubble_label.visible = false
		return
	if full_sentence == "":
		action_bubble_label.visible = false
	else:
		action_bubble_label.text = full_sentence
		action_bubble_label.reset_size()
		action_bubble_label.visible = true

		if GameManager and GameManager.current_verb_id == "give" and GameManager.current_selected_item_data == null and GameManager.hovered_interactable != null:
			action_bubble_label.add_theme_stylebox_override("normal", disabled_bubble_style)
			action_bubble_label.add_theme_color_override("default_color", Color(0.6, 0.6, 0.6, 1.0))
		else:
			action_bubble_label.add_theme_stylebox_override("normal", normal_bubble_style)
			action_bubble_label.remove_theme_color_override("default_color")

func _on_interaction_complete():
	action_bubble_label.visible = false
	_update_button_selected_visual_state("")

func _update_button_selected_visual_state(selected_verb_id: String):
	for button_node in all_button_slots:
		var button_verb_id = button_node.get_meta("verb_id", "")
		if is_instance_valid(button_node):
			if button_verb_id == "think" and think_pulse_tween and think_pulse_tween.is_valid():
				continue

			if button_verb_id != "" and button_verb_id == selected_verb_id:
				button_node.modulate = Color(0.2, 0.85, 1.0, 1.0)
			else:
				button_node.modulate = Color(1.0, 1.0, 1.0)

func _on_new_hint_available(is_available: bool):
	if not active_verb_buttons.has("think"): return
	var btn = active_verb_buttons["think"]

	if think_pulse_tween and think_pulse_tween.is_valid():
		think_pulse_tween.kill()

	if is_available and GameManager and GameManager.assisted_mode:
		btn.modulate = Color.WHITE
		think_pulse_tween = create_tween().set_loops()
		think_pulse_tween.tween_property(btn, "modulate", Color(1.0, 1.0, 0.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
		think_pulse_tween.tween_property(btn, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		if GameManager and GameManager.current_verb_id == "think":
			btn.modulate = Color(0.2, 0.85, 1.0, 1.0)
		else:
			btn.modulate = Color.WHITE
