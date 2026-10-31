extends Control
## step 2.359 / 2.361: a viewer for a rigged character (run Dev/rig_tools/rig_viewer.tscn with F6).
## shows the character built from her parts, with keys to flip through every part and to save the
## combinations you like as named expressions - the names dialogue will use later, like
## actor_change("Layla", "happy"). N switches character (Layla, Fiona, Julian, Jayce).
##   1-9    next variant of that slot (Shift: previous)   P   next saved expression (Shift: previous)
##   S      save the current parts as an expression       X   delete the current expression (press twice)
##   R      back to the defaults                          C   copy the parts list
##   B      background: dark / grey / light / checker     Z   fit to screen / actual pixels
##   F      flip                                          O   show the patch boxes
##   L      reload the parts (after running the cutter again)

## the character's parts (written by Dev/rig_tools/rig_parts_cutter.gd)
var parts_path := "res://characters/layla/parts/layla_parts.json"
## step 2.401: N switches to the next character in CHARACTERS (Shift+N the previous one). each one's parts
## are at res://characters/<name>/parts/<name>_parts.json and its expressions at
## res://characters/<name>/<name>_expressions.json.
const CHARACTERS := ["layla", "fiona", "julian", "jayce"]
var _character_index := 0
## her named expressions: {"name": "parts list"}. kept outside the parts folder, so cutting again never
## touches it
var expressions_path := "res://characters/layla/layla_expressions.json"

const Composer = preload("res://characters/rig/actor_rig_composer.gd")
const BACKGROUNDS := [Color(0.13, 0.14, 0.17), Color(0.5, 0.5, 0.52), Color(0.92, 0.92, 0.9)]

var _bg: ColorRect
var _checker: TextureRect
var _pic: TextureRect
var _boxes: Control
var _info: Label
var _list: Label
var _save_box: PanelContainer
var _name_edit: LineEdit
var _choice: Dictionary = {}
var _bg_index := 0
var _fit := true
var _show_boxes := false
var _rig: Dictionary = {}
var _expressions: Dictionary = {}
var _current := ""          # the expression last picked or saved ("" = none)
var _delete_armed := false
var _message := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg = ColorRect.new()
	_bg.color = BACKGROUNDS[0]
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_checker = TextureRect.new()
	_checker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_checker.texture = _make_checker()
	_checker.stretch_mode = TextureRect.STRETCH_TILE
	_checker.visible = false
	add_child(_checker)
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_pic)
	_boxes = Control.new()
	_boxes.draw.connect(_draw_boxes)
	_pic.add_child(_boxes)
	_info = _make_label(Vector2(24, 20))
	_list = _make_label(Vector2(0, 20))
	_build_save_box()
	resized.connect(_layout)
	_load()


func _make_label(at: Vector2) -> Label:
	var l := Label.new()
	l.position = at
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _build_save_box() -> void:
	_save_box = PanelContainer.new()
	_save_box.visible = false
	var row := VBoxContainer.new()
	_save_box.add_child(row)
	var prompt := Label.new()
	prompt.text = "Save these parts as an expression named:   (Enter to save, Esc to cancel)"
	row.add_child(prompt)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(520, 0)
	_name_edit.text_submitted.connect(_on_name_submitted)
	row.add_child(_name_edit)
	add_child(_save_box)


func _load() -> void:
	Composer.clear_cache()
	_rig = Composer.load_rig(parts_path)
	_choice = Composer.resolve(_rig, "") if not _rig.is_empty() else {}
	_load_expressions()
	_rebuild()


func _load_expressions() -> void:
	_expressions = {}
	if FileAccess.file_exists(expressions_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(expressions_path))
		if data is Dictionary:
			_expressions = data


func _save_expressions() -> bool:
	var f := FileAccess.open(expressions_path, FileAccess.WRITE)
	if f == null:
		_message = "Couldn't write " + expressions_path
		return false
	f.store_string(JSON.stringify(_expressions, "\t", true) + "\n")
	f.close()
	return true


func _names() -> Array:
	var names: Array = _expressions.keys()
	names.sort()
	return names


func _parts_string() -> String:
	var words: Array[String] = []
	for slot_data in _rig.get("slots", []):
		words.append(String(_choice.get(slot_data["name"], "")))
	return " ".join(words)


func _rebuild() -> void:
	if _rig.is_empty():
		_pic.texture = null
		_info.text = "No parts at %s.\nRun its cutter in Dev/rig_tools/ first.   (N: next character)" % parts_path
		_list.text = ""
		return
	_pic.texture = Composer.compose(parts_path, _parts_string())
	_layout()
	_boxes.queue_redraw()
	var size: Array = _rig["size"]
	var canvas: Array = _rig.get("source_canvas", size)
	var lines: Array[String] = []
	lines.append("%s   canvas %dx%d, stored %dx%d   (one picture in video memory: %.1f MB)" % [_rig.get("character", "?"), canvas[0], canvas[1], size[0], size[1], size[0] * size[1] * 4.0 / 1048576.0])
	var n := 1
	for slot_data in _rig["slots"]:
		var names: Array = slot_data["variants"].keys()
		names.sort()
		var cur: String = _choice.get(slot_data["name"], "")
		lines.append("[%d] %s: %s   (%d/%d)" % [n, slot_data["name"], cur, names.find(cur) + 1, names.size()])
		n += 1
	lines.append("parts: \"%s\"" % _parts_string())
	if _current != "":
		var changed := _expressions.has(_current) and Composer.resolve(_rig, String(_expressions[_current])) != _choice
		lines.append("expression: %s%s" % [_current, "   (changed - S to save)" if changed else ""])
	if _message != "":
		lines.append(_message)
	lines.append("1-9 parts  P expressions  S save  X delete  R reset  C copy  B background  Z fit/pixels  F flip  O boxes  L reload  N character")
	_info.text = "\n".join(lines)
	# the saved expressions, down the right-hand side
	var list_lines: Array[String] = ["Expressions (%s):" % expressions_path.get_file()]
	if _expressions.is_empty():
		list_lines.append("  none yet - S saves one")
	for name in _names():
		list_lines.append(("> " if name == _current else "   ") + name)
	_list.text = "\n".join(list_lines)
	_layout()


func _layout() -> void:
	_list.position.x = size.x - _list.size.x - 24.0
	_save_box.position = Vector2((size.x - 560.0) * 0.5, size.y * 0.42)
	if _pic.texture == null:
		return
	var tex_size := Vector2(_pic.texture.get_size())
	var scale_f := 1.0
	if _fit:
		scale_f = minf((size.y - 40.0) / tex_size.y, (size.x - 40.0) / tex_size.x)
	_pic.size = tex_size * scale_f
	_pic.position = (size - _pic.size) * 0.5
	_boxes.size = _pic.size


func _draw_boxes() -> void:
	if not _show_boxes or _rig.is_empty():
		return
	var canvas: Array = _rig.get("source_canvas", _rig["size"])
	var origin: Array = _rig.get("source_origin", [0, 0])
	var k: float = _pic.size.x / float(canvas[0])
	for slot_data in _rig["slots"]:
		if slot_data["name"] == _rig.get("base_slot", "body"):
			continue
		var entry = slot_data["variants"].get(_choice.get(slot_data["name"], ""))
		if entry:
			var r := Rect2(Vector2(entry["pos"][0] + origin[0], entry["pos"][1] + origin[1]) * k, Vector2(entry["size"][0], entry["size"][1]) * k)
			_boxes.draw_rect(r, Color(0.2, 0.85, 1.0), false, 2.0)


func _pick(name: String) -> void:
	_current = name
	_choice = Composer.resolve(_rig, String(_expressions[name]))
	_rebuild()


func _open_save_box() -> void:
	_save_box.visible = true
	_name_edit.text = _current
	_name_edit.grab_focus()
	_name_edit.select_all()


func _on_name_submitted(text: String) -> void:
	var name := text.strip_edges().to_lower().replace(" ", "_")
	var clean := ""
	for ch in name:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_":
			clean += ch
	_save_box.visible = false
	_name_edit.release_focus()
	if clean == "":
		_message = "Not saved: the name needs letters or numbers."
		_rebuild()
		return
	_expressions[clean] = _parts_string()
	if _save_expressions():
		_message = "Saved \"%s\" = \"%s\"" % [clean, _expressions[clean]]
	_current = clean
	_rebuild()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	if _save_box.visible:
		if key == KEY_ESCAPE:
			_save_box.visible = false
			_name_edit.release_focus()
		return
	if key != KEY_X:
		_delete_armed = false
	_message = ""
	if key >= KEY_1 and key <= KEY_9:
		var slots: Array = _rig.get("slots", [])
		var i: int = key - KEY_1
		if i < slots.size():
			var names: Array = slots[i]["variants"].keys()
			names.sort()
			var at: int = names.find(_choice.get(slots[i]["name"], ""))
			at = posmod(at + (-1 if event.shift_pressed else 1), names.size())
			_choice[slots[i]["name"]] = names[at]
			_rebuild()
		return
	match key:
		KEY_P:
			var names := _names()
			if names.is_empty():
				_message = "No expressions saved yet - S saves the current parts."
			else:
				var at: int = names.find(_current)
				at = posmod(at + (-1 if event.shift_pressed else 1), names.size()) if at >= 0 else (names.size() - 1 if event.shift_pressed else 0)
				_pick(names[at])
				return
			_rebuild()
		KEY_S:
			_open_save_box()
			get_viewport().set_input_as_handled()
		KEY_X:
			if _current == "" or not _expressions.has(_current):
				_message = "Pick an expression with P first."
			elif not _delete_armed:
				_delete_armed = true
				_message = "Press X again to delete \"%s\"." % _current
			else:
				_expressions.erase(_current)
				_save_expressions()
				_message = "Deleted \"%s\"." % _current
				_current = ""
				_delete_armed = false
			_rebuild()
		KEY_R:
			_current = ""
			_choice = Composer.resolve(_rig, "")
			_rebuild()
		KEY_C:
			DisplayServer.clipboard_set(_parts_string())
			_message = "Copied \"%s\"" % _parts_string()
			_rebuild()
		KEY_B:
			_bg_index = (_bg_index + 1) % (BACKGROUNDS.size() + 1)
			_checker.visible = _bg_index == BACKGROUNDS.size()
			_bg.color = BACKGROUNDS[_bg_index] if _bg_index < BACKGROUNDS.size() else Color(1, 1, 1)
		KEY_Z:
			_fit = not _fit
			_layout()
			_boxes.queue_redraw()
		KEY_F:
			_pic.flip_h = not _pic.flip_h
		KEY_O:
			_show_boxes = not _show_boxes
			_boxes.queue_redraw()
		KEY_L:
			_load()
			_message = "Reloaded."
			_rebuild()
		KEY_N:
			# step 2.401: the next character
			_character_index = posmod(_character_index + (-1 if event.shift_pressed else 1), CHARACTERS.size())
			var who: String = CHARACTERS[_character_index]
			parts_path = "res://characters/%s/parts/%s_parts.json" % [who, who]
			expressions_path = "res://characters/%s/%s_expressions.json" % [who, who]
			_current = ""
			_delete_armed = false
			_load()
			_message = "Showing %s." % who
			_rebuild()


func _make_checker() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, Color(0.8, 0.8, 0.8) if (x / 16 + y / 16) % 2 == 0 else Color(0.62, 0.62, 0.62))
	return ImageTexture.create_from_image(img)
