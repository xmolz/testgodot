extends RefCounted
## step 2.359: cuts a character's layered exports into a rig: one picture per body pose plus small
## patches for everything else (eyes, mouth, brows...), and a parts map (<character>_parts.json).
## run through Dev/rig_tools/rig_parts_cutter.gd (an EditorScript: File > Run, or Ctrl+Shift+X).
##
## source files: full-canvas PNG layers named <order>_<character>_<slot> @<variant>.png, e.g.
##   1_layla_body@hand_on_waist.png   2_layla_eyes@regular.png   3_layla_mouth@smile.png
## <order> is the drawing order (lowest at the back). the base slot (body) is kept whole; every other
## layer is cut down to the box around its pixels, with its place recorded in the map.
## stray specks (tiny clusters far from everything else) are erased first, so they can't blow up a
## patch's box. everything is trimmed to the box around all layers (plus a little padding), which also
## removes the empty canvas above the head.
## step 2.363: on the base layers (the body poses) a speck counts as stray when it's more than
## body_stray_px pixels from any real part of the drawing - so leftovers next to an elbow go too, not
## only ones outside the figure. erase_at removes particular clusters by hand: file name -> points on
## the source canvas; the cluster under (or within a few pixels of) each point is erased.
## optional slots (blush, tears...) get an extra "nothing" variant, e.g. no_blush, that draws nothing.

const NAME_PATTERN := "^(\\d+)_([a-z0-9]+)_([a-z0-9_]+)@([a-z0-9_]+)\\.png$"


## returns a report: {"ok": bool, "lines": [...]}. defaults: slot -> variant used when a slot isn't named.
static func run(source_dir: String, out_dir: String, defaults: Dictionary = {}, base_slot: String = "body",
		pad: int = 8, min_keep: int = 32, stray_dist: int = 24, optional_slots: Dictionary = {},
		erase_at: Dictionary = {}, body_stray_px: int = 12) -> Dictionary:
	var lines: Array[String] = []
	var re := RegEx.new()
	re.compile(NAME_PATTERN)
	var dir := DirAccess.open(source_dir)
	if dir == null:
		return {"ok": false, "lines": ["can't open " + source_dir]}
	var layers: Array = []
	var character := ""
	for file_name in dir.get_files():
		var m := re.search(file_name)
		if m == null:
			if file_name.to_lower().ends_with(".png"):
				lines.append("skipped (name doesn't match <order>_<character>_<slot> @<variant>.png): " + file_name)
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(source_dir.path_join(file_name)))
		if img == null or img.is_empty():
			lines.append("couldn't load " + file_name)
			continue
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		character = m.get_string(2)
		layers.append({"order": int(m.get_string(1)), "slot": m.get_string(3), "variant": m.get_string(4), "file": file_name, "img": img})
	if layers.is_empty():
		return {"ok": false, "lines": lines + ["no layers found in " + source_dir]}
	var size: Vector2i = layers[0]["img"].get_size()
	for layer in layers:
		if layer["img"].get_size() != size:
			return {"ok": false, "lines": lines + ["%s is %s, but the others are %s: every layer must be the same canvas size" % [layer["file"], layer["img"].get_size(), size]]}
	# 1. strays
	var union := Rect2i()
	for layer in layers:
		var points = erase_at.get(layer["file"], erase_at.get(layer["file"].replace("@", " @"), erase_at.get(layer["file"].replace(" @", "@"), [])))
		for point in points:
			var erased: int = _erase_cluster_at(layer["img"], Vector2i(point[0], point[1]))
			lines.append("%s: erased the spot at %d,%d (%d pixels)" % [layer["file"], point[0], point[1], erased] if erased > 0 else "%s: nothing to erase at %d,%d" % [layer["file"], point[0], point[1]])
		var near_px: int = body_stray_px if layer["slot"] == base_slot else -1
		var removed: int = _clean_strays(layer["img"], min_keep, stray_dist, near_px)
		if removed > 0:
			lines.append("%s: removed %d stray pixel(s)" % [layer["file"], removed])
		var used: Rect2i = layer["img"].get_used_rect()
		layer["used"] = used
		if used.size == Vector2i.ZERO:
			lines.append("%s is empty" % layer["file"])
			continue
		union = used if union.size == Vector2i.ZERO else union.merge(used)
	# 2. the shared box, padded and kept on the canvas
	union = union.grow(pad).intersection(Rect2i(Vector2i.ZERO, size))
	lines.append("canvas %dx%d trimmed to %dx%d (from %d,%d)" % [size.x, size.y, union.size.x, union.size.y, union.position.x, union.position.y])
	# 3. write the parts
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var slots: Dictionary = {}
	for layer in layers:
		var slot: String = layer["slot"]
		if not slots.has(slot):
			slots[slot] = {"name": slot, "order": layer["order"], "variants": {}}
		var region: Rect2i = union if slot == base_slot else layer["used"]
		if region.size == Vector2i.ZERO:
			continue
		var part: Image = layer["img"].get_region(region)
		var out_name := "%s_%s @%s.png" % [character, slot, layer["variant"]]
		var err := part.save_png(ProjectSettings.globalize_path(out_dir.path_join(out_name)))
		if err != OK:
			lines.append("couldn't save " + out_name)
			continue
		var pos: Vector2i = region.position - union.position
		slots[slot]["variants"][layer["variant"]] = {"file": out_name, "pos": [pos.x, pos.y], "size": [region.size.x, region.size.y]}
	# 4. the parts map
	var slot_list: Array = slots.values()
	slot_list.sort_custom(func(a, b): return a["order"] < b["order"])
	for slot_data in slot_list:
		var names: Array = slot_data["variants"].keys()
		names.sort()
		var wanted: String = String(defaults.get(slot_data["name"], ""))
		slot_data["default"] = wanted if names.has(wanted) else (names[0] if not names.is_empty() else "")
	if not slots.has(base_slot):
		lines.append("WARNING: no '%s' layer - the rig needs one as its base" % base_slot)
	# step 2.363: optional slots get a variant that draws nothing, and it's their default
	for slot_data in slot_list:
		var none_name: String = String(optional_slots.get(slot_data["name"], ""))
		if none_name != "":
			slot_data["variants"][none_name] = {"file": "", "pos": [0, 0], "size": [0, 0]}
			slot_data["default"] = String(defaults.get(slot_data["name"], none_name))
	var parts := {
		"version": 1,
		"character": character,
		"base_slot": base_slot,
		"size": [union.size.x, union.size.y],
		"source_canvas": [size.x, size.y],
		"source_origin": [union.position.x, union.position.y],
		"slots": slot_list,
	}
	var json_path := out_dir.path_join("%s_parts.json" % character)
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "lines": lines + ["couldn't write " + json_path]}
	f.store_string(JSON.stringify(parts, "\t"))
	f.close()
	for slot_data in slot_list:
		var bits: Array[String] = []
		for v in slot_data["variants"]:
			var s: Array = slot_data["variants"][v]["size"]
			bits.append("%s %dx%d" % [v, s[0], s[1]])
		lines.append("%d %s (default %s): %s" % [slot_data["order"], slot_data["name"], slot_data["default"], ", ".join(bits)])
	lines.append("wrote " + json_path)
	return {"ok": true, "lines": lines}


## erases clusters smaller than min_keep pixels that sit more than stray_dist pixels away from every
## bigger cluster's box - or, with near_px >= 0, more than near_px pixels from any pixel of a bigger
## cluster. returns how many pixels were erased.
static func _clean_strays(img: Image, min_keep: int, stray_dist: int, near_px: int = -1) -> int:
	var used := img.get_used_rect()
	if used.size == Vector2i.ZERO:
		return 0
	var w := img.get_width()
	var data := img.get_data()
	var visited := PackedByteArray()
	visited.resize(w * img.get_height())
	# step 2.363: which cluster each pixel belongs to (0 = none), and which clusters are big
	var labels := PackedInt32Array()
	labels.resize(w * img.get_height())
	var big_ids := {}
	var next_id := 0
	var big_boxes: Array[Rect2i] = []
	var small: Array = []   # [pixel indices, box]
	var queue := PackedInt32Array()
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			var start := y * w + x
			if visited[start] == 1 or data[start * 4 + 3] == 0:
				continue
			# flood one cluster (8-connected)
			next_id += 1
			visited[start] = 1
			queue.resize(0)
			queue.append(start)
			var head := 0
			var minx := x
			var maxx := x
			var miny := y
			var maxy := y
			var pixels := PackedInt32Array()
			while head < queue.size():
				var i: int = queue[head]
				head += 1
				labels[i] = next_id
				var px := i % w
				var py := i / w
				minx = mini(minx, px)
				maxx = maxi(maxx, px)
				miny = mini(miny, py)
				maxy = maxi(maxy, py)
				if pixels.size() < min_keep:
					pixels.append(i)
				for dy in [-1, 0, 1]:
					var ny: int = py + dy
					if ny < used.position.y or ny >= used.end.y:
						continue
					for dx in [-1, 0, 1]:
						var nx: int = px + dx
						if nx < used.position.x or nx >= used.end.x:
							continue
						var j: int = ny * w + nx
						if visited[j] == 0 and data[j * 4 + 3] != 0:
							visited[j] = 1
							queue.append(j)
			var box := Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
			if queue.size() >= min_keep:
				big_boxes.append(box)
				big_ids[next_id] = true
			else:
				small.append([pixels, box])
	var removed := 0
	for entry in small:
		var box: Rect2i = entry[1]
		var near := false
		if near_px >= 0:
			# step 2.363: any pixel of a big cluster within near_px of this one's box?
			var win := box.grow(near_px).intersection(Rect2i(0, 0, w, img.get_height()))
			for y in range(win.position.y, win.end.y):
				for x in range(win.position.x, win.end.x):
					if big_ids.has(labels[y * w + x]):
						near = true
						break
				if near:
					break
		else:
			for big in big_boxes:
				var dx := maxi(maxi(big.position.x - box.end.x, box.position.x - big.end.x), 0)
				var dy := maxi(maxi(big.position.y - box.end.y, box.position.y - big.end.y), 0)
				if maxi(dx, dy) <= stray_dist:
					near = true
					break
		if near or big_boxes.is_empty():
			continue
		for i in entry[0]:
			data[i * 4] = 0
			data[i * 4 + 1] = 0
			data[i * 4 + 2] = 0
			data[i * 4 + 3] = 0
			removed += 1
	if removed > 0:
		img.set_data(w, img.get_height(), false, Image.FORMAT_RGBA8, data)
	return removed


## step 2.363: erases the cluster under the point (or the nearest one within 6 pixels), if it's small
## enough to be a spot (under 400 pixels) - so a misplaced point can never wipe out part of the drawing.
## returns how many pixels were erased.
static func _erase_cluster_at(img: Image, point: Vector2i, max_size: int = 400) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var start := -1
	var best := 1 << 30
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var x := point.x + dx
			var y := point.y + dy
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			if data[(y * w + x) * 4 + 3] != 0 and dx * dx + dy * dy < best:
				best = dx * dx + dy * dy
				start = y * w + x
	if start < 0:
		return 0
	var seen := {start: true}
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		if queue.size() > max_size:
			return 0
		var i: int = queue[head]
		head += 1
		var px := i % w
		var py := i / w
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var nx: int = px + dx
				var ny: int = py + dy
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var j: int = ny * w + nx
				if not seen.has(j) and data[j * 4 + 3] != 0:
					seen[j] = true
					queue.append(j)
	for i in queue:
		data[i * 4] = 0
		data[i * 4 + 1] = 0
		data[i * 4 + 2] = 0
		data[i * 4 + 3] = 0
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)
	return queue.size()
