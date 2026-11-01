extends Node
## Global state: progress, checkpoints, settings and input map.

signal settings_changed
signal state_changed

const SAVE_PATH := "user://asterion_save.json"
const SETTINGS_PATH := "user://asterion_settings.cfg"
const TOTAL_SPARKS := 5
const SAVE_VERSION := 1

var settings := {
	"music": 0.75,
	"sfx": 0.9,
	"sensitivity": 1.0,
	"quality": 1,  # 0 = leve, 1 = bonito
	"touch_controls": true,
}

## Current playthrough. Flags are plain strings so saves stay readable.
var state: Dictionary = {}

## The RetroNexa opening plays once per launch.
var splash_shown := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()
	new_state()

func new_state() -> void:
	state = {
		"version": SAVE_VERSION,
		"chapter": 1,
		"checkpoint": "clearing",
		"flags": {},
		"sparks": [],
		"essence": "",
		"time": 0.0,
	}
	state_changed.emit()

func flag(name: String) -> bool:
	return bool(state.get("flags", {}).get(name, false))

func set_flag(name: String, value := true) -> void:
	state["flags"][name] = value
	state_changed.emit()

func chapter() -> int:
	return int(state.get("chapter", 1))

func spark_count() -> int:
	return state.get("sparks", []).size()

func has_spark(id: String) -> bool:
	return state.get("sparks", []).has(id)

func add_spark(id: String) -> void:
	if not has_spark(id):
		state["sparks"].append(id)
		state_changed.emit()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state, "\t"))

func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	new_state()
	for key in data.keys():
		state[key] = data[key]
	if typeof(state.get("flags")) != TYPE_DICTIONARY:
		state["flags"] = {}
	if typeof(state.get("sparks")) != TYPE_ARRAY:
		state["sparks"] = []
	state_changed.emit()
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for key in settings.keys():
			settings[key] = cfg.get_value("settings", key, settings[key])
	apply_settings()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings.keys():
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)

func set_setting(key: String, value) -> void:
	settings[key] = value
	apply_settings()
	save_settings()

func apply_settings() -> void:
	settings_changed.emit()

func is_touch_device() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]

func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"cast": [KEY_E, KEY_J],
		"interact": [KEY_F, KEY_ENTER],
		"run": [KEY_SHIFT],
		"swap_essence": [KEY_TAB, KEY_R],
		"cam_left": [KEY_Q],
		"cam_right": [KEY_C],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# Gamepad support (useful on Android TV / controllers).
	var pad := {
		"jump": JOY_BUTTON_A, "cast": JOY_BUTTON_X, "interact": JOY_BUTTON_B,
		"swap_essence": JOY_BUTTON_Y, "pause": JOY_BUTTON_START, "run": JOY_BUTTON_LEFT_SHOULDER,
	}
	for action in pad.keys():
		var jb := InputEventJoypadButton.new()
		jb.button_index = pad[action]
		InputMap.action_add_event(action, jb)
