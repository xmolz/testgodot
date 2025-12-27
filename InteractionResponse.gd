# res://interactions/InteractionResponse.gd
class_name InteractionResponse
extends Resource

## The conditions that must be met for this interaction to trigger.

# The verb that the player must use (e.g., "use", "examine", "pickup").
@export var verb_id: String = ""

# If not empty, this is the item the player must have selected ("in hand")
# for this interaction to work.
@export var required_item_id: String = ""


## The sequence of actions to perform if the conditions are met.
@export var actions_to_perform: Array[Action]
