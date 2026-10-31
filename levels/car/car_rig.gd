extends Control
## step 2.386: the car art as a stack of layers, drawn in the art's own order: runs of fixed layers (the
## car, the foreground...), one layer per slot showing its current option (Fiona's poses, eyes, mouths;
## Layla's poses and face parts), and extra pieces of an option that sit at another depth. everything
## comes from the manifest written by Dev/car_test/car_parts_cutter.gd (rev 4). the rig scales itself
## once to cover its parent; anything that moves or tints it (vibration, bumps, a push-in, the time-of-
## day tint) moves and tints every layer with it.
##   apply("sideways smile hand_up", "fiona_")   set several parts by option name (crossfades)
##   apply("default", "fiona_")                  every fiona_ slot back to its default
##   set_part("fiona_eyes", "sideways")          one slot directly

@export_file("*.json") var manifest_path: String = "res://Backgrounds/Car/parts/car_parts.json"
@export var fade_seconds: float = 0.12
## the art is scaled up this much so its edges never show during a bump
@export var overscan: float = 1.03
## 1 = the art covers the parent; 2 = twice that (the car ride zooms its world instead)
var zoom: float = 1.0
## the art pixel kept at the centre of the parent
var focus: Vector2 = Vector2(1920, 1080)
## extra offset in the parent's pixels (vibration, bumps)
var offset: Vector2 = Vector2.ZERO

var canvas: Vector2 = Vector2(3840, 2160)
var loaded: bool = false

var _stack: Control
var _outline_layer: Control
# slot -> {"rect": Rect2i, "default": String, "textures": {option: Texture2D}, "rects": {option: Rect2i},
#          "current": String, "node": TextureRect, "holder": Control, "covers": Array,
#          "holder_tween": Tween, "pieces": [{"variant": String, "node": TextureRect, "tween": Tween}]}
var _slots: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_stack = Control.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	_outline_layer = Control.new()
	_outline_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline_layer.visible = false
	add_child(_outline_layer)
	loaded = _load_manifest()


func _load_manifest() -> bool:
	if not FileAccess.file_exists(manifest_path):
		push_warning("car_rig: no manifest at %s. run Dev/car_test/car_parts_cutter.gd first." % manifest_path)
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("car_rig: %s is not valid JSON." % manifest_path)
		return false
	if int(data.get("format", 1)) < 2:
		push_warning("car_rig: %s is from an older cutter. run Dev/car_test/car_parts_cutter.gd again." % manifest_path)
		return false
	var c: Array = data.get("canvas", [3840, 2160])
	canvas = Vector2(float(c[0]), float(c[1]))
	focus = canvas * 0.5
	size = canvas
	_stack.size = canvas

	var slots: Dictionary = data.get("slots", {})
	for slot in slots:
		var s: Dictionary = slots[slot]
		var textures := {}
		var rects := {}
		var variants: Dictionary = s.get("variants", {})
		for v in variants:
			var p: String = String(variants[v]["path"])
			if ResourceLoader.exists(p):
				textures[v] = load(p)
				rects[v] = _rect(variants[v]["rect"])
			else:
				push_warning("car_rig: part %s not found (not imported yet?)." % p)
		var d: String = String(s.get("default", ""))
		_slots[slot] = {"rect": _rect(s.get("rect", [0, 0, 0, 0])), "default": d, "textures": textures, "rects": rects,
			"current": d, "node": null, "holder": null, "covers": Array(s.get("covers", [])),
			"shown_with": Array(s.get("shown_with", [])),   # step 2.387
			"holder_tween": null, "pieces": []}
		var outline := ReferenceRect.new()
		outline.editor_only = false
		outline.border_color = Color(1.0, 0.3, 0.55)
		outline.border_width = 4.0
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r: Rect2i = _slots[slot]["rect"]
		outline.position = Vector2(r.position)
		outline.size = Vector2(r.size)
		_outline_layer.add_child(outline)

	var fixed_count := 0
	for item in data.get("stack", []):
		if item.has("fixed"):
			var p: String = String(item["fixed"])
			if not ResourceLoader.exists(p):
				push_warning("car_rig: %s not found (not imported yet?)." % p)
				continue
			_stack.add_child(_layer(load(p), _rect(item["rect"]), 1.0))
			fixed_count += 1
		elif item.has("slot"):
			var slot: String = String(item["slot"])
			if not _slots.has(slot):
				continue
			var holder := Control.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stack.add_child(holder)
			_slots[slot]["holder"] = holder
		elif item.has("piece"):
			var slot: String = String(item["piece"])
			var p: String = String(item["path"])
			if not _slots.has(slot) or not ResourceLoader.exists(p):
				push_warning("car_rig: piece %s not found (not imported yet?)." % p)
				continue
			var variant: String = String(item["variant"])
			var node := _layer(load(p), _rect(item["rect"]), 1.0 if variant == _slots[slot]["current"] else 0.0)
			_stack.add_child(node)
			_slots[slot]["pieces"].append({"variant": variant, "node": node, "tween": null})
	if fixed_count == 0:
		push_warning("car_rig: no fixed layers in %s (not imported yet?)." % manifest_path)
		return false
	for slot in _slots:
		_show(_slots[slot], String(_slots[slot]["default"]), 0.0)
	return true


func get_slots(prefix: String = "") -> Array:
	var names: Array = []
	for slot in _slots:
		if String(slot).begins_with(prefix):
			names.append(slot)
	names.sort()
	return names


## every option of a slot, the default first
func get_options(slot: String) -> Array:
	if not _slots.has(slot):
		return []
	var names: Array = _slots[slot]["textures"].keys()
	names.sort()
	names.erase(String(_slots[slot]["default"]))
	names.push_front(_slots[slot]["default"])
	return names


func get_current(slot: String) -> String:
	return String(_slots[slot]["current"]) if _slots.has(slot) else ""


func get_slot_rect(slot: String) -> Rect2i:
	return _slots[slot]["rect"] if _slots.has(slot) else Rect2i()


func set_outlines_visible(on: bool) -> void:
	_outline_layer.visible = on


## option names separated by spaces, each switched in whichever slot (starting with prefix) has it.
## "default" puts every slot starting with prefix back to its default.
func apply(spec: String, prefix: String = "", seconds: float = -1.0) -> void:
	for word in spec.split(" ", false):
		if word == "default":
			for slot in get_slots(prefix):
				set_part(slot, _slots[slot]["default"], seconds)
			continue
		var hit := false
		for slot in get_slots(prefix):
			if word == _slots[slot]["default"] or _slots[slot]["textures"].has(word):
				set_part(slot, word, seconds)
				hit = true
				break
		if not hit:
			push_warning("car_rig: no %s option called \"%s\"." % [prefix + "*" if prefix != "" else "slot", word])


func set_part(slot: String, option: String, seconds: float = -1.0) -> void:
	if not _slots.has(slot):
		push_warning("car_rig: no slot \"%s\"." % slot)
		return
	var info: Dictionary = _slots[slot]
	if option == String(info["current"]):
		return
	if option != String(info["default"]) and not info["textures"].has(option):
		push_warning("car_rig: slot \"%s\" has no option \"%s\"." % [slot, option])
		return
	_show(info, option, fade_seconds if seconds < 0.0 else seconds)


# a slot shows `option` as its own layer in its box (nothing, for an option with no texture, like an
# empty "no_blush" default); the new one fades in while the old one fades out. the slot's pieces at
# other depths follow, and slots it covers are hidden or shown again.
func _show(info: Dictionary, option: String, t: float) -> void:
	var old: TextureRect = info["node"]
	var new: TextureRect = null
	if info["textures"].has(option) and info["holder"] != null:
		new = _layer(info["textures"][option], info["rects"][option], 0.0 if t > 0.0 else 1.0)
		info["holder"].add_child(new)
	info["node"] = new
	info["current"] = option
	for piece in info["pieces"]:
		var target: float = 1.0 if piece["variant"] == option else 0.0
		piece["tween"] = _fade(piece["node"], target, t, piece["tween"])
	_apply_covers(t)
	if t <= 0.0:
		if old:
			old.queue_free()
		return
	# step 2.414: the new layer fades in over the old one, and only then does the old one fade out. fading
	# both at once let whatever is underneath show through for a moment (at the halfway point, two half-
	# transparent layers only cover three quarters).
	var tw := create_tween().set_parallel(true)
	if new:
		tw.tween_property(new, "modulate:a", 1.0, t)
	if old:
		tw.tween_property(old, "modulate:a", 0.0, t).set_delay(t)
		tw.chain().tween_callback(old.queue_free)


# a slot showing anything other than its default hides the slots it covers; they fade out with it coming
# in, and back in when it goes
func _apply_covers(t: float) -> void:
	var hidden := {}
	for slot in _slots:
		var info: Dictionary = _slots[slot]
		if not info["covers"].is_empty() and String(info["current"]) != String(info["default"]):
			for c in info["covers"]:
				hidden[String(c)] = true
		# step 2.387: shown only while another slot shows one option (her sideways face with her sideways pose)
		var sw: Array = info["shown_with"]
		if sw.size() == 2 and _slots.has(String(sw[0])) and String(_slots[String(sw[0])]["current"]) != String(sw[1]):
			hidden[String(slot)] = true
	for slot in _slots:
		var info: Dictionary = _slots[slot]
		if info["holder"] == null:
			continue
		info["holder_tween"] = _fade(info["holder"], 0.0 if hidden.has(slot) else 1.0, t, info["holder_tween"])


func _fade(node: CanvasItem, target: float, t: float, old_tween: Tween) -> Tween:
	if old_tween and old_tween.is_valid():
		old_tween.kill()
	if t <= 0.0 or is_equal_approx(node.modulate.a, target):
		node.modulate.a = target
		return null
	var tw := create_tween()
	# step 2.414: a layer going away (a piece, or a slot another part now covers) waits until what replaces
	# it has faded in, as in _show()
	if target < node.modulate.a:
		tw.tween_interval(t)
	tw.tween_property(node, "modulate:a", target, t)
	return tw


func _layer(tex: Texture2D, r: Rect2i, alpha: float) -> TextureRect:
	var node := TextureRect.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.texture = tex
	node.position = Vector2(r.position)
	node.size = Vector2(r.size)
	node.modulate.a = alpha
	return node


func _rect(r: Array) -> Rect2i:
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


func _process(_delta: float) -> void:
	var area := get_parent_area_size()
	if area.x <= 0.0 or area.y <= 0.0:
		return
	var cover: float = maxf(area.x / canvas.x, area.y / canvas.y) * overscan
	var s: float = cover * zoom
	scale = Vector2(s, s)
	position = area * 0.5 - focus * s + offset
