class_name NightlyContractTestSuite
extends RefCounted

const RunStateScript := preload("res://scripts/game/run_state.gd")
const SaveSystem := preload("res://scripts/system/persistence.gd")
const PlayerMapPresentationScript := preload("res://scripts/ui/player_map_presentation.gd")
const BaseLayoutScript := preload("res://scripts/ui/base_layout.gd")
const SAVE_ROOT := "res://.tmp/nightly/save-boundary-contract"

const FEMALE_GHOUL_HASHES := [
	"85944c51018691adbe3a6bcb40898ebb390add4fc7243531d2746690c6dd108b",
	"03222f39a2d9e52683cf8b6c7dc6940c717c1830e3f572d70331d58d7980a2e0",
	"716fcf5db51d902514313f21440e22ba9bd9ffac14553e855bb1a3d4c5d1dc1b",
	"db5ec118eb6986bc38385a351b473a96b45f29c1f153f5ba041a4c71123baf61",
]

var failures: Array[String] = []


func run() -> Array[String]:
	failures.clear()
	_test_weapon_model_and_transaction()
	_test_camp_and_soul_contract()
	_test_save_boundary()
	_test_map_presentation_state()
	_test_nightly_privacy_contract()
	_test_runtime_assets()
	return failures


func _test_weapon_model_and_transaction() -> void:
	var expected := {
		"rusty_sabre": ["melee", "one_handed"],
		"bone_knife": ["melee", "one_handed"],
		"grave_mace": ["melee", "one_handed"],
		"bone_bow": ["ranged", "two_handed"],
		"short_crossbow": ["ranged", "two_handed"],
		"old_claymore": ["melee", "two_handed"],
	}
	for item_id in expected:
		_expect(
			GameRules.weapon_attack_type(item_id) == expected[item_id][0]
			and GameRules.weapon_grip(item_id) == expected[item_id][1],
			"Attack/grip classification mismatch for %s" % item_id,
		)
	var claymore: Dictionary = GameRules.EQUIPMENT.old_claymore
	_expect(
		claymore.damage == 3 and claymore.accuracy == 2 and claymore.min_depth == 14
		and claymore.salvage == {"wood": 1, "stone": 3},
		"Old Claymore rules must match the approved contract",
	)
	_expect(
		not GameRules.available_equipment_ids(87).has("old_claymore")
		and GameRules.available_equipment_ids(86).has("old_claymore"),
		"Old Claymore must enter ordinary loot exactly at depth 14",
	)

	var salvage_state := RunStateScript.new()
	salvage_state.camp_upgrades.crusher = true
	var salvage_key := salvage_state.add_item("old_claymore")
	var salvage_result := salvage_state.dismantle_item(salvage_key)
	_expect(
		bool(salvage_result.get("ok", false))
		and salvage_result.get("gained", {}) == {"wood": 1, "stone": 3, "cloth": 0}
		and salvage_state.resources == {"wood": 1, "stone": 3, "cloth": 0}
		and not salvage_state.inventory.has(salvage_key),
		"Old Claymore dismantling must consume one item and grant exactly 1W/3S",
	)

	var lifecycle := RunStateScript.new()
	lifecycle.current_form_id = "almost_human"
	lifecycle.highest_unlocked_form_index = 4
	lifecycle.camp_upgrades.whetstone = true
	lifecycle.camp_upgrades.ritual_table = true
	lifecycle.resources = {"wood": 99, "stone": 99, "cloth": 99}
	lifecycle.banked_souls = GameRules.ITEM_BINDING_SOUL_COST
	var upgrade_key := lifecycle.add_item("old_claymore")
	for expected_level in range(1, 4):
		var upgraded := lifecycle.upgrade_weapon(upgrade_key, 0.0, 1.0)
		upgrade_key = String(upgraded.get("item_key", ""))
		_expect(
			bool(upgraded.get("ok", false))
			and upgraded.get("outcome", "") == "upgraded"
			and GameRules.item_upgrade_level(upgrade_key) == expected_level,
			"Old Claymore guaranteed upgrade must reach +%d with its canonical key" % expected_level,
		)
	var maximum_resources: Dictionary = lifecycle.resources.duplicate(true)
	var maximum := lifecycle.upgrade_weapon(upgrade_key, 0.0, 0.0)
	_expect(
		maximum.get("reason", "") == "maximum" and lifecycle.resources == maximum_resources,
		"Old Claymore +3 must reject another upgrade without spending resources",
	)
	lifecycle.set_item_mark(upgrade_key, "keep")
	_expect(
		bool(lifecycle.equip_from_inventory(upgrade_key, "right_hand").get("ok", false)),
		"Old Claymore +3 lifecycle fixture must equip",
	)
	var bound_result := lifecycle.bind_item(upgrade_key, "equipped", "right_hand")
	var bound_claymore := GameRules.make_item_key("old_claymore", 3, true)
	_expect(
		bool(bound_result.get("ok", false))
		and lifecycle.loadout.get("right_hand", "") == bound_claymore
		and lifecycle.item_mark(bound_claymore, "equipped", "right_hand") == "keep",
		"Binding must retain the +3 Old Claymore and its equipped mark",
	)
	lifecycle.die()
	_expect(
		lifecycle.loadout.get("right_hand", "") == bound_claymore
		and lifecycle.item_mark(bound_claymore, "equipped", "right_hand") == "keep",
		"A bound +3 Old Claymore and its mark must survive death in the real main hand",
	)

	var one_handed_ids := ["rusty_sabre", "bone_knife", "grave_mace"]
	var two_handed_ids := ["bone_bow", "short_crossbow", "old_claymore"]
	var offhand_ids := ["bone_buckler", "gravediggers_lamp", "hollow_lantern", "pilgrim_shield"]
	for weapon_id in one_handed_ids:
		for offhand_id in offhand_ids:
			var pair_state := RunStateScript.new()
			pair_state.current_form_id = "almost_human"
			pair_state.highest_unlocked_form_index = 4
			var weapon_key := pair_state.add_item(weapon_id)
			var offhand_key := pair_state.add_item(offhand_id)
			var weapon_result := pair_state.equip_from_inventory(weapon_key, "right_hand")
			var offhand_result := pair_state.equip_from_inventory(offhand_key, "left_hand")
			_expect(
				bool(weapon_result.get("ok", false)) and bool(offhand_result.get("ok", false))
				and pair_state.loadout.get("right_hand", "") == weapon_key
				and pair_state.loadout.get("left_hand", "") == offhand_key,
				"One-handed %s must coexist with real offhand %s" % [weapon_id, offhand_id],
			)
	for weapon_id in two_handed_ids:
		for offhand_id in offhand_ids:
			var offhand_first := RunStateScript.new()
			offhand_first.current_form_id = "almost_human"
			offhand_first.highest_unlocked_form_index = 4
			var first_offhand_key := offhand_first.add_item(offhand_id)
			var first_weapon_key := offhand_first.add_item(weapon_id)
			offhand_first.equip_from_inventory(first_offhand_key, "left_hand")
			var displacing_result := offhand_first.equip_from_inventory(first_weapon_key, "right_hand")
			_expect(
				bool(displacing_result.get("ok", false))
				and offhand_first.loadout.get("right_hand", "") == first_weapon_key
				and not offhand_first.loadout.has("left_hand")
				and offhand_first.inventory.get(first_offhand_key, 0) == 1,
				"Two-handed %s must safely displace offhand %s" % [weapon_id, offhand_id],
			)

			var weapon_first := RunStateScript.new()
			weapon_first.current_form_id = "almost_human"
			weapon_first.highest_unlocked_form_index = 4
			var second_weapon_key := weapon_first.add_item(weapon_id)
			var second_offhand_key := weapon_first.add_item(offhand_id)
			weapon_first.equip_from_inventory(second_weapon_key, "right_hand")
			var matrix_result := weapon_first.equip_from_inventory(second_offhand_key, "left_hand")
			_expect(
				bool(matrix_result.get("ok", false))
				and weapon_first.loadout.get("left_hand", "") == second_offhand_key
				and not weapon_first.loadout.has("right_hand")
				and weapon_first.inventory.get(second_weapon_key, 0) == 1,
				"Offhand %s must atomically displace two-handed %s" % [offhand_id, weapon_id],
			)

	var replacement_state := RunStateScript.new()
	replacement_state.current_form_id = "almost_human"
	replacement_state.highest_unlocked_form_index = 4
	var replacement_claymore := replacement_state.add_item("old_claymore")
	replacement_state.set_item_mark(replacement_claymore, "keep")
	replacement_state.equip_from_inventory(replacement_claymore, "right_hand")
	var replacement_sabre := replacement_state.add_item("rusty_sabre")
	var replace_one := replacement_state.equip_from_inventory(replacement_sabre, "right_hand")
	_expect(
		bool(replace_one.get("ok", false))
		and replacement_state.loadout.get("right_hand", "") == replacement_sabre
		and replacement_state.inventory.get(replacement_claymore, 0) == 1
		and replacement_state.item_mark(replacement_claymore) == "keep"
		and not replacement_state.loadout.has("left_hand"),
		"Replacing Old Claymore with a one-hander must return its marked physical item and free offhand",
	)
	var replacement_bow := replacement_state.add_item("bone_bow")
	var replace_two := replacement_state.equip_from_inventory(replacement_bow, "right_hand")
	_expect(
		bool(replace_two.get("ok", false))
		and replacement_state.loadout.get("right_hand", "") == replacement_bow
		and replacement_state.inventory.get(replacement_sabre, 0) == 1
		and not replacement_state.loadout.has("left_hand"),
		"Replacing one two-hand-capable main-hand state with another must retain one real main slot",
	)

	var state := RunStateScript.new()
	state.character_name = "Nightly"
	state.current_form_id = "almost_human"
	state.highest_unlocked_form_index = 4
	state.soul_level = 3
	state.absorbed_souls = int(GameRules.FORMS.almost_human.threshold)
	state.lifetime_souls_earned = state.absorbed_souls
	var buckler := GameRules.make_item_key("bone_buckler", 1, true)
	var claymore_key := GameRules.make_item_key("old_claymore", 2, true)
	state.loadout.left_hand = buckler
	state.equipped_marks.left_hand = "salvage"
	state.add_item_key(buckler, 1)
	state.add_item_key(claymore_key, 1, "keep")
	var result := state.equip_from_inventory(claymore_key, "right_hand")
	_expect(bool(result.get("ok", false)), "Two-handed equip must succeed after full validation")
	_expect(
		state.loadout.right_hand == claymore_key and not state.loadout.has("left_hand"),
		"Two-handed weapon must occupy only the real main-hand slot",
	)
	_expect(
		state.inventory.get(buckler, 0) == 2 and state.inventory_marks.get(buckler, "") == "salvage",
		"Displaced bound/upgraded offhand and its mark must survive a stack collision",
	)

	var lamp := GameRules.make_item_key("gravediggers_lamp")
	state.add_item_key(lamp, 1, "keep")
	var offhand_swap := state.equip_from_inventory(lamp, "left_hand")
	_expect(
		bool(offhand_swap.get("ok", false))
		and state.loadout.get("left_hand", "") == lamp
		and not state.loadout.has("right_hand")
		and state.inventory.get(claymore_key, 0) == 1
		and state.item_mark(claymore_key) == "keep"
		and state.item_mark(lamp, "equipped", "left_hand") == "keep"
		and RunStateScript.is_snapshot_data_valid(state.to_snapshot_data()),
		"Marked bound/upgraded two-hander must atomically return to inventory for an offhand",
	)
	var impossible := state.to_snapshot_data()
	impossible.loadout.right_hand = claymore_key
	_expect(
		not RunStateScript.is_snapshot_data_valid(impossible),
		"Strict current snapshots must reject a two-handed main hand plus real offhand",
	)
	var reverse_swap := state.equip_from_inventory(claymore_key, "right_hand")
	_expect(
		bool(reverse_swap.get("ok", false))
		and state.loadout.get("right_hand", "") == claymore_key
		and not state.loadout.has("left_hand")
		and state.inventory.get(lamp, 0) == 1
		and state.item_mark(lamp) == "keep"
		and RunStateScript.is_snapshot_data_valid(state.to_snapshot_data()),
		"Two-handed re-equip must symmetrically return the marked offhand",
	)


func _test_camp_and_soul_contract() -> void:
	var state := RunStateScript.new()
	state.character_name = "Camp"
	_expect(
		GameRules.SOUL_LEVEL_START == 0 and state.soul_level == 0
		and state.get_effective_soul_level() == 1,
		"Fresh raw/effective Soul Level must be 0/1 from the canonical jacket",
	)
	_expect(
		state.camp_upgrades.keys().size() == 13
		and state.camp_upgrades.keys().all(func(id): return GameRules.CAMP_UPGRADES.has(id)),
		"Camp state must contain exactly the stable 13-entry registry",
	)
	var before := state.to_snapshot_data()
	var kettle := state.build_camp_upgrade("kettle")
	_expect(
		kettle.get("reason", "") == "prerequisite"
		and kettle.get("required_upgrade", "") == "campfire"
		and state.to_snapshot_data() == before,
		"Kettle prerequisite must validate before costs with no mutation",
	)
	var writing := state.build_camp_upgrade("writing_set")
	_expect(
		writing.get("reason", "") == "prerequisite"
		and writing.get("required_upgrade", "") == "workbench",
		"Writing set must require the workbench",
	)
	_expect(not state.is_camp_upgrade_revealed("mural"), "Mural must stay completely hidden before the tail")

	state.resources.wood = 29
	before = state.to_snapshot_data()
	_expect(
		not bool(state.build_camp_upgrade("rocking_chair").get("ok", false))
		and state.to_snapshot_data() == before,
		"Rocking chair at 29 wood must reject with byte-equivalent state",
	)
	state.resources.wood = 30
	_expect(bool(state.build_camp_upgrade("rocking_chair").get("ok", false)), "Rocking chair must build at 30 wood")
	_expect(
		state.resources.wood == 0 and state.soul_level == 1,
		"Rocking chair must spend exactly 30 wood and grant raw Soul +1 once",
	)
	before = state.to_snapshot_data()
	_expect(
		not bool(state.build_camp_upgrade("rocking_chair").get("ok", false))
		and state.to_snapshot_data() == before,
		"Built rocking chair must never replay its Soul bonus",
	)

	state.resources.wood = 3
	state.resources.stone = 3
	_expect(bool(state.build_camp_upgrade("campfire").get("ok", false)), "Campfire fixture must build")
	state.banked_souls = 60
	state.milestones.minotaur_defeated = true
	state.milestones.minotaur_tail_awarded = true
	state.trophies.minotaur_tail = 1
	state.resources.wood = 12
	state.resources.stone = 20
	state.resources.cloth = 5
	_expect(bool(state.is_camp_upgrade_revealed("mural")), "Tail must reveal the mural")
	_expect(bool(state.build_camp_upgrade("mural").get("ok", false)), "Mural fixture must build")
	_expect(
		state.soul_level == 3 and state.get_effective_soul_level() == 4,
		"Campfire, mural and chair plus jacket must produce raw/effective 3/4",
	)
	var invalid := state.to_snapshot_data()
	invalid.camp_upgrades.workbench = false
	invalid.camp_upgrades.writing_set = true
	_expect(
		not RunStateScript.is_snapshot_data_valid(invalid),
		"Strict current snapshots must reject violated camp dependencies",
	)


func _test_save_boundary() -> void:
	_cleanup_save_root()
	_continue_test_save_boundary()


func _test_map_presentation_state() -> void:
	var presentation := PlayerMapPresentationScript.new()
	for sex in ["female", "male"]:
		for form_id in GameRules.FORM_ORDER:
			presentation.activate(sex, form_id)
			_expect(
				presentation.active_frames.size() == 4,
				"Active-set lazy cache must load exactly four frames for %s/%s" % [sex, form_id],
			)
	var state := RunStateScript.new()
	state.character_name = "No Drift"
	var before := state.to_snapshot_data()
	var random := RandomNumberGenerator.new()
	random.seed = 4419
	var rng_before := random.state
	presentation.activate("female", "ghoul")
	presentation.begin_step(Vector2i.LEFT, 0.2)
	_expect(
		presentation.step_duration == 0.10
		and presentation.visual().offset_cells == Vector2.RIGHT,
		"Step must begin at the previous cell with the 0.10-second cap",
	)
	presentation.update(0.05)
	_expect(
		presentation.visual().frame_index == 1,
		"Contact must switch to the authored transition pose at 50 percent",
	)
	# The replacement step proves unfinished presentation is snapped, not queued.
	presentation.begin_step(Vector2i.RIGHT, 0.11)
	_expect(
		is_equal_approx(presentation.step_duration, 0.0825)
		and presentation.visual().offset_cells == Vector2.LEFT,
		"New step must own presentation immediately and use 0.75 of the expected interval",
	)
	presentation.update(1.0)
	_expect(
		presentation.visual().offset_cells == Vector2.ZERO and not presentation.moving,
		"Completed presentation must land exactly on the logical cell",
	)
	var directions := [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
	for index in range(1000):
		var direction: Vector2i = directions[index % directions.size()]
		presentation.begin_step(direction, 0.11)
		presentation.update(0.1)
	_expect(
		presentation.visual().offset_cells == Vector2.ZERO and not presentation.moving,
		"One thousand presentation steps must accumulate no offset drift or queue",
	)
	presentation.begin_step(Vector2i.LEFT, 0.11)
	presentation.update(1.0)
	var left_flip := bool(presentation.visual().flip_h)
	presentation.begin_step(Vector2i.UP, 0.11)
	presentation.update(1.0)
	_expect(
		not left_flip and not bool(presentation.visual().flip_h),
		"Vertical motion must retain the last left-facing horizontal direction",
	)
	presentation.begin_step(Vector2i.RIGHT, 0.11)
	presentation.update(1.0)
	presentation.begin_step(Vector2i.DOWN, 0.11)
	presentation.update(1.0)
	_expect(bool(presentation.visual().flip_h), "Right-facing art must mirror and survive vertical motion")
	_expect(
		state.to_snapshot_data() == before and state.total_turns == 0 and random.state == rng_before,
		"Presentation-only steps must change no save field, turn counter or RNG state",
	)


func _test_nightly_privacy_contract() -> void:
	var source := FileAccess.get_file_as_string("res://tools/run_nightly.ps1")
	var lowered := source.to_lower()
	_expect(
		not lowered.contains("applicationdata") and not lowered.contains("app_userdata"),
		"Nightly runner must never discover or manifest the real Godot user-data root",
	)
	_expect(
		source.contains("Join-Path $sourceRuntime 'editor_data'")
		and source.contains("APPDATA = Join-Path $runRoot 'environment\\appdata'")
		and source.contains("LOCALAPPDATA = Join-Path $runRoot 'environment\\localappdata'")
		and source.contains("ALMSTH_NIGHTLY_ROOT = $runRoot"),
		"Nightly runner must retain safe source-runtime protection and private child paths",
	)


func _continue_test_save_boundary() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT))
	var state := RunStateScript.new()
	state.character_name = "Boundary"
	state.character_sex = "female"
	var first := SaveSystem.save_slot(state, "backup-case", "overwrite", SAVE_ROOT, 100)
	_expect(bool(first.get("ok", false)), "Current v18 fixture must save")
	state.carried_souls = 1
	var second := SaveSystem.save_slot(state, "backup-case", "overwrite", SAVE_ROOT, 101)
	_expect(bool(second.get("ok", false)), "Second v18 fixture must create a backup")
	var primary_path := SAVE_ROOT.path_join("backup-case.json")
	var primary := _read_json(primary_path)
	primary.version = 16
	_write_json(primary_path, primary)
	var loaded := SaveSystem.load_slot("backup-case", SAVE_ROOT)
	_expect(
		bool(loaded.get("ok", false)) and bool(loaded.get("recovered_from_backup", false))
		and bool(loaded.get("write_locked", false)) and loaded.version == 18,
		"v16 primary with a valid v18 backup must load the backup under write lock",
	)

	var legacy := SaveSystem.save_slot(state, "legacy-16", "overwrite", SAVE_ROOT, 90)
	_expect(bool(legacy.get("ok", false)), "Legacy fixture must start as valid v18")
	var legacy_path := SAVE_ROOT.path_join("legacy-16.json")
	var legacy_data := _read_json(legacy_path)
	legacy_data.version = 16
	_write_json(legacy_path, legacy_data)
	var before_bytes := FileAccess.get_file_as_bytes(legacy_path)
	var explicit_reject := SaveSystem.save_slot(state, "legacy-16", "overwrite", SAVE_ROOT, 102)
	_expect(
		not bool(explicit_reject.get("ok", false))
		and explicit_reject.get("reason", "") == "occupied_incompatible"
		and FileAccess.get_file_as_bytes(legacy_path) == before_bytes
		and not FileAccess.file_exists(legacy_path + ".tmp"),
		"Explicit incompatible family must reject before .tmp and preserve all bytes",
	)
	var rows := SaveSystem.list_slots(SAVE_ROOT)
	var legacy_row := {}
	for row in rows:
		if row.slot_id == "legacy-16":
			legacy_row = row
	_expect(
		not legacy_row.is_empty() and bool(legacy_row.get("locked", false))
		and not bool(legacy_row.get("compatible", true)),
		"Standalone v16 save must remain visible as a locked deletable row",
	)
	var generated_ids := ["legacy-16", "fresh-v18"]
	var generated := SaveSystem.save_slot(
		state, "", "overwrite", SAVE_ROOT, 103,
		func() -> String: return generated_ids.pop_front(),
	)
	_expect(
		bool(generated.get("ok", false)) and generated.slot_id == "fresh-v18",
		"Auto-generated collision must select another fully free family",
	)
	_expect(
		FileAccess.get_file_as_bytes(legacy_path) == before_bytes,
		"Generated collision retry must not mutate the occupied v16 family",
	)

	var bad_backup_save := SaveSystem.save_slot(state, "bad-backup", "overwrite", SAVE_ROOT, 104)
	_expect(bool(bad_backup_save.get("ok", false)), "Invalid-backup fixture must publish a v18 primary")
	var bad_backup_path := SAVE_ROOT.path_join("bad-backup.json")
	var unsupported_backup := _read_json(bad_backup_path)
	unsupported_backup.version = 16
	_write_json(bad_backup_path + ".bak", unsupported_backup)
	var bad_backup_primary_bytes := FileAccess.get_file_as_bytes(bad_backup_path)
	var bad_backup_bytes := FileAccess.get_file_as_bytes(bad_backup_path + ".bak")
	var bad_backup_reject := SaveSystem.save_slot(state, "bad-backup", "overwrite", SAVE_ROOT, 105)
	var bad_backup_load := SaveSystem.load_slot("bad-backup", SAVE_ROOT)
	_expect(
		not bool(bad_backup_reject.get("ok", false))
		and bad_backup_reject.get("reason", "") == "occupied_incompatible"
		and FileAccess.get_file_as_bytes(bad_backup_path) == bad_backup_primary_bytes
		and FileAccess.get_file_as_bytes(bad_backup_path + ".bak") == bad_backup_bytes
		and not FileAccess.file_exists(bad_backup_path + ".tmp"),
		"A valid v18 primary plus unsupported backup must reject without changing family bytes",
	)
	_expect(
		bool(bad_backup_load.get("ok", false)) and bool(bad_backup_load.get("write_locked", false)),
		"A valid primary with an unsafe backup must load write-locked for automatic branching",
	)

	var pending_save := SaveSystem.save_slot(state, "pending-temp", "overwrite", SAVE_ROOT, 106)
	_expect(bool(pending_save.get("ok", false)), "Existing-temporary fixture must publish a v18 primary")
	var pending_path := SAVE_ROOT.path_join("pending-temp.json")
	_write_json(pending_path + ".tmp", {"version": 999, "recovery": "preserve"})
	var pending_primary_bytes := FileAccess.get_file_as_bytes(pending_path)
	var pending_temp_bytes := FileAccess.get_file_as_bytes(pending_path + ".tmp")
	var pending_reject := SaveSystem.save_slot(state, "pending-temp", "overwrite", SAVE_ROOT, 107)
	var pending_load := SaveSystem.load_slot("pending-temp", SAVE_ROOT)
	_expect(
		not bool(pending_reject.get("ok", false))
		and pending_reject.get("reason", "") == "occupied_incompatible"
		and FileAccess.get_file_as_bytes(pending_path) == pending_primary_bytes
		and FileAccess.get_file_as_bytes(pending_path + ".tmp") == pending_temp_bytes,
		"An existing recovery temporary must reject before truncation and preserve exact bytes",
	)
	_expect(
		bool(pending_load.get("ok", false)) and bool(pending_load.get("write_locked", false)),
		"A valid primary with a surviving temporary must load write-locked for automatic branching",
	)

	var state_only_path := SAVE_ROOT.path_join("strict-state-only.json")
	var state_before_strict_load := state.to_snapshot_data()
	for malformed_version in ["18", 18.5, 19]:
		_write_json(state_only_path, {
			"version": malformed_version,
			"kind": "state_only",
			"state": state.to_save_data(),
		})
		var malformed_bytes := FileAccess.get_file_as_bytes(state_only_path)
		_expect(
			SaveSystem.load_game(state_only_path).is_empty()
			and FileAccess.get_file_as_bytes(state_only_path) == malformed_bytes
			and state.to_snapshot_data() == state_before_strict_load,
			"Malformed or future state-only versions must reject without file or runtime mutation: %s"
			% [malformed_version],
		)

	var strict_slot_save := SaveSystem.save_slot(state, "strict-numeric-slot", "overwrite", SAVE_ROOT, 108)
	_expect(bool(strict_slot_save.get("ok", false)), "Strict numeric slot fixture must publish")
	var strict_slot_path := SAVE_ROOT.path_join("strict-numeric-slot.json")
	var strict_slot_valid := _read_json(strict_slot_path)
	for field_case in [
		{"field": "version", "value": 17.5},
		{"field": "version", "value": "17"},
		{"field": "version", "value": 19},
		{"field": "envelope_version", "value": "1"},
	]:
		var malformed_slot := strict_slot_valid.duplicate(true)
		malformed_slot[field_case.field] = field_case.value
		_write_json(strict_slot_path, malformed_slot)
		var malformed_slot_bytes := FileAccess.get_file_as_bytes(strict_slot_path)
		_expect(
			not bool(SaveSystem.load_slot("strict-numeric-slot", SAVE_ROOT).get("ok", false))
			and FileAccess.get_file_as_bytes(strict_slot_path) == malformed_slot_bytes
			and state.to_snapshot_data() == state_before_strict_load,
			"Malformed slot numeric field must reject without mutation: %s=%s"
			% [field_case.field, field_case.value],
		)
	_expect(
		bool(SaveSystem.delete_slot("legacy-16", SAVE_ROOT).get("ok", false)),
		"Locked v16 rows must still support the existing confirmed deletion flow",
	)
	_cleanup_save_root()


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ", true, true))
	file = null


func _cleanup_save_root() -> void:
	var directory := DirAccess.open(SAVE_ROOT)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_ROOT.path_join(entry)))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_ROOT))


func _test_runtime_assets() -> void:
	_test_camp_runtime_assets()
	var manifest_file := FileAccess.open(
		"res://art/characters/map-runtime/2026-09-01/runtime-manifest.json", FileAccess.READ,
	)
	_expect(manifest_file != null, "Map runtime manifest must exist")
	var runtime_manifest: Dictionary = (
		JSON.parse_string(manifest_file.get_as_text()) if manifest_file != null else {}
	)
	_expect(
		int(runtime_manifest.get("schema_version", 0)) == 2
		and runtime_manifest.get("sets", {}).size() == 9,
		"Map runtime manifest must document all nine generated sets with shared-scale schema",
	)
	var sets: Array[String] = []
	for sex in ["female", "male"]:
		for form in GameRules.FORM_ORDER:
			sets.append("%s/%s" % [sex, form])
	_expect(sets.size() == 10, "Map character matrix must contain ten sets")
	for set_id in sets:
		var hashes: Dictionary = {}
		var silhouettes: Dictionary = {}
		var generated_set: Dictionary = runtime_manifest.get("sets", {}).get(set_id, {})
		var shared_scale := float(generated_set.get("shared_normalization_scale", 0.0))
		if set_id != "female/ghoul":
			_expect(shared_scale > 0.0, "Generated set must document one shared scale: %s" % set_id)
		for frame_index in range(4):
			var path := (
				"res://assets/dungeon/female-ghoul/frames/walk-%02d.png" % frame_index
				if set_id == "female/ghoul"
				else "res://assets/dungeon/player-forms/%s/walk-%02d.png" % [set_id, frame_index]
			)
			_expect(FileAccess.file_exists(path), "Missing map frame %s" % path)
			if not FileAccess.file_exists(path):
				continue
			var image := Image.load_from_file(path)
			_expect(
				image.get_size() == Vector2i(264, 264) and image.get_format() == Image.FORMAT_RGBA8,
				"Map frame must be 264x264 RGBA8: %s" % path,
			)
			var used := image.get_used_rect()
			_expect(
				used.position.x >= 4 and used.position.y >= 4
				and used.end.x <= 260 and used.end.y <= 260,
				"Map frame needs at least 4 px alpha padding: %s (%s)" % [path, used],
			)
			var digest := FileAccess.get_sha256(path)
			hashes[digest] = true
			if set_id == "female/ghoul":
				_expect(digest == FEMALE_GHOUL_HASHES[frame_index], "Protected female-ghoul frame changed: %s" % path)
			else:
				var frame_entry: Dictionary = generated_set.get("frames", [])[frame_index]
				var source_size: Array = frame_entry.get("source_subject_size", [])
				var resized_size: Array = frame_entry.get("resized_subject_size", [])
				_expect(
					source_size.size() == 2 and resized_size.size() == 2
					and int(resized_size[0]) == maxi(1, roundi(int(source_size[0]) * shared_scale))
					and int(resized_size[1]) == maxi(1, roundi(int(source_size[1]) * shared_scale)),
					"Every pose must use the set's exact shared scale: %s/%02d" % [set_id, frame_index],
				)
				_expect(
					String(frame_entry.get("sha256", "")).to_lower() == digest,
					"Map manifest digest must match runtime frame: %s" % path,
				)
				silhouettes[String(frame_entry.get("silhouette_sha256", ""))] = true
		_expect(hashes.size() == 4, "Every set needs four materially distinct source poses: %s" % set_id)
		if set_id != "female/ghoul":
			_expect(
				silhouettes.size() == 4 and not silhouettes.has(""),
				"Every generated gait must contain four registered, non-translation silhouettes: %s" % set_id,
			)

	var claymore_path := "res://assets/items/item-old-claymore.png"
	var claymore := Image.load_from_file(claymore_path)
	_expect(
		claymore.get_size() == Vector2i(132, 132) and claymore.get_format() == Image.FORMAT_RGBA8,
		"Old Claymore icon must be 132x132 RGBA8",
	)
	var claymore_used := claymore.get_used_rect()
	_expect(
		claymore_used.position.x >= 4 and claymore_used.position.y >= 4
		and claymore_used.end.x <= 128 and claymore_used.end.y <= 128,
		"Old Claymore icon must keep at least 4 px alpha padding",
	)
	for physical_size in [Vector2i(44, 44), Vector2i(64, 64), Vector2i(33, 33), Vector2i(48, 48)]:
		var reduced := claymore.duplicate()
		reduced.resize(physical_size.x, physical_size.y, Image.INTERPOLATE_LANCZOS)
		_expect(not reduced.get_used_rect().has_area() == false, "Claymore must remain visible at %s" % physical_size)


func _test_camp_runtime_assets() -> void:
	var expected_order := [
		"mural", "bunk", "textile_area", "workbench", "writing_set", "ritual_table",
		"crusher", "whetstone", "campfire", "kettle", "rocking_chair", "record_player",
		"storage_chest",
	]
	_expect(GameRules.CAMP_DRAW_ORDER == expected_order, "Camp runtime draw order must be fixed and exact")
	var historical_hashes := {
		"mural": "873a2e82c4e0c466f64390d129a90e6b305559b6d7a3f69bcb6f3373de7ea5f8",
		"bunk": "1ed92c680cf6c8f00a0379a7e0c6573cff8e960b7fa18e57f8cc32f210eec2f4",
		"textile_area": "fc349615115ad19b23378f3ecb0a6f17f5c3853af50ff7e0b856b49b32e25406",
		"writing_set": "321343681b6d27c62ea76abe3bd8b820139a748d800bb49bac86f1560f989a0e",
		"ritual_table": "00f165adc06e245745b056c04d50b051340695188e94e3bebf12cfe4bbc1d440",
		"crusher": "539579729599b0925dcedf62bdf09cbbfb477d3a393a332956d309340e1a1e24",
		"whetstone": "e0ebfba632ea769130420f310cbc93df46315e47c44ac4cd89f1858c945bbba5",
		"campfire": "1b87dec63be53de77af808ab52e5ee836a10eed69818ff7525f054884f8e1ad1",
		"kettle": "df117ad4c36079f6b72e89896700cf88915bd2dc9dfffc1143a81c7170cbb84c",
		"rocking_chair": "f6b00201118422480e0a4fafbdc071ff64fbb4aec11041034f8f721cd3cc91e1",
	}
	var stage1e_hashes := {
		"workbench": "c48a78418b85b14ddc8cb4a59f0af520db48a6d191cd72848de046aa10345303",
		"record_player": "067820e5123e52111e8af6dc819fd0212c37a01c497604d6263355d6f50f3873",
	}
	_expect(
		FileAccess.get_sha256("res://assets/art/death-camp-background.png")
		== "84d4abb92ad0610cff86c0947718fb2c6825cc52a4f6c2856aa790870d28eccf",
		"Death must retain the byte-identical old camp background",
	)
	var base := Image.load_from_file("res://assets/art/camp-2026-09-01/camp-base.png")
	_expect(
		base.get_size() == Vector2i(818, 480) and base.get_format() == Image.FORMAT_RGB8
		and FileAccess.get_sha256("res://assets/art/camp-2026-09-01/camp-base.png")
		== "39441a7e46047593ae01783738b590f4fb8e0e1de24c065f058ec5b7b4a5fa15",
		"New camp base must be one precise 818x480 RGB8 image",
	)
	var manifest_file := FileAccess.open("res://assets/art/camp-2026-09-01/manifest.json", FileAccess.READ)
	var manifest: Dictionary = JSON.parse_string(manifest_file.get_as_text())
	_expect(
		int(manifest.get("schema_version", 0)) == 3
		and not bool(manifest.get("approved_v2_lineage_only", true))
		and bool(manifest.get("base_and_historical_layers_use_approved_v2_lineage_only", false))
		and manifest.get("draw_order", []) == expected_order,
		"Camp manifest must distinguish the independent Storage Chest from historical v2 lineage",
	)
	var source_cells: Array[Rect2] = []
	for module_id in expected_order:
		var path := "res://assets/art/camp-2026-09-01/camp-%s.png" % module_id.replace("_", "-")
		_expect(FileAccess.file_exists(path), "Missing independent camp layer: %s" % module_id)
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(path)
		if historical_hashes.has(module_id):
			_expect(
				FileAccess.get_sha256(path) == historical_hashes[module_id],
				"Historical camp layer must remain byte-identical: %s" % module_id,
			)
		if stage1e_hashes.has(module_id):
			_expect(FileAccess.get_sha256(path) == stage1e_hashes[module_id], "Stage 1E camp correction hash mismatch: %s" % module_id)
		var expected_rect: Rect2 = BaseLayoutScript.CAMP_LAYER_LOCAL_RECTS[module_id]
		var runtime_texture := load(path) as Texture2D
		_expect(
			runtime_texture != null and runtime_texture.get_size() == Vector2(image.get_size()),
			"Godot import cache must match the generated tight source dimensions: %s"
			% module_id,
		)
		_expect(
			image.get_format() == Image.FORMAT_RGBA8
			and image.get_size() == Vector2i(expected_rect.size),
			"Camp layer size/format must match its documented draw rect: %s" % module_id,
		)
		_expect(
			image.get_size() != Vector2i(818, 480) and image.get_used_rect().has_area(),
			"Camp layers must be tight non-empty RGBA crops, never full-screen: %s" % module_id,
		)
		_expect(
			Rect2(Vector2.ZERO, image.get_size()).encloses(Rect2(image.get_used_rect())),
			"Camp layer alpha must remain inside its own draw rect: %s" % module_id,
		)
		var occupied_pixels := 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > (8.0 / 255.0):
					occupied_pixels += 1
		var alpha_coverage := float(occupied_pixels) / float(image.get_width() * image.get_height())
		_expect(
			alpha_coverage < 0.90,
			"Camp layers must be independent silhouettes, not broad opaque scene patches: %s (%0.4f)"
			% [module_id, alpha_coverage],
		)
		_expect(
			image.get_pixel(0, 0).a <= (8.0 / 255.0)
			or image.get_pixel(image.get_width() - 1, 0).a <= (8.0 / 255.0)
			or image.get_pixel(0, image.get_height() - 1).a <= (8.0 / 255.0)
			or image.get_pixel(image.get_width() - 1, image.get_height() - 1).a <= (8.0 / 255.0),
			"Camp layer needs transparent exterior around its owned prop: %s" % module_id,
		)
		if module_id == "storage_chest":
			var storage_record: Dictionary = manifest.layers.storage_chest
			var storage_source: Dictionary = manifest.storage_chest_source
			var used := image.get_used_rect()
			_expect(
				FileAccess.get_sha256(path)
				== "e4728c749eefdddb02aa123130e7af6227805f4b5f690d40f30a732c2d3d020f"
				and image.get_size() == Vector2i(108, 67),
				"Storage Chest runtime must keep its exact hash and 108x67 size",
			)
			_expect(
				used.position == Vector2i(8, 4) and used.end == Vector2i(100, 63),
				"Storage Chest runtime must keep exact tight alpha bounds: %s" % used,
			)
			_expect(
				Array(storage_record.bottom_center_reference).map(func(value): return int(value))
				== [54, 63]
				and int(storage_record.bottom_clearance) == 4,
				"Storage Chest runtime must keep bottom-center (54,63) and 4px clearance",
			)
			_expect(
				storage_source.path == "art/concepts/camp/2026-09-01/storage-chest-master.png"
				and String(storage_source.sha256).to_lower()
				== "9fc7c1d961e2a9b0d13ea967866c3c6b4e91422e044d1eb7e894770238c3d1a3"
				and storage_source.generation == "built-in image_gen"
				and storage_source.generated_result_id == "exec-f4220fc7-adab-4c44-9243-6cd76a83e082"
				and String(storage_source.exact_prompt).contains("low, broad, CLOSED storage chest")
				and storage_record.mask_components == null,
				"Storage Chest must document its honest independent built-in ImageGen source and exact prompt",
			)
			var import_text := FileAccess.get_file_as_string(path + ".import")
			_expect(
				import_text.contains("mipmaps/generate=false")
				and import_text.contains("process/fix_alpha_border=true"),
				"Storage Chest import must disable mipmaps and fix the alpha border",
			)
		else:
			var components: Array = manifest.layers[module_id].mask_components
			_expect(components.size() == 1, "Each historical camp module must own one isolated atlas cell: %s" % module_id)
			if components.size() == 1:
				var xyxy: Array = components[0].source_xyxy
				var source_cell := Rect2(xyxy[0], xyxy[1], xyxy[2] - xyxy[0], xyxy[3] - xyxy[1])
				for other_cell in source_cells:
					_expect(
						not source_cell.intersects(other_cell),
						"Camp atlas source cells must never share neighbor pixels: %s" % module_id,
					)
				source_cells.append(source_cell)
		if module_id in ["crusher", "whetstone"]:
			var component_gate: Dictionary = manifest.layers[module_id].get("component_gate", {})
			_expect(
				component_gate.get("policy", "") == "retain_largest_8_connected_alpha_cluster"
				and int(component_gate.get("output_component_count", 0)) == 1
				and int(component_gate.get("removed_component_count", 0)) > 0
				and _alpha_component_count(image, 0.0) == 1,
				"Standalone workshop layer must pass the strict orphan/component gate: %s"
				% module_id,
			)
			var removed_above_16: Array = component_gate.get("removed_components_above_16", [])
			var expected_removed_pixels := 541 if module_id == "whetstone" else 11
			var documented_removed_component := false
			for component in removed_above_16:
				if int(component.get("pixel_count", 0)) == expected_removed_pixels:
					documented_removed_component = true
					break
			_expect(
				documented_removed_component,
				"%s recipe must document removal of its detached %d-pixel leak"
				% [module_id.capitalize(), expected_removed_pixels],
			)
	var storage_draw := BaseLayoutScript.CAMP_LAYER_LOCAL_RECTS.storage_chest
	var storage_hit := BaseLayoutScript.CAMP_INTERACTIVE_HITBOX_LOCAL_RECTS.storage_chest
	_expect(
		storage_draw == Rect2(224, 392, 108, 67)
		and storage_hit == Rect2(230, 395, 96, 60)
		and BaseLayoutScript.camp_layer_rect("storage_chest") == Rect2(252, 470, 108, 67)
		and BaseLayoutScript.station_hitbox_rect("storage_chest") == Rect2(258, 473, 96, 60),
		"Storage Chest must retain the exact local and Base-origin draw/hit geometry",
	)
	for historical_id in expected_order.slice(0, 12):
		var old_draw: Rect2 = BaseLayoutScript.CAMP_LAYER_LOCAL_RECTS[historical_id]
		_expect(
			not storage_draw.intersects(old_draw) and not storage_hit.intersects(old_draw),
			"Storage Chest geometry must not overlap historical draw rect: %s" % historical_id,
		)
		if BaseLayoutScript.CAMP_INTERACTIVE_HITBOX_LOCAL_RECTS.has(historical_id):
			var old_hit: Rect2 = BaseLayoutScript.CAMP_INTERACTIVE_HITBOX_LOCAL_RECTS[historical_id]
			_expect(
				not storage_draw.intersects(old_hit) and not storage_hit.intersects(old_hit),
				"Storage Chest geometry must not overlap historical service hitbox: %s" % historical_id,
			)
	for service_id in ["crusher", "whetstone", "ritual_table", "kettle", "storage_chest"]:
		_expect(
			BaseLayoutScript.CAMP_INTERACTIVE_HITBOX_LOCAL_RECTS.has(service_id),
			"Existing interactive camp service needs one documented hitbox: %s" % service_id,
		)
	for decorative_id in ["mural", "bunk", "campfire", "workbench", "writing_set", "textile_area", "rocking_chair", "record_player"]:
		_expect(
			not BaseLayoutScript.CAMP_INTERACTIVE_HITBOX_LOCAL_RECTS.has(decorative_id),
			"Decorative camp modules must not invent an interactive service: %s" % decorative_id,
		)
	var workbench_recipe: Dictionary = manifest.layers.workbench.get("stage1e_recipe", {})
	var patch_recipe: Dictionary = workbench_recipe.get("attached_pale_patch", {})
	_expect(BaseLayoutScript.CAMP_LAYER_LOCAL_RECTS.record_player == Rect2(652, 223, 166, 250), "Stage 1E record-player draw rect must remain exact")
	var padding: Array = manifest.layers.record_player.get("stage1e_recipe", {}).get("padding", [])
	var histogram: Dictionary = workbench_recipe.get("cleared_alpha_histogram", {})
	var patch_window: Array = patch_recipe.get("window_xyxy", [])
	var patch_bounds: Array = patch_recipe.get("cleared_inclusive_bbox", [])
	_expect(padding.size() == 4 and int(padding[0]) == 4 and int(padding[1]) == 4 and int(padding[2]) == 3 and int(padding[3]) == 4, "Stage 1E record-player padding recipe must remain exact")
	_expect(int(workbench_recipe.get("cleared_pixel_count", 0)) == 47 and int(histogram.get("1", 0)) == 18 and int(histogram.get("2", 0)) == 29, "Stage 1E workbench exterior matte recipe must retain exact 47 alpha-only clears")
	_expect(int(patch_recipe.get("cleared_pixel_count", 0)) == 457 and patch_window.size() == 4 and int(patch_window[0]) == 64 and int(patch_window[1]) == 107 and int(patch_window[2]) == 136 and int(patch_window[3]) == 131 and patch_bounds.size() == 4 and int(patch_bounds[0]) == 64 and int(patch_bounds[1]) == 107 and int(patch_bounds[2]) == 135 and int(patch_bounds[3]) == 130 and int(patch_recipe.get("retained_brown_or_wood_pixels", 0)) == 269 and bool(patch_recipe.get("alpha_zeroed_rgb_preserved", false)), "Stage 1E workbench attached-halo recipe must retain the exact bounded 457-pixel cleanup")


func _alpha_component_count(image: Image, threshold: float) -> int:
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var count := 0
	for y in range(height):
		for x in range(width):
			var start_index := y * width + x
			if visited[start_index] != 0 or image.get_pixel(x, y).a <= threshold:
				continue
			count += 1
			var pending: Array[Vector2i] = [Vector2i(x, y)]
			visited[start_index] = 1
			while not pending.is_empty():
				var point: Vector2i = pending.pop_back()
				for neighbor_y in range(point.y - 1, point.y + 2):
					for neighbor_x in range(point.x - 1, point.x + 2):
						if neighbor_x == point.x and neighbor_y == point.y:
							continue
						if neighbor_x < 0 or neighbor_y < 0 or neighbor_x >= width or neighbor_y >= height:
							continue
						var neighbor_index := neighbor_y * width + neighbor_x
						if (
							visited[neighbor_index] == 0
							and image.get_pixel(neighbor_x, neighbor_y).a > threshold
						):
							visited[neighbor_index] = 1
							pending.append(Vector2i(neighbor_x, neighbor_y))
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
