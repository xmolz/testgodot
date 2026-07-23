extends DialogueLabel
# skips the typewriter auto-pause for

func _should_auto_pause() -> bool:
	var parsed_text: String = get_parsed_text()
	var i := visible_characters - 1
	if i >= 1 and visible_characters < parsed_text.length() and parsed_text[i] == ".":
		var prev := parsed_text[i - 1]
		var two_back := parsed_text[i - 2] if i >= 2 else " "
		if prev == prev.to_upper() and prev != prev.to_lower() and (two_back == "." or two_back == " "):
			return false
	return super()
