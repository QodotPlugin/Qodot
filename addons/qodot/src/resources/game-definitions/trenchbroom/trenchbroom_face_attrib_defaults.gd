@tool
class_name TrenchBroomFaceAttribDefaults extends Resource

@export var texture_name: String
@export var offset: Vector2
@export var scale: Vector2 = Vector2.ONE
@export var rotation: float
@export var surface_contents: PackedStringArray
@export var surface_flags: PackedStringArray
@export var surface_value: float
@export var color: Color

func _to_string() -> String:
	var export_object: Dictionary
	export_object["textureName"] = texture_name
	export_object["offset"] = [offset.x, offset.y]
	export_object["scale"] = [scale.x, scale.y]
	export_object["rotation"] = rotation
	if !surface_contents.is_empty():
		export_object["surfaceContents"] = surface_contents
	if !surface_flags.is_empty():
		export_object["surfaceFlags"] = surface_flags
	export_object["surfaceValue"] = surface_value
	export_object["color"] = "%f %f %f %f" % [color.r, color.g, color.b, color.a]

	return JSON.stringify(export_object, "\t")
