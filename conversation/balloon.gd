extends CanvasLayer
# a basic dialogue balloon for use with dialogue manager.

# the action to use for advancing the dialogue
@export var next_action: StringName = &"ui_accept"

# the action to use to skip typing the dialogue
@export var skip_action: StringName = &"ui_cancel"

# the dialogue resource
var resource: DialogueResource

# temporary game state
var temporary_game_states: Array = []

# see if we are waiting for the player
var is_waiting_for_input: bool = false

# see if we are running
var will_hide_balloon: bool = false

# a dictionary to store any ephemeral variable
var locals: Dictionary = {}

var _locale: String = TranslationServer.get_locale()

# the current line
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# the dialogue has finished so close the balloon
			queue_free()
	get:
		return dialogue_line

# a cooldown timer for delaying
var mutation_cooldown: Timer = Timer.new()

# the base balloon anchor
@onready var balloon: Control = %Balloon

# the label showing the name
@onready var character_label: RichTextLabel = %CharacterLabel

# the label showing the currently spoken dialogue
@onready var dialogue_label: DialogueLabel = %DialogueLabel

# the menu of response
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu


func _ready() -> void:
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	# if the responses menu doesn't
	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)



func _unhandled_input(_event: InputEvent) -> void:
	# only the balloon is allowed
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# detect a change of locale
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio = dialogue_label.visible_ratio
		self.dialogue_line = await resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


# start some dialogue
func start(dialogue_resource: DialogueResource, title: String, extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	resource = dialogue_resource
	self.dialogue_line = await resource.get_next_dialogue_line(title, temporary_game_states)


# apply any changes to the
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	# show our balloon
	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	# wait for input
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


# go to the next line
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
	# see if we need to skip typing of the dialogue
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	# when there are no response
	get_viewport().set_input_as_handled()

	# ////////////////(modified section below)
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		# play the sound when clicking to go next
		SoundManager.play_sfx("ui_click")
		next(dialogue_line.next_id)

	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		# play the sound when pressing space/enter to go next
		SoundManager.play_sfx("ui_click")
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	# play the sound when clicking a choice button
	SoundManager.play_sfx("ui_click")
	next(response.next_id)

# *******************[add this function]
func _on_dialogue_label_spoke(letter: String, letter_index: int, speed: float) -> void:
	# don't play sound for space
	if letter == " ":
		return

	SoundManager.play_dialogue_blip()

#endregion
