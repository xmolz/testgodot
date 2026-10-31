# notificationmanager.gd
extends CanvasLayer

const NOTIFICATION_SCENE = preload("res://ui/Notification.tscn")

@onready var notification_container = $NotificationContainer
var active_notification: Node = null

func _ready():
	Events.notification_requested.connect(add_notification)
	# step 2.250: notifications are display-only; let hover and clicks reach what's underneath.
	notification_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	_ignore_mouse(active_notification)
	notification_container.add_child(active_notification)
	active_notification.show_message(message)


# step 2.250: sets a node and every Control under it to ignore the mouse.
func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
