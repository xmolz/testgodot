@tool
extends EditorScript
## step 2.298 rev 2 (dev test): cuts the car's expression overlays out of full-size layer exports.
## run it from the script editor: open this file, then File > Run (Ctrl+Shift+X).
##
## input, in SOURCE_DIR (a .gdignore folder, so nothing in it is imported or shipped):
##   car_full.png                   the whole car frame with NO expression layer showing, full size
##   <slot> @<variant>.png           one expression layer on its own, exported at full size on a
##                                  transparent canvas, e.g. fiona_face @smile_straight.png
## output, in OUT_DIR:
##   car_full.png                   the base frame (a copy of the source)
##   <slot>__<variant>.png          the expression cut down to the slot's box
##   car_parts.json                 the base path, each slot's box, default and overlays (read by car_rig.gd)
##
## the expression layers sit on top of everything in the art, so each overlay is simply laid over the
## base at its box position. only one overlay per slot shows at a time.

const SOURCE_DIR := "res://Dev/car_test/source/"
const OUT_DIR := "res://Dev/car_test/parts/"
const BASE_NAME := "car_full"
## each slot's box in art pixels (x, y, width, height). anything in a layer export outside its slot's
## box is ignored (the cutter warns); widen a box if an expression reaches its edge.
const SLOTS := {
	"fiona_face": Rect2i(688, 656, 528, 320),
}
## the overlay each slot shows when the scene starts ("" = none)
const DEFAULTS := {
	"fiona_face": "frown_straight",
}


func _run() -> void:
	if cut_all():
		EditorInterface.get_resource_filesystem().scan()


static func cut_all() -> bool:
	var base := Image.load_from_file(SOURCE_DIR + BASE_NAME + ".png")
	if base == null or base.is_empty():
		push_error("car_parts_cutter: no %s%s.png. export the full frame (no expression) there first." % [SOURCE_DIR, BASE_NAME])
		return false
	base.convert(Image.FORMAT_RGBA8)
	var canvas := base.get_size()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var base_out := OUT_DIR + BASE_NAME + ".png"
	base.save_png(base_out)

	var manifest := {
		"canvas": [canvas.x, canvas.y],
		"base": base_out,
		"slots": {},
	}
	for slot in SLOTS:
		var r: Rect2i = SLOTS[slot]
		if not Rect2i(Vector2i.ZERO, canvas).encloses(r):
			push_error("car_parts_cutter: the %s box %s is outside the %s canvas." % [slot, r, canvas])
			return false
		manifest["slots"][slot] = {
			"rect": [r.position.x, r.position.y, r.size.x, r.size.y],
			"default": String(DEFAULTS.get(slot, "")),
			"variants": {},
		}

	var made := 0
	for f in DirAccess.get_files_at(SOURCE_DIR):
		if not f.to_lower().ends_with(".png") or not f.contains("@"):
			continue
		var stem := f.get_basename()
		var slot := stem.get_slice("@", 0)
		var variant := stem.get_slice("@", 1)
		if not SLOTS.has(slot):
			push_warning("car_parts_cutter: %s - no slot called \"%s\" in SLOTS; skipped." % [f, slot])
			continue
		if variant.is_empty():
			push_warning("car_parts_cutter: %s - no variant name after the @; skipped." % f)
			continue
		var img := Image.load_from_file(SOURCE_DIR + f)
		if img == null or img.is_empty():
			push_warning("car_parts_cutter: %s could not be read; skipped." % f)
			continue
		img.convert(Image.FORMAT_RGBA8)
		if img.get_size() != canvas:
			push_warning("car_parts_cutter: %s is %s, the base is %s; skipped. export both at full size." % [f, img.get_size(), canvas])
			continue
		var rect: Rect2i = SLOTS[slot]

		# anything drawn outside the box? (clear the box and see if anything is left)
		var outside := img.duplicate() as Image
		outside.fill_rect(rect, Color(0, 0, 0, 0))
		if not outside.is_invisible():
			var used := outside.get_used_rect()
			push_warning("car_parts_cutter: %s has marks outside the %s box (within %s - stray dots?). they are ignored." % [f, slot, used])

		var patch := img.get_region(rect)
		if patch.is_invisible():
			push_warning("car_parts_cutter: %s is empty inside the %s box; skipped." % [f, slot])
			continue
		var edge := _edge_pixels(patch)
		if edge > 0:
			push_warning("car_parts_cutter: %s touches the edge of the %s box (%d pixel(s)); it gets cut off. widen the box in SLOTS." % [f, slot, edge])

		var out_path := OUT_DIR + "%s__%s.png" % [slot, variant]
		patch.save_png(out_path)
		manifest["slots"][slot]["variants"][variant] = out_path
		print("car_parts_cutter: %s -> %s" % [f, out_path])
		made += 1

	for slot in SLOTS:
		var d: String = manifest["slots"][slot]["default"]
		if d != "" and not manifest["slots"][slot]["variants"].has(d):
			push_warning("car_parts_cutter: the default \"%s\" for %s has no export (%s @%s.png)." % [d, slot, slot, d])

	var fa := FileAccess.open(OUT_DIR + "car_parts.json", FileAccess.WRITE)
	if fa == null:
		push_error("car_parts_cutter: could not write %scar_parts.json." % OUT_DIR)
		return false
	fa.store_string(JSON.stringify(manifest, "\t"))
	fa.close()
	print_rich("[color=green]car_parts_cutter: base + %d overlay(s) written to %s[/color]" % [made, OUT_DIR])
	return true


# how many pixels on the box's outermost ring are drawn on
static func _edge_pixels(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var n := 0
	for x in w:
		if img.get_pixel(x, 0).a > 0.0: n += 1
		if img.get_pixel(x, h - 1).a > 0.0: n += 1
	for y in range(1, h - 1):
		if img.get_pixel(0, y).a > 0.0: n += 1
		if img.get_pixel(w - 1, y).a > 0.0: n += 1
	return n
