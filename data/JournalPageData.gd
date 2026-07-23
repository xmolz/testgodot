extends Resource
class_name JournalPageData

# 0 = first left, 1 = first right, 2 = second left, etc.
@export var page_index: int = 0

# drag your transparent png from csp here!
@export var page_texture: Texture2D

# leave blank to always show.
@export var required_flag: String = ""
