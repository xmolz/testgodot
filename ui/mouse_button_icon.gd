# mouse_button_icon.gd — the small mouse glyphs shown inline in the action bubble
# for two-button zoom items ({LMB} / {RMB} tokens, see VerbUI.gd). drawn in code in
# the bubble's palette (4x, then downsampled for smooth edges), cached per size.
# to use painted icons later, return loaded textures from get_icon() instead.
extends RefCounted

enum { LEFT, RIGHT }

const SUPERSAMPLE := 4
const WIDTH_RATIO := 0.72
const BODY := Color(0.93, 0.93, 0.93, 1.0)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.9)
const LIT := Color(0.2, 0.85, 1.0, 1.0) # #33d9ff, the bubble's object-name cyan
const SEAM := Color(0.35, 0.35, 0.35, 1.0)

static var _cache: Dictionary = {}


static func get_icon(side: int, height: int) -> Texture2D:
	var key := "%d_%d" % [side, height]
	if _cache.has(key):
		return _cache[key]
	var out_w: int = int(round(height * WIDTH_RATIO))
	var w: int = out_w * SUPERSAMPLE
	var h: int = height * SUPERSAMPLE
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var half := Vector2(w, h) * 0.5
	var radius: float = w * 0.46
	var outline: float = 2.0 * SUPERSAMPLE
	var seam: float = 1.5 * SUPERSAMPLE
	var button_bottom: float = h * 0.42
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5) - half
			var d := _sd_round_rect(p, half - Vector2(1.0, 1.0), radius)
			if d > 0.0:
				continue
			var c := BODY
			if d > -outline:
				c = OUTLINE
			elif absf(y + 0.5 - button_bottom) < seam * 0.5:
				c = SEAM
			elif y + 0.5 < button_bottom:
				if absf(p.x) < seam * 0.5:
					c = SEAM
				elif (p.x < 0.0 and side == LEFT) or (p.x > 0.0 and side == RIGHT):
					c = LIT
			img.set_pixel(x, y, c)
	img.resize(out_w, height, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _sd_round_rect(p: Vector2, half_size: Vector2, r: float) -> float:
	var q := Vector2(absf(p.x), absf(p.y)) - half_size + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
