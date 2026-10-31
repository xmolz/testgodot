extends RefCounted
## step 2.315: makes all the text in a UI subtree bigger by one factor, so a whole screen can be tuned
## with a single number. every Label and Button found is scaled from its current size exactly once (it's
## marked), so it is safe to call again after rows are rebuilt or new pieces are added.

## the memory box and its chapter drawer on PC. mobile already has its own larger sizes, so it stays at 1.
const MEMORY_BOX_DESKTOP := 1.25


static func memory_box_factor() -> float:
	return 1.0 if OS.has_feature("mobile") else MEMORY_BOX_DESKTOP


static func apply(root: Node, factor: float, skip: Array = []) -> void:
	if root == null or is_equal_approx(factor, 1.0):
		return
	_walk(root, factor, skip)


static func _walk(node: Node, factor: float, skip: Array) -> void:
	if skip.has(node):
		return
	if (node is Label or node is Button) and not node.has_meta("ui_text_scaled"):
		var current: int = node.get_theme_font_size("font_size")
		if current > 0:
			node.add_theme_font_size_override("font_size", int(round(current * factor)))
		node.set_meta("ui_text_scaled", true)
	for child in node.get_children():
		_walk(child, factor, skip)


## step 2.318: shrinks a one-line label's font until its text fits max_width, down to min_ratio of the size
## it had the first time it was fitted (so it can grow back when there's more room); past that, the end is
## cut off with "…".
static func fit_width(label: Label, max_width: float, min_ratio: float = 0.7) -> void:
	if label == null or max_width <= 0.0:
		return
	var base: int = int(label.get_meta("fit_base_size", 0))
	if base <= 0:
		base = label.get_theme_font_size("font_size")
		label.set_meta("fit_base_size", base)
	var font: Font = label.get_theme_font("font")
	if font == null or base <= 0:
		return
	var size: int = base
	var min_size: int = int(ceil(base * min_ratio))
	while size > min_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 1
	label.add_theme_font_size_override("font_size", size)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
