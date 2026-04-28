# Notification.gd
extends PanelContainer

const DURATION = 4.0 # 4 seconds feels better with the fade out

@onready var label = $Label
@onready var timer = $Timer

var _fade_tween: Tween

func _ready():
	# Set initial state for the "pop-in" animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

	# We want the scale to happen from the center of the capsule
	pivot_offset = size / 2.0

	# The Flashy Pop-in Tween
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_message(text: String):
	label.text = text
	timer.wait_time = DURATION
	timer.start()

# --- NEW: Updates the notification in-place with an attention-grabbing effect ---
func update_message(new_text: String):
	label.text = new_text
	timer.start(DURATION) # Reset the hide timer

	# Stop fading out if it was in the middle of disappearing
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	modulate.a = 1.0 # Ensure it's fully visible

	# Re-center pivot in case the new text size changed the panel's width
	pivot_offset = size / 2.0

	# Play a quick "bump" scale effect to catch the eye
	var bump_tween = create_tween()
	bump_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_SINE)
	bump_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Briefly flash the text color cyan, then fade back to white
	label.modulate = Color(0.2, 0.85, 1.0, 1.0)
	var color_tween = create_tween()
	color_tween.tween_property(label, "modulate", Color.WHITE, 0.4)

func _on_timer_timeout():
	# The Smooth Fade-out Tween
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	# Destroy the node AFTER the fade out is complete
	_fade_tween.tween_callback(queue_free)
