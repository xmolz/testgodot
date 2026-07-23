# -------------[soundmanager.gd]
extends Node

# ---------------[sound effect library]
var sfx_library: Dictionary = {
	# ui & misc
	"ui_click": preload("res://Sfx/Game World/ui_click.wav"),
	"start_game": preload("res://Sfx/start.wav"),
	"notification_ping": preload("res://Sfx/Game World/notification_ping.wav"),
	"item_remove": preload("res://Sfx/Game World/item_remove.wav"),
	"swish": preload("res://Sfx/Dialog/swish_effect.wav"),
	"form_correct_input": preload("res://Sfx/form_correct_input.mp3"),
	"form_incorrect_input": preload("res://Sfx/form_incorrect_input.mp3"),
	"mcbucket_scream": preload("res://Sfx/Dialog/mcbucket_scream.wav"),
	
	# game world
	"door_close": preload("res://Sfx/Game World/scifi door close.mp3"),
	"door_open": preload("res://Sfx/Game World/scifi door open.mp3"),
	"hospital_toilet_flush": preload("res://Sfx/Game World/hospital_toilet_flush.mp3"),
	
	# footsteps
	"step_1": preload("res://Sfx/Player/squeak_01.wav"), 
	"step_2": preload("res://Sfx/Player/squeak_02.wav"),
	"step_3": preload("res://Sfx/Player/squeak_03.wav"),

	# ambience
	"room_tone_air": preload("res://Sfx/Game World/ambience_spaceship.mp3"),
	"room_tone_electric": preload("res://Sfx/Game World/ambience_fluoroscent_buzz.mp3"),
	"room_tone_traffic": preload("res://Sfx/Game World/ambience_distant_highway.mp3"),
	
	# ---------------------[looping sfx]
	"heavy_breathing": preload("res://Sfx/Dialog/heavy_breathing.mp3"),
	"scan_effect": preload("res://Sfx/Dialog/scan_effect.mp3")
}

# ------------[sounds that must remain audible while the game is paused (ui / meta sounds).]
const UNPAUSABLE_SFX: Array[String] = [
	"ui_click",
	"start_game",
	"notification_ping",
	"item_remove",
	"swish",
	"form_correct_input",
	"form_incorrect_input",
]

# ------------------[music library]
var music_library: Dictionary = {
	"aida_theme": preload("res://Sfx/Music/aida_corporate_theme.ogg"),
	"sergey_sad_theme": preload("res://Sfx/Music/sergey_sad_theme.ogg"),
	"mcbucket_normal_theme": preload("res://Sfx/Music/mcbucket_regular_theme.ogg"),
	"mcbucket_cannathink_theme": preload("res://Sfx/Music/mcbucket_cannathink_theme.ogg"),
	"sergey_hj_music":preload("res://Sfx/Music/flip_that.ogg"),
	"cicadas":preload("res://Sfx/Music/cicadas.ogg"),
	"that_soft_touch":preload("res://Sfx/Music/that soft touch.ogg")
}

# persistent bgm player
var _music_player: AudioStreamPlayer = null
var _music_tween: Tween = null

# -------------[looping sfx tracking]
var _looping_sfx_players: Dictionary = {}
var _looping_sfx_tweens: Dictionary = {}


# active ambience players
var _active_ambience_players: Array[AudioStreamPlayer] = []

# last footstep tracking
var _last_footstep_key: String = ""

# ---------------[audio ducking variables]
var _ambience_bus_index: int = -1
var _base_ambience_volume: float = 0.0

# -------------------[mobile-only loudness boost applied to the master bus. settings.gd reads this]
# to compensate, so user-facing volume
var mobile_master_boost: float = 0.0


# -------------[initialization]
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# ----------[mobile audio enhancement]
	# run before base volume capture
	# prevent volume restore issues
	# preserve mobile boost
	if OS.has_feature("mobile"):
		mobile_master_boost = 4.0
		var master_bus_idx = AudioServer.get_bus_index("Master")
		if master_bus_idx != -1:
			var current_vol = AudioServer.get_bus_volume_db(master_bus_idx)
			AudioServer.set_bus_volume_db(master_bus_idx, current_vol + mobile_master_boost)

			var compressor = AudioEffectCompressor.new()
			compressor.threshold = -15.0
			compressor.ratio = 3.0
			compressor.release_ms = 250.0
			AudioServer.add_bus_effect(master_bus_idx, compressor)

		# boost low frequencies for mobile
		# additional mobile headroom
		for quiet_bus_name in ["Footsteps", "Ambience", "looping sfx"]:
			var quiet_idx = AudioServer.get_bus_index(quiet_bus_name)
			if quiet_idx != -1:
				AudioServer.set_bus_volume_db(quiet_idx, AudioServer.get_bus_volume_db(quiet_idx) + 3.0)

	# capture the ambience bus index
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


# --------------[sfx functions]
func play_sfx(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer:
	if not sfx_library.has(sound_name):
		print_rich("[color=red]SoundManager Error: Tried to play non-existent SFX: '%s'[/color]" % sound_name)
		return null 

	var player = AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS if sound_name in UNPAUSABLE_SFX else Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	
	player.stream = sfx_library[sound_name]

	# globally soften the ui click
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


# --------------[ambience functions]
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

# helper function to let the
func set_ambience_volume(vol: float):
	if _ambience_bus_index != -1:
		AudioServer.set_bus_volume_db(_ambience_bus_index, vol)


# ----------------------[music functions]

# instantly stops the currently playing
func stop_music():
	fade_out_music(0.0)

# ----------[called via dialogue: do soundmanager.play_music_track("aida_theme", 3.0)]
func play_music_track(track_name: String, fade_duration: float = 1.0):
	_initialize_music_player()
	
	if not music_library.has(track_name):
		print_rich("[color=red]SoundManager: Music track '%s' not found![/color]" % track_name)
		return

	var stream = music_library[track_name]
	
	# don't restart if it's already playing the same track
	if _music_player.stream == stream and _music_player.playing:
		return
		
	if track_name == "unnatural_city":
		_music_player.bus = "Intro Music"
	else:
		_music_player.bus = "Main Music"

	_music_player.stream = stream
	
	# stop any current fade tweens
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
		
	var current_ambience_vol = AudioServer.get_bus_volume_db(_ambience_bus_index)
		
	if fade_duration > 0.0:
		_music_player.volume_db = -80.0
		_music_player.play()
		
		# set parallel to true so
		_music_tween = create_tween().set_parallel(true)
		_music_tween.tween_property(_music_player, "volume_db", -5.0, fade_duration).set_trans(Tween.TRANS_SINE)
		_music_tween.tween_method(set_ambience_volume, current_ambience_vol, _base_ambience_volume - 30.0, fade_duration).set_trans(Tween.TRANS_SINE)
	else:
		_music_player.volume_db = -5.0
		_music_player.play()
		set_ambience_volume(_base_ambience_volume - 30.0)

# --------------[called via dialogue: do soundmanager.fade_out_music(5.0)]
func fade_out_music(fade_duration: float = 2.0):
	if not is_instance_valid(_music_player) or not _music_player.playing:
		return
		
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	var current_ambience_vol = AudioServer.get_bus_volume_db(_ambience_bus_index)

	if fade_duration > 0.0:
		# set parallel to true so
		_music_tween = create_tween().set_parallel(true)
		_music_tween.tween_property(_music_player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE)
		_music_tween.tween_method(set_ambience_volume, current_ambience_vol, _base_ambience_volume, fade_duration).set_trans(Tween.TRANS_SINE)
		
		# chain wait until both fades
		_music_tween.chain().tween_callback(_music_player.stop)
	else:
		_music_player.stop()
		set_ambience_volume(_base_ambience_volume)

# ---------------------[looping sfx functions]

# ------------[called via dialogue: do soundmanager.play_looping_sfx("heavy_breathing", 2.0, 0.0)]
func play_looping_sfx(sound_name: String, fade_duration: float = 1.0, target_volume_db: float = 0.0):
	if not sfx_library.has(sound_name):
		print_rich("[color=red]SoundManager: Looping SFX '%s' not found![/color]" % sound_name)
		return

	var player: AudioStreamPlayer
	
	# check if it's already playing
	if _looping_sfx_players.has(sound_name) and is_instance_valid(_looping_sfx_players[sound_name]):
		player = _looping_sfx_players[sound_name]
		if player.playing: return
	else:
		# create a persistent player for this sound
		player = AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		player.bus = "looping sfx"
		add_child(player)
		player.stream = sfx_library[sound_name]
		_looping_sfx_players[sound_name] = player

	# kill any existing fade tweens for this specific sound
	if _looping_sfx_tweens.has(sound_name) and _looping_sfx_tweens[sound_name].is_valid():
		_looping_sfx_tweens[sound_name].kill()

	var current_ambience_vol = AudioServer.get_bus_volume_db(_ambience_bus_index)

	# start the fade in
	if fade_duration > 0.0:
		player.volume_db = -80.0
		player.play()
		
		# set parallel to true so
		var tween = create_tween().set_parallel(true)
		tween.tween_property(player, "volume_db", target_volume_db, fade_duration).set_trans(Tween.TRANS_SINE)
		tween.tween_method(set_ambience_volume, current_ambience_vol, _base_ambience_volume - 30.0, fade_duration).set_trans(Tween.TRANS_SINE)
		_looping_sfx_tweens[sound_name] = tween
	else:
		player.volume_db = target_volume_db
		player.play()
		set_ambience_volume(_base_ambience_volume - 30.0)

# ----------[called via dialogue: do soundmanager.stop_looping_sfx("heavy_breathing", 3.0)]
func stop_looping_sfx(sound_name: String, fade_duration: float = 1.0):
	if not _looping_sfx_players.has(sound_name) or not is_instance_valid(_looping_sfx_players[sound_name]):
		return

	var player = _looping_sfx_players[sound_name]

	if _looping_sfx_tweens.has(sound_name) and _looping_sfx_tweens[sound_name].is_valid():
		_looping_sfx_tweens[sound_name].kill()

	var current_ambience_vol = AudioServer.get_bus_volume_db(_ambience_bus_index)

	# start the fade out
	if fade_duration > 0.0:
		# set parallel to true so
		var tween = create_tween().set_parallel(true)
		tween.tween_property(player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE)
		tween.tween_method(set_ambience_volume, current_ambience_vol, _base_ambience_volume, fade_duration).set_trans(Tween.TRANS_SINE)
		
		# clean up after fade finishes
		tween.chain().tween_callback(func(): _cleanup_looping_sfx(sound_name))
		_looping_sfx_tweens[sound_name] = tween
	else:
		_cleanup_looping_sfx(sound_name)
		set_ambience_volume(_base_ambience_volume)

# internal helper to safely delete
func _cleanup_looping_sfx(sound_name: String):
	if _looping_sfx_players.has(sound_name):
		var player = _looping_sfx_players[sound_name]
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
		_looping_sfx_players.erase(sound_name)
		_looping_sfx_tweens.erase(sound_name)

func stop_all_audio():
	stop_music()
	stop_all_ambience()
	for sound_name in _looping_sfx_players.keys():
		var player = _looping_sfx_players[sound_name]
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_looping_sfx_players.clear()
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	for tween in _looping_sfx_tweens.values():
		if tween and tween.is_valid():
			tween.kill()
	_looping_sfx_tweens.clear()
	set_ambience_volume(_base_ambience_volume)
