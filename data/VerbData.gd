# verbdata.gd
extends Resource
class_name VerbData

# the unique internal identifier for
@export var verb_id: String = ""

# the text displayed on the
@export var display_text: String = ""

# optional: an icon for the verb button
# @export var icon: texture2d = null

# is this verb available by
@export var unlocked_by_default: bool = true

# does this verb typically require
# (e.g., "examine" might sometimes be
@export var requires_target_object: bool = true

# **************[add this line]
# the dialogue file to use
@export var fallback_dialogue_file: DialogueResource
# ////////////////////// end of addition
# i can add properties here later!
