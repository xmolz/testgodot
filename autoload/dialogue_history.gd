# DialogueHistory.gd (Autoload) — session log of dialogue lines, choices, and player actions.
extends Node

const MAX_ENTRIES = 500
var entries: Array[Dictionary] = []
var visited_responses: Dictionary = {}

const SEEN_LINES_PATH = "user://seen_dialogue.save"
var seen_lines: Dictionary = {}

func _ready():
	load_seen_lines()

func mark_line_seen(key: String) -> void:
	seen_lines[key] = true

func is_line_seen(key: String) -> bool:
	return seen_lines.has(key)

func save_seen_lines() -> void:
	var f = FileAccess.open(SEEN_LINES_PATH, FileAccess.WRITE)
	if f: f.store_var(seen_lines)

func load_seen_lines() -> void:
	if FileAccess.file_exists(SEEN_LINES_PATH):
		var f = FileAccess.open(SEEN_LINES_PATH, FileAccess.READ)
		if f:
			var data = f.get_var()
			if data is Dictionary: seen_lines = data

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
