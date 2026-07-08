extends Node2D

var _pulse_time: float = 0.0

func _ready():
	z_index = 10 # Sit above floor, below player
	hide()

func _process(delta):
	if visible:
		_pulse_time += delta * 5.0
		queue_redraw()

func _draw():
	var color = Color(0.2, 0.85, 1.0, 0.6 + sin(_pulse_time) * 0.3)
	draw_arc(Vector2.ZERO, 15.0, 0, TAU, 32, color, 3.0, true)
	draw_circle(Vector2.ZERO, 4.0, color)
