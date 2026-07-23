extends CanvasLayer

signal form_closed

const FORM_DIALOGUE = preload("res://dialogue/form_related_dialogue.dialogue")
const CONVERSATION_BALLOON_SCENE = preload("res://conversation/conversationballoon.tscn")

# inputs from lineeditcontainer
@onready var first_name_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/FirstName_Edit
@onready var middle_name_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/MiddleName_Edit
@onready var last_name_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/LastName_Edit
@onready var dob_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/DOB_Edit
@onready var phone_number_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/PhoneNumber_Edit
@onready var account_number_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/AccountNumber_Edit

# buttons from buttoncontainer
@onready var first_name_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/FirstName_Button
@onready var middle_name_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/MiddleName_Button
@onready var last_name_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/LastName_Button
@onready var dob_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/DOB_Button
@onready var phone_number_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/PhoneNumber_Button
@onready var account_number_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/AccountNumber_Button

# the submit and back button
@onready var submit_button: Button = $TabletFrame/Padding/ContentCanvas/Submit_Button
@onready var back_button: Button = $TabletFrame/Padding/ContentCanvas/Back_Button

func _ready():
	hide()
	# connect every single button to its own function.
	first_name_button.pressed.connect(_on_first_name_submit)
	middle_name_button.pressed.connect(_on_middle_name_submit)
	last_name_button.pressed.connect(_on_last_name_submit)
	dob_button.pressed.connect(_on_dob_submit)
	phone_number_button.pressed.connect(_on_phone_number_submit)
	account_number_button.pressed.connect(_on_account_number_submit)

	submit_button.pressed.connect(_on_submit_application_pressed)
	back_button.pressed.connect(_on_submit_form)

	# /////////////////(back button outline (pc & mobile))
	back_button.flat = false
	var back_normal = StyleBoxFlat.new()
	back_normal.bg_color = Color(0.1, 0.15, 0.2, 0.8)
	back_normal.corner_radius_top_left = 6
	back_normal.corner_radius_top_right = 6
	back_normal.corner_radius_bottom_left = 6
	back_normal.corner_radius_bottom_right = 6
	back_normal.border_width_left = 2
	back_normal.border_width_top = 2
	back_normal.border_width_right = 2
	back_normal.border_width_bottom = 2
	back_normal.border_color = Color(0.4, 0.5, 0.6, 0.8)
	back_normal.content_margin_left = 15
	back_normal.content_margin_right = 15
	back_normal.content_margin_top = 5
	back_normal.content_margin_bottom = 5

	var back_hover = back_normal.duplicate()
	back_hover.bg_color = Color(0.2, 0.3, 0.4, 0.9)
	back_hover.border_color = Color(0.2, 0.85, 1.0, 1.0)

	back_button.add_theme_stylebox_override("normal", back_normal)
	back_button.add_theme_stylebox_override("hover", back_hover)
	back_button.add_theme_stylebox_override("focus", back_hover)
	back_button.add_theme_stylebox_override("pressed", back_hover)

	# ***********************[mobile scaling for insurance form]
	if OS.has_feature("mobile"):
		$TabletFrame.anchor_left = 0.05
		$TabletFrame.anchor_right = 0.95
		$TabletFrame.anchor_top = 0.05
		$TabletFrame.anchor_bottom = 0.95

		var header_logo = $TabletFrame/Padding/ContentCanvas/HeaderContainer/HavemoreLabel
		var header_text = $TabletFrame/Padding/ContentCanvas/HeaderContainer/Label2
		var subtitle = $TabletFrame/Padding/ContentCanvas/Subtitle

		header_logo.add_theme_font_size_override("font_size", 60)
		header_text.add_theme_font_size_override("font_size", 44)
		subtitle.add_theme_font_size_override("font_size", 30)
		subtitle.offset_top = 130
		subtitle.offset_bottom = 170

		back_button.add_theme_font_size_override("font_size", 36)
		submit_button.add_theme_font_size_override("font_size", 42)

		var labels_container = $TabletFrame/Padding/ContentCanvas/LabelsContainer
		for child in labels_container.get_children():
			if child is Label:
				child.add_theme_font_size_override("font_size", 32)
				child.custom_minimum_size.y = 80

		var edits_container = $TabletFrame/Padding/ContentCanvas/LineEditContainer
		for child in edits_container.get_children():
			if child is LineEdit:
				child.add_theme_font_size_override("font_size", 30)
				child.custom_minimum_size.y = 80

		var btns_container = $TabletFrame/Padding/ContentCanvas/ButtonContainer
		for child in btns_container.get_children():
			if child is Button:
				child.add_theme_font_size_override("font_size", 30)
				child.custom_minimum_size.y = 80

	# ********** dynamic ui adjustments
	# change all "confirm" buttons to "check"
	var check_buttons = [first_name_button, middle_name_button, last_name_button, dob_button, phone_number_button, account_number_button]
	for btn in check_buttons:
		btn.text = "Check"

	# visually "disable" the submit button
	submit_button.modulate = Color(0.5, 0.5, 0.5, 1.0)

	# ////////////(restore previously solved fields)
	if GameManager and Flags.get_game_flag("first_name_correct"):
		lock_field("first_name", "FIONA")

	# close form when clicking the dark background
	$ColorRect/BackgroundButton.pressed.connect(func():
		if SoundManager: SoundManager.play_sfx("ui_click")
		_on_submit_form()
	)

# ---------------[handler functions for each "okay" button]

func _on_first_name_submit():
	_handle_field_submitted("first_name", first_name_edit.text)

func _on_middle_name_submit():
	_handle_field_submitted("middle_name", middle_name_edit.text)

func _on_last_name_submit():
	_handle_field_submitted("last_name", last_name_edit.text)

func _on_dob_submit():
	_handle_field_submitted("date_of_birth", dob_edit.text)

func _on_phone_number_submit():
	_handle_field_submitted("phone_number", phone_number_edit.text)

func _on_account_number_submit():
	_handle_field_submitted("account_number", account_number_edit.text)

# -----------------------[handler for the final submit/close button]

func _on_submit_application_pressed():
	_handle_submit_requested()

func _on_submit_form():
	# this function simply closes the form.
	emit_signal("form_closed")
	queue_free()

# //////////////////////[ui locking logic]

func lock_field(field_id: String, corrected_value: String):
	match field_id:
		"first_name":
			first_name_edit.text = corrected_value
			first_name_edit.editable = false
			first_name_edit.modulate = Color(0.5, 0.5, 0.5, 1.0)
			
			first_name_button.disabled = true
			first_name_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
			
		# you can add additional fields
		# "last_name":
		# last_name_edit.text = corrected_value
		# last_name_edit.editable = false
		# last_name_edit.modulate = color(0.5, 0.5, 0.5, 1.0)
		# last_name_button.disabled = true
		# last_name_button.modulate = color(0.5, 0.5, 0.5, 1.0)

# ********************* puzzle logic (moved from gamemanager)

func _handle_field_submitted(field_id: String, value):
	match field_id:
		"first_name":
			var regex = RegEx.new()
			regex.compile("(?i)^\\s*fiona\\s*$")

			if regex.search(value):
				if SoundManager: SoundManager.play_sfx("form_correct_input")
				lock_field("first_name", "FIONA")

				var balloon = DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, FORM_DIALOGUE, "first_name_correct")
				if is_instance_valid(balloon): balloon.process_mode = Node.PROCESS_MODE_ALWAYS

				Flags.set_game_flag("first_name_correct", true)

			else:
				if SoundManager: SoundManager.play_sfx("form_incorrect_input")

				var formatted_wrong_name = _format_wrong_name(value)
				var temp_state = {"wrong_name": formatted_wrong_name}
				var balloon = DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, FORM_DIALOGUE, "first_name_incorrect", [temp_state])
				if is_instance_valid(balloon): balloon.process_mode = Node.PROCESS_MODE_ALWAYS

		_:
			if SoundManager: SoundManager.play_sfx("form_incorrect_input")
			var balloon = DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, FORM_DIALOGUE, "field_not_ready")
			if is_instance_valid(balloon): balloon.process_mode = Node.PROCESS_MODE_ALWAYS

func _format_wrong_name(raw_name: String) -> String:
	var clean = raw_name.strip_edges().to_lower()
	if clean.length() == 0:
		return "..."
	elif clean.length() <= 2:
		return clean.substr(0, 1).to_upper() + clean.substr(1) + "..."
	else:
		var part1 = clean.substr(0, 1).to_upper() + clean.substr(1, 1)
		var part2 = clean.substr(2)
		return part1 + "..." + part2

func _handle_submit_requested():
	var f_name = Flags.get_game_flag("first_name_correct")
	var m_name = Flags.get_game_flag("middle_name_correct")
	var l_name = Flags.get_game_flag("last_name_correct")
	var dob = Flags.get_game_flag("dob_correct")
	var phone = Flags.get_game_flag("phone_number_correct")
	var account = Flags.get_game_flag("account_number_correct")

	if f_name and m_name and l_name and dob and phone and account:
		if SoundManager: SoundManager.play_sfx("form_correct_input")
		var balloon = DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, FORM_DIALOGUE, "complete_submit")
		if is_instance_valid(balloon): balloon.process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		if SoundManager: SoundManager.play_sfx("form_incorrect_input")
		var balloon = DialogueManager.show_dialogue_balloon_scene(CONVERSATION_BALLOON_SCENE, FORM_DIALOGUE, "incomplete_submit")
		if is_instance_valid(balloon): balloon.process_mode = Node.PROCESS_MODE_ALWAYS
