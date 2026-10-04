# laylacharacter.gd — in-world companion. the Sprite texture is driven by the
# AnimationPlayer ("idle" / "walk"); the follow logic lives entirely in the
# CompanionFollow child.
# presentation only lives here: the body's velocity is owned by CompanionFollow.
extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite
@onready var follow: CompanionFollow = $CompanionFollow
@onready var interaction_area: Interactable = $InteractionArea if has_node("InteractionArea") else null
@onready var anim: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

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

	_update_animation(absf(velocity.x) > 10.0)

	# face where we walk; face the target while standing still. the save system
	# records flip_h on the node named "Sprite", so keep that node's name.
	if absf(velocity.x) > 10.0:
		sprite.flip_h = velocity.x < 0.0
	elif is_instance_valid(follow):
		var t: Node2D = follow.get_target()
		if t:
			sprite.flip_h = t.global_position.x < global_position.x

# walk while moving, idle otherwise. the walk cycle scales with the follow speed so
# her feet keep pace when she jogs to catch up.
func _update_animation(walking: bool) -> void:
	if not is_instance_valid(anim):
		return
	var wanted: String = "walk" if walking else "idle"
	if anim.current_animation != wanted:
		anim.play(wanted)
	if walking and is_instance_valid(follow) and follow.speed > 0.0:
		anim.speed_scale = absf(velocity.x) / follow.speed
	else:
		anim.speed_scale = 1.0
