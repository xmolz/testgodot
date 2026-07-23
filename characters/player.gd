extends CharacterBody2D

const SPEED = 700.0
const GRAVITY = 800.0
const WALK_TO_THRESHOLD_X = 5.0
const INTERACTION_OFFSET_X = 30.0

# variable to hold the calculated safe stopping distance
var player_half_width: float = 65.0 

@onready var sprite_2d: Sprite2D = $Sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var thought_bubble_pivot = $ThoughtBubblePivot
@onready var thought_bubble_pos = $ThoughtBubblePos
@onready var prompt_label = $ThoughtBubblePivot/ThoughtBubble/MarginContainer/PromptLabel
var _thought_bounce_tween: Tween

var current_animation_state = "idle"

var _is_walking_to_target: bool = false
var _actual_walk_destination: Vector2
var _start_walk_position_x: float = 0.0
var _interactable_after_walk: Interactable = null
var _verb_for_interaction: String = ""
var _item_for_interaction: ItemData = null
var _can_move: bool = true
var _stuck_timer: float = 0.0
var _is_manual_walking: bool = false

func _ready():
	# if not sprite_2d: print_rich("[color=red]player: sprite2d
	# ***********[if not animation_player: print_rich("[color=red]player: animationplayer node not found![/color]")]
	
	# *****************[auto-calculate width]
	# this makes the wall-stopping logic
	if collision_shape_2d and collision_shape_2d.shape is RectangleShape2D:
		var shape_w = collision_shape_2d.shape.size.x
		# formula: (shape width / 2) * object scale + buffer
		player_half_width = (shape_w * global_scale.x / 2.0) + 15.0
		# print("player: auto-calculated stopping distance: ",
	else:
		pass
		# print_rich("[color=yellow]player: could not calc width
	
	play_animation("idle")

	thought_bubble_pivot.visible = false
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(0, 0, 0, 0.8)
	bubble_style.border_width_left = 3
	bubble_style.border_width_top = 3
	bubble_style.border_width_right = 3
	bubble_style.border_width_bottom = 3
	bubble_style.border_color = Color(1, 1, 1, 1)
	bubble_style.corner_radius_top_left = 20
	bubble_style.corner_radius_top_right = 20
	bubble_style.corner_radius_bottom_left = 20
	bubble_style.corner_radius_bottom_right = 20
	$ThoughtBubblePivot/ThoughtBubble.add_theme_stylebox_override("panel", bubble_style)
	prompt_label.add_theme_font_override("normal_font", preload("res://Fonts/VarelaRound-Regular.ttf"))
	prompt_label.add_theme_font_override("bold_font", preload("res://Fonts/varela_round_bold.tres"))
	prompt_label.add_theme_font_override("italics_font", preload("res://Fonts/varela_round_italic.tres"))
	prompt_label.add_theme_font_override("bold_italics_font", preload("res://Fonts/varela_round_bold_italic.tres"))
	prompt_label.add_theme_font_size_override("normal_font_size", 44)
	prompt_label.fit_content = true
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF

func _physics_process(delta: float):
	if not _can_move:
		if is_instance_valid(animation_player) and current_animation_state == "walk":
			set_animation_state("idle")
		velocity.x = 0
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		return

	# ************[unified manual movement (keyboard & mouse hold)]
	var manual_direction = Input.get_axis("ui_left", "ui_right")

	if GameManager and GameManager.is_mouse_held_for_walk:
		var mouse_x = get_global_mouse_position().x
		var dist = abs(mouse_x - global_position.x)

		# ////////////////////[hysteresis:]
		# if she is already walking,
		# if she is standing still,
		var active_deadzone = 20.0 if _is_manual_walking else 150.0

		if dist > active_deadzone:
			manual_direction = sign(mouse_x - global_position.x)

	if manual_direction != 0:
		if _is_walking_to_target:
			_stop_walking()

		_is_manual_walking = true
		velocity.x = manual_direction * SPEED

		if not is_on_floor():
			velocity.y += GRAVITY * delta

		if is_instance_valid(sprite_2d): sprite_2d.flip_h = (velocity.x < 0)

		move_and_slide()

		if abs(get_real_velocity().x) < 10.0:
			set_animation_state("idle")
		else:
			set_animation_state("walk")
		return

	elif _is_manual_walking:
		# she reached the 20px inner
		_is_manual_walking = false
		velocity.x = 0
		set_animation_state("idle")

		if not is_on_floor():
			velocity.y += GRAVITY * delta

		move_and_slide()
		return
	#

	if _is_walking_to_target:
		var direction_to_destination = global_position.direction_to(_actual_walk_destination)
		var x_distance_to_destination = abs(global_position.x - _actual_walk_destination.x)

		# ***********[stuck failsafe]
		if abs(get_real_velocity().x) < 10.0:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0

		if _stuck_timer > 0.2:
			_stop_walking()
			return
		#

		# calculate exactly how far we will move this frame
		var step_distance = SPEED * delta

		# if the distance to the
		if x_distance_to_destination > (step_distance + WALK_TO_THRESHOLD_X):
			velocity.x = sign(_actual_walk_destination.x - global_position.x) * SPEED

			if not is_on_floor():
				velocity.y += GRAVITY * delta

			if is_instance_valid(sprite_2d): sprite_2d.flip_h = (velocity.x < 0)
			set_animation_state("walk")

		else:
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

	# idle physic
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	velocity.x = 0

	if not _is_walking_to_target and current_animation_state == "walk":
		set_animation_state("idle")

	move_and_slide()

# helper to cleanly stop walking
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
		# print_rich("[color=green]hit wall at %s. adjusting
		var direction_back = (global_position - result.position).normalized()
		
		# ////////////////////[dynamic stopping distance]
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

	# ////////////[custom offset logic]
	var current_offset = INTERACTION_OFFSET_X
	if verb_id == "flash":
		current_offset = 270.0
	#

	# ////////////[approach side override]
	var forced_side = 0
	if is_instance_valid(interactable_node) and "approach_side" in interactable_node:
		forced_side = interactable_node.approach_side

	if forced_side == 1:
		_actual_walk_destination.x = target_x - current_offset
	elif forced_side == 2:
		_actual_walk_destination.x = target_x + current_offset
	else:
		if global_position.x < target_x:
			_actual_walk_destination.x = target_x - current_offset
		else:
			_actual_walk_destination.x = target_x + current_offset
	#

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
		
func show_thought_bubble(text: String):
	prompt_label.text = "[center]" + text + "[/center]"
	thought_bubble_pivot.visible = true

	if is_instance_valid(thought_bubble_pos):
		var target_x = thought_bubble_pos.position.x
		if sprite_2d and sprite_2d.flip_h:
			# apply a manual offset to
			target_x = -target_x - (-10.0)

		thought_bubble_pivot.position = Vector2(target_x, thought_bubble_pos.position.y)

		if _thought_bounce_tween: _thought_bounce_tween.kill()
		_thought_bounce_tween = create_tween().set_loops()
		_thought_bounce_tween.tween_property(thought_bubble_pivot, "position:y", thought_bubble_pos.position.y - 10.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_thought_bounce_tween.tween_property(thought_bubble_pivot, "position:y", thought_bubble_pos.position.y, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func hide_thought_bubble():
	thought_bubble_pivot.visible = false
	if _thought_bounce_tween: _thought_bounce_tween.kill()

var _last_step_time: int = 0
const STEP_COOLDOWN_MSEC: int = 350

func on_footstep_frame():
	# check if we are moving
	if velocity.length() < 1.0:
		return

	# check time cooldown
	var current_time = Time.get_ticks_msec()
	if current_time - _last_step_time < STEP_COOLDOWN_MSEC:
		return

	# /////////////////[3. play sound & reset timer]
	SoundManager.play_random_footstep()
	_last_step_time = current_time
