extends CanvasLayer

signal field_submitted(field_id: String, value)
signal form_closed

# --- NEW, CORRECT NODE PATHS FOR YOUR ORGANIZED SCENE ---
# We get a reference to every single input and button.

# Inputs from LineEditContainer
@onready var first_name_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/FirstName_Edit
@onready var middle_name_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/MiddleName_Edit
@onready var last_name_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/LastName_Edit
@onready var dob_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/DOB_Edit # Now a LineEdit
@onready var phone_number_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/PhoneNumber_Edit
@onready var account_number_edit: LineEdit = $TabletFrame/Padding/ContentCanvas/LineEditContainer/AccountNumber_Edit

# Buttons from ButtonContainer
@onready var first_name_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/FirstName_Button
@onready var middle_name_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/MiddleName_Button
@onready var last_name_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/LastName_Button
@onready var dob_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/DOB_Button
@onready var phone_number_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/PhoneNumber_Button
@onready var account_number_button: Button = $TabletFrame/Padding/ContentCanvas/ButtonContainer/AccountNumber_Button

# The final submit button (renamed from close_button)
@onready var submit_button: Button = $TabletFrame/Padding/ContentCanvas/Submit_Button


func _ready():
	hide()
	# Connect every single button to its own function.
	first_name_button.pressed.connect(_on_first_name_submit)
	middle_name_button.pressed.connect(_on_middle_name_submit)
	last_name_button.pressed.connect(_on_last_name_submit)
	dob_button.pressed.connect(_on_dob_submit)
	phone_number_button.pressed.connect(_on_phone_number_submit)
	account_number_button.pressed.connect(_on_account_number_submit)

	submit_button.pressed.connect(_on_submit_form) # This is your old close button

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
	# This now gets the text from the LineEdit, not the date spinner.
	var value = dob_edit.text
	emit_signal("field_submitted", "date_of_birth", value)

func _on_phone_number_submit():
	var value = phone_number_edit.text
	emit_signal("field_submitted", "phone_number", value)

func _on_account_number_submit():
	var value = account_number_edit.text
	emit_signal("field_submitted", "account_number", value)

# --- HANDLER FOR THE FINAL SUBMIT/CLOSE BUTTON ---

func _on_submit_form():
	# This function simply closes the form.
	emit_signal("form_closed")
	queue_free()
