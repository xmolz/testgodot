# ConversationEventManager.gd
extends Node


# Signal to request a background change in the active conversation overlay
# We pass the new texture path as an argument.
signal change_conversation_background(new_background_texture_path: String)

# You can add more conversation-related signals here later if needed,
# e.g., for character sprite changes, sound effects, etc.
