extends CharacterBody2D

const SPEED = 700.0
const GRAVITY = 800.0
const WALK_TO_THRESHOLD_X = 5.0
const INTERACTION_OFFSET_X = 30.0

# Variable to hold the calculated safe stopping distance
var player_half_width: float = 65.0 

@onready var sprite_2d: Sprite2D = $Sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
# Reference to get the actual width of the player
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

var current_animation_state = "idle"

var _is_walking_to_target: bool = false
var _actual_walk_destination: Vector2
var _start_walk_position_x: float = 0.0
var _interactable_after_walk: Interactable = null
var _verb_for_interaction: String = ""
var _item_for_interaction: ItemData = null
var _can_move: bool = true
var _stuck_timer: float = 0.0 # To track how long we've been stuck

func _ready():
	if not sprite_2d: print_rich("[color=red]Player: Sprite2D node not found![/color]")
	if not animation_player: print_rich("[color=red]Player: AnimationPlayer node not found![/color]")
	
	# --- AUTO-CALCULATE WIDTH ---
	# This makes the wall-stopping logic screen-size and scale independent.
	if collision_shape_2d and collision_shape_2d.shape is RectangleShape2D:
		var shape_w = collision_shape_2d.shape.size.x
		# Formula: (Shape Width / 2) * Object Scale + Buffer
		player_half_width = (shape_w * global_scale.x / 2.0) + 15.0
		print("Player: Auto-calculated stopping distance: ", player_half_width)
	else:
		print_rich("[color=yellow]Player: Could not calc width (Shape missing or not Rectangle). Using default 65.0[/color]")
	# ----------------------------
	
	play_animation("idle")

func _physics_process(delta: float):
	if not _can_move:
		if is_instance_valid(animation_player):
			set_animation_state("idle")
		velocity.x = 0
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			velocity.y = 0 
		move_and_slide()
		return

	if _is_walking_to_target:
		var direction_to_destination = global_position.direction_to(_actual_walk_destination)
		var x_distance_to_destination = abs(global_position.x - _actual_walk_destination.x)

		# Check direction to prevent overshooting
		var direction_from_start = sign(_actual_walk_destination.x - _start_walk_position_x)
		var direction_from_current = sign(_actual_walk_destination.x - global_position.x)
		var has_not_reached_target = (direction_from_start == direction_from_current)

		# --- STUCK FAILSAFE ---
		# If we are trying to move but velocity is near zero
		if abs(get_real_velocity().x) < 10.0:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0 # Reset if we move
			
		# If we've been stuck for 0.2 seconds, give up.
		if _stuck_timer > 0.2:
			print_rich("[color=orange]Player: Stuck against obstacle for %.2fs. Stopping.[/color]" % _stuck_timer)
			_stop_walking()
			return
		# ----------------------

		if has_not_reached_target and x_distance_to_destination > WALK_TO_THRESHOLD_X:
			velocity.x = direction_to_destination.x * SPEED
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			else:
				velocity.y = move_toward(velocity.y, 0, GRAVITY * delta * 0.1)

			if is_instance_valid(sprite_2d): sprite_2d.flip_h = (velocity.x < 0)
			set_animation_state("walk")
		
		else: # Reached destination
			_stop_walking()
			
			if is_instance_valid(_interactable_after_walk):
				face_target(_interactable_after_walk.global_position) 
				var interactable_ref = _interactable_after_walk
				var verb_ref = _verb_for_interaction
				var item_ref = _item_for_interaction
				_interactable_after_walk = null
				_verb_for_interaction = ""
				_item_for_interaction = null

				if GameManager and GameManager.has_method("player_reached_interaction_target"):
					GameManager.player_reached_interaction_target(interactable_ref, verb_ref, item_ref)
		
		move_and_slide()
		return

	# Idle Physics
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = move_toward(velocity.y, 0, GRAVITY * delta * 0.1) 

	velocity.x = move_toward(velocity.x, 0, SPEED * 0.5)
	if abs(velocity.x) < 1.0 : velocity.x = 0

	if not _is_walking_to_target:
		set_animation_state("idle")

	move_and_slide()

# Helper to cleanly stop walking
func _stop_walking():
	_is_walking_to_target = false
	_stuck_timer = 0.0
	velocity = Vector2.ZERO
	set_animation_state("idle")
	if GameManager and GameManager.has_method("player_has_finished_walk_command"):
		GameManager.player_has_finished_walk_command()

func walk_to_point(destination_pos: Vector2):
	if not _can_move: return

	_interactable_after_walk = null
	_verb_for_interaction = ""
	_item_for_interaction = null
	_stuck_timer = 0.0

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, destination_pos)
	query.exclude = [self.get_rid()]
	
	var result = space_state.intersect_ray(query)

	if result:
		print_rich("[color=green]Hit Wall at %s. Adjusting destination.[/color]" % result.position)
		var direction_back = (global_position - result.position).normalized()
		
		# --- DYNAMIC STOPPING DISTANCE ---
		_actual_walk_destination = result.position + (direction_back * player_half_width)
		_actual_walk_destination.y = global_position.y
	else:
		_actual_walk_destination.x = destination_pos.x
		_actual_walk_destination.y = global_position.y 

	_start_walk_position_x = global_position.x
	_is_walking_to_target = true

func walk_to_and_interact(interactable_walk_to_point_pos: Vector2, interactable_node: Interactable, verb_id: String, item_data: ItemData):
	if not _can_move: return

	_interactable_after_walk = interactable_node
	_verb_for_interaction = verb_id
	_item_for_interaction = item_data
	_stuck_timer = 0.0

	var target_x = interactable_walk_to_point_pos.x
	if global_position.x < target_x:
		_actual_walk_destination.x = target_x - INTERACTION_OFFSET_X
	else:
		_actual_walk_destination.x = target_x + INTERACTION_OFFSET_X
	_actual_walk_destination.y = global_position.y

	_start_walk_position_x = global_position.x
	_is_walking_to_target = true

func set_can_move(value: bool):
	_can_move = value
	if not _can_move:
		_stop_walking()

func face_target(target_global_position: Vector2):
	if not is_instance_valid(sprite_2d): return
	if target_global_position.x > global_position.x + 1.0:
		sprite_2d.flip_h = false 
	elif target_global_position.x < global_position.x - 1.0: 
		sprite_2d.flip_h = true

func set_animation_state(new_state: String):
	if not is_instance_valid(animation_player): return
	if current_animation_state == new_state:
		if not animation_player.is_playing() and animation_player.has_animation(new_state):
			animation_player.play(new_state)
		return
	current_animation_state = new_state
	play_animation(new_state)

func play_animation(anim_name: String):
	if not is_instance_valid(animation_player): return
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
		
var _last_step_time: int = 0
const STEP_COOLDOWN_MSEC: int = 350 # Time in milliseconds (increase to slow down sounds)

func on_footstep_frame():
	# 1. Check if we are moving
	if velocity.length() < 1.0:
		return

	# 2. Check Time Cooldown
	var current_time = Time.get_ticks_msec()
	if current_time - _last_step_time < STEP_COOLDOWN_MSEC:
		return # Too soon! Skip this sound.

	# 3. Play Sound & Reset Timer
	SoundManager.play_random_footstep()
	_last_step_time = current_time
