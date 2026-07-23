# explanation_data.gd
extends Resource

class_name ExplanationData

# the node we want the spotlight to focus on.
@export var target_node_path: NodePath

# the lines of text that will be displayed one by one.
@export var explanation_lines: PackedStringArray

# you can still add more
# @export var title: string
@export var exceptions_to_hide: Array[NodePath]
