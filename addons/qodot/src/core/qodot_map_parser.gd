class_name QodotMapParser extends RefCounted

var scope: ParseScope = ParseScope.FILE
var comment: bool = false
var entity_idx: int = -1
var brush_idx: int = -1
var face_idx: int = -1
var component_idx: int = 0
var prop_key: String = ""
var current_property: String = ""
var valve_uvs: bool = false

var current_face: Face
var current_brush: Brush
var current_entity: Entity

var map_data: MapData

func _init(in_map_data: MapData) -> void:
	map_data = in_map_data

func load(map_file: String) -> bool:
	current_face = Face.new()
	current_brush = Brush.new()
	current_entity = Entity.new()
	
	scope = ParseScope.FILE
	comment = false
	entity_idx = -1
	brush_idx = -1
	face_idx = -1
	component_idx = 0
	valve_uvs = false
	
	var map: FileAccess = FileAccess.open(map_file, FileAccess.READ)
	if map == null:
		printerr("Error: Failed to open map file (" + map_file + ")")
		return false
		
	while not map.eof_reached():
		var line: String = map.get_line()
		newline()
		
		var tokens: Array[String] = split_string(line, [" ", "\t"], true)
		for s in tokens:
			token(s)
	
	return true
		
func split_string(s: String, delimeters: Array[String], allow_empty: bool = true) -> Array[String]:
	var parts: Array[String] = []
	
	var start := 0
	var i := 0
	
	while i < s.length():
		if s[i] in delimeters:
			if allow_empty or start < i:
				parts.push_back(s.substr(start, i - start))
			start = i + 1
		i += 1
	
	if allow_empty or start < i:
		parts.push_back(s.substr(start, i - start))
	
	return parts
	
func set_scope(new_scope: ParseScope) -> void:
	"""
	match new_scope:
		ParseScope.FILE:
			print("Switching to file scope.")
		ParseScope.ENTITY:
			print("Switching to entity " + str(entity_idx) + "scope")
		ParseScope.PROPERTY_VALUE:
			print("Switching to property value scope")
		ParseScope.BRUSH:
			print("Switching to brush " + str(brush_idx) + " scope")
		ParseScope.PLANE_0:
			print("Switching to face " + str(face_idx) + " plane 0 scope")
		ParseScope.PLANE_1:
			print("Switching to face " + str(face_idx) + " plane 1 scope")
		ParseScope.PLANE_2:
			print("Switching to face " + str(face_idx) + " plane 2 scope")
		ParseScope.TEXTURE:
			print("Switching to texture scope")
		ParseScope.U:
			print("Switching to U scope")
		ParseScope.V:
			print("Switching to V scope")
		ParseScope.VALVE_U:
			print("Switching to Valve U scope")
		ParseScope.VALVE_V:
			print("Switching to Valve V scope")
		ParseScope.ROT:
			print("Switching to rotation scope")
		ParseScope.U_SCALE:
			print("Switching to U scale scope")
		ParseScope.V_SCALE:
			print("Switching to V scale scope")
	"""
	scope = new_scope

func token(buf_str: String) -> void:
	if comment:
		return
	elif buf_str == "//":
		comment = true
		return
	
	match scope:
		ParseScope.FILE:
			if buf_str == "{":
				entity_idx += 1
				brush_idx = -1
				set_scope(ParseScope.ENTITY)
		ParseScope.ENTITY:
			if buf_str.begins_with('"'):
				prop_key = buf_str.substr(1)
				if prop_key.ends_with('"'):
					prop_key = prop_key.left(-1)
					set_scope(ParseScope.PROPERTY_VALUE)
			elif buf_str == "{":
				brush_idx += 1
				face_idx = -1
				set_scope(ParseScope.BRUSH)
			elif buf_str == "}":
				commit_entity()
				set_scope(ParseScope.FILE)
		ParseScope.PROPERTY_VALUE:
			var is_first = buf_str[0] == '"'
			var is_last = buf_str.right(1) == '"'
			
			if is_first:
				if current_property != "":
					current_property = ""
				
			if is_first or is_last:
				current_property += buf_str
			else:
				current_property += " " + buf_str + " "
				
			if is_last:
				current_entity.properties[prop_key] = current_property.substr(1, len(current_property) - 2)
				set_scope(ParseScope.ENTITY)
		ParseScope.BRUSH:
			if buf_str == "(":
				face_idx += 1
				component_idx = 0
				set_scope(ParseScope.PLANE_0)
			elif buf_str == "}":
				commit_brush()
				set_scope(ParseScope.ENTITY)
		ParseScope.PLANE_0:
			if buf_str == ")":
				component_idx = 0
				set_scope(ParseScope.PLANE_1)
			else:
				match component_idx:
					0:
						current_face.plane_points.v0.x = float(buf_str)
					1:
						current_face.plane_points.v0.y = float(buf_str)
					2:
						current_face.plane_points.v0.z = float(buf_str)
						
				component_idx += 1
		ParseScope.PLANE_1:
			if buf_str != "(":
				if buf_str == ")":
					component_idx = 0
					set_scope(ParseScope.PLANE_2)
				else:
					match component_idx:
						0:
							current_face.plane_points.v1.x = float(buf_str)
						1:
							current_face.plane_points.v1.y = float(buf_str)
						2:
							current_face.plane_points.v1.z = float(buf_str)
							
					component_idx += 1
		ParseScope.PLANE_2:
			if buf_str != "(":
				if buf_str == ")":
					component_idx = 0
					set_scope(ParseScope.TEXTURE)
				else:
					match component_idx:
						0:
							current_face.plane_points.v2.x = float(buf_str)
						1:
							current_face.plane_points.v2.y = float(buf_str)
						2:
							current_face.plane_points.v2.z = float(buf_str)
							
					component_idx += 1
		ParseScope.TEXTURE:
			current_face.texture_idx = map_data.register_texture(buf_str)
			set_scope(ParseScope.U)
		ParseScope.U:
			if buf_str == "[":
				valve_uvs = true
				component_idx = 0
				set_scope(ParseScope.VALVE_U)
			else:
				valve_uvs = false
				current_face.uv_standard.x = float(buf_str)
				set_scope(ParseScope.V)
		ParseScope.V:
				current_face.uv_standard.y = float(buf_str)
				set_scope(ParseScope.ROT)
		ParseScope.VALVE_U:
			if buf_str == "]":
				component_idx = 0
				set_scope(ParseScope.VALVE_V)
			else:
				match component_idx:
					0:
						current_face.uv_valve.u.axis.x = float(buf_str)
					1:
						current_face.uv_valve.u.axis.y = float(buf_str)
					2:
						current_face.uv_valve.u.axis.z = float(buf_str)
					3:
						current_face.uv_valve.u.offset = float(buf_str)
					
				component_idx += 1
		ParseScope.VALVE_V:
			if buf_str != "[":
				if buf_str == "]":
					set_scope(ParseScope.ROT)
				else:
					match component_idx:
						0:
							current_face.uv_valve.v.axis.x = float(buf_str)
						1:
							current_face.uv_valve.v.axis.y = float(buf_str)
						2:
							current_face.uv_valve.v.axis.z = float(buf_str)
						3:
							current_face.uv_valve.v.offset = float(buf_str)
						
					component_idx += 1
		ParseScope.ROT:
			current_face.uv_extra.rot = float(buf_str)
			set_scope(ParseScope.U_SCALE)
		ParseScope.U_SCALE:
			current_face.uv_extra.scale_x = float(buf_str)
			set_scope(ParseScope.V_SCALE)
		ParseScope.V_SCALE:
			current_face.uv_extra.scale_y = float(buf_str)
			commit_face()
			set_scope(ParseScope.BRUSH)
				
func commit_entity() -> void:
	var new_entity:= Entity.new()
	new_entity.spawn_type = EntitySpawnType.ENTITY
	new_entity.properties = current_entity.properties
	new_entity.brushes = current_entity.brushes
	
	map_data.entities.append(new_entity)
	current_entity = Entity.new()
	
func commit_brush() -> void:
	current_entity.brushes.append(current_brush)
	current_brush = Brush.new()
	
func commit_face() -> void:
	var v0v1: Vector3 = current_face.plane_points.v1 - current_face.plane_points.v0
	var v1v2: Vector3 = current_face.plane_points.v2 - current_face.plane_points.v1
	current_face.plane_normal = v1v2.cross(v0v1).normalized()
	current_face.plane_dist = current_face.plane_normal.dot(current_face.plane_points.v0)
	current_face.is_valve_uv = valve_uvs
	
	current_brush.faces.append(current_face)
	current_face = Face.new()
	

func newline() -> void:
	if comment:
		comment = false

# Nested
enum ParseScope{
	FILE,
	COMMENT,
	ENTITY,
	PROPERTY_VALUE,
	BRUSH,
	PLANE_0,
	PLANE_1,
	PLANE_2,
	TEXTURE,
	U,
	V,
	VALVE_U,
	VALVE_V,
	ROT,
	U_SCALE,
	V_SCALE
}

enum EntitySpawnType{
	WORLDSPAWN = 0,
	MERGE_WORLDSPAWN = 1,
	ENTITY = 2,
	GROUP = 3
}

class FacePoints:
	var v0: Vector3
	var v1: Vector3
	var v2: Vector3

class ValveTextureAxis:
	var axis: Vector3
	var offset: float
	
class ValveUV:
	var u: ValveTextureAxis
	var v: ValveTextureAxis
	
	func _init() -> void:
		u = ValveTextureAxis.new()
		v = ValveTextureAxis.new()
	
class FaceUVExtra:
	var rot: float
	var scale_x: float
	var scale_y: float
	
class Face:
	var plane_points: FacePoints
	var plane_normal: Vector3
	var plane_dist: float
	var texture_idx: int
	var is_valve_uv: bool
	var uv_standard: Vector2
	var uv_valve: ValveUV
	var uv_extra: FaceUVExtra
	
	func _init() -> void:
		plane_points = FacePoints.new()
		uv_valve = ValveUV.new()
		uv_extra = FaceUVExtra.new()

class Brush:
	var faces: Array[Face]
	var center: Vector3

class Entity:
	var properties: Dictionary
	var brushes: Array[Brush]
	var center: Vector3
	var spawn_type: EntitySpawnType
	
class FaceVertex:
	var vertex: Vector3
	var normal: Vector3
	var uv: Vector2
	var tangent: Vector4
	
	func duplicate() -> FaceVertex:
		var new_vert := FaceVertex.new()
		new_vert.vertex = vertex
		new_vert.normal = normal
		new_vert.uv = uv
		new_vert.tangent = tangent
		return new_vert
	
class FaceGeometry:
	var vertices: Array[FaceVertex]
	var indicies: Array[int]

class BrushGeometry:
	var faces: Array[FaceGeometry]
	
class EntityGeometry:
	var brushes: Array[BrushGeometry]

class TextureData:
	var name: String
	var width: int
	var height: int
	
	func _init(in_name: String):
		name = in_name
	
class WorldspawnLayer:
	var texture_idx: int
	var build_visuals: bool
	
	func _init(in_texture_idx: int, in_build_visuals: bool):
		texture_idx = in_texture_idx
		build_visuals = in_build_visuals
	
class MapData:
	var entities: Array[Entity]
	var entity_geo: Array[EntityGeometry]
	var textures: Array[TextureData]
	var worldspawn_layers: Array[WorldspawnLayer]
		
	func register_worldspawn_layer(name: String, build_visuals: bool) -> void:
		worldspawn_layers.append(WorldspawnLayer.new(find_texture(name), build_visuals))
		
	func find_worldspawn_layer(texture_idx: int) -> int:
		for i in range(worldspawn_layers.size()):
			if worldspawn_layers[i].texture_idx == texture_idx:
				return i
		return -1
	
	func register_texture(name: String) -> int:
		for i in range(textures.size()):
			if textures[i].name == name:
				return i
		
		textures.append(TextureData.new(name))
		return textures.size() - 1
	
	func set_texture_size(name: String, width: int, height: int) -> void:
		for i in range(textures.size()):
			if textures[i].name == name:
				textures[i].width = width
				textures[i].height = height
				return
	
	func find_texture(texture_name: String) -> int:
		for i in range(textures.size()):
			if textures[i].name == texture_name:
				return i
		return -1
	
	func set_spawn_type_by_classname(key: String, spawn_type: EntitySpawnType) -> void:
		for entity in entities:
			if entity.properties.has("classname") and entity.properties["classname"] == key:
				entity.spawn_type = spawn_type
	
	func clear() -> void:
		entities.clear()
		entity_geo.clear()
		textures.clear()
		worldspawn_layers.clear()
	
	func print_entities() -> void:
		print("Yet to implement LMMapData::map_data_print_entities...")
