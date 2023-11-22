class_name Qodot extends RefCounted

var map_data:= QodotMapData.new()
var map_parser:= QodotMapParser.new(map_data)
var geo_generator = preload("res://addons/qodot/src/core/qodot_geo_generator.gd").new(map_data)
var surface_gatherer:= QodotSurfaceGatherer.new(map_data)

func load_map(filename: String) -> void:
	map_parser.load(filename)

func get_texture_list() -> PackedStringArray:
	var g_textures: PackedStringArray
	var tex_count: int = map_data.textures.size()
	
	g_textures.resize(tex_count)
	for i in range(tex_count):
		g_textures.set(i, map_data.textures[i].name)
	
	return g_textures

func set_entity_definitions(entity_defs: Dictionary) -> void:
	for i in range(entity_defs.size()):
		var key: String = entity_defs.keys()[i]
		var val: int = entity_defs.values()[i].get("spawn_type", QodotMapData.EntitySpawnType.ENTITY)
		map_data.set_spawn_type_by_classname(key, val as QodotMapData.EntitySpawnType)

func set_worldspawn_layers(worldspawn_layers: Array) -> void:
	for layer in worldspawn_layers:
		var build_visuals: bool = layer.get("build_visuals", false)
		var texture: String = layer.get("texture", "NONE")
		map_data.register_worldspawn_layer(texture, build_visuals)

func generate_geometry(texture_dict: Dictionary) -> void:
	var keys: Array = texture_dict.keys()
	for key in keys:
		var val: Vector2 = texture_dict[key]
		map_data.set_texture_size(key, val.x, val.y)
	geo_generator.run()

func get_worldspawn_layer_dicts() -> Array:
	var worldspawn_ent:= map_data.entities[0] if map_data.entities.size() > 0 else null
	
	var worldspawn_layer_dicts: Array
	if worldspawn_ent == null:
		return worldspawn_layer_dicts
		
	for layer in map_data.worldspawn_layers:
		var layer_dict: Dictionary
		var tex_data:= map_data.textures[layer.texture_idx]
		if tex_data == null:
			continue
		
		layer_dict["texture"] = tex_data.name
		
		var brush_indices: PackedInt64Array
		for b in range(worldspawn_ent.brushes.size()):
			var brush:= worldspawn_ent.brushes[b]
			var is_layer_brush: bool = false
			for face in brush.faces:
				if face.texture_idx == layer.texture_idx:
					is_layer_brush = true
					break
					
			if is_layer_brush:
				brush_indices.append(b)
			
		layer_dict["brush_indices"] = brush_indices
		worldspawn_layer_dicts.append(layer_dict)
		
	return worldspawn_layer_dicts

func get_entity_dicts() -> Array:
	var ent_dicts: Array
	for entity in map_data.entities:
		var dict: Dictionary
		dict["brush_count"] = entity.brushes.size()
		
		var brush_indices: PackedInt64Array
		for b in range(entity.brushes.size()):
			var brush:= entity.brushes[b]
			var is_wsl_brush: bool = false
			for face in brush.faces:
				if map_data.find_worldspawn_layer(face.texture_idx) != -1:
					is_wsl_brush = true
					break
			if !is_wsl_brush:
				brush_indices.append(b)
		
		dict["brush_indices"] = brush_indices
		dict["center"] = Vector3(entity.center.y, entity.center.z, entity.center.x)
		dict["properties"] = entity.properties
		
		ent_dicts.append(dict)
	
	return ent_dicts

func get_worldspawn_layers() -> Array:
	return map_data.worldspawn_layers

func gather_texture_surfaces(texture_name: String, clip_filter_texture: String, skip_filter_texture: String) -> void:
	_gather_texture_surfaces_internal(texture_name, clip_filter_texture, skip_filter_texture, true)

func gather_texture_surfaces_mt(texture_name: String, clip_filter_texture: String, skip_filter_texture: String, inverse_scale_factor: float) -> Array:
	var sg:= QodotSurfaceGatherer.new(map_data)
	sg.reset_params()
	sg.split_type = QodotSurfaceGatherer.SurfaceSplitType.ENTITY
	sg.set_texture_filter(texture_name)
	sg.set_clip_filter_texture(clip_filter_texture)
	sg.set_skip_filter_texture(skip_filter_texture)
	sg.filter_worldspawn_layers = true
	sg.run()
	return _fetch_surfaces_internal(sg, inverse_scale_factor)

func gather_worldspawn_layer_surfaces(texture_name: String, clip_filter_texture: String, skip_filter_texture: String) -> void:
	_gather_texture_surfaces_internal(texture_name, clip_filter_texture, skip_filter_texture, false)

func gather_entity_convex_collision_surfaces(entity_idx: int) -> void:
	_gather_convex_collision_surfaces(entity_idx, true)
	
func gather_entity_concave_collision_surfaces(entity_idx: int, skip_filter_texture: String) -> void:
	_gather_concave_collision_surfaces(entity_idx, skip_filter_texture, true)
	
func gather_worldspawn_layer_collision_surfaces(entity_idx: int) -> void:
	_gather_convex_collision_surfaces(entity_idx, false)
	
func fetch_surfaces(inverse_scale_factor: float) -> Array:	
	return _fetch_surfaces_internal(surface_gatherer, inverse_scale_factor)

func _fetch_surfaces_internal(surf_gatherer: QodotSurfaceGatherer, inverse_scale_factor: float) -> Array:	
	var surfs:= surf_gatherer.out_surfaces
	var surf_array: Array
	
	for surf in surfs:
		if surf == null or surf.vertices.size() == 0:
			surf_array.append(null)
			continue
			
		var vertices: PackedVector3Array
		var normals: PackedVector3Array
		var tangents: PackedFloat64Array
		var uvs: PackedVector2Array
		for v in surf.vertices:
			vertices.append(Vector3(v.vertex.y, v.vertex.z, v.vertex.x) / inverse_scale_factor)
			normals.append(Vector3(v.normal.y, v.normal.z, v.normal.x))
			tangents.append(v.tangent.y)
			tangents.append(v.tangent.z)
			tangents.append(v.tangent.x)
			tangents.append(v.tangent.w)
			uvs.append(Vector2(v.uv.x, v.uv.y))
			
		var indices: PackedInt32Array
		if surf.indicies.size() > 0:
			indices.append_array(surf.indicies)
		
		var brush_array: Array
		brush_array.resize(Mesh.ARRAY_MAX)
		
		brush_array[Mesh.ARRAY_VERTEX] = vertices
		brush_array[Mesh.ARRAY_NORMAL] = normals
		brush_array[Mesh.ARRAY_TANGENT] = tangents
		brush_array[Mesh.ARRAY_TEX_UV] = uvs
		brush_array[Mesh.ARRAY_INDEX] = indices
		
		surf_array.append(brush_array)
		
	return surf_array

# internal
func _gather_texture_surfaces_internal(texture_name: String, clip_filter_texture: String, skip_filter_texture: String, filter_layers: bool) -> void:
	surface_gatherer.reset_params()
	surface_gatherer.split_type = QodotSurfaceGatherer.SurfaceSplitType.ENTITY
	surface_gatherer.set_texture_filter(texture_name)
	surface_gatherer.set_clip_filter_texture(clip_filter_texture)
	surface_gatherer.set_skip_filter_texture(skip_filter_texture)
	surface_gatherer.filter_worldspawn_layers = filter_layers
	
	surface_gatherer.run()

func _gather_convex_collision_surfaces(entity_idx: int, filter_layers: bool) -> void:
	surface_gatherer.reset_params()
	surface_gatherer.split_type = QodotSurfaceGatherer.SurfaceSplitType.BRUSH
	surface_gatherer.entity_filter_idx = entity_idx
	surface_gatherer.filter_worldspawn_layers = filter_layers
	
	surface_gatherer.run()
	
func _gather_concave_collision_surfaces(entity_idx: int, skip_filter_texture: String, filter_layers: bool) -> void:
	surface_gatherer.reset_params()
	surface_gatherer.split_type = QodotSurfaceGatherer.SurfaceSplitType.NONE
	surface_gatherer.entity_filter_idx = entity_idx
	surface_gatherer.set_skip_filter_texture(skip_filter_texture)
	surface_gatherer.filter_worldspawn_layers = filter_layers
	
	surface_gatherer.run()
