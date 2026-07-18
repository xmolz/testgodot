extends CanvasLayer
## A basic dialogue balloon for use with Dialogue Manager.

## The action to use for advancing the dialogue
@export var next_action: StringName = &"ui_accept"

## The action to use to skip typing the dialogue
@export var skip_action: StringName = &"ui_cancel"

# --- ICON EXPORTS ---
@export_group("Response Icons")
@export var proceed_icon: Texture2D
@export var back_icon: Texture2D
@export var leave_icon: Texture2D

## The dialogue resource
var resource: DialogueResource

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

## See if we are running a long mutation and should hide the balloon
var will_hide_balloon: bool = false

## A dictionary to store any ephemeral variables
var locals: Dictionary = {}

var _locale: String = TranslationServer.get_locale()
var _is_responses_clickable: bool = false
var _is_simulating_choice: bool = false

# --- CACHED OBJECTS (avoid per-line allocations) ---
var _bbcode_regex: RegEx
var _blank_spacer_icon: ImageTexture
var _cached_name_styles: Dictionary = {}  # lookup_key -> StyleBoxFlat

# --- Character Background Color Lookup Table (For the Nameplate) ---
var character_colors: Dictionary = {
	"AIda": Color("#20B2AA"),   # Light Sea Green
	"Sergey": Color("#DAA520"), # Goldenrod
	"McBucket": Color("#FF4500"), # Orange-Red
	"Old Man": Color("#FF4500"),
	"Old Man McBucket": Color("#FF4500"),
	"Layla": Color("#FF8299"),   # Soft Rose Pink
	"Lewgend": Color("#708090"), # Neutral Slate Grey
	"Nathan": Color("#FF69B4"),  # Hot Pink
	"Dread": Color("#4B0082"),   # Indigo
	"The... Toilet?": Color("#DC143C"),   # Crimson Red (Warning!)
	"Player": Color("#FFD65C"),            # Blonde Gold (HSV 43,44,100)
	"Alyssa": Color("#9370DB"),   # Medium Purple
}

# --- Character Portrait Lookup Table ---
var character_portraits: Dictionary = {
	"AIda": preload("res://Sprites/dialogue sprites/aida_dialogue_sprite.PNG"),
	"Sergey": preload("res://Sprites/dialogue sprites/sergey_dialogue_sprite.png"),
	"McBucket": preload("res://Sprites/dialogue sprites/mcbucket_dialogue_sprite.PNG"),
	"Old Man": preload("res://Sprites/dialogue sprites/mcbucket_dialogue_sprite.PNG"),
	"Old Man McBucket": preload("res://Sprites/dialogue sprites/mcbucket_dialogue_sprite.PNG"),
	"Layla": preload("res://Sprites/dialogue sprites/layla_dialogue_sprite.png"),
	"Lewgend": preload("res://Sprites/dialogue sprites/lewgend_dialogue_sprite.png"),
	"Nathan": preload("res://icon.svg"),
	"The... Toilet?": preload("res://Sprites/dialogue sprites/toilet_dialogue_sprite.png"),
	"Player": preload("res://Sprites/dialogue sprites/protag_dialogue_sprite.png")
}

# --- Character Shader Background Colors ---
var character_bg_colors: Dictionary = {
	"AIda": {
		"top": Color("#c22b64"),
		"bot": Color("#ffffff"),
		"dot": Color(1.0, 1.0, 1.0, 0.4)
	},
	"Layla": {
		"top": Color("#FF9EAF"),
		"bot": Color("#FFE0E6"),
		"dot": Color(1.0, 1.0, 1.0, 0.4)
	},
	"Lewgend": {
		"top": Color("#4F4F4F"),
		"bot": Color("#A9A9A9"),
		"dot": Color(1.0, 1.0, 1.0, 0.2)
	},
	"The... Toilet?": {
		"top": Color("#330000"),
		"bot": Color("#a30000"),
		"dot": Color(0.0, 0.0, 0.0, 0.3)
	},
	"Player": {
		"top": Color("#000000"),
		"bot": Color("#FFD65C"),
		"dot": Color(1.0, 0.84, 0.36, 0.4)
	},
	"Sergey": {
		"top": Color("#B8860B"),
		"bot": Color("#FFFFFF"),
		"dot": Color(1.0, 1.0, 1.0, 0.4)
	},
	"McBucket": {
		"top": Color("#9400D3"),
		"bot": Color("#FFD700"),
		"dot": Color(1.0, 0.0, 0.2, 0.4)
	},
	"Old Man": {
		"top": Color("#9400D3"),
		"bot": Color("#FFD700"),
		"dot": Color(1.0, 0.0, 0.2, 0.4)
	},
	"Old Man McBucket": {
		"top": Color("#9400D3"),
		"bot": Color("#FFD700"),
		"dot": Color(1.0, 0.0, 0.2, 0.4)
	},
	"Alyssa": {
		"top": Color("#4B0082"), # Indigo
		"bot": Color("#E6E6FA"), # Lavender
		"dot": Color(1.0, 1.0, 1.0, 0.4)
	},
}
## The current line
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			queue_free()
	get:
		return dialogue_line

## A cooldown timer for delaying the balloon hide when encountering a mutation.
var mutation_cooldown: Timer = Timer.new()

## Timer for auto-advancing text
var auto_advance_timer: Timer = Timer.new()

## The base balloon anchor
@onready var balloon: Control = %Balloon

## The label showing the name of the currently speaking character
@onready var character_label: RichTextLabel = %CharacterLabel

## The label showing the currently spoken dialogue
@onready var dialogue_label: DialogueLabel = %DialogueLabel

## The menu of responses
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu

## Reference to the Portrait TextureRect (The Image itself)
@onready var portrait_rect: TextureRect = %PortraitRect

## Reference to the Container wrapping the portrait (The Box + Background)
@onready var portrait_container: PanelContainer = %PortraitContainer

## Reference to the Name Panel Container
@onready var name_panel: PanelContainer = $Balloon/NamePanel

## Reference to the Dialogue Container
@onready var dialogue_container: MarginContainer = $Balloon/Dialogue

## Is the UI currently hidden by the player?
var is_ui_hidden: bool = false

var _is_log_open: bool = false

## Quick Menu references
@onready var quick_menu: HBoxContainer = %QuickMenu
@onready var log_button: Button = %LogButton
@onready var hide_button: Button = %HideButton
@onready var menu_button: Button = %MenuButton
@onready var auto_button: Button = %AutoButton


func _ready() -> void:
	if log_button:
		log_button.pressed.connect(_on_log_button_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
	if auto_button:
		auto_button.pressed.connect(_on_auto_button_pressed)
		#Restore the cyan hover color once the mouse leaves the button
		auto_button.mouse_exited.connect(func():
			if GameManager and not Settings.is_auto_playing:
				auto_button.add_theme_color_override("font_hover_color", Color(0.6, 0.6, 0.6, 1.0) if OS.has_feature("mobile") else Color(0.2, 0.85, 1.0, 1.0))
		)
	if hide_button:
		hide_button.pressed.connect(_on_hide_button_pressed)
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	# --- Disable auto focus outline on the first item ---
	responses_menu.auto_focus_first_item = false

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	auto_advance_timer.one_shot = true
	auto_advance_timer.timeout.connect(_on_auto_advance_timeout)
	add_child(auto_advance_timer)

	if GameManager:
		_update_auto_button_visuals()
		if not Settings.auto_forward_toggled.is_connected(_on_global_auto_toggled):
			Settings.auto_forward_toggled.connect(_on_global_auto_toggled)

	# --- Style the responses menu and template button ---
	# 1. Increase vertical spacing between response buttons
	responses_menu.add_theme_constant_override("separation", 8)

	# 2. Setup Rounded Corners, Alignment, and Padding for the template button
	var template_btn = responses_menu.response_template as Button
	if template_btn:
		template_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		template_btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		template_btn.clip_contents = false
		template_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		template_btn.custom_minimum_size = Vector2(400, 0)

		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.15, 0.15, 0.15, 0.85) # Dark gray, slightly transparent
		normal_style.corner_radius_top_left = 6
		normal_style.corner_radius_top_right = 6
		normal_style.corner_radius_bottom_left = 6
		normal_style.corner_radius_bottom_right = 6
		# Add internal padding
		normal_style.content_margin_left = 15
		normal_style.content_margin_top = 8
		normal_style.content_margin_bottom = 8
		normal_style.content_margin_right = 25
		# Add an invisible border to the normal state so the button doesn't change size on hover
		normal_style.border_width_left = 2
		normal_style.border_width_top = 2
		normal_style.border_width_right = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = Color(1.0, 1.0, 1.0, 0.0)
		normal_style.anti_aliasing = false

		var hover_style = normal_style.duplicate()
		hover_style.bg_color = Color(0.1, 0.25, 0.3, 0.9) # Slightly cyan background
		hover_style.border_color = Color(0.2, 0.85, 1.0, 0.8) # Crisp cyan border

		template_btn.add_theme_stylebox_override("normal", normal_style)
		template_btn.add_theme_stylebox_override("hover", hover_style)
		template_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		template_btn.add_theme_stylebox_override("pressed", hover_style)
	# ---------------------------------------------------------

	# --- MOBILE UI SCALING ---
	if OS.has_feature("mobile"):
		quick_menu.add_theme_constant_override("separation", 50)
		menu_button.add_theme_font_size_override("font_size", 44)
		log_button.add_theme_font_size_override("font_size", 44)
		auto_button.add_theme_font_size_override("font_size", 44)
		hide_button.add_theme_font_size_override("font_size", 44)

		for qbtn in [menu_button, log_button, hide_button]:
			qbtn.add_theme_color_override("font_hover_color", Color(0.6, 0.6, 0.6, 1.0))

		responses_menu.add_theme_constant_override("separation", 25)
		if template_btn:
			template_btn.custom_minimum_size = Vector2(600, 0)
			var mobile_style = template_btn.get_theme_stylebox("normal").duplicate()
			mobile_style.content_margin_top = 20
			mobile_style.content_margin_bottom = 20
			mobile_style.content_margin_right = 35
			template_btn.add_theme_stylebox_override("normal", mobile_style)
			template_btn.add_theme_stylebox_override("hover", mobile_style)
			template_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			template_btn.add_theme_stylebox_override("pressed", mobile_style)

		dialogue_container.add_theme_constant_override("margin_top", 35)
		dialogue_container.add_theme_constant_override("margin_bottom", 30)

		# Bring the top anchors up by 5% to make the box slightly taller on mobile
		var panel = $Balloon/Panel
		var dialogue_node = $Balloon/Dialogue

		panel.anchor_top -= 0.05
		dialogue_node.anchor_top -= 0.05

		# Scale up and shift up the portrait box to match the taller mobile panel.
		# The TextureRect inside will automatically scale the image to fit this new 190x190 box.
		if is_instance_valid(portrait_container):
			portrait_container.offset_left = 40
			portrait_container.offset_top = -260
			portrait_container.offset_right = 230
			portrait_container.offset_bottom = -70

		# Move the NamePanel up by the same 5% so it stays perfectly aligned above the box
		if is_instance_valid(name_panel):
			name_panel.anchor_top -= 0.05
			name_panel.anchor_bottom -= 0.05

	# --- FIX RESPONSE EXPANSION DIRECTION (Universal) ---
	var responses_container = $Balloon/Responses
	var responses_menu_vbox = %ResponsesMenu
	if is_instance_valid(responses_container) and is_instance_valid(responses_menu_vbox):
		responses_container.anchor_right = 0.95
		responses_menu_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	# --- Pre-compile regex and create reusable spacer icon ---
	_bbcode_regex = RegEx.new()
	_bbcode_regex.compile("\\[.*?\\]")

	var blank_img = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	_blank_spacer_icon = ImageTexture.create_from_image(blank_img)

	# Preloaded icons are used directly, size capped by theme overrides
	# --- FAUX BOLD/ITALIC FONTS (Varela Round ships Regular only) ---
	var base_font: Font = dialogue_label.get_theme_font("normal_font")

	var vn_bold_font := FontVariation.new()
	vn_bold_font.base_font = base_font
	vn_bold_font.variation_embolden = 0.6

	var vn_italic_font := FontVariation.new()
	vn_italic_font.base_font = base_font
	vn_italic_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)

	var vn_bold_italic_font := FontVariation.new()
	vn_bold_italic_font.base_font = base_font
	vn_bold_italic_font.variation_embolden = 0.6
	vn_bold_italic_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)

	dialogue_label.add_theme_font_override("bold_font", vn_bold_font)
	dialogue_label.add_theme_font_override("italics_font", vn_italic_font)
	dialogue_label.add_theme_font_override("bold_italics_font", vn_bold_italic_font)

	# The nameplate wraps every name in [b]...[/b], so it needs the bold variant too
	character_label.add_theme_font_override("bold_font", vn_bold_font)

	# --- DYNAMIC TEXT SCALING (PC, Mobile & Marketing) ---
	if GameManager:
		if not Settings.text_scale_changed.is_connected(_update_text_scale):
			Settings.text_scale_changed.connect(_update_text_scale)
	_update_text_scale(Settings.dialogue_text_scale if GameManager else 1.0)


func _unhandled_input(event: InputEvent) -> void:
	# --- Arrow keys summon the highlight when no option is focused ---
	# (When an option IS focused, arrow presses are consumed by Godot's native
	# focus navigation and Space/Enter by the focused button, so they never
	# reach _unhandled_input. Only the "nothing focused" case lands here.)
	if responses_menu.visible and not is_ui_hidden and not dialogue_label.is_typing:
		var items: Array = responses_menu.get_menu_items()
		if items.size() > 0:
			if event.is_action_pressed("ui_down"):
				get_viewport().set_input_as_handled()
				items[0].grab_focus()
				return
			if event.is_action_pressed("ui_up"):
				get_viewport().set_input_as_handled()
				items[items.size() - 1].grab_focus()
				return

	if event.is_action_pressed(next_action):
		# Unhide the UI if hidden (mirrors the gui_input path)
		if is_ui_hidden:
			get_viewport().set_input_as_handled()
			set_ui_hidden(false)
			return

		if dialogue_line != null and not dialogue_label.is_typing and responses_menu.visible:
			var items: Array = responses_menu.get_menu_items()

			# Exactly one option: select it immediately (existing behaviour)
			if items.size() == 1 and _is_responses_clickable:
				get_viewport().set_input_as_handled()
				_simulate_single_response_click(items[0].get_meta("response"))
				return

			# Multiple options, nothing highlighted yet:
			# the first press summons the highlight instead of selecting
			if items.size() > 1:
				get_viewport().set_input_as_handled()
				items[0].grab_focus()
				return

		# Fallback advance for lines with no responses, in case the balloon
		# lost keyboard focus (e.g. after closing the history log)
		if is_waiting_for_input and dialogue_line != null and dialogue_line.responses.size() == 0:
			get_viewport().set_input_as_handled()
			if SoundManager: SoundManager.play_sfx("ui_click")
			next(dialogue_line.next_id)
			return

	# Existing behaviour: swallow all other input while dialogue is on screen
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio = dialogue_label.visible_ratio
		self.dialogue_line = await resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


## Start some dialogue
func start(dialogue_resource: DialogueResource, title: String, extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	resource = dialogue_resource
	self.dialogue_line = await resource.get_next_dialogue_line(title, temporary_game_states)


## Apply any changes to the balloon given a new [DialogueLine].
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()
	auto_advance_timer.stop()

	is_waiting_for_input = false
	_is_simulating_choice = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	# --- FIX: Move the reset up here to run BEFORE evaluating the new line! ---
	balloon.show()
	will_hide_balloon = false
	_restore_dialogue_visibility()
	# --------------------------------------------------------------------------

	# 1. Get the Raw name (includes BBCode like [color]...)
	var raw_name_with_tags = dialogue_line.character
	
	# 2. Create a "Clean" name (No Tags) for Dictionary lookups
	var lookup_key = _bbcode_regex.sub(raw_name_with_tags, "", true).strip_edges() # "Dread"

	# 2b. Create a display name that swaps "Player" for the actual name or "???"
	var display_name = raw_name_with_tags
	if lookup_key == "Player":
		if GameManager and Flags.get_game_flag("first_name_correct"):
			display_name = display_name.replace("Player", "Fiona")
		else:
			display_name = display_name.replace("Player", "???")

	# 3. Handle Name Panel Visibility and Color
	if display_name.is_empty():
		name_panel.visible = false
	else:
		name_panel.visible = true
		
		# --- SMART SPACE INSERTER LOGIC ---
		var spaced_name = ""
		var inside_tag = false

		for i in range(display_name.length()):
			var char = display_name[i]

			if char == "[":
				inside_tag = true

			spaced_name += char

			if char == "]":
				inside_tag = false

			# If we are NOT inside a tag, and it's not a bracket, add a space
			if not inside_tag and char != "[" and char != "]":
				# Only add space if the NEXT char isn't a tag opener
				if i < display_name.length() - 1 and display_name[i+1] != "[":
					spaced_name += " "
		# ----------------------------------

		character_label.text = "[center][b]" + spaced_name + "[/b][/center]"
		character_label.add_theme_color_override("default_color", Color.WHITE)
		
		# Update Background Panel Color using the CLEAN lookup key
		if not _cached_name_styles.has(lookup_key):
			var new_style = name_panel.get_theme_stylebox("panel").duplicate()
			if character_colors.has(lookup_key):
				new_style.bg_color = character_colors[lookup_key]
			else:
				new_style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
			_cached_name_styles[lookup_key] = new_style
		name_panel.add_theme_stylebox_override("panel", _cached_name_styles[lookup_key])

	# 4. Update Portrait using CLEAN lookup key
	if character_portraits.has(lookup_key):
		portrait_rect.texture = character_portraits[lookup_key]
		
		# SHOW THE WHOLE CONTAINER (Box + Pattern + Image)
		portrait_container.visible = true 
		
		dialogue_container.add_theme_constant_override("margin_left", 260 if OS.has_feature("mobile") else 230)
		# --- NEW: SWAP SHADER COLORS ---
		var bg_pattern = portrait_container.get_node("BackgroundPattern")
		if bg_pattern and bg_pattern.material is ShaderMaterial:
			if character_bg_colors.has(lookup_key):
				var colors = character_bg_colors[lookup_key]
				bg_pattern.material.set_shader_parameter("color_top", colors["top"])
				bg_pattern.material.set_shader_parameter("color_bottom", colors["bot"])
				bg_pattern.material.set_shader_parameter("dot_color", colors["dot"])
			else:
				# Default generic colors if we forgot to add them to the dictionary
				bg_pattern.material.set_shader_parameter("color_top", Color("#1f2938"))
				bg_pattern.material.set_shader_parameter("color_bottom", Color("#0a0d14"))
				bg_pattern.material.set_shader_parameter("dot_color", Color(0, 0, 0, 0.3))
	else:
		# HIDE THE WHOLE CONTAINER
		portrait_container.visible = false 
		
		dialogue_container.add_theme_constant_override("margin_left", 50 if OS.has_feature("mobile") else 30)

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line
	if GameManager:
		if Settings.instant_text:
			dialogue_label.seconds_per_step = 0.0
		else:
			dialogue_label.seconds_per_step = Settings.text_speed

	responses_menu.hide()
	responses_menu.modulate.a = 1.0 # --- Reset alpha for safety
	responses_menu.responses = dialogue_line.responses

	# --- FORMATTING LOGIC FOR RESPONSES ---
	for i in range(responses_menu.get_child_count()):
		var button = responses_menu.get_child(i)

		# Ignore the template and any non-button children
		if button == responses_menu.response_template or not button is Button:
			continue

		# Retrieve the DialogueResponse object attached to the button
		if not button.has_meta("response"):
			continue

		var response_obj = button.get_meta("response")
		var original_text = response_obj.text
		var display_text = original_text

		# Safely check if this line has been visited using a truly unique ID
		var unique_choice_id = resource.resource_path + "::" + response_obj.id
		var is_visited = false
		if DialogueHistory:
			is_visited = DialogueHistory.visited_responses.has(unique_choice_id)

		# Default colors and icon
		var resting_color = Color.WHITE # Reverted back to pure white
		var hover_color = Color.WHITE
		var lower_text = display_text.to_lower()
		var assigned_icon: Texture2D = null

		# Parse custom tags and apply styling/icons
		if "[proceed]" in lower_text:
			display_text = display_text.replacen("[proceed]", "").strip_edges()
			assigned_icon = proceed_icon
			resting_color = Color(0.2, 0.85, 1.0, 1.0) # Cyan
			hover_color = Color.WHITE
		elif "[back]" in lower_text:
			display_text = display_text.replacen("[back]", "").strip_edges()
			assigned_icon = back_icon
			resting_color = Color(0.6, 0.6, 0.6, 1.0) # Gray
			hover_color = Color(0.8, 0.8, 0.8, 1.0) # Light Gray
		elif "[leave]" in lower_text:
			display_text = display_text.replacen("[leave]", "").strip_edges()
			assigned_icon = leave_icon
			resting_color = Color(0.6, 0.6, 0.6, 1.0) # Gray
			hover_color = Color(0.8, 0.8, 0.8, 1.0) # Light Gray
		elif is_visited:
			resting_color = Color(0.6, 0.6, 0.6, 1.0) # Gray
			hover_color = Color(0.8, 0.8, 0.8, 1.0) # Light Gray

		# --- ICON AND ALIGNMENT REFACTOR ---
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

		if assigned_icon == null:
			assigned_icon = _blank_spacer_icon

		button.text = display_text
		button.icon = assigned_icon
		button.expand_icon = false
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 32)
		button.add_theme_constant_override("h_separation", 12)
		# --------------------------------------------------------------------------------------

		# Text colors
		button.add_theme_color_override("font_color", resting_color)
		button.add_theme_color_override("font_focus_color", hover_color)
		button.add_theme_color_override("font_hover_color", hover_color)
		button.add_theme_color_override("font_pressed_color", hover_color)

		# Icon colors
		button.add_theme_color_override("icon_normal_color", resting_color)
		button.add_theme_color_override("icon_focus_color", hover_color)
		button.add_theme_color_override("icon_hover_color", hover_color)
		button.add_theme_color_override("icon_pressed_color", hover_color)

		if OS.has_feature("mobile"):
			button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		else:
			# Keyboard focus draws the same panel as mouse hover
			button.add_theme_stylebox_override("focus", button.get_theme_stylebox("hover"))
		if OS.has_feature("mobile"):
			button.add_theme_color_override("font_hover_color", resting_color)
			button.add_theme_color_override("icon_hover_color", resting_color)
			button.add_theme_color_override("font_focus_color", resting_color)
			button.add_theme_color_override("icon_focus_color", resting_color)

		# --- Fix sticky hover state by dropping focus on mouse exit ---
		if not button.mouse_exited.is_connected(button.release_focus):
			button.mouse_exited.connect(button.release_focus)
	# ------------------------------------------

	# --- RECORD HISTORY ---
	if GameManager and not dialogue_line.text.is_empty():
		var history_display_name = lookup_key
		if lookup_key == "Player":
			if Flags.get_game_flag("first_name_correct"):
				history_display_name = "Fiona"
			else:
				history_display_name = "???"

		DialogueHistory.add_line(lookup_key, history_display_name, dialogue_line.text)

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE

		# --- Fade-In Cooldown to prevent spam-clicking ---
		_is_responses_clickable = false
		responses_menu.modulate.a = 0.0
		responses_menu.show()

		var fade_tween = create_tween()
		fade_tween.tween_property(responses_menu, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
		fade_tween.tween_callback(func(): _is_responses_clickable = true)
		# ------------------------------------------------------

		# --- AUTO-FORWARD SINGLE CHOICE ---
		if GameManager and Settings.is_auto_playing and dialogue_line.responses.size() == 1:
			_start_auto_advance_timer()

	elif dialogue_line.time != "":
		var time = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()

		if GameManager and Settings.is_auto_playing:
			_start_auto_advance_timer()

## Go to the next line
func next(next_id: String) -> void:
	self.dialogue_line = await resource.get_next_dialogue_line(next_id, temporary_game_states)


#region Signals

func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()

func _on_mutated(_mutation: Dictionary) -> void:
	is_waiting_for_input = false

	# --- COMMENT THESE OUT TO FIX THE BLINK ---
	# will_hide_balloon = true
	# mutation_cooldown.start(0.1)

func _on_balloon_gui_input(event: InputEvent) -> void:
	var is_right_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed()
	var is_h_key = event is InputEventKey and event.keycode == KEY_H and event.is_pressed() and not event.is_echo()

	# --- NEW: UNHIDE ON CLICK OR 'H' ---
	if is_ui_hidden:
		if event is InputEventMouseButton and event.is_pressed() and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			get_viewport().set_input_as_handled()
			set_ui_hidden(false)
			return
		elif event.is_action_pressed(next_action) or event.is_action_pressed(skip_action) or is_h_key:
			get_viewport().set_input_as_handled()
			set_ui_hidden(false)
			return

	# --- NEW: HIDE ON RIGHT-CLICK OR 'H' ---
	if is_right_click or is_h_key:
		get_viewport().set_input_as_handled()
		set_ui_hidden(true)
		return

	# --- NEW: SCROLL UP TO OPEN LOG ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
		get_viewport().set_input_as_handled()
		_on_log_button_pressed()
		return

	# See if we need to skip typing of the dialogue
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action) or event.is_action_pressed(next_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if SoundManager: SoundManager.play_sfx("ui_click")
		next(dialogue_line.next_id)

	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		if SoundManager: SoundManager.play_sfx("ui_click")
		next(dialogue_line.next_id)

func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	# --- Ignore clicks if the menu is still fading in ---
	if not _is_responses_clickable:
		return
	# ---------------------------------------------------------

	# Record visited response using a truly unique ID
	var unique_choice_id = resource.resource_path + "::" + response.id
	if DialogueHistory:
		DialogueHistory.visited_responses[unique_choice_id] = true

	# --- RECORD CHOICE HISTORY ---
	if GameManager:
		var all_options: Array[String] = []
		var chosen_idx = 0
		for i in range(dialogue_line.responses.size()):
			var resp = dialogue_line.responses[i]
			all_options.append(resp.text)
			if resp.id == response.id:
				chosen_idx = i

		var player_name = "Player"
		if Flags.get_game_flag("first_name_correct"):
			player_name = "Fiona"
		else:
			player_name = "???"

		DialogueHistory.add_choice("Player", player_name, all_options, chosen_idx)

	if SoundManager: SoundManager.play_sfx("ui_click")
	next(response.next_id)

func _on_dialogue_label_spoke(letter: String, letter_index: int, speed: float) -> void:
	if letter == " ": return
	# if SoundManager: SoundManager.play_dialogue_blip()

#endregion


#region Quick Menu (VN Style)

func _on_hide_button_pressed() -> void:
	if SoundManager: SoundManager.play_sfx("ui_click")
	set_ui_hidden(true)

func set_ui_hidden(hide: bool) -> void:
	is_ui_hidden = hide
	var is_visible = not hide

	if hide:
		if not auto_advance_timer.is_stopped():
			auto_advance_timer.paused = true
	else:
		if GameManager and Settings.is_auto_playing:
			if is_instance_valid(auto_advance_timer) and auto_advance_timer.paused:
				auto_advance_timer.paused = false
			elif not dialogue_label.is_typing:
				if is_waiting_for_input or (dialogue_line and dialogue_line.responses.size() == 1):
					_start_auto_advance_timer()

	var panel = $Balloon/Panel
	panel.visible = is_visible
	dialogue_container.visible = is_visible
	$Balloon/Responses.visible = is_visible
	quick_menu.visible = is_visible

	# Only restore character elements if we are toggling ON, and the current line requires them
	if is_visible and dialogue_line != null:
		var raw_name = dialogue_line.character
		name_panel.visible = not raw_name.is_empty()

		var lookup_key = _bbcode_regex.sub(raw_name, "", true).strip_edges()
		portrait_container.visible = character_portraits.has(lookup_key)
	else:
		name_panel.visible = false
		portrait_container.visible = false

func _restore_dialogue_visibility() -> void:
	set_ui_hidden(false)

func _on_log_button_pressed() -> void:
	if SoundManager: SoundManager.play_sfx("ui_click")
	var log_scene = load("res://ui/dialogue_history_ui.tscn")
	if log_scene:
		var log_instance = log_scene.instantiate()
		get_tree().root.add_child(log_instance)

		# Suspend Auto-Forward while the log is open
		_is_log_open = true
		if not auto_advance_timer.is_stopped():
			auto_advance_timer.paused = true

		log_instance.tree_exited.connect(func():
			if not is_instance_valid(self):
				return

			_is_log_open = false
			if GameManager and Settings.is_auto_playing:
				# If timer was paused, resume it
				if is_instance_valid(auto_advance_timer) and auto_advance_timer.paused:
					auto_advance_timer.paused = false
				# If text finished typing while the log was open, start the timer now
				elif not dialogue_label.is_typing:
					if is_waiting_for_input or (dialogue_line and dialogue_line.responses.size() == 1):
						_start_auto_advance_timer()
		)

func _on_auto_button_pressed() -> void:
	if SoundManager: SoundManager.play_sfx("ui_click")
	if GameManager:
		Settings.is_auto_playing = not Settings.is_auto_playing

func _on_global_auto_toggled(is_on: bool):
	_update_auto_button_visuals()
	if is_on and not dialogue_label.is_typing:
		if is_waiting_for_input:
			_start_auto_advance_timer()
		elif dialogue_line.responses.size() == 1:
			_start_auto_advance_timer()
	elif not is_on:
		auto_advance_timer.stop()

func _start_auto_advance_timer():
	if _is_log_open or is_ui_hidden:
		return

	# Base wait from settings + 0.025 seconds per character
	var wait_time = Settings.auto_time_delay + (dialogue_line.text.length() * 0.025)
	auto_advance_timer.start(wait_time)

func _on_auto_advance_timeout():
	if is_waiting_for_input:
		next(dialogue_line.next_id)
	elif dialogue_line.responses.size() == 1:
		_simulate_single_response_click(dialogue_line.responses[0])

func _simulate_single_response_click(response: DialogueResponse):
	if _is_simulating_choice: return
	_is_simulating_choice = true
	var target_btn: Button = null
	for i in range(responses_menu.get_child_count()):
		var btn = responses_menu.get_child(i)
		if btn is Button and btn.has_meta("response") and btn.get_meta("response") == response:
			target_btn = btn
			break

	if target_btn:
		target_btn.grab_focus()
		target_btn.pivot_offset = target_btn.size / 2.0

		var tween = create_tween()
		# Visually compress and tint the button to simulate a physical click
		tween.tween_property(target_btn, "scale", Vector2(0.95, 0.95), 0.1).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(target_btn, "modulate", Color(0.6, 0.85, 1.0, 1.0), 0.1)

		# Bounce back
		tween.tween_property(target_btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(target_btn, "modulate", Color.WHITE, 0.1)

		# Trigger the actual dialogue progression right when the button reaches maximum compression
		tween.parallel().tween_callback(func():
			_on_responses_menu_response_selected(response)
		).set_delay(0.1)
	else:
		_on_responses_menu_response_selected(response)

func _cancel_auto_mode():
	if GameManager and Settings.is_auto_playing:
		Settings.is_auto_playing = false

func _update_auto_button_visuals():
	if not auto_button: return
	if GameManager and Settings.is_auto_playing:
		auto_button.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 1.0))
		auto_button.add_theme_color_override("font_hover_color", Color(0.2, 0.85, 1.0, 1.0) if OS.has_feature("mobile") else Color(0.4, 0.95, 1.0, 1.0))
		auto_button.add_theme_color_override("font_focus_color", Color(0.2, 0.85, 1.0, 1.0))
	else:
		auto_button.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		auto_button.add_theme_color_override("font_focus_color", Color(0.6, 0.6, 0.6, 1.0)) # Prevent the button from sticking 'on' due to focus
		
		# Temporarily suppress the cyan hover color if we just clicked it off
		if auto_button.is_hovered() and not OS.has_feature("mobile"):
			auto_button.add_theme_color_override("font_hover_color", Color(0.6, 0.6, 0.6, 1.0))
		else:
			auto_button.add_theme_color_override("font_hover_color", Color(0.6, 0.6, 0.6, 1.0) if OS.has_feature("mobile") else Color(0.2, 0.85, 1.0, 1.0))

func _on_menu_button_pressed() -> void:
	if SoundManager: SoundManager.play_sfx("ui_click")
	if GameManager and is_instance_valid(GameManager.pause_menu_ui):
		GameManager.pause_menu_ui.toggle_pause()

#endregion

func _update_text_scale(scale_mult: float) -> void:
	var base_diag_size = 44 if OS.has_feature("mobile") else 28
	var base_name_size = 44 if OS.has_feature("mobile") else 30
	var base_resp_size = 38 if OS.has_feature("mobile") else 28

	var diag_size = int(base_diag_size * scale_mult)
	var name_size = int(base_name_size * scale_mult)
	var resp_size = int(base_resp_size * scale_mult)

	if is_instance_valid(dialogue_label):
		dialogue_label.add_theme_font_size_override("normal_font_size", diag_size)
		dialogue_label.add_theme_font_size_override("bold_font_size", diag_size)
		dialogue_label.add_theme_font_size_override("italics_font_size", diag_size)
		dialogue_label.add_theme_font_size_override("bold_italics_font_size", diag_size)

	if is_instance_valid(character_label):
		character_label.add_theme_font_size_override("normal_font_size", name_size)
		character_label.add_theme_font_size_override("bold_font_size", name_size)

	if is_instance_valid(responses_menu):
		for i in range(responses_menu.get_child_count()):
			var btn = responses_menu.get_child(i)
			if btn is Button:
				btn.add_theme_font_size_override("font_size", resp_size)
