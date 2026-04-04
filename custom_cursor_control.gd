extends Control

@onready var parent = get_parent()

func _draw():
	var fill_color = Color(0.2, 0.85, 1.0, 1.0) if parent.is_hovering else Color.WHITE
	var outline_color = Color(0.0, 0.0, 0.0, 0.6) # Semi-transparent black outline
	var radius = parent._current_radius

	var dot_radius = 3.0
	var line_thickness = 3.0
	var outline_thickness = 2.0

	# Center dot outline
	draw_circle(Vector2.ZERO, dot_radius + outline_thickness, outline_color)
	# Center dot fill
	draw_circle(Vector2.ZERO, dot_radius, fill_color)

	# Draw crosshair lines
	var length = radius * 0.7
	for i in range(4):
		var angle = parent._rotation_angle + (i * PI / 2.0)
		var dir = Vector2(cos(angle), sin(angle))
		var start_pos = dir * (radius * 0.5)
		var end_pos = dir * (radius + length)

		# Line outline (drawn thicker and slightly longer/shorter to encase the fill)
		draw_line(start_pos - (dir * outline_thickness), end_pos + (dir * outline_thickness), outline_color, line_thickness + (outline_thickness * 2.0), true)
		# Line fill
		draw_line(start_pos, end_pos, fill_color, line_thickness, true)
