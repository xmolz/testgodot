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
	# --- FIX: Prevent hover effects during explanations ---
	if GameManager and GameManager.current_game_state == GameManager.GameState.EXPLANATION:
		return
		
	# Tint it bright cyan when hovered
	texture_button.modulate = Color(0.2, 0.85, 1.0, 1.0)

func _on_hover_exit():
	# --- FIX: Prevent hover effects during explanations ---
	if GameManager and GameManager.current_game_state == GameManager.GameState.EXPLANATION:
		return
		
	# Return to normal colors
	texture_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_texture_button_pressed():
	# --- FIX: Prevent clicking the button during explanations ---
	if GameManager and GameManager.current_game_state == GameManager.GameState.EXPLANATION:
		return
		
	# Play a UI click sound
	if SoundManager:
		SoundManager.play_sfx("ui_click", 1.5)
		
	print("The insurance form was clicked on!")
	emit_signal("form_button_pressed")
