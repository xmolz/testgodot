extends Resource
class_name JournalPageData

## 0 = First Left, 1 = First Right, 2 = Second Left, etc.
@export var page_index: int = 0

## Drag your transparent PNG from CSP here!
@export var page_texture: Texture2D

## Leave blank to always show. Type a flag name to hide until unlocked.
@export var required_flag: String = ""
