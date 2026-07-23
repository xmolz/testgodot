extends CanvasLayer

signal form_button_pressed

# we updated the node path
@onready var texture_button: TextureButton = $FormPanel/MarginContainer/TextureButton

func _ready():
	# ******************* universal layout (pc & mobile)
	var form_panel = $FormPanel
	var tab_panel = $FormPanel/TabPanel
	var tab_label = $FormPanel/TabPanel/Label

	form_panel.anchor_left = 0.89
	form_panel.anchor_right = 0.98

	tab_panel.anchor_left = 0.5
	tab_panel.anchor_right = 0.5
	tab_panel.offset_left = -60
	tab_panel.offset_right = 60

	if OS.has_feature("mobile"):
		form_panel.anchor_top = 0.75
		tab_panel.offset_top = -50
		tab_label.add_theme_font_size_override("font_size", 28)
	#

	texture_button.pressed.connect(_on_texture_button_pressed)
	
	# add hover effects to make it feel responsive
	texture_button.mouse_entered.connect(_on_hover_enter)
	texture_button.mouse_exited.connect(_on_hover_exit)

func _on_hover_enter():
	# --------------(fix: prevent hover effects during explanations)
	if GameManager and GameManager.current_game_state == GameManager.GameState.EXPLANATION:
		return
		
	# tint it bright cyan when hovered
	texture_button.modulate = Color(0.2, 0.85, 1.0, 1.0)

func _on_hover_exit():
	# -------------- fix: prevent hover effects during explanations
	if GameManager and GameManager.current_game_state == GameManager.GameState.EXPLANATION:
		return
		
	# return to normal color
	texture_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_texture_button_pressed():
	# ************[fix: prevent clicking the button during explanations]
	if GameManager and GameManager.current_game_state == GameManager.GameState.EXPLANATION:
		return
		
	# play a ui click sound
	if SoundManager:
		SoundManager.play_sfx("ui_click")
		
	print("The insurance form was clicked on!")
	emit_signal("form_button_pressed")
