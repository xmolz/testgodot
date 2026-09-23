# LockerZoom.gd — zoom overlay for locker interiors (Fiona's first).
# Same contract as MedicineCabinetZoom.gd minus the Aida-caught logic: the base
# ObjectZoomOverlay enters ZOOM_VIEW with the tree paused, which freezes any
# dialogue balloon opened from inside the view. Unpause (deferred, after the
# base _ready has finished) exactly as the medicine cabinet does.
class_name LockerZoom
extends ObjectZoomOverlay


func _ready() -> void:
	super._ready()
	get_tree().set_deferred("paused", false)
