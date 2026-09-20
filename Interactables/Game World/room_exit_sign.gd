# roomexitsign.gd — edge-of-room exit zone. Desktop: the sprite is hidden and the
# custom cursor morphs into a bobbing arrow while hovering the zone; the sentence
# line reads "Go to <Room>". Mobile: no cursor exists, so the visible bobbing
# arrow sprite stays as the tap affordance. It IS an interactable (hover outline,
# display name, verbs, walk-to all inherited), so navigation is wired per instance
# the same way as the hub bathroom door: an InteractionResponse on "use" carrying
# a SlideWipeTeleportAction to a spawn marker. The cursor arrow itself is driven by
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
# keyboard edge-exit (2.70): hold the movement axis toward arrow_direction while
# standing inside the zone and the sign fires its own walk_to teleport. mouse is
# untouched; this only reads ui_left/ui_right (A/D, arrows, stick).
const EDGE_HOLD_SECONDS := 0.15
const EDGE_ARRIVAL_COOLDOWN := 0.4
var _edge_hold: float = 0.0
var _edge_cooldown: float = 0.0
var _edge_fired: bool = false
var _dialogue_up: bool = false

@onready var _sign_visual: Sprite2D = $ObjectSprite
@onready var _zone_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	hover_prefix = "Go to"
	hover_ignores_verb = true
	super._ready()
	if Events and Events.has_signal("room_changed"):
		Events.room_changed.connect(_on_edge_room_changed)
	if DialogueManager:
		DialogueManager.dialogue_started.connect(func(_r): _dialogue_up = true)
		DialogueManager.dialogue_ended.connect(func(_r): _dialogue_up = false)

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
	var player = GameManager.player_node if GameManager else null
	if is_instance_valid(player) and player.has_method("face_target"):
		player.face_target(player.global_position + Vector2(float(arrow_direction) * 100.0, 0.0))
	await super.attempt_interaction("walk_to", "")


func _physics_process(delta: float) -> void:
	if _edge_cooldown > 0.0:
		_edge_cooldown -= delta
		_edge_hold = 0.0
		return
	if _edge_fired:
		# re-arm only once the key is released and no balloon is up, so a
		# sign whose walk_to is a dialogue (Classrooms) can fire again later
		# without replaying while the key is still held.
		if Input.get_axis("ui_left", "ui_right") == 0.0 and _edge_exit_allowed():
			_edge_fired = false
		_edge_hold = 0.0
		return
	if not _edge_exit_allowed():
		_edge_hold = 0.0
		return
	var player := GameManager.player_node
	if not is_instance_valid(player) or not _zone_contains(player.global_position):
		_edge_hold = 0.0
		return
	var axis := Input.get_axis("ui_left", "ui_right")
	if axis == 0.0 or signf(axis) != signf(float(arrow_direction)):
		_edge_hold = 0.0
		return
	_edge_hold += delta
	if _edge_hold < EDGE_HOLD_SECONDS:
		return
	_edge_hold = 0.0
	_edge_fired = true
	if GameManager and GameManager.has_method("process_interaction_click"):
		GameManager.process_interaction_click(self)
	else:
		attempt_interaction("walk_to", "")


func _on_edge_room_changed() -> void:
	_edge_fired = false
	_edge_hold = 0.0
	_edge_cooldown = EDGE_ARRIVAL_COOLDOWN


func _edge_exit_allowed() -> bool:
	if GameManager == null:
		return false
	if GameManager.current_game_state != GameManager.GameState.IN_GAME_PLAY:
		return false
	if GameManager.current_interaction_state != GameManager.InteractionState.WORLD:
		return false
	if GameManager.is_transitioning or GameManager.is_mouse_held_for_walk or _dialogue_up:
		return false
	return true


func _zone_contains(world_point: Vector2) -> bool:
	if not is_instance_valid(_zone_shape) or not (_zone_shape.shape is RectangleShape2D):
		return false
	var half: Vector2 = (_zone_shape.shape as RectangleShape2D).size * 0.5
	var local: Vector2 = _zone_shape.to_local(world_point)
	return absf(local.x) <= half.x and absf(local.y) <= half.y


# ---- exit walk fix (2.77) ----
# player.walk_to_and_interact parks the player INTERACTION_OFFSET_X short of the sign on
# the player's own side and then faces the sign. standing past the sign (between it and the
# wall) that means a step back into the room and a turn away from the exit. if the player
# is already inside the zone there is nothing to walk to: leave now, facing the way out.
func does_verb_require_walk(_verb_id_to_check: String, _item_data_used: ItemData = null) -> bool:
	var player = GameManager.player_node if GameManager else null
	if is_instance_valid(player) and _zone_contains(player.global_position):
		return false
	return true
