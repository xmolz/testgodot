# memorychapterdata.gd
class_name MemoryChapterData
extends Resource

# the name of the chapter displayed on the button.
@export var chapter_name: String = "Chapter Title"

# the image displayed on the button.
@export var chapter_image: Texture2D

# the scene that will be
@export var scene_path_to_load: String = ""

# the gamemanager flag that must
# if empty, the chapter is unlocked by default.
@export var unlock_flag: String = ""

# if true, selecting this chapter
# instead of loading scene_path_to_load.
@export var triggers_dev_cta: bool = false
