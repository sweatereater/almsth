class_name Persistence
extends RefCounted

const Presentation := preload("res://scripts/system/presentation_settings.gd")

const SAVE_VERSION := 12
const MIN_SUPPORTED_SAVE_VERSION := 1
const SAVE_PATH := "user://savegame.json"
const SAVES_DIR := "user://saves"
const SETTINGS_PATH := "user://settings.cfg"
const SLOT_ENVELOPE_VERSION := 1
const LEGACY_IMPORT_MARKER := ".legacy-imported.json"
const DEFAULT_AUDIO_SETTINGS := {
	"muted": false,
	"background_volume": 50,
	"actions_volume": 75,
}


static func save_game(state: RunState, path := SAVE_PATH) -> Error:
	return _atomic_write_json({
		"version": SAVE_VERSION,
		"state": state.to_save_data(),
	}, path)


static func load_game(path := SAVE_PATH) -> Dictionary:
	var parsed = _read_json_dictionary(path)
	if not _is_legacy_envelope_valid(parsed):
		parsed = _read_json_dictionary(path + ".bak")
	if not _is_legacy_envelope_valid(parsed):
		return {}
	return parsed.get("state", {}).duplicate(true)


static func save_slot(
	state: RunState,
	slot_id := "",
	save_policy := "overwrite",
	saves_dir := SAVES_DIR,
	timestamp := -1,
	id_factory := Callable(),
	extra_metadata: Dictionary = {},
	fault_injector := Callable(),
) -> Dictionary:
	var resolved_timestamp := timestamp if timestamp >= 0 else int(Time.get_unix_time_from_system())
	var resolved_id := _safe_slot_id(slot_id)
	if resolved_id.is_empty():
		if not slot_id.strip_edges().is_empty():
			return {"ok": false, "error": ERR_INVALID_PARAMETER, "slot_id": ""}
		resolved_id = _safe_slot_id(String(id_factory.call()) if id_factory.is_valid() else _generate_slot_id(resolved_timestamp))
	if resolved_id.is_empty():
		return {"ok": false, "error": ERR_INVALID_PARAMETER, "slot_id": ""}
	var metadata := {
		"slot_id": resolved_id,
		"updated_at": resolved_timestamp,
		"character_name": state.character_name,
		"lifetime_souls_earned": state.lifetime_souls_earned,
		"save_policy": "history" if save_policy == "history" else "overwrite",
	}
	for key in extra_metadata:
		metadata[key] = extra_metadata[key]
	var envelope := {
		"envelope_version": SLOT_ENVELOPE_VERSION,
		"version": SAVE_VERSION,
		"metadata": metadata,
		"state": state.to_save_data(),
	}
	var path := _slot_path(saves_dir, resolved_id)
	var error := _atomic_write_json(envelope, path, fault_injector)
	if error != OK:
		return {"ok": false, "error": error, "slot_id": resolved_id}
	return {"ok": true, "error": OK, "slot_id": resolved_id, "metadata": metadata}


static func load_slot(slot_id: String, saves_dir := SAVES_DIR) -> Dictionary:
	var resolved_id := _safe_slot_id(slot_id)
	if resolved_id.is_empty():
		return {"ok": false, "error": ERR_INVALID_PARAMETER}
	var path := _slot_path(saves_dir, resolved_id)
	var envelope := _read_json_dictionary(path)
	var recovered_from_backup := false
	if not _is_slot_envelope_valid(envelope, resolved_id):
		envelope = _read_json_dictionary(path + ".bak")
		recovered_from_backup = true
	if not _is_slot_envelope_valid(envelope, resolved_id):
		return {"ok": false, "error": ERR_FILE_CORRUPT}
	return {
		"ok": true,
		"error": OK,
		"slot_id": resolved_id,
		"metadata": (envelope["metadata"] as Dictionary).duplicate(true),
		"state": (envelope["state"] as Dictionary).duplicate(true),
		"recovered_from_backup": recovered_from_backup,
	}


static func list_slots(saves_dir := SAVES_DIR) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(saves_dir)
	if directory == null:
		return result
	var slot_ids := {}
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir():
			var slot_id := ""
			if file_name.ends_with(".json.bak"):
				slot_id = file_name.trim_suffix(".json.bak")
			elif file_name.ends_with(".json"):
				slot_id = file_name.trim_suffix(".json")
			if not slot_id.is_empty() and file_name != LEGACY_IMPORT_MARKER and file_name != LEGACY_IMPORT_MARKER + ".bak":
				slot_ids[slot_id] = true
		file_name = directory.get_next()
	directory.list_dir_end()
	for slot_id_value in slot_ids:
		var slot_id := String(slot_id_value)
		var loaded := load_slot(slot_id, saves_dir)
		if bool(loaded.get("ok", false)):
			var row: Dictionary = (loaded["metadata"] as Dictionary).duplicate(true)
			row["slot_id"] = slot_id
			row["recovered_from_backup"] = bool(loaded.get("recovered_from_backup", false))
			result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_time := int(a.get("updated_at", 0))
		var b_time := int(b.get("updated_at", 0))
		return a_time > b_time if a_time != b_time else String(a.get("slot_id", "")) < String(b.get("slot_id", ""))
	)
	return result


static func latest_slot(saves_dir := SAVES_DIR) -> Dictionary:
	var slots := list_slots(saves_dir)
	return slots[0].duplicate(true) if not slots.is_empty() else {}


static func delete_slot(
	slot_id: String,
	saves_dir := SAVES_DIR,
	fault_injector := Callable(),
) -> Dictionary:
	var resolved_id := _safe_slot_id(slot_id)
	if resolved_id.is_empty():
		return {
			"ok": false,
			"error": ERR_INVALID_PARAMETER,
			"slot_id": "",
			"removed": false,
			"remaining": {},
		}
	var primary_path := _slot_path(saves_dir, resolved_id)
	var primary_valid := _is_slot_envelope_valid(_read_json_dictionary(primary_path), resolved_id)
	var backup_valid := _is_slot_envelope_valid(_read_json_dictionary(primary_path + ".bak"), resolved_id)
	var targets := [{"stage": "temporary", "path": primary_path + ".tmp"}]
	# Preserve the last valid representation until the final successful removal.
	# Normally primary is authoritative and remains last. During backup recovery,
	# remove the invalid/missing primary first and keep the valid backup last so a
	# failed attempt remains listable and retriable from the UI.
	if not primary_valid and backup_valid:
		targets.append({"stage": "primary", "path": primary_path})
		targets.append({"stage": "backup", "path": primary_path + ".bak"})
	else:
		targets.append({"stage": "backup", "path": primary_path + ".bak"})
		targets.append({"stage": "primary", "path": primary_path})
	var removed_stages: Array[String] = []
	for target in targets:
		var path := String(target["path"])
		var stage := String(target["stage"])
		if not FileAccess.file_exists(path):
			continue
		if fault_injector.is_valid() and bool(fault_injector.call(stage)):
			return _delete_slot_result(
				false, ERR_CANT_CREATE, resolved_id, primary_path, removed_stages, stage,
			)
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if remove_error != OK:
			return _delete_slot_result(
				false, remove_error, resolved_id, primary_path, removed_stages, stage,
			)
		removed_stages.append(stage)
	return _delete_slot_result(
		true, OK, resolved_id, primary_path, removed_stages, "",
	)


static func _delete_slot_result(
	ok: bool,
	error: Error,
	slot_id: String,
	primary_path: String,
	removed_stages: Array[String],
	error_stage: String,
) -> Dictionary:
	var remaining := {
		"temporary": FileAccess.file_exists(primary_path + ".tmp"),
		"backup": FileAccess.file_exists(primary_path + ".bak"),
		"primary": FileAccess.file_exists(primary_path),
	}
	return {
		"ok": ok and not bool(remaining["temporary"]) and not bool(remaining["backup"]) and not bool(remaining["primary"]),
		"error": error,
		"slot_id": slot_id,
		"removed": not removed_stages.is_empty(),
		"removed_stages": removed_stages.duplicate(),
		"error_stage": error_stage,
		"remaining": remaining,
	}


static func import_legacy_once(
	legacy_path := SAVE_PATH,
	saves_dir := SAVES_DIR,
	timestamp := -1,
	id_factory := Callable(),
) -> Dictionary:
	var marker_path := saves_dir.path_join(LEGACY_IMPORT_MARKER)
	if FileAccess.file_exists(marker_path):
		return {"ok": true, "imported": false}
	for metadata in list_slots(saves_dir):
		if bool(metadata.get("legacy_import", false)):
			_atomic_write_json({"imported": true}, marker_path)
			return {"ok": true, "imported": false, "slot_id": metadata.get("slot_id", "")}
	var legacy_data := load_game(legacy_path)
	if legacy_data.is_empty():
		return {"ok": true, "imported": false}
	var legacy_state := RunState.new()
	if not legacy_state.restore_save_data(legacy_data):
		return {"ok": false, "imported": false, "error": ERR_FILE_CORRUPT}
	var generated_id := String(id_factory.call()) if id_factory.is_valid() else _generate_slot_id(timestamp)
	var save_result := save_slot(
		legacy_state, generated_id, "overwrite", saves_dir, timestamp, Callable(),
		{"legacy_import": true},
	)
	if not bool(save_result.get("ok", false)):
		return save_result.merged({"imported": false}, true)
	var marker_error := _atomic_write_json({"imported": true, "slot_id": save_result["slot_id"]}, marker_path)
	if marker_error != OK:
		return {"ok": false, "imported": true, "error": marker_error, "slot_id": save_result["slot_id"]}
	return {"ok": true, "imported": true, "slot_id": save_result["slot_id"]}


static func _is_legacy_envelope_valid(parsed: Dictionary) -> bool:
	if not parsed is Dictionary:
		return false
	var version := int(parsed.get("version", 0))
	if version < MIN_SUPPORTED_SAVE_VERSION or version > SAVE_VERSION:
		return false
	return parsed.get("state", null) is Dictionary


static func _is_slot_envelope_valid(envelope: Dictionary, expected_slot_id := "") -> bool:
	if int(envelope.get("envelope_version", 0)) != SLOT_ENVELOPE_VERSION:
		return false
	var version := int(envelope.get("version", 0))
	if version < MIN_SUPPORTED_SAVE_VERSION or version > SAVE_VERSION:
		return false
	if not envelope.get("metadata", null) is Dictionary or not envelope.get("state", null) is Dictionary:
		return false
	var metadata: Dictionary = envelope["metadata"]
	return (
		not String(metadata.get("slot_id", "")).is_empty()
		and (expected_slot_id.is_empty() or String(metadata.get("slot_id", "")) == expected_slot_id)
		and not String(metadata.get("character_name", "")).strip_edges().is_empty()
	)


static func _atomic_write_json(data: Dictionary, path: String, fault_injector := Callable()) -> Error:
	var directory_path := path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error
	var temporary_path := path + ".tmp"
	var backup_path := path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	var write_error := file.get_error()
	file = null
	if write_error != OK:
		_remove_if_exists(temporary_path)
		return write_error
	var validation := _read_json_dictionary(temporary_path)
	if not _payload_matches_schema(validation, data):
		_remove_if_exists(temporary_path)
		return ERR_FILE_CORRUPT
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var had_primary := FileAccess.file_exists(path)
	if had_primary:
		var existing_primary := _read_json_dictionary(path)
		if _payload_matches_schema(existing_primary, data):
			if FileAccess.file_exists(backup_path):
				var remove_backup_error := DirAccess.remove_absolute(absolute_backup)
				if remove_backup_error != OK:
					_remove_if_exists(temporary_path)
					return remove_backup_error
			var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup)
			if backup_error != OK:
				_remove_if_exists(temporary_path)
				return backup_error
		else:
			var remove_primary_error := DirAccess.remove_absolute(absolute_path)
			if remove_primary_error != OK:
				_remove_if_exists(temporary_path)
				return remove_primary_error
			had_primary = false
	if fault_injector.is_valid() and bool(fault_injector.call("after_primary_backup")):
		if had_primary and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		_remove_if_exists(temporary_path)
		return ERR_CANT_CREATE
	var promote_error := DirAccess.rename_absolute(absolute_temporary, absolute_path)
	if promote_error != OK:
		if had_primary and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		_remove_if_exists(temporary_path)
		return promote_error
	return OK


static func _payload_matches_schema(candidate: Dictionary, template: Dictionary) -> bool:
	if candidate.is_empty():
		return false
	if template.has("envelope_version"):
		var metadata: Dictionary = template.get("metadata", {})
		return _is_slot_envelope_valid(candidate, String(metadata.get("slot_id", "")))
	if template.has("version") and template.has("state"):
		return _is_legacy_envelope_valid(candidate)
	return true


static func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return {}
	return (json.data as Dictionary).duplicate(true)


static func _slot_path(saves_dir: String, slot_id: String) -> String:
	return saves_dir.path_join(slot_id + ".json")


static func _safe_slot_id(value: String) -> String:
	var candidate := value.strip_edges()
	if candidate.is_empty() or candidate.length() > 96 or candidate.contains(".."):
		return ""
	for character in candidate:
		var code := character.unicode_at(0)
		var ascii_letter := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var ascii_digit := code >= 48 and code <= 57
		if not (ascii_letter or ascii_digit or character == "_" or character == "-" or character == "."):
			return ""
	if candidate == "." or candidate == LEGACY_IMPORT_MARKER.trim_suffix(".json"):
		return ""
	return candidate


static func _generate_slot_id(timestamp: int) -> String:
	var actual_timestamp := timestamp if timestamp >= 0 else int(Time.get_unix_time_from_system())
	var random := RandomNumberGenerator.new()
	random.randomize()
	return "%x-%08x" % [actual_timestamp, random.randi()]


static func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func delete_game(path := SAVE_PATH) -> Error:
	var result := OK
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
			if result == OK and error != OK:
				result = error
	return result


static func save_settings(data: Dictionary, path := SETTINGS_PATH) -> Error:
	var config := ConfigFile.new()
	# Retain unrelated settings written by older or platform-specific builds.
	if FileAccess.file_exists(path):
		config.load(path)
	if data.has("fullscreen"):
		config.set_value("display", "fullscreen", bool(data["fullscreen"]))
	if data.has("inspection_radius"):
		config.set_value("gameplay", "inspection_radius", int(data["inspection_radius"]))
	if data.has("dungeon_cell_size"):
		config.set_value(
			"gameplay", "dungeon_cell_size",
			Presentation.sanitize_cell_size(data["dungeon_cell_size"]),
		)
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
		"dungeon_cell_size": Presentation.sanitize_cell_size(
			config.get_value(
				"gameplay", "dungeon_cell_size", Presentation.DEFAULT_CELL_SIZE,
			),
		),
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
