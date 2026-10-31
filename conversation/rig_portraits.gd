extends RefCounted
## step 2.405: dialogue-box portraits for the rigged cast, cut from their own neutral pictures: a square
## around the face, built once per session and shared by every balloon. used inside the memory chapters
## (conversationballoon.gd); a character whose parts aren't there keeps the portrait it had.

const Composer = preload("res://characters/rig/actor_rig_composer.gd")
## balloon name -> [parts map, expressions file, expression, centre of the eyes x, eye line y]
## (positions in pixels on the 1100x1740 character canvas, measured from each rig's parts)
const SPECS := {
	"Player": ["res://characters/fiona/parts/fiona_parts.json", "res://characters/fiona/fiona_expressions.json", "base", 614.0, 614.0],
	"Layla": ["res://characters/layla/parts/layla_parts.json", "res://characters/layla/layla_expressions.json", "neutral", 632.0, 610.0],
	"Julian": ["res://characters/julian/parts/julian_parts.json", "res://characters/julian/julian_expressions.json", "base", 622.0, 350.0],
	"Jayce": ["res://characters/jayce/parts/jayce_parts.json", "res://characters/jayce/jayce_expressions.json", "base", 687.0, 499.0],
}
## the square's side in canvas pixels, how far below the eye line its centre sits, and the portrait's size
const SIDE := 520.0
const BELOW_EYES := 20.0
const OUT_PX := 256

static var _made: Dictionary = {}
static var _built := false


## balloon name -> portrait texture, for every rigged character whose parts are in place
static func all() -> Dictionary:
	if not _built:
		_built = true
		for who in SPECS:
			var tex: Texture2D = _make(SPECS[who])
			if tex:
				_made[who] = tex
	return _made


static func _make(spec: Array) -> Texture2D:
	var parts_path: String = spec[0]
	if not FileAccess.file_exists(parts_path):
		return null
	var parts: String = spec[2]
	if FileAccess.file_exists(spec[1]):
		var named = JSON.parse_string(FileAccess.get_file_as_string(spec[1]))
		if named is Dictionary and named.has(spec[2]):
			parts = String(named[spec[2]])
	var img: Image = Composer.compose_image(parts_path, parts)
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var origin = Composer.load_rig(parts_path).get("source_origin", [0, 0])
	var side := int(SIDE)
	var corner := Vector2i(int(float(spec[3]) - SIDE * 0.5) - int(origin[0]), int(float(spec[4]) + BELOW_EYES - SIDE * 0.5) - int(origin[1]))
	var src := Rect2i(corner, Vector2i(side, side)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if src.size.x <= 0 or src.size.y <= 0:
		return null
	var out := Image.create(side, side, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, src, src.position - corner)
	out.resize(OUT_PX, OUT_PX, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(out)
