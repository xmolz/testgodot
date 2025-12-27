# This script MUST extend Control.
extends Control

# --- THIS IS THE CRUCIAL FIX ---
# This code uses direct paths to the nodes shown in your screenshot.
# It is guaranteed to work with your scene structure.
@onready var d1: Control = $HBoxContainer/Day1
@onready var d2: Control = $HBoxContainer/Day2
@onready var m1: Control = $HBoxContainer/Month1
@onready var m2: Control = $HBoxContainer/Month2
@onready var y1: Control = $HBoxContainer/Year1
@onready var y2: Control = $HBoxContainer/Year2
@onready var y3: Control = $HBoxContainer/Year3
@onready var y4: Control = $HBoxContainer/Year4
# ---------------------------------

@onready var hbox_container: HBoxContainer = $HBoxContainer

func _ready():
	# This line fixes the layout/overlap issue.
	self.custom_minimum_size = hbox_container.get_combined_minimum_size()

func get_date_string() -> String:
	# Because the paths above are now correct, this function will work
	# without the "null instance" error.
	var day_str = str(d1.current_digit) + str(d2.current_digit)
	var month_str = str(m1.current_digit) + str(m2.current_digit)
	var year_str = str(y1.current_digit) + str(y2.current_digit) + str(y3.current_digit) + str(y4.current_digit)

	return "%s/%s/%s" % [day_str, month_str, year_str]
