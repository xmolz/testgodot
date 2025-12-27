# Notification.gd
extends PanelContainer

# Set the duration for the notification
const DURATION = 5.0 # 5 seconds

@onready var label = $Label
@onready var timer = $Timer

# This function is called by the NotificationManager to set up the notification
func show_message(text: String):
	label.text = text
	timer.wait_time = DURATION
	timer.start()

# This function is called when the Timer finishes its countdown
func _on_timer_timeout():
	# Optional: You can add a fade-out animation here using a Tween
	# For now, we will just remove the notification from the scene
	queue_free()
