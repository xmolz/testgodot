# res://interactions/actions/saylineaction.gd
class_name SayLineAction
extends Action

# the line of dialogue for the character to say.
@export var line_to_say: String = "..."


# override the base execute method
func execute(interactable_node: Interactable) -> bool:
	# we have access to the
	# we can use it to
	# gamemanager is already set up to listen for.
	interactable_node.display_dialogue.emit(line_to_say)
	return true
