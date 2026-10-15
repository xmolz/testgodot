extends Control
## step 2.212 (rebuilt in 2.214): a comic thought bubble for the conversation stage, used as a prop:
##   do prop_enter("Thought", "res://conversation/props/layla_thought_bubble.tscn", "right", 330.0, 1.3)
##   do prop_call("Thought", "play")    # bubble puffs in, the equation builds, clears, the answer pops in
##   do prop_call("Thought", "burst")   # pops the bubble
##   do prop_leave("Thought")
## The cloud and its trail are drawn here: every circle gets a dark outline pass, then a white fill
## pass, plus a filled polygon through the circle centres so the inside is always solid.
## Children of Items pop in left to right (tree order); then Items clears and the children of
## Reveal pop in, the last one with the reveal sound and its Glow.
## Any child with a Clip/Picture inside is a portrait: the picture is fitted whole (head to toe)
## inside its frame, from its own visible pixels, whatever empty canvas the png has.

## sound per item pop, for the clear, and for the reveal, by SoundManager sfx name ("" = silent).
@export var pop_sfx: String = "ui_click"
@export var clear_sfx: String = ""
@export var reveal_sfx: String = ""
@export var trail_points: PackedVector3Array = PackedVector3Array([Vector3(34, 452, 13), Vector3(78, 414, 19), Vector3(132, 370, 26)])
@export var cloud_circles: PackedVector3Array = PackedVector3Array([
	Vector3(250, 105, 82), Vector3(375, 78, 92), Vector3(510, 82, 88), Vector3(628, 118, 76),
	Vector3(690, 205, 70), Vector3(628, 292, 74), Vector3(500, 322, 84), Vector3(360, 320, 84),
	Vector3(240, 296, 76), Vector3(190, 205, 74)])
@export var outline_width: float = 5.0
@export var fill_color: Color = Color(1, 1, 1, 1)
@export var outline_color: Color = Color(0.12, 0.1, 0.12, 1)
## seconds between one equation piece and the next
@export var beat: float = 0.6
## how long the finished equation holds before it clears for the answer
@export var hold_before_clear: float = 0.9

const CLOUD_CENTRE := Vector2(440, 200)

var _cloud_t: float = 0.0          # 0..1, how grown the cloud is (drives _draw)
var _trail_t: float = 0.0          # 0..3, how many trail puffs are out

@onready var _items: Control = $Items
@onready var _reveal: Control = $Reveal


func _ready() -> void:
	pivot_offset = size * 0.5
	for group in [_items, _reveal]:
		for c in group.get_children():
			if c is CanvasItem:
				c.visible = false
			_fit_portrait(c)
	queue_redraw()


func _fit_portrait(frame: Node) -> void:
	var tr := frame.get_node_or_null("Clip/Picture") as TextureRect
	if tr == null or tr.texture == null or not (frame is Control):
		return
	var box := _opaque_box(tr.texture)
	var fsize: Vector2 = (frame as Control).size
	var s: float = minf(fsize.x / box.size.x, fsize.y / box.size.y)
	tr.size = Vector2(tr.texture.get_width(), tr.texture.get_height()) * s
	# centre the figure horizontally, stand it on the frame's bottom edge
	tr.position = Vector2(fsize.x * 0.5 - (box.position.x + box.size.x * 0.5) * s,
		fsize.y - (box.position.y + box.size.y) * s)


# the bounding box of the picture's visible pixels (sampled every few pixels).
func _opaque_box(tex: Texture2D) -> Rect2:
	var img := tex.get_image()
	if img == null:
		return Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height()))
	if img.is_compressed():
		img.decompress()
	var step := maxi(2, int(img.get_width() / 200))
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			if img.get_pixel(x, y).a > 0.5:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2(Vector2.ZERO, Vector2(img.get_width(), img.get_height()))
	return Rect2(min_x, min_y, max_x - min_x + step, max_y - min_y + step)


func _draw() -> void:
	var puffs: int = int(floor(_trail_t))
	var trail: Array = []
	for i in trail_points.size():
		if i < puffs:
			trail.append(trail_points[i])
	var cloud: Array = []
	var core := PackedVector2Array()
	if _cloud_t > 0.0:
		for c in cloud_circles:
			var p := CLOUD_CENTRE.lerp(Vector2(c.x, c.y), _cloud_t)
			cloud.append(Vector3(p.x, p.y, c.z * _cloud_t))
			core.append(p)
	for c in trail + cloud:
		draw_circle(Vector2(c.x, c.y), c.z + outline_width, outline_color)
	for c in trail + cloud:
		draw_circle(Vector2(c.x, c.y), c.z, fill_color)
	# the circles are listed around the cloud's rim, so their centres make a solid core
	if core.size() >= 3:
		draw_colored_polygon(core, fill_color)


func _set_cloud_t(v: float) -> void:
	_cloud_t = v
	queue_redraw()


func _set_trail_t(v: float) -> void:
	_trail_t = v
	queue_redraw()


func _sfx(sfx_name: String) -> void:
	if sfx_name.is_empty():
		return
	var sm = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_sfx"):
		sm.play_sfx(sfx_name)


func play() -> void:
	# trail puffs out from the thinker, then the cloud blooms
	var t := create_tween()
	t.tween_method(_set_trail_t, 0.0, float(trail_points.size()) + 0.01, 0.42)
	t.tween_method(_set_cloud_t, 0.0, 1.06, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_cloud_t, 1.06, 1.0, 0.1)
	await t.finished
	await get_tree().create_timer(0.25).timeout
	# the equation builds up to "="
	for node in _items.get_children():
		if node is Control:
			await _pop_in(node, pop_sfx)
			await get_tree().create_timer(beat).timeout
	await get_tree().create_timer(hold_before_clear).timeout
	# it clears...
	_sfx(clear_sfx)
	var c := create_tween().set_parallel(true)
	for node in _items.get_children():
		if node is Control:
			node.pivot_offset = node.size * 0.5
			c.tween_property(node, "scale", Vector2(0.3, 0.3), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			c.tween_property(node, "modulate:a", 0.0, 0.22)
	await c.finished
	await get_tree().create_timer(0.35).timeout
	# ...for the answer
	var answers := _reveal.get_children()
	for i in answers.size():
		var node := answers[i] as Control
		if node:
			var last := i == answers.size() - 1
			await _pop_in(node, reveal_sfx if last and not reveal_sfx.is_empty() else pop_sfx, last)


func _pop_in(node: Control, sfx_name: String, with_glow: bool = false) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.2, 0.2)
	node.modulate.a = 0.0
	node.visible = true
	_sfx(sfx_name)
	var t := create_tween().set_parallel(true)
	t.tween_property(node, "modulate:a", 1.0, 0.12)
	t.tween_property(node, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(node, "scale", Vector2.ONE, 0.12)
	if with_glow:
		var glow := node.get_node_or_null("Glow") as CanvasItem
		if glow:
			glow.modulate.a = 0.0
			t.chain().tween_property(glow, "modulate:a", 1.0, 0.35)
	await t.finished


func burst() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	await t.finished
