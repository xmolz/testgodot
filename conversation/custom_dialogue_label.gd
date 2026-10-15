extends DialogueLabel
# skips the typewriter auto-pause after initials (e.g. "J. Smith").
# step 2.215: expands [small] tags against the current base font size, installs the
# [mutter] effect, and drops the "." "?" "!" beats while a line is sped up with [speed].

const TextFx = preload("res://conversation/text_fx.gd")
const MutterEffect = preload("res://conversation/mutter_effect.gd")

## at or above this [speed=] multiplier, "." "?" "!" no longer pause the typing (rushed speech).
@export var rush_pause_speed: float = 2.0


func _ready() -> void:
	for fx in custom_effects:
		if fx is MutterEffect:
			return
	install_effect(MutterEffect.new())


func _update_text() -> void:
	if dialogue_line == null:
		return
	text = TextFx.expand_small(dialogue_line.text, get_theme_font_size("normal_font_size"))

func _should_auto_pause() -> bool:
	# rushed speech: no beats while the line is sped up (step 2.215)
	if dialogue_line != null and _get_speed(visible_characters) >= rush_pause_speed:
		return false
	var parsed_text: String = get_parsed_text()
	var i := visible_characters - 1
	if i >= 1 and visible_characters < parsed_text.length() and parsed_text[i] == ".":
		var prev := parsed_text[i - 1]
		var two_back := parsed_text[i - 2] if i >= 2 else " "
		if prev == prev.to_upper() and prev != prev.to_lower() and (two_back == "." or two_back == " "):
			return false
	return super()
