class_name StorageTestSuite
extends RefCounted

const SaveSystem := preload("res://scripts/system/persistence.gd")
const Snapshot := preload("res://scripts/system/run_snapshot.gd")
const ROOT := "res://.tmp/storage-test"
const FIXTURE_ROOT := "res://tests/fixtures/save-v17"

var failures: Array[String] = []


func run(_tree: SceneTree) -> Array[String]:
	failures.clear()
	_cleanup(ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	_test_rules_and_build()
	_test_atomic_transfers()
	_test_transfer_rejections()
	_test_storage_isolation_and_scale()
	_test_death_and_validation()
	_test_frozen_v17_migration()
	_test_v18_roundtrip_and_mixed_family()
	_cleanup(ROOT)
	return failures


func _test_rules_and_build() -> void:
	var historical := GameRules.CAMP_DRAW_ORDER.slice(0, 12)
	_expect(
		historical == RunState.CAMP_UPGRADE_IDS_V17
		and GameRules.CAMP_DRAW_ORDER.size() == 13
		and GameRules.CAMP_DRAW_ORDER.back() == "storage_chest",
		"Storage Chest must append after the exact 12 historical camp ids",
	)
	_expect(
		SaveSystem.SAVE_VERSION == 18
		and SaveSystem.STATE_ONLY_VERSION == 18
		and SaveSystem.MIN_SUPPORTED_SAVE_VERSION == 17
		and SaveSystem.SLOT_ENVELOPE_VERSION == 1
		and Snapshot.FORMAT_VERSION == 2,
		"Storage must advance only state/save version to 18 while retaining v17 support and envelope/RunSnapshot formats",
	)
	_expect(
		GameRules.CAMP_UPGRADES.storage_chest.cost == {
			"wood": 20, "stone": 4, "cloth": 3,
		}
		and GameRules.CAMP_UPGRADES.storage_chest.get("requires", []).is_empty(),
		"Storage Chest must cost exact wood20/stone4/cloth3 with no prerequisite",
	)
	var state := _state("Build")
	state.resources = {"wood": 19, "stone": 4, "cloth": 3}
	var before := state.resources.duplicate(true)
	var rejected := state.build_camp_upgrade("storage_chest")
	_expect(
		not rejected.get("ok", false)
		and rejected.get("reason") == "resources"
		and state.resources == before
		and not state.camp_upgrades.storage_chest,
		"Unaffordable Storage Chest must be a resource-preserving no-op",
	)
	state.resources.wood = 20
	var built := state.build_camp_upgrade("storage_chest")
	_expect(
		built.get("ok", false)
		and state.camp_upgrades.storage_chest
		and state.resources == {"wood": 0, "stone": 0, "cloth": 0},
		"Storage Chest must charge its exact cost once",
	)
	var after := state.to_snapshot_data()
	_expect(
		state.build_camp_upgrade("storage_chest").get("reason") == "built"
		and state.to_snapshot_data() == after,
		"Building Storage Chest twice must be an exact no-op",
	)


func _test_atomic_transfers() -> void:
	var state := _state("Transfers")
	state.camp_upgrades.storage_chest = true
	var upgraded_bound := GameRules.make_item_key("old_claymore", 3, true)
	state.inventory[upgraded_bound] = 4
	state.inventory_marks[upgraded_bound] = "salvage"
	var turns := state.total_turns
	var one := state.transfer_inventory_to_storage(upgraded_bound, 1)
	_expect(
		one.get("ok", false)
		and state.inventory.get(upgraded_bound) == 3
		and state.storage.get(upgraded_bound) == 1
		and state.inventory_marks.get(upgraded_bound) == "salvage"
		and state.storage_marks.get(upgraded_bound) == "salvage"
		and state.total_turns == turns,
		"Move-one must preserve canonical +3 bound identity, source mark and turn count",
	)
	var all_to_storage := state.transfer_inventory_to_storage(
		upgraded_bound, int(state.inventory[upgraded_bound]),
	)
	_expect(
		all_to_storage.get("ok", false)
		and not state.inventory.has(upgraded_bound)
		and not state.inventory_marks.has(upgraded_bound)
		and state.storage[upgraded_bound] == 4
		and state.storage_marks[upgraded_bound] == "salvage",
		"Move-all to storage must remove the source stack without losing its mark",
	)
	var one_back := state.transfer_storage_to_inventory(upgraded_bound, 1)
	_expect(
		one_back.get("ok", false)
		and state.storage[upgraded_bound] == 3
		and state.inventory[upgraded_bound] == 1
		and state.storage_marks[upgraded_bound] == "salvage"
		and state.inventory_marks[upgraded_bound] == "salvage",
		"Move-one back must preserve both physical stack marks",
	)
	var all_back := state.transfer_storage_to_inventory(upgraded_bound, 3)
	_expect(
		all_back.get("ok", false)
		and state.inventory[upgraded_bound] == 4
		and not state.storage.has(upgraded_bound)
		and not state.storage_marks.has(upgraded_bound),
		"Move-all back must merge count and clear the exhausted storage mark",
	)

	# Conservative merge: keep wins; salvage requires both stacks to be salvage.
	var key := GameRules.make_item_key("bone_knife", 2)
	state.inventory[key] = 2
	state.inventory_marks[key] = "salvage"
	state.storage[key] = 1
	state.storage_marks[key] = "keep"
	state.transfer_inventory_to_storage(key, 1)
	_expect(
		state.storage_marks.get(key) == "keep" and state.inventory_marks.get(key) == "salvage",
		"Destination keep must win while the partial source retains salvage",
	)
	state.storage_marks.erase(key)
	state.transfer_inventory_to_storage(key, 1)
	_expect(
		not state.storage_marks.has(key),
		"A salvage move into an unmarked stack must conservatively become unmarked",
	)

	for merge_case in [
		{"destination": "keep", "source": "", "expected": "keep"},
		{"destination": "salvage", "source": "keep", "expected": "keep"},
		{"destination": "salvage", "source": "", "expected": ""},
		{"destination": "", "source": "keep", "expected": "keep"},
		{"destination": "", "source": "salvage", "expected": ""},
		{"destination": "salvage", "source": "salvage", "expected": "salvage"},
	]:
		var merge_state := _state("Merge")
		merge_state.camp_upgrades.storage_chest = true
		var merge_key := GameRules.make_item_key("aiming_ring", 0)
		merge_state.inventory[merge_key] = 2
		merge_state.storage[merge_key] = 1
		if not String(merge_case.source).is_empty():
			merge_state.inventory_marks[merge_key] = merge_case.source
		if not String(merge_case.destination).is_empty():
			merge_state.storage_marks[merge_key] = merge_case.destination
		var merged := merge_state.transfer_inventory_to_storage(merge_key, 1)
		_expect(
			merged.get("ok", false)
			and merge_state.storage_marks.get(merge_key, "") == merge_case.expected
			and merge_state.inventory_marks.get(merge_key, "") == merge_case.source,
			"Storage mark merge matrix must use conservative add-item semantics: %s" % merge_case,
		)


func _test_transfer_rejections() -> void:
	var state := _state("Reject")
	var key := GameRules.make_item_key("bone_knife", 1)
	state.inventory[key] = 2
	state.inventory_marks[key] = "keep"
	var cases: Array[Callable] = [
		func() -> Dictionary: return state.transfer_inventory_to_storage(key, 1),
	]
	for call in cases:
		var before := _four_dictionaries(state)
		_expect(
			not call.call().get("ok", false) and _four_dictionaries(state) == before,
			"Unbuilt chest transfer must preserve all four dictionaries exactly",
		)
	state.camp_upgrades.storage_chest = true
	state.loadout.right_hand = GameRules.make_item_key("old_claymore", 1)
	for request in [
		{"key": key, "count": 0},
		{"key": key, "count": -1},
		{"key": key, "count": 3},
		{"key": "unknown@0", "count": 1},
		{"key": GameRules.permanent_jacket_key(), "count": 1},
		{"key": String(state.loadout.right_hand), "count": 1},
	]:
		var before := _four_dictionaries(state)
		var result := state.transfer_inventory_to_storage(request.key, request.count)
		_expect(
			not result.get("ok", false) and _four_dictionaries(state) == before,
			"Rejected storage request must be atomic: %s" % request,
		)
	var before_float := _four_dictionaries(state)
	_expect(
		not state.transfer_inventory_to_storage(key, 1.0).get("ok", false)
		and _four_dictionaries(state) == before_float,
		"Transfer API must reject a non-int count without clamping",
	)
	state.storage_marks[key] = "keep"
	var before_stale_mark := _four_dictionaries(state)
	_expect(
		not state.transfer_inventory_to_storage(key, 1).get("ok", false)
		and _four_dictionaries(state) == before_stale_mark,
		"A destination mark without an existing stack must reject atomically",
	)


func _test_storage_isolation_and_scale() -> void:
	var state := _state("Isolation")
	for upgrade_id in ["storage_chest", "crusher", "whetstone", "ritual_table"]:
		state.camp_upgrades[upgrade_id] = true
	state.resources = {"wood": 20, "stone": 20, "cloth": 20}
	state.banked_souls = 100
	state.lifetime_souls_earned = 100
	var stored_key := GameRules.make_item_key("bone_knife", 1)
	state.storage[stored_key] = 10000
	state.storage_marks[stored_key] = "salvage"
	state.loadout.right_hand = GameRules.make_item_key("old_claymore", 2)
	state.equipped_marks.right_hand = "keep"
	state.inventory[GameRules.make_item_key("rotting_mail", 0)] = 2
	var storage_before := state.storage.duplicate(true)
	var storage_marks_before := state.storage_marks.duplicate(true)
	var loadout_before := state.loadout.duplicate(true)
	var equipped_marks_before := state.equipped_marks.duplicate(true)
	var resources_before := state.resources.duplicate(true)
	var souls_before := state.get_total_souls()
	_expect(
		not state.equip_from_inventory(stored_key).get("ok", false)
		and not state.dismantle_item(stored_key).get("ok", false)
		and not state.upgrade_weapon(stored_key, 0.0, 0.0).get("ok", false)
		and not state.bind_item(stored_key, "storage").get("ok", false)
		and state.storage == storage_before
		and state.storage_marks == storage_marks_before
		and state.loadout == loadout_before
		and state.equipped_marks == equipped_marks_before
		and state.resources == resources_before
		and state.get_total_souls() == souls_before,
		"Storage stacks must never enter loadout, equipped marks, Crusher, Whetstone, or Ritual operations",
	)
	state.dismantle_all_items()
	_expect(
		state.storage == storage_before and state.storage_marks == storage_marks_before,
		"Crusher bulk operations must ignore every stored stack",
	)
	var turns_before := state.total_turns
	var total_before := int(state.storage[stored_key])
	for _index in range(500):
		var outward := state.transfer_storage_to_inventory(stored_key, 1)
		var inward := state.transfer_inventory_to_storage(stored_key, 1)
		if not outward.get("ok", false) or not inward.get("ok", false):
			failures.append("Large repeated storage transfer unexpectedly failed")
			break
	_expect(
		int(state.storage.get(stored_key, 0)) + int(state.inventory.get(stored_key, 0))
		== total_before
		and state.storage_marks.get(stored_key, "") == "salvage"
		and state.total_turns == turns_before,
		"Large repeated transfers must preserve total count, mark identity, and turns",
	)


func _test_death_and_validation() -> void:
	var state := _state("Death")
	state.camp_upgrades.storage_chest = true
	var key := GameRules.make_item_key("old_claymore", 3, true)
	state.storage[key] = 7
	state.storage_marks[key] = "keep"
	state.inventory[GameRules.make_item_key("bone_knife", 0)] = 2
	state.carried_souls = 9
	state.lifetime_souls_earned = 9
	var storage_before := state.storage.duplicate(true)
	var marks_before := state.storage_marks.duplicate(true)
	state.current_floor = 88
	state.safe_return()
	_expect(
		state.storage == storage_before and state.storage_marks == marks_before,
		"Safe return must preserve Storage contents and marks exactly",
	)
	state.die()
	_expect(
		state.storage == storage_before
		and state.storage_marks == marks_before
		and state.inventory.is_empty(),
		"Death must preserve storage while retaining expedition inventory loss rules",
	)
	var valid := state.to_snapshot_data()
	_expect(RunState.is_snapshot_data_valid(valid), "Canonical nonempty built storage must validate")
	for mutate in [
		func(data: Dictionary): data.camp_upgrades.storage_chest = false,
		func(data: Dictionary): data.storage[key] = 0,
		func(data: Dictionary): data.storage["unknown@0"] = 1,
		func(data: Dictionary): data.storage[GameRules.permanent_jacket_key()] = 1,
		func(data: Dictionary): data.storage_marks[key] = "later",
		func(data: Dictionary): data.storage_marks[GameRules.make_item_key("bone_knife", 0)] = "keep",
	]:
		var invalid := valid.duplicate(true)
		mutate.call(invalid)
		_expect(not RunState.is_snapshot_data_valid(invalid), "Malformed storage snapshot must reject")


func _test_frozen_v17_migration() -> void:
	var saves := ROOT.path_join("frozen")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saves))
	var fixtures := [
		{
			"source": FIXTURE_ROOT.path_join("frozen-v17-state-only.json"),
			"slot": "frozen-v17-state",
			"full": false,
		},
		{
			"source": FIXTURE_ROOT.path_join("frozen-v17-full-run.json"),
			"slot": "frozen-v17-full",
			"full": true,
		},
	]
	for fixture in fixtures:
		var destination := saves.path_join(String(fixture.slot) + ".json")
		_copy_bytes(String(fixture.source), destination)
		var before := FileAccess.get_file_as_bytes(destination)
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(destination))
		var decoded_errors: Array = []
		var historical: Dictionary = Snapshot.decode(raw.state, decoded_errors)
		var loaded := SaveSystem.load_slot(String(fixture.slot), saves)
		var loaded_historical: Dictionary = loaded.get("state", {}).duplicate(true)
		loaded_historical.erase("storage")
		loaded_historical.erase("storage_marks")
		if loaded_historical.get("camp_upgrades") is Dictionary:
			loaded_historical.camp_upgrades.erase("storage_chest")
		_expect(
			loaded.get("ok", false)
			and loaded.get("version") == 17
			and loaded.get("state", {}).get("storage") == {}
			and loaded.get("state", {}).get("storage_marks") == {}
			and not loaded.get("state", {}).get("camp_upgrades", {}).get("storage_chest", true)
			and loaded_historical == RunState.snapshot_data_from_json(historical)
			and loaded.get("metadata") == raw.metadata
			and FileAccess.get_file_as_bytes(destination) == before,
			"Authentic v17 fixture must migrate read-only exactly once without other state/metadata changes",
		)
		_expect(
			(bool(loaded.get("snapshot", {}).is_empty()) != bool(fixture.full))
			and (
				not bool(fixture.full)
				or (
					loaded.snapshot.context == "base"
					and loaded.snapshot.rng_seed == -7017001700170017
					and loaded.snapshot.rng_state == 17001700170017
				)
			),
			"v17 full-run migration must preserve exact context and RNG while state-only stays snapshot-free",
		)
		var second := SaveSystem.load_slot(String(fixture.slot), saves)
		_expect(
			second.get("state") == loaded.get("state")
			and second.get("snapshot") == loaded.get("snapshot")
			and FileAccess.get_file_as_bytes(destination) == before,
			"Repeated v17 load must be idempotent and never rewrite the fixture",
		)

	# A v18-shaped or otherwise extended payload stamped as v17 is corruption.
	var malformed_path := saves.path_join("frozen-v17-state.json")
	var malformed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(malformed_path))
	malformed.state["storage"] = {}
	_write_json(malformed_path, malformed)
	_expect(
		not SaveSystem.load_slot("frozen-v17-state", saves).get("ok", false),
		"Extended v17 state must remain corrupt instead of being interpreted ambiguously",
	)

	var malformed_cases: Array[Callable] = [
		func(raw: Dictionary): raw["unexpected_envelope"] = true,
		func(raw: Dictionary): raw.state.erase("character_sex"),
		func(raw: Dictionary): raw.state["unexpected"] = true,
		func(raw: Dictionary): raw.state.camp_upgrades.erase("record_player"),
		func(raw: Dictionary): raw.state.camp_upgrades["future_camp"] = false,
		func(raw: Dictionary): raw.state.inventory["unknown@0"] = 1,
		func(raw: Dictionary): raw.state.inventory["bone_knife@0"] = "1",
	]
	var fixture_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		FIXTURE_ROOT.path_join("frozen-v17-state-only.json")
	))
	for case_index in range(malformed_cases.size()):
		var slot_id := "malformed-v17-%d" % case_index
		var case_path := saves.path_join(slot_id + ".json")
		var malformed_case := fixture_raw.duplicate(true)
		malformed_case.metadata.slot_id = slot_id
		malformed_cases[case_index].call(malformed_case)
		_write_json(case_path, malformed_case)
		var case_bytes := FileAccess.get_file_as_bytes(case_path)
		_expect(
			not SaveSystem.load_slot(slot_id, saves).get("ok", false)
			and FileAccess.get_file_as_bytes(case_path) == case_bytes,
			"Missing/extra/unknown/malformed strict v17 case must reject read-only: %d" % case_index,
		)
	var corrupt_path := saves.path_join("corrupt-v17.json")
	_write_raw_text(corrupt_path, "{not valid json")
	var corrupt_bytes := FileAccess.get_file_as_bytes(corrupt_path)
	_expect(
		not SaveSystem.load_slot("corrupt-v17", saves).get("ok", false)
		and FileAccess.get_file_as_bytes(corrupt_path) == corrupt_bytes,
		"Corrupt v17-family JSON must reject without mutation",
	)

	var fallback := ROOT.path_join("v17-fallback")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fallback))
	var fallback_primary := fallback.path_join("frozen-v17-state.json")
	_write_raw_text(fallback_primary, "{corrupt primary")
	_copy_bytes(
		FIXTURE_ROOT.path_join("frozen-v17-state-only.json"), fallback_primary + ".bak",
	)
	var fallback_primary_bytes := FileAccess.get_file_as_bytes(fallback_primary)
	var fallback_backup_bytes := FileAccess.get_file_as_bytes(fallback_primary + ".bak")
	var fallback_loaded := SaveSystem.load_slot("frozen-v17-state", fallback)
	_expect(
		fallback_loaded.get("ok", false)
		and fallback_loaded.get("version") == 17
		and fallback_loaded.get("recovered_from_backup", false)
		and fallback_loaded.get("write_locked", false)
		and fallback_loaded.state.storage == {}
		and FileAccess.get_file_as_bytes(fallback_primary) == fallback_primary_bytes
		and FileAccess.get_file_as_bytes(fallback_primary + ".bak") == fallback_backup_bytes,
		"A valid authentic v17 backup must migrate in memory under write lock without rewriting either member",
	)


func _test_v18_roundtrip_and_mixed_family() -> void:
	var saves := ROOT.path_join("current")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saves))
	var state := _state("Current v18")
	state.camp_upgrades.storage_chest = true
	var key := GameRules.make_item_key("old_claymore", 3, true)
	state.storage[key] = 5
	state.storage_marks[key] = "keep"
	var random := RandomNumberGenerator.new()
	random.seed = 180018
	var saved := SaveSystem.save_slot(
		state, "current", "overwrite", saves, 1800, Callable(), {}, Callable(),
		Snapshot.capture("base", {}, Vector2i.ZERO, random, {}),
	)
	var loaded := SaveSystem.load_slot("current", saves)
	_expect(
		saved.get("ok", false)
		and loaded.get("version") == 18
		and loaded.get("state") == state.to_snapshot_data()
		and loaded.get("snapshot", {}).get("context") == "base",
		"Current v18 full-run must roundtrip storage and exact snapshot context",
	)
	var state_only_path := saves.path_join("current-state-only.json")
	var state_only_error := SaveSystem.save_game(state, state_only_path)
	var state_only_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state_only_path))
	_expect(
		state_only_error == OK
		and int(state_only_raw.version) == 18
		and state_only_raw.kind == "state_only"
		and SaveSystem.load_game(state_only_path) == state.to_save_data(),
		"Current v18 state-only saves must roundtrip Storage Chest state and marks exactly",
	)

	var state_b := _state("Current B")
	state_b.camp_upgrades.storage_chest = true
	state_b.storage[GameRules.make_item_key("bone_bow", 2)] = 9
	state_b.storage_marks[GameRules.make_item_key("bone_bow", 2)] = "salvage"
	var random_b := RandomNumberGenerator.new()
	random_b.seed = 180019
	SaveSystem.save_slot(
		state_b, "current-b", "overwrite", saves, 1801, Callable(), {}, Callable(),
		Snapshot.capture("base", {}, Vector2i.ZERO, random_b, {}),
	)
	var a_first := SaveSystem.load_slot("current", saves)
	var b_middle := SaveSystem.load_slot("current-b", saves)
	var a_second := SaveSystem.load_slot("current", saves)
	_expect(
		a_first.get("state") == state.to_snapshot_data()
		and b_middle.get("state") == state_b.to_snapshot_data()
		and a_second.get("state") == a_first.get("state")
		and a_second.get("snapshot") == a_first.get("snapshot"),
		"Slot A→B→A loads must preserve each v18 Storage Chest snapshot without cross-slot leakage",
	)

	# Publishing over a supported v17 primary writes v18 and retains the authentic
	# v17 bytes as a valid backup; both members remain loadable and write-safe.
	var mixed := ROOT.path_join("mixed")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(mixed))
	var v17_path := mixed.path_join("frozen-v17-state.json")
	_copy_bytes(FIXTURE_ROOT.path_join("frozen-v17-state-only.json"), v17_path)
	var v17_bytes := FileAccess.get_file_as_bytes(v17_path)
	var replacement := _state("Replacement")
	var update := SaveSystem.save_slot(replacement, "frozen-v17-state", "overwrite", mixed, 1801)
	var primary_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(v17_path))
	var mixed_loaded := SaveSystem.load_slot("frozen-v17-state", mixed)
	_expect(
		update.get("ok", false)
		and int(primary_raw.version) == 18
		and FileAccess.get_file_as_bytes(v17_path + ".bak") == v17_bytes
		and mixed_loaded.get("ok", false)
		and not mixed_loaded.get("write_locked", true),
		"A normal save over v17 must publish v18 while retaining a valid mixed-version family",
	)

	for unsupported in [16, 19]:
		var path := mixed.path_join("unsupported-%d.json" % unsupported)
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			FIXTURE_ROOT.path_join("frozen-v17-state-only.json")
		))
		raw.version = unsupported
		raw.metadata.slot_id = "unsupported-%d" % unsupported
		_write_json(path, raw)
		_expect(
			not SaveSystem.load_slot("unsupported-%d" % unsupported, mixed).get("ok", false),
			"Unsupported save version %d must reject" % unsupported,
		)
	var rows := SaveSystem.list_slots(mixed)
	for unsupported in [16, 19]:
		var slot_id := "unsupported-%d" % unsupported
		var row := {}
		for candidate in rows:
			if candidate.get("slot_id") == slot_id:
				row = candidate
				break
		_expect(
			row.get("incompatible_version", 0) == unsupported
			and row.get("reason", "") == "incompatible_version",
			"Only versions outside [17,18] must list as incompatible: %d" % unsupported,
		)


func _state(name_value: String) -> RunState:
	var state := RunState.new()
	state.configure_character(name_value, GameRules.default_attributes())
	return state


func _four_dictionaries(state: RunState) -> Dictionary:
	return {
		"inventory": state.inventory.duplicate(true),
		"inventory_marks": state.inventory_marks.duplicate(true),
		"storage": state.storage.duplicate(true),
		"storage_marks": state.storage_marks.duplicate(true),
	}


func _copy_bytes(source: String, destination: String) -> void:
	var output := FileAccess.open(destination, FileAccess.WRITE)
	output.store_buffer(FileAccess.get_file_as_bytes(source))
	output.close()


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ", true, true))
	file.close()


func _write_raw_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _expect(condition: bool, message_value: String) -> void:
	if not condition:
		failures.append(message_value)


func _cleanup(path: String) -> void:
	assert(path == ROOT or path.begins_with(ROOT + "/"))
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(file_name)))
	for child in directory.get_directories():
		_cleanup(path.path_join(child))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
