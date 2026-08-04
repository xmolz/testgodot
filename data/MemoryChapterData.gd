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
# the drawer falls back to thumbnail_path.
@export_file("*.png", "*.jpg", "*.webp") var detail_image_path: String = ""

# optional content tags shown below the description in the detail
# drawer (e.g. adult-content descriptors). empty = no tag row shown.
@export var content_tags: Array[String] = []

# if true, the detail drawer shows an "OPTIONAL" tag beside the chapter name.
@export var is_optional: bool = false

# title inside dialogue/chapter_launch.dialogue played over the portal swirl
# while the chapter loads. empty = no monologue (minimum hold still applies).
@export var launch_dialogue_title: String = ""

# optional conversation overlay scene (an AdvancedConversationOverlay variant)
# played over the level right after the portal, before control is handed to the
# player. loaded on demand. empty = straight into the level.
@export_file("*.tscn") var intro_overlay_path: String = ""

# optional pannable wake-CG layer scene (a WakeCGLayer), spawned under the intro overlay so
# the overlay's eyelid can blink open onto it. only used by the in-place (empty scene path)
# launch for now. empty = no wake CG.
@export_file("*.tscn") var wake_cg_scene_path: String = ""
