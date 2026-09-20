@tool
class_name PortraitPlaque
extends PanelContainer
## Close-up content for a framed professor portrait: cropped image left, text panel right.
## All text is Inspector-editable; the born line is the keypad clue and is drawn larger.
## Used by OpenCloseupAction via closeup_panel (needs a custom_minimum_size on the image).

@export var professor_name: String = "Dr. Name":
	set(v):
		professor_name = v
		_apply()
@export var subtitle: String = "Ph.D. · Title":
	set(v):
		subtitle = v
		_apply()
@export var lab_line: String = "Head, Laboratory · Greendale University":
	set(v):
		lab_line = v
		_apply()
@export var born_line: String = "Born 01/01/1960 · City":
	set(v):
		born_line = v
		_apply()
@export_multiline var body_text: String = "Two or three lines about them, in the voice of whoever commissioned the plaque.":
	set(v):
		body_text = v
		_apply()
@export_multiline var quote_text: String = "\"A quote that tells you who they are.\"":
	set(v):
		quote_text = v
		_apply()
@export var dedication: String = "Portrait commissioned by the Graduate Association":
	set(v):
		dedication = v
		_apply()
@export var panel_tint: Color = Color(0.84, 0.84, 0.82, 1.0):
	set(v):
		panel_tint = v
		_apply()

@onready var _name_label: Label = %NameLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _lab_label: Label = %LabLabel
@onready var _born_label: Label = %BornLabel
@onready var _body_label: Label = %BodyLabel
@onready var _quote_label: Label = %QuoteLabel
@onready var _dedication_label: Label = %DedicationLabel
@onready var _text_panel: PanelContainer = %TextPanel


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	_name_label.text = professor_name
	_subtitle_label.text = subtitle
	_lab_label.text = lab_line
	_born_label.text = born_line
	_body_label.text = body_text
	_quote_label.text = quote_text
	_dedication_label.text = dedication
	var style := _text_panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var sb: StyleBoxFlat = (style as StyleBoxFlat).duplicate()
		sb.bg_color = panel_tint
		_text_panel.add_theme_stylebox_override("panel", sb)
