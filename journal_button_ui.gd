extends CanvasLayer

signal journal_button_pressed

@onready var texture_button: TextureButton = $JournalPanel/MarginContainer/TextureButton
@onready var badge: PanelContainer = $JournalPanel/NotificationBadge
@onready var badge_label: Label = $JournalPanel/NotificationBadge/Label

var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")
var pulse_tween: Tween

func _ready():
	texture_button.pressed.connect(_on_texture_button_pressed)
	texture_button.mouse_entered.connect(_on_hover_enter)
	texture_button.mouse_exited.connect(_on_hover_exit)

	# Style the Badge
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color("#D4A017") # Dark Golden Yellow
	badge_style.corner_radius_top_left = 20
	badge_style.corner_radius_top_right = 20
	badge_style.corner_radius_bottom_left = 20
	badge_style.corner_radius_bottom_right = 20
	badge_style.border_width_left = 2
	badge_style.border_width_top = 2
	badge_style.border_width_right = 2
	badge_style.border_width_bottom = 2
	badge_style.border_color = Color.BLACK
	badge.add_theme_stylebox_override("panel", badge_style)

	badge_label.add_theme_font_override("font", custom_font)
	badge_label.add_theme_font_size_override("font_size", 24)
	badge_label.add_theme_color_override("font_color", Color.BLACK)

	# Check Flag
	if GameManager:
		badge.visible = not GameManager.get_game_flag("journal_opened_once")

	# Start pulsing if visible
	if badge.visible:
		_start_pulse_animation()

func _start_pulse_animation():
	if pulse_tween:
		pulse_tween.kill()

	# Create an infinite looping tween
	pulse_tween = create_tween().set_loops()

	# Fade down to 30% opacity, then back to 100% opacity
	pulse_tween.tween_property(badge, "modulate:a", 0.3, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(badge, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_hover_enter():
	if GameManager and GameManager.current_game_state == GameManager.GameState.EXPLANATION:
		return
	texture_button.modulate = Color(0.2, 0.85, 1.0, 1.0)

func _on_hover_exit():
	if GameManager and GameManager.current_game_state == GameManager.GameState.EXPLANATION:
		return
	texture_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_texture_button_pressed():
	if GameManager and GameManager.current_game_state == GameManager.GameState.EXPLANATION:
		return

	if SoundManager:
		SoundManager.play_sfx("ui_click")

	# Hide badge, kill tween, and save flag
	if GameManager:
		GameManager.set_game_flag("journal_opened_once", true)

	if pulse_tween:
		pulse_tween.kill()

	badge.visible = false
	badge.modulate.a = 1.0 # Reset alpha just in case

	emit_signal("journal_button_pressed")

func set_notification_enabled(is_enabled: bool):
	if not is_enabled:
		badge.visible = false
		if pulse_tween:
			pulse_tween.kill()
	else:
		if GameManager and not GameManager.get_game_flag("journal_opened_once"):
			if not badge.visible:
				badge.visible = true
				_start_pulse_animation()
