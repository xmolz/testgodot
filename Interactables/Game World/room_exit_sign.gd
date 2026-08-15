# roomexitsign.gd — edge-of-room exit zone. Desktop: the sprite is hidden and the
# custom cursor morphs into a bobbing arrow while hovering the zone; the sentence
# line reads "Go to <Room>". Mobile: no cursor exists, so the visible bobbing
# arrow sprite stays as the tap affordance. It IS an interactable (hover outline,
# display name, verbs, walk-to all inherited), so navigation is wired per instance
# the same way as the hub bathroom door: an InteractionResponse on "use" carrying
# a TeleportAction to a spawn marker. The cursor arrow itself is driven by
# GameManager's resolved hover (see _update_top_hovered_object), NOT by this node,
# so anything standing inside the zone that wins the hover takes the cursor back.
extends Interactable

# +1 the arrow points right, -1 it points left (mirrors the visual and the bob).
@export var arrow_direction: int = 1

# the template zone is 240x880 centered near the sign; at runtime it is widened and
# pushed toward the travel direction so the band reaches the screen edge with no
# dead sliver (the arrow must hold right up to the boundary). WalkToPoint and the
# sign position are untouched.
const ZONE_EXTRA_WIDTH := 240.0
const ZONE_OUTWARD_SHIFT := 120.0

@onready var _sign_visual: Sprite2D = $ObjectSprite
@onready var _zone_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	hover_prefix = "Go to"
	super._ready()

	# the RectangleShape2D resource is shared by every sign instance — duplicate
	# before resizing so each instance owns its zone.
	if is_instance_valid(_zone_shape) and _zone_shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = _zone_shape.shape.duplicate()
		rect.size.x += ZONE_EXTRA_WIDTH
		_zone_shape.shape = rect
		_zone_shape.position.x += ZONE_OUTWARD_SHIFT * signf(arrow_direction)

	if is_instance_valid(_sign_visual):
		if OS.has_feature("mobile"):
			if arrow_direction < 0:
				_sign_visual.scale.x = -1.0

			# gentle horizontal bob toward the direction of travel. tween loops
			# forever and dies with the node.
			var base_x: float = _sign_visual.position.x
			var t := create_tween().set_loops()
			t.tween_property(_sign_visual, "position:x", base_x + 14.0 * signf(arrow_direction), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(_sign_visual, "position:x", base_x, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			# desktop: the zone is invisible; the morphing cursor is the affordance.
			_sign_visual.visible = false


# an exit is navigation, not an object: whatever verb reaches it (including the bare
# click's hidden "walk_to" and the auto-injected "flash"), route it to the walk_to
# response — which is the teleport. no examine flavor, no fallbacks.
func attempt_interaction(_verb_id: String, _item_id_used_with: String = ""):
	await super.attempt_interaction("walk_to", "")
