# DialogueHistory.gd (Autoload) — session log of dialogue lines, choices, and player actions.
extends Node

const MAX_ENTRIES = 100
var entries: Array[Dictionary] = []
var visited_responses: Dictionary = {}


func add_line(lookup_name: String, display_name: String, text: String):
	entries.append({
		"type": "line",
		"lookup_name": lookup_name,
		"display_name": display_name,
		"text": text
	})
	_trim()


func add_choice(lookup_name: String, display_name: String, options: Array[String], selected_index: int):
	entries.append({
		"type": "choice",
		"lookup_name": lookup_name,
		"display_name": display_name,
		"options": options,
		"selected_index": selected_index
	})
	_trim()


func add_action(verb_name: String, object_name: String, item_name: String = ""):
	entries.append({
		"type": "action",
		"verb": verb_name,
		"object": object_name,
		"item": item_name
	})
	_trim()


func _trim():
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()


func reset():
	entries.clear()
	visited_responses.clear()
