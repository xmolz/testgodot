# laylacharacter.gd — template in-world companion. placeholder rectangle for now; real
# art later replaces the Sprite texture and adds an AnimationPlayer without touching the
# follow logic, which lives entirely in the CompanionFollow child.
# presentation only lives here: the body's velocity is owned by CompanionFollow.
extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite
@onready var follow: CompanionFollow = $CompanionFollow
@onready var interaction_area: Interactable = $InteractionArea if has_node("InteractionArea") else null

func _ready() -> void:
	# record which side the player is standing on the moment an interaction fires.
	# interaction_started is emitted at the top of attempt_interaction — after the
	# walk-to completes, before StartConversationAction runs — so the flag is always
	# fresh when the conversation overlay's dialogue reads it. fires for every verb
	# (examine included); the recompute is harmless.
	if is_instance_valid(interaction_area):
		interaction_area.interaction_started.connect(_on_interaction_started)

func _on_interaction_started() -> void:
	if GameManager and is_instance_valid(GameManager.player_node):
		Flags.set_level_flag("layla_player_on_left", GameManager.player_node.global_position.x < global_position.x)

func _process(_delta: float) -> void:
	if not is_instance_valid(sprite):
		return

	# face where we walk; face the target while standing still. invisible on a solid
	# rectangle, but it exercises the flip plumbing the save system records (flip_h on
	# the node named "Sprite"), and real art inherits it for free.
	if absf(velocity.x) > 10.0:
		sprite.flip_h = velocity.x < 0.0
	elif is_instance_valid(follow):
		var t: Node2D = follow.get_target()
		if t:
			sprite.flip_h = t.global_position.x < global_position.x
