extends Resource
class_name CharacterProfile

@export var actor_id: String = ""
@export var default_scale: float = 1.0
@export var expressions: Dictionary = {}

# horizontal fraction of the canvas where the character's visual centre sits. 0.5 = centred
# canvas (every pre-2.50 sprite). measured by PIL scan (content bbox centre / canvas width).
@export var canvas_anchor_x: float = 0.5

# step 2.401: horizontal fraction of the canvas where the face sits, for close-ups (actor_focus) when the
# face isn't over the body's centre (a head turned to one side). < 0 = use canvas_anchor_x. measured per
# sprite (the centre of the eyes / canvas width).
@export var face_x_ratio: float = -1.0

# step 2.401: talking mouths, for a rig whose expressions keep the mouth shut (Fiona): head variant -> the
# mouth part added while this character speaks ("*" = any head not listed). empty = no automatic mouth.
@export var talk_mouths: Dictionary = {}
# step 2.401: the rig slot whose variant picks the mouth in talk_mouths
@export var talk_head_slot: String = "head"

# vertical fraction of the canvas where the face centre (eye line) sits. 0.2 = the legacy
# constant every pre-2.50 portrait crop was tuned for. measured per sprite (2.55 A scan + eyeball).
@export var face_y_ratio: float = 0.2
