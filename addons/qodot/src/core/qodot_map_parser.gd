class_name QodotMapParser extends RefCounted

var STRIP_FUNC_GROUP := true

var scope:= QodotMapParser.ParseScope.FILE
var comment: bool = false
var entity_idx: int = -1
var brush_idx: int = -1
var face_idx: int = -1
var component_idx: int = 0
var prop_key: String = ""
var current_property: String = ""
var valve_uvs: bool = false

var current_face: QodotMapData.Face
var current_brush: QodotMapData.Brush
var current_entity: QodotMapData.Entity

var map_data: QodotMapData

func _init(in_map_data: QodotMapData) -> void:
	map_data = in_map_data

func load(map_file: String) -> bool:
	current_face = QodotMapData.Face.new()
	current_brush = QodotMapData.Brush.new()
	current_entity = QodotMapData.Entity.new()
	
	scope = QodotMapParser.ParseScope.FILE
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
		if comment:
			comment = false
		
		var tokens := split_string(line, [" ", "\t"], true)
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
	
func set_scope(new_scope: QodotMapParser.ParseScope) -> void:
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
		QodotMapParser.ParseScope.FILE:
			if buf_str == "{":
				entity_idx += 1
				brush_idx = -1
				set_scope(QodotMapParser.ParseScope.ENTITY)
		QodotMapParser.ParseScope.ENTITY:
			if buf_str.begins_with('"'):
				prop_key = buf_str.substr(1)
				if prop_key.ends_with('"'):
					prop_key = prop_key.left(-1)
					set_scope(QodotMapParser.ParseScope.PROPERTY_VALUE)
			elif buf_str == "{":
				brush_idx += 1
				face_idx = -1
				set_scope(QodotMapParser.ParseScope.BRUSH)
			elif buf_str == "}":
				commit_entity()
				set_scope(QodotMapParser.ParseScope.FILE)
		QodotMapParser.ParseScope.PROPERTY_VALUE:
			var is_first = buf_str[0] == '"'
			var is_last = buf_str.right(1) == '"'
			
			if is_first:
				if current_property != "":
					current_property = ""
				
			if not is_last:
				current_property += buf_str + " "
			else:
				current_property += buf_str
				
			if is_last:
				current_entity.properties[prop_key] = current_property.substr(1, len(current_property) - 2)
				set_scope(QodotMapParser.ParseScope.ENTITY)
		QodotMapParser.ParseScope.BRUSH:
			if buf_str == "(":
				face_idx += 1
				component_idx = 0
				set_scope(QodotMapParser.ParseScope.PLANE_0)
			elif buf_str == "}":
				commit_brush()
				set_scope(QodotMapParser.ParseScope.ENTITY)
		QodotMapParser.ParseScope.PLANE_0:
			if buf_str == ")":
				component_idx = 0
				set_scope(QodotMapParser.ParseScope.PLANE_1)
			else:
				match component_idx:
					0:
						current_face.plane_points.v0.x = float(buf_str)
					1:
						current_face.plane_points.v0.y = float(buf_str)
					2:
						current_face.plane_points.v0.z = float(buf_str)
						
				component_idx += 1
		QodotMapParser.ParseScope.PLANE_1:
			if buf_str != "(":
				if buf_str == ")":
					component_idx = 0
					set_scope(QodotMapParser.ParseScope.PLANE_2)
				else:
					match component_idx:
						0:
							current_face.plane_points.v1.x = float(buf_str)
						1:
							current_face.plane_points.v1.y = float(buf_str)
						2:
							current_face.plane_points.v1.z = float(buf_str)
							
					component_idx += 1
		QodotMapParser.ParseScope.PLANE_2:
			if buf_str != "(":
				if buf_str == ")":
					component_idx = 0
					set_scope(QodotMapParser.ParseScope.TEXTURE)
				else:
					match component_idx:
						0:
							current_face.plane_points.v2.x = float(buf_str)
						1:
							current_face.plane_points.v2.y = float(buf_str)
						2:
							current_face.plane_points.v2.z = float(buf_str)
							
					component_idx += 1
		QodotMapParser.ParseScope.TEXTURE:
			current_face.texture_idx = map_data.register_texture(buf_str)
			set_scope(QodotMapParser.ParseScope.U)
		QodotMapParser.ParseScope.U:
			if buf_str == "[":
				valve_uvs = true
				component_idx = 0
				set_scope(QodotMapParser.ParseScope.VALVE_U)
			else:
				valve_uvs = false
				current_face.uv_standard.x = float(buf_str)
				set_scope(QodotMapParser.ParseScope.V)
		QodotMapParser.ParseScope.V:
				current_face.uv_standard.y = float(buf_str)
				set_scope(QodotMapParser.ParseScope.ROT)
		QodotMapParser.ParseScope.VALVE_U:
			if buf_str == "]":
				component_idx = 0
				set_scope(QodotMapParser.ParseScope.VALVE_V)
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
		QodotMapParser.ParseScope.VALVE_V:
			if buf_str != "[":
				if buf_str == "]":
					set_scope(QodotMapParser.ParseScope.ROT)
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
		QodotMapParser.ParseScope.ROT:
			current_face.uv_extra.rot = float(buf_str)
			set_scope(QodotMapParser.ParseScope.U_SCALE)
		QodotMapParser.ParseScope.U_SCALE:
			current_face.uv_extra.scale_x = float(buf_str)
			set_scope(QodotMapParser.ParseScope.V_SCALE)
		QodotMapParser.ParseScope.V_SCALE:
			current_face.uv_extra.scale_y = float(buf_str)
			commit_face()
			set_scope(QodotMapParser.ParseScope.BRUSH)
				
func commit_entity() -> void:
	if STRIP_FUNC_GROUP and current_entity.properties.has("classname") and current_entity.properties["classname"] == "func_group" and map_data.entities.size() > 0:
			map_data.entities[0].brushes.append_array(current_entity.brushes)
	else:
		var new_entity:= QodotMapData.Entity.new()
		new_entity.spawn_type = QodotMapData.EntitySpawnType.ENTITY
		new_entity.properties = current_entity.properties
		new_entity.brushes = current_entity.brushes
		
		map_data.entities.append(new_entity)
		
	current_entity = QodotMapData.Entity.new()
	
func commit_brush() -> void:
	current_entity.brushes.append(current_brush)
	current_brush = QodotMapData.Brush.new()
	
func commit_face() -> void:
	var v0v1: Vector3 = current_face.plane_points.v1 - current_face.plane_points.v0
	var v1v2: Vector3 = current_face.plane_points.v2 - current_face.plane_points.v1
	current_face.plane_normal = v1v2.cross(v0v1).normalized()
	current_face.plane_dist = current_face.plane_normal.dot(current_face.plane_points.v0)
	current_face.is_valve_uv = valve_uvs
	
	current_brush.faces.append(current_face)
	current_face = QodotMapData.Face.new()

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
