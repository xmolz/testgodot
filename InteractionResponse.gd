# res://interactions/InteractionResponse.gd
class_name InteractionResponse
extends Resource

## The verb that the player must use (e.g., "use", "examine", "pickup").
@export var verb_id: String = ""

## If not empty, this is the item the player must have selected ("in hand").
@export var required_item_id: String = ""

## Optional: The name of a game flag that must be checked.
@export var required_flag_id: String = ""
## The value the flag must have for this interaction to be valid.
@export var required_flag_value: bool = true

# --- ADD THIS VARIABLE ---
## Checked: Player walks to object. Unchecked: Player acts from current position (remote).
@export var requires_walk: bool = true 
# -------------------------

## The sequence of actions to perform if the conditions are met.
@export var actions_to_perform: Array[Action]
