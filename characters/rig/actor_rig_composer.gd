extends RefCounted
class_name ActorRigComposer
## step 2.359: builds a character's picture from rig parts (written by Dev/rig_tools/rig_parts_cutter.gd):
## the body pose, with each other slot's patch drawn on top in order. a parts list is a few words, each
## a variant name from any slot, in any order - e.g. "regular open_happy" - and slots it doesn't name
## show their default. compose() returns one texture; only that picture sits in video memory.

static var _rigs: Dictionary = {}   # parts json path -> the loaded rig


## the loaded rig (cached): {"size", "base_slot", "slots": [{name, order, default, variants: {name: {img, pos}}}]}
static func load_rig(parts_path: String) -> Dictionary:
	if _rigs.has(parts_path):
		return _rigs[parts_path]
	if not FileAccess.file_exists(parts_path):
		push_warning("ActorRigComposer: no parts map at " + parts_path)
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(parts_path))
	if not data is Dictionary:
		push_warning("ActorRigComposer: can't read " + parts_path)
		return {}
	var folder := parts_path.get_base_dir()
	for slot_data in data["slots"]:
		for v in slot_data["variants"]:
			var entry: Dictionary = slot_data["variants"][v]
			# load the picture, take its pixels, and let the texture go again (only the composed
			# picture should live in video memory)
			# step 2.363: an optional slot's "nothing" variant has no file
			if String(entry["file"]) == "":
				entry["img"] = null
				continue
			var tex = ResourceLoader.load(folder.path_join(entry["file"]), "", ResourceLoader.CACHE_MODE_IGNORE)
			var img: Image = tex.get_image() if tex else null
			if img:
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
			entry["img"] = img
	_rigs[parts_path] = data
	return data


## slot name -> variant, starting from the defaults and applying each word of the parts list
static func resolve(rig: Dictionary, parts: String) -> Dictionary:
	var choice := {}
	for slot_data in rig.get("slots", []):
		choice[slot_data["name"]] = slot_data["default"]
	for word in parts.split(" ", false):
		var found := false
		for slot_data in rig.get("slots", []):
			if slot_data["variants"].has(word):
				choice[slot_data["name"]] = word
				found = true
				break
		if not found:
			push_warning("ActorRigComposer: no part called '%s'" % word)
	return choice


static func compose_image(parts_path: String, parts: String) -> Image:
	var rig := load_rig(parts_path)
	if rig.is_empty():
		return null
	var choice := resolve(rig, parts)
	var base_slot: String = rig.get("base_slot", "body")
	var out: Image = null
	for slot_data in rig["slots"]:
		if slot_data["name"] == base_slot:
			var base_entry = slot_data["variants"].get(choice[base_slot])
			if base_entry and base_entry["img"]:
				out = base_entry["img"].duplicate()
	if out == null:
		push_warning("ActorRigComposer: no base picture in " + parts_path)
		return null
	for slot_data in rig["slots"]:
		if slot_data["name"] == base_slot:
			continue
		var entry = slot_data["variants"].get(choice[slot_data["name"]])
		if entry == null or entry["img"] == null:
			continue
		var p: Array = entry["pos"]
		out.blend_rect(entry["img"], Rect2i(Vector2i.ZERO, entry["img"].get_size()), Vector2i(int(p[0]), int(p[1])))
	return out


## step 2.360: the picture keeps the size of the canvas it was drawn on (e.g. 1100x1740, like every
## other character), so scaling and placement match the rest of the cast. only the trimmed part - where
## the character actually is - is stored in video memory; the empty border is a margin, not pixels.
static func compose(parts_path: String, parts: String) -> Texture2D:
	var img := compose_image(parts_path, parts)
	if img == null:
		return null
	var tex := ImageTexture.create_from_image(img)
	var rig := load_rig(parts_path)
	var canvas = rig.get("source_canvas")
	var origin = rig.get("source_origin")
	if not (canvas is Array and origin is Array):
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(Vector2.ZERO, Vector2(img.get_size()))
	at.margin = Rect2(float(origin[0]), float(origin[1]), float(canvas[0]) - img.get_width(), float(canvas[1]) - img.get_height())
	return at


## forget loaded rigs (e.g. after cutting new parts)
static func clear_cache() -> void:
	_rigs.clear()
