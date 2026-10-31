# closeup_upscale.gd - step 2.261: shows a close-up larger than it was laid out by scaling every
# size inside it (font sizes, minimum sizes, spacing, stylebox margins, borders, corners, shadows)
# rather than the node itself, so text renders at the larger size and stays sharp.
# factor 1.0 leaves the scene untouched; the wall copy of the certificate uses 1.0.
extends Control

## how much larger to show this close-up. about 1.25 is the most that fits above the Back button.
@export var factor: float = 1.0

const SIDES := [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]
const CORNERS := [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_RIGHT, CORNER_BOTTOM_LEFT]


func _ready() -> void:
	if is_equal_approx(factor, 1.0):
		return
	_scale_tree(self)


func _scale_tree(node: Node) -> void:
	if node is Control:
		_scale_control(node as Control)
	for child in node.get_children():
		_scale_tree(child)


func _scale_control(c: Control) -> void:
	c.custom_minimum_size = (c.custom_minimum_size * factor).round()
	if c.has_theme_font_size_override("font_size"):
		c.add_theme_font_size_override("font_size", maxi(1, roundi(c.get_theme_font_size("font_size") * factor)))
	for constant_name in ["separation", "line_spacing"]:
		if c.has_theme_constant_override(constant_name):
			c.add_theme_constant_override(constant_name, roundi(c.get_theme_constant(constant_name) * factor))
	for style_name in ["panel", "separator"]:
		if c.has_theme_stylebox_override(style_name):
			c.add_theme_stylebox_override(style_name, _scaled_style(c.get_theme_stylebox(style_name)))


# each Control gets its own copy, so the shared sub-resources in the scene file are never changed.
func _scaled_style(style: StyleBox) -> StyleBox:
	var scaled := style.duplicate() as StyleBox
	for side in SIDES:
		var margin: float = scaled.get_content_margin(side)
		if margin > 0.0:
			scaled.set_content_margin(side, margin * factor)
	if scaled is StyleBoxFlat:
		var flat := scaled as StyleBoxFlat
		for side in SIDES:
			var width: int = flat.get_border_width(side)
			if width > 0:
				flat.set_border_width(side, maxi(1, roundi(width * factor)))
		for corner in CORNERS:
			flat.set_corner_radius(corner, roundi(flat.get_corner_radius(corner) * factor))
		flat.shadow_size = roundi(flat.shadow_size * factor)
		flat.shadow_offset = flat.shadow_offset * factor
	elif scaled is StyleBoxLine:
		var line := scaled as StyleBoxLine
		line.thickness = maxi(1, roundi(line.thickness * factor))
	return scaled
