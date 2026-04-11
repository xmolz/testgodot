extends Control

var sun_sprite: TextureRect

func _ready():
	sun_sprite = TextureRect.new()
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.9, 0.6, 1.0), Color(1.0, 0.6, 0.7, 0.8), Color(1.0, 0.4, 0.6, 0.0)])
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 400
	tex.height = 400
	sun_sprite.texture = tex
	sun_sprite.position = Vector2(-200, -200)
	sun_sprite.pivot_offset = Vector2(200, 200)
	add_child(sun_sprite)

	# Gentle pulsing glow
	var pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(sun_sprite, "scale", Vector2(1.15, 1.15), 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(sun_sprite, "scale", Vector2(0.85, 0.85), 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
