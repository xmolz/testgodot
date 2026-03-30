extends CanvasLayer
## A basic dialogue balloon for use with Dialogue Manager.

## The action to use for advancing the dialogue
@export var next_action: StringName = &"ui_accept"

## The action to use to skip typing the dialogue
@export var skip_action: StringName = &"ui_cancel"

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

# --- Character Background Color Lookup Table (For the Nameplate) ---
var character_colors: Dictionary = {
	"AIda": Color("#20B2AA"),   # Light Sea Green
	"Sergey": Color("#DAA520"), # Goldenrod
	"McBucket": Color("#6B8E23"), # Olive Drab
	"Nathan": Color("#FF69B4"),  # Hot Pink
	"Dread": Color("#4B0082"),   # Indigo
	"The... Toilet?": Color("#DC143C"),   # Crimson Red (Warning!)
	"Player": Color("#FFD65C")            # Blonde Gold (HSV 43,44,100)
}

# --- Character Portrait Lookup Table ---
var character_portraits: Dictionary = {
	"AIda": preload("res://Sprites/dialogue sprites/aida_dialogue_sprite.png"), 
	"Sergey": preload("res://Sprites/dialogue sprites/sergey_dialogue_sprite.png"),
	"McBucket": preload("res://mcbucket.png"),
	"Nathan": preload("res://icon.svg"),
	"The... Toilet?": preload("res://Sprites/dialogue sprites/toilet_dialogue_sprite.png"), # <--- UPDATE THIS PATH
	"Player": preload("res://Sprites/dialogue sprites/protag_dialogue_sprite.png")
}

# --- Character Shader Background Colors ---
var character_bg_colors: Dictionary = {
	"AIda": {
		"top": Color("#c22b64"), 
		"bot": Color("#ffffff"), 
		"dot": Color(1.0, 1.0, 1.0, 0.4)
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
	}
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

## The toggle button for hiding/showing dialogue
var dialogue_toggle_button: Control


func _ready() -> void:
	_create_toggle_button()
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)


func _unhandled_input(_event: InputEvent) -> void:
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

	is_waiting_for_input = false
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
	var regex = RegEx.new()
	regex.compile("\\[.*?\\]") # Matches anything inside [ ]
	var lookup_key = regex.sub(raw_name_with_tags, "", true).strip_edges() # "Dread"
	
	# 3. Handle Name Panel Visibility and Color
	if raw_name_with_tags.is_empty():
		name_panel.visible = false
	else:
		name_panel.visible = true
		
		# --- SMART SPACE INSERTER LOGIC ---
		var spaced_name = ""
		var inside_tag = false
		
		for i in range(raw_name_with_tags.length()):
			var char = raw_name_with_tags[i]
			
			if char == "[":
				inside_tag = true
			
			spaced_name += char
			
			if char == "]":
				inside_tag = false
				
			# If we are NOT inside a tag, and it's not a bracket, add a space
			if not inside_tag and char != "[" and char != "]":
				# Only add space if the NEXT char isn't a tag opener
				if i < raw_name_with_tags.length() - 1 and raw_name_with_tags[i+1] != "[":
					spaced_name += " "
		# ----------------------------------

		character_label.text = "[center][b]" + spaced_name + "[/b][/center]"
		character_label.add_theme_color_override("default_color", Color.WHITE)
		
		# Update Background Panel Color using the CLEAN lookup key
		var new_style = name_panel.get_theme_stylebox("panel").duplicate()
		if character_colors.has(lookup_key):
			new_style.bg_color = character_colors[lookup_key]
		else:
			new_style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
		name_panel.add_theme_stylebox_override("panel", new_style)

	# 4. Update Portrait using CLEAN lookup key
	if character_portraits.has(lookup_key):
		portrait_rect.texture = character_portraits[lookup_key]
		
		# SHOW THE WHOLE CONTAINER (Box + Pattern + Image)
		portrait_container.visible = true 
		
		dialogue_container.add_theme_constant_override("margin_left", 230)
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
		
		dialogue_container.add_theme_constant_override("margin_left", 30)

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var time = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()

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
	will_hide_balloon = true
	mutation_cooldown.start(0.1)

func _on_balloon_gui_input(event: InputEvent) -> void:
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if SoundManager: SoundManager.play_sfx("dialogue_advance")
		next(dialogue_line.next_id)

	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		if SoundManager: SoundManager.play_sfx("dialogue_advance")
		next(dialogue_line.next_id)

func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	if SoundManager: SoundManager.play_sfx("dialogue_advance")
	next(response.next_id)

func _on_dialogue_label_spoke(letter: String, letter_index: int, speed: float) -> void:
	if letter == " ": return
	# if SoundManager: SoundManager.play_dialogue_blip()

#endregion


#region Dialogue Toggle Button

func _create_toggle_button() -> void:
	var toggle_scene = load("res://dialogue_toggle_ui.tscn")
	var toggle_panel = toggle_scene.instantiate()
	balloon.add_child(toggle_panel)
	dialogue_toggle_button = toggle_panel.get_node("ToggleIcon")
	dialogue_toggle_button.toggled_visibility.connect(_on_dialogue_toggle)

func _on_dialogue_toggle(is_visible: bool) -> void:
	var panel = $Balloon/Panel
	panel.visible = is_visible
	dialogue_container.visible = is_visible
	$Balloon/Responses.visible = is_visible
	
	# Only restore character elements if we are toggling ON, and the current line requires them
	if is_visible and dialogue_line != null:
		var raw_name = dialogue_line.character
		name_panel.visible = not raw_name.is_empty()
		
		# Check if the portrait should be visible too
		var regex = RegEx.new()
		regex.compile("\\[.*?\\]")
		var lookup_key = regex.sub(raw_name, "", true).strip_edges()
		
		# TOGGLE THE CONTAINER
		portrait_container.visible = character_portraits.has(lookup_key)
	else:
		# Always hide them when toggling OFF
		name_panel.visible = false
		portrait_container.visible = false

func _restore_dialogue_visibility() -> void:
	if dialogue_toggle_button:
		dialogue_toggle_button.set_dialogue_visible(true)
	
	# Reuse the smart toggle logic to safely turn the UI back on
	_on_dialogue_toggle(true)
#endregion
