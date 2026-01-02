# SoundManager.gd
extends Node

# --- Sound Effect Library ---
var sfx_library: Dictionary = {
	"ui_click": preload("res://ui_click.wav"),
	"notification_ping": preload("res://notification_ping.wav"),
	"dialogue_advance": preload("res://Sfx/Dialog/Dialog_sfx.wav"),
	"swish": preload("res://Sfx/Dialog/swish_effect.wav")
}

# --- Music Library & Player ---
const MAIN_THEME = preload("res://Sfx/Music/wii menu.mp3")

# A dedicated, persistent player for background music
# It starts as null. We will create it when it's first needed.
var _music_player: AudioStreamPlayer = null


# --- The NEW, SAFE Initialization Function ---
# This is a private function that ensures the music player exists.
func _initialize_music_player():
	# If the player already exists, do nothing.
	if is_instance_valid(_music_player):
		return

	# If it doesn't exist, create and configure it now.
	print_rich("[color=LawnGreen]SoundManager: Initializing music player for the first time.[/color]")
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	# --- FIX: ALLOW MUSIC TO PLAY WHILE GAME IS PAUSED ---
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	# -----------------------------------------------------

	_music_player.stream = MAIN_THEME

	# Set the loop mode for the WAV file
	var audio_stream_wav = _music_player.stream as AudioStreamWAV
	if audio_stream_wav:
		audio_stream_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD


# --- SFX Function (Unchanged) ---
func play_sfx(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0):
	if not sfx_library.has(sound_name):
		print_rich("[color=red]SoundManager Error: Tried to play non-existent SFX: '%s'[/color]" % sound_name)
		return

	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = sfx_library[sound_name]
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()
	player.finished.connect(player.queue_free)


# --- Public Music Functions (Now with Safety Checks) ---
func play_music():
	# --- ADD THIS GUARD ---
	# Before we do anything, make sure the player is ready.
	_initialize_music_player()
	# --------------------

	# Now it's safe to access the player.
	if not _music_player.playing:
		_music_player.play()

func stop_music():
	# --- ADD THIS GUARD ---
	# We even add the check here, just in case stop_music() is ever called first.
	_initialize_music_player()
	# --------------------

	# Now it's safe to access the player.
	_music_player.stop()
