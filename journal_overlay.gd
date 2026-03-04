extends CanvasLayer

signal journal_closed

# --- NOW EXPORTED TO THE INSPECTOR ---
@export var journal_entries: Array[JournalPageData] = []

@onready var left_page_layers = %LeftPageLayers
@onready var right_page_layers = %RightPageLayers
@onready var page_indicator_label = %PageIndicatorLabel
@onready var prev_button = %PrevButton
@onready var next_button = %NextButton
@onready var close_button = %CloseButton

var current_spread: int = 0
var total_spreads: int = 1

func _ready():
	# Calculate how many total spreads (pairs of pages) we need
	var max_page = 0
	for entry in journal_entries:
		if entry and entry.page_index > max_page:
			max_page = entry.page_index
			
	total_spreads = ceil((max_page + 1) / 2.0)
	if total_spreads == 0: total_spreads = 1 
	
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	update_display()

func update_display():
	# 1. Clear old images from the pages
	for child in left_page_layers.get_children(): child.queue_free()
	for child in right_page_layers.get_children(): child.queue_free()
	
	# 2. Calculate which pages we are looking at
	var left_idx = current_spread * 2
	var right_idx = current_spread * 2 + 1
	
	# 3. Stack the transparent PNGs
	for entry in journal_entries:
		# Safety check if an array slot is empty or missing a texture
		if not entry or not entry.page_texture:
			continue
			
		# Check if this layer requires a flag to be visible
		if entry.required_flag != "":
			var flag_name = entry.required_flag
			var is_unlocked = false
			if GameManager.current_level_state_manager and GameManager.get_current_level_flag(flag_name):
				is_unlocked = true
			elif GameManager.get_game_flag(flag_name):
				is_unlocked = true
				
			if not is_unlocked:
				continue # Skip adding this image layer!
		
		# Add the image to the correct side of the book
		if entry.page_index == left_idx:
			_add_image_layer(left_page_layers, entry.page_texture)
		elif entry.page_index == right_idx:
			_add_image_layer(right_page_layers, entry.page_texture)

	# 4. Update UI
	page_indicator_label.text = str(current_spread + 1) + " / " + str(total_spreads)
	prev_button.disabled = (current_spread == 0)
	next_button.disabled = (current_spread >= total_spreads - 1)

# Helper function to spawn a TextureRect dynamically using the assigned Texture
func _add_image_layer(parent: Control, tex: Texture2D):
	var rect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)

func _on_prev_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	current_spread -= 1
	update_display()

func _on_next_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	current_spread += 1
	update_display()

func _on_close_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	journal_closed.emit()
