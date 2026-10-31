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

# step 2.308: the game flag set when the player finishes this chapter. a chapter whose unlock_flag is this
# same flag unlocks then (and glows as new in the memory box until its description is opened).
# empty = finishing this chapter unlocks nothing.
@export var completion_flag: String = ""

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

# step 2.316: when the drawer has to crop the detail image to fit the text, which part to keep:
# 0 = the top, 0.5 = the middle, 1 = the bottom.
@export_range(0.0, 1.0, 0.05) var detail_image_focus: float = 0.5

# step 2.312: adult content the player can't avoid, shown as the "Content" row of tags in the detail drawer
# (F95-style names, e.g. "Exhibitionism"). empty = the row shows a single muted "None".
@export var content_tags: Array[String] = []

# step 2.312: adult content the player can choose to avoid, shown as the "Skippable" row. empty = row hidden.
@export var skippable_tags: Array[String] = []

# step 2.312: insurance form fields this chapter gives the whole answer to (e.g. "First name"), shown as the
# "Insurance form" row. empty (and no partial clues) = row hidden.
@export var form_clues: Array[String] = []

# step 2.312: insurance form fields this chapter only gives part of (half a phone number, a date the player
# has to work out), shown in the same row marked "(partial)".
@export var partial_form_clues: Array[String] = []

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

# step 2.418: game flags a REPLAY of this chapter starts without, by prefix: "kb_" clears every kb_* flag,
# "counter_layla_closeness" clears that one counter. the canon run's values come back untouched when the
# replay ends (ChapterLaunchSequence.end_replay). empty = a replay keeps every flag as it finds it.
@export var replay_reset_prefixes: Array[String] = []
