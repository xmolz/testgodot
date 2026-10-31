extends Control
## step 2.298 rev 2 (dev test): the car art at its native pixel size, with small overlays laid over it
## (expressions, later poses). everything comes from the manifest that car_parts_cutter.gd writes:
## the base frame, each slot's box, its default and its overlays.
## the rig scales itself once to cover its parent, so anything that moves it (vibration, bumps, a
## push-in) moves every overlay with it, and the boxes always line up with the art.
##   set_part("fiona_face", "smile_straight")   crossfade to that overlay
##   set_part("fiona_face", "")                 no overlay (the bare base)

@export_file("*.json") var manifest_path: String = "res://Dev/car_test/parts/car_parts.json"
@export var fade_seconds: float = 0.15
## the art is scaled up this much so its edges never show during a bump (as in the car ride)
@export var overscan: float = 1.03
## 1 = the art covers the screen; 2 = twice that
var zoom: float = 1.0
## the art pixel kept at the centre of the screen
var focus: Vector2 = Vector2(1920, 1080)
## extra screen offset (vibration, bumps)
var offset: Vector2 = Vector2.ZERO

var canvas: Vector2 = Vector2(3840, 2160)
var loaded: bool = false

var _base: TextureRect
var _patch_layer: Control
var _outline_layer: Control
# slot -> {"rect": Rect2i, "default": String, "textures": {variant: Texture2D}, "current": String, "node": TextureRect}
var _slots: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_base = TextureRect.new()
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_base.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_base)
	_patch_layer = Control.new()
	_patch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_patch_layer)
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
	var c: Array = data.get("canvas", [3840, 2160])
	canvas = Vector2(float(c[0]), float(c[1]))
	focus = canvas * 0.5
	size = canvas
	_base.size = canvas
	var base_path: String = String(data.get("base", ""))
	if ResourceLoader.exists(base_path):
		_base.texture = load(base_path)
	else:
		push_warning("car_rig: base image %s not found (not imported yet?)." % base_path)
	var slots: Dictionary = data.get("slots", {})
	for slot in slots:
		var s: Dictionary = slots[slot]
		var r: Array = s.get("rect", [0, 0, 0, 0])
		var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		var textures := {}
		var variants: Dictionary = s.get("variants", {})
		for v in variants:
			var p: String = String(variants[v])
			if ResourceLoader.exists(p):
				textures[v] = load(p)
			else:
				push_warning("car_rig: patch %s not found (not imported yet?)." % p)
		_slots[slot] = {"rect": rect, "default": String(s.get("default", "")), "textures": textures, "current": "", "node": null}
		var outline := ReferenceRect.new()
		outline.editor_only = false
		outline.border_color = Color(1.0, 0.3, 0.55)
		outline.border_width = 4.0
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.position = Vector2(rect.position)
		outline.size = Vector2(rect.size)
		_outline_layer.add_child(outline)
	for slot in _slots:
		var d: String = _slots[slot]["default"]
		if d != "":
			set_part(slot, d, 0.0)
	return true


func get_variants(slot: String) -> Array:
	if not _slots.has(slot):
		return []
	var names: Array = _slots[slot]["textures"].keys()
	names.sort()
	return names


func get_current(slot: String) -> String:
	return String(_slots[slot]["current"]) if _slots.has(slot) else ""


func get_default(slot: String) -> String:
	return String(_slots[slot]["default"]) if _slots.has(slot) else ""


func get_slot_rect(slot: String) -> Rect2i:
	return _slots[slot]["rect"] if _slots.has(slot) else Rect2i()


func set_outlines_visible(on: bool) -> void:
	_outline_layer.visible = on


func set_part(slot: String, variant: String, seconds: float = -1.0) -> void:
	if not _slots.has(slot):
		push_warning("car_rig: no slot \"%s\"." % slot)
		return
	var info: Dictionary = _slots[slot]
	if variant == String(info["current"]):
		return
	if variant != "" and not info["textures"].has(variant):
		push_warning("car_rig: slot \"%s\" has no variant \"%s\"." % [slot, variant])
		return
	var t: float = fade_seconds if seconds < 0.0 else seconds
	var old: TextureRect = info["node"]
	var new: TextureRect = null
	if variant != "":
		new = TextureRect.new()
		new.mouse_filter = Control.MOUSE_FILTER_IGNORE
		new.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		new.stretch_mode = TextureRect.STRETCH_SCALE
		new.texture = info["textures"][variant]
		var rect: Rect2i = info["rect"]
		new.position = Vector2(rect.position)
		new.size = Vector2(rect.size)
		new.modulate.a = 0.0 if t > 0.0 else 1.0
		_patch_layer.add_child(new)
	info["node"] = new
	info["current"] = variant
	if t <= 0.0:
		if old:
			old.queue_free()
		return
	# overlays: the old one fades out while the new one fades in
	var tw := create_tween().set_parallel(true)
	if new:
		tw.tween_property(new, "modulate:a", 1.0, t)
	if old:
		tw.tween_property(old, "modulate:a", 0.0, t)
		tw.chain().tween_callback(old.queue_free)


func _process(_delta: float) -> void:
	var area := get_parent_area_size()
	if area.x <= 0.0 or area.y <= 0.0:
		return
	var cover: float = maxf(area.x / canvas.x, area.y / canvas.y) * overscan
	var s: float = cover * zoom
	scale = Vector2(s, s)
	position = area * 0.5 - focus * s + offset
