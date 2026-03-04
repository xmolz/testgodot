extends CanvasLayer

signal form_button_pressed

# We updated the node path to match the new panel structure
@onready var texture_button: TextureButton = $FormPanel/MarginContainer/TextureButton

func _ready():
	texture_button.pressed.connect(_on_texture_button_pressed)
	
	# Add hover effects to make it feel responsive
	texture_button.mouse_entered.connect(_on_hover_enter)
	texture_button.mouse_exited.connect(_on_hover_exit)

func _on_hover_enter():
	# Tint it bright cyan when hovered
	texture_button.modulate = Color(0.2, 0.85, 1.0, 1.0)

func _on_hover_exit():
	# Return to normal colors
	texture_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_texture_button_pressed():
	# Play a UI click sound
	if SoundManager:
		SoundManager.play_sfx("ui_click", 1.5)
		
	print("The insurance form was clicked on!")
	emit_signal("form_button_pressed")
