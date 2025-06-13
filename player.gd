extends CharacterBody2D

const SPEED = 150.0
const GRAVITY = 800.0 # Make sure this matches your project settings if you use built-in gravity
const WALK_TO_THRESHOLD_X = 5.0 # How close on X axis to stop
const INTERACTION_OFFSET_X = 30.0 # Horizontal offset from the interactable's actual WalkToPoint.x

@onready var sprite_2d: Sprite2D = $Sprite # Ensure this node path is correct
@onready var animation_player: AnimationPlayer = $AnimationPlayer # Ensure this node path is correct

var current_animation_state = "idle"

var _is_walking_to_target: bool = false
var _actual_walk_destination: Vector2      # The final calculated X,Y point the player moves to
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

		if x_distance_to_destination > WALK_TO_THRESHOLD_X:
			velocity.x = direction_to_destination.x * SPEED
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			else: # On floor, gentle Y velocity adjustment
				velocity.y = move_toward(velocity.y, 0, GRAVITY * delta * 0.1) # Less aggressive Y damping

			if is_instance_valid(sprite_2d): sprite_2d.flip_h = (velocity.x < 0)
			set_animation_state("walk")
		else: # Reached destination
			velocity = Vector2.ZERO # Stop all movement
			_is_walking_to_target = false
			set_animation_state("idle")

			if is_instance_valid(_interactable_after_walk):
				face_target(_interactable_after_walk.global_position) # Face the interactable

				var interactable_ref = _interactable_after_walk
				var verb_ref = _verb_for_interaction
				var item_ref = _item_for_interaction

				# Clear player's state for this interaction
				_interactable_after_walk = null
				_verb_for_interaction = ""
				_item_for_interaction = null

				# Tell GameManager the player has arrived
				if GameManager and GameManager.has_method("player_reached_interaction_target"):
					GameManager.player_reached_interaction_target(interactable_ref, verb_ref, item_ref)
				else:
					print_rich("[color=red]Player: GameManager or player_reached_interaction_target method not found![/color]")
			else:
				print_rich("[color=yellow]Player: Reached walk target, but _interactable_after_walk was null or invalid.[/color]")
		move_and_slide()
		return

	# --- Normal Player-Controlled Movement ---
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else: # On floor
		velocity.y = move_toward(velocity.y, 0, GRAVITY * delta * 0.1) # Gentle Y damping

	var input_direction_x = Input.get_axis("move_left", "move_right")
	if input_direction_x != 0:
		velocity.x = input_direction_x * SPEED
		if is_instance_valid(sprite_2d): sprite_2d.flip_h = (velocity.x < 0)
		set_animation_state("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.5) # Allow some sliding to stop, or set to 0 for instant stop
		if abs(velocity.x) < 1.0 : velocity.x = 0 # Snap to zero if very slow
		set_animation_state("idle")

	move_and_slide()


## Called by GameManager to initiate walking to an interactable
func walk_to_and_interact(interactable_walk_to_point_pos: Vector2, interactable_node: Interactable, verb_id: String, item_data: ItemData):
	if not _can_move:
		print("Player: Cannot walk_to_and_interact, _can_move is false.")
		# Optionally, tell GameManager interaction can't proceed immediately
		# if GameManager and GameManager.has_method("cancel_current_interaction_flow"):
		#     GameManager.cancel_current_interaction_flow("Player cannot move")
		return

	_interactable_after_walk = interactable_node
	_verb_for_interaction = verb_id
	_item_for_interaction = item_data # MODIFIED: Store the ItemData object

	var target_x = interactable_walk_to_point_pos.x
	# Use the player's current Y position for the destination to avoid "snapping" up/down
	# unless the interactable's WalkToPoint is significantly different (e.g., stairs).
	# For simplicity, let's keep player's Y, assuming interactables are roughly on same ground level.
	var target_y = global_position.y # Or interactable_walk_to_point_pos.y if it's reliably ground level

	if global_position.x < target_x: # Player is to the left of the interactable's core X
		_actual_walk_destination.x = target_x - INTERACTION_OFFSET_X
	else: # Player is to the right
		_actual_walk_destination.x = target_x + INTERACTION_OFFSET_X

	_actual_walk_destination.y = target_y # Maintain player's current Y level

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
		# Let gravity take over if in air, or set Y to 0 if on ground
		if not is_on_floor():
			# Keep current Y velocity for natural fall
			pass
		else:
			velocity.y = 0
		set_animation_state("idle") # Ensure idle animation when movement disabled

func face_target(target_global_position: Vector2):
	if not _can_move and not _is_walking_to_target: # Allow facing if auto-walking, even if _can_move is false for dialogue
		# Or, more simply, always allow facing if called:
		pass # Remove the _can_move check here if facing should always be possible

	if not is_instance_valid(sprite_2d): return

	if target_global_position.x > global_position.x + 1.0: # Add a small threshold
		sprite_2d.flip_h = false # Face right
	elif target_global_position.x < global_position.x - 1.0: # Add a small threshold
		sprite_2d.flip_h = true  # Face left

# --- Animation Helper Functions ---
func set_animation_state(new_state: String):
	if not is_instance_valid(animation_player): return # Guard against invalid node

	if current_animation_state == new_state:
		if not animation_player.is_playing() and animation_player.has_animation(new_state):
			animation_player.play(new_state) # Restart if not playing (e.g. idle after finishing once)
		return

	current_animation_state = new_state
	play_animation(new_state)

func play_animation(anim_name: String):
	if not is_instance_valid(animation_player): return

	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	else:
		print_rich("[color=red]Player: '%s' animation not found in AnimationPlayer.[/color]" % anim_name)
