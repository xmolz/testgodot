extends CanvasLayer

signal field_submitted(field_id: String, value)
signal form_closed
signal form_submit_requested

# Inputs from LineEditContainer
@onready var first_name_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/FirstName_Edit
@onready var middle_name_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/MiddleName_Edit
@onready var last_name_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/LastName_Edit
@onready var dob_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/DOB_Edit
@onready var phone_number_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/PhoneNumber_Edit
@onready var account_number_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/AccountNumber_Edit

# Buttons from ButtonContainer
@onready var first_name_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/FirstName_Button
@onready var middle_name_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/MiddleName_Button
@onready var last_name_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/LastName_Button
@onready var dob_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/DOB_Button
@onready var phone_number_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/PhoneNumber_Button
@onready var account_number_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/AccountNumber_Button

# The Submit and Back buttons
@onready var submit_button: Button = $TabletFrame/Padding/ContentCanvas/Submit_Button
@onready var back_button: Button = $TabletFrame/Padding/ContentCanvas/Back_Button

func _ready():
	hide()
	# Connect every single button to its own function.
	first_name_button.pressed.connect(_on_first_name_submit)
	middle_name_button.pressed.connect(_on_middle_name_submit)
	last_name_button.pressed.connect(_on_last_name_submit)
	dob_button.pressed.connect(_on_dob_submit)
	phone_number_button.pressed.connect(_on_phone_number_submit)
	account_number_button.pressed.connect(_on_account_number_submit)

	submit_button.pressed.connect(_on_submit_application_pressed)
	back_button.pressed.connect(_on_submit_form) # Route the back button to close the form

	# --- BACK BUTTON OUTLINE (PC & Mobile) ---
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

	# --- MOBILE SCALING FOR INSURANCE FORM ---
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

	# --- DYNAMIC UI ADJUSTMENTS ---
	# Change all "Confirm" buttons to "Check"
	var check_buttons = [first_name_button, middle_name_button, last_name_button, dob_button, phone_number_button, account_number_button]
	for btn in check_buttons:
		btn.text = "Check"

	# Visually "disable" the submit button (but keep it clickable for dialogue)
	submit_button.modulate = Color(0.5, 0.5, 0.5, 1.0)

	# --- RESTORE PREVIOUSLY SOLVED FIELDS ---
	if GameManager and Flags.get_game_flag("first_name_correct"):
		lock_field("first_name", "FIONA")

	# Close form when clicking the dark background
	$ColorRect/BackgroundButton.pressed.connect(func():
		if SoundManager: SoundManager.play_sfx("ui_click")
		_on_submit_form()
	)

# --- HANDLER FUNCTIONS FOR EACH "OKAY" BUTTON ---

func _on_first_name_submit():
	var value = first_name_edit.text
	emit_signal("field_submitted", "first_name", value)

func _on_middle_name_submit():
	var value = middle_name_edit.text
	emit_signal("field_submitted", "middle_name", value)

func _on_last_name_submit():
	var value = last_name_edit.text
	emit_signal("field_submitted", "last_name", value)

func _on_dob_submit():
	var value = dob_edit.text
	emit_signal("field_submitted", "date_of_birth", value)

func _on_phone_number_submit():
	var value = phone_number_edit.text
	emit_signal("field_submitted", "phone_number", value)

func _on_account_number_submit():
	var value = account_number_edit.text
	emit_signal("field_submitted", "account_number", value)

# --- HANDLER FOR THE FINAL SUBMIT/CLOSE BUTTON ---

func _on_submit_application_pressed():
	# Tell the GameManager that we want to evaluate the whole form!
	emit_signal("form_submit_requested")

func _on_submit_form():
	# This function simply closes the form.
	emit_signal("form_closed")
	queue_free()

# --- UI LOCKING LOGIC ---

func lock_field(field_id: String, corrected_value: String):
	match field_id:
		"first_name":
			first_name_edit.text = corrected_value
			first_name_edit.editable = false
			first_name_edit.modulate = Color(0.5, 0.5, 0.5, 1.0) # Grey out text box
			
			first_name_button.disabled = true
			first_name_button.modulate = Color(0.5, 0.5, 0.5, 1.0) # Grey out button
			
		# You can add additional fields here as you expand the logic!
		# "last_name":
		#     last_name_edit.text = corrected_value
		#     last_name_edit.editable = false
		#     last_name_edit.modulate = Color(0.5, 0.5, 0.5, 1.0)
		#     last_name_button.disabled = true
		#     last_name_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
