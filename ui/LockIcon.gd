extends Control
## step 2.308: a padlock drawn in code (no image file), used over locked chapters in the memory box.
## it scales with its own size and is centred in it.
## step 2.310: a see-through color is mixed with hole_color (the tile behind) into one solid color first.
## drawn see-through, the shackle, its legs and the body each blended on their own, so where they
## overlap the lock came out brighter, in bands.

@export var color: Color = Color(0.537, 0.867, 1.0)       # the memory box cyan
@export var hole_color: Color = Color(0.06, 0.07, 0.11)   # the keyhole, the same dark as the panel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s <= 1.0:
		return
	var c: Vector2 = size * 0.5
	var col: Color = hole_color.lerp(Color(color, 1.0), color.a)
	col.a = 1.0
	# body: a rounded square in the lower part
	var bw: float = s * 0.62
	var bh: float = s * 0.46
	var body := Rect2(c.x - bw * 0.5, c.y - bh * 0.5 + s * 0.14, bw, bh)
	var box := StyleBoxFlat.new()
	box.bg_color = col
	box.set_corner_radius_all(int(s * 0.07))
	box.anti_aliasing = true
	draw_style_box(box, body)
	# shackle: a thick half ring with two legs down into the body
	var thick: float = s * 0.09
	var r: float = bw * 0.30
	var top: float = body.position.y - s * 0.12
	draw_arc(Vector2(c.x, top), r, PI, TAU, 32, col, thick, true)
	draw_line(Vector2(c.x - r, top), Vector2(c.x - r, body.position.y + thick), col, thick, true)
	draw_line(Vector2(c.x + r, top), Vector2(c.x + r, body.position.y + thick), col, thick, true)
	# keyhole: a circle over a short tapered slot
	var kc := Vector2(c.x, body.position.y + bh * 0.42)
	var kr: float = s * 0.055
	draw_circle(kc, kr, hole_color, true, -1.0, true)
	var slot := PackedVector2Array([
		kc + Vector2(-kr * 0.45, 0.0), kc + Vector2(kr * 0.45, 0.0),
		kc + Vector2(kr * 0.75, kr * 2.6), kc + Vector2(-kr * 0.75, kr * 2.6)])
	draw_colored_polygon(slot, hole_color)
