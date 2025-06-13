# ItemData.gd
extends Resource
class_name ItemData # Makes this usable as a type hint and for creating new resources easily

## The unique identifier for this item (e.g., "key_main_door", "burger_mystery_meat").
## Use snake_case, all lowercase, for consistency with verb_ids.
@export var item_id: String = ""

## The name of the item as it will be displayed to the player (e.g., in inventory, in dialogue).
@export var display_name: String = "New Item"

## The texture to use as an icon for this item in the inventory UI.
@export var icon: Texture2D = null

## The description of the item that the player sees/thinks when they "Examine" it
## (either directly in inventory or if they use "Examine" on the item in the world before picking it up).
@export_multiline var description: String = "It's an item."

## Can this item be stacked in the inventory? (e.g., arrows, coins)
## For most classic point-and-click adventure items, this will be false.
@export var is_stackable: bool = false

## If is_stackable is true, what's the maximum number that can be in one stack?
## (Not highly relevant if is_stackable is usually false).
@export var max_stack_size: int = 1

## (Optional) A list of verb_ids that this item can be *primarily* used with.
## This is more for filtering or providing hints, as the actual "Use Item X with Y"
## logic is usually defined on the target interactable (Y).
## Example: A key might primarily be for "use_item" (on a door). A food item might be for "give" or "use_item" (on self).
# @export var compatible_verb_ids: Array[String] = []

# You can add more game-specific properties here later, for example:
# @export var is_quest_item: bool = false
# @export var value: int = 0 # If you had currency
# @export var sfx_on_pickup: AudioStream = null
# @export var sfx_on_use: AudioStream = null

# No functions are strictly needed in this Resource script itself for basic data storage.
# Its purpose is to define a data structure that you can edit in the Inspector.

func _init(id: String = "", name: String = "", tex: Texture2D = null, desc: String = ""):
	# Optional constructor for creating instances from code, though mostly you'll use .tres files
	if id != "": item_id = id
	if name != "": display_name = name
	if tex != null: icon = tex
	if desc != "": description = desc
