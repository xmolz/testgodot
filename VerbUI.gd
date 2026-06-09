# VerbUI.gd
extends CanvasLayer

@onready var action_bubble_label: RichTextLabel = $ActionBubbleLabel
@onready var verb_button_grid: GridContainer = $VerbGridPanel/GridContainer

var active_verb_buttons: Dictionary = {}
var all_button_slots: Array[Button] = []
var normal_bubble_style: StyleBoxFlat
var disabled_bubble_style: StyleBoxFlat
var think_pulse_tween: Tween

func _ready():
	if verb_button_grid:
		verb_button_grid.columns = 3
	else:
		print_rich("[color=red]VerbUI: VerbButtonGrid node not found! Cannot set columns.[/color]")
		return

	for child in verb_button_grid.get_children():
		verb_button_grid.remove_child(child)
		child.queue_free()

	all_button_slots.clear()
	active_verb_buttons.clear()

	# Enforce horizontal anchors to prevent overlapping
	$VerbGridPanel.anchor_left = 0.02
	$VerbGridPanel.anchor_right = 0.44

	if OS.has_feature("mobile"):
		$VerbGridPanel.anchor_top = 0.75
		$VerbGridPanel/TabPanel.offset_top = -50
		$VerbGridPanel/TabPanel.offset_right = 190
		$VerbGridPanel/TabPanel/ActionsLabel.add_theme_font_size_override("font_size", 28)
		action_bubble_label.add_theme_font_size_override("normal_font_size", 28)

	for i in range(9):
		var new_button = Button.new()
		new_button.text = "-"
		new_button.disabled = true
		new_button.name = "VerbSlotButton_" + str(i)
		if OS.has_feature("mobile"):
			new_button.custom_minimum_size = Vector2(0, 0)
			new_button.add_theme_font_size_override("font_size", 36)
		else:
			new_button.custom_minimum_size = Vector2(100, 30)
		new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_button.size_flags_vertical = Control.SIZE_EXPAND_FILL

		# --- THE FIX: Disable focus so it doesn't get stuck highlighted! ---
		new_button.focus_mode = Control.FOCUS_NONE
		# -------------------------------------------------------------------

		all_button_slots.append(new_button)
		verb_button_grid.add_child(new_button)

	if GameManager:
		GameManager.available_verbs_changed.connect(_on_available_verbs_changed)
		GameManager.verb_changed.connect(_on_game_manager_verb_changed)
		GameManager.sentence_line_updated.connect(_on_game_manager_sentence_line_updated)
		GameManager.interaction_complete.connect(_on_interaction_complete)
		GameManager.new_hint_available.connect(_on_new_hint_available)

		if GameManager.has_method("get_currently_displayable_verbs"):
			_on_available_verbs_changed(GameManager.get_currently_displayable_verbs())
		else:
			print_rich("[color=orange]VerbUI: GameManager doesn't have get_currently_displayable_verbs yet.[/color]")

	else:
		print_rich("[color=red]VerbUI: GameManager not found during _ready().[/color]")

	action_bubble_label.visible = false

	# --- PC UI COLOR HIGHLIGHT FIX: Configure RichTextLabel properties ---
	action_bubble_label.bbcode_enabled = true
	action_bubble_label.fit_content = true
	action_bubble_label.scroll_active = false
	action_bubble_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	action_bubble_label.add_theme_font_override("normal_font", preload("res://Fonts/VarelaRound-Regular.ttf"))
	action_bubble_label.add_theme_font_size_override("normal_font_size", 24)
	action_bubble_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	action_bubble_label.add_theme_constant_override("shadow_outline_size", 1)

	# --- QOL FIX: Cache styles for faded label ---
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

	for i in range(all_button_slots.size()):
		var button_node: Button = all_button_slots[i]

		for conn in button_node.pressed.get_connections():
			if conn.callable.get_object() == self:
				button_node.pressed.disconnect(conn.callable)

		if i < available_verb_data_array.size():
			var verb_data: VerbData = available_verb_data_array[i]
			if verb_data and is_instance_valid(verb_data):
				button_node.text = verb_data.display_text
				button_node.disabled = false
				button_node.set_meta("verb_id", verb_data.verb_id)
				button_node.pressed.connect(_on_verb_button_pressed_dynamic.bind(verb_data.verb_id))
				active_verb_buttons[verb_data.verb_id] = button_node
			else:
				button_node.text = "-"
				button_node.disabled = true
				button_node.set_meta("verb_id", "")
		else:
			button_node.text = "-"
			button_node.disabled = true
			button_node.set_meta("verb_id", "")

	_update_button_selected_visual_state(GameManager.current_verb_id if GameManager else "")

	if GameManager and GameManager.has_method("has_unread_hint"):
		_on_new_hint_available(GameManager.has_unread_hint())

func _on_verb_button_pressed_dynamic(verb_id_pressed: String):
	if SoundManager: SoundManager.play_sfx("ui_click")

	if GameManager and verb_id_pressed != "":
		GameManager.select_verb(verb_id_pressed)
	else:
		print("VerbUI: GameManager not found or empty verb_id pressed.")

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

		# --- QOL FIX: Faded label for incomplete Give ---
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
