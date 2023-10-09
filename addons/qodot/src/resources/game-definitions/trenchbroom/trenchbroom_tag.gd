## Enables transparent textures in Trenchbroom and other map editors.
## Does not affect appearance or functionality in Godot.
## Uses a pattern matching system to identify brushes, faces, or brush
## entities that should contain Trenchbroom tag attributes.
class_name TrenchBroomTag
extends Resource

enum TagMatchType {
	TEXTURE, ## Tag applies to any face with a texture matching the texture name.
	CONTENT_FLAG, ## Tag applies to any brush with a content flag matching the tag pattern.
	SURFACE_FLAG, ## Tag applies to any face with a surface flag matching the tag pattern.
	SURFACE_PARAM, ## Tag applies to any face with a special surface param. See Trenchbroom Manual for more info: https://trenchbroom.github.io/manual/latest/#special_brush_face_types
	CLASSNAME ## Tag applies to any brush entity with a class name matching the tag pattern.
}

## Name to define this tag. Not used as the matching pattern.
@export var tag_name: String

## The attributes applied to matching faces or brushes. Only "_transparent" is
## supported in Trenchbroom, which makes matching faces or brushes transparent.
@export var tag_attributes : Array[String] = ["transparent"]

## Detemines how the tag is matched. See [constant TagMatchType].
@export var tag_match_type: TagMatchType

## A string that filters which flag, param, or classname to use. [code]*[/code]
## can be used as a wildcard to include multiple options.
## [b]Example:[/b] [code]trigger_*[/code] with [constant TagMatchType] [i]Classname[/i] will apply
## this tag to all brush entities with the [code]trigger_[/code] prefix.
@export var tag_pattern: String

## A string that filters which textures recieve these attributes. Only used with
## a [constant TagMatchType] of [i]Texture[/i].
@export var texture_name: String
