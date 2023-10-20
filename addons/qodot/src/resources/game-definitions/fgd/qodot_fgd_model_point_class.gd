@tool
class_name QodotFGDModelPointClass
extends QodotFGDPointClass

## Optional - if empty, will use the game dir provided when exported.
@export_global_dir var trenchbroom_game_dir = ""
## Display model export folder. Optional - if empty, will use the settings from the project config
@export var trenchbroom_models_folder := ""
## Scale expression applied to model in Trenchbroom. See https://trenchbroom.github.io/manual/latest/#display-models-for-entities for more info.
@export var scale_expression := ""
@export var generate_bounding_box := true
@export var apply_rotation_on_import := true
@export var generate_gd_ignore_file := false
func build_def_text() -> String:
	_generate_model()
	return super()

func _generate_model():
	if not scene_file:
		return 
	
	var gltf_state := GLTFState.new()
	var path = _get_export_dir()
	var node = _get_node()
	if node == null: return
	if not _create_gltf_file(gltf_state, path, node, generate_gd_ignore_file):
		printerr("could not create gltf file")
		return
	node.queue_free()
	const model_key := "model"
	const size_key := "size"
	if scale_expression.is_empty():
		meta_properties[model_key] = '"%s"' % _get_local_path()
	else:
		meta_properties[model_key] = '{"path": "%s", "scale": %s }' % [
			_get_local_path(), 
			scale_expression
		]
	if generate_bounding_box:
		meta_properties[size_key] = _get_bounding_box(gltf_state.meshes)

func _get_node() -> Node3D:
	var node := scene_file.instantiate()
	if node is Node3D: return node as Node3D
	node.queue_free()
	printerr("Scene is not of type 'Node3D'")
	return null


func _get_export_dir() -> String:
	var tb_game_dir = _get_working_dir()
	var export_dir = _get_model_folder()
	return tb_game_dir.path_join(export_dir).path_join('%s.glb' % classname)

func _get_local_path() -> String:
	return _get_model_folder().path_join('%s.glb' % classname)

func _get_model_folder() -> String:
	return (QodotProjectConfig.get_setting(QodotProjectConfig.PROPERTY.TRENCHBROOM_MODELS_FOLDER) 
		if trenchbroom_models_folder.is_empty() 
		else trenchbroom_models_folder)

func _get_working_dir() -> String:
	return (QodotProjectConfig.get_setting(QodotProjectConfig.PROPERTY.TRENCHBROOM_WORKING_FOLDER)
		if trenchbroom_game_dir.is_empty()
		else trenchbroom_game_dir)

func _create_gltf_file(gltf_state: GLTFState, path: String, node: Node3D, create_ignore_files: bool) -> bool:
	var error := 0 
	var global_export_path = path
	var gltf_document := GLTFDocument.new()
	gltf_state.create_animations = false
	node.rotate_y(deg_to_rad(-90))
	gltf_document.append_from_scene(node, gltf_state)
	if error != OK:
		printerr("Failed appending to gltf document", error)
		return false

	call_deferred("_save_to_file_system", gltf_document, gltf_state, global_export_path, create_ignore_files)
	return true

func _save_to_file_system(gltf_document: GLTFDocument, gltf_state: GLTFState, path: String, create_ignore_files: bool):
	var error := 0
	error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		printerr("Failed creating dir", error)
		return 

	if create_ignore_files: _create_ignore_files(path.get_base_dir())

	error = gltf_document.write_to_filesystem(gltf_state, path)
	if error != OK:
		printerr("Failed writing to file system", error)
		return 
	print('exported model ', path)

func _create_ignore_files(path: String):
	var error := 0
	const gdIgnore = ".gdignore"
	var file = path.path_join(gdIgnore)
	if FileAccess.file_exists(file):
		return
	var fileAccess := FileAccess.open(file, FileAccess.WRITE)
	fileAccess.store_string('')
	fileAccess.close()

func _get_bounding_box(meshes: Array[GLTFMesh]) -> AABB:
	var aabb := AABB()
	for mesh in meshes:
		aabb.merge(mesh.mesh.get_mesh().get_aabb())
	return aabb