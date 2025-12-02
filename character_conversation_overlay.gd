extends CanvasLayer
class_name CharacterConversationOverlay

signal conversation_finished(dialogue_resource: DialogueResource)

# --- EXPORT VARIABLES ---
@export var conversation_dialogue_file: DialogueResource
@export var background_animations: SpriteFrames
@export var initial_animation_name: String = "float_loop"
@export var scene_character_sprite_texture: Texture2D

# --- NODE REFERENCES ---
@onready var root_container: Control = $RootContainer
@onready var animated_background: TextureRect = $RootContainer/AnimatedBackground
@onready var character_main_sprite: Sprite2D = $RootContainer/CharacterMainSprite
@onready var background_sprite: Sprite2D = $RootContainer/BackgroundSprite


# --- ANIMATION STATE VARIABLES ---
var _current_anim_name: String = ""
var _current_frame_index: int = 0
var _time_since_last_frame: float = 0.0
var _is_playing: bool = false

# --- SHAKE STATE VARIABLES ---
var _is_shaking: bool = false
var _shake_timer: float = 0.0
var _shake_strength: float = 10.0
var _shake_rng := RandomNumberGenerator.new()
var _is_persistent_shake: bool = false
var _ignore_next_got_dialogue_signal: bool = false # <-- NEW: The fix!


func _ready():
	# --- Optional Character Sprite Logic ---
	if character_main_sprite:
		if scene_character_sprite_texture:
			character_main_sprite.texture = scene_character_sprite_texture
			character_main_sprite.visible = true
		else:
			character_main_sprite.visible = false
	else:
		print_rich("[color=orange]CharacterConversationOverlay: 'CharacterMainSprite' node not found.[/color]")

	# --- Signal Connections ---
	DialogueManager.dialogue_ended.connect(_on_dialoge_ended_from_manager)
	DialogueManager.got_dialogue.connect(_on_got_dialogue)

	# --- Initialize RNG for shaking ---
	_shake_rng.randomize()

	# --- Start Initial Animation and Dialogue ---
	if background_animations:
		play_animation(initial_animation_name)
	else:
		print_rich("[color=red]No 'background_animations' (SpriteFrames) assigned![/color]")

	# --- UPDATED DIALOGUE START ---
	if conversation_dialogue_file:
		DialogueManager.show_dialogue_balloon_scene(
			"res://conversationballoon.tscn",
			conversation_dialogue_file,
			"start",
			[self]
		)
	else:
		print_rich("[color=red]No 'conversation_dialogue_file' assigned![/color]")
		conversation_finished.emit(null)
		_cleanup_and_queue_free()


func _process(delta: float):
	# --- UNCHANGED SHAKE LOGIC ---
	if _is_shaking:
		if not _is_persistent_shake:
			_shake_timer -= delta
			if _shake_timer <= 0:
				_is_shaking = false
				root_container.position = Vector2.ZERO

		if _is_shaking:
			var offset_x = _shake_rng.randf_range(-_shake_strength, _shake_strength)
			var offset_y = _shake_rng.randf_range(-_shake_strength, _shake_strength)
			root_container.position = Vector2(offset_x, offset_y)

	# --- Existing Animated Background Logic ---
	if not _is_playing or not background_animations:
		return

	var anim_speed = background_animations.get_animation_speed(_current_anim_name)
	if anim_speed == 0: return

	var frame_count = background_animations.get_frame_count(_current_anim_name)
	var does_loop = background_animations.get_animation_loop(_current_anim_name)
	var time_per_frame = 1.0 / anim_speed
	_time_since_last_frame += delta
	if _time_since_last_frame >= time_per_frame:
		_time_since_last_frame -= time_per_frame
		_current_frame_index += 1
		if _current_frame_index >= frame_count:
			if does_loop: _current_frame_index = 0
			else:
				_current_frame_index = frame_count - 1
				_is_playing = false
		update_frame()


# --- UPDATED SIGNAL HANDLER ---
func _on_got_dialogue(_line: DialogueLine):
	# If our "ignore" flag is up, lower it and exit immediately.
	# This consumes the signal from the line the `do shake` is on.
	if _ignore_next_got_dialogue_signal:
		_ignore_next_got_dialogue_signal = false
		return

	# If the flag was down, and we're in a persistent shake, stop it.
	if _is_persistent_shake:
		_is_shaking = false
		_is_persistent_shake = false
		root_container.position = Vector2.ZERO
		print_rich("[color=orange]Persistent shake stopped by new dialogue line.[/color]")


# --- UPDATED SHAKE FUNCTION ---
func shake(duration: float = 0.4, strength: float = 10.0):
	_shake_strength = strength
	_is_shaking = true

	if duration < 0:
		_is_persistent_shake = true
		_ignore_next_got_dialogue_signal = true # <-- SET THE FLAG
		print_rich("[color=cyan]Starting PERSISTENT shake with strength " + str(strength) + "[/color]")
	else:
		_is_persistent_shake = false
		_ignore_next_got_dialogue_signal = false # <-- Ensure flag is down for timed shakes
		_shake_timer = duration
		print_rich("[color=cyan]Starting TIMED shake for " + str(duration) + "s with strength " + str(strength) + "[/color]")


# --- UNCHANGED FUNCTIONS BELOW ---

func play_animation(anim_name: String):
	if not background_animations.has_animation(anim_name):
		print_rich("[color=red]Animation '"+anim_name+"' not found.[/color]")
		return
	_current_anim_name = anim_name
	_current_frame_index = 0
	_time_since_last_frame = 0.0
	_is_playing = true
	update_frame()
	print_rich("[color=green]Playing animation: '"+_current_anim_name+"'[/color]")


func update_frame():
	if animated_background and background_animations.has_animation(_current_anim_name):
		var texture = background_animations.get_frame_texture(_current_anim_name, _current_frame_index)
		animated_background.texture = texture


func change_background_animation(animation_name: String):
	play_animation(animation_name)


func change_background_sprite(texture_path: String):
	if not background_sprite:
		print_rich("[color=red]Cannot change background: 'BackgroundSprite' node not found.[/color]")
		return
	if texture_path.is_empty():
		background_sprite.visible = false
		print_rich("[color=orange]BackgroundSprite hidden.[/color]")
		return
	var new_texture = load(texture_path)
	if new_texture is Texture2D:
		background_sprite.texture = new_texture
		background_sprite.visible = true
		print_rich("[color=green]BackgroundSprite texture updated to: " + texture_path + "[/color]")
	else:
		print_rich("[color=red]Failed to load texture for BackgroundSprite at path: " + texture_path + "[/color]")


func _on_dialoge_ended_from_manager(resource: DialogueResource):
	if resource == conversation_dialogue_file:
		conversation_finished.emit(resource)
		_cleanup_and_queue_free()

func _cleanup_and_queue_free():
	if DialogueManager.is_connected("dialogue_ended", _on_dialoge_ended_from_manager):
		DialogueManager.disconnect("dialogue_ended", _on_dialoge_ended_from_manager)
	if DialogueManager.is_connected("got_dialogue", _on_got_dialogue):
		DialogueManager.disconnect("got_dialogue", _on_got_dialogue)
	queue_free()


func _exit_tree():
	_cleanup_and_queue_free()
