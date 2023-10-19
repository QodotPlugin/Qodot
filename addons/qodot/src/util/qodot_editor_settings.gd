@tool
class_name QodotEditorSettings
extends Resource

var trenchbroom_game_config_path: String:
    get: 
        _try_loading()
        return settings_dict.get(trenchbroom_game_config_key, '')
    set(val):
        settings_dict[trenchbroom_game_config_key] = val
        _save_settings()
var trenchbroom_project_path: String:
    get: 
        _try_loading()
        return settings_dict.get(trenchbroom_project_setting_key, '')
    set(val):
        settings_dict[trenchbroom_project_setting_key] = val
        _save_settings()
var settings_dict: Dictionary
var loaded := false

const trenchbroom_game_config_key := "tb_game_config_path"
const trenchbroom_project_setting_key := "tb_project_path"

static func get_setting(name) -> String:
    var settings = load("res://addons/qodot/game_definitions/qodot_editor_settings.tres")
    if not settings.loaded: settings._load_settings()
    return settings.settings_dict.get(name, '') as String

static func get_trenchbroom_game_config_path() -> String:
    return get_setting(trenchbroom_game_config_key)

static func get_trenchbroom_project_path() -> String:
    return get_setting(trenchbroom_project_setting_key)

func _get_property_list() -> Array:
    var properties = []
    const usage = PROPERTY_USAGE_EDITOR
    const type = TYPE_STRING
    const hint = PROPERTY_HINT_GLOBAL_DIR

    properties.append({
        "name": "trenchbroom_game_config_path",
        "usage": PROPERTY_USAGE_EDITOR,
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_GLOBAL_DIR,
    })
    properties.append({
        "name": "trenchbroom_project_path",
        "usage": PROPERTY_USAGE_EDITOR,
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_GLOBAL_DIR,
    })
    return properties

func _load_settings() -> void:
    loaded = true
    var path = _get_path()
    var settings = FileAccess.get_file_as_string(path)
    settings_dict = {}
    if not settings or settings.is_empty(): return
    settings = JSON.parse_string(settings)
    for key in settings.keys():
        settings_dict[key] = settings[key]
    print("Loaded settings from ", path)
    notify_property_list_changed()

func _try_loading() -> void:
    if not loaded: _load_settings()

func _save_settings() -> void:
    settings_dict[trenchbroom_game_config_key] = trenchbroom_game_config_path
    settings_dict[trenchbroom_project_setting_key] = trenchbroom_project_path
    var path = _get_path()
    var file = FileAccess.open(path, FileAccess.WRITE)
    var json = JSON.stringify(settings_dict)
    file.store_line(json)
    loaded = false
    print("Saved settings to ", path)

func _get_path() -> String:
    var application_name = ProjectSettings.get('application/config/name')
    return 'user://QodotEditorSettings-' + application_name + ".json"