# NotificationManager.gd
extends CanvasLayer

const NOTIFICATION_SCENE = preload("res://Notification.tscn")

@onready var notification_container = $NotificationContainer
var active_notification: Node = null

func _ready():
	GameManager.notification_requested.connect(add_notification)

func add_notification(message: String):
	# Play the sound effect as soon as a notification is requested.
	SoundManager.play_sfx("notification_ping")

	# Check if we already have a notification on screen
	if is_instance_valid(active_notification):
		# Tell the active one to bump and change text
		active_notification.update_message(message)
		return

	# If no active notification exists, create a new one
	active_notification = NOTIFICATION_SCENE.instantiate()
	notification_container.add_child(active_notification)
	active_notification.show_message(message)
