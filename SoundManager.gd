# SoundManager.gd
extends Node

# --- Sound Effect Library ---
var sfx_library: Dictionary = {
	# UI & Misc
	"ui_click": preload("res://ui_click.wav"),
	"start_game": preload("res://Sfx/start.wav"),
	"notification_ping": preload("res://notification_ping.wav"),
	"swish": preload("res://Sfx/Dialog/swish_effect.wav"),
	"form_correct_input": preload("res://Sfx/form_correct_input.mp3"),
	"form_incorrect_input": preload("res://Sfx/form_incorrect_input.mp3"),
	"mcbucket_scream": preload("res://Sfx/Dialog/mcbucket_scream.wav"),
	
	# Game World
	"door_close": preload("res://Sfx/Game World/scifi door close.mp3"),
	"door_open": preload("res://Sfx/Game World/scifi door open.mp3"),
	"hospital_toilet_flush": preload("res://Sfx/Game World/hospital_toilet_flush.mp3"),
	
	# Footsteps
	"step_1": preload("res://Sfx/Player/squeak_01.wav"), 
	"step_2": preload("res://Sfx/Player/squeak_02.wav"),
	"step_3": preload("res://Sfx/Player/squeak_03.wav"),

	# Ambience
	"room_tone_air": preload("res://Sfx/Game World/ambience_spaceship.mp3"),
	"room_tone_electric": preload("res://Sfx/Game World/ambience_fluoroscent_buzz.mp3"),
	"room_tone_traffic": preload("res://Sfx/Game World/ambience_distant_highway.mp3"),
	
	# Looping SFX
	"heavy_breathing": preload("res://Sfx/Dialog/heavy_breathing.mp3") # <-- Update this path to where your file actually is!
}

# --- Music Library ---
var music_library: Dictionary = {
	"aida_theme": preload("res://Sfx/Music/aida_corporate_theme.mp3"),
	"unnatural_city": preload("res://Sfx/Music/Unnatural City.ogg"),
	"sergey_sad_theme": preload("res://Sfx/Music/sergey_sad_theme.mp3"),
	"mcbucket_normal_theme": preload("res://Sfx/Music/mcbucket_regular_theme.mp3"),
	"mcbucket_cannathink_theme": preload("res://Sfx/Music/mcbucket_cannathink_theme.mp3"),
	"sergey_hj_music":preload("res://Sfx/Music/snake_city_run_boy_run.mp3")
}

# A dedicated, persistent player for background music
var _music_player: AudioStreamPlayer = null
var _music_tween: Tween = null

# --- NEW: Looping SFX Tracking ---
var _looping_sfx_players: Dictionary = {}
var _looping_sfx_tweens: Dictionary = {}


# Store active ambience players so we can stop them
var _active_ambience_players: Array[AudioStreamPlayer] = []

# Variable to remember the previous footstep (for non-repeating logic)
var _last_footstep_key: String = ""

# --- Audio Ducking Variables ---
var _ambience_bus_index: int = -1
var _base_ambience_volume: float = 0.0


# --- Initialization ---
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Capture the Ambience bus index and its default volume so we can restore it later
	_ambience_bus_index = AudioServer.get_bus_index("Ambience")
	if _ambience_bus_index != -1:
		_base_ambience_volume = AudioServer.get_bus_volume_db(_ambience_bus_index)

func _initialize_music_player():
	if is_instance_valid(_music_player):
		return

	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.bus = "Main Music"


# --- SFX Functions ---
func play_sfx(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer:
	if not sfx_library.has(sound_name):
		print_rich("[color=red]SoundManager Error: Tried to play non-existent SFX: '%s'[/color]" % sound_name)
		return null 

	var player = AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	
	player.stream = sfx_library[sound_name]

	# Globally soften the UI click (higher pitch = lighter sound, lower volume = less aggressive)
	if sound_name == "ui_click":
		if pitch == 1.0: pitch = 1.2
		if volume_db == 0.0: volume_db = -6.0

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
	
	play_sfx(chosen_step, randf_range(1.2, 1.4), -18.0, "Footsteps")


# --- Ambience Functions ---
func play_ambience(sound_name: String, volume_db: float = 0.0):
	if not sfx_library.has(sound_name):
		print("SoundManager: Ambience '%s' not found." % sound_name)
		return

	var player = AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	
	player.stream = sfx_library[sound_name]
	player.volume_db = volume_db
	player.bus = "Ambience" 
	player.play()
	
	_active_ambience_players.append(player)

func stop_all_ambience():
	for player in _active_ambience_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_active_ambience_players.clear()

# Helper function to let the Tween system change the bus volume
func set_ambience_volume(vol: float):
	if _ambience_bus_index != -1:
		AudioServer.set_bus_volume_db(_ambience_bus_index, vol)


# --- Music Functions ---

# Instantly stops the currently playing music and resets the ambience volume
func stop_music():
	fade_out_music(0.0)

# Called via dialogue: do SoundManager.play_music_track("aida_theme", 3.0)
func play_music_track(track_name: String, fade_duration: float = 1.0):
	_initialize_music_player()
	
	if not music_library.has(track_name):
		print_rich("[color=red]SoundManager: Music track '%s' not found![/color]" % track_name)
		return

	var stream = music_library[track_name]
	
	# Don't restart if it's already playing the same track
	if _music_player.stream == stream and _music_player.playing:
		return
		
	if track_name == "unnatural_city":
		_music_player.bus = "Intro Music"
	else:
		_music_player.bus = "Main Music"

	_music_player.stream = stream
	
	# Stop any current fade tweens
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
		
	var current_ambience_vol = AudioServer.get_bus_volume_db(_ambience_bus_index)
		
	if fade_duration > 0.0:
		_music_player.volume_db = -80.0
		_music_player.play()
		
		# Set parallel to true so the music fades UP while the ambience fades DOWN
		_music_tween = create_tween().set_parallel(true)
		_music_tween.tween_property(_music_player, "volume_db", -5.0, fade_duration).set_trans(Tween.TRANS_SINE)
		_music_tween.tween_method(set_ambience_volume, current_ambience_vol, _base_ambience_volume - 30.0, fade_duration).set_trans(Tween.TRANS_SINE)
	else:
		_music_player.volume_db = -5.0
		_music_player.play()
		set_ambience_volume(_base_ambience_volume - 30.0)

# Called via dialogue: do SoundManager.fade_out_music(5.0)
func fade_out_music(fade_duration: float = 2.0):
	if not is_instance_valid(_music_player) or not _music_player.playing:
		return
		
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	var current_ambience_vol = AudioServer.get_bus_volume_db(_ambience_bus_index)

	if fade_duration > 0.0:
		# Set parallel to true so the music fades DOWN while the ambience fades UP
		_music_tween = create_tween().set_parallel(true)
		_music_tween.tween_property(_music_player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE)
		_music_tween.tween_method(set_ambience_volume, current_ambience_vol, _base_ambience_volume, fade_duration).set_trans(Tween.TRANS_SINE)
		
		# Chain wait until both fades are done, then stop the player entirely
		_music_tween.chain().tween_callback(_music_player.stop)
	else:
		_music_player.stop()
		set_ambience_volume(_base_ambience_volume)

# --- Looping SFX Functions ---

# Called via dialogue: do SoundManager.play_looping_sfx("heavy_breathing", 2.0, 0.0)
func play_looping_sfx(sound_name: String, fade_duration: float = 1.0, target_volume_db: float = 0.0):
	if not sfx_library.has(sound_name):
		print_rich("[color=red]SoundManager: Looping SFX '%s' not found![/color]" % sound_name)
		return

	var player: AudioStreamPlayer
	
	# Check if it's already playing
	if _looping_sfx_players.has(sound_name) and is_instance_valid(_looping_sfx_players[sound_name]):
		player = _looping_sfx_players[sound_name]
		if player.playing: return # Already playing, do nothing
	else:
		# Create a new persistent player for this sound
		player = AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.bus = "looping sfx" # Ensure you create this bus in the Audio tab!
		add_child(player)
		player.stream = sfx_library[sound_name]
		_looping_sfx_players[sound_name] = player

	# Kill any existing fade tweens for this specific sound
	if _looping_sfx_tweens.has(sound_name) and _looping_sfx_tweens[sound_name].is_valid():
		_looping_sfx_tweens[sound_name].kill()

	var current_ambience_vol = AudioServer.get_bus_volume_db(_ambience_bus_index)

	# Start the fade in
	if fade_duration > 0.0:
		player.volume_db = -80.0
		player.play()
		
		# Set parallel to true so breathing fades UP while ambience fades DOWN
		var tween = create_tween().set_parallel(true)
		tween.tween_property(player, "volume_db", target_volume_db, fade_duration).set_trans(Tween.TRANS_SINE)
		tween.tween_method(set_ambience_volume, current_ambience_vol, _base_ambience_volume - 30.0, fade_duration).set_trans(Tween.TRANS_SINE)
		_looping_sfx_tweens[sound_name] = tween
	else:
		player.volume_db = target_volume_db
		player.play()
		set_ambience_volume(_base_ambience_volume - 30.0)

# Called via dialogue: do SoundManager.stop_looping_sfx("heavy_breathing", 3.0)
func stop_looping_sfx(sound_name: String, fade_duration: float = 1.0):
	if not _looping_sfx_players.has(sound_name) or not is_instance_valid(_looping_sfx_players[sound_name]):
		return

	var player = _looping_sfx_players[sound_name]

	if _looping_sfx_tweens.has(sound_name) and _looping_sfx_tweens[sound_name].is_valid():
		_looping_sfx_tweens[sound_name].kill()

	var current_ambience_vol = AudioServer.get_bus_volume_db(_ambience_bus_index)

	# Start the fade out
	if fade_duration > 0.0:
		# Set parallel to true so breathing fades DOWN while ambience fades UP
		var tween = create_tween().set_parallel(true)
		tween.tween_property(player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE)
		tween.tween_method(set_ambience_volume, current_ambience_vol, _base_ambience_volume, fade_duration).set_trans(Tween.TRANS_SINE)
		
		# Clean up after fade finishes
		tween.chain().tween_callback(func(): _cleanup_looping_sfx(sound_name))
		_looping_sfx_tweens[sound_name] = tween
	else:
		_cleanup_looping_sfx(sound_name)
		set_ambience_volume(_base_ambience_volume)

# Internal helper to safely delete the audio player when it's done
func _cleanup_looping_sfx(sound_name: String):
	if _looping_sfx_players.has(sound_name):
		var player = _looping_sfx_players[sound_name]
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
		_looping_sfx_players.erase(sound_name)
		_looping_sfx_tweens.erase(sound_name)
