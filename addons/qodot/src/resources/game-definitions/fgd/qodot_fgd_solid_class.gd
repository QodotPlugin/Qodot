@tool
class_name QodotFGDSolidClass
extends QodotFGDClass

enum SpawnType {
	WORLDSPAWN = 0, ## Is worldspawn
	MERGE_WORLDSPAWN = 1, ## Should be combined with worldspawn
	ENTITY = 2, ## Is its own separate entity
	GROUP = 3 ## Is a group
}

enum CollisionShapeType {
	NONE, ## Should have no collision shape
	CONVEX, ## Should have a convex collision shape
	CONCAVE ## Should have a concave collision shape
}

@export var spawn : String = QodotUtil.CATEGORY_STRING
## Controls whether a given SolidClass is the worldspawn, is combined with the worldspawn, or is spawned as its own free-standing entity
@export var spawn_type: SpawnType = SpawnType.ENTITY

@export var visual_build: String = QodotUtil.CATEGORY_STRING
## Controls whether a visual mesh is built for this SolidClass
@export var build_visuals := true

@export var collision_build : String = QodotUtil.CATEGORY_STRING
## Controls how collisions are built for this SolidClass
@export var collision_shape_type: CollisionShapeType = CollisionShapeType.CONVEX

@export var scripting: String = QodotUtil.CATEGORY_STRING
## The script file to associate with this SolidClass
## On building the map, this will be attached to any brush entities created via this classname
@export var script_class: Script

func _init():
	prefix = "@SolidClass"
