# res://interactions/actions/callmethodaction.gd
class_name CallMethodAction
extends Action

# a path to the node you want to call a function on.
@export var target_node_path: NodePath

# the name of the function to call on the target node.
@export var method_name: String = ""

# an array of arguments (optional)
@export var arguments: Array


func execute(interactable_node: Interactable) -> bool:
	if target_node_path.is_empty() or method_name.is_empty():
		push_warning("CallMethodAction on '%s' is not configured correctly." % interactable_node.object_display_name)
		return true

	# get the target node. the
	# running this action. this is flexible and powerful.
	var target_node = interactable_node.get_node_or_null(target_node_path)

	if not is_instance_valid(target_node):
		push_warning("CallMethodAction on '%s' could not find the target node at path: %s" % [interactable_node.object_display_name, target_node_path])
		return true

	if not target_node.has_method(method_name):
		push_warning("CallMethodAction: Target node '%s' does not have method '%s'." % [target_node.name, method_name])
		return true

	# call the method on the
	# callv is used to call
	target_node.callv(method_name, arguments)
	print_rich("[color=cyan]CallMethodAction: Called method '%s' on node '%s'[/color]" % [method_name, target_node.name])
	return true
