# MemoryChapterData.gd
class_name MemoryChapterData
extends Resource

## The name of the chapter displayed on the button.
@export var chapter_name: String = "Chapter Title"

## The image displayed on the button.
@export var chapter_image: Texture2D

## The scene that will be loaded when this chapter is selected.
@export var scene_path_to_load: String = ""

## The GameManager flag that must be 'true' for this chapter to be unlocked.
## If empty, the chapter is unlocked by default.
@export var unlock_flag: String = ""

## If true, selecting this chapter plays the dev CTA dialogue
## instead of loading scene_path_to_load.
@export var triggers_dev_cta: bool = false
