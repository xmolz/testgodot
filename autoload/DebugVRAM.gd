# res://autoload/DebugVRAM.gd
class_name DebugVRAM
extends RefCounted

static func snapshot(tag: String) -> void:
	if OS.is_debug_build():
		var bytes = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
		var mb = float(bytes) / (1024.0 * 1024.0)
		print_rich("[color=yellow][VRAM SNAPSHOT] %s: %.1f MB[/color]" % [tag, mb])
