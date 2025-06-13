# VerbData.gd
extends Resource
class_name VerbData # Makes it usable as a type hint

## The unique internal identifier for this verb (e.g., "examine", "talk_to")
@export var verb_id: String = ""

## The text displayed on the UI button for this verb (e.g., "Examine", "Talk to")
@export var display_text: String = ""

## Optional: An icon for the verb button
# @export var icon: Texture2D = null

## Is this verb available by default when the game starts or a new general state begins?
@export var unlocked_by_default: bool = true

## Does this verb typically require the player to click on a target object after selecting the verb?
## (e.g., "Examine" might sometimes be used on the general scene, but mostly on objects)
@export var requires_target_object: bool = true

# You could add more properties later, like:
# @export var sfx_on_select: AudioStream = null
# @export var cursor_to_use: Texture2D = null
