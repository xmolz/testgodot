extends Control
## step 2.185: dev-only preview for conversation/phone/phone_cg.tscn (not used by the game).
## Open Dev/phone_cg_preview.tscn and press F6 (Run Current Scene).

const POSES := [
	[Vector2.ZERO, 0.0, 1.0], # 1: rest
	[Vector2(-150, 380), -6.0, 1.35], # 2: brought close, screen fills the view
	[Vector2(260, 140), 7.0, 0.85], # 3: tilted away
]

@onready var phone: Control = $PhoneCG
@onready var help: Label = $Help


func _ready() -> void:
	help.text = "Up / Down: move selection     1 / 2 / 3: poses (rest, close, tilted)\nB: backlight on / off     S: hand sway on / off     H: hide this help"
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_UP:
			phone.step_selection(-1)
		KEY_DOWN:
			phone.step_selection(1)
		KEY_1, KEY_2, KEY_3:
			var pose: Array = POSES[key.keycode - KEY_1]
			phone.move_to(pose[0], pose[1], pose[2], 0.7)
		KEY_B:
			phone.fade_backlight(0.0 if phone.backlight > 0.5 else 1.0, 0.25)
		KEY_S:
			phone.sway_enabled = not phone.sway_enabled
		KEY_H:
			help.visible = not help.visible
		_:
			return
	get_viewport().set_input_as_handled()
