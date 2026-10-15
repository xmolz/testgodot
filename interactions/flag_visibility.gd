extends CanvasItem
## step 2.209: shows this node only while a level flag has the given value (true by default).
## Attach to any Sprite2D / Node2D / Control placed in a level. In the editor the node stays
## visible so it can be positioned; in game it follows the flag and updates when it changes.

@export var flag_name: String = ""
@export var show_when: bool = true


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	visible = _wanted()
	call_deferred("_hook_flags")


func _hook_flags() -> void:
	var lsm = Flags.current_level_state_manager
	if lsm and not lsm.level_flag_changed.is_connected(_on_level_flag_changed):
		lsm.level_flag_changed.connect(_on_level_flag_changed)
	visible = _wanted()


func _on_level_flag_changed(changed_flag: String, _value: bool) -> void:
	if changed_flag == flag_name:
		visible = _wanted()


func _wanted() -> bool:
	if flag_name.is_empty():
		return true
	return Flags.get_level_flag(flag_name) == show_when
