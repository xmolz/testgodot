# memorychapterdata.gd
class_name MemoryChapterData
extends Resource

# the name of the chapter displayed on the button.
@export var chapter_name: String = "Chapter Title"

# path to the button thumbnail. loaded lazily by ChapterButton and
# released when the button leaves the tree, to keep VRAM usage low.
@export_file("*.png", "*.jpg", "*.webp") var thumbnail_path: String = ""

# the scene that will be
@export var scene_path_to_load: String = ""

# the gamemanager flag that must
# if empty, the chapter is unlocked by default.
@export var unlock_flag: String = ""

# if true, selecting this chapter
# instead of loading scene_path_to_load.
@export var triggers_dev_cta: bool = false

enum ChapterType { STORY, SPICY }

# the category of this chapter, shown as a badge in the detail drawer.
@export var chapter_type: ChapterType = ChapterType.STORY

# description shown in the detail drawer.
@export_multiline var chapter_description: String = ""

# path to a large detail image for the drawer. loaded on demand and
# freed when the drawer closes, to keep VRAM usage low. if empty,
# the drawer falls back to chapter_image.
@export_file("*.png", "*.jpg", "*.webp") var detail_image_path: String = ""

# optional content tags shown below the description in the detail
# drawer (e.g. adult-content descriptors). empty = no tag row shown.
@export var content_tags: Array[String] = []

# if true, the detail drawer shows an "OPTIONAL" tag beside the chapter name.
@export var is_optional: bool = false

# optional monologue shown over the portal swirl while the chapter loads.
# one line per newline. empty = no monologue (minimum hold still applies).
@export_multiline var launch_monologue: String = ""
