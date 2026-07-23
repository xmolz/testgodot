# this script must extend "control"
extends Control

# this signal is how the
# it will be used later
signal digit_changed(new_digit: int)

# get direct references to the nodes within this scene.
@onready var up_button: Button = $VBoxContainer/UpButton
@onready var down_button: Button = $VBoxContainer/DownButton
@onready var digit_label: Label = $VBoxContainer/DigitLabel

# this variable holds the "state"
var current_digit: int = 0


# the _ready function runs once,
# it's the perfect place for setup.
func _ready():
	# --------------------(mobile scaling)
	if OS.has_feature("mobile"):
		custom_minimum_size = Vector2(80, 200)
		up_button.add_theme_font_size_override("font_size", 42)
		down_button.add_theme_font_size_override("font_size", 42)
		digit_label.add_theme_font_size_override("font_size", 46)

	# set the label to its starting value.
	_update_label()
	# connect the buttons' 'pressed' signals
	up_button.pressed.connect(_on_up_pressed)
	down_button.pressed.connect(_on_down_pressed)


# this function is called only
func _on_up_pressed():
	# increment the digit, wrapping from
	current_digit = (current_digit + 1) % 10
	# update the visual text.
	_update_label()
	# announce that the digit has
	emit_signal("digit_changed", current_digit)


# this function is called only
func _on_down_pressed():
	# decrement the digit, wrapping from 0 back to 9.
	if current_digit == 0:
		current_digit = 9
	else:
		current_digit -= 1
	# update the visual text.
	_update_label()
	# announce that the digit has
	emit_signal("digit_changed", current_digit)


# a helper function to avoid
# it simply updates the label's
func _update_label():
	digit_label.text = str(current_digit)
