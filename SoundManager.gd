# SoundManager.gd
extends Node

# The sound library remains the same.
var sfx_library: Dictionary = {
	"ui_click": preload("res://ui_click.wav"),
	# --- ADD THIS LINE ---
	# Make sure this path is correct for your project!
	"notification_ping": preload("res://notification_ping.wav")
	# --------------------
}


# The rest of the script remains exactly the same...
func play_sfx(sound_name: String, pitch: float = 1.0):
	# First, check if the sound name we're asking for actually exists in our library.
	if not sfx_library.has(sound_name):
		print_rich("[color=red]SoundManager Error: Tried to play non-existent SFX: '%s'[/color]" % sound_name)
		return

	# 1. Create a brand new audio player instance in memory.
	var player = AudioStreamPlayer.new()

	# 2. Add it to the scene tree as a child of the SoundManager.
	add_child(player)

	# 3. Configure the new player.
	player.stream = sfx_library[sound_name]
	player.pitch_scale = pitch

	# 4. Play the sound.
	player.play()

	# 5. Connect to the player's "finished" signal for automatic cleanup.
	player.finished.connect(player.queue_free)
