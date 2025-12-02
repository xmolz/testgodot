# res://interactions/actions/SayLineAction.gd
class_name SayLineAction
extends Action

## The line of dialogue for the character to say.
@export var line_to_say: String = "..."


# Override the base execute method with specific logic for this action.
func execute(interactable_node: Interactable) -> bool:
	# We have access to the interactable that is running this action.
	# We can use it to emit its `display_dialogue` signal, which the
	# GameManager is already set up to listen for.
	interactable_node.display_dialogue.emit(line_to_say)
	return true
