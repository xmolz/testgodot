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

# --- Character Background Color Lookup Table ---
var character_colors: Dictionary = {
	"AIda": Color("#20B2AA"),   # Light Sea Green
	"Sergey": Color("#DAA520"), # Goldenrod
	"McBucket": Color("#6B8E23"), # Olive Drab
	"Nathan": Color("#FF69B4"),  # Hot Pink
	"Dread": Color("#4B0082")    # Indigo (Example for your screenshot)
}

# --- Character Portrait Lookup Table ---
var character_portraits: Dictionary = {
	"AIda": preload("res://test_character_portrait.jpg"), 
	"Sergey": preload("res://sergei.PNG"),
	"McBucket": preload("res://mcbucket.png"),
	"Nathan": preload("res://icon.svg")
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

## Reference to the Portrait TextureRect
@onready var portrait_rect: TextureRect = %PortraitRect

## Reference to the Name Panel Container
@onready var name_panel: PanelContainer = $Balloon/NamePanel

## Reference to the Dialogue Container
@onready var dialogue_container: MarginContainer = $Balloon/Dialogue


func _ready() -> void:
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
		portrait_rect.visible = true
		dialogue_container.add_theme_constant_override("margin_left", 230)
	else:
		portrait_rect.visible = false
		dialogue_container.add_theme_constant_override("margin_left", 30)

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	balloon.show()
	will_hide_balloon = false

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
