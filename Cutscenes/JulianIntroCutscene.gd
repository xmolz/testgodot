extends Cutscene
## Julian's introduction CG. Fires once, the first time the player enters the Grad Commons.
## Trigger: Events.room_changed + player inside ROOM_RECT + level flag not yet set.

const FLAG_SEEN := "julian_intro_seen"
const OVERLAY_SCENE := "res://conversation/julian_intro_overlay.tscn"
const ROOM_RECT := Rect2(4800, 3000, 3840, 1080)
const ENTRY_DELAY := 0.45

var _armed: bool = true


func _ready() -> void:
	super._ready()
	Events.room_changed.connect(_on_room_changed)


func _on_level_state_ready() -> void:
	# nothing to reconcile: the flag is written only after the conversation ends,
	# so an interrupted run simply replays on next entry.
	_armed = not Flags.get_level_flag(FLAG_SEEN)


func _on_room_changed() -> void:
	if not _armed:
		return
	if Flags.get_level_flag(FLAG_SEEN):
		_armed = false
		return
	var player = GameManager.player_node
	if not is_instance_valid(player):
		return
	if not ROOM_RECT.has_point(player.global_position):
		return
	_armed = false
	start_cutscene()


func _execution_steps() -> void:
	await get_tree().create_timer(ENTRY_DELAY).timeout
	var packed: PackedScene = load(OVERLAY_SCENE)
	if packed == null:
		push_error("JulianIntroCutscene: missing overlay scene %s" % OVERLAY_SCENE)
		Flags.set_level_flag(FLAG_SEEN, true)
		return
	var overlay = packed.instantiate()
	get_tree().root.add_child(overlay)
	overlay.begin_conversation()
	await overlay.conversation_finished
	Flags.set_level_flag(FLAG_SEEN, true)
	if is_instance_valid(overlay) and overlay.is_inside_tree():
		overlay.queue_free()
