@tool
extends EditorScript
## step 2.359: run this in the script editor (File > Run, or Ctrl+Shift+X) to cut a character's layered
## exports into rig parts. set the four values below, run, then check the Output panel.
## the source folder needs an empty file named .gdignore so Godot never imports the exports;
## once the parts look right in Dev/rig_tools/rig_viewer.tscn, the exports can be deleted
## (re-export from the drawing file whenever something changes, and run this again).

const SOURCE_DIR := "res://characters/layla/source"
const OUT_DIR := "res://characters/layla/parts"
## which variant each slot shows when a parts list doesn't name it
const DEFAULTS := {"body": "hand_on_waist", "eyes": "regular", "mouth": "smile", "brows": "base", "flush": "no_flush", "blush": "no_blush", "tears": "no_tears"}
const BASE_SLOT := "body"
## step 2.363: slots that can show nothing - each gets an extra variant with this name that draws nothing
const OPTIONAL_SLOTS := {"flush": "no_flush", "blush": "no_blush", "tears": "no_tears"}
## step 2.363: spots to erase by hand - source file -> [x, y] points on the 1100x1740 canvas; the little
## cluster under each point is erased (never anything bigger than 400 pixels)
const ERASE_AT := {
	"1_layla_body@hand_on_chest.png": [[869, 1167], [304, 1226]],
	"1_layla_body@hand_up.png": [[869, 1167]],
	"2_layla_eyes@sad.png": [[617, 539], [607, 540]],
}

const RigCutterCore = preload("res://Dev/rig_tools/rig_cutter_core.gd")


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var report: Dictionary = RigCutterCore.run(SOURCE_DIR, OUT_DIR, DEFAULTS, BASE_SLOT, 8, 32, 24, OPTIONAL_SLOTS, ERASE_AT, 12)
	for line in report["lines"]:
		print("[rig cutter] ", line)
	print("[rig cutter] %s in %.1fs" % ["done" if report["ok"] else "FAILED", (Time.get_ticks_msec() - t0) / 1000.0])
	if report["ok"]:
		EditorInterface.get_resource_filesystem().scan()
