extends VideoStreamPlayer

func _ready():
	# When the video finishes, force it to play again immediately
	finished.connect(play)
