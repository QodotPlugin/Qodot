@tool
class_name QodotFGDPointClass
extends QodotFGDClass

func _init():
	prefix = "@PointClass"

# The scene file to associate with this PointClass
# On building the map, this scene will be instanced into the scene tree
@export_group ("Scene")
@export var scene_file: PackedScene

# The script file to associate with this PointClass
# On building the map, this will be attached to any brush entities created
# via this classname if no scene_file is specified
@export_group ("Scripting")
@export var script_class: Script

@export_group("Build")
## Entity will use `angles`, `mangle`, or `angle` to determine rotations on QodotMap build, prioritizing the key value pairs in that order.
@export var apply_rotation_on_map_build := true
