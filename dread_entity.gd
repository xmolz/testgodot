extends Control

var base_aura: TextureRect
var face_rect: TextureRect
var _base_pos: Vector2

var evil_face_tex: Texture2D
var crying_face_tex: Texture2D

func _ready():
	_base_pos = position

	# Load the textures (Paths can be adjusted in the inspector/editor if needed)
	evil_face_tex = load("res://Backgrounds/dread_evil_face.png")
	crying_face_tex = load("res://Backgrounds/dread_crying_face.png")

	# Procedurally generate a soft purple aura
	base_aura = TextureRect.new()
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(0.5, 0.0, 0.8, 1.0), Color(0.5, 0.0, 0.8, 0.0)])
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 300
	tex.height = 300
	base_aura.texture = tex
	base_aura.position = Vector2(-150, -150)
	add_child(base_aura)

	# Create the Face TextureRect
	face_rect = TextureRect.new()
	face_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Make the face smaller (200x200 instead of 400x400)
	face_rect.size = Vector2(200, 200)
	# Shift by exactly half the size (-100, -100) to keep it perfectly centered
	face_rect.position = Vector2(-100, -100)
	face_rect.modulate.a = 0.0
	add_child(face_rect)

	# Breathing tween
	var tween = create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(_delta):
	# Glitch Movement
	if randf() < 0.08:
		position = _base_pos + Vector2(randf_range(-40, 40), randf_range(-20, 20))
		base_aura.modulate = Color(0.8, 0.2, 1.0, randf_range(0.4, 1.0))
	else:
		position = position.lerp(_base_pos, 0.2)
		base_aura.modulate = Color(0.6, 0.1, 0.8, 0.8)

	# Face Flash
	if randf() < 0.02 and face_rect.modulate.a <= 0.1:
		# Randomly pick which face to flash
		if randf() > 0.5:
			face_rect.texture = evil_face_tex
		else:
			face_rect.texture = crying_face_tex

		face_rect.modulate.a = randf_range(0.5, 1.0)
		var flash_tween = create_tween()
		flash_tween.tween_property(face_rect, "modulate:a", 0.0, 0.3)
