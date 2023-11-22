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

@export_group("Spawn")
## Controls whether a given SolidClass is the worldspawn, is combined with the worldspawn, or is spawned as its own free-standing entity
@export var spawn_type: SpawnType = SpawnType.ENTITY

@export_group("Visual Build")
## Controls whether a visual mesh is built for this SolidClass
@export var build_visuals := true
## Automatically unwrap the UV2 for lightmapping on build
@export var use_in_baked_light := true
## Shadow casting setting allows for further lightmapping customization
@export var shadow_casting_setting := GeometryInstance3D.SHADOW_CASTING_SETTING_ON
## Automatically build OccluderInstance3D for this entity
@export var build_occlusion := false
## This entity will only be visible for Camera3Ds whose cull mask includes any of the render layers this VisualInstance3D is set to
@export_flags_3d_render var render_layers: int = 1

@export_group("Collision Build")
## Controls how collisions are built for this SolidClass
@export var collision_shape_type: CollisionShapeType = CollisionShapeType.CONVEX
## The physics layers this SolidClass is in.
@export_flags_3d_physics var collision_layer: int = 1
## The physics layers this SolidClass scans.
@export_flags_3d_physics var collision_mask: int = 1
## The priority used to solve colliding when occurring penetration. The higher the priority is, the lower the penetration into the SolidClass will be. This can for example be used to prevent the player from breaking through the boundaries of a level.
@export var collision_priority: float = 1.0
## The collision margin for the SolidClass' collision shapes. Not used in Godot Physics. See Shape3D docs for details.
@export var collision_shape_margin: float = 0.04

@export_group("Scripting")
## The script file to associate with this SolidClass
## On building the map, this will be attached to any brush entities created via this classname
@export var script_class: Script

func _init():
	prefix = "@SolidClass"
