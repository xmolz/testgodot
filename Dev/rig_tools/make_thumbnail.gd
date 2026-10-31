@tool
extends EditorScript
## step 2.413: makes a small copy of a big picture, for the memory box (e.g. the apartment's location picture
## from its living-room background). open this file in the script editor and run it (File > Run, or
## Ctrl+Shift+X); the copy is written next to the source and imported. change the three constants to make
## another one.

const SOURCE := "res://Backgrounds/Apartment/apartment_living_room.png"
const OUT := "res://Backgrounds/Apartment/apartment_thumbnail.png"
## the copy's width in pixels; its height keeps the source's shape
const WIDTH := 640


func _run() -> void:
	var err := make(SOURCE, OUT, WIDTH)
	if err == OK:
		print("[thumbnail] wrote %s (%d px wide)" % [OUT, WIDTH])
		EditorInterface.get_resource_filesystem().scan()
	else:
		print("[thumbnail] FAILED (%s) - is %s there?" % [error_string(err), SOURCE])


static func make(source: String, out: String, width: int) -> Error:
	var img := Image.load_from_file(ProjectSettings.globalize_path(source))
	if img == null or img.is_empty():
		return ERR_FILE_NOT_FOUND
	var height: int = maxi(1, roundi(float(img.get_height()) * float(width) / float(img.get_width())))
	img.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return img.save_png(ProjectSettings.globalize_path(out))
