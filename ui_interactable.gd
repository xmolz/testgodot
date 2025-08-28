# UI_Interactable.gd
# Attach this script to the root TextureButton node.

extends TextureButton

# Get a reference to the child node that has all the real game logic.
# The '$' syntax is a shorthand way to get a direct child node.
@onready var interactable_logic: Interactable = $Interactable


func _ready():
	# When this UI button is pressed, call our custom function.
	pressed.connect(_on_button_pressed)

	# Connect the hover signals to keep your outline effect!
	# This forwards the UI hover event to the Interactable's existing functions.
	mouse_entered.connect(interactable_logic._on_mouse_entered)
	mouse_exited.connect(interactable_logic._on_mouse_exited)


func _on_button_pressed():
	# When clicked, tell the GameManager to process an interaction,
	# but pass in our child node, which has all the data and logic.
	if GameManager:
		GameManager.process_interaction_click(interactable_logic)
