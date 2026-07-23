# itemdata.gd
extends Resource
class_name ItemData

# the unique identifier for this
# use snake_case, all lowercase, for
@export var item_id: String = ""

# the name of the item
@export var display_name: String = "New Item"

# the texture to use as
@export var icon: Texture2D = null

# the description of the item
# (either directly in inventory or
@export_multiline var description: String = "It's an item."

# can this item be stacked
# for most classic point-and-click adventure
@export var is_stackable: bool = false

# if is_stackable is true, what's
# (not highly relevant if is_stackable is usually false).
@export var max_stack_size: int = 1

# (optional) a list of verb_ids
# this is more for filtering
# logic is usually defined on
# example: a key might primarily
# @export var compatible_verb_ids: array[string] = []

# you can add more game-specific
# @export var is_quest_item: bool = false
# @export var value: int = 0 # if you had currency
# ////////// @export var sfx_on_pickup: audiostream = null
# ------------------(@export var sfx_on_use: audiostream = null)

# no functions are strictly needed
# its purpose is to define

func _init(id: String = "", name: String = "", tex: Texture2D = null, desc: String = ""):
	# optional constructor for creating instances
	if id != "": item_id = id
	if name != "": display_name = name
	if tex != null: icon = tex
	if desc != "": description = desc
