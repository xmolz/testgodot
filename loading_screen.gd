extends CanvasLayer

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var info_label: Label = $VBoxContainer/LoadingInfoLabel

# The list of massive files we want to pre-load.
var load_queue = [
	{"path": "res://main_menu.tscn", "name": "Main Menu UI"},
	{"path": "res://conversation_backgrounds.tres", "name": "Intro Cinematics"},
	{"path": "res://CharacterConversationOverlay.tscn", "name": "Intro Sequence"},
	{"path": "res://main.tscn", "name": "Hospital World"}
]

var current_load_index: int = 0
var progress_array: Array = []

func _ready():
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
		
		# Save it to the GameManager based on what it is
		match current_file["path"]:
			"res://main_menu.tscn":
				GameManager.cached_main_menu_scene = loaded_resource
			"res://CharacterConversationOverlay.tscn":
				GameManager.cached_intro_overlay_scene = loaded_resource
			"res://main.tscn":
				GameManager.cached_main_game_scene = loaded_resource
		
		# Move to the next file
		current_load_index += 1
		_start_next_load()
		
	elif load_status == ResourceLoader.THREAD_LOAD_FAILED or load_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		print_rich("[color=red]LoadingScreen Error: Failed to load %s[/color]" % current_file["path"])
		set_process(false)

func _finish_loading():
	progress_bar.value = 100
	info_label.text = "Loading Complete!"
	
	# Wait a tiny fraction of a second so the player sees 100%
	await get_tree().create_timer(0.5).timeout
	
	# Tell the GameManager to boot up the Main Menu!
	GameManager.change_game_state(GameManager.GameState.MAIN_MENU)
	
	queue_free()
