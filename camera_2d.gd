extends Camera2D

@export var target_path: NodePath
var target_node: Node2D

func _ready():
	if target_path:
		target_node = get_node_or_null(target_path)

	# 1. The Camera MUST update in Physics to match the Player's move_and_slide()
	#process_callback = Camera2D.PROCESS_CALLBACK_PHYSICS
	position_smoothing_enabled = false
	
	# 2. Turn OFF _process, turn ON _physics_process
	set_process(false)
	set_physics_process(true)

func _physics_process(_delta):
	if is_instance_valid(target_node):
		# 3. Snap perfectly to the player in the physics step.
		# Because Physics Interpolation is ON globally, Godot will now automatically 
		# smooth the visual rendering of BOTH the player and the camera together!
		global_position = target_node.global_position

func snap_to_target():
	if not target_node: return
	global_position = target_node.global_position
	reset_physics_interpolation()
