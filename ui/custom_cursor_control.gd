extends Control

@onready var parent = get_parent()

# exit-zone arrow: same silhouette as the exit sign's ArrowGlyph, cursor-scaled.
# NOTE: a plain Array of Vector2s, not a PackedVector2Array — the packed-array
# constructor is not a constant expression for `const` in this Godot version.
const ARROW_POINTS := [
	Vector2(-45, -14), Vector2(8, -14), Vector2(8, -36),
	Vector2(50, 0), Vector2(8, 36), Vector2(8, 14), Vector2(-45, 14)
]
const ARROW_SCALE := 0.6
const ARROW_BOB_DISTANCE := 14.0
const ARROW_BOB_CYCLE_SECONDS := 1.2  # matches the old sign tween: 0.6s out + 0.6s back
const ARROW_FILL := Color(0.2, 0.85, 1.0, 1.0)  # game accent cyan
const ARROW_OUTLINE := Color(0.0, 0.0, 0.0, 0.6)

func _draw():
	if parent.is_exit_mode and not parent._over_ui:
		_draw_exit_arrow()
		return

	var fill_color = Color(0.2, 0.85, 1.0, 1.0) if parent.is_hovering else Color.WHITE
	var outline_color = Color(0.0, 0.0, 0.0, 0.6)
	var radius = parent._current_radius

	var dot_radius = 3.0
	var line_thickness = 3.0
	var outline_thickness = 2.0

	# center dot outline
	draw_circle(Vector2.ZERO, dot_radius + outline_thickness, outline_color)
	# center dot fill
	draw_circle(Vector2.ZERO, dot_radius, fill_color)

	# draw crosshair line
	var length = radius * 0.7
	for i in range(4):
		var angle = parent._rotation_angle + (i * PI / 2.0)
		var dir = Vector2(cos(angle), sin(angle))
		var start_pos = dir * (radius * 0.5)
		var end_pos = dir * (radius + length)

		# line outline (drawn thicker and
		draw_line(start_pos - (dir * outline_thickness), end_pos + (dir * outline_thickness), outline_color, line_thickness + (outline_thickness * 2.0), true)
		# line fill
		draw_line(start_pos, end_pos, fill_color, line_thickness, true)

func _draw_exit_arrow():
	var dir: float = float(parent.exit_direction)
	# 0 -> 14px -> 0 bob toward the travel direction; same feel as the sign tween.
	var bob: float = (0.5 - 0.5 * cos(parent._exit_bob_time * TAU / ARROW_BOB_CYCLE_SECONDS)) * ARROW_BOB_DISTANCE
	var pts := PackedVector2Array()
	for p in ARROW_POINTS:
		pts.append(Vector2((p.x * ARROW_SCALE + bob) * dir, p.y * ARROW_SCALE))
	# black outline pass under the fill: closed fat polyline
	var outline_pts := pts.duplicate()
	outline_pts.append(pts[0])
	draw_polyline(outline_pts, ARROW_OUTLINE, 4.0, true)
	draw_colored_polygon(pts, ARROW_FILL)
