# NotificationManager.gd
extends CanvasLayer

const NOTIFICATION_SCENE = preload("res://Notification.tscn")

@onready var notification_container = $NotificationContainer

func _ready():
	GameManager.notification_requested.connect(add_notification)

func add_notification(message: String):
	# --- ADD THIS LINE ---
	# Play the sound effect as soon as a notification is requested.
	SoundManager.play_sfx("notification_ping")
	# --------------------

	# Create a new instance of our Notification scene
	var notification_instance = NOTIFICATION_SCENE.instantiate()

	# Add it to the VBoxContainer. The container will handle positioning.
	notification_container.add_child(notification_instance)

	# Set the message on the new notification instance.
	notification_instance.show_message(message)
