extends Resource
class_name CharacterProfile

@export var actor_id: String = ""
@export var default_scale: float = 1.0
@export var expressions: Dictionary = {}

# horizontal fraction of the canvas where the character's visual centre sits. 0.5 = centred
# canvas (every pre-2.50 sprite). measured by PIL scan (content bbox centre / canvas width).
@export var canvas_anchor_x: float = 0.5

# vertical fraction of the canvas where the face centre (eye line) sits. 0.2 = the legacy
# constant every pre-2.50 portrait crop was tuned for. measured per sprite (2.55 A scan + eyeball).
@export var face_y_ratio: float = 0.2
