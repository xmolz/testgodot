# companion_follow.gd — reusable follower brain for in-world characters.
# a plain Node dropped onto a CharacterBody2D, same composition pattern as
# WaypointMovement. it drives the parent body's velocity and move_and_slide(), so a
# body must never have two active movement brains at once.
#
# attach()/detach() are the public API: levels can set auto_attach_to_player on an
# instance, and dialogues/interactions can call them later through CallMethodAction.
class_name CompanionFollow
extends Node

signal attached(target: Node2D)
signal detached

# level-facing switch: find the "player" group node on ready and follow it.
@export var auto_attach_to_player: bool = false

# stop once within this x-gap of the target...
@export var follow_gap: float = 170.0
# ...and only start walking again once the target has pulled a further band away.
# the two together are hysteresis: without it the follower jitters at the boundary.
@export var resume_band: float = 60.0

# matches the player's 700, so the trailing gap holds steady during a long walk
# instead of stretching out behind them...
@export var speed: float = 700.0
# ...and the catch-up gear closes whatever distance opened while she stood waiting.
@export var catchup_distance: float = 350.0
@export var catchup_multiplier: float = 1.25

# same constant the player uses.
@export var gravity: float = 800.0

var _body: CharacterBody2D = null
var _target: Node2D = null
var _moving: bool = false

func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_warning("CompanionFollow: parent is not a CharacterBody2D, disabling.")
		set_physics_process(false)
		return
	# room teleports (TeleportAction) announce themselves on this signal. an attached
	# follower has x-only pathing and rooms are separated by walls, so she comes along
	# by snapping instead of pathing into a wall and getting stranded.
	Events.room_changed.connect(_on_room_changed)
	if auto_attach_to_player:
		_try_auto_attach()

# the player may not be in the tree yet depending on scene order — poll until it is.
func _try_auto_attach() -> void:
	while is_inside_tree():
		var p = get_tree().get_first_node_in_group("player")
		if is_instance_valid(p):
			attach(p)
			return
		await get_tree().process_frame

# snap beside the target on the side we were already on, comfort gap respected. known
# cosmetic limit: she pops in as the transition doors reopen rather than walking in.
func _on_room_changed() -> void:
	if not is_attached() or _body == null:
		return
	var side: float = signf(_body.global_position.x - _target.global_position.x)
	if side == 0.0:
		side = -1.0
	_body.global_position = _target.global_position + Vector2(side * follow_gap, 0.0)
	_body.velocity = Vector2.ZERO
	_moving = false

func attach(target: Node2D) -> void:
	# a follower must be crossable. the floor and the player share collision layer 1,
	# so mask filtering alone cannot ignore the player — without an exception, this
	# body's own move_and_slide() depenetrates her out of the player's shape every
	# frame and she gets shoved along in front of them like a crate.
	_clear_target_exception()
	_target = target
	if _body and _target is PhysicsBody2D:
		_body.add_collision_exception_with(_target)
	attached.emit(target)

func detach() -> void:
	_clear_target_exception()
	_target = null
	_moving = false
	detached.emit()

func _clear_target_exception() -> void:
	if _body and is_instance_valid(_target) and _target is PhysicsBody2D:
		_body.remove_collision_exception_with(_target)

func is_attached() -> bool:
	return is_instance_valid(_target)

func get_target() -> Node2D:
	return _target if is_instance_valid(_target) else null

# followers freeze whenever the player would be frozen: outside gameplay, or in any
# non-world interaction state (conversations, zoom views, chapter launches).
func _can_follow_now() -> bool:
	if not GameManager:
		return false
	if GameManager.current_game_state != GameManager.GameState.IN_GAME_PLAY:
		return false
	if GameManager.current_interaction_state != GameManager.InteractionState.WORLD:
		return false
	return true

func _physics_process(delta: float) -> void:
	if _body == null:
		return

	var vx := 0.0
	if is_instance_valid(_target) and _can_follow_now():
		var dx: float = _target.global_position.x - _body.global_position.x
		var dist: float = absf(dx)

		if _moving:
			if dist <= follow_gap:
				_moving = false
		else:
			if dist > follow_gap + resume_band:
				_moving = true

		if _moving:
			var s: float = speed
			if dist > catchup_distance:
				s *= catchup_multiplier
			vx = signf(dx) * s

	# gravity + slide even when idle or detached, so the body always rests on the floor.
	_body.velocity.x = vx
	if not _body.is_on_floor():
		_body.velocity.y += gravity * delta
	_body.move_and_slide()
