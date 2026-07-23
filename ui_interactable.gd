# ui_interactable.gd
# attach this script to the root texturebutton node.

extends TextureButton

# get a reference to the
# the '$' syntax is a
@onready var interactable_logic: Interactable = $Interactable


func _ready():
	# when this ui button is
	pressed.connect(_on_button_pressed)

	# connect the hover signals to keep your outline effect!
	# this forwards the ui hover
	mouse_entered.connect(interactable_logic._on_mouse_entered)
	mouse_exited.connect(interactable_logic._on_mouse_exited)


func _on_button_pressed():
	# when clicked, tell the gamemanager
	# but pass in our child
	if GameManager:
		GameManager.process_interaction_click(interactable_logic)
