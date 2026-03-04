extends CanvasLayer

signal journal_button_pressed

@onready var texture_button: TextureButton = $JournalPanel/MarginContainer/TextureButton

func _ready():
	texture_button.pressed.connect(_on_texture_button_pressed)
	
	# Add hover effects
	texture_button.mouse_entered.connect(_on_hover_enter)
	texture_button.mouse_exited.connect(_on_hover_exit)

func _on_hover_enter():
	texture_button.modulate = Color(0.2, 0.85, 1.0, 1.0) # Flashy Cyan

func _on_hover_exit():
	texture_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_texture_button_pressed():
	if SoundManager:
		SoundManager.play_sfx("ui_click", 1.5)
		
	print_rich("[color=cyan]The Journal button was pressed![/color]")
	emit_signal("journal_button_pressed")
