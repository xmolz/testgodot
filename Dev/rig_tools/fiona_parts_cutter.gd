@tool
extends EditorScript
## step 2.401: cuts Fiona's layered exports into rig parts. open this file in the script editor and run it
## (File > Run, or Ctrl+Shift+X), then check the Output panel. it's the same cutter as Layla's
## (rig_parts_cutter.gd) with Fiona's folders. her rig, back to front:
##   body   poses drawn without a head
##   head	   heads with their expression drawn in, mouth shut
##   mouth  the open mouth for each head angle, which goes on while she talks ("closed" draws nothing)
##   arm    an arm drawn over her head, for poses that need one ("no_arm" draws nothing)
## the source folder needs an empty file named .gdignore so Godot never imports the exports. after a
## change, re-export the layers into it and run this again.

const SOURCE_DIR := "res://characters/fiona/source"
const OUT_DIR := "res://characters/fiona/parts"
## which variant each slot shows when a parts list doesn't name it
const DEFAULTS := {"body": "hand_on_hip", "head": "neutral", "mouth": "closed", "arm": "no_arm"}
const BASE_SLOT := "body"
## slots that may draw nothing: slot -> the name of that "nothing" variant
const OPTIONAL_SLOTS := {"mouth": "closed", "arm": "no_arm"}

const RigCutterCore = preload("res://Dev/rig_tools/rig_cutter_core.gd")


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var report: Dictionary = RigCutterCore.run(SOURCE_DIR, OUT_DIR, DEFAULTS, BASE_SLOT, 8, 32, 24, OPTIONAL_SLOTS, {}, 12)
	for line in report["lines"]:
		print("[fiona cutter] ", line)
	print("[fiona cutter] %s in %.1fs" % ["done" if report["ok"] else "FAILED", (Time.get_ticks_msec() - t0) / 1000.0])
	if report["ok"]:
		EditorInterface.get_resource_filesystem().scan()
