extends EditorInspectorPlugin
class_name QodotEditorButton

func _can_handle(object):
	if object is TrenchBroomGameConfig:
		return true
	if object is QodotFGDFile:
		return true
	if object is QodotProjectConfig:
		return true
	return false

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if object is QodotFGDFile or object is TrenchBroomGameConfig:
		if name == "export_file":
			create_button("name","Click to export",name)
			return true
	elif object is QodotProjectConfig:
		if name == "export_qodot_settings":
			create_button("name","Click to export settings",name)
			return true
	return false

func create_button(name:StringName,text:StringName,property:StringName):
	var b = ButtonTrigger.new()
	b.text = text
	b.property = property
	add_property_editor(name,b)

class ButtonTrigger:
	extends EditorProperty
	var button = Button.new()
	var text = "Trigger Export"
	var property = "ERROR"
	func _ready():
		add_child(button)
		add_focusable(button)
		button.text = text
		button.pressed.connect(trigger)
	func trigger():
		emit_changed(property,true,"",true)


