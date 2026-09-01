class_name Persistence
extends RefCounted

const Presentation := preload("res://scripts/system/presentation_settings.gd")
const Snapshot := preload("res://scripts/system/run_snapshot.gd")

const SAVE_VERSION := 17
const STATE_ONLY_VERSION := 17
const MIN_SUPPORTED_SAVE_VERSION := 17
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

## Tie-break same-second gameplay publications without scanning every slot on
## every turn. Reading existing slots also advances this process-local clock.
static var _publication_clock := 0


static func save_game(state: RunState, path := SAVE_PATH) -> Error:
	return _atomic_write_json({
		"version": STATE_ONLY_VERSION,
		"kind": "state_only",
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
	snapshot: Dictionary = {},
) -> Dictionary:
	var resolved_timestamp := timestamp if timestamp >= 0 else int(Time.get_unix_time_from_system())
	var explicit_id := not slot_id.strip_edges().is_empty()
	var resolved_id := _safe_slot_id(slot_id) if explicit_id else ""
	if explicit_id and resolved_id.is_empty():
		return {"ok": false, "error": ERR_INVALID_PARAMETER, "slot_id": ""}
	if not explicit_id:
		var generated_candidates := {}
		for attempt in range(64):
			var raw_candidate := (
				String(id_factory.call())
				if id_factory.is_valid() and attempt < 8
				else _generate_slot_id(resolved_timestamp + attempt)
			)
			var candidate := _safe_slot_id(raw_candidate)
			if candidate.is_empty() or generated_candidates.has(candidate):
				continue
			generated_candidates[candidate] = true
			if not _slot_family_exists(saves_dir, candidate):
				resolved_id = candidate
				break
	if resolved_id.is_empty():
		return {"ok": false, "error": ERR_ALREADY_EXISTS, "slot_id": ""}
	var path := _slot_path(saves_dir, resolved_id)
	if explicit_id and _slot_family_exists(saves_dir, resolved_id):
		var family_is_safe := not FileAccess.file_exists(path + ".tmp")
		for family_path in [path, path + ".bak"]:
			if FileAccess.file_exists(family_path):
				family_is_safe = (
					family_is_safe
					and _is_slot_envelope_valid(_read_json_dictionary(family_path), resolved_id)
				)
		if not family_is_safe:
			return {
				"ok": false,
				"error": ERR_FILE_CORRUPT,
				"reason": "occupied_incompatible",
				"slot_id": resolved_id,
			}
	var serialized_state := (
		state.to_save_data() if snapshot.is_empty() else state.to_snapshot_data()
	)
	var metadata := {
		"slot_id": resolved_id,
		"updated_at": resolved_timestamp,
		"character_name": serialized_state.character_name,
		"lifetime_souls_earned": serialized_state.lifetime_souls_earned,
		"save_policy": "history" if save_policy == "history" else "overwrite",
	}
	for key in extra_metadata:
		metadata[key] = extra_metadata[key]
	if not snapshot.is_empty():
		_publication_clock = maxi(_publication_clock + 1, int(Time.get_unix_time_from_system() * 1000000.0))
		metadata["publication_order"] = str(_publication_clock)
	var envelope := {
		"envelope_version": SLOT_ENVELOPE_VERSION,
		"version": SAVE_VERSION,
		"kind": "state_only" if snapshot.is_empty() else "full_run",
		"metadata": metadata,
		"state": serialized_state if snapshot.is_empty() else Snapshot.encode(serialized_state),
	}
	if not snapshot.is_empty():
		envelope["snapshot"] = snapshot.duplicate(true)
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
	var primary_exists := FileAccess.file_exists(path)
	var primary_valid := _is_slot_envelope_valid(envelope, resolved_id)
	var backup_path := path + ".bak"
	var backup_exists := FileAccess.file_exists(backup_path)
	var backup_envelope := _read_json_dictionary(backup_path) if backup_exists else {}
	var backup_valid := backup_exists and _is_slot_envelope_valid(backup_envelope, resolved_id)
	var recovered_from_backup := false
	if not primary_valid:
		envelope = backup_envelope
		recovered_from_backup = true
	if not _is_slot_envelope_valid(envelope, resolved_id):
		return {"ok": false, "error": ERR_FILE_CORRUPT}
	_publication_clock = maxi(_publication_clock, int(envelope["metadata"].get("publication_order", "0")))
	return {
		"ok": true,
		"error": OK,
		"slot_id": resolved_id,
		"metadata": (envelope["metadata"] as Dictionary).duplicate(true),
		"state": (envelope["state"] as Dictionary).duplicate(true),
		"snapshot": Snapshot.restore(envelope.get("snapshot"), envelope["state"]) if envelope.get("kind") == "full_run" else {},
		"version": int(envelope["version"]),
		"recovered_from_backup": recovered_from_backup,
		"write_locked": (
			(recovered_from_backup and primary_exists)
			or (backup_exists and not backup_valid)
			or FileAccess.file_exists(path + ".tmp")
		),
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
			row["write_locked"] = bool(loaded.get("write_locked", false))
			row["compatible"] = true
			row["locked"] = false
			result.append(row)
			continue
		var raw := _read_raw_json_dictionary(_slot_path(saves_dir, slot_id))
		if raw.is_empty():
			raw = _read_raw_json_dictionary(_slot_path(saves_dir, slot_id) + ".bak")
		var raw_metadata: Dictionary = raw.get("metadata", {}) if raw.get("metadata") is Dictionary else {}
		var raw_state: Dictionary = raw.get("state", {}) if raw.get("state") is Dictionary else {}
		result.append({
			"slot_id": slot_id,
			"updated_at": int(raw_metadata.get("updated_at", 0)),
			"character_name": String(raw_metadata.get("character_name", raw_state.get("character_name", ""))),
			"lifetime_souls_earned": int(raw_metadata.get("lifetime_souls_earned", 0)),
			"save_policy": String(raw_metadata.get("save_policy", "overwrite")),
			"compatible": false,
			"locked": true,
			"write_locked": true,
			"incompatible_version": int(raw.get("version", 0)),
			"corrupt": raw.is_empty(),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_time := int(a.get("updated_at", 0))
		var b_time := int(b.get("updated_at", 0))
		if a_time != b_time:
			return a_time > b_time
		var a_order := int(a.get("publication_order", "0"))
		var b_order := int(b.get("publication_order", "0"))
		if a_order != b_order:
			return a_order > b_order
		# Old state-only files have no publication order; retain their stable tie.
		return String(a.get("slot_id", "")) < String(b.get("slot_id", ""))
	)
	return result


static func latest_slot(saves_dir := SAVES_DIR) -> Dictionary:
	var slots := list_slots(saves_dir)
	for slot in slots:
		if bool(slot.get("compatible", true)) and not bool(slot.get("locked", false)):
			return slot.duplicate(true)
	return {}


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
	var save_result := save_slot(
		legacy_state, "", "overwrite", saves_dir, timestamp, id_factory,
		{"legacy_import": true},
	)
	if not bool(save_result.get("ok", false)):
		return save_result.merged({"imported": false}, true)
	var marker_error := _atomic_write_json({"imported": true, "slot_id": save_result["slot_id"]}, marker_path)
	if marker_error != OK:
		return {"ok": false, "imported": true, "error": marker_error, "slot_id": save_result["slot_id"]}
	return {"ok": true, "imported": true, "slot_id": save_result["slot_id"]}


static func _is_legacy_envelope_valid(parsed: Dictionary) -> bool:
	if (
		not parsed is Dictionary
		or parsed.size() != 3
		or not parsed.has("version")
		or not parsed.has("kind")
		or not parsed.has("state")
		or parsed.get("kind") != "state_only"
	):
		return false
	var raw_version: Variant = parsed.get("version", null)
	if not _is_exact_json_integer(raw_version):
		return false
	var version := int(raw_version)
	if version < MIN_SUPPORTED_SAVE_VERSION or version > SAVE_VERSION:
		return false
	if not parsed.get("state", null) is Dictionary:
		return false
	return _valid_save_kind(parsed)


static func _is_slot_envelope_valid(envelope: Dictionary, expected_slot_id := "") -> bool:
	var raw_envelope_version: Variant = envelope.get("envelope_version", null)
	if not _is_exact_json_integer(raw_envelope_version) or int(raw_envelope_version) != SLOT_ENVELOPE_VERSION:
		return false
	var raw_version: Variant = envelope.get("version", null)
	if not _is_exact_json_integer(raw_version):
		return false
	var version := int(raw_version)
	if version < MIN_SUPPORTED_SAVE_VERSION or version > SAVE_VERSION:
		return false
	if not envelope.get("metadata", null) is Dictionary or not envelope.get("state", null) is Dictionary:
		return false
	if not _valid_save_kind(envelope):
		return false
	var metadata: Dictionary = envelope["metadata"]
	for field in [
		"slot_id", "updated_at", "character_name", "lifetime_souls_earned", "save_policy",
	]:
		if not metadata.has(field):
			return false
	var metadata_slot_id: Variant = metadata.slot_id
	var metadata_name: Variant = metadata.character_name
	var metadata_policy: Variant = metadata.save_policy
	var state: Dictionary = envelope.state
	if (
		not metadata_slot_id is String
		or _safe_slot_id(metadata_slot_id) != metadata_slot_id
		or (not expected_slot_id.is_empty() and metadata_slot_id != expected_slot_id)
		or not metadata_name is String
		or metadata_name != state.get("character_name")
		or not metadata_policy is String
		or metadata_policy not in ["overwrite", "history"]
		or not _is_exact_json_integer(metadata.updated_at)
		or int(metadata.updated_at) < 0
		or not _is_exact_json_integer(metadata.lifetime_souls_earned)
		or int(metadata.lifetime_souls_earned) < 0
		or int(metadata.lifetime_souls_earned) != int(state.get("lifetime_souls_earned", -1))
	):
		return false
	if envelope.kind == "full_run":
		if not metadata.has("publication_order"):
			return false
		var order: Variant = metadata.publication_order
		if (
			not order is String
			or not order.is_valid_int()
			or str(int(order)) != order
			or int(order) <= 0
		):
			return false
	elif metadata.has("publication_order"):
		# Reserved for exact full-run publications. Accepting it on a state-only
		# slot would let setup records participate in resume ordering.
		return false
	return true


static func _is_exact_json_integer(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floorf(value)


## v17 explicitly separates setup-only helpers from complete live runs. Missing or
## corrupt full snapshots never silently resume at base. Old test files/backs stay
## on disk untouched and are excluded, including by one-time legacy import.
static func _valid_save_kind(envelope: Dictionary) -> bool:
	if envelope.get("kind") == "full_run":
		return not Snapshot.restore(envelope.get("snapshot"), envelope["state"]).is_empty()
	if envelope.get("kind") == "state_only":
		return not envelope.has("snapshot") and not String(envelope["state"].get("character_name", "")).strip_edges().is_empty() and RunState.is_stage1_save_data_valid(envelope["state"])
	return false


static func _atomic_write_json(data: Dictionary, path: String, fault_injector := Callable()) -> Error:
	var directory_path := path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error
	var temporary_path := path + ".tmp"
	var backup_path := path + ".bak"
	# Preflight happens before creating or truncating .tmp. An unsupported or corrupt
	# primary belongs to the user and can still be explicitly deleted from the slot UI;
	# an attempted save must never remove or replace it as a side effect.
	if FileAccess.file_exists(temporary_path):
		return ERR_ALREADY_EXISTS
	if FileAccess.file_exists(path):
		var existing_primary := _read_json_dictionary(path)
		if not _payload_matches_schema(existing_primary, data):
			return ERR_FILE_CORRUPT
	if FileAccess.file_exists(backup_path):
		var existing_backup := _read_json_dictionary(backup_path)
		if not _payload_matches_schema(existing_backup, data):
			return ERR_FILE_CORRUPT
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	# Snapshot floats have their own lossless encoding. Retain decimal precision
	# for legacy state-only files and other ordinary JSON numeric fields as well.
	file.store_string(JSON.stringify(data, "  ", true, true))
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
		if FileAccess.file_exists(backup_path):
			var remove_backup_error := DirAccess.remove_absolute(absolute_backup)
			if remove_backup_error != OK:
				_remove_if_exists(temporary_path)
				return remove_backup_error
		var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup)
		if backup_error != OK:
			_remove_if_exists(temporary_path)
			return backup_error
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
	var data := _read_raw_json_dictionary(path)
	if data.is_empty():
		return {}
	var raw_version: Variant = data.get("version", null)
	if _is_exact_json_integer(raw_version) and int(raw_version) == SAVE_VERSION and data.get("state") is Dictionary:
		var errors: Array = []
		var decoded: Variant = Snapshot.decode(data["state"], errors)
		if not errors.is_empty() or not decoded is Dictionary:
			return {}
		data["state"] = RunState.snapshot_data_from_json(decoded)
	return data


static func _read_raw_json_dictionary(path: String) -> Dictionary:
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


static func _slot_family_exists(saves_dir: String, slot_id: String) -> bool:
	var path := _slot_path(saves_dir, slot_id)
	return (
		FileAccess.file_exists(path)
		or FileAccess.file_exists(path + ".bak")
		or FileAccess.file_exists(path + ".tmp")
	)


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
	if data.has("dungeon_cell_size"):
		config.set_value(
			"gameplay", "dungeon_cell_size",
			Presentation.sanitize_cell_size(data["dungeon_cell_size"]),
		)
	if data.has("auto_movement_speed_percent"):
		config.set_value(
			"gameplay", "auto_movement_speed_percent",
			Presentation.sanitize_auto_movement_speed_percent(
				data["auto_movement_speed_percent"]
			),
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
		"dungeon_cell_size": Presentation.sanitize_cell_size(
			config.get_value(
				"gameplay", "dungeon_cell_size", Presentation.DEFAULT_CELL_SIZE,
			),
		),
		"auto_movement_speed_percent": Presentation.sanitize_auto_movement_speed_percent(
			config.get_value(
				"gameplay", "auto_movement_speed_percent",
				Presentation.DEFAULT_AUTO_MOVEMENT_SPEED_PERCENT,
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
