# res://interactions/actions/PlaySoundAction.gd
extends Action
class_name PlaySoundAction

## The key name of the sound to play (must exist in SoundManager.sfx_library).
@export var sound_name: String = ""

## If true, the game will wait for the sound to finish before starting the next action.
## Useful for "Sound -> Then Dialogue" sequences.
@export var wait_for_completion: bool = false

@export_range(0.1, 4.0) var pitch: float = 1.0
@export_range(-80.0, 24.0) var volume_db: float = 0.0

func execute(_interactable_node: Interactable) -> Variant:
	if sound_name == "":
		push_warning("PlaySoundAction: No sound_name specified.")
		return true

	# Call the manager and get the player instance back
	var audio_player = SoundManager.play_sfx(sound_name, pitch, volume_db)

	if wait_for_completion and is_instance_valid(audio_player):
		# This pauses the interaction sequence until the sound finishes
		await audio_player.finished
	
	return true
