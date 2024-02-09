@tool
class_name QodotMap
extends QodotNode3D

## Builds Godot scenes from .map files
##
## A QodotMap node lets you define the source file for a map, as well as specify
## the definitions for entities, textures, and materials that appear in the map.
## To use this node, select an instance of the node in the Godot editor and
## select "Quick Build", "Full Build", or "Unwrap UV2" from the toolbar.
## Alternatively, call [method manual_build] from code.
##
## @tutorial: https://qodotplugin.github.io/docs/beginner's-guide-to-qodot/

## Force reinitialization of Qodot on map build
const DEBUG := false
## How long to wait between child/owner batches
const YIELD_DURATION := 0.0

## Emitted when the build process successfully completes
signal build_complete()
## Emitted when the build process finishes a step. [code]progress[/code] is from 0.0-1.0
signal build_progress(step, progress)
## Emitted when the build process fails
signal build_failed()

## Emitted when UV2 unwrapping is completed
signal unwrap_uv2_complete()

@export_category("Map")
## Trenchbroom Map file to build a scene from
@export_global_file("*.map") var map_file := ""
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
@export var texture_file_extensions := PackedStringArray(["png", "jpg", "jpeg", "bmp"])
## Optional. List of worldspawn layers.
## A worldspawn layer converts any brush of a certain texture to a certain kind of node. See example 1-2.
@export var worldspawn_layers: Array[QodotWorldspawnLayer]
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
@export_category("Build")
## If true, print profiling data before and after each build step
@export var print_profiling_data := false
## If true, Qodot will build a hierarchy from Trenchbroom groups, each group being a node. Otherwise, Qodot nodes will ignore Trenchbroom groups and have a flat structure.
@export var use_trenchbroom_group_hierarchy := false
## If true, stop the whole editor until build is complete
@export var block_until_complete := false
## How many nodes to set the owner of, or add children of, at once. Higher values may lead to quicker build times, but a less responsive editor.
@export var set_owner_batch_size := 1000

# Build context variables
var qodot = null

var profile_timestamps := {}

var add_child_array := []
var set_owner_array := []

var should_add_children := true
var should_set_owners := true

var texture_list := []
var texture_loader = null
var texture_dict := {}
var texture_size_dict := {}
var material_dict := {}
var entity_definitions := {}
var entity_dicts := []
var worldspawn_layer_dicts := []
var entity_mesh_dict := {}
var worldspawn_layer_mesh_dict := {}
var entity_nodes := []
var worldspawn_layer_nodes := []
var entity_mesh_instances := {}
var entity_occluder_instances := {}
var worldspawn_layer_mesh_instances := {}
var entity_collision_shapes := []
var worldspawn_layer_collision_shapes := []

# Overrides
func _ready() -> void:
	if not DEBUG:
		return
	
	if not Engine.is_editor_hint():
		if verify_parameters():
			build_map()

# Utility
## Verify that Qodot is functioning and that [member map_file] exists. If so, build the map. If not, signal [signal build_failed]
func verify_and_build():
	if verify_parameters():
		build_map()
	else:
		emit_signal("build_failed")

## Build the map.
func manual_build():
	should_add_children = false
	should_set_owners = false
	verify_and_build()

## Return true if parameters are valid; Qodot should be functioning and [member map_file] should exist.
func verify_parameters():
	if not qodot or DEBUG:
		qodot = load("res://addons/qodot/src/core/qodot.gd").new()
	
	if not qodot:
		push_error("Error: Failed to load qodot.")
		return false
	
	if map_file == "":
		push_error("Error: Map file not set")
		return false
	
	if not FileAccess.file_exists(map_file):
		push_error("Error: No such file %s" % map_file)
		return false
	
	return true

## Reset member variables that affect the current build
func reset_build_context():
	add_child_array = []
	set_owner_array = []
	
	texture_list = []
	texture_loader = null
	texture_dict = {}
	texture_size_dict = {}
	material_dict = {}
	entity_definitions = {}
	entity_dicts = []
	worldspawn_layer_dicts = []
	entity_mesh_dict = {}
	worldspawn_layer_mesh_dict = {}
	entity_nodes = []
	worldspawn_layer_nodes = []
	entity_mesh_instances = {}
	entity_occluder_instances = {}
	worldspawn_layer_mesh_instances = {}
	entity_collision_shapes = []
	worldspawn_layer_collision_shapes = []
	
	build_step_index = 0
	build_step_count = 0
	
	if qodot:
		qodot = load("res://addons/qodot/src/core/qodot.gd").new()
		
## Record the start time of a build step for profiling
func start_profile(item_name: String) -> void:
	if print_profiling_data:
		print(item_name)
		profile_timestamps[item_name] = Time.get_unix_time_from_system()

## Finish profiling for a build step; print associated timing data
func stop_profile(item_name: String) -> void:
	if print_profiling_data:
		if item_name in profile_timestamps:
			var delta: float = Time.get_unix_time_from_system() - profile_timestamps[item_name]
			print("Done in %s sec.\n" % snapped(delta, 0.01))
			profile_timestamps.erase(item_name)

## Run a build step. [code]step_name[/code] is the method corresponding to the step, [code]params[/code] are parameters to pass to the step, and [code]func_name[/code] does nothing.
func run_build_step(step_name: String, params: Array = [], func_name: String = ""):
	start_profile(step_name)
	if func_name == "":
		func_name = step_name
	var result = callv(step_name, params)
	stop_profile(step_name)
	return result

## Add [code]node[/code] as a child of parent, or as a child of [code]below[/code] if non-null. Also queue for ownership assignment.
func add_child_editor(parent, node, below = null) -> void:
	var prev_parent = node.get_parent()
	if prev_parent:
		prev_parent.remove_child(node)
	
	if below:
		below.add_sibling(node)
	else:
		parent.add_child(node)
	
	set_owner_array.append(node)

## Set the owner of [code]node[/code] to the current scene.
func set_owner_editor(node):
	var tree := get_tree()
	
	if not tree:
		return
	
	var edited_scene_root := tree.get_edited_scene_root()
	
	if not edited_scene_root:
		return
	
	node.set_owner(edited_scene_root)

var build_step_index := 0
var build_step_count := 0
var build_steps := []
var post_attach_steps := []

## Register a build step.
## [code]build_step[/code] is a string that corresponds to a method on this class, [code]arguments[/code] a list of arguments to pass to this method, and [code]target[/code] is a property on this class to save the return value of the build step in. If [code]post_attach[/code] is true, the step will be run after the scene hierarchy is completed.
func register_build_step(build_step: String, arguments := [], target := "", post_attach := false) -> void:
	(post_attach_steps if post_attach else build_steps).append([build_step, arguments, target])
	build_step_count += 1

## Run all build steps. Emits [signal build_progress] after each step.
## If [code]post_attach[/code] is true, run post-attach steps instead and signal [signal build_complete] when finished.
func run_build_steps(post_attach := false) -> void:
	var target_array = post_attach_steps if post_attach else build_steps
	
	while target_array.size() > 0:
		var build_step = target_array.pop_front()
		emit_signal("build_progress", build_step[0], float(build_step_index + 1) / float(build_step_count))
		
		var scene_tree := get_tree()
		if scene_tree and not block_until_complete:
			await get_tree().create_timer(YIELD_DURATION).timeout
		
		var result = run_build_step(build_step[0], build_step[1])
		var target = build_step[2]
		if target != "":
			set(target, result)
			
		build_step_index += 1
		
		if scene_tree and not block_until_complete:
			await get_tree().create_timer(YIELD_DURATION).timeout

	if post_attach:
		_build_complete()
	else:
		start_profile('add_children')
		add_children()

## Register all steps for the build. See [method register_build_step] and [method run_build_steps]
func register_build_steps() -> void:
	register_build_step('remove_children')
	register_build_step('load_map')
	register_build_step('fetch_texture_list', [], 'texture_list')
	register_build_step('init_texture_loader', [], 'texture_loader')
	register_build_step('load_textures', [], 'texture_dict')
	register_build_step('build_texture_size_dict', [], 'texture_size_dict')
	register_build_step('build_materials', [], 'material_dict')
	register_build_step('fetch_entity_definitions', [], 'entity_definitions')
	register_build_step('set_qodot_entity_definitions', [])
	register_build_step('set_qodot_worldspawn_layers', [])
	register_build_step('generate_geometry', [])
	register_build_step('fetch_entity_dicts', [], 'entity_dicts')
	register_build_step('fetch_worldspawn_layer_dicts', [], 'worldspawn_layer_dicts')
	register_build_step('build_entity_nodes', [], 'entity_nodes')
	register_build_step('build_worldspawn_layer_nodes', [], 'worldspawn_layer_nodes')
	register_build_step('resolve_group_hierarchy', [])
	register_build_step('build_entity_mesh_dict', [], 'entity_mesh_dict')
	register_build_step('build_worldspawn_layer_mesh_dict', [], 'worldspawn_layer_mesh_dict')
	register_build_step('build_entity_mesh_instances', [], 'entity_mesh_instances')
	register_build_step('build_entity_occluder_instances', [], 'entity_occluder_instances')
	register_build_step('build_worldspawn_layer_mesh_instances', [], 'worldspawn_layer_mesh_instances')
	register_build_step('build_entity_collision_shape_nodes', [], 'entity_collision_shapes')
	register_build_step('build_worldspawn_layer_collision_shape_nodes', [], 'worldspawn_layer_collision_shapes')

## Register all post-attach steps for the build. See [method register_build_step] and [method run_build_steps]
func register_post_attach_steps() -> void:
	register_build_step('build_entity_collision_shapes', [], "", true)
	register_build_step('build_worldspawn_layer_collision_shapes', [], "", true)
	register_build_step('apply_entity_meshes', [], "", true)
	register_build_step('apply_entity_occluders', [], "", true)
	register_build_step('apply_worldspawn_layer_meshes', [], "", true)
	register_build_step('apply_properties', [], "", true)
	register_build_step('connect_signals', [], "", true)
	register_build_step('remove_transient_nodes', [], "", true)

# Actions
## Build the map
func build_map() -> void:
	reset_build_context()
	
	print('Building %s\n' % map_file)
	start_profile('build_map')
	
	register_build_steps()
	register_post_attach_steps()
	
	run_build_steps()

## Recursively unwrap UV2s for [code]node[/code] and its children, in preparation for baked lighting.
func unwrap_uv2(node: Node = null) -> void:
	var target_node = null
	
	if node:
		target_node = node
	else:
		target_node = self
		print("Unwrapping mesh UV2s")
	
	if target_node is MeshInstance3D:
		var mesh = target_node.get_mesh()
		if mesh is ArrayMesh:
			mesh.lightmap_unwrap(Transform3D.IDENTITY, uv_unwrap_texel_size / inverse_scale_factor)
	
	for child in target_node.get_children():
		unwrap_uv2(child)
	
	if not node:
		print("Unwrap complete")
		emit_signal("unwrap_uv2_complete")

# Build Steps
## Recursively remove and delete all children of this node
func remove_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

## Parse and load [member map_file]
func load_map() -> void:
	var file: String = map_file
	qodot.load_map(file)

## Get textures found in [member map_file]
func fetch_texture_list() -> Array:
	return qodot.get_texture_list() as Array

## Initialize texture loader, allowing textures in [member base_texture_dir] and [member texture_wads] to be turned into materials
func init_texture_loader() -> QodotTextureLoader:
	var tex_ldr := QodotTextureLoader.new(
		base_texture_dir,
		texture_file_extensions,
		texture_wads
	)
	tex_ldr.unshaded = unshaded
	return tex_ldr

## Build a dictionary from Trenchbroom texture names to their corresponding Texture2D resources in Godot
func load_textures() -> Dictionary:
	return texture_loader.load_textures(texture_list) as Dictionary

## Build a dictionary from Trenchbroom texture names to Godot materials
func build_materials() -> Dictionary:
	return texture_loader.create_materials(texture_list, material_file_extension, default_material, default_material_albedo_uniform)

## Collect entity definitions from [member entity_fgd], as a dictionary from Trenchbroom classnames to entity definitions
func fetch_entity_definitions() -> Dictionary:
	return entity_fgd.get_entity_definitions()

## Hand the Qodot C# core the entity definitions
func set_qodot_entity_definitions() -> void:
	qodot.set_entity_definitions(build_libmap_entity_definitions(entity_definitions))

## Hand the Qodot C# core the worldspawn layer definitions. See [member worldspawn_layers]
func set_qodot_worldspawn_layers() -> void:
	qodot.set_worldspawn_layers(build_libmap_worldspawn_layers(worldspawn_layers))

## Generate geometry from map file
func generate_geometry() -> void:
	qodot.generate_geometry(texture_size_dict);

## Get a list of dictionaries representing each entity from the Qodot C# core
func fetch_entity_dicts() -> Array:
	return qodot.get_entity_dicts()

## Get a list of dictionaries representing each worldspawn layer from the Qodot C# core
func fetch_worldspawn_layer_dicts() -> Array:
	var layer_dicts = qodot.get_worldspawn_layer_dicts()
	return layer_dicts if layer_dicts else []

## Build a dictionary from Trenchbroom textures to the sizes of their corresponding Godot textures
func build_texture_size_dict() -> Dictionary:
	var texture_size_dict := {}
	
	for tex_key in texture_dict:
		var texture := texture_dict[tex_key] as Texture2D
		if texture:
			texture_size_dict[tex_key] = texture.get_size()
		else:
			texture_size_dict[tex_key] = Vector2.ONE
	
	return texture_size_dict

## Marshall Qodot FGD definitions for transfer to libmap
func build_libmap_entity_definitions(entity_definitions: Dictionary) -> Dictionary:
	var libmap_entity_definitions = {}
	for classname in entity_definitions:
		libmap_entity_definitions[classname] = {}
		if entity_definitions[classname] is QodotFGDSolidClass:
			libmap_entity_definitions[classname]['spawn_type'] = entity_definitions[classname].spawn_type
	return libmap_entity_definitions

## Marshall worldspawn layer definitions for transfer to libmap
func build_libmap_worldspawn_layers(worldspawn_layers: Array) -> Array:
	var libmap_worldspawn_layers := []
	for worldspawn_layer in worldspawn_layers:
		libmap_worldspawn_layers.append({
			'name': worldspawn_layer.name,
			'texture': worldspawn_layer.texture,
			'node_class': worldspawn_layer.node_class,
			'build_visuals': worldspawn_layer.build_visuals,
			'collision_shape_type': worldspawn_layer.collision_shape_type,
			'script_class': worldspawn_layer.script_class
		})
	return libmap_worldspawn_layers

## Build nodes from the entities in [member entity_dicts]
func build_entity_nodes() -> Array:
	var entity_nodes := []

	for entity_idx in range(0, entity_dicts.size()):
		var entity_dict := entity_dicts[entity_idx] as Dictionary
		var properties := entity_dict['properties'] as Dictionary
		
		var node = QodotEntity.new()
		var node_name = "entity_%s" % entity_idx
		
		var should_add_child = should_add_children
		
		if 'classname' in properties:
			var classname = properties['classname']
			node_name += "_" + classname
			if classname in entity_definitions:
				var entity_definition := entity_definitions[classname] as QodotFGDClass
				if entity_definition is QodotFGDSolidClass:
					if entity_definition.spawn_type == QodotFGDSolidClass.SpawnType.MERGE_WORLDSPAWN:
						entity_nodes.append(null)
						continue
					elif use_trenchbroom_group_hierarchy and entity_definition.spawn_type == QodotFGDSolidClass.SpawnType.GROUP:
						should_add_child = false
					if entity_definition.node_class != "":
						node.queue_free()
						node = ClassDB.instantiate(entity_definition.node_class)
				elif entity_definition is QodotFGDPointClass:
					if entity_definition.scene_file:
						var flag = PackedScene.GEN_EDIT_STATE_DISABLED
						if Engine.is_editor_hint():
							flag = PackedScene.GEN_EDIT_STATE_INSTANCE
						node.queue_free()
						node = entity_definition.scene_file.instantiate(flag)
					elif entity_definition.node_class != "":
						node.queue_free()
						node = ClassDB.instantiate(entity_definition.node_class)
					if 'rotation_degrees' in node and entity_definition.apply_rotation_on_map_build:
						var angles := Vector3.ZERO
						if 'angles' in properties or 'mangle' in properties:
							var key := 'angles' if 'angles' in properties else 'mangle'
							var angles_raw = properties[key]
							if not angles_raw is Vector3:
								angles_raw = angles_raw.split_floats(' ')
							if angles_raw.size() > 2:
								angles = Vector3(-angles_raw[0], angles_raw[1], -angles_raw[2])
								if key == 'mangle':
									if entity_definition.classname.begins_with('light'):
										angles = Vector3(angles_raw[1], angles_raw[0], -angles_raw[2])
									elif entity_definition.classname == 'info_intermission':
										angles = Vector3(angles_raw[0], angles_raw[1], -angles_raw[2])
							else:
								push_error("Invalid vector format for \'" + key + "\' in entity \'" + classname + "\'")
						elif 'angle' in properties:
							var angle = properties['angle']
							if not angle is float:
								angle = float(angle)
							angles.y += angle
						angles.y += 180
						node.rotation_degrees = angles
				if entity_definition.script_class:
					node.set_script(entity_definition.script_class)
		
		node.name = node_name
		
		if 'origin' in properties:
			var origin_vec = Vector3.ZERO
			var origin_comps = properties['origin'].split_floats(' ')
			if origin_comps.size() > 2:
				origin_vec = Vector3(origin_comps[1], origin_comps[2], origin_comps[0])
			else:
				push_error("Invalid vector format for \'origin\' in " + node.name)
			if "position" in node:
				if node.position is Vector3:
					node.position = origin_vec / inverse_scale_factor
				elif node.position is Vector2:
					node.position = Vector2(origin_vec.z, -origin_vec.y)
		else:
			if entity_idx != 0 and "position" in node:
				if node.position is Vector3:
					node.position = entity_dict['center'] / inverse_scale_factor
		
		entity_nodes.append(node)
		
		if should_add_child:
			queue_add_child(self, node)
	
	return entity_nodes

## Build nodes from the worldspawn layers in [member worldspawn_layers]
func build_worldspawn_layer_nodes() -> Array:
	var worldspawn_layer_nodes := []
	
	for worldspawn_layer in worldspawn_layers:
		var node = ClassDB.instantiate(worldspawn_layer.node_class)
		node.name = "entity_0_" + worldspawn_layer.name
		if worldspawn_layer.script_class:
			node.set_script(worldspawn_layer.script_class)
		
		worldspawn_layer_nodes.append(node)
		queue_add_child(self, node, entity_nodes[0])
	
	return worldspawn_layer_nodes

## Resolve entity group hierarchy, turning Trenchbroom groups into nodes and queueing their contents to be added to said nodes as children
func resolve_group_hierarchy() -> void:
	if not use_trenchbroom_group_hierarchy:
		return
	
	var parent_entities := {}
	var child_entities := {}
	
	# Gather all entities which are children in some group or parents in some group
	for node_idx in range(0, entity_nodes.size()):
		var node = entity_nodes[node_idx]
		var properties = entity_dicts[node_idx]['properties']
		
		if not properties: continue
		
		if not ('_tb_id' in properties or '_tb_group' in properties or '_tb_layer' in properties):
			continue
		
		if not 'classname' in properties: continue
		var classname = properties['classname']
		
		if not classname in entity_definitions: continue
		var entity_definition = entity_definitions[classname]

		# identify children
		if '_tb_group' in properties or '_tb_layer' in properties: 
			child_entities[node_idx] = node

		# identify parents
		if '_tb_id' in properties:
			if properties['_tb_name'] != "Unnamed":
				if properties['_tb_type'] == "_tb_group":
					node.name = "group_" + str(properties['_tb_id'])
				elif properties['_tb_type'] == "_tb_layer":
					node.name = "layer_" + str(properties['_tb_layer_sort_index'])
				node.name = node.name + "_" + properties['_tb_name']
			parent_entities[node_idx] = node
	
	var child_to_parent_map := {}
	
	#For each child,...
	for node_idx in child_entities:
		var node = child_entities[node_idx]
		var properties = entity_dicts[node_idx]['properties']
		var tb_group = null
		if '_tb_group' in properties:
			tb_group = properties['_tb_group']
		elif '_tb_layer' in properties:
			tb_group = properties['_tb_layer']
		if tb_group == null: continue

		var parent = null
		var parent_properties = null
		var parent_entity = null
		var parent_idx = null
		
		#...identify its direct parent out of the parent_entities array
		for possible_parent in parent_entities:
			parent_entity = parent_entities[possible_parent]
			parent_properties = entity_dicts[possible_parent]['properties']
			
			if parent_properties['_tb_id'] == tb_group:
				parent = parent_entity
				parent_idx = possible_parent
				break
		#if there's a match, pass it on to the child-parent relationship map
		if parent:
			child_to_parent_map[node_idx] = parent_idx 
	
	for child_idx in child_to_parent_map:
		var child = entity_nodes[child_idx]
		var parent_idx = child_to_parent_map[child_idx]
		var parent = entity_nodes[parent_idx]
		
		queue_add_child(parent, child, null, true)

## Return the node associated with a Trenchbroom index. Unused.
func get_node_by_tb_id(target_id: String, entity_nodes: Dictionary):
	for node_idx in entity_nodes:
		var node = entity_nodes[node_idx]
		
		if not node:
			continue
		
		if not 'properties' in node:
			continue
		
		var properties = node['properties']
		
		if not '_tb_id' in properties:
			continue
		
		var parent_id = properties['_tb_id']
		if parent_id == target_id:
			return node
		
	return null

## Build [CollisionShape3D] nodes for brush entities
func build_entity_collision_shape_nodes() -> Array:
	var entity_collision_shapes_arr := []
	
	for entity_idx in range(0, entity_nodes.size()):
		var entity_collision_shapes := []
		
		var entity_dict = entity_dicts[entity_idx]
		var properties = entity_dict['properties']
		
		var node := entity_nodes[entity_idx] as Node
		var concave = false
		
		if 'classname' in properties:
			var classname = properties['classname']
			if classname in entity_definitions:
				var entity_definition := entity_definitions[classname] as QodotFGDSolidClass
				if entity_definition:
					if entity_definition.collision_shape_type == QodotFGDSolidClass.CollisionShapeType.NONE:
						entity_collision_shapes_arr.append(null)
						continue
					elif entity_definition.collision_shape_type == QodotFGDSolidClass.CollisionShapeType.CONCAVE:
						concave = true
					
					if entity_definition.spawn_type == QodotFGDSolidClass.SpawnType.MERGE_WORLDSPAWN:
						# TODO: Find the worldspawn object instead of assuming index 0
						node = entity_nodes[0] as Node
					
					if node and node is CollisionObject3D:
						(node as CollisionObject3D).collision_layer = entity_definition.collision_layer
						(node as CollisionObject3D).collision_mask = entity_definition.collision_mask
						(node as CollisionObject3D).collision_priority = entity_definition.collision_priority
		
		# don't create collision shapes that wont be attached to a CollisionObject3D as they are a waste
		if not node or (not node is CollisionObject3D):
			entity_collision_shapes_arr.append(null)
			continue
		
		if concave:
			var collision_shape := CollisionShape3D.new()
			collision_shape.name = "entity_%s_collision_shape" % entity_idx
			entity_collision_shapes.append(collision_shape)
			queue_add_child(node, collision_shape)
		else:
			for brush_idx in entity_dict['brush_indices']:
				var collision_shape := CollisionShape3D.new()
				collision_shape.name = "entity_%s_brush_%s_collision_shape" % [entity_idx, brush_idx]
				entity_collision_shapes.append(collision_shape)
				queue_add_child(node, collision_shape)
		entity_collision_shapes_arr.append(entity_collision_shapes)
	
	return entity_collision_shapes_arr

## Build CollisionShape3D nodes for worldspawn layers
func build_worldspawn_layer_collision_shape_nodes() -> Array:
	var worldspawn_layer_collision_shapes := []
	
	for layer_idx in range(0, worldspawn_layers.size()):
		if layer_idx >= worldspawn_layer_dicts.size():
			continue
		
		var layer = worldspawn_layers[layer_idx]
		
		var layer_dict = worldspawn_layer_dicts[layer_idx]
		var node := worldspawn_layer_nodes[layer_idx] as Node
		var concave = false
		
		var shapes := []
		
		if layer.collision_shape_type == QodotFGDSolidClass.CollisionShapeType.NONE:
			worldspawn_layer_collision_shapes.append(shapes)
			continue
		elif layer.collision_shape_type == QodotFGDSolidClass.CollisionShapeType.CONCAVE:
			concave = true
		
		if not node:
			worldspawn_layer_collision_shapes.append(shapes)
			continue
		
		if concave:
			var collision_shape := CollisionShape3D.new()
			collision_shape.name = "entity_0_%s_collision_shape" % layer.name
			shapes.append(collision_shape)
			queue_add_child(node, collision_shape)
		else:
			for brush_idx in layer_dict['brush_indices']:
				var collision_shape := CollisionShape3D.new()
				collision_shape.name = "entity_0_%s_brush_%s_collision_shape" % [layer.name, brush_idx]
				shapes.append(collision_shape)
				queue_add_child(node, collision_shape)
		
		worldspawn_layer_collision_shapes.append(shapes)
	
	return worldspawn_layer_collision_shapes

## Build the concrete [Shape3D] resources for each brush
func build_entity_collision_shapes() -> void:
	for entity_idx in range(0, entity_dicts.size()):
		var entity_dict := entity_dicts[entity_idx] as Dictionary
		var properties = entity_dict['properties']
		var entity_position: Vector3 = Vector3.ZERO
		if entity_nodes[entity_idx] != null and entity_nodes[entity_idx].get("position"):
			if entity_nodes[entity_idx].position is Vector3:
				entity_position = entity_nodes[entity_idx].position
		var entity_collision_shape = entity_collision_shapes[entity_idx]
		
		if entity_collision_shape == null:
			continue
		
		var concave: bool = false
		var shape_margin: float = 0.04
		
		if 'classname' in properties:
			var classname = properties['classname']
			if classname in entity_definitions:
				var entity_definition = entity_definitions[classname] as QodotFGDSolidClass
				if entity_definition:
					match(entity_definition.collision_shape_type):
						QodotFGDSolidClass.CollisionShapeType.NONE:
							continue
						QodotFGDSolidClass.CollisionShapeType.CONVEX:
							concave = false
						QodotFGDSolidClass.CollisionShapeType.CONCAVE:
							concave = true
					shape_margin = entity_definition.collision_shape_margin
		
		if entity_collision_shapes[entity_idx] == null:
			continue
		
		if concave:
			qodot.gather_entity_concave_collision_surfaces(entity_idx, face_skip_texture)
		else:
			qodot.gather_entity_convex_collision_surfaces(entity_idx)
		
		var entity_surfaces := qodot.fetch_surfaces(inverse_scale_factor) as Array
		
		var entity_verts := PackedVector3Array()
		
		for surface_idx in range(0, entity_surfaces.size()):
			var surface_verts = entity_surfaces[surface_idx]
			
			if surface_verts == null:
				continue
			
			if concave:
				var vertices := surface_verts[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var indices := surface_verts[Mesh.ARRAY_INDEX] as PackedInt32Array
				for vert_idx in indices:
					entity_verts.append(vertices[vert_idx])
			else:
				var shape_points = PackedVector3Array()
				for vertex in surface_verts[Mesh.ARRAY_VERTEX]:
					if not vertex in shape_points:
						shape_points.append(vertex)
				
				var shape = ConvexPolygonShape3D.new()
				shape.set_points(shape_points)
				shape.margin = shape_margin
				
				var collision_shape = entity_collision_shape[surface_idx]
				collision_shape.set_shape(shape)
				
		if concave:
			if entity_verts.size() == 0:
				continue
			
			var shape = ConcavePolygonShape3D.new()
			shape.set_faces(entity_verts)
			shape.margin = shape_margin
			
			var collision_shape = entity_collision_shapes[entity_idx][0]
			collision_shape.set_shape(shape)

## Build the concrete [Shape3D] resources for each worldspawn layer
func build_worldspawn_layer_collision_shapes() -> void:
	for layer_idx in range(0, worldspawn_layers.size()):
		if layer_idx >= worldspawn_layer_dicts.size():
			continue
		
		var layer = worldspawn_layers[layer_idx]
		var concave = false
		
		match(layer.collision_shape_type):
			QodotFGDSolidClass.CollisionShapeType.NONE:
				continue
			QodotFGDSolidClass.CollisionShapeType.CONVEX:
				concave = false
			QodotFGDSolidClass.CollisionShapeType.CONCAVE:
				concave = true
		
		var layer_dict = worldspawn_layer_dicts[layer_idx]
		
		if not worldspawn_layer_collision_shapes[layer_idx]:
			continue
		
		qodot.gather_worldspawn_layer_collision_surfaces(0)
		
		var layer_surfaces := qodot.fetch_surfaces(inverse_scale_factor) as Array
		
		var verts := PackedVector3Array()
		
		for i in range(0, layer_dict.brush_indices.size()):
			var surface_idx = layer_dict.brush_indices[i]
			var surface_verts = layer_surfaces[surface_idx]
			
			if not surface_verts:
				continue
			
			if concave:
				var vertices := surface_verts[0] as PackedVector3Array
				var indices := surface_verts[8] as PackedInt32Array
				for vert_idx in indices:
					verts.append(vertices[vert_idx])
			else:
				var shape_points = PackedVector3Array()
				for vertex in surface_verts[0]:
					if not vertex in shape_points:
						shape_points.append(vertex)
				
				var shape = ConvexPolygonShape3D.new()
				shape.set_points(shape_points)
				
				var collision_shape = worldspawn_layer_collision_shapes[layer_idx][i]
				collision_shape.set_shape(shape)
		
		if concave:
			if verts.size() == 0:
				continue
			
			var shape = ConcavePolygonShape3D.new()
			shape.set_faces(verts)
			
			var collision_shape = worldspawn_layer_collision_shapes[layer_idx][0]
			collision_shape.set_shape(shape)

## Build Dictionary from entity indices to [ArrayMesh] instances
func build_entity_mesh_dict() -> Dictionary:
	var meshes := {}
	
	var texture_surf_map: Dictionary
	for texture in texture_dict:
		texture_surf_map[texture] = Array()
	
	var gather_task = func(i):
		var texture = texture_dict.keys()[i]
		texture_surf_map[texture] = qodot.gather_texture_surfaces_mt(texture, brush_clip_texture, face_skip_texture, inverse_scale_factor)
	
	var task_id:= WorkerThreadPool.add_group_task(gather_task, texture_dict.keys().size(), 4, true)
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	
	for texture in texture_dict:
		var texture_surfaces := texture_surf_map[texture] as Array
		
		for entity_idx in range(0, texture_surfaces.size()):
			var entity_dict := entity_dicts[entity_idx] as Dictionary
			var properties = entity_dict['properties']
			
			var entity_surface = texture_surfaces[entity_idx]
			
			if 'classname' in properties:
				var classname = properties['classname']
				if classname in entity_definitions:
					var entity_definition = entity_definitions[classname] as QodotFGDSolidClass
					if entity_definition:
						if entity_definition.spawn_type == QodotFGDSolidClass.SpawnType.MERGE_WORLDSPAWN:
							entity_surface = null
							
						if not entity_definition.build_visuals and not entity_definition.build_occlusion:
							entity_surface = null
						
			if entity_surface == null:
				continue
			
			if not entity_idx in meshes:
				meshes[entity_idx] = ArrayMesh.new()
			
			var mesh: ArrayMesh = meshes[entity_idx]
			mesh.add_surface_from_arrays(ArrayMesh.PRIMITIVE_TRIANGLES, entity_surface)
			mesh.surface_set_name(mesh.get_surface_count() - 1, texture)
			mesh.surface_set_material(mesh.get_surface_count() - 1, material_dict[texture])
	
	return meshes

## Build Dictionary from worldspawn layers (via textures) to [ArrayMesh] instances
func build_worldspawn_layer_mesh_dict() -> Dictionary:
	var meshes := {}
	
	for layer in worldspawn_layer_dicts:
		var texture = layer.texture
		qodot.gather_worldspawn_layer_surfaces(texture, brush_clip_texture, face_skip_texture)
		var texture_surfaces := qodot.fetch_surfaces(inverse_scale_factor) as Array
		
		var mesh: Mesh = null
		if not texture in meshes:
			meshes[texture] = ArrayMesh.new()
		
		mesh = meshes[texture]
		mesh.add_surface_from_arrays(ArrayMesh.PRIMITIVE_TRIANGLES, texture_surfaces[0])
		mesh.surface_set_name(mesh.get_surface_count() - 1, texture)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material_dict[texture])
	
	return meshes

## Build [MeshInstance3D]s from brush entities and add them to the add child queue
func build_entity_mesh_instances() -> Dictionary:
	var entity_mesh_instances := {}
	for entity_idx in entity_mesh_dict:
		var use_in_baked_light = false
		var shadow_casting_setting := GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		var render_layers: int = 1
		
		var entity_dict := entity_dicts[entity_idx] as Dictionary
		var properties = entity_dict['properties']
		var classname = properties['classname']
		if classname in entity_definitions:
			var entity_definition = entity_definitions[classname] as QodotFGDSolidClass
			if entity_definition:
				if not entity_definition.build_visuals:
					continue
				
				if entity_definition.use_in_baked_light:
					use_in_baked_light = true
				elif '_shadow' in properties:
					if properties['_shadow'] == "1":
						use_in_baked_light = true
				shadow_casting_setting = entity_definition.shadow_casting_setting
				render_layers = entity_definition.render_layers
		
		if not entity_mesh_dict[entity_idx]:
			continue
		
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = 'entity_%s_mesh_instance' % entity_idx
		mesh_instance.gi_mode = MeshInstance3D.GI_MODE_STATIC if use_in_baked_light else GeometryInstance3D.GI_MODE_DISABLED
		mesh_instance.cast_shadow = shadow_casting_setting
		mesh_instance.layers = render_layers
		
		queue_add_child(entity_nodes[entity_idx], mesh_instance)
		
		entity_mesh_instances[entity_idx] = mesh_instance
	
	return entity_mesh_instances

func build_entity_occluder_instances() -> Dictionary:
	var entity_occluder_instances := {}
	for entity_idx in entity_mesh_dict:
		var entity_dict := entity_dicts[entity_idx] as Dictionary
		var properties = entity_dict['properties']
		var classname = properties['classname']
		if classname in entity_definitions:
			var entity_definition = entity_definitions[classname] as QodotFGDSolidClass
			if entity_definition:
				if entity_definition.build_occlusion:
					if not entity_mesh_dict[entity_idx]:
						continue
					
					var occluder_instance := OccluderInstance3D.new()
					occluder_instance.name = 'entity_%s_occluder_instance' % entity_idx
					
					queue_add_child(entity_nodes[entity_idx], occluder_instance)
					entity_occluder_instances[entity_idx] = occluder_instance
	
	return entity_occluder_instances

## Build Dictionary from worldspawn layers (via textures) to [MeshInstance3D]s
func build_worldspawn_layer_mesh_instances() -> Dictionary:
	var worldspawn_layer_mesh_instances := {}
	var idx = 0
	for i in range(0, worldspawn_layers.size()):
		var worldspawn_layer = worldspawn_layers[i]
		var texture_name = worldspawn_layer.texture
		
		if not texture_name in worldspawn_layer_mesh_dict:
			continue
		
		var mesh := worldspawn_layer_mesh_dict[texture_name] as Mesh
		
		if not mesh:
			continue
		
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = 'entity_0_%s_mesh_instance' % worldspawn_layer.name
		mesh_instance.gi_mode = MeshInstance3D.GI_MODE_STATIC
		
		queue_add_child(worldspawn_layer_nodes[idx], mesh_instance)
		idx += 1
		
		worldspawn_layer_mesh_instances[texture_name] = mesh_instance
	
	return worldspawn_layer_mesh_instances

## Assign [ArrayMesh]es to their [MeshInstance3D] counterparts
func apply_entity_meshes() -> void:
	for entity_idx in entity_mesh_instances:
		var mesh := entity_mesh_dict[entity_idx] as Mesh
		var mesh_instance := entity_mesh_instances[entity_idx] as MeshInstance3D
		if not mesh or not mesh_instance:
			continue
		
		mesh_instance.set_mesh(mesh)
		queue_add_child(entity_nodes[entity_idx], mesh_instance)

func apply_entity_occluders() -> void:
	for entity_idx in entity_mesh_dict:
		var mesh := entity_mesh_dict[entity_idx] as Mesh
		var occluder_instance : OccluderInstance3D
		
		if entity_idx in entity_occluder_instances:
			occluder_instance = entity_occluder_instances[entity_idx]
		
		if not mesh or not occluder_instance:
			continue
		
		var verts: PackedVector3Array
		var indices: PackedInt32Array
		for surf_idx in range(mesh.get_surface_count()):
			var vert_count := verts.size()
			var surf_array := mesh.surface_get_arrays(surf_idx)
			verts.append_array(surf_array[Mesh.ARRAY_VERTEX])
			indices.resize(indices.size() + surf_array[Mesh.ARRAY_INDEX].size())
			for new_index in surf_array[Mesh.ARRAY_INDEX]:
				indices.append(new_index + vert_count)
		
		var occluder := ArrayOccluder3D.new()
		occluder.set_arrays(verts, indices)
		
		occluder_instance.occluder = occluder
		
## Assign [ArrayMesh]es to their [MeshInstance3D] counterparts for worldspawn layers
func apply_worldspawn_layer_meshes() -> void:
	for texture_name in worldspawn_layer_mesh_dict:
		var mesh = worldspawn_layer_mesh_dict[texture_name]
		var mesh_instance = worldspawn_layer_mesh_instances[texture_name]
		
		if not mesh or not mesh_instance:
			continue
		
		mesh_instance.set_mesh(mesh)

## Add a child and its new parent to the add child queue. If [code]below[/code] is a node, add it as a child to that instead. If [code]relative[/code] is true, set the location of node relative to parent.
func queue_add_child(parent, node, below = null, relative = false) -> void:
	add_child_array.append({"parent": parent, "node": node, "below": below, "relative": relative})

## Assign children to parents based on the contents of the add child queue (see [method queue_add_child])
func add_children() -> void:
	while true:
		for i in range(0, set_owner_batch_size):
			var data = add_child_array.pop_front()
			if data:
				add_child_editor(data['parent'], data['node'], data['below'])
				if data['relative']:
					data['node'].global_transform.origin -= data['parent'].global_transform.origin
			else:
				add_children_complete()
				return
		
		var scene_tree := get_tree()
		if scene_tree and not block_until_complete:
			await get_tree().create_timer(YIELD_DURATION).timeout

## Set owners and start post-attach build steps
func add_children_complete():
	stop_profile('add_children')
	
	if should_set_owners:
		start_profile('set_owners')
		set_owners()
	else:
		run_build_steps(true)

## Set owner of nodes generated by Qodot to scene root based on [member set_owner_array]
func set_owners():
	while true:
		for i in range(0, set_owner_batch_size):
			var node = set_owner_array.pop_front()
			if node:
				set_owner_editor(node)
			else:
				set_owners_complete()
				return
				
		var scene_tree := get_tree()
		if scene_tree and not block_until_complete:
			await get_tree().create_timer(YIELD_DURATION).timeout

## Finish profiling for set_owners and start post-attach build steps
func set_owners_complete():
	stop_profile('set_owners')
	run_build_steps(true)

## Apply Trenchbroom properties to [QodotEntity] instances, transferring Trenchbroom dictionaries to [QodotEntity.properties]
func apply_properties() -> void:
	for entity_idx in range(0, entity_nodes.size()):
		var entity_node = entity_nodes[entity_idx]
		if not entity_node:
			continue
		
		var entity_dict := entity_dicts[entity_idx] as Dictionary
		var properties := entity_dict['properties'] as Dictionary
		
		if 'classname' in properties:
			var classname = properties['classname']
			if classname in entity_definitions:
				var entity_definition := entity_definitions[classname] as QodotFGDClass
				
				for property in properties:
					var prop_string = properties[property]
					if property in entity_definition.class_properties:
						var prop_default = entity_definition.class_properties[property]
						if prop_default is int:
							properties[property] = prop_string.to_int()
						elif prop_default is float:
							properties[property] = prop_string.to_float()
						elif prop_default is Vector3:
							var prop_comps = prop_string.split_floats(" ")
							if prop_comps.size() > 2:
								properties[property] = Vector3(prop_comps[0], prop_comps[1], prop_comps[2])
							else:
								push_error("Invalid vector format for \'" + property + "\' in entity \'" + classname + "\': " + prop_string)
								properties[property] = prop_default
						elif prop_default is Color:
							var prop_color = prop_default
							var prop_comps = prop_string.split(" ")
							if prop_comps.size() > 2:
								if "." in prop_comps[0] or "." in prop_comps[1] or "." in prop_comps[2]:
									prop_color.r = prop_comps[0].to_float()
									prop_color.g = prop_comps[1].to_float()
									prop_color.b = prop_comps[2].to_float()
								else:
									prop_color.r8 = prop_comps[0].to_int()
									prop_color.g8 = prop_comps[1].to_int()
									prop_color.b8 = prop_comps[2].to_int()
							else:
								push_error("Invalid color format for \'" + property + "\' in entity \'" + classname + "\': " + prop_string)
								
							properties[property] = prop_color
						elif prop_default is Dictionary:
							properties[property] = prop_string.to_int()
						elif prop_default is Array:
							properties[property] = prop_string.to_int()
				
				# Assign properties not defined with defaults from the entity definition
				for property in entity_definitions[classname].class_properties:
					if not property in properties:
						var prop_default = entity_definition.class_properties[property]
						# Flags
						if prop_default is Array:
							var prop_flags_sum := 0
							for prop_flag in prop_default:
								if prop_flag is Array and prop_flag.size() > 2:
									if prop_flag[2] and prop_flag[1] is int:
										prop_flags_sum += prop_flag[1]
							properties[property] = prop_flags_sum
						# Choices
						elif prop_default is Dictionary:
							var prop_desc = entity_definition.class_property_descriptions[property]
							if prop_desc is Array and prop_desc.size() > 1 and prop_desc[1] is int:
								properties[property] = prop_desc[1]
							else:
								properties[property] = 0
						# Everything else
						else:
							properties[property] = prop_default
						
		if 'properties' in entity_node:
			entity_node.properties = properties

## Wire signals based on Trenchbroom [code]target[/code] and [code]targetname[/code] properties
func connect_signals() -> void:
	for entity_idx in range(0, entity_nodes.size()):
		var entity_node = entity_nodes[entity_idx]
		if not entity_node:
			continue
		
		var entity_dict := entity_dicts[entity_idx] as Dictionary
		var entity_properties := entity_dict['properties'] as Dictionary
		
		if not 'target' in entity_properties:
			continue
		
		var target_nodes := get_nodes_by_targetname(entity_properties['target'])
		for target_node in target_nodes:
			connect_signal(entity_node, target_node)

## Connect a signal on [code]entity_node[/code] to [code]target_node[/code], possibly mediated by the contents of a [code]signal[/code] or [code]receiver[/code] entity
func connect_signal(entity_node: Node, target_node: Node) -> void:
	if target_node.properties['classname'] == 'signal':
		var signal_name = target_node.properties['signal_name']
		
		var receiver_nodes := get_nodes_by_targetname(target_node.properties['target'])
		for receiver_node in receiver_nodes:
			if receiver_node.properties['classname'] != 'receiver':
				continue
			
			var receiver_name = receiver_node.properties['receiver_name']
			
			var target_nodes := get_nodes_by_targetname(receiver_node.properties['target'])
			for node in target_nodes:
				entity_node.connect(signal_name,Callable(node,receiver_name),CONNECT_PERSIST)
	else:
		var signal_list = entity_node.get_signal_list()
		for signal_dict in signal_list:
			if signal_dict['name'] == 'trigger':
				entity_node.connect("trigger",Callable(target_node,"use"),CONNECT_PERSIST)
				break

## Remove nodes marked transient. See [member QodotFGDClass.transient_node]
func remove_transient_nodes() -> void:
	for entity_idx in range(0, entity_nodes.size()):
		var entity_node = entity_nodes[entity_idx]
		if not entity_node:
			continue
		
		var entity_dict := entity_dicts[entity_idx] as Dictionary
		var entity_properties := entity_dict['properties'] as Dictionary
		
		if not 'classname' in entity_properties:
			continue
		
		var classname = entity_properties['classname']
		
		if not classname in entity_definitions:
			continue
		
		var entity_definition = entity_definitions[classname]
		if entity_definition.transient_node:
			entity_node.get_parent().remove_child(entity_node)
			entity_node.queue_free()

## Find all nodes with matching targetname property
func get_nodes_by_targetname(targetname: String) -> Array:
	var nodes := []
	
	for node_idx in range(0, entity_nodes.size()):
		var node = entity_nodes[node_idx]
		if not node:
			continue
		
		var entity_dict := entity_dicts[node_idx] as Dictionary
		var entity_properties := entity_dict['properties'] as Dictionary
		
		if not 'targetname' in entity_properties:
			continue
		
		if entity_properties['targetname'] == targetname:
			nodes.append(node)
	
	return nodes

# Cleanup after build is finished (internal)
func _build_complete():
	reset_build_context()
	
	stop_profile('build_map')
	if not print_profiling_data:
		print('\n')
	print('Build complete\n')
	
	emit_signal("build_complete")
