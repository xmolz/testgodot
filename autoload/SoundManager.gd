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
	"elevator_hum": preload("res://Sfx/Game World/elevator_hum.wav"),
	"fiona_phone_ringtone": preload("res://Sfx/fiona_phone_ringtone.wav"),
	"door_unlock": preload("res://Sfx/door_unlock.wav"),
	"door_slam": preload("res://Sfx/door_slam.wav"),
	"squeaky_toy": preload("res://Sfx/squeaky_toy.wav"),
	# step 2.382: the university's swing doors (SwingDoorTeleportAction asks for this name) and layla's scream
	"wood_door_open": preload("res://Sfx/university_door_open.wav"),
	"layla_scream": preload("res://Sfx/layla_scream.wav"),
	# step 2.392: the car ride's road thump (levels/car/car_ride_home.gd car_bump)
	"road_thump": preload("res://Sfx/road_thump.wav"),
	
	# step 2.393: the supply-room locker (the rusty pick snaps / the steel pick opens it) and the lab keypads
	# (a wrong code / the right code)
	"pencil_snap": preload("res://Sfx/pencil_snap.wav"),
	"door_open_success": preload("res://Sfx/door_open_success.wav"),
	"incorrect_beep": preload("res://Sfx/incorrect_beep.wav"),

	# step 2.396: a record winding down, for music that stops dead (Fiona bringing out Jayce's camera)
	"vinyl_stop": preload("res://Sfx/vinyl_stop.wav"),
	# step 2.410: Layla Runs Away (looping, via play_looping_sfx): her heartbeat through the pose, and the shower
	"thudding_heartbeat": preload("res://Sfx/thudding_heartbeat.ogg"),
	"shower_loop": preload("res://Sfx/shower_loop.ogg"),
	# step 2.415: a single hop (Layla's jumps and bounces, now and then), and a wolf whistle (Jayce)
	"jump_sound_effect": preload("res://Sfx/jump_sound_effect.ogg"),
	"whistle": preload("res://Sfx/whistle.ogg"),

	# step 2.397: the memory box's portal (going in, its hum, coming out) and the vending machine dropping a snack
	"portal_going_in": preload("res://Sfx/portal_going_in.wav"),
	"portal_hum": preload("res://Sfx/energy_hum_portal.wav"),
	"portal_coming_out": preload("res://Sfx/portal_coming_out.wav"),
	"vending_machine": preload("res://Sfx/vending_machine.wav"),

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
	"fiona_phone_ringtone",
	"ui_click",
	"start_game",
	"notification_ping",
	"item_remove",
	"swish",
	"form_correct_input",
	"form_incorrect_input",
	# step 2.397: the portal plays over the memory box and through scene changes
	"portal_going_in",
	"portal_coming_out",
]

# ------------[muffled sfx bus (runtime-created in _ready)]
const MUFFLED_BUS_NAME := "Muffled SFX"
const MUFFLED_CUTOFF_HZ := 800.0

# ------------[muffled ambience bus (runtime-created in _ready)]
# step 2.380: a low-passed bus for ambience heard through walls and windows (the university's
# city-outside layer). it sends into Ambience, so the ambience volume setting and ducking still apply.
const MUFFLED_AMBIENCE_BUS_NAME := "Muffled Ambience"
const MUFFLED_AMBIENCE_DEFAULT_CUTOFF_HZ := 1000.0

# step 2.380: long level ambience, loaded on first use (then cached in sfx_library) instead of
# preloaded at boot with everything else.
const LEVEL_AMBIENCE_PATHS: Dictionary = {
	"uni_empty_room": "res://Sfx/empty_room_ambience_university.wav",
	"uni_city_outside": "res://Sfx/city_outside_morning.wav",
	# step 2.406: the skating rink next door (heard muffled, through the walls)
	"uni_skating_rink": "res://Sfx/skating_rink_ambience.ogg",
}

# step 2.380: true while a level plays its own ambience; play_hub_ambience() stays quiet then.
var level_ambience_active: bool = false

# ------------------[music library]
var music_library: Dictionary = {
	"aida_theme": preload("res://Sfx/Music/aida_corporate_theme.ogg"),
	"sergey_sad_theme": preload("res://Sfx/Music/sergey_sad_theme.ogg"),
	"mcbucket_normal_theme": preload("res://Sfx/Music/mcbucket_regular_theme.ogg"),
	"mcbucket_cannathink_theme": preload("res://Sfx/Music/mcbucket_cannathink_theme.ogg"),
	"sergey_hj_music":preload("res://Sfx/Music/flip_that.ogg"),
	"cicadas":preload("res://Sfx/Music/cicadas.ogg"),
	"that_soft_touch":preload("res://Sfx/Music/that soft touch.ogg"),
	# step 2.392: the chapter-opening dream (from the launch swirl to the cut to black), and waking up to
	# layla (until the first conversation with her ends)
	"haunted_techno": preload("res://Sfx/Music/haunted_techno.ogg"),
	"woken_up_to_layla": preload("res://Sfx/Music/woken_up_to_layla_music.ogg"),
	# step 2.396: Julian's intro CG (julian_intro.dialogue), and the two conversation themes (julian_talk.dialogue,
	# guard_lab.dialogue), each for as long as he's in the conversation
	"julian_intro_theme": preload("res://Sfx/Music/julian_intro_theme.ogg"),
	"julian_hub_theme": preload("res://Sfx/Music/julian_hub_theme.ogg"),
	"jayce_hub_theme": preload("res://Sfx/Music/jayce_hub_theme.ogg"),
	# step 2.405: talking to Layla in the chapter (layla_chapter_1.dialogue ~ companion_hub), and the ride
	#home (car_ride_home.dialogue, from the car fading in to the end)
	"layla_hub_theme": preload("res://Sfx/Music/layla_hub_theme.ogg"),
	"car_ride_back": preload("res://Sfx/Music/car_ride_back_music.ogg"),
	# step 2.410: the apartment in Layla Runs Away, until the pose
	"mischief_music": preload("res://Sfx/Music/mischief_music.ogg"),
}

# step 2.392: a track's volume in dB on the music player (Main Music bus). tracks not listed play at -5.
# raise or lower a number here to balance a track against the others.
const MUSIC_TRACK_VOLUME_DB: Dictionary = {
	"haunted_techno": -5.0,
	"woken_up_to_layla": -5.0,
	"julian_intro_theme": -5.0,
	"julian_hub_theme": -5.0,
	"jayce_hub_theme": -5.0,
	"layla_hub_theme": -5.0,
	"car_ride_back": -5.0,
	"mischief_music": -5.0,
}

# step 2.405: how far a track ducks the ambience bus (dB). tracks not listed duck it by 30, almost to silence;
# the car ride's music only dips the road a little, so the freeway stays under it.
const MUSIC_TRACK_DUCK_DB: Dictionary = {
	"car_ride_back": -8.0,
}

# step 2.392: true after cut_music(): the music stopped dead but the ambience stays ducked, so the silence
# after the cut stays silent. the next play_music_track(), fade_out_music() or stop_music() clears it.
var _ambience_held_after_cut: bool = false

# step 2.396: true while fade_out_music() is fading a track down. asking for that same track again then
# brings it back up where it is (e.g. the player opens the same conversation again within the fade),
# instead of being ignored as "already playing" and fading away anyway.
var _music_fading_out: bool = false

# persistent bgm player
var _music_player: AudioStreamPlayer = null
var _music_tween: Tween = null

# step 2.397: the memory box portal's hum (a loop, on the "looping sfx" bus). TransitionLayer starts it as the
# portal grows and fades it as the portal lets go. a launch monologue can fade it sooner, e.g. when the
# chapter's own music takes over the swirl:   do SoundManager.fade_out_portal_hum(3.0)
# its level in dB (balance it against the two whooshes and the music here)
const PORTAL_HUM_DB := 0.0
var _portal_hum: AudioStreamPlayer
var _portal_hum_tween: Tween

# -------------[looping sfx tracking]
var _looping_sfx_players: Dictionary = {}
var _looping_sfx_tweens: Dictionary = {}


# active ambience players
var _active_ambience_players: Array[AudioStreamPlayer] = []
var _ambience_snapshot: Array[Dictionary] = []
var _ambience_tweens: Dictionary = {}

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

	# ----------[muffled sfx bus]
	# Runtime-created so no bus-layout resource edit is needed. Low-pass
	# filtered for "heard through machinery/walls" sounds (first user: the
	# elevator journey hum). Sends into SFX so it inherits SFX volume.
	if AudioServer.get_bus_index(MUFFLED_BUS_NAME) == -1:
		AudioServer.add_bus()
		var muffled_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(muffled_idx, MUFFLED_BUS_NAME)
		AudioServer.set_bus_send(muffled_idx, "SFX")
		var lowpass := AudioEffectLowPassFilter.new()
		lowpass.cutoff_hz = MUFFLED_CUTOFF_HZ
		AudioServer.add_bus_effect(muffled_idx, lowpass)

	# step 2.380: the muffled ambience bus, same pattern as the muffled sfx bus above
	if AudioServer.get_bus_index(MUFFLED_AMBIENCE_BUS_NAME) == -1:
		AudioServer.add_bus()
		var muffled_amb_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(muffled_amb_idx, MUFFLED_AMBIENCE_BUS_NAME)
		AudioServer.set_bus_send(muffled_amb_idx, "Ambience")
		var amb_lowpass := AudioEffectLowPassFilter.new()
		amb_lowpass.cutoff_hz = MUFFLED_AMBIENCE_DEFAULT_CUTOFF_HZ
		AudioServer.add_bus_effect(muffled_amb_idx, amb_lowpass)

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


## step 2.339: plays a one-shot sfx and waits for it to finish, so a dialogue beat can follow the sound -
## e.g. a door unlocking before someone walks in. from dialogue:
##   do SoundManager.play_sfx_and_wait("door_unlock")
## waits for the sound's length (adjusted for pitch), so it never hangs, even on a looping file.
func play_sfx_and_wait(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0, bus_name: String = "SFX") -> void:
	var player: AudioStreamPlayer = play_sfx(sound_name, pitch, volume_db, bus_name)
	if player == null or player.stream == null:
		return
	var seconds: float = player.stream.get_length() / maxf(pitch, 0.01)
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout


## step 2.284: stops every one-shot of this sfx that is still playing (e.g. a ringtone once the call is
## picked up). from dialogue: do SoundManager.stop_sfx("fiona_phone_ringtone")
func stop_sfx(sound_name: String) -> void:
	if not sfx_library.has(sound_name):
		return
	var stream = sfx_library[sound_name]
	for child in get_children():
		if child is AudioStreamPlayer and child.stream == stream:
			child.stop()
			child.queue_free()


func play_random_footstep():
	var all_steps = ["step_1", "step_2", "step_3"]
	var valid_steps = all_steps.duplicate()
	
	if _last_footstep_key != "" and _last_footstep_key in valid_steps:
		valid_steps.erase(_last_footstep_key)
	
	var chosen_step = valid_steps.pick_random()
	_last_footstep_key = chosen_step
	
	play_sfx(chosen_step, randf_range(1.2, 1.4), -18.0, "Footsteps")


# --------------[ambience functions]
# step 2.380: bus_name picks the bus (default Ambience); fade_in_seconds fades the layer in from silence.
# names in LEVEL_AMBIENCE_PATHS load on first use.
func play_ambience(sound_name: String, volume_db: float = 0.0, bus_name: String = "Ambience", fade_in_seconds: float = 0.0):
	if not sfx_library.has(sound_name) and LEVEL_AMBIENCE_PATHS.has(sound_name):
		var level_stream = load(LEVEL_AMBIENCE_PATHS[sound_name])
		# step 2.406: level ambience always loops (an .ogg's own Loop box is easy to miss)
		if level_stream is AudioStreamOggVorbis or level_stream is AudioStreamMP3:
			level_stream.loop = true
		if level_stream:
			sfx_library[sound_name] = level_stream
	if not sfx_library.has(sound_name):
		print("SoundManager: Ambience '%s' not found." % sound_name)
		return

	var player = AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)

	player.stream = sfx_library[sound_name]
	player.volume_db = -80.0 if fade_in_seconds > 0.0 else volume_db
	player.bus = bus_name
	player.play()

	player.set_meta("sound_name", sound_name)
	player.set_meta("base_volume_db", volume_db)
	player.set_meta("bus_name", bus_name)

	_active_ambience_players.append(player)

	if fade_in_seconds > 0.0:
		var tween = create_tween().bind_node(player)
		_ambience_tweens[player] = tween
		tween.tween_property(player, "volume_db", volume_db, fade_in_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var p = player
		tween.chain().tween_callback(func():
			_ambience_tweens.erase(p)
		)

func stop_all_ambience():
	_ambience_snapshot.clear()
	for tween in _ambience_tweens.values():
		if tween and tween.is_valid():
			tween.kill()
	# step 2.380: a player still fading out has already left the active list; with its fade killed
	# it would keep playing, so stop it here too
	for faded in _ambience_tweens.keys():
		if is_instance_valid(faded) and not _active_ambience_players.has(faded):
			faded.stop()
			faded.queue_free()
	_ambience_tweens.clear()

	for player in _active_ambience_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_active_ambience_players.clear()

func fade_out_all_ambience(fade_duration: float = 1.0) -> void:
	_ambience_snapshot.clear()
	for player in _active_ambience_players:
		if is_instance_valid(player) and player.playing:
			var s_name = player.get_meta("sound_name", "")
			var base_vol = player.get_meta("base_volume_db", 0.0)
			if not s_name.is_empty():
				_ambience_snapshot.append({
					"sound_name": s_name,
					"base_volume_db": base_vol,
					"bus_name": player.get_meta("bus_name", "Ambience"),   # step 2.380
				})

	for tween in _ambience_tweens.values():
		if tween and tween.is_valid():
			tween.kill()
	_ambience_tweens.clear()

	if fade_duration <= 0.0:
		stop_all_ambience()
		return

	var players_to_fade = _active_ambience_players.duplicate()
	_active_ambience_players.clear()

	for player in players_to_fade:
		if is_instance_valid(player):
			var tween = create_tween().bind_node(player)
			_ambience_tweens[player] = tween
			tween.tween_property(player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			var p = player
			tween.chain().tween_callback(func():
				if is_instance_valid(p):
					p.stop()
					p.queue_free()
				_ambience_tweens.erase(p)
			)

func resume_ambience(fade_duration: float = 1.0) -> void:
	for tween in _ambience_tweens.values():
		if tween and tween.is_valid():
			tween.kill()
	_ambience_tweens.clear()

	for entry in _ambience_snapshot:
		var sound_name = entry["sound_name"]
		var base_vol = entry["base_volume_db"]

		var already_playing = false
		for player in _active_ambience_players:
			if is_instance_valid(player) and player.get_meta("sound_name", "") == sound_name:
				already_playing = true
				break
		if already_playing:
			continue

		play_ambience(sound_name, -80.0, entry.get("bus_name", "Ambience"))   # step 2.380: its own bus
		var player = _active_ambience_players[-1]
		player.set_meta("sound_name", sound_name)
		player.set_meta("base_volume_db", base_vol)

		if fade_duration <= 0.0:
			player.volume_db = base_vol
		else:
			var tween = create_tween().bind_node(player)
			_ambience_tweens[player] = tween
			tween.tween_property(player, "volume_db", base_vol, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			var p = player
			tween.chain().tween_callback(func():
				_ambience_tweens.erase(p)
			)
	_ambience_snapshot.clear()

# step 2.380: the hub's room tone (GameManager starts it). stays off while a level plays its own.
func play_hub_ambience() -> void:
	if level_ambience_active:
		return
	play_ambience("room_tone_air", -5.0)
	play_ambience("room_tone_electric", -15.0)

# step 2.380: how muffled the Muffled Ambience bus is (a lower cutoff is more muffled).
func set_muffled_ambience_cutoff(cutoff_hz: float) -> void:
	var idx := AudioServer.get_bus_index(MUFFLED_AMBIENCE_BUS_NAME)
	if idx == -1:
		return
	for i in AudioServer.get_bus_effect_count(idx):
		var fx = AudioServer.get_bus_effect(idx, i)
		if fx is AudioEffectLowPassFilter:
			fx.cutoff_hz = cutoff_hz

# step 2.381: set a playing ambience layer's volume (and the volume it resumes at), cutting short any fade.
func set_ambience_layer_volume(sound_name: String, volume_db: float) -> void:
	for player in _active_ambience_players:
		if is_instance_valid(player) and player.get_meta("sound_name", "") == sound_name:
			var fade = _ambience_tweens.get(player)
			if fade and fade.is_valid():
				fade.kill()
			_ambience_tweens.erase(player)
			player.volume_db = volume_db
			player.set_meta("base_volume_db", volume_db)

func clear_ambience_snapshot() -> void:
	_ambience_snapshot.clear()

# helper function to let the
func set_ambience_volume(vol: float):
	if _ambience_bus_index != -1:
		AudioServer.set_bus_volume_db(_ambience_bus_index, vol)


# ----------------------[music functions]

# instantly stops the currently playing
func stop_music():
	fade_out_music(0.0)

## step 2.392: stops the music dead, with no fade, and keeps the ambience ducked: a hard cut into silence.
## the chapter-opening dream ends this way, just before layla's music starts. the next play_music_track()
## keeps the ambience ducked; fade_out_music() or stop_music() brings it back.
## from dialogue: do SoundManager.cut_music()
func cut_music() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_fading_out = false
	if is_instance_valid(_music_player) and _music_player.playing:
		_music_player.stop()
		_ambience_held_after_cut = true

# ----------[called via dialogue: do soundmanager.play_music_track("aida_theme", 3.0)]
func play_music_track(track_name: String, fade_duration: float = 1.0):
	_initialize_music_player()
	
	if not music_library.has(track_name):
		print_rich("[color=red]SoundManager: Music track '%s' not found![/color]" % track_name)
		return

	var stream = music_library[track_name]
	
	# don't restart if it's already playing the same track. step 2.396: unless it's fading out - then it
	# comes back up from where it is, without starting over.
	var resuming: bool = _music_player.stream == stream and _music_player.playing and _music_fading_out
	if _music_player.stream == stream and _music_player.playing and not resuming:
		return
		
	if track_name == "unnatural_city":
		_music_player.bus = "Intro Music"
	else:
		_music_player.bus = "Main Music"

	# step 2.396: setting the stream again would stop a track that's coming back up from a fade
	if not resuming:
		_music_player.stream = stream
	# step 2.392: the track's own volume (MUSIC_TRACK_VOLUME_DB), and a new track takes over the ducking
	var target_db: float = MUSIC_TRACK_VOLUME_DB.get(track_name, -5.0)
	var duck_db: float = MUSIC_TRACK_DUCK_DB.get(track_name, -30.0)   # step 2.405
	_ambience_held_after_cut = false
	
	# stop any current fade tweens
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
		
	var current_ambience_vol = AudioServer.get_bus_volume_db(_ambience_bus_index)
		
	_music_fading_out = false
	if fade_duration > 0.0:
		if not resuming:
			_music_player.volume_db = -80.0
			_music_player.play()
		
		# set parallel to true so
		_music_tween = create_tween().set_parallel(true)
		_music_tween.tween_property(_music_player, "volume_db", target_db, fade_duration).set_trans(Tween.TRANS_SINE)
		_music_tween.tween_method(set_ambience_volume, current_ambience_vol, _base_ambience_volume + duck_db, fade_duration).set_trans(Tween.TRANS_SINE)
	else:
		_music_player.volume_db = target_db
		if not resuming:
			_music_player.play()
		set_ambience_volume(_base_ambience_volume + duck_db)

# --------------[called via dialogue: do soundmanager.fade_out_music(5.0)]
func fade_out_music(fade_duration: float = 2.0):
	if not is_instance_valid(_music_player) or not _music_player.playing:
		# step 2.392: after cut_music() the music is already silent but the ambience is still ducked: bring it back
		if _ambience_held_after_cut:
			_ambience_held_after_cut = false
			if _music_tween and _music_tween.is_valid():
				_music_tween.kill()
			if fade_duration > 0.0:
				_music_tween = create_tween()
				_music_tween.tween_method(set_ambience_volume, AudioServer.get_bus_volume_db(_ambience_bus_index), _base_ambience_volume, fade_duration).set_trans(Tween.TRANS_SINE)
			else:
				set_ambience_volume(_base_ambience_volume)
		return
	_ambience_held_after_cut = false
		
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	var current_ambience_vol = AudioServer.get_bus_volume_db(_ambience_bus_index)

	if fade_duration > 0.0:
		# set parallel to true so
		_music_tween = create_tween().set_parallel(true)
		_music_tween.tween_property(_music_player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE)
		_music_tween.tween_method(set_ambience_volume, current_ambience_vol, _base_ambience_volume, fade_duration).set_trans(Tween.TRANS_SINE)
		
		# chain wait until both fades
		_music_fading_out = true
		_music_tween.chain().tween_callback(_finish_music_fade)
	else:
		_music_fading_out = false
		_music_player.stop()
		set_ambience_volume(_base_ambience_volume)

# step 2.396: the end of a fade-out
func _finish_music_fade() -> void:
	_music_fading_out = false
	if is_instance_valid(_music_player):
		_music_player.stop()

# ---------------------[portal hum]

## step 2.397: the portal's hum rises over fade_in seconds and loops until fade_out_portal_hum(). asking again
## while it plays (or fades) brings it back up without restarting it.
func start_portal_hum(fade_in: float = 1.0) -> void:
	if not sfx_library.has("portal_hum"):
		return
	if not is_instance_valid(_portal_hum):
		_portal_hum = AudioStreamPlayer.new()
		_portal_hum.process_mode = Node.PROCESS_MODE_ALWAYS
		_portal_hum.bus = "looping sfx"
		var stream = sfx_library["portal_hum"]
		# it loops even if the import's Loop Mode was left on Detect From WAV / Disabled
		if stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_portal_hum.stream = stream
		add_child(_portal_hum)
	if _portal_hum_tween and _portal_hum_tween.is_valid():
		_portal_hum_tween.kill()
	if not _portal_hum.playing:
		_portal_hum.volume_db = -80.0
		_portal_hum.play()
	_portal_hum_tween = create_tween()
	_portal_hum_tween.tween_property(_portal_hum, "volume_db", PORTAL_HUM_DB, maxf(0.01, fade_in)).set_trans(Tween.TRANS_SINE)


## step 2.397: fades the portal's hum out and stops it. does nothing when it isn't playing.
func fade_out_portal_hum(seconds: float = 1.0) -> void:
	if not is_instance_valid(_portal_hum) or not _portal_hum.playing:
		return
	if _portal_hum_tween and _portal_hum_tween.is_valid():
		_portal_hum_tween.kill()
	_portal_hum_tween = create_tween()
	_portal_hum_tween.tween_property(_portal_hum, "volume_db", -80.0, maxf(0.01, seconds)).set_trans(Tween.TRANS_SINE)
	_portal_hum_tween.tween_callback(_portal_hum.stop)

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
		# step 2.410: a looping sound loops even if its file's Loop box was left off in the Import tab
		if player.stream is AudioStreamOggVorbis or player.stream is AudioStreamMP3:
			player.stream.loop = true
		elif player.stream is AudioStreamWAV and player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			player.stream.loop_begin = 0
			player.stream.loop_end = int(player.stream.get_length() * player.stream.mix_rate)
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
	# step 2.397: the portal's hum
	if _portal_hum_tween and _portal_hum_tween.is_valid():
		_portal_hum_tween.kill()
	if is_instance_valid(_portal_hum):
		_portal_hum.stop()
	set_ambience_volume(_base_ambience_volume)
