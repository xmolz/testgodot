# Notification.gd
extends PanelContainer

const DURATION = 4.0 # 4 seconds feels better with the fade out

@onready var label = $Label
@onready var timer = $Timer

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

func _on_timer_timeout():
	# The Smooth Fade-out Tween
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	# Destroy the node AFTER the fade out is complete
	tween.tween_callback(queue_free)
