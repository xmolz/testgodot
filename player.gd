extends CharacterBody2D

const SPEED = 700.0
const GRAVITY = 800.0 # Make sure this matches your project settings if you use built-in gravity
const WALK_TO_THRESHOLD_X = 5.0 # How close on X axis to stop
const INTERACTION_OFFSET_X = 30.0 # Horizontal offset from the interactable's actual WalkToPoint.x

@onready var sprite_2d: Sprite2D = $Sprite # Ensure this node path is correct
@onready var animation_player: AnimationPlayer = $AnimationPlayer # Ensure this node path is correct

var current_animation_state = "idle"

var _is_walking_to_target: bool = false
var _actual_walk_destination: Vector2      # The final calculated X,Y point the player moves to
var _start_walk_position_x: float = 0.0    # ADDED: To prevent overshooting
var _interactable_after_walk: Interactable = null
var _verb_for_interaction: String = ""
var _item_for_interaction: ItemData = null # MODIFIED: Store ItemData, initialize to null

var _can_move: bool = true

func _ready():
	# Ensure nodes are valid
	if not sprite_2d: print_rich("[color=red]Player: Sprite2D node not found![/color]")
	if not animation_player: print_rich("[color=red]Player: AnimationPlayer node not found![/color]")
	play_animation("idle")

func _physics_process(delta: float):
	if not _can_move:
		if is_instance_valid(animation_player): # Check if node is still valid
			set_animation_state("idle") # Keep playing idle animation
		velocity.x = 0 # Stop horizontal movement
		# Apply gravity if not on floor
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			velocity.y = 0 # Or a small downward force if needed for slopes
		move_and_slide()
		return

	if _is_walking_to_target:
		var direction_to_destination = global_position.direction_to(_actual_walk_destination)
		var x_distance_to_destination = abs(global_position.x - _actual_walk_destination.x)

		# --- This is the corrected arrival logic to prevent overshooting ---
		var direction_from_start = sign(_actual_walk_destination.x - _start_walk_position_x)
		var direction_from_current = sign(_actual_walk_destination.x - global_position.x)

		# The walk continues IF we are still approaching the target from the original direction.
		var has_not_reached_target = (direction_from_start == direction_from_current)

		if has_not_reached_target and x_distance_to_destination > WALK_TO_THRESHOLD_X:
			velocity.x = direction_to_destination.x * SPEED
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			else: # On floor, gentle Y velocity adjustment
				velocity.y = move_toward(velocity.y, 0, GRAVITY * delta * 0.1)

			if is_instance_valid(sprite_2d): sprite_2d.flip_h = (velocity.x < 0)
			set_animation_state("walk")
		# --- END OF MODIFICATION ---
		else: # Reached destination
			velocity = Vector2.ZERO # Stop all movement
			_is_walking_to_target = false
			set_animation_state("idle")

			# --- THIS IS THE NEW, CRITICAL LINE ---
			# Tell the GameManager that ANY walk command is now finished, unlocking mouse input.
			if GameManager and GameManager.has_method("player_has_finished_walk_command"):
				GameManager.player_has_finished_walk_command()
			# -------------------------------------

			if is_instance_valid(_interactable_after_walk):
				face_target(_interactable_after_walk.global_position) # Face the interactable

				var interactable_ref = _interactable_after_walk
				var verb_ref = _verb_for_interaction
				var item_ref = _item_for_interaction

				# Clear player's state for this interaction
				_interactable_after_walk = null
				_verb_for_interaction = ""
				_item_for_interaction = null

				# Tell GameManager the player has arrived to trigger the interaction
				if GameManager and GameManager.has_method("player_reached_interaction_target"):
					GameManager.player_reached_interaction_target(interactable_ref, verb_ref, item_ref)
				else:
					print_rich("[color=red]Player: GameManager or player_reached_interaction_target method not found![/color]")
			else:
				print_rich("[color=yellow]Player: Reached walk target point.[/color]")
		move_and_slide()
		return

	# --- No keyboard input, just apply physics when idle ---
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else: # On floor
		velocity.y = move_toward(velocity.y, 0, GRAVITY * delta * 0.1) # Gentle Y damping

	# Apply friction to stop sliding
	velocity.x = move_toward(velocity.x, 0, SPEED * 0.5)
	if abs(velocity.x) < 1.0 : velocity.x = 0

	# Only set idle animation if we're not already trying to walk somewhere
	if not _is_walking_to_target:
		set_animation_state("idle")

	move_and_slide()


## Called by GameManager to walk to a generic point in the world.
func walk_to_point(destination_pos: Vector2):
	if not _can_move:
		print("Player: Cannot walk_to_point, _can_move is false.")
		return

	# Clear any pending interaction, as this is just a move command.
	_interactable_after_walk = null
	_verb_for_interaction = ""
	_item_for_interaction = null

	_actual_walk_destination.x = destination_pos.x
	_actual_walk_destination.y = global_position.y

	_start_walk_position_x = global_position.x
	_is_walking_to_target = true

	print("Player: Walking to point: %s" % str(_actual_walk_destination))


## Called by GameManager to initiate walking to an interactable
func walk_to_and_interact(interactable_walk_to_point_pos: Vector2, interactable_node: Interactable, verb_id: String, item_data: ItemData):
	if not _can_move:
		print("Player: Cannot walk_to_and_interact, _can_move is false.")
		return

	_interactable_after_walk = interactable_node
	_verb_for_interaction = verb_id
	_item_for_interaction = item_data

	var target_x = interactable_walk_to_point_pos.x
	var target_y = global_position.y

	if global_position.x < target_x: # Player is to the left of the interactable's core X
		_actual_walk_destination.x = target_x - INTERACTION_OFFSET_X
	else: # Player is to the right
		_actual_walk_destination.x = target_x + INTERACTION_OFFSET_X

	_actual_walk_destination.y = target_y

	_start_walk_position_x = global_position.x
	_is_walking_to_target = true

	var item_name_for_log = "None"
	if _item_for_interaction: item_name_for_log = _item_for_interaction.display_name

	print("Player: Original WalkToPoint: %s. Calculated Destination: %s for verb '%s' on '%s' with item '%s'" % [
		str(interactable_walk_to_point_pos),
		str(_actual_walk_destination),
		verb_id,
		interactable_node.object_display_name,
		item_name_for_log
	])

func set_can_move(value: bool):
	_can_move = value
	if not _can_move:
		_is_walking_to_target = false # Cancel any auto-walk
		velocity.x = 0 # Stop horizontal movement immediately
		if not is_on_floor():
			pass
		else:
			velocity.y = 0
		set_animation_state("idle") # Ensure idle animation when movement disabled

func face_target(target_global_position: Vector2):
	if not _can_move and not _is_walking_to_target:
		pass

	if not is_instance_valid(sprite_2d): return

	if target_global_position.x > global_position.x + 1.0: # Add a small threshold
		sprite_2d.flip_h = false # Face right
	elif target_global_position.x < global_position.x - 1.0: # Add a small threshold
		sprite_2d.flip_h = true  # Face left

# --- Animation Helper Functions ---
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
	else:
		print_rich("[color=red]Player: '%s' animation not found in AnimationPlayer.[/color]" % anim_name)
