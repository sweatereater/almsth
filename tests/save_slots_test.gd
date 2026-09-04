class_name SaveSlotsTestSuite
extends RefCounted

const SaveSystem := preload("res://scripts/system/persistence.gd")
const Snapshot := preload("res://scripts/system/run_snapshot.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const SaveMenuPanel := preload("res://scripts/ui/save_menu_panel.gd")

const ROOT := "res://.tmp/nightly/save-slots-regression"
const LEGACY_PATH := ROOT + "/legacy.json"
const SLOTS_PATH := ROOT + "/slots"

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_cleanup()
	_test_lifetime_counter()
	_test_atomic_backup_and_listing()
	_test_strict_v18_state_only_validation()
	await _test_main_rejects_invalid_v18_state_only(tree)
	await _test_strict_v18_full_run_validation(tree)
	await _test_corrupt_reason_diagnostics(tree)
	_test_legacy_import_once()
	_test_failure_does_not_publish_slot()
	_test_permanent_slot_deletion()
	await _test_main_and_panel(tree)
	_cleanup()
	return failures


func _test_strict_v18_state_only_validation() -> void:
	var strict_dir := ROOT + "/strict-v18"
	var source := _state("Strict v18", 4)
	var source_before := source.to_snapshot_data()
	var fixtures := [
		{"id": "missing-soul", "kind": "erase", "field": "soul_level"},
		{"id": "missing-hp", "kind": "erase", "field": "hp"},
		{"id": "extra-top-level", "kind": "extra"},
		{"id": "missing-save-policy", "kind": "metadata_policy"},
		{"id": "state-only-publication-order", "kind": "metadata_order"},
		{"id": "wrong-turn-type", "kind": "set", "field": "total_turns", "value": "0"},
		{"id": "negative-soul", "kind": "set", "field": "soul_level", "value": -1},
		{"id": "missing-skill", "kind": "missing_skill"},
		{"id": "extra-skill", "kind": "extra_skill"},
		{"id": "overmax-skill", "kind": "overmax_skill"},
		{"id": "missing-skill-prereq", "kind": "skill_prerequisite"},
		{"id": "form-lifetime-mismatch", "kind": "progression"},
		{"id": "noncanonical-absorbed-total", "kind": "absorbed_gap"},
		{"id": "skeleton-satiated", "kind": "status"},
		{"id": "skeleton-rested", "kind": "rested_status"},
		{"id": "highest-without-lifetime", "kind": "highest_lifetime"},
		{"id": "highest-plus-wallet-without-lifetime", "kind": "highest_wallet_lifetime"},
		{"id": "invalid-kettle-preparation", "kind": "kettle_preparation"},
		{"id": "invalid-rest-preparation", "kind": "rest_preparation"},
		{"id": "unlearned-cooldown", "kind": "cooldown"},
		{"id": "current-form-locked-cooldown", "kind": "form_locked_cooldown"},
		{"id": "inactive-regeneration-progress", "kind": "regeneration"},
		{"id": "overflow-mana-progress", "kind": "mana_overflow"},
		{"id": "full-mana-progress", "kind": "mana_full"},
		{"id": "two-hand-offhand", "kind": "two_hand"},
		{"id": "writing-no-workbench", "kind": "camp", "built": "writing_set"},
		{"id": "kettle-no-campfire", "kind": "camp", "built": "kettle"},
	]
	for fixture in fixtures:
		var slot_id := String(fixture.id)
		_expect(
			bool(SaveSystem.save_slot(source, slot_id, "overwrite", strict_dir, 710).get("ok", false)),
			"Strict v18 fixture must begin as a valid state-only slot: %s" % slot_id,
		)
		var path := strict_dir.path_join(slot_id + ".json")
		var envelope := _read_json(path)
		var disk_state: Dictionary = envelope.get("state", {})
		match String(fixture.kind):
			"erase":
				disk_state.erase(String(fixture.field))
			"set":
				disk_state[String(fixture.field)] = fixture.value
			"missing_skill":
				disk_state.skill_levels.erase("strong_spine")
			"extra_skill":
				disk_state.skill_levels["spinal_cord"] = 0
			"overmax_skill":
				disk_state.skill_levels.strong_bones = 6
			"extra":
				disk_state["intruder"] = true
			"metadata_policy":
				envelope.metadata.erase("save_policy")
			"metadata_order":
				envelope.metadata["publication_order"] = "123"
			"skill_prerequisite":
				disk_state.skill_levels.magic_missile = 1
			"progression":
				disk_state.absorbed_souls = 20
			"absorbed_gap":
				disk_state.absorbed_souls = 15
				disk_state.current_form_id = "zombie"
				disk_state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("zombie")
				disk_state.lifetime_souls_earned = int(disk_state.carried_souls) + 15
			"status":
				disk_state.active_statuses = {
					"satiated": {"remaining_turns": 10, "temporary_hp": 3},
				}
			"rested_status":
				disk_state.active_statuses = {
					"rested": {"remaining_turns": 10, "temporary_hp": 5},
				}
			"highest_lifetime":
				disk_state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
				disk_state.soul_level = 3
			"highest_wallet_lifetime":
				disk_state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
				disk_state.soul_level = 3
				disk_state.lifetime_souls_earned = int(GameRules.FORMS.almost_human.threshold)
			"kettle_preparation":
				disk_state.camp_preparation.pending = true
				disk_state.camp_preparation.kettle_selected = true
				disk_state.food = 0
			"rest_preparation":
				disk_state.camp_preparation.pending = true
				disk_state.camp_preparation.rested = true
			"cooldown":
				disk_state.ability_cooldowns = {"dash": 5}
			"form_locked_cooldown":
				disk_state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
				disk_state.soul_level = 1
				disk_state.lifetime_souls_earned = (
					int(disk_state.carried_souls) + int(GameRules.FORMS.ghoul.threshold)
				)
				disk_state.skill_levels.dash = 1
				disk_state.ability_cooldowns = {"dash": 5}
			"regeneration":
				disk_state.regeneration_progress = 1
			"mana_overflow":
				disk_state.mana = 0
				disk_state.mana_regeneration_progress = 2.0
			"mana_full":
				disk_state.mana_regeneration_progress = 0.5
			"two_hand":
				disk_state.loadout["right_hand"] = "old_claymore"
				disk_state.loadout["left_hand"] = "hollow_lantern"
			"camp":
				disk_state.camp_upgrades[String(fixture.built)] = true
		envelope["state"] = disk_state
		_write_text(path, JSON.stringify(envelope, "  ", true, true))
		if slot_id == "missing-soul":
			_write_text(path + ".bak", "{\"version\":15,\"preserve\":\"backup\"}")
			_write_text(path + ".tmp", "{interrupted-temporary")
		var before_family := _snapshot_family_bytes(path)
		_expect(
			not bool(SaveSystem.load_slot(slot_id, strict_dir).get("ok", false))
			and _snapshot_family_bytes(path) == before_family
			and source.to_snapshot_data() == source_before,
			"Invalid v18 state-only disk payload must reject with exact file/runtime preservation: %s"
			% slot_id,
		)

	var legacy_path := strict_dir.path_join("missing-soul-legacy.json")
	var legacy_state := source.to_save_data()
	legacy_state.erase("soul_level")
	_write_text(legacy_path, JSON.stringify({
		"version": SaveSystem.SAVE_VERSION,
		"kind": "state_only",
		"state": legacy_state,
	}, "  ", true, true))
	var legacy_bytes := FileAccess.get_file_as_bytes(legacy_path)
	_expect(
		SaveSystem.load_game(legacy_path).is_empty()
		and FileAccess.get_file_as_bytes(legacy_path) == legacy_bytes
		and source.to_snapshot_data() == source_before,
		"Legacy-path v18 state-only missing soul_level must reject without mutation",
	)


func _test_main_rejects_invalid_v18_state_only(tree: SceneTree) -> void:
	var strict_dir := ROOT + "/strict-main"
	var invalid_source := _state("Invalid on disk", 3)
	_expect(
		bool(SaveSystem.save_slot(
			invalid_source, "missing-soul", "overwrite", strict_dir, 720,
		).get("ok", false)),
		"Main strict-load fixture must publish before corruption",
	)
	var path := strict_dir.path_join("missing-soul.json")
	var envelope := _read_json(path)
	var disk_state: Dictionary = envelope.get("state", {})
	disk_state.erase("soul_level")
	envelope["state"] = disk_state
	_write_text(path, JSON.stringify(envelope, "  ", true, true))
	_write_text(path + ".bak", "{\"version\":15,\"preserve\":\"backup\"}")
	_write_text(path + ".tmp", "{interrupted-temporary")
	var before_family := _snapshot_family_bytes(path)

	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = true
	main.audio_playback_enabled = false
	main.save_slots_directory = strict_dir
	main.settings_path = ROOT + "/strict-main-settings.cfg"
	main.legacy_save_path = ROOT + "/strict-main-missing-legacy.json"
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var live_state := _state("Live sentinel", 9)
	main.state = live_state
	main.active_save_slot_id = "live-sentinel"
	main.screen = main.Screen.BASE
	main.main_menu_open = true
	var live_before := live_state.to_snapshot_data()
	main._on_save_slot_load_requested("missing-soul")
	_expect(
		main.state == live_state
		and main.state.to_snapshot_data() == live_before
		and main.active_save_slot_id == "live-sentinel"
		and main.screen == main.Screen.BASE
		and main.last_save_error == Loc.text("MSG_LOAD_CORRUPT_FAMILY", [ERR_FILE_CORRUPT])
		and _snapshot_family_bytes(path) == before_family,
		"Main must reject missing soul_level before restore with exact live/file preservation",
	)
	main.queue_free()
	await tree.process_frame


func _test_strict_v18_full_run_validation(tree: SceneTree) -> void:
	var strict_dir := ROOT + "/strict-full-run"
	var invalid_families := {}
	for fixture in [
		{"id": "full-missing-skill", "kind": "missing_skill"},
		{"id": "full-extra-attribute", "kind": "extra_attribute"},
		{"id": "full-extra-state", "kind": "extra_state"},
		{"id": "full-missing-rooms", "kind": "missing_rooms"},
		{"id": "full-empty-rooms", "kind": "empty_rooms"},
		{"id": "full-fixed-bypass", "kind": "fixed_bypass"},
		{"id": "full-missing-boss", "kind": "missing_boss"},
		{"id": "full-progression", "kind": "progression"},
		{"id": "full-missing-policy", "kind": "missing_policy"},
		{"id": "full-missing-order", "kind": "missing_order"},
		{"id": "full-metadata-lifetime", "kind": "metadata_lifetime"},
	]:
		var slot_id := String(fixture.id)
		var kind := String(fixture.kind)
		var full_state := _state("Strict full", 5)
		var snapshot_override := {}
		if kind in ["missing_rooms", "empty_rooms", "fixed_bypass"]:
			full_state.current_floor = 99
			var random := RandomNumberGenerator.new()
			random.seed = 160099
			var floor := FloorGenerator.new().generate(99, 160099, 0.0)
			snapshot_override = Snapshot.capture(
				"dungeon", floor, floor.start, random,
				{"attack_memories": {}, "event_revision": 0},
			)
		elif kind == "missing_boss":
			full_state.current_floor = 90
			var random := RandomNumberGenerator.new()
			random.seed = 160090
			var floor := FixedFloor90.create()
			snapshot_override = Snapshot.capture(
				"dungeon", floor, floor.start, random,
				{"attack_memories": {}, "event_revision": 0},
			)
		var publish_result := _save_full_run(
			full_state, slot_id, strict_dir, 730, snapshot_override,
		)
		_expect(
			bool(publish_result.get("ok", false)),
			"Strict full-run fixture must publish before corruption: %s (%s)"
			% [slot_id, publish_result],
		)
		if not bool(publish_result.get("ok", false)):
			continue
		var path := strict_dir.path_join(slot_id + ".json")
		var envelope := _read_json(path)
		match kind:
			"missing_skill":
				envelope.state.skill_levels.erase("ears")
			"extra_attribute":
				envelope.state.attributes["intruder"] = 7
			"extra_state":
				envelope.state["intruder"] = true
			"missing_rooms":
				envelope.snapshot.floor_data.erase("rooms")
			"empty_rooms":
				envelope.snapshot.floor_data.rooms = []
			"fixed_bypass":
				envelope.snapshot.floor_data.erase("rooms")
				envelope.snapshot.floor_data.fixed_layout = true
			"missing_boss":
				for field in ["boss_uid", "boss_defeated", "boss_door", "boss_door_open"]:
					envelope.snapshot.floor_data.erase(field)
			"progression":
				envelope.state.absorbed_souls = 20
			"missing_policy":
				envelope.metadata.erase("save_policy")
			"missing_order":
				envelope.metadata.erase("publication_order")
			"metadata_lifetime":
				envelope.metadata.lifetime_souls_earned = (
					int(envelope.metadata.lifetime_souls_earned) + 1
				)
		_write_text(path, JSON.stringify(envelope, "  ", true, true))
		var before_family := _snapshot_family_bytes(path)
		invalid_families[slot_id] = before_family
		var decode_errors: Array = []
		var decoded_state: Variant = Snapshot.decode(envelope.state, decode_errors)
		var snapshot_rejected := (
			decoded_state is Dictionary
			and Snapshot.restore(envelope.snapshot, decoded_state).is_empty()
		)
		var metadata_only := kind in ["missing_policy", "missing_order", "metadata_lifetime"]
		_expect(
			decode_errors.is_empty()
			and decoded_state is Dictionary
			and (not snapshot_rejected if metadata_only else snapshot_rejected)
			and not bool(SaveSystem.load_slot(slot_id, strict_dir).get("ok", false))
			and _snapshot_family_bytes(path) == before_family,
			"Current v18 full-run schema must reject without file mutation: %s"
			% slot_id,
		)

	# An invalid primary does not poison a valid full-run backup. Loading is read-only
	# and write-locked so a later save branches instead of overwriting either source.
	var fallback_id := "full-backup-fallback"
	var fallback_before := _state("Fallback before", 6)
	var fallback_after := _state("Fallback after", 7)
	_expect(
		bool(_save_full_run(fallback_before, fallback_id, strict_dir, 740).get("ok", false))
		and bool(_save_full_run(fallback_after, fallback_id, strict_dir, 741).get("ok", false)),
		"Full-run fallback fixture must publish valid primary and backup",
	)
	var fallback_path := strict_dir.path_join(fallback_id + ".json")
	var corrupt_primary := _read_json(fallback_path)
	corrupt_primary.metadata.erase("save_policy")
	_write_text(fallback_path, JSON.stringify(corrupt_primary, "  ", true, true))
	var fallback_family_before := _snapshot_family_bytes(fallback_path)
	var recovered := SaveSystem.load_slot(fallback_id, strict_dir)
	_expect(
		bool(recovered.get("ok", false))
		and bool(recovered.get("recovered_from_backup", false))
		and bool(recovered.get("write_locked", false))
		and String((recovered.get("state", {}) as Dictionary).get("character_name", ""))
		== "Fallback before"
		and _snapshot_family_bytes(fallback_path) == fallback_family_before,
		"Invalid-metadata full-run primary must load the valid backup read-only and write-locked",
	)

	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = true
	main.audio_playback_enabled = false
	main.save_slots_directory = strict_dir
	main.settings_path = ROOT + "/strict-full-run-settings.cfg"
	main.legacy_save_path = ROOT + "/strict-full-run-missing-legacy.json"
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var live_state := _state("Full live sentinel", 10)
	main.state = live_state
	main.active_save_slot_id = "full-live-sentinel"
	main.screen = main.Screen.BASE
	main.main_menu_open = true
	var live_before := live_state.to_snapshot_data()
	for slot_id in invalid_families:
		main._on_save_slot_load_requested(String(slot_id))
		var path := strict_dir.path_join(String(slot_id) + ".json")
		_expect(
			main.state == live_state
			and main.state.to_snapshot_data() == live_before
			and main.active_save_slot_id == "full-live-sentinel"
			and main.screen == main.Screen.BASE
			and main.last_save_error == Loc.text(
				"MSG_LOAD_CORRUPT_FAMILY", [ERR_FILE_CORRUPT],
			)
			and _snapshot_family_bytes(path) == invalid_families[slot_id],
			"Main must reject invalid full-run nested schema with exact live/file preservation: %s"
			% slot_id,
		)
	main._on_save_slot_load_requested(fallback_id)
	_expect(
		main.state != live_state
		and main.state.character_name == "Fallback before"
		and main.active_save_slot_id == fallback_id
		and main.active_save_write_locked
		and _snapshot_family_bytes(fallback_path) == fallback_family_before,
		"Main must restore a valid full-run backup without rewriting the corrupt family",
	)
	main.queue_free()
	await tree.process_frame


func _test_corrupt_reason_diagnostics(tree: SceneTree) -> void:
	_expect(ERR_FILE_CORRUPT == 16, "Godot corrupt-file diagnostics must retain numeric error code 16")
	var diagnostics_dir := ROOT + "/corrupt-reasons"
	var live_state := _state("Live Fraction", 8)
	live_state.mana = 0
	live_state.mana_regeneration_progress = 0.37500000000000006
	var live_before := live_state.to_snapshot_data()
	var random := RandomNumberGenerator.new()
	random.seed = 170001
	var rng_before := random.state
	var valid_snapshot := Snapshot.capture("base", {}, Vector2i.ZERO, random, {})
	var invalid_snapshot := valid_snapshot.duplicate(true)
	invalid_snapshot.rng_state = "not-an-int64"

	var free_result := SaveSystem.save_slot(
		live_state, "invalid-free", "overwrite", diagnostics_dir, 800,
		Callable(), {}, Callable(), invalid_snapshot,
	)
	var free_path := diagnostics_dir.path_join("invalid-free.json")
	_expect(
		not bool(free_result.get("ok", true))
		and int(free_result.get("error", OK)) == ERR_FILE_CORRUPT
		and String(free_result.get("reason", "")) == "invalid_live_snapshot"
		and _snapshot_family_bytes(free_path) == {
			"": {"exists": false, "bytes": PackedByteArray()},
			".bak": {"exists": false, "bytes": PackedByteArray()},
			".tmp": {"exists": false, "bytes": PackedByteArray()},
		}
		and live_state.to_snapshot_data() == live_before
		and random.state == rng_before,
		"Invalid live snapshot on a free family must return error 16 before any file/runtime/RNG mutation",
	)

	var existing_id := "invalid-existing"
	_expect(
		bool(SaveSystem.save_slot(
			live_state, existing_id, "overwrite", diagnostics_dir, 801,
			Callable(), {}, Callable(), valid_snapshot,
		).get("ok", false)),
		"Invalid-live existing-family fixture must publish a valid exact snapshot",
	)
	var existing_path := diagnostics_dir.path_join(existing_id + ".json")
	var existing_before := _snapshot_family_bytes(existing_path)
	var existing_result := SaveSystem.save_slot(
		live_state, existing_id, "overwrite", diagnostics_dir, 802,
		Callable(), {}, Callable(), invalid_snapshot,
	)
	_expect(
		not bool(existing_result.get("ok", true))
		and int(existing_result.get("error", OK)) == ERR_FILE_CORRUPT
		and String(existing_result.get("reason", "")) == "invalid_live_snapshot"
		and _snapshot_family_bytes(existing_path) == existing_before
		and not FileAccess.file_exists(existing_path + ".tmp")
		and live_state.to_snapshot_data() == live_before
		and random.state == rng_before,
		"Invalid live snapshot on a valid family must preserve exact bytes, runtime state and RNG",
	)
	var fractional_load := SaveSystem.load_slot(existing_id, diagnostics_dir)
	_expect(
		bool(fractional_load.get("ok", false))
		and var_to_bytes((fractional_load.state as Dictionary).mana_regeneration_progress)
		== var_to_bytes(live_state.mana_regeneration_progress),
		"Raw live preflight and disk verification must preserve valid fractional field bits",
	)

	var corrupt_id := "bad-primary-and-backup"
	_expect(
		bool(_save_full_run(_state("Corrupt Old", 1), corrupt_id, diagnostics_dir, 810).get("ok", false))
		and bool(_save_full_run(_state("Corrupt New", 2), corrupt_id, diagnostics_dir, 811).get("ok", false)),
		"Corrupt-family fixture must begin with a valid primary and backup",
	)
	var corrupt_path := diagnostics_dir.path_join(corrupt_id + ".json")
	_write_text(corrupt_path, "{bad-primary")
	_write_text(corrupt_path + ".bak", "{bad-backup")
	var corrupt_before := _snapshot_family_bytes(corrupt_path)
	var corrupt_save := _save_full_run(
		_state("Must Stay In Memory", 3), corrupt_id, diagnostics_dir, 812,
	)
	var corrupt_load := SaveSystem.load_slot(corrupt_id, diagnostics_dir)
	var corrupt_row := {}
	for row in SaveSystem.list_slots(diagnostics_dir):
		if row.get("slot_id") == corrupt_id:
			corrupt_row = row
			break
	_expect(
		not bool(corrupt_save.get("ok", true))
		and int(corrupt_save.get("error", OK)) == ERR_FILE_CORRUPT
		and String(corrupt_save.get("reason", "")) == "occupied_incompatible"
		and not bool(corrupt_load.get("ok", true))
		and int(corrupt_load.get("error", OK)) == ERR_FILE_CORRUPT
		and String(corrupt_load.get("reason", "")) == "corrupt_family"
		and bool(corrupt_row.get("corrupt", false))
		and String(corrupt_row.get("reason", "")) == "corrupt_family"
		and _snapshot_family_bytes(corrupt_path) == corrupt_before
		and not FileAccess.file_exists(corrupt_path + ".tmp"),
		"Bad primary plus backup must remain a visible corrupt family and reject writes without mutation",
	)

	var backup_fallback_id := "bad-primary-valid-backup"
	_expect(
		bool(_save_full_run(
			_state("Backup Source", 4), backup_fallback_id, diagnostics_dir, 820,
		).get("ok", false))
		and bool(_save_full_run(
			_state("Primary Source", 5), backup_fallback_id, diagnostics_dir, 821,
		).get("ok", false)),
		"Valid-backup fallback fixture must publish twice",
	)
	var backup_fallback_path := diagnostics_dir.path_join(backup_fallback_id + ".json")
	_write_text(backup_fallback_path, "{bad-primary")
	var backup_fallback_before := _snapshot_family_bytes(backup_fallback_path)
	var backup_fallback := SaveSystem.load_slot(backup_fallback_id, diagnostics_dir)
	var backup_fallback_row := SaveSystem.list_slots(diagnostics_dir).filter(
		func(row: Dictionary) -> bool: return row.get("slot_id") == backup_fallback_id
	)
	_expect(
		bool(backup_fallback.get("ok", false))
		and bool(backup_fallback.get("recovered_from_backup", false))
		and bool(backup_fallback.get("write_locked", false))
		and String((backup_fallback.state as Dictionary).character_name) == "Backup Source"
		and backup_fallback_row.size() == 1
		and bool(backup_fallback_row[0].get("compatible", false))
		and not bool(backup_fallback_row[0].get("corrupt", false))
		and _snapshot_family_bytes(backup_fallback_path) == backup_fallback_before,
		"Bad primary with valid backup must load the exact backup read-only without family mutation",
	)

	var primary_fallback_id := "valid-primary-bad-backup"
	_expect(
		bool(_save_full_run(
			_state("Backup To Corrupt", 6), primary_fallback_id, diagnostics_dir, 830,
		).get("ok", false))
		and bool(_save_full_run(
			_state("Valid Primary", 7), primary_fallback_id, diagnostics_dir, 831,
		).get("ok", false)),
		"Valid-primary fallback fixture must publish twice",
	)
	var primary_fallback_path := diagnostics_dir.path_join(primary_fallback_id + ".json")
	_write_text(primary_fallback_path + ".bak", "{bad-backup")
	var primary_fallback_before := _snapshot_family_bytes(primary_fallback_path)
	var primary_fallback := SaveSystem.load_slot(primary_fallback_id, diagnostics_dir)
	var primary_fallback_row := SaveSystem.list_slots(diagnostics_dir).filter(
		func(row: Dictionary) -> bool: return row.get("slot_id") == primary_fallback_id
	)
	_expect(
		bool(primary_fallback.get("ok", false))
		and not bool(primary_fallback.get("recovered_from_backup", true))
		and bool(primary_fallback.get("write_locked", false))
		and String((primary_fallback.state as Dictionary).character_name) == "Valid Primary"
		and primary_fallback_row.size() == 1
		and bool(primary_fallback_row[0].get("compatible", false))
		and not bool(primary_fallback_row[0].get("corrupt", false))
		and _snapshot_family_bytes(primary_fallback_path) == primary_fallback_before,
		"Valid primary with bad backup must load the exact primary read-only without family mutation",
	)
	_expect(
		bool(_save_full_run(
			_state("Diagnostic Fifth", 8), "diagnostic-fifth", diagnostics_dir, 840
		).get("ok", false))
		and bool(_save_full_run(
			_state("Diagnostic Sixth", 9), "diagnostic-sixth", diagnostics_dir, 841
		).get("ok", false)),
		"Diagnostic layout fixture must publish two additional valid families",
	)
	var diagnostic_slots := SaveSystem.list_slots(diagnostics_dir)
	_expect(
		diagnostic_slots.size() == SaveMenuPanel.PAGE_SIZE,
		"Diagnostic fixture must contain exactly PAGE_SIZE=6 families",
	)

	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	main.save_slots_directory = diagnostics_dir
	main.settings_path = ROOT + "/corrupt-reasons-settings.cfg"
	main.legacy_save_path = ROOT + "/corrupt-reasons-missing-legacy.json"
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	for locale in ["ru", "en"]:
		Loc.set_locale(locale)
		main._apply_locale()
		_expect(
			main._save_failure_text({
				"error": ERR_FILE_CORRUPT, "reason": "occupied_incompatible",
			}) == Loc.text("MSG_SAVE_OCCUPIED_INCOMPATIBLE", [ERR_FILE_CORRUPT])
			and main._save_failure_text({
				"error": ERR_FILE_CORRUPT, "reason": "invalid_live_snapshot",
			}) == Loc.text("MSG_SAVE_INVALID_LIVE_SNAPSHOT", [ERR_FILE_CORRUPT])
			and main._save_failure_text({
				"error": ERR_FILE_CORRUPT, "reason": "write_verification_failed",
			}) == Loc.text("MSG_SAVE_WRITE_VERIFICATION_FAILED", [ERR_FILE_CORRUPT])
			and main._load_failure_text(corrupt_load)
			== Loc.text("MSG_LOAD_CORRUPT_FAMILY", [ERR_FILE_CORRUPT]),
			"RU/EN error-16 diagnostics must map stable runtime reasons to exact localized guidance",
		)
		main.save_menu_panel.set_slots(diagnostic_slots)
		main.save_menu_panel.show_menu(false)
		main.save_menu_panel.show_load_list()
		await tree.process_frame
		_expect(
			main.save_menu_panel.slot_buttons.size() == main.save_menu_panel.PAGE_SIZE
			and main.save_menu_panel.trash_buttons.size() == main.save_menu_panel.PAGE_SIZE,
			"%s diagnostics must render exactly all six load/trash rows" % locale,
		)
		var last_six_row: Button = main.save_menu_panel.slot_buttons[-1]
		var last_six_trash: Button = main.save_menu_panel.trash_buttons[-1]
		main.save_menu_panel.back_button.grab_focus()
		await _push_physical_key(main, tree, KEY_UP)
		_expect(
			main.get_viewport().gui_get_focus_owner() == last_six_row
			and last_six_row.focus_neighbor_right == last_six_trash.get_path()
			and last_six_trash.focus_neighbor_left == last_six_row.get_path(),
			"%s keyboard Up from Back must reach the sixth row with Trash horizontally reachable" % locale,
		)
		await _push_physical_key(main, tree, KEY_RIGHT)
		_expect(
			main.get_viewport().gui_get_focus_owner() == last_six_trash,
			"%s keyboard Right from the sixth row must reach its Trash action" % locale,
		)
		await _push_physical_key(main, tree, KEY_LEFT)
		_expect(
			main.get_viewport().gui_get_focus_owner() == last_six_row,
			"%s keyboard Left from Trash must return to the sixth row" % locale,
		)
		main.save_menu_panel.back_button.grab_focus()
		await _push_gamepad(main, tree, JOY_BUTTON_DPAD_UP)
		_expect(
			main.get_viewport().gui_get_focus_owner() == last_six_row,
			"%s physical D-pad Up from Back must reach the sixth row when paging is hidden" % locale,
		)
		await _push_gamepad(main, tree, JOY_BUTTON_DPAD_RIGHT)
		_expect(
			main.get_viewport().gui_get_focus_owner() == last_six_trash,
			"%s physical D-pad Right from the sixth row must reach its Trash action" % locale,
		)
		await _push_gamepad(main, tree, JOY_BUTTON_DPAD_LEFT)
		_expect(
			main.get_viewport().gui_get_focus_owner() == last_six_row,
			"%s physical D-pad Left from Trash must return to the sixth row" % locale,
		)
		main.save_menu_panel.back_button.grab_focus()
		await _push_physical_key(main, tree, KEY_DOWN)
		_expect(
			main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.slot_buttons[0],
			"%s Down from Back must wrap sensibly to the first six-row entry" % locale,
		)
		main.save_menu_panel.back_button.grab_focus()
		await _push_gamepad(main, tree, JOY_BUTTON_DPAD_DOWN)
		_expect(
			main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.slot_buttons[0],
			"%s physical D-pad Down from Back must wrap to the first six-row entry" % locale,
		)
		last_six_row.grab_focus()
		await _push_physical_key(main, tree, KEY_DOWN)
		_expect(
			main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.back_button,
			"%s Down from the sixth load row must reach Back when paging is hidden" % locale,
		)
		for diagnostic in [
			Loc.text("MSG_SAVE_WRITE_VERIFICATION_FAILED", [ERR_FILE_CORRUPT]),
			Loc.text("SAVE_MENU_DELETE_ERROR", [ERR_CANT_CREATE]),
		]:
			main.save_menu_panel.set_error(diagnostic)
			await tree.process_frame
			_expect(
				_error_banner_fits(main.save_menu_panel),
				"%s save diagnostic must fit the real 72px banner above all six rows" % locale,
			)
			main.save_menu_panel.trash_buttons[-1].grab_focus()
			await tree.process_frame
			_expect(
				main.get_viewport().gui_get_focus_owner()
				== main.save_menu_panel.trash_buttons[-1]
				and main.save_menu_panel.back_button.visible
				and not main.save_menu_panel.previous_button.visible
				and not main.save_menu_panel.next_button.visible,
				"%s six-row diagnostics must retain trash focus and one-page Back semantics" % locale,
			)
		main.save_menu_panel.set_error("")
		var corrupt_index := -1
		for index in range(main.save_menu_panel.slots.size()):
			if main.save_menu_panel.slots[index].get("slot_id") == corrupt_id:
				corrupt_index = index
				break
		_expect(corrupt_index >= 0, "Corrupt list row must remain visible in %s" % locale)
		if corrupt_index >= 0:
			main.save_menu_panel.page = floori(
				float(corrupt_index) / float(main.save_menu_panel.PAGE_SIZE),
			)
			main.save_menu_panel._rebuild_slot_buttons()
			main.save_menu_panel._refresh_state()
			var local_index: int = (
				corrupt_index - main.save_menu_panel.page * main.save_menu_panel.PAGE_SIZE
			)
			_expect(
				main.save_menu_panel.slot_buttons[local_index].disabled
				and main.save_menu_panel.slot_buttons[local_index].tooltip_text
				== Loc.text("SAVE_MENU_CORRUPT_TOOLTIP", [
					Loc.text("SAVE_MENU_CORRUPT_NAME"), ERR_FILE_CORRUPT,
				]),
				"RU/EN corrupt row must be disabled and name confirmed error 16 without inventing a field",
			)
	Loc.set_locale("ru")
	main.queue_free()
	await tree.process_frame


func _test_lifetime_counter() -> void:
	var state := RunState.new()
	state.configure_character("Lifetime", GameRules.default_attributes())
	state.loadout = {"talisman": "soul_locket"}
	_expect(state.add_souls(3) == 4 and state.lifetime_souls_earned == 4, "Soul bonuses must contribute to the lifetime earned counter")
	state.carried_souls = 0
	_expect(state.lifetime_souls_earned == 4, "Spending or clearing current souls must not reduce lifetime earnings")
	var restored := RunState.new()
	_expect(restored.restore_save_data(state.to_save_data()) and restored.lifetime_souls_earned == 4, "Lifetime earnings must roundtrip")
	var legacy := RunState.new()
	_expect(
		legacy.restore_save_data({"character_name": "Legacy", "banked_souls": 7, "carried_souls": 3, "absorbed_souls": 10})
		and legacy.lifetime_souls_earned == 20,
		"Legacy lifetime earnings must use the documented lower-bound baseline",
	)


func _test_atomic_backup_and_listing() -> void:
	var numeric_id := SaveSystem.save_slot(_state("Numeric", 1), "slot-123", "overwrite", SLOTS_PATH, 50)
	_expect(bool(numeric_id.get("ok", false)), "Opaque slot ids must allow safe ASCII digits and punctuation")
	var generated := SaveSystem.save_slot(_state("Generated", 1), "", "overwrite", SLOTS_PATH, 60)
	_expect(
		bool(generated.get("ok", false)) and not String(generated.get("slot_id", "")).is_empty(),
		"The default hexadecimal id generator must publish a valid slot without an injected factory",
	)
	var first := _state("First", 5)
	first.absorbed_souls = int(GameRules.FORMS.revenant.threshold)
	first.lifetime_souls_earned += first.absorbed_souls
	first.current_form_id = "revenant"
	first.highest_unlocked_form_index = GameRules.FORM_ORDER.find("revenant")
	first.skill_levels.nervous_system = 1
	first.skill_levels.dash = 1
	first.skill_levels.double_attack = 1
	first.ability_cooldowns = {"dash": 13, "double_attack": 2}
	first.active_statuses = {"rested": {"remaining_turns": 177, "temporary_hp": 3}}
	var first_save := SaveSystem.save_slot(first, "slot-a", "overwrite", SLOTS_PATH, 100)
	_expect(bool(first_save.get("ok", false)), "A deterministic slot must save")
	first.add_souls(4)
	var second_save := SaveSystem.save_slot(first, "slot-a", "overwrite", SLOTS_PATH, 200)
	_expect(bool(second_save.get("ok", false)), "Overwriting a slot must atomically publish the new envelope")
	_expect(FileAccess.file_exists(SLOTS_PATH + "/slot-a.json.bak"), "An overwritten primary must retain a same-directory backup")
	_write_text(SLOTS_PATH + "/slot-a.json", "{broken")
	var recovered := SaveSystem.load_slot("slot-a", SLOTS_PATH)
	var recovered_state := RunState.new()
	var recovered_state_ok := recovered_state.restore_save_data(recovered.get("state", {}))
	_expect(
		bool(recovered.get("ok", false)) and bool(recovered.get("recovered_from_backup", false))
		and int((recovered.get("state", {}) as Dictionary).get("lifetime_souls_earned", 0)) == 53
		and recovered_state_ok
		and recovered_state.ability_cooldowns == {"dash": 13, "double_attack": 2}
		and recovered_state.active_statuses == {
			"rested": {"remaining_turns": 177, "temporary_hp": 3},
		},
		"A corrupt primary must fall back to exact validated status and cooldown state",
	)
	_write_text(SLOTS_PATH + "/ignored.json.tmp", JSON.stringify({"metadata": {"slot_id": "ignored"}}))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOTS_PATH + "/slot-a.json"))
	var other := _state("Other", 2)
	_expect(bool(SaveSystem.save_slot(other, "slot-b", "history", SLOTS_PATH, 100).get("ok", false)), "A second deterministic slot must save")
	var slots := SaveSystem.list_slots(SLOTS_PATH)
	_expect(slots.size() == 4, "Listing must include unique primary/backup-only slots and ignore temporary files")
	if slots.size() == 4:
		_expect(
			String(slots[0].get("slot_id", "")) == "slot-a" and String(slots[1].get("slot_id", "")) == "slot-b",
			"Slot ordering must be newest-first with a stable id tie-break",
		)
		_expect(bool(slots[0].get("recovered_from_backup", false)), "A backup-only power-loss slot must remain visible and marked recovered")
	_expect(String(SaveSystem.latest_slot(SLOTS_PATH).get("slot_id", "")) == "slot-a", "Latest valid slot must use deterministic ordering")

	var fault_state := _state("Before Fault", 3)
	_expect(bool(SaveSystem.save_slot(fault_state, "fault-slot", "overwrite", SLOTS_PATH, 250).get("ok", false)), "Fault fixture must save")
	fault_state.character_name = "After Fault"
	var failed := SaveSystem.save_slot(
		fault_state, "fault-slot", "overwrite", SLOTS_PATH, 350, Callable(), {},
		func(stage: String) -> bool: return stage == "after_primary_backup",
	)
	var restored := SaveSystem.load_slot("fault-slot", SLOTS_PATH)
	_expect(
		not bool(failed.get("ok", true)) and bool(restored.get("ok", false))
		and String((restored.get("state", {}) as Dictionary).get("character_name", "")) == "Before Fault"
		and int((restored.get("metadata", {}) as Dictionary).get("updated_at", 0)) == 250,
		"A deterministic failure after rotation must restore and list the prior valid primary",
	)
	_expect(SaveSystem.list_slots(SLOTS_PATH).any(func(row: Dictionary) -> bool: return row.get("slot_id") == "fault-slot"), "A rollback-restored slot must remain listable")


func _test_legacy_import_once() -> void:
	_write_text(LEGACY_PATH, JSON.stringify({
		"version": 1,
		"state": {"character_name": "Imported", "banked_souls": 11, "carried_souls": 2, "absorbed_souls": 20},
	}))
	var old_bytes := FileAccess.get_file_as_string(LEGACY_PATH)
	var rejected := SaveSystem.import_legacy_once(LEGACY_PATH, SLOTS_PATH, 299, func() -> String: return "old-rejected")
	_expect(not rejected.get("imported", false) and FileAccess.get_file_as_string(LEGACY_PATH) == old_bytes, "Old test saves stay untouched and never auto-import")
	_write_text(LEGACY_PATH, JSON.stringify({
		"version": SaveSystem.SAVE_VERSION,
		"kind": "state_only",
		"state": _valid_state_only_data("Imported", 11, 2, 24),
	}))
	var collision_dir := ROOT + "/legacy-collision-slots"
	var occupied := SaveSystem.save_slot(_state("Keep", 2), "legacy-collision", "overwrite", collision_dir, 299)
	_expect(bool(occupied.get("ok", false)), "Legacy collision fixture must publish an occupied family")
	var occupied_path := collision_dir + "/legacy-collision.json"
	var occupied_bytes := FileAccess.get_file_as_bytes(occupied_path)
	var collision_ids := ["legacy-collision", "legacy-free"]
	var collision_import := SaveSystem.import_legacy_once(
		LEGACY_PATH, collision_dir, 300, func() -> String: return collision_ids.pop_front(),
	)
	_expect(
		bool(collision_import.get("ok", false)) and bool(collision_import.get("imported", false))
		and collision_import.get("slot_id", "") == "legacy-free"
		and FileAccess.get_file_as_bytes(occupied_path) == occupied_bytes,
		"Automatic legacy import must retry a fully occupied family without overwriting it",
	)
	var imported := SaveSystem.import_legacy_once(LEGACY_PATH, SLOTS_PATH, 300, func() -> String: return "legacy-slot")
	_expect(bool(imported.get("ok", false)) and bool(imported.get("imported", false)), "An explicit current state-only helper can import once")
	var imported_load := SaveSystem.load_slot("legacy-slot", SLOTS_PATH)
	_expect(
		bool(imported_load.get("ok", false))
		and int((imported_load.get("state", {}) as Dictionary).get("lifetime_souls_earned", 0)) == 37,
		"Legacy import must preserve state and establish its lower-bound lifetime total",
	)
	var count_before := SaveSystem.list_slots(SLOTS_PATH).size()
	var repeated := SaveSystem.import_legacy_once(LEGACY_PATH, SLOTS_PATH, 400, func() -> String: return "duplicate")
	_expect(
		bool(repeated.get("ok", false)) and not bool(repeated.get("imported", true))
		and SaveSystem.list_slots(SLOTS_PATH).size() == count_before,
		"Legacy import must not duplicate a save on later startups",
	)

	# The single-file boundary is intentionally state-only. A structurally valid
	# full-run envelope must never have its dungeon snapshot stripped and restored
	# through the permissive setup helper as a base save.
	var full_legacy_path := ROOT + "/legacy-full-run.json"
	var full_legacy_slots := ROOT + "/legacy-full-run-slots"
	var full_legacy_state := _state("Full legacy rejection", 3)
	full_legacy_state.current_floor = 99
	var full_legacy_floor: Dictionary = FloorGenerator.new().generate(99, 160901, 0.0)
	var full_legacy_random := RandomNumberGenerator.new()
	full_legacy_random.seed = 160901
	_write_text(full_legacy_path, JSON.stringify({
		"version": SaveSystem.SAVE_VERSION,
		"kind": "full_run",
		"state": full_legacy_state.to_snapshot_data(),
		"snapshot": Snapshot.capture(
			"dungeon", full_legacy_floor, full_legacy_floor.start, full_legacy_random,
			{"attack_memories": {}, "event_revision": 0},
		),
	}, "  ", true, true))
	var full_legacy_bytes := FileAccess.get_file_as_bytes(full_legacy_path)
	var full_legacy_import := SaveSystem.import_legacy_once(
		full_legacy_path, full_legacy_slots, 401,
		func() -> String: return "must-not-import-full-run",
	)
	_expect(
		SaveSystem.load_game(full_legacy_path).is_empty()
		and not bool(full_legacy_import.get("imported", false))
		and FileAccess.get_file_as_bytes(full_legacy_path) == full_legacy_bytes
		and SaveSystem.list_slots(full_legacy_slots).is_empty(),
		"Legacy single-file loading must reject full_run without stripping its snapshot or mutating files",
	)


func _test_failure_does_not_publish_slot() -> void:
	var invalid := SaveSystem.save_slot(_state("Invalid", 1), "../escape", "overwrite", SLOTS_PATH, 500)
	_expect(not bool(invalid.get("ok", true)), "Invalid opaque ids must fail without publishing a slot")
	_expect(not FileAccess.file_exists(ROOT + "/escape.json"), "A failed slot write must not escape its injected directory")


func _test_permanent_slot_deletion() -> void:
	var delete_dir := ROOT + "/delete-slots"
	_write_text(delete_dir + "/sibling.json", "keep")
	_write_text(delete_dir + "/.legacy-imported.json", "{\"imported\":true}")
	_write_text(delete_dir + "/target.json.tmp", "temporary")
	_write_text(delete_dir + "/target.json.bak", "backup")
	_write_text(delete_dir + "/target.json", "primary")
	var deleted := SaveSystem.delete_slot("target", delete_dir)
	_expect(
		bool(deleted.get("ok", false)) and bool(deleted.get("removed", false))
		and (deleted.get("removed_stages", []) as Array) == ["temporary", "backup", "primary"],
		"Permanent deletion must remove the exact temporary, backup and primary family in fail-fast order",
	)
	_expect(
		FileAccess.file_exists(delete_dir + "/sibling.json")
		and FileAccess.file_exists(delete_dir + "/.legacy-imported.json"),
		"Permanent deletion must preserve sibling slots and the legacy-import marker",
	)
	var missing := SaveSystem.delete_slot("target", delete_dir)
	_expect(
		bool(missing.get("ok", false)) and not bool(missing.get("removed", true)),
		"Deleting an already absent valid slot must be idempotent",
	)
	var invalid := SaveSystem.delete_slot("../sibling", delete_dir)
	_expect(
		not bool(invalid.get("ok", true)) and int(invalid.get("error", OK)) == ERR_INVALID_PARAMETER
		and FileAccess.file_exists(delete_dir + "/sibling.json"),
		"Traversal ids must fail validation without touching the filesystem",
	)
	_write_text(delete_dir + "/backup-only.json.bak", "backup")
	_expect(
		bool(SaveSystem.delete_slot("backup-only", delete_dir).get("ok", false))
		and not FileAccess.file_exists(delete_dir + "/backup-only.json.bak"),
		"Backup-only families must be deletable",
	)
	_write_text(delete_dir + "/corrupt.json", "{broken")
	_write_text(delete_dir + "/corrupt.json.bak", "valid-enough-for-delete")
	_expect(
		bool(SaveSystem.delete_slot("corrupt", delete_dir).get("ok", false)),
		"A corrupt primary with a backup must still be permanently deletable",
	)
	for failed_recovery_stage in ["primary", "backup"]:
		var recovery_id := "recoverable-" + String(failed_recovery_stage)
		var recovery_state := _state("Recoverable %s" % failed_recovery_stage, 7)
		_expect(
			bool(SaveSystem.save_slot(recovery_state, recovery_id, "overwrite", delete_dir, 800).get("ok", false))
			and bool(SaveSystem.save_slot(recovery_state, recovery_id, "overwrite", delete_dir, 801).get("ok", false)),
			"Recoverable deletion fixture must publish a valid primary and backup",
		)
		_write_text(delete_dir + "/" + recovery_id + ".json", "{broken")
		var failed_recovery := SaveSystem.delete_slot(
			recovery_id, delete_dir,
			func(stage: String) -> bool: return stage == failed_recovery_stage,
		)
		var recovery_remaining: Dictionary = failed_recovery.get("remaining", {})
		_expect(
			not bool(failed_recovery.get("ok", true))
			and bool(recovery_remaining.get("backup", false))
			and SaveSystem.list_slots(delete_dir).any(
				func(row: Dictionary) -> bool: return row.get("slot_id") == recovery_id
			),
			"A %s fault must preserve the valid backup as a visible retry source" % failed_recovery_stage,
		)
		_expect(
			bool(SaveSystem.delete_slot(recovery_id, delete_dir).get("ok", false))
			and not SaveSystem.list_slots(delete_dir).any(
				func(row: Dictionary) -> bool: return row.get("slot_id") == recovery_id
			),
			"Retry after recoverable %s failure must remove the exact family" % failed_recovery_stage,
		)
	for failed_stage in ["temporary", "backup", "primary"]:
		var slot_id: String = "fault-" + String(failed_stage)
		var base: String = delete_dir + "/" + slot_id + ".json"
		_write_text(base + ".tmp", "temporary")
		_write_text(base + ".bak", "backup")
		_write_text(base, "primary")
		var failed := SaveSystem.delete_slot(
			slot_id, delete_dir,
			func(stage: String) -> bool: return stage == failed_stage,
		)
		var remaining: Dictionary = failed.get("remaining", {})
		var expected_remaining := {
			"temporary": failed_stage == "temporary",
			"backup": failed_stage != "primary",
			"primary": true,
		}
		_expect(
			not bool(failed.get("ok", true)) and String(failed.get("error_stage", "")) == failed_stage
			and remaining == expected_remaining,
			"Injected %s deletion failure must report the authoritative remaining family" % failed_stage,
		)
		_expect(
			bool(SaveSystem.delete_slot(slot_id, delete_dir).get("ok", false)),
			"Retry after an injected %s failure must safely finish deletion" % failed_stage,
		)
	var imported_dir := ROOT + "/delete-imported"
	var imported_legacy := ROOT + "/delete-imported-legacy.json"
	_write_text(imported_legacy, JSON.stringify({
		"version": SaveSystem.SAVE_VERSION,
		"kind": "state_only",
		"state": _valid_state_only_data("Imported Delete", 0, 0, 0),
	}))
	var imported := SaveSystem.import_legacy_once(
		imported_legacy, imported_dir, 700, func() -> String: return "imported-delete",
	)
	_expect(bool(imported.get("imported", false)), "Imported deletion fixture must import once")
	_expect(bool(SaveSystem.delete_slot("imported-delete", imported_dir).get("ok", false)), "Imported slots must be deletable")
	var reimport := SaveSystem.import_legacy_once(
		imported_legacy, imported_dir, 701, func() -> String: return "must-not-return",
	)
	_expect(
		bool(reimport.get("ok", false)) and not bool(reimport.get("imported", true))
		and SaveSystem.list_slots(imported_dir).is_empty(),
		"Deleting an imported slot must preserve its marker and never re-import the legacy save",
	)


func _test_main_and_panel(_tree: SceneTree) -> void:
	var tree := _tree
	var ui_slots := ROOT + "/ui-slots"
	var newest := _state("Newest Hero", 15)
	_expect(bool(SaveSystem.save_slot(newest, "newest", "overwrite", ui_slots, 900).get("ok", false)), "Startup fixture slot must save")
	for index in range(1, 8):
		_expect(bool(SaveSystem.save_slot(_state("Page Hero %d" % index, index), "page-%d" % index, "history", ui_slots, 807 - index).get("ok", false)), "Pagination fixture %d must save" % index)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = true
	main.audio_playback_enabled = false
	main.save_slots_directory = ui_slots
	main.settings_path = ROOT + "/settings.cfg"
	main.legacy_save_path = ROOT + "/missing-legacy.json"
	var ids := ["single", "history-a", "history-b", "history-c"]
	var times := [1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800]
	main.save_id_factory = func() -> String: return String(ids.pop_front())
	main.save_time_provider = func() -> int: return int(times.pop_front()) if not times.is_empty() else 1900
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	_expect(
		main.screen == main.Screen.STARTUP and main.save_menu_panel.visible
		and main.state.character_name.is_empty(),
		"Startup must show Continue/New/Load without automatically loading a character",
	)
	_expect(
		not main.save_menu_panel.continue_button.disabled
		and not main.save_menu_panel.load_button.disabled
		and main.save_menu_panel.settings_button.visible
		and main.save_menu_panel.exit_button.visible
		and main.save_menu_panel.new_game_button.focus_mode == Control.FOCUS_ALL,
		"Startup must expose all five unified actions with deterministic focus",
	)
	var startup_slots: Array[Dictionary] = []
	startup_slots.append_array(main.save_menu_panel.slots.duplicate(true))
	var empty_slots: Array[Dictionary] = []
	main.save_menu_panel.set_slots(empty_slots)
	main.save_menu_panel.show_startup()
	await tree.process_frame
	_expect(
		main.save_menu_panel.continue_button.visible
		and main.save_menu_panel.continue_button.disabled
		and main.save_menu_panel.load_button.visible
		and main.save_menu_panel.load_button.disabled
		and main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.new_game_button
		and main.save_menu_panel.subtitle_label.text == Loc.text("SAVE_MENU_EMPTY_SUBTITLE"),
		"Empty startup must keep Continue/Load visible disabled, focus New and explain the empty state",
	)
	main.save_menu_panel.set_slots(startup_slots)
	main.save_menu_panel.show_startup()
	for locale in ["ru", "en"]:
		Loc.set_locale(locale)
		main._apply_locale()
		main.save_menu_panel.show_load_list()
		_expect(
			not main.save_menu_panel.slot_buttons.is_empty()
			and main.save_menu_panel.slot_buttons[0].tooltip_text.contains("Newest Hero")
			and main.save_menu_panel.slot_buttons[0].tooltip_text.contains("15"),
			"RU/EN load rows must show the full character name, local date and lifetime souls",
		)
		_expect(main.save_menu_panel.next_button.visible and main.save_menu_panel.page_label.text.contains("1 / 2"), "RU/EN load lists must expose localized pagination")
		main.save_menu_panel.show_startup()
	Loc.set_locale("ru")
	main._apply_locale()
	await tree.process_frame

	# Keyboard and gamepad directions move startup focus; mouse opens the list.
	main.save_menu_panel.continue_button.grab_focus()
	await _push_physical_key(main, tree, KEY_DOWN)
	_expect(main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.new_game_button, "Keyboard arrows must navigate startup controls")
	main.save_menu_panel.continue_button.grab_focus()
	await _push_gamepad(main, tree, JOY_BUTTON_DPAD_DOWN)
	_expect(main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.new_game_button, "Gamepad D-pad must navigate startup controls")
	await _click(main, tree, main.save_menu_panel.load_button.get_global_rect().get_center())
	_expect(main.save_menu_panel.list_mode, "Mouse input must open the explicit save list")
	main.save_menu_panel.slot_buttons[-1].grab_focus()
	await _push_physical_key(main, tree, KEY_DOWN)
	_expect(main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.next_button, "Keyboard focus must reach the next-page control")
	main.save_menu_panel.slot_buttons[-1].grab_focus()
	await _push_gamepad(main, tree, JOY_BUTTON_DPAD_DOWN)
	_expect(main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.next_button, "Gamepad focus must reach the next-page control")
	main.save_menu_panel.back_button.grab_focus()
	await _push_physical_key(main, tree, KEY_UP)
	_expect(
		main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.next_button,
		"Keyboard Up from Back must preserve the enabled Next target on page one",
	)
	main.save_menu_panel.back_button.grab_focus()
	await _push_gamepad(main, tree, JOY_BUTTON_DPAD_UP)
	_expect(
		main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.next_button,
		"Physical D-pad Up from Back must preserve the enabled Next target on page one",
	)
	await _click(main, tree, main.save_menu_panel.next_button.get_global_rect().get_center())
	await tree.process_frame
	_expect(main.save_menu_panel.page == 1 and main.save_menu_panel.slot_buttons.size() == 2, "Mouse pagination must expose the seventh and eighth saves")
	main.save_menu_panel.back_button.grab_focus()
	await _push_physical_key(main, tree, KEY_UP)
	_expect(
		main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.previous_button,
		"Keyboard Up from Back must preserve the enabled Previous target on the final page",
	)
	main.save_menu_panel.back_button.grab_focus()
	await _push_gamepad(main, tree, JOY_BUTTON_DPAD_UP)
	_expect(
		main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.previous_button,
		"Physical D-pad Up from Back must preserve the enabled Previous target on the final page",
	)
	_expect(main.save_menu_panel.slot_buttons[0].tooltip_text.contains("Page Hero 6") and main.save_menu_panel.slot_buttons[1].tooltip_text.contains("Page Hero 7"), "Second page must retain deterministic slot order")
	main.save_menu_panel.slot_buttons[0].pressed.emit()
	_expect(main.state.character_name == "Page Hero 6", "The seventh save must be loadable from page two")
	main.screen = main.Screen.STARTUP
	main.save_menu_panel.show_load_list()
	main.save_menu_panel._change_page(1)
	main.save_menu_panel.slot_buttons[1].pressed.emit()
	_expect(main.state.character_name == "Page Hero 7", "The eighth save must be loadable from page two")
	main.screen = main.Screen.STARTUP
	main.main_menu_open = true
	main.save_menu_panel.show_startup()
	main.save_menu_panel.show_load_list()
	var load_signals: Array[String] = []
	var delete_signals: Array[String] = []
	main.save_menu_panel.load_requested.connect(func(slot_id: String) -> void: load_signals.append(slot_id))
	main.save_menu_panel.delete_requested.connect(func(slot_id: String) -> void: delete_signals.append(slot_id))
	_expect(
		main.save_menu_panel.slot_buttons[0].size == Vector2(460, 52)
		and main.save_menu_panel.trash_buttons[0].size == Vector2(52, 52)
		and is_equal_approx(
			main.save_menu_panel.trash_buttons[0].position.x
			- (main.save_menu_panel.slot_buttons[0].position.x + 460.0), 8.0,
		),
		"Every save row must retain a 460x52 load control, 8px gap and 52x52 trash target",
	)
	main.save_menu_panel.slot_buttons[0].grab_focus()
	await tree.process_frame
	await _panel_action(main.save_menu_panel, tree, "ui_right")
	_expect(
		main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.trash_buttons[0],
		"Right navigation must move from Load to Trash in the same row",
	)
	await _panel_action(main.save_menu_panel, tree, "ui_down")
	_expect(
		main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.trash_buttons[1],
		"Down navigation in the delete column must retain that column",
	)
	var state_before_trash = main.state
	await _click(main, tree, main.save_menu_panel.trash_buttons[0].get_global_rect().get_center())
	_expect(
		main.save_menu_panel.delete_modal_open and main.state == state_before_trash
		and load_signals.is_empty()
		and main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.delete_no_button,
		"Mouse/touch Trash must open an input-blocking modal, never load, and default focus to No",
	)
	await _panel_action(main.save_menu_panel, tree, "ui_right")
	_expect(main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.delete_yes_button, "Modal Right must move only from No to Yes")
	await _panel_action(main.save_menu_panel, tree, "ui_left")
	_expect(main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.delete_no_button, "Modal Left must return to the safe No action")
	var delete_signal_count_before_no := delete_signals.size()
	await _click(main, tree, main.save_menu_panel.delete_no_button.get_global_rect().get_center())
	for _frame in range(6):
		await tree.process_frame
	_expect(not main.save_menu_panel.delete_modal_open, "A real mouse click on No must close the modal")
	_expect(main.save_menu_panel.list_mode, "A real mouse No must preserve list mode")
	_expect(main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.trash_buttons[0], "A real mouse No must restore Trash focus")
	_expect(delete_signals.size() == delete_signal_count_before_no and load_signals.is_empty(), "A real mouse No must not delete or load")
	await _click(main, tree, main.save_menu_panel.trash_buttons[0].get_global_rect().get_center())
	await _push_gamepad(main, tree, JOY_BUTTON_B)
	_expect(
		not main.save_menu_panel.delete_modal_open
		and main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.trash_buttons[0],
		"Physical gamepad B must cancel deletion and restore the original Trash focus",
	)
	await _touch(main, tree, main.save_menu_panel.trash_buttons[0].get_global_rect().get_center())
	_expect(main.save_menu_panel.delete_modal_open and load_signals.is_empty(), "ScreenTouch on Trash must open the same modal without loading")
	await _touch(main, tree, main.save_menu_panel.delete_no_button.get_global_rect().get_center())
	_expect(not main.save_menu_panel.delete_modal_open, "ScreenTouch on No must close the modal")
	_expect(main.save_menu_panel.list_mode and main.save_menu_panel.visible, "ScreenTouch modal cancellation must keep the save list open")
	_expect(main.active_save_slot_id == "page-7" and main.state == state_before_trash, "ScreenTouch modal cancellation must not load another slot")
	_expect(load_signals.is_empty(), "ScreenTouch modal cancellation must not emit Load")
	main.active_save_slot_id = "page-7"
	main.screen = main.Screen.STARTUP
	main.save_menu_panel.set_slots(SaveSystem.list_slots(ui_slots))
	main.save_menu_panel.set_active_slot_id("page-7")
	main.save_menu_panel.show_startup()
	main.save_menu_panel.show_load_list()
	main.save_menu_panel._change_page(1)
	await tree.process_frame
	_expect(main.save_menu_panel.page == 1 and main.save_menu_panel.trash_buttons.size() == 2, "Delete paging fixture must start with two rows on page two")
	main.save_menu_panel.trash_buttons[1].pressed.emit()
	await tree.process_frame
	_expect(
		main.save_menu_panel.delete_modal_open
		and main.save_menu_panel.delete_modal_body.text.contains(Loc.text("SAVE_MENU_DELETE_ACTIVE_WARNING")),
		"Deleting the active slot must explicitly preserve and explain the in-memory session",
	)
	main.save_menu_panel.delete_yes_button.pressed.emit()
	main.save_menu_panel.delete_yes_button.pressed.emit()
	await tree.process_frame
	_expect(delete_signals.count("page-7") == 1, "Yes must emit active deletion exactly once (signals: %s)" % [delete_signals])
	_expect(not FileAccess.file_exists(ui_slots + "/page-7.json"), "Confirmed active deletion must remove its primary")
	_expect(
		main.save_menu_panel.page == 1 and main.save_menu_panel.slot_buttons.size() == 1,
		"Confirmed deletion must keep the remaining row on page two",
	)
	main.save_menu_panel.trash_buttons[0].pressed.emit()
	main.save_menu_panel.delete_yes_button.pressed.emit()
	await tree.process_frame
	_expect(
		main.save_menu_panel.page == 0 and main.save_menu_panel.slot_buttons.size() == 6
		and not FileAccess.file_exists(ui_slots + "/page-6.json"),
		"Deleting the sole row on page two must clamp back to page zero",
	)
	await _push_action(main, tree, "ui_cancel")
	_expect(not main.save_menu_panel.list_mode, "Esc/B action must return one layer from the load list")

	var timestamp_before := int(SaveSystem.latest_slot(ui_slots).get("updated_at", 0))
	main._on_save_slot_load_requested("newest")
	_expect(main.screen == main.Screen.BASE and main.state.character_name == "Newest Hero", "Continue/load must restore the selected slot")
	_expect(
		int(SaveSystem.latest_slot(ui_slots).get("updated_at", 0)) == timestamp_before,
		"Loading a slot must not immediately resave it",
	)
	var in_memory_state = main.state
	var menu_timestamp_before := int(
		(SaveSystem.load_slot("newest", ui_slots).get("metadata", {}) as Dictionary).get("updated_at", 0)
	)
	main._show_character()
	main._open_main_menu()
	_expect(
		main.main_menu_open and main.save_menu_panel.visible
		and main.save_menu_panel.in_game_context
		and main.save_menu_panel.continue_button.text == Loc.text("SAVE_MENU_RESUME")
		and int(
			(SaveSystem.load_slot("newest", ui_slots).get("metadata", {}) as Dictionary).get("updated_at", 0)
		) == menu_timestamp_before,
		"The same opaque five-action menu must open over an in-memory game",
	)
	main.save_menu_panel.continue_button.pressed.emit()
	_expect(
		not main.main_menu_open and main.state == in_memory_state and main.screen == main.Screen.BASE,
		"In-game Continue must resume the exact in-memory state without save/load",
	)
	main._open_main_menu()
	main.save_menu_panel.settings_button.grab_focus()
	main.save_menu_panel.settings_button.pressed.emit()
	_expect(
		main.settings_open and not main.save_menu_panel.visible
		and main.settings_new_game_button.visible
		and not main.settings_exit_button.visible,
		"Settings opened from the main menu must replace only the top menu layer",
	)
	main._close_settings()
	await tree.process_frame
	_expect(
		main.main_menu_open
		and main.save_menu_panel.visible
		and not main.settings_open
		and main.save_menu_panel.settings_button.has_focus(),
		"Settings Back must return to the exact main-menu trigger rather than gameplay",
	)
	main.save_menu_panel.show_load_list()
	main.save_menu_panel.back_button.pressed.emit()
	_expect(
		main.save_menu_panel.visible and not main.save_menu_panel.list_mode
		and main.save_menu_panel.in_game_context
		and main.save_menu_panel.continue_button.text == Loc.text("SAVE_MENU_RESUME"),
		"Mouse/touch Back from the in-game load list must return exactly one menu layer",
	)
	main._resume_from_main_menu()

	# Unsafe siblings load read-only, then Main branches to a fresh family without
	# touching the valid primary, incompatible backup, or interrupted temporary.
	for unsafe_case in ["backup", "temporary"]:
		var unsafe_id: String = "unsafe-" + str(unsafe_case)
		_expect(
			bool(SaveSystem.save_slot(_state("Unsafe sibling", 4), unsafe_id, "overwrite", ui_slots, 950).get("ok", false)),
			"Unsafe sibling fixture must publish: %s" % unsafe_case,
		)
		var unsafe_path := ui_slots.path_join(unsafe_id + ".json")
		var sibling_path := unsafe_path + (".bak" if unsafe_case == "backup" else ".tmp")
		_write_text(sibling_path, "{\"version\":15,\"preserve\":\"%s\"}" % unsafe_case)
		var unsafe_primary_bytes := FileAccess.get_file_as_bytes(unsafe_path)
		var unsafe_sibling_bytes := FileAccess.get_file_as_bytes(sibling_path)
		main._on_save_slot_load_requested(unsafe_id)
		_expect(
			main.active_save_slot_id == unsafe_id and main.active_save_write_locked,
			"Main must retain but write-lock a loaded family with an unsafe %s" % unsafe_case,
		)
		var branch_id: String = "branch-from-" + str(unsafe_case)
		var branch_factory_before: Callable = main.save_id_factory
		main.save_id_factory = func() -> String: return branch_id
		_expect(
			main._save_game_at_base("update") and main.active_save_slot_id == branch_id
			and not main.active_save_write_locked
			and FileAccess.get_file_as_bytes(unsafe_path) == unsafe_primary_bytes
			and FileAccess.get_file_as_bytes(sibling_path) == unsafe_sibling_bytes
			and bool(SaveSystem.load_slot(branch_id, ui_slots).get("ok", false)),
			"A write-locked %s family must branch safely and preserve every original byte" % unsafe_case,
		)
		main.save_id_factory = branch_factory_before

	# Production defaults must create a valid hexadecimal id without test factories.
	main.state = _state("Default Id Hero", 2)
	main.active_save_slot_id = ""
	var injected_factory: Callable = main.save_id_factory
	main.save_id_factory = Callable()
	_expect(main._save_game_at_base("create") and not main.active_save_slot_id.is_empty(), "Main's first save must work with the default id generator")
	_expect(bool(SaveSystem.load_slot(main.active_save_slot_id, ui_slots).get("ok", false)), "Main's default generated id must be loadable")
	main.save_id_factory = injected_factory

	# Checked policy overwrites one slot; history policy snapshots only meaningful returns.
	main.state = _state("Policy Hero", 3)
	main.active_save_slot_id = ""
	main.save_policy_overwrite = true
	_expect(main._save_game_at_base("create"), "Checked overwrite policy must create its active slot")
	var single_id: String = main.active_save_slot_id
	var count_after_single := SaveSystem.list_slots(ui_slots).size()
	main.state.add_souls(2)
	_expect(main._save_game_at_base("safe_return") and main.active_save_slot_id == single_id, "Checked policy must overwrite the same slot on meaningful returns")
	_expect(SaveSystem.list_slots(ui_slots).size() == count_after_single, "Checked policy must not grow slot history")

	main.active_save_slot_id = ""
	main.save_policy_overwrite = false
	_expect(main._save_game_at_base("create"), "History policy must create an initial snapshot")
	var history_a: String = main.active_save_slot_id
	var history_count := SaveSystem.list_slots(ui_slots).size()
	main.state.base_level = 7
	_expect(main._save_game_at_base("update") and main.active_save_slot_id == history_a, "Base purchases must update the active history snapshot")
	_expect(
		SaveSystem.list_slots(ui_slots).size() == history_count
		and int((SaveSystem.load_slot(history_a, ui_slots).get("state", {}) as Dictionary).get("base_level", 0)) == 7,
		"Base updates must not create history entries and must persist their new state",
	)
	_expect(main._save_game_at_base("death") and main.active_save_slot_id != history_a, "Death return must create a fresh history snapshot")
	_expect(SaveSystem.list_slots(ui_slots).size() == history_count + 1, "Meaningful history return must add exactly one snapshot")

	# Save failure is localized and never advances/publishes a generated active id.
	main.active_save_slot_id = ""
	main.save_id_factory = func() -> String: return "unpublished-failure"
	main.save_fault_injector = func(stage: String) -> bool: return stage == "after_primary_backup"
	_expect(not main._save_game_at_base("death"), "Injected write fault must surface a save failure")
	_expect(
		main.active_save_slot_id.is_empty()
		and not main.last_save_error.is_empty()
		and not FileAccess.file_exists(ui_slots.path_join("unpublished-failure.json"))
		and not FileAccess.file_exists(ui_slots.path_join("unpublished-failure.json.tmp")),
		"Failed saves must not advance active ids or publish bytes and must expose localized feedback",
	)
	main.save_fault_injector = Callable()
	main.save_id_factory = func() -> String: return String(ids.pop_front())

	# A rotated-write failure must not advance an active id or its published timestamp.
	main.active_save_slot_id = "newest"
	var active_before: String = main.active_save_slot_id
	var active_timestamp_before := int((SaveSystem.load_slot(active_before, ui_slots).get("metadata", {}) as Dictionary).get("updated_at", 0))
	main.save_fault_injector = func(stage: String) -> bool: return stage == "after_primary_backup"
	_expect(not main._save_game_at_base("update"), "Injected post-rotation failure must surface through Main")
	_expect(
		main.active_save_slot_id == active_before
		and int((SaveSystem.load_slot(active_before, ui_slots).get("metadata", {}) as Dictionary).get("updated_at", 0)) == active_timestamp_before,
		"A failed atomic update must not advance Main's active id or published timestamp",
	)
	main.save_fault_injector = Callable()

	# Deleting the active disk slot detaches, preserves memory, and blocks immediate exit autosave.
	var active_delete_state := _state("Active Delete Hero", 21)
	_expect(bool(SaveSystem.save_slot(active_delete_state, "active-delete", "overwrite", ui_slots, 3000).get("ok", false)), "Active deletion fixture must save")
	main._on_save_slot_load_requested("active-delete")
	var exact_in_memory_state = main.state
	main._open_main_menu()
	main.save_menu_panel.show_load_list()
	main.save_menu_panel.trash_buttons[0].pressed.emit()
	_expect(
		main.save_menu_panel.delete_modal_body.text.contains(Loc.text("SAVE_MENU_DELETE_ACTIVE_WARNING")),
		"The active-slot modal must explain detached in-memory behavior",
	)
	main.save_menu_panel.delete_yes_button.pressed.emit()
	await tree.process_frame
	_expect(
		main.state == exact_in_memory_state and main.active_save_slot_id.is_empty()
		and main.active_save_detached_by_delete and not main.active_save_detached_can_resave
		and not FileAccess.file_exists(ui_slots + "/active-delete.json"),
		"Deleting the active slot must preserve exact RunState and mark the session detached",
	)
	var detached_count := SaveSystem.list_slots(ui_slots).size()
	var detached_exit_calls: Array[int] = []
	main.exit_request_hook = func() -> void: detached_exit_calls.append(1)
	main._request_exit()
	_expect(
		detached_exit_calls.size() == 1 and SaveSystem.list_slots(ui_slots).size() == detached_count
		and not FileAccess.file_exists(ui_slots + "/active-delete.json"),
		"Exiting from the detached base menu must not recreate the deleted save",
	)
	main._resume_from_main_menu()
	_expect(
		main.active_save_detached_by_delete and main.active_save_detached_can_resave
		and main.state == exact_in_memory_state,
		"Explicit Continue must re-arm only the next legitimate base save without saving immediately",
	)
	var prior_factory: Callable = main.save_id_factory
	var prior_time_provider: Callable = main.save_time_provider
	main.save_id_factory = func() -> String: return "fresh-after-delete"
	main.save_time_provider = func() -> int: return 3100
	_expect(
		main._save_game_at_base("update") and main.active_save_slot_id == "fresh-after-delete"
		and not main.active_save_detached_by_delete and not main.active_save_detached_can_resave
		and bool(SaveSystem.load_slot("fresh-after-delete", ui_slots).get("ok", false)),
		"The next legitimate save after resume must use a fresh opaque id and clear detachment",
	)
	main.save_id_factory = prior_factory
	main.save_time_provider = prior_time_provider

	# Non-active deletion and deterministic errors never mutate the active run.
	_expect(bool(SaveSystem.save_slot(_state("Delete Other", 4), "delete-other", "overwrite", ui_slots, 3200).get("ok", false)), "Non-active delete fixture must save")
	var active_before_other: String = main.active_save_slot_id
	var state_before_other = main.state
	main._on_save_slot_delete_requested("delete-other")
	_expect(
		main.active_save_slot_id == active_before_other and main.state == state_before_other
		and not FileAccess.file_exists(ui_slots + "/delete-other.json"),
		"Deleting a non-active slot must not mutate active id or RunState",
	)
	_expect(bool(SaveSystem.save_slot(_state("Delete Error", 5), "delete-error", "overwrite", ui_slots, 3300).get("ok", false)), "Deletion error fixture must save")
	main._open_main_menu()
	main.save_menu_panel.show_load_list()
	main.save_delete_fault_injector = func(stage: String) -> bool: return stage == "primary"
	main.save_menu_panel.trash_buttons[0].pressed.emit()
	main.save_menu_panel.delete_yes_button.pressed.emit()
	await tree.process_frame
	_expect(
		main.save_menu_panel.list_mode and main.save_menu_panel.error_label.visible
		and main.save_menu_panel.error_label.text.contains(str(ERR_CANT_CREATE))
		and _error_banner_fits(main.save_menu_panel)
		and FileAccess.file_exists(ui_slots + "/delete-error.json")
		and main.save_menu_panel.slots.any(func(row: Dictionary) -> bool: return row.get("slot_id") == "delete-error"),
		"Deletion errors must remain visible in list mode and refresh from authoritative disk state",
	)
	main.save_delete_fault_injector = Callable()
	main._on_save_slot_delete_requested("delete-error")
	_expect(not FileAccess.file_exists(ui_slots + "/delete-error.json"), "A deletion retry must safely remove the remaining active family")
	for recovery_stage in ["primary", "backup"]:
		var ui_recovery_id := "ui-recovery-" + String(recovery_stage)
		var ui_recovery_state := _state("UI Recovery %s" % recovery_stage, 8)
		_expect(
			bool(SaveSystem.save_slot(ui_recovery_state, ui_recovery_id, "overwrite", ui_slots, 3400).get("ok", false))
			and bool(SaveSystem.save_slot(ui_recovery_state, ui_recovery_id, "overwrite", ui_slots, 3401).get("ok", false)),
			"UI recovery fixture must publish primary and backup",
		)
		_write_text(ui_slots + "/" + ui_recovery_id + ".json", "{broken")
		main.save_menu_panel.set_slots(SaveSystem.list_slots(ui_slots))
		main.save_menu_panel.show_load_list()
		var recovery_index := -1
		for row_index in range(main.save_menu_panel.slots.size()):
			if main.save_menu_panel.slots[row_index].get("slot_id") == ui_recovery_id:
				recovery_index = row_index
				break
		_expect(recovery_index >= 0, "Recoverable backup row must be visible before UI deletion")
		main.save_menu_panel.page = floori(float(recovery_index) / float(main.save_menu_panel.PAGE_SIZE))
		main.save_menu_panel._rebuild_slot_buttons()
		main.save_menu_panel._refresh_state()
		await tree.process_frame
		var recovery_local_index: int = recovery_index - main.save_menu_panel.page * main.save_menu_panel.PAGE_SIZE
		main.save_delete_fault_injector = func(stage: String) -> bool: return stage == recovery_stage
		await _click(main, tree, main.save_menu_panel.trash_buttons[recovery_local_index].get_global_rect().get_center())
		_expect(main.save_menu_panel.delete_modal_open, "A real mouse Trash must open recoverable %s confirmation" % recovery_stage)
		var recovery_delete_signal_count := delete_signals.size()
		await _click(main, tree, main.save_menu_panel.delete_yes_button.get_global_rect().get_center())
		await tree.process_frame
		_expect(delete_signals.size() == recovery_delete_signal_count + 1, "A real mouse Yes must invoke recoverable %s deletion exactly once" % recovery_stage)
		_expect(main.save_menu_panel.list_mode, "A recoverable %s mouse failure must preserve list mode" % recovery_stage)
		_expect(main.save_menu_panel.error_label.visible, "A recoverable %s mouse failure must display its error" % recovery_stage)
		_expect(
			main.save_menu_panel.slots.any(
				func(row: Dictionary) -> bool: return row.get("slot_id") == ui_recovery_id
			),
			"A recoverable %s mouse failure must keep its UI row and Trash retry available" % recovery_stage,
		)
		main.save_delete_fault_injector = Callable()
		await _click(main, tree, main.save_menu_panel.trash_buttons[recovery_local_index].get_global_rect().get_center())
		await _click(main, tree, main.save_menu_panel.delete_yes_button.get_global_rect().get_center())
		await tree.process_frame
		_expect(
			not main.save_menu_panel.slots.any(
				func(row: Dictionary) -> bool: return row.get("slot_id") == ui_recovery_id
			)
			and not FileAccess.file_exists(ui_slots + "/" + ui_recovery_id + ".json.bak"),
			"Trash retry after recoverable %s failure must remove the family" % recovery_stage,
		)
	main._resume_from_main_menu()

	# Deleting the sole startup slot produces the explicit empty state.
	var prior_slots_directory: String = main.save_slots_directory
	var last_dir := ROOT + "/last-slot"
	_expect(bool(SaveSystem.save_slot(_state("Last Hero", 1), "last", "overwrite", last_dir, 1).get("ok", false)), "Last-slot fixture must save")
	main.save_slots_directory = last_dir
	main.active_save_slot_id = ""
	main._show_startup()
	main.save_menu_panel.show_load_list()
	main.save_menu_panel.trash_buttons[0].pressed.emit()
	main.save_menu_panel.delete_yes_button.pressed.emit()
	await tree.process_frame
	_expect(
		main.save_menu_panel.slots.is_empty() and main.save_menu_panel.empty_label.visible,
		"Deleting the last slot must leave the load list in its clear empty state",
	)
	main.save_menu_panel.show_menu(false)
	_expect(
		main.save_menu_panel.continue_button.disabled and main.save_menu_panel.load_button.disabled,
		"Deleting the last startup slot must immediately disable Continue and Load",
	)
	main.save_slots_directory = prior_slots_directory
	main.screen = main.Screen.BASE
	main.main_menu_open = false
	main.state = state_before_other
	main.active_save_slot_id = active_before_other

	# Opening the menu cancels every transient gameplay mode and blocks world input.
	main.screen = main.Screen.DUNGEON
	main.state.current_floor = 99
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(2, 2)
	var player_before: Vector2i = main.player_pos
	var turns_before: int = main.state.total_turns
	main.auto_explore_active = true
	main.auto_travel_active = true
	main.ability_targeting_id = "dash"
	main.ability_target_cells.clear()
	main.ability_target_cells.append(Vector2i(3, 2))
	main._open_main_menu()
	main._handle_board_cell(Vector2i(3, 2))
	_expect(
		main.player_pos == player_before and main.state.total_turns == turns_before
		and not main.auto_explore_active and not main.auto_travel_active
		and main.ability_targeting_id.is_empty(),
		"Entering Main Menu must cancel transients and block board input without mutating the run",
	)
	var slot_count_before_exit := SaveSystem.list_slots(ui_slots).size()
	var exit_calls: Array[int] = []
	main.exit_request_hook = func() -> void: exit_calls.append(1)
	main.save_menu_panel.exit_button.pressed.emit()
	_expect(exit_calls.is_empty(), "Exit must retain the existing second-click confirmation")
	main.save_menu_panel.exit_button.pressed.emit()
	_expect(
		exit_calls.size() == 1 and SaveSystem.list_slots(ui_slots).size() == slot_count_before_exit,
		"Injected dungeon Exit must save the active slot and request shutdown once without creating a history milestone",
	)
	_expect(not SaveSystem.load_slot(main.active_save_slot_id, ui_slots).get("snapshot", {}).is_empty(), "Dungeon Exit must publish an exact snapshot")
	main._resume_from_main_menu()

	# Starting another character keeps every existing slot and resets the policy checkbox to ON.
	var count_before_new := SaveSystem.list_slots(ui_slots).size()
	main._on_startup_new_game_requested()
	_expect(
		main.screen == main.Screen.NAME_CREATION and main.save_policy_checkbox.button_pressed
		and SaveSystem.list_slots(ui_slots).size() == count_before_new,
		"New Game must preserve other saves and default the creation checkbox to checked",
	)
	main.queue_free()
	await tree.process_frame


func _state(character_name: String, souls: int) -> RunState:
	var state := RunState.new()
	state.configure_character(character_name, GameRules.default_attributes())
	state.add_souls(souls)
	return state


func _save_full_run(
	state: RunState, slot_id: String, saves_dir: String, timestamp: int,
	snapshot_override: Dictionary = {},
) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = 160091
	var snapshot := (
		Snapshot.capture("base", {}, Vector2i.ZERO, random, {})
		if snapshot_override.is_empty()
		else snapshot_override
	)
	return SaveSystem.save_slot(
		state, slot_id, "overwrite", saves_dir, timestamp,
		Callable(), {}, Callable(), snapshot,
	)


func _valid_state_only_data(
	character_name: String, banked_souls: int, carried_souls: int, absorbed_souls: int,
) -> Dictionary:
	var state := RunState.new()
	state.configure_character(character_name, GameRules.default_attributes())
	state.banked_souls = banked_souls
	state.carried_souls = carried_souls
	state.absorbed_souls = absorbed_souls
	state.lifetime_souls_earned = banked_souls + carried_souls + absorbed_souls
	state.current_form_id = GameRules.form_for_absorbed_souls(absorbed_souls)
	state.highest_unlocked_form_index = GameRules.FORM_ORDER.find(state.current_form_id)
	return state.to_save_data()


func _floor_fixture() -> Dictionary:
	var tiles := {}
	for y in range(5):
		for x in range(5):
			tiles[Vector2i(x, y)] = "floor"
	tiles[Vector2i(0, 1)] = "wall"
	tiles[Vector2i(4, 3)] = "wall"
	return {
		"width": 5, "height": 5, "tiles": tiles, "start": Vector2i(1, 1),
		"rooms": [
			{
				"door": Vector2i(1, 0), "outward": Vector2i.RIGHT,
				"cells": {Vector2i(0, 0): true},
				"reserved": {Vector2i(0, 0): true, Vector2i(1, 0): true},
			},
			{
				"door": Vector2i(3, 4), "outward": Vector2i.LEFT,
				"cells": {Vector2i(4, 4): true},
				"reserved": {Vector2i(4, 4): true, Vector2i(3, 4): true},
			},
		],
		"base_gate": Vector2i(0, 2), "exit": Vector2i(4, 2), "exit_known": false,
		"cradle": Vector2i(-1, -1), "items": [], "enemies": [],
		"cradle_known": false, "cradle_used": false, "cradle_pity_resolved": true,
		"seed": 1, "cradle_roll_chance": 0.0,
		"biome": "", "initial_enemy_kinds": [], "decorations": {},
		"visible_cells": {}, "explored_cells": {}, "observed_cells": {},
	}


func _action_event(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.flush()


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _snapshot_family_bytes(primary_path: String) -> Dictionary:
	var result := {}
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = primary_path + suffix
		var exists := FileAccess.file_exists(path)
		result[suffix] = {
			"exists": exists,
			"bytes": FileAccess.get_file_as_bytes(path) if exists else PackedByteArray(),
		}
	return result


func _error_banner_fits(panel: Control) -> bool:
	if not panel.error_banner.visible or not panel.error_label.visible:
		return false
	var label: Label = panel.error_label
	var measured := label.get_theme_font("font").get_multiline_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_CENTER,
		label.size.x,
		label.get_theme_font_size("font_size"),
	)
	if measured.y > label.size.y or panel.error_banner.size.y < 64.0 or panel.error_banner.size.y > 72.0:
		return false
	if (
		panel.slot_buttons.size() != panel.PAGE_SIZE
		or panel.trash_buttons.size() != panel.PAGE_SIZE
	):
		return false
	var banner_rect := Rect2(panel.error_banner.position, panel.error_banner.size)
	var paging_and_back := [
		Rect2(panel.previous_button.position, panel.previous_button.size),
		Rect2(panel.page_label.position, panel.page_label.size),
		Rect2(panel.next_button.position, panel.next_button.size),
		Rect2(panel.back_button.position, panel.back_button.size),
	]
	for index in range(panel.PAGE_SIZE):
		var row: Control = panel.slot_buttons[index]
		var trash: Control = panel.trash_buttons[index]
		var row_rect := Rect2(row.position, row.size)
		var trash_rect := Rect2(trash.position, trash.size)
		if banner_rect.intersects(row_rect) or banner_rect.intersects(trash_rect):
			return false
		for lower_rect in paging_and_back:
			if lower_rect.intersects(row_rect) or lower_rect.intersects(trash_rect):
				return false
		if (
			row.focus_neighbor_right != trash.get_path()
			or trash.focus_neighbor_left != row.get_path()
			or row.focus_neighbor_top.is_empty()
			or row.focus_neighbor_bottom.is_empty()
			or trash.focus_neighbor_top.is_empty()
			or trash.focus_neighbor_bottom.is_empty()
		):
			return false
	return (
		panel.slot_buttons[0].position.y
		>= panel.error_banner.position.y + panel.error_banner.size.y + 4.0
		and panel.slot_buttons[-1].position.y + panel.slot_buttons[-1].size.y
		<= panel.previous_button.position.y - 2.0
	)


func _push_action(main, tree: SceneTree, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	main.get_viewport().push_input(press, true)
	await tree.process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await tree.process_frame


func _panel_action(panel: Control, tree: SceneTree, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	_expect(panel.handle_input(press), "Save panel must consume %s while open" % action)
	await tree.process_frame


func _push_physical_key(main, tree: SceneTree, keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	main.get_viewport().push_input(press, true)
	await tree.process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await tree.process_frame


func _push_gamepad(main, tree: SceneTree, button_index: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button_index
	press.pressed = true
	main.get_viewport().push_input(press, true)
	await tree.process_frame
	var release := InputEventJoypadButton.new()
	release.button_index = button_index
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await tree.process_frame


func _click(main, tree: SceneTree, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.pressed = true
	main.get_viewport().push_input(press, true)
	await tree.process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await tree.process_frame


func _touch(main, tree: SceneTree, position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = position
	press.pressed = true
	main.get_viewport().push_input(press, true)
	await tree.process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = position
	release.pressed = false
	main.get_viewport().push_input(release, true)
	for _frame in range(6):
		await tree.process_frame


func _cleanup() -> void:
	_remove_tree(ROOT)


func _remove_tree(path: String) -> void:
	assert(path == ROOT or path.begins_with(ROOT + "/"), "Save-slot cleanup escaped its fixed nightly root")
	var directory := DirAccess.open(path)
	if directory == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
