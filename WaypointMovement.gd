# WaypointMovement.gd
class_name WaypointMovement
extends Node

# --- Configuration (Set these in the Inspector) ---
@export var enabled: bool = true
@export var movement_speed: float = 50.0
@export var wait_duration: float = 2.0 # How long to wait at each waypoint

# An array of NodePaths pointing to Marker2D nodes
@export var waypoints: Array[NodePath]

enum LoopType { ONE_SHOT, LOOP, PING_PONG }
@export var loop_type: LoopType = LoopType.LOOP

# --- Internal State ---
var _target_node: CharacterBody2D # The parent node we will move
var _animated_sprite: AnimatedSprite2D
var _current_waypoint_index: int = 0
var _is_waiting: bool = false
var _ping_pong_direction: int = 1 # 1 for forward, -1 for backward

# A timer we create in code to handle waiting
var _wait_timer: Timer

func _ready():
	if not enabled or get_parent() == null or waypoints.is_empty():
		# If not enabled, no parent, or no waypoints, disable processing.
		set_physics_process(false)
		return

	# Get references to the nodes we need to control
	_target_node = get_parent()
	if not _target_node is CharacterBody2D:
		print_rich("[color=red]WaypointMovement Error: Parent must be a CharacterBody2D.[/color]")
		set_physics_process(false)
		return

	_animated_sprite = _target_node.get_node_or_null("AnimatedSprite2D")
	if not _animated_sprite:
		_animated_sprite = _target_node.get_node_or_null("ObjectSprite")

	# Create and configure the wait timer
	_wait_timer = Timer.new()
	_wait_timer.wait_time = wait_duration
	_wait_timer.one_shot = true
	add_child(_wait_timer) # Add the timer to the scene tree
	_wait_timer.timeout.connect(_on_wait_timer_timeout)

func _physics_process(delta: float):
	if _is_waiting:
		# If we are waiting, do nothing.
		return

	# Get the global position of the target waypoint
	var target_marker: Marker2D = get_node_or_null(waypoints[_current_waypoint_index])
	if not target_marker:
		print_rich("[color=orange]WaypointMovement: Waypoint at index %s is invalid. Stopping.[/color]" % _current_waypoint_index)
		set_physics_process(false)
		return

	var target_position = target_marker.global_position

	# Check if we've arrived at the target
	if _target_node.global_position.distance_to(target_position) < 5.0:
		_handle_arrival()
	else:
		_move_towards(target_position)

func _handle_arrival():
	_target_node.velocity = Vector2.ZERO # Stop moving
	if _animated_sprite: _animated_sprite.play("idle")

	_is_waiting = true
	_wait_timer.start() # Start the wait timer

	# Figure out the next waypoint index based on loop type
	if loop_type == LoopType.PING_PONG:
		_current_waypoint_index += _ping_pong_direction
		if _current_waypoint_index >= waypoints.size() or _current_waypoint_index < 0:
			_ping_pong_direction *= -1
			_current_waypoint_index += _ping_pong_direction * 2
	else: # For LOOP and ONE_SHOT
		_current_waypoint_index += 1

	# Handle ONE_SHOT end and LOOP wrap-around
	if _current_waypoint_index >= waypoints.size():
		if loop_type == LoopType.ONE_SHOT:
			enabled = false
			set_physics_process(false)
			return
		elif loop_type == LoopType.LOOP:
			_current_waypoint_index = 0

func _move_towards(target_position: Vector2):
	var direction = _target_node.global_position.direction_to(target_position)
	_target_node.velocity = direction * movement_speed
	_target_node.move_and_slide()

	# Update animation based on direction
	if _animated_sprite:
		# Assumes you have "walk_right" and "walk_left" animations
		if _target_node.velocity.x > 0.1:
			_animated_sprite.play("walk_right") # Or just "walk" and flip the sprite
			_animated_sprite.flip_h = false
		elif _target_node.velocity.x < -0.1:
			_animated_sprite.play("walk_right") # Or just "walk" and flip the sprite
			_animated_sprite.flip_h = true
		# Optional: Add walk_up/walk_down if you have them

func _on_wait_timer_timeout():
	_is_waiting = false # Wait is over, resume moving in _physics_process
