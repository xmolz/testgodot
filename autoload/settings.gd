# Settings.gd (Autoload) — user preferences + persistence (user://settings.cfg).
extends Node

signal auto_forward_toggled(is_on: bool)
signal fullscreen_toggled(is_on: bool)
signal text_scale_changed(new_scale: float)

const SETTINGS_FILE_PATH = "user://settings.cfg"

# --- Dialogue text ---
var text_speed: float = 0.02
var instant_text: bool = false
var dialogue_text_scale: float = 1.0:
	set(val):
		dialogue_text_scale = val
		text_scale_changed.emit(val)
var auto_time_delay: float = 0.486
var is_auto_playing: bool = false:
	set(val):
		is_auto_playing = val
		auto_forward_toggled.emit(val)

# --- Gameplay ---
var assisted_mode: bool = false

# --- Display ---
var fullscreen: bool = true


func _ready():
	load_settings()
	apply_window_mode()


func set_bus_volume(bus_name: String, linear_val: float):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))


func get_bus_volume(bus_name: String) -> float:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	return 1.0


func save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master", get_bus_volume("Master"))
	cfg.set_value("audio", "music", get_bus_volume("Music"))
	cfg.set_value("audio", "sfx", get_bus_volume("SFX"))
	cfg.set_value("dialogue", "text_speed", text_speed)
	cfg.set_value("dialogue", "instant_text", instant_text)
	cfg.set_value("dialogue", "text_scale", dialogue_text_scale)
	cfg.set_value("dialogue", "auto_forward", is_auto_playing)
	cfg.set_value("dialogue", "auto_delay", auto_time_delay)
	cfg.set_value("gameplay", "assisted_mode", assisted_mode)
	cfg.set_value("display", "fullscreen", fullscreen)
	var err = cfg.save(SETTINGS_FILE_PATH)
	if err != OK:
		push_warning("Settings: Could not save settings to %s (error %d)" % [SETTINGS_FILE_PATH, err])


func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_FILE_PATH) != OK:
		return
	set_bus_volume("Master", clampf(float(cfg.get_value("audio", "master", get_bus_volume("Master"))), 0.0, 1.0))
	set_bus_volume("Music", clampf(float(cfg.get_value("audio", "music", get_bus_volume("Music"))), 0.0, 1.0))
	set_bus_volume("SFX", clampf(float(cfg.get_value("audio", "sfx", get_bus_volume("SFX"))), 0.0, 1.0))
	text_speed = clampf(float(cfg.get_value("dialogue", "text_speed", text_speed)), 0.005, 0.05)
	instant_text = bool(cfg.get_value("dialogue", "instant_text", instant_text))
	
	if OS.has_feature("mobile"):
		dialogue_text_scale = clampf(float(cfg.get_value("dialogue", "text_scale", dialogue_text_scale)), 0.6, 1.1)
	else:
		dialogue_text_scale = clampf(float(cfg.get_value("dialogue", "text_scale", dialogue_text_scale)), 0.5, 1.5)
		
	is_auto_playing = bool(cfg.get_value("dialogue", "auto_forward", is_auto_playing))
	auto_time_delay = clampf(float(cfg.get_value("dialogue", "auto_delay", auto_time_delay)), 0.125, 1.75)
	assisted_mode = bool(cfg.get_value("gameplay", "assisted_mode", assisted_mode))
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	apply_window_mode()


func apply_window_mode():
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return
	var target = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
		else DisplayServer.WINDOW_MODE_MAXIMIZED
	if DisplayServer.window_get_mode() != target:
		DisplayServer.window_set_mode(target)


func set_fullscreen(val: bool):
	fullscreen = val
	apply_window_mode()
	fullscreen_toggled.emit(val)
	save_settings()


func toggle_fullscreen():
	set_fullscreen(not fullscreen)


func _input(event):
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return
	if event.is_action_pressed("toggle_fullscreen"):
		get_viewport().set_input_as_handled()
		toggle_fullscreen()
