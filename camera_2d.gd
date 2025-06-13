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
