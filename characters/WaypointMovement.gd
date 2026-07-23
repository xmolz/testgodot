# **********************(waypointmovement.gd)
class_name WaypointMovement
extends Node

# ///////////////////////[configuration]
@export var enabled: bool = true
@export var movement_speed: float = 50.0
@export var wait_duration: float = 2.0 

@export var waypoints: Array[NodePath]

enum LoopType { ONE_SHOT, LOOP, PING_PONG }
@export var loop_type: LoopType = LoopType.LOOP

# *********** internal state
var _target_node: CharacterBody2D
var _animation_player: AnimationPlayer
var _sprite_2d: Sprite2D 
var _current_waypoint_index: int = 0
var _is_waiting: bool = false
var _ping_pong_direction: int = 1

var _wait_timer: Timer

func _ready():
	if not enabled or get_parent() == null or waypoints.is_empty():
		set_physics_process(false)
		return

	_target_node = get_parent()
	if not _target_node is CharacterBody2D:
		set_physics_process(false)
		return

	_animation_player = _target_node.get_node_or_null("AnimationPlayer")
	
	# try to find the sprite
	_sprite_2d = _target_node.get_node_or_null("Sprite")
	if not _sprite_2d:
		_sprite_2d = _target_node.get_node_or_null("ObjectSprite")

	_wait_timer = Timer.new()
	_wait_timer.wait_time = wait_duration
	_wait_timer.one_shot = true
	add_child(_wait_timer)
	_wait_timer.timeout.connect(_on_wait_timer_timeout)

func _physics_process(delta: float):
	if _is_waiting:
		return

	var target_marker: Marker2D = get_node_or_null(waypoints[_current_waypoint_index])
	if not target_marker:
		set_physics_process(false)
		return

	var target_position = target_marker.global_position

	if _target_node.global_position.distance_to(target_position) < 5.0:
		_handle_arrival()
	else:
		_move_towards(target_position)

func _handle_arrival():
	_target_node.velocity = Vector2.ZERO 
	
	if _animation_player: 
		_animation_player.play("idle")

	_is_waiting = true
	_wait_timer.start()

	if loop_type == LoopType.PING_PONG:
		_current_waypoint_index += _ping_pong_direction
		if _current_waypoint_index >= waypoints.size() or _current_waypoint_index < 0:
			_ping_pong_direction *= -1
			_current_waypoint_index += _ping_pong_direction * 2
	else:
		_current_waypoint_index += 1

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

	if _animation_player and _animation_player.current_animation != "walk":
		_animation_player.play("walk")

	if _sprite_2d:
		if _target_node.velocity.x > 0.1:
			_sprite_2d.flip_h = false 
		elif _target_node.velocity.x < -0.1:
			_sprite_2d.flip_h = true

func _on_wait_timer_timeout():
	_is_waiting = false 

# //////////////////////// public functions for aida to control
func pause_movement():
	set_physics_process(false)
	
	# only pause the timer if it actually got created!
	if is_instance_valid(_wait_timer):
		_wait_timer.paused = true  
		
	if is_instance_valid(_target_node):
		_target_node.velocity = Vector2.ZERO
	if is_instance_valid(_animation_player):
		_animation_player.play("idle")

func resume_movement():
	# only unpause the timer if it actually got created!
	if is_instance_valid(_wait_timer):
		_wait_timer.paused = false 
		
	# only resume the physics loop
	if enabled and not waypoints.is_empty():
		set_physics_process(true)
	
# ------------(cutscene control)

# this function is a "coroutine". we can 'await' it!
func move_to_position_async(target_pos: Vector2, stop_distance: float = 5.0, timeout: float = 8.0) -> void:
	pause_movement()
	
	# print_rich("[color=orange]aidamove: start. from %s to
	
	var start_time = Time.get_ticks_msec()
	var arrived = false
	
	while not arrived:
		if not is_instance_valid(_target_node): return

		# /////////////////////[debugging every second]
		# we use modulo to print
		if Time.get_ticks_msec() % 1000 < 20: 
			var dist = _target_node.global_position.distance_to(target_pos)
			# print("aidamove: dist: %.2f | velocity:

		# check timeout (the safety net)
		var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
		if elapsed > timeout:
			# print_rich("[color=red]aidamove: timeout! force teleporting.[/color]")
			_target_node.global_position = target_pos
			arrived = true
			break

		# calculate horizontal distance only (the logic fix)
		# we only care about x
		var x_distance = abs(_target_node.global_position.x - target_pos.x)
		
		if x_distance <= stop_distance:
			arrived = true
			_target_node.velocity = Vector2.ZERO
			if _animation_player: _animation_player.play("idle")
			# print_rich("[color=green]aidamove: arrived at x coordinate.[/color]")
		else:
			# ************* 3. move horizontally only
			# determine direction: 1.0 (right) or -1.0 (left)
			var direction_x = sign(target_pos.x - _target_node.global_position.x)
			
			# apply velocity only to x.
			_target_node.velocity.x = direction_x * movement_speed
			_target_node.velocity.y = 0
			
			_target_node.move_and_slide()
			
			if _animation_player and _animation_player.current_animation != "walk":
				_animation_player.play("walk")
			
			if _sprite_2d:
				if _target_node.velocity.x > 0.1: _sprite_2d.flip_h = false
				elif _target_node.velocity.x < -0.1: _sprite_2d.flip_h = true
		
		await get_tree().physics_frame
		
func set_target_waypoint_index(index: int):
	if waypoints.is_empty(): return
	
	# clamp ensures we don't crash if you give a bad number
	_current_waypoint_index = clamp(index, 0, waypoints.size() - 1)
	# ------------------- print("waypointmovement: manually reset target to waypoint index %s" % _current_waypoint_index)
