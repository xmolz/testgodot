# memorygroupdata.gd
class_name MemoryGroupData
extends Resource

# defines whether this group belongs
enum MemoryCategory { STORY, SPICY }

# the name of the group (e.g., "university", "faye").
@export var group_name: String = "Location Name"

# the image for the location/group.
@export var group_image: Texture2D

# the category this group will be displayed under.
@export var category: MemoryCategory = MemoryCategory.STORY

# an array that holds all
@export var chapters: Array[MemoryChapterData] = []
