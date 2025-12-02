extends CanvasLayer

# This is the signal that the GameManager will listen for.
signal form_button_pressed

# Get a reference to the actual button node in the scene.
@onready var texture_button: TextureButton = $TextureButton


func _ready():
	# Connect the child button's 'pressed' signal to a function in THIS script.
	# We are essentially "listening" to our own child.
	texture_button.pressed.connect(_on_texture_button_pressed)


func _on_texture_button_pressed():
	# This function runs when the child button is clicked.
	print("The insurance form was clicked on! (Signal from inside the scene)")

	# Now, we emit our OWN signal to notify the outside world (like GameManager).
	# This is called "bubbling up" a signal.
	emit_signal("form_button_pressed")
