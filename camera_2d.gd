# Attach this script to your Camera2D node in main.tscn
extends Camera2D

@export var target_path: NodePath
var target_node: Node2D

func _ready():
	if target_path:
		target_node = get_node_or_null(target_path)
	if not target_node:
		print_rich("[color=red]Camera target not found! Assign Player to Target Path.[/color]")

	# IMPORTANT: Enable these in the Inspector for the Camera2D node:
	# - Limit Left, Limit Top, Limit Right, Limit Bottom (set your values)
	# - Position Smoothing Enabled (set to true)
	# - Position Smoothing Speed (e.g., 5.0)

func _process(delta): # Or _physics_process, matching player
	if target_node:
		# Simply update the camera's position to the target.
		# Let the built-in limits and position smoothing handle the rest.
		global_position = target_node.global_position


# Add this to camera_2d.gd

func snap_to_target():
	if not target_node: return
	
	# 1. Disable smoothing temporarily
	var previous_smoothing = position_smoothing_enabled
	position_smoothing_enabled = false
	
	# 2. Force position update immediately
	global_position = target_node.global_position
	
	# 3. We need to wait for the physics engine to acknowledge the move
	# before turning smoothing back on, otherwise it might still jitter.
	await get_tree().process_frame
	
	# 4. Re-enable smoothing
	position_smoothing_enabled = previous_smoothing
