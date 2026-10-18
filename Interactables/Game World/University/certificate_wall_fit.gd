# step 2.248: fits the wall certificate to whatever size the close-up layout really ends up
# at (fonts differ per machine, so the size isn't fixed): scales it, centers it on the
# Interactable's origin, and sizes the hover outline and the click area to match.
# sits on a plain child Node of the certificate's Area2D.
extends Node

## the certificate's size on the wall, as a fraction of its close-up size.
@export var wall_scale: float = 0.215
## how far the hover outline sits outside the certificate, and how thick it is.
@export var glow_pad: float = 4.0
@export var glow_thickness: float = 8.0


func _ready() -> void:
	_fit.call_deferred()


func _fit() -> void:
	var area := get_parent()
	if area == null:
		return
	var cert := area.get_node_or_null("Certificate") as Control
	if cert == null:
		return
	# containers settle their sizes during the first layout pass.
	await get_tree().process_frame
	if not is_instance_valid(cert):
		return
	var full: Vector2 = cert.get_combined_minimum_size()
	cert.size = full
	cert.scale = Vector2(wall_scale, wall_scale)
	var shown: Vector2 = full * wall_scale
	cert.position = -shown * 0.5

	var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		var rect := (shape_node.shape as RectangleShape2D).duplicate() as RectangleShape2D
		rect.size = shown
		shape_node.shape = rect

	var glow := area.get_node_or_null("HoverGlow")
	if glow:
		var h: Vector2 = shown * 0.5 + Vector2(glow_pad, glow_pad)
		var t: float = glow_thickness
		_place(glow.get_node_or_null("GlowTop"), Vector2(-h.x, -h.y), Vector2(h.x * 2.0, t))
		_place(glow.get_node_or_null("GlowBottom"), Vector2(-h.x, h.y - t), Vector2(h.x * 2.0, t))
		_place(glow.get_node_or_null("GlowLeft"), Vector2(-h.x, -h.y), Vector2(t, h.y * 2.0))
		_place(glow.get_node_or_null("GlowRight"), Vector2(h.x - t, -h.y), Vector2(t, h.y * 2.0))


func _place(node: Node, pos: Vector2, size: Vector2) -> void:
	if node is Control:
		(node as Control).position = pos
		(node as Control).size = size
