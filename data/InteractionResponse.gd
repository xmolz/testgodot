# res://data/interactionresponse.gd
class_name InteractionResponse
extends Resource

# the verb that the player
@export var verb_id: String = ""

# if not empty, this is
@export var required_item_id: String = ""

# optional: the name of a game flag that must be checked.
@export var required_flag_id: String = ""
# the value the flag must
@export var required_flag_value: bool = true

# *******************(add this variable)
# checked: player walks to object.
@export var requires_walk: bool = true 
#

# the sequence of actions to
@export var actions_to_perform: Array[Action]
