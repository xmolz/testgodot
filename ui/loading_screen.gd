extends CanvasLayer

@onready var loading_box: VBoxContainer = $Layout/Column/BottomSlot/LoadingBox
@onready var progress_bar: ProgressBar = $Layout/Column/BottomSlot/LoadingBox/ProgressBar
@onready var info_label: Label = $Layout/Column/BottomSlot/LoadingBox/LoadingInfoLabel
@onready var continue_box: VBoxContainer = $Layout/Column/BottomSlot/ContinueBox
@onready var age_ack_label: Label = $Layout/Column/BottomSlot/ContinueBox/AgeAckLabel
@onready var continue_button: Button = $Layout/Column/BottomSlot/ContinueBox/ButtonSlot/ContinueButton
@onready var title_label: Label = $Layout/Column/TitleLabel
@onready var body_label: Label = $Layout/Column/BodyLabel
@onready var caption_label: Label = $Layout/Column/CaptionLabel
@onready var portrait_row: HBoxContainer = $Layout/Column/PortraitRow
@onready var patron_label: Label = $Layout/Column/PatronLabel
@onready var footer_label: Label = $Layout/Column/FooterLabel
@onready var bottom_slot: Control = $Layout/Column/BottomSlot

# TODO: Replace these with the real love-interest base sprites when they're ready.
# Sprites of any height/crop work: each portrait scales keep-aspect to fill the
# flexible band the layout gives it.
const LOVE_INTEREST_PORTRAITS: Array[String] = [
	"res://Sprites/characters/layla/layla_base.png",
	"res://Sprites/characters/layla/layla_base.png",
	"res://Sprites/characters/layla/layla_base.png",
	"res://Sprites/characters/layla/layla_base.png",
]

# The list of massive files we want to pre-load.
var load_queue = [
	{"path": "res://ui/main_menu.tscn", "name": "System Interfaces"},
	{"path": "res://ui/difficulty_select_screen.tscn", "name": "Game Configuration"},
	{"path": "res://conversation/AdvancedConversationOverlay.tscn", "name": "Narrative Engine"},
	{"path": "res://main.tscn", "name": "Environment Data"}
]

var current_load_index: int = 0
var progress_array: Array = []
var _pulse_tween: Tween
var _continue_pressed: bool = false

func _ready():
	var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")
	for node in [info_label, age_ack_label, title_label, body_label, caption_label, patron_label, footer_label]:
		node.add_theme_font_override("font", custom_font)
	progress_bar.add_theme_font_override("font", custom_font)
	continue_button.add_theme_font_override("font", custom_font)

	# --- MOBILE SCALING ---
	# Only fonts and minimum sizes change here; the container layout handles
	# all positioning, so nothing can overlap regardless of text height.
	if OS.has_feature("mobile"):
		info_label.add_theme_font_size_override("font_size", 40)
		progress_bar.custom_minimum_size.y = 70
		progress_bar.add_theme_font_size_override("font_size", 36)

		title_label.add_theme_font_size_override("font_size", 52)
		body_label.add_theme_font_size_override("font_size", 26)
		caption_label.add_theme_font_size_override("font_size", 32)
		patron_label.add_theme_font_size_override("font_size", 24)
		age_ack_label.add_theme_font_size_override("font_size", 24)
		footer_label.add_theme_font_size_override("font_size", 18)
		continue_button.add_theme_font_size_override("font_size", 40)
		continue_button.custom_minimum_size = Vector2(520, 90)

		bottom_slot.custom_minimum_size.y = 200
		$Layout/Column/SpacerTop.size_flags_stretch_ratio = 0.25
		$Layout/Column/SpacerBottom.size_flags_stretch_ratio = 0.25

		var layout: MarginContainer = $Layout
		layout.add_theme_constant_override("margin_left", 60)
		layout.add_theme_constant_override("margin_right", 60)
		layout.add_theme_constant_override("margin_top", 24)
		layout.add_theme_constant_override("margin_bottom", 28)

	_build_portrait_row()
	continue_button.pressed.connect(_on_continue_pressed)

	progress_bar.value = 0
	_start_next_load()

func _build_portrait_row():
	for path in LOVE_INTEREST_PORTRAITS:
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("LoadingScreen: portrait not found: %s" % path)
			continue
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.set_meta("aspect", float(tex.get_width()) / float(tex.get_height()))
		rect.modulate.a = 0.0
		portrait_row.add_child(rect)

	# Portraits resize to fill whatever height the layout gives the row
	portrait_row.resized.connect(_resize_portraits)
	_resize_portraits.call_deferred()

	# Staggered fade-in so the row feels authored rather than popping in
	for i in portrait_row.get_child_count():
		var child := portrait_row.get_child(i)
		var tw := create_tween()
		tw.tween_interval(0.2 + i * 0.15)
		tw.tween_property(child, "modulate:a", 1.0, 0.35)

func _resize_portraits():
	var count := portrait_row.get_child_count()
	if count == 0:
		return
	var sep: float = portrait_row.get_theme_constant("separation")
	var total_aspect := 0.0
	for child in portrait_row.get_children():
		total_aspect += child.get_meta("aspect", 0.5)
	# Fill the band's height, capped so all portraits plus gaps fit the width.
	var h: float = portrait_row.size.y
	var max_h: float = (portrait_row.size.x - sep * (count - 1)) / total_aspect
	h = minf(h, max_h)
	for child in portrait_row.get_children():
		var w: float = h * child.get_meta("aspect", 0.5)
		if absf(child.custom_minimum_size.x - w) > 1.0:
			child.custom_minimum_size = Vector2(w, 0)

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

	# Let the player see 100% before the swap
	await get_tree().create_timer(0.4).timeout

	# Fade out the loading box, fade in the age line + Continue button.
	# Both live inside the fixed-height BottomSlot, so the column never reflows.
	var tween_out := create_tween()
	tween_out.tween_property(loading_box, "modulate:a", 0.0, 0.25)
	await tween_out.finished
	loading_box.visible = false

	continue_box.modulate.a = 0.0
	continue_box.visible = true
	var tween_in := create_tween()
	tween_in.tween_property(continue_box, "modulate:a", 1.0, 0.3)
	await tween_in.finished

	# Keyboard / gamepad accept works immediately
	continue_button.grab_focus()

	# Gentle pulse so the button reads as alive
	continue_button.pivot_offset = continue_button.size / 2.0
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(continue_button, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(continue_button, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_continue_pressed():
	if _continue_pressed:
		return
	_continue_pressed = true
	continue_button.disabled = true
	if _pulse_tween:
		_pulse_tween.kill()
	if SoundManager:
		SoundManager.play_sfx("start_game")

	# Tell the GameManager to boot up the Main Menu!
	GameManager.change_game_state(GameManager.GameState.MAIN_MENU)
	queue_free()
