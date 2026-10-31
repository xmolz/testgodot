@tool
extends EditorScript
## step 2.395: cuts Jayce's layered exports into rig parts. open this file in the script editor and run it
## (File > Run, or Ctrl+Shift+X), then check the Output panel. it's the same cutter as Layla's
## (rig_parts_cutter.gd) with Jayce's folders. his rig is one body drawn without a face, plus whole faces
## drawn on the same canvas (one per expression), so it has two slots: body and face.
## the source folder needs an empty file named .gdignore so Godot never imports the exports. after a
## change, re-export the layers into it and run this again.

const SOURCE_DIR := "res://characters/jayce/source"
const OUT_DIR := "res://characters/jayce/parts"
## which variant each slot shows when a parts list doesn't name it
const DEFAULTS := {"body": "hand_in_pocket", "face": "smirk"}
const BASE_SLOT := "body"

const RigCutterCore = preload("res://Dev/rig_tools/rig_cutter_core.gd")


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var report: Dictionary = RigCutterCore.run(SOURCE_DIR, OUT_DIR, DEFAULTS, BASE_SLOT, 8, 32, 24, {}, {}, 12)
	for line in report["lines"]:
		print("[jayce cutter] ", line)
	print("[jayce cutter] %s in %.1fs" % ["done" if report["ok"] else "FAILED", (Time.get_ticks_msec() - t0) / 1000.0])
	if report["ok"]:
		EditorInterface.get_resource_filesystem().scan()
