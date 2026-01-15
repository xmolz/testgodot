# TransitionLayer.gd
extends CanvasLayer

signal transition_halfway # Emitted when doors are fully closed
signal transition_finished # Emitted when doors are fully open again

@onready var left_shutter = $LeftShutter
@onready var right_shutter = $RightShutter

func _ready():
	# Ensure they start invisible/off-screen
	open_instant()

func open_instant():
	var viewport_width = get_viewport().get_visible_rect().size.x
	left_shutter.position.x = -left_shutter.size.x
	right_shutter.position.x = viewport_width

# This function plays the full sequence: Close -> Wait -> Open
func play_transition_sequence():
	var viewport_width = get_viewport().get_visible_rect().size.x
	var center_x = viewport_width / 2.0
	
	# --- PLAY CLOSE SOUND ---
	# We play this immediately as the shutters start moving in.
	SoundManager.play_sfx("door_close")
	
	var tween = create_tween()
	# Parallel animation: Both doors slide in at the same time
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART) # Nice smooth sci-fi motion
	tween.set_ease(Tween.EASE_OUT)
	
	# Slide Left Shutter to 0 (Left edge)
	tween.tween_property(left_shutter, "position:x", 0.0, 0.5)
	# Slide Right Shutter to center (Right edge moves left)
	tween.tween_property(right_shutter, "position:x", center_x, 0.5)
	
	# Wait for animation to finish
	await tween.finished
	
	emit_signal("transition_halfway") # TELL THE GAME TO TELEPORT NOW
	
	# Optional: Small pause while screen is black
	await get_tree().create_timer(0.2).timeout
	
	# --- PLAY OPEN SOUND ---
	# We play this right before the shutters start opening.
	SoundManager.play_sfx("door_open")
	
	# Open the doors
	var open_tween = create_tween()
	open_tween.set_parallel(true)
	open_tween.set_trans(Tween.TRANS_QUART)
	open_tween.set_ease(Tween.EASE_IN)
	
	# Slide back out
	open_tween.tween_property(left_shutter, "position:x", -left_shutter.size.x, 0.5)
	open_tween.tween_property(right_shutter, "position:x", viewport_width, 0.5)
	
	await open_tween.finished
	emit_signal("transition_finished")
