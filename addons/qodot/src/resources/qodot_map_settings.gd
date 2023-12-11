class_name QodotMapSettings
extends Resource

@export_category("Map")
## Ratio between Trenchbroom units in the .map file and Godot units.
## An inverse scale factor of 16 would cause 16 Trenchbroom units to correspond to 1 Godot unit. See [url=https://qodotplugin.github.io/docs/geometry.html#scale]Scale[/url] in the Qodot documentation.
@export var inverse_scale_factor := 16.0
@export_category("Entities")
## [QodotFGDFile] for the map.
## This resource will translate between Trenchbroom classnames and Godot scripts/scenes. See [url=https://qodotplugin.github.io/docs/entities/]Entities[/url] in the Qodot manual.
@export var entity_fgd: QodotFGDFile = load("res://addons/qodot/game_definitions/fgd/qodot_fgd.tres")
@export_category("Textures")
## Base directory for textures. When building materials, Qodot will search this directory for texture files matching the textures assigned to Trenchbroom faces.
@export_dir var base_texture_dir := "res://textures"
## File extensions to search for texture data.
@export var texture_file_extensions : PackedStringArray = ["png", "jpg", "jpeg", "bmp"]
## Optional. Path for the clip texture, relative to [member base_texture_dir].
## Brushes textured with the clip texture will be turned into invisible but solid volumes.
@export var brush_clip_texture := "special/clip"
## Optional. Path for the skip texture, relative to [member base_texture_dir].
## Faces textured with the skip texture will not be rendered.
@export var face_skip_texture := "special/skip"
## Optional. WAD files to pull textures from.
## Quake engine games are distributed with .WAD files, which are packed texture libraries. Qodot can import these files as [QuakeWadFile]s.
@export var texture_wads: Array[QuakeWadFile]
@export_category("Materials")
## File extensions to search for Material definitions
@export var material_file_extension := "tres"
## If true, all materials will be unshaded, i.e. will ignore light. Also known as "fullbright".
@export var unshaded := false
## Material used as template when generating missing materials.
@export var default_material : Material = StandardMaterial3D.new()
## Default albedo texture (used when [member default_material] is a [ShaderMaterial])
@export var default_material_albedo_uniform := ""
@export_category("UV Unwrap")
## Texel size for UV2 unwrapping.
## A texel size of 1 will lead to a 1:1 correspondence between texture texels and lightmap texels. Larger values will produce less detailed lightmaps. To conserve memory and filesize, use the largest value that still looks good.
@export var uv_unwrap_texel_size := 1.0
