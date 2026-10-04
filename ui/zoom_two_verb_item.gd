# zoom_two_verb_item.gd — zoom-view item that answers to both mouse buttons.
# left click = examine, right click = pick up (only when can_pick_up); the verb is
# named per click, so the zoom needs no sticky verb. while hovered, the action
# bubble shows the available actions with mouse glyphs
# (GameManager.update_sentence_line_ui asks build_mouse_hint_sentence).
# items with can_pick_up = false ignore the right button entirely.
# touch devices: a tap is a left click, so it examines; no pickup on touch yet.
extends "res://ui_interactable.gd"

const LEFT_VERB_ID := "examine"
const RIGHT_VERB_ID := "pickup"

@export var can_pick_up: bool = false

var _last_button_index: int = MOUSE_BUTTON_LEFT


func _ready() -> void:
	super._ready()
	# the right button only reaches items that can be picked up; on anything else a
	# right click passes through and nothing happens.
	if can_pick_up and not OS.has_feature("mobile"):
		button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	gui_input.connect(_on_gui_input)


# the gui_input signal fires before the button emits pressed, so this records
# which mouse button the press or release belongs to.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_last_button_index = event.button_index


func _on_button_pressed():
	if not GameManager or not GameManager.has_method("process_interaction_click_with_verb"):
		super._on_button_pressed()
		return
	var verb_id: String = LEFT_VERB_ID
	if can_pick_up and _last_button_index == MOUSE_BUTTON_RIGHT:
		verb_id = RIGHT_VERB_ID
	GameManager.process_interaction_click_with_verb(interactable_logic, verb_id)


# sentence for the action bubble; {LMB}/{RMB} become mouse glyphs in VerbUI.gd.
func build_mouse_hint_sentence(object_colored: String) -> String:
	var examine_text := _verb_text(LEFT_VERB_ID)
	if can_pick_up:
		return "{LMB} %s %s     {RMB} %s" % [examine_text, object_colored, _verb_text(RIGHT_VERB_ID)]
	return "{LMB} %s %s" % [examine_text, object_colored]


func _verb_text(verb_id: String) -> String:
	var verb_data = Verbs.get_verb_data_by_id(verb_id) if GameManager else null
	return verb_data.display_text if verb_data else verb_id
