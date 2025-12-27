# This script MUST extend "Control" because its root node is a Control node.
extends Control

# This signal is how the spinner communicates with the outside world.
# It will be used later if you want to validate the date as it's being entered.
signal digit_changed(new_digit: int)

# Get direct references to the nodes within this scene.
@onready var up_button: Button = $VBoxContainer/UpButton
@onready var down_button: Button = $VBoxContainer/DownButton
@onready var digit_label: Label = $VBoxContainer/DigitLabel

# This variable holds the "state" or current value of this spinner.
var current_digit: int = 0


# The _ready function runs once, when the node is first added to the scene.
# It's the perfect place for setup.
func _ready():
	# Set the label to its starting value.
	_update_label()
	# Connect the buttons' 'pressed' signals to our functions below.
	up_button.pressed.connect(_on_up_pressed)
	down_button.pressed.connect(_on_down_pressed)


# This function is called ONLY when the up_button is pressed.
func _on_up_pressed():
	# Increment the digit, wrapping from 9 back to 0 using the modulo operator.
	current_digit = (current_digit + 1) % 10
	# Update the visual text.
	_update_label()
	# Announce that the digit has changed and what its new value is.
	emit_signal("digit_changed", current_digit)


# This function is called ONLY when the down_button is pressed.
func _on_down_pressed():
	# Decrement the digit, wrapping from 0 back to 9.
	if current_digit == 0:
		current_digit = 9
	else:
		current_digit -= 1
	# Update the visual text.
	_update_label()
	# Announce that the digit has changed and what its new value is.
	emit_signal("digit_changed", current_digit)


# A helper function to avoid repeating the same line of code.
# It simply updates the Label's text to match our current_digit variable.
func _update_label():
	digit_label.text = str(current_digit)
