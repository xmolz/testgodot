# notification.gd
extends PanelContainer

const DURATION = 4.0

@onready var label = $Label
@onready var timer = $Timer

var _fade_tween: Tween

func _ready():
	# set initial state for the "pop-in" animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

	if OS.has_feature("mobile"):
		label.add_theme_font_size_override("font_size", 36)
		var mobile_style = get_theme_stylebox("panel").duplicate()
		mobile_style.content_margin_left = 40
		mobile_style.content_margin_right = 40
		mobile_style.content_margin_top = 20
		mobile_style.content_margin_bottom = 20
		add_theme_stylebox_override("panel", mobile_style)
		reset_size()

	# we want the scale to
	pivot_offset = size / 2.0

	# the flashy pop-in tween
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_message(text: String):
	label.text = text
	timer.wait_time = DURATION
	timer.start()

# ------------------- updates the notification in-place with an attention-grabbing effect
func update_message(new_text: String):
	label.text = new_text
	timer.start(DURATION)

	# stop fading out if it was in the middle of disappearing
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	modulate.a = 1.0

	# re-center pivot in case the
	pivot_offset = size / 2.0

	# play a quick "bump" scale effect to catch the eye
	var bump_tween = create_tween()
	bump_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_SINE)
	bump_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# briefly flash the text color
	label.modulate = Color(0.2, 0.85, 1.0, 1.0)
	var color_tween = create_tween()
	color_tween.tween_property(label, "modulate", Color.WHITE, 0.4)

func _on_timer_timeout():
	# the smooth fade-out tween
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	# destroy the node after the fade out is complete
	_fade_tween.tween_callback(queue_free)
