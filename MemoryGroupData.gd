# MemoryGroupData.gd
class_name MemoryGroupData
extends Resource

## Defines whether this group belongs in the "Story" or "Spicy" tab.
enum MemoryCategory { STORY, SPICY }

## The name of the group (e.g., "University", "Faye").
@export var group_name: String = "Location Name"

## The image for the location/group.
@export var group_image: Texture2D

## The category this group will be displayed under.
@export var category: MemoryCategory = MemoryCategory.STORY

## An array that holds all the chapter data resources for this group.
@export var chapters: Array[MemoryChapterData] = []
