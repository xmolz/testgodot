# res://autoload/DebugVRAM.gd
class_name DebugVRAM
extends RefCounted

# plain print() on purpose: rich-text tags do not survive a copy/paste out of the output
# panel, and the whole point of this log is being pasted somewhere else.
static var _log: PackedStringArray = []
static var _last_mb: float = -1.0
static var _peak_mb: float = 0.0

static func snapshot(tag: String) -> void:
	if not OS.is_debug_build():
		return
	var bytes = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var mb = float(bytes) / (1024.0 * 1024.0)
	_peak_mb = maxf(_peak_mb, mb)
	var line: String
	if _last_mb < 0.0:
		line = "[VRAM] %-42s %7.1f MB" % [tag, mb]
	else:
		line = "[VRAM] %-42s %7.1f MB  (%+.1f)" % [tag, mb, mb - _last_mb]
	_last_mb = mb
	_log.append(line)
	print(line)

# one paste-friendly block with the whole session history. the launch and return pipelines
# call this at their ends; it is safe to call from anywhere.
static func report() -> void:
	if not OS.is_debug_build():
		return
	print("[VRAM] ======== session report (peak %.1f MB) ========" % _peak_mb)
	for line in _log:
		print(line)
	print("[VRAM] ======== end report ========")
