extends RefCounted
## step 2.401: talking mouths for rigged characters whose expressions keep the mouth shut (Fiona). her
## profile's talk_mouths says which mouth part fits which head (head variant -> mouth part, "*" = any other
## head). while she's speaking, AdvancedConversationOverlay shows her current parts with that mouth added,
## and takes it off again for everyone else's lines. dialogue only ever picks her pose and head.

const Composer = preload("res://characters/rig/actor_rig_composer.gd")


## step 2.434: the names in a speaker string. "Layla" -> ["Layla"]; "Layla & Jayce" -> ["Layla", "Jayce"].
static func speakers(speaker: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part in speaker.split("&"):
		var name := part.strip_edges()
		if not name.is_empty():
			out.append(name)
	return out


## true when this line is the character speaking out loud: her own name as the speaker (or "Player" for the
## protagonist), and not a thought in parentheses or a silent "...".
## step 2.434: a compound speaker ("Layla & Jayce") counts for each of them.
static func is_speaking(actor_id: String, is_protagonist: bool, speaker: String, text: String) -> bool:
	var names := speakers(speaker)
	if not (actor_id in names) and not (is_protagonist and "Player" in names):
		return false
	var said := text.strip_edges()
	return not (said.is_empty() or said.begins_with("(") or said == "..." or said == "…")


## the parts list for the same picture with the talking mouth on, or "" when there's no mouth for it
static func talking_parts(parts_path: String, parts: String, talk_mouths: Dictionary, head_slot: String) -> String:
	if talk_mouths.is_empty():
		return ""
	var rig: Dictionary = Composer.load_rig(parts_path)
	if rig.is_empty():
		return ""
	var head: String = String(Composer.resolve(rig, parts).get(head_slot, ""))
	var mouth: String = String(talk_mouths.get(head, talk_mouths.get("*", "")))
	return "" if mouth == "" else parts + " " + mouth
