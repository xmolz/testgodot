# roomexitsign.gd — clickable edge-of-room exit marker: a bobbing arrow. it IS an
# interactable (hover outline, display name, verbs, walk-to all inherited), so
# navigation is wired per instance the same way as the hub bathroom door: an
# InteractionResponse on "use" carrying a TeleportAction to a spawn marker.
extends Interactable

# +1 the arrow points right, -1 it points left (mirrors the visual and the bob).
@export var arrow_direction: int = 1

@onready var _sign_visual: Sprite2D = $ObjectSprite

func _ready():
	super._ready()

	if is_instance_valid(_sign_visual):
		if arrow_direction < 0:
			_sign_visual.scale.x = -1.0

		# gentle horizontal bob toward the direction of travel. tween loops forever and
		# dies with the node.
		var base_x: float = _sign_visual.position.x
		var t := create_tween().set_loops()
		t.tween_property(_sign_visual, "position:x", base_x + 14.0 * signf(arrow_direction), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(_sign_visual, "position:x", base_x, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# an exit is navigation, not an object: whatever verb reaches it (including the bare
# click's hidden "walk_to" and the auto-injected "flash"), route it to the walk_to
# response — which is the teleport. no examine flavor, no fallbacks.
func attempt_interaction(_verb_id: String, _item_id_used_with: String = ""):
	await super.attempt_interaction("walk_to", "")
