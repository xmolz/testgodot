extends Sprite2D
## step 2.404: an item shown beside a character in a conversation, not drawn in her hand: it pops in next to
## her at chest height, on the side facing the others, bobs gently, and has a soft light rim and a shadow so
## it reads on any backdrop. AdvancedConversationOverlay.actor_item() adds it as a child of the character's
## picture, so it follows her moves, close-ups and dimming; it never mirrors when she's flipped.

## item name -> picture (the developer's art: 512x512, transparent background)
const PICTURES := {
	"phone": "res://Sprites/held_items/layla_phone.png",
	"keycard": "res://Sprites/held_items/access_card.png",
	"camera": "res://Sprites/held_items/camera.png",
}
## how tall the picture is drawn, in the character's canvas pixels (the cast's canvas is 1100x1740)
const CANVAS_PX := 300.0
## where it sits: this far across from her face toward the others (fraction of the canvas width), and this
## far below her eye line (fraction of the canvas height)
const SIDE_OFFSET := 0.30
const DROP := 0.24
## the bob: canvas pixels up and down, and seconds per bob
const BOB_PX := 8.0
const BOB_SECONDS := 2.6
const POP_SECONDS := 0.3
const RIM_SHADER := preload("res://ui/held_item_rim.gdshader")

var _face := Vector2(0.5, 0.3)   # her face, as fractions of her picture (face_x, face_y)
var _t := 0.0
var _pop := 0.0
var _tween: Tween


## false when the item has no picture (unknown name, or the file isn't in place yet)
func setup(item: String, face_ratio: Vector2) -> bool:
	var path: String = PICTURES.get(item, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("HeldItem: no picture for '%s' (%s)" % [item, path])
		return false
	texture = load(path)
	_face = face_ratio
	var mat := ShaderMaterial.new()
	mat.shader = RIM_SHADER
	material = mat
	var shadow := Sprite2D.new()
	shadow.texture = texture
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.3)
	shadow.position = Vector2(14.0, 18.0)
	shadow.show_behind_parent = true
	add_child(shadow)
	modulate.a = 0.0
	return true


func _ready() -> void:
	_place()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "_pop", 1.0, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, POP_SECONDS * 0.6)


## pops away, then frees itself
func leave() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "_pop", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	_place()


func _place() -> void:
	var host := get_parent() as Control
	if host == null or texture == null:
		return
	var size: Vector2 = host.size
	if host is TextureRect and host.texture:
		size = host.texture.get_size()
	var xf: Transform2D = host.get_global_transform()
	var face := Vector2(size.x * _face.x, size.y * (_face.y + DROP))
	var right := face + Vector2(size.x * SIDE_OFFSET, 0.0)
	var left := face - Vector2(size.x * SIDE_OFFSET, 0.0)
	var mid: float = get_viewport_rect().size.x * 0.5
	var spot := right if absf((xf * right).x - mid) <= absf((xf * left).x - mid) else left
	position = spot + Vector2(0.0, sin(_t * TAU / BOB_SECONDS) * BOB_PX)
	# canvas pixels per picture pixel; the sign undoes her flip, so the item never mirrors
	var k: float = CANVAS_PX / float(texture.get_height()) * lerpf(0.6, 1.0, _pop)
	scale = Vector2(k * signf(xf.x.x), k * signf(xf.y.y))
