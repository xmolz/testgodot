# TransitionLayer.gd
extends CanvasLayer

signal transition_halfway 
signal transition_finished

@onready var left_shutter = get_node_or_null("LeftShutter")
@onready var right_shutter = get_node_or_null("RightShutter")
@onready var iris_rect = get_node_or_null("IrisColorRect")

func _ready():
	open_instant()

func open_instant():
	# If Godot runs this before the screen is ready, safely abort to prevent crashes.
	if not left_shutter or not right_shutter: return
	
	var viewport_width = get_viewport().get_visible_rect().size.x
	left_shutter.position.x = -left_shutter.size.x
	right_shutter.position.x = viewport_width
	
	if iris_rect and iris_rect.material:
		iris_rect.material.set_shader_parameter("circle_size", 1.5)
		iris_rect.visible = false

# --- 1. SCI-FI DOOR TRANSITION (Used for Teleporting) ---
func play_transition_sequence():
	if not left_shutter or not right_shutter: return
	
	var viewport_width = get_viewport().get_visible_rect().size.x
	var center_x = viewport_width / 2.0
	
	SoundManager.play_sfx("door_close")
	
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(left_shutter, "position:x", 0.0, 0.5)
	tween.tween_property(right_shutter, "position:x", center_x, 0.5)
	await tween.finished
	
	emit_signal("transition_halfway")
	
	# 1.2 second delay while screen is black (1 second longer)
	await get_tree().create_timer(1.2).timeout
	
	SoundManager.play_sfx("door_open")
	
	var open_tween = create_tween().set_parallel(true)
	open_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	open_tween.tween_property(left_shutter, "position:x", -left_shutter.size.x, 0.5)
	open_tween.tween_property(right_shutter, "position:x", viewport_width, 0.5)
	
	await open_tween.finished
	emit_signal("transition_finished")


# --- 2. IRIS "EYE" TRANSITIONS (Used for loading states) ---
func play_iris_close(duration: float = 1.0):
	if not iris_rect or not iris_rect.material: 
		await get_tree().create_timer(duration).timeout
		emit_signal("transition_halfway")
		return
	
	iris_rect.visible = true
	iris_rect.material.set_shader_parameter("circle_size", 1.5) # Start wide open
	
	var tween = create_tween()
	# Tween to -0.1 to completely swallow the soft edge!
	tween.tween_property(iris_rect.material, "shader_parameter/circle_size", -0.1, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	emit_signal("transition_halfway")

func play_iris_open(duration: float = 1.0):
	if not iris_rect or not iris_rect.material: 
		await get_tree().create_timer(duration).timeout
		emit_signal("transition_finished")
		return
	
	iris_rect.visible = true
	iris_rect.material.set_shader_parameter("circle_size", -0.1) # Start completely closed
	
	var tween = create_tween()
	tween.tween_property(iris_rect.material, "shader_parameter/circle_size", 1.5, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	iris_rect.visible = false
	emit_signal("transition_finished")
