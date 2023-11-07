@tool
class_name QodotProjectConfig
extends Resource

enum PROPERTY {
	TRENCHBROOM_GAMES_FOLDER = 0,
	TRENCHBROOM_WORKING_FOLDER = 1,
	TRENCHBROOM_MODELS_FOLDER = 2
}

@export var export_qodot_settings: bool: set = _save_settings

const CONFIG_PROPERTIES: Array[Dictionary] = [
	{
		"name": "trenchbroom_games_folder",
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
		"qodot_type": PROPERTY.TRENCHBROOM_GAMES_FOLDER
	},
	{
		"name": "trenchbroom_working_folder",
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
		"qodot_type": PROPERTY.TRENCHBROOM_WORKING_FOLDER
	},
	{
		"name": "trenchbroom_models_folder",
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"qodot_type": PROPERTY.TRENCHBROOM_MODELS_FOLDER
	}
]

var settings_dict: Dictionary
var loaded := false

static func get_setting(name: PROPERTY) -> String:
	var settings = load("res://addons/qodot/qodot_project_config.tres")
	if not settings.loaded: settings._load_settings()
	return settings.settings_dict.get(PROPERTY.keys()[name], '') as String

func _get_property_list() -> Array:
	return CONFIG_PROPERTIES.duplicate()

func _get(property: StringName):
	var config = _get_config_property(property)
	if config == null and not config is Dictionary: return null
	_try_loading()
	return settings_dict.get(PROPERTY.keys()[config['qodot_type']], _get_default_value(config['type']))

func _set(property: StringName, value: Variant):
	var config = _get_config_property(property)
	if config == null and not config is Dictionary: return
	settings_dict[PROPERTY.keys()[config['qodot_type']]] = value
	
func _get_default_value(type):
	match type:
		TYPE_STRING: return ''
		TYPE_INT: return 0
		TYPE_FLOAT: return 0.0
		TYPE_BOOL: return false
		TYPE_ARRAY: return []
		TYPE_DICTIONARY: return {}
	push_error("Invalid setting type. Returning null")
	return null

func _get_config_property(name: StringName) -> Variant:
	for config in CONFIG_PROPERTIES:
		if config['name'] == name: 
			return config
	return null

func _load_settings() -> void:
	loaded = true
	var path = _get_path()
	if not FileAccess.file_exists(path): return
	var settings = FileAccess.get_file_as_string(path)
	settings_dict = {}
	if not settings or settings.is_empty(): return
	settings = JSON.parse_string(settings)
	for key in settings.keys():
		settings_dict[key] = settings[key]
	notify_property_list_changed()

func _try_loading() -> void:
	if not loaded: _load_settings()

func _save_settings(_s = null) -> void:
	if settings_dict.size() == 0: return
	var path = _get_path()
	var file = FileAccess.open(path, FileAccess.WRITE)
	var json = JSON.stringify(settings_dict)
	file.store_line(json)
	loaded = false
	print("Saved settings to ", path)

func _get_path() -> String:
	var application_name = ProjectSettings.get('application/config/name')
	return 'user://' + application_name  + 'QodotConfig.json'
