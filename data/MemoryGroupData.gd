# memorygroupdata.gd
class_name MemoryGroupData
extends Resource

# defines whether this group belongs
enum MemoryCategory { STORY, SPICY }

# the name of the group (e.g., "university", "faye").
@export var group_name: String = "Location Name"

# path to the group thumbnail. loaded lazily by LocationRow and
# released when the row leaves the tree, to keep VRAM usage low.
@export_file("*.png", "*.jpg", "*.webp") var group_thumbnail_path: String = ""

# the category this group will be displayed under.
@export var category: MemoryCategory = MemoryCategory.STORY

# an array that holds all
@export var chapters: Array[MemoryChapterData] = []
