# notificationmanager.gd
extends CanvasLayer

const NOTIFICATION_SCENE = preload("res://ui/Notification.tscn")

@onready var notification_container = $NotificationContainer
var active_notification: Node = null

func _ready():
	Events.notification_requested.connect(add_notification)

func add_notification(message: String):
	if SaveManager and SaveManager.is_loading:
		return

	# play the sound effect as
	SoundManager.play_sfx("notification_ping")

	# check if we already have a notification on screen
	if is_instance_valid(active_notification):
		# tell the active one to bump and change text
		active_notification.update_message(message)
		return

	# if no active notification exists, create a one
	active_notification = NOTIFICATION_SCENE.instantiate()
	notification_container.add_child(active_notification)
	active_notification.show_message(message)
