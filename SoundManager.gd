# SoundManager.gd
extends Node

# --- Sound Effect Library ---
var sfx_library: Dictionary = {
	# UI & Misc
	"ui_click": preload("res://ui_click.wav"),
	"notification_ping": preload("res://notification_ping.wav"),
	"dialogue_advance": preload("res://Sfx/Dialog/Dialog_sfx.wav"),
	"swish": preload("res://Sfx/Dialog/swish_effect.wav"),
	
	# Game World
	"door_close": preload("res://Sfx/Game World/scifi door close.mp3"),
	"door_open": preload("res://Sfx/Game World/scifi door open.mp3"),
	"hospital_toilet_flush": preload("res://Sfx/Game World/hospital_toilet_flush.mp3"),
	
	# Footsteps
	"step_1": preload("res://Sfx/Player/squeak_01.wav"), 
	"step_2": preload("res://Sfx/Player/squeak_02.wav"),
	"step_3": preload("res://Sfx/Player/squeak_03.wav"),

	# --- NEW: AMBIENCE ---
	# I mapped your files to logical names. 
	# CHECK THESE PATHS MATCH YOUR FOLDER STRUCTURE!
	"room_tone_air": preload("res://Sfx/Game World/ambience_spaceship.mp3"),
	"room_tone_electric": preload("res://Sfx/Game World/ambience_fluoroscent_buzz.mp3"),
	"room_tone_traffic": preload("res://Sfx/Game World/ambience_distant_highway.mp3")
}

# --- Music Library & Player ---
const MAIN_THEME = null # Disabled for now

# A dedicated, persistent player for background music
var _music_player: AudioStreamPlayer = null

# NEW: Store active ambience players so we can stop them
var _active_ambience_players: Array[AudioStreamPlayer] = []

# Variable to remember the previous footstep (for non-repeating logic)
var _last_footstep_key: String = ""


# --- Initialization ---
func _initialize_music_player():
	if is_instance_valid(_music_player):
		return

	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if MAIN_THEME:
		_music_player.stream = MAIN_THEME
		var audio_stream_wav = _music_player.stream as AudioStreamWAV
		if audio_stream_wav:
			audio_stream_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD


# --- SFX Functions ---
func play_sfx(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer:
	if not sfx_library.has(sound_name):
		print_rich("[color=red]SoundManager Error: Tried to play non-existent SFX: '%s'[/color]" % sound_name)
		return null 

	var player = AudioStreamPlayer.new()
	
	# --- FIX: Ensure SFX continues playing even when the game pauses ---
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	
	add_child(player)
	player.stream = sfx_library[sound_name]
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.bus = bus_name 
	player.play()
	
	player.finished.connect(player.queue_free)
	return player

func play_random_footstep():
	var all_steps = ["step_1", "step_2", "step_3"]
	var valid_steps = all_steps.duplicate()
	
	if _last_footstep_key != "" and _last_footstep_key in valid_steps:
		valid_steps.erase(_last_footstep_key)
	
	var chosen_step = valid_steps.pick_random()
	_last_footstep_key = chosen_step
	
	# Lighter pitch and lower volume for female protagonist
	play_sfx(chosen_step, randf_range(1.2, 1.4), -18.0, "Footsteps")


# --- NEW: Ambience Functions ---
func play_ambience(sound_name: String, volume_db: float = 0.0):
	if not sfx_library.has(sound_name):
		print("SoundManager: Ambience '%s' not found." % sound_name)
		return

	var player = AudioStreamPlayer.new()
	
	# --- FIX: Ensure Ambience continues playing even when the game pauses ---
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	
	add_child(player)
	player.stream = sfx_library[sound_name]
	player.volume_db = volume_db
	
	# Send to "Ambience" bus if you created it, otherwise "SFX"
	# I recommend creating an "Ambience" bus in the Audio tab!
	player.bus = "Ambience" 
	
	player.play()
	
	# Store reference so we can kill it later
	_active_ambience_players.append(player)

func stop_all_ambience():
	for player in _active_ambience_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_active_ambience_players.clear()


# --- Music Functions ---
func play_music():
	_initialize_music_player()
	if not _music_player.playing:
		_music_player.play()

func stop_music():
	_initialize_music_player()
	_music_player.stop()
