extends VideoStreamPlayer

func _ready():
	# when the video finishes, force
	finished.connect(play)
