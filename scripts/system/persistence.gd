class_name Persistence
extends RefCounted

const SAVE_VERSION := 8
const MIN_SUPPORTED_SAVE_VERSION := 1
const SAVE_PATH := "user://savegame.json"
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_AUDIO_SETTINGS := {
	"muted": false,
	"background_volume": 50,
	"actions_volume": 75,
}


static func save_game(state: RunState, path := SAVE_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"state": state.to_save_data(),
	}, "  "))
	return OK


static func load_game(path := SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed = json.data
	if not parsed is Dictionary:
		return {}
	var version := int(parsed.get("version", 0))
	if version < MIN_SUPPORTED_SAVE_VERSION or version > SAVE_VERSION:
		return {}
	return parsed.get("state", {}) if parsed.get("state", {}) is Dictionary else {}


static func delete_game(path := SAVE_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func save_settings(data: Dictionary, path := SETTINGS_PATH) -> Error:
	var config := ConfigFile.new()
	# Retain unrelated settings written by older or platform-specific builds.
	if FileAccess.file_exists(path):
		config.load(path)
	if data.has("fullscreen"):
		config.set_value("display", "fullscreen", bool(data["fullscreen"]))
	if data.has("inspection_radius"):
		config.set_value("gameplay", "inspection_radius", int(data["inspection_radius"]))
	if data.has("locale"):
		config.set_value("localization", "locale", String(data["locale"]))
	if data.has("bindings"):
		config.set_value("input", "bindings", data["bindings"])
	if data.has("audio"):
		var audio = data["audio"]
		if audio is Dictionary:
			if audio.has("muted"):
				config.set_value("audio", "muted", _strict_bool(
					audio["muted"], DEFAULT_AUDIO_SETTINGS["muted"],
				))
			if audio.has("background_volume"):
				config.set_value("audio", "background_volume", _bounded_percent(
					audio["background_volume"], DEFAULT_AUDIO_SETTINGS["background_volume"],
				))
			if audio.has("actions_volume"):
				config.set_value("audio", "actions_volume", _bounded_percent(
					audio["actions_volume"], DEFAULT_AUDIO_SETTINGS["actions_volume"],
				))
	return config.save(path)


static func load_settings(path := SETTINGS_PATH) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return {}
	return {
		"fullscreen": bool(config.get_value("display", "fullscreen", false)),
		"inspection_radius": int(config.get_value("gameplay", "inspection_radius", 6)),
		"locale": String(config.get_value("localization", "locale", "ru")),
		"bindings": config.get_value("input", "bindings", {}),
		"audio": {
			"muted": _strict_bool(
				config.get_value("audio", "muted", DEFAULT_AUDIO_SETTINGS["muted"]),
				DEFAULT_AUDIO_SETTINGS["muted"],
			),
			"background_volume": _bounded_percent(
				config.get_value("audio", "background_volume", DEFAULT_AUDIO_SETTINGS["background_volume"]),
				DEFAULT_AUDIO_SETTINGS["background_volume"],
			),
			"actions_volume": _bounded_percent(
				config.get_value("audio", "actions_volume", DEFAULT_AUDIO_SETTINGS["actions_volume"]),
				DEFAULT_AUDIO_SETTINGS["actions_volume"],
			),
		},
	}


static func _strict_bool(value, default_value: bool) -> bool:
	return value if value is bool else default_value


static func _bounded_percent(value, default_value: int) -> int:
	if not value is int and not value is float:
		return default_value
	return clampi(roundi(float(value)), 0, 100)


static func delete_settings(path := SETTINGS_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
