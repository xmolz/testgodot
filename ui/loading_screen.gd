extends CanvasLayer

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var info_label: Label = $VBoxContainer/LoadingInfoLabel

# The list of massive files we want to pre-load.
var load_queue = [
	{"path": "res://ui/main_menu.tscn", "name": "System Interfaces"},
	{"path": "res://ui/difficulty_select_screen.tscn", "name": "Game Configuration"},
	{"path": "res://conversation/AdvancedConversationOverlay.tscn", "name": "Narrative Engine"},
	{"path": "res://main.tscn", "name": "Environment Data"}
]

var current_load_index: int = 0
var progress_array: Array = []

func _ready():
	var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")
	info_label.add_theme_font_override("font", custom_font)
	progress_bar.add_theme_font_override("font", custom_font)

	# --- MOBILE SCALING ---
	if OS.has_feature("mobile"):
		info_label.add_theme_font_size_override("font_size", 48)
		progress_bar.custom_minimum_size.y = 80
		progress_bar.add_theme_font_size_override("font_size", 36)

		var vbox = $VBoxContainer
		vbox.offset_top = -350
		vbox.offset_bottom = -100
		vbox.add_theme_constant_override("separation", 25)

	progress_bar.value = 0
	_start_next_load()

func _start_next_load():
	if current_load_index >= load_queue.size():
		_finish_loading()
		return
		
	var current_file = load_queue[current_load_index]
	info_label.text = "Loading: " + current_file["name"] + "..."
	
	# Start loading the file on a background CPU thread
	ResourceLoader.load_threaded_request(current_file["path"])
	set_process(true)

func _process(_delta):
	var current_file = load_queue[current_load_index]
	
	# Check the status of the background thread
	var load_status = ResourceLoader.load_threaded_get_status(current_file["path"], progress_array)
	
	if load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# Calculate overall progress across all files
		var base_progress = (float(current_load_index) / load_queue.size()) * 100.0
		var file_progress = (progress_array[0] * 100.0) / load_queue.size()
		progress_bar.value = base_progress + file_progress
		
	elif load_status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		
		# Grab the finished resource
		var loaded_resource = ResourceLoader.load_threaded_get(current_file["path"])
		
		# Save it to the SceneDirector based on what it is
		match current_file["path"]:
			"res://ui/main_menu.tscn":
				SceneDirector.cached_main_menu_scene = loaded_resource
			"res://conversation/AdvancedConversationOverlay.tscn":
				SceneDirector.cached_intro_overlay_scene = loaded_resource
			"res://main.tscn":
				SceneDirector.cached_main_game_scene = loaded_resource
		
		# Move to the next file
		current_load_index += 1
		_start_next_load()
		
	elif load_status == ResourceLoader.THREAD_LOAD_FAILED or load_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("LoadingScreen: Failed to load %s (status %d) — skipping." % [current_file["path"], load_status])
		print_rich("[color=red]LoadingScreen Error: Failed to load %s — skipping.[/color]" % current_file["path"])
		set_process(false)
		current_load_index += 1
		_start_next_load()

func _finish_loading():
	progress_bar.value = 100
	info_label.text = "Loading Complete!"
	
	# Wait a tiny fraction of a second so the player sees 100%
	await get_tree().create_timer(0.5).timeout
	
	# Tell the GameManager to boot up the Main Menu!
	GameManager.change_game_state(GameManager.GameState.MAIN_MENU)
	
	queue_free()
