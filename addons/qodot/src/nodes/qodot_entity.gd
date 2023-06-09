class_name QodotEntity extends QodotNode3D

## Base class for entities created by Qodot
##
## This is an abstract base class. In order to create a QodotEntity-derived node, derived classes should be assigned to a [member QodotFGDPointClass.script_class] or [member QodotFGDSolidClass.script_class], so they can be instanced during the building of a [QodotMap] node.
## Derived classes should override [method update_properties].
##
## @tutorial: https://qodotplugin.github.io/docs/entities/scripting-entities

## Properties for this entity. Populated from Trenchbroom's entity property editor when building a [QodotMap].
@export var properties: Dictionary:
	get:
		return properties  # TODO Converter40 Non existent get function
	set(new_properties):
		if properties != new_properties:
			properties = new_properties
			update_properties()


## Handle updates to [member properties]
func update_properties() -> void:
	pass
