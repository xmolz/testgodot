# attach this script to your
extends ColorRect

func _ready():
	print_rich("[color=cyan]InputBlocker ready: MouseFilter=%s, Size=%s[/color]" % [mouse_filter, size])

func _gui_input(event):
	if event is InputEventMouseButton:
		print_rich("[color=red]InputBlocker caught mouse click! This should block world input.[/color]")
		# accept the event to consume it
		accept_event()
