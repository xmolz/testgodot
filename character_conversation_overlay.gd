extends CanvasLayer
class_name CharacterConversationOverlay

# This signal will be emitted when the conversation is fully finished
signal conversation_finished(dialogue_resource: DialogueResource)

# --- Export Variables (configure these in the Inspector of THIS scene) ---
@export var conversation_dialogue_file: DialogueResource # Drag the character's .dialogue file here (e.g., faye.dialogue)
@export var scene_background_texture: Texture2D # Drag the background image for this conversation here
@export var scene_character_sprite_texture: Texture2D # Drag the character sprite for this conversation here

# --- Node References (wire these up in the @onready section) ---
@onready var background_rect: ColorRect = $BackgroundRect # To capture clicks
@onready var background_sprite: TextureRect = $BackgroundSprite # The actual background image
@onready var character_main_sprite: Sprite2D = $CharacterMainSprite


func _ready():
	# Set the visuals from this scene's exports
	if background_sprite:
		background_sprite.texture = scene_background_texture
	else:
		print_rich("[color=red]CharacterConversationOverlay: 'BackgroundSprite' TextureRect not found![/color]")

	if character_main_sprite:
		character_main_sprite.texture = scene_character_sprite_texture
		# Initial position/scale should be set in the scene editor for consistent placement
	else:
		print_rich("[color=red]CharacterConversationOverlay: 'CharacterMainSprite' Sprite2D not found![/color]")

	# Make sure the background rect stops mouse events from going to the game below
	background_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# --- Start the dialogue! ---
	if conversation_dialogue_file:
		print("CharacterConversationOverlay: Starting dialogue: ", conversation_dialogue_file.resource_path)
		# NEW LINE: Use show_dialogue_balloon_scene to specify your custom balloon
		DialogueManager.show_dialogue_balloon_scene(
			"res://conversationballoon.tscn", # Path to your custom balloon scene
			conversation_dialogue_file,
			"start"
		)
	else:
		print_rich("[color=red]CharacterConversationOverlay: No 'conversation_dialogue_file' assigned to this scene![/color]")
		# If no dialogue file, signal immediate completion
		conversation_finished.emit(null) # Null resource indicates abnormal end
		queue_free()

	# Connect to DialogueManager's dialogue_ended signal to know when *its* dialogue ends
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended_from_manager)

func _on_dialogue_ended_from_manager(resource: DialogueResource):
	# This signal fires when DialogueManager runs out of dialogue lines *for this specific dialogue resource*.
	# Ensure it's the dialogue resource associated with this overlay that just ended.
	if resource == conversation_dialogue_file:
		print("CharacterConversationOverlay: Dialogue with ", resource.resource_path, " concluded.")
		conversation_finished.emit(resource) # Signal GameManager that we are done
		# Disconnect to prevent multiple connections if this overlay is reused (though we queue_free immediately)
		if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended_from_manager):
			DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended_from_manager)
		queue_free() # Remove this overlay from the scene tree
