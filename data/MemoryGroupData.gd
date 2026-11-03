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

# step 2.308: the game flag that opens this location. while it is false the row shows "?" for its name,
# a dark "?" tile for its picture, and every chapter in it as locked. empty = always open.
@export var unlock_flag: String = ""

# step 2.429: the row isn't added to the memory box until at least one of its chapters is shown AND unlocked
# (a hidden or padlocked chapter doesn't count). for a location whose only chapters may never exist on a save.
@export var hidden_until_a_chapter_opens: bool = false

# an array that holds all
@export var chapters: Array[MemoryChapterData] = []
