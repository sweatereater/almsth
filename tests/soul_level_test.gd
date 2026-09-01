class_name SoulLevelTestSuite
extends RefCounted

const SaveSystem := preload("res://scripts/system/persistence.gd")
const Loc := preload("res://scripts/localization/localization.gd")

const ROOT := "res://.tmp/nightly/soul-level-regression"

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_cleanup()
	_test_rules_and_evolution_gates()
	_test_campfire_and_permanence()
	_test_permanent_jacket_invariants()
	_test_current_soul_roundtrips()
	_test_slot_compatibility()
	await _test_interface(tree)
	_cleanup()
	return failures


func _test_rules_and_evolution_gates() -> void:
	var requirements := {
		"skeleton": 1, "zombie": 1, "ghoul": 2, "revenant": 3, "almost_human": 4,
	}
	_expect(GameRules.SOUL_LEVEL_START == 0 and GameRules.CAMPFIRE_SOUL_LEVEL_BONUS == 1, "Soul Level raw start 0 and Campfire bonus 1 must remain explicit rules")
	for form_id in GameRules.FORM_ORDER:
		_expect(GameRules.required_soul_level(form_id) == requirements[form_id], "Soul Level requirement mismatch for %s" % form_id)

	for index in range(GameRules.FORM_ORDER.size() - 1):
		var current_form: String = GameRules.FORM_ORDER[index]
		var next_form: String = GameRules.FORM_ORDER[index + 1]
		var required := GameRules.required_soul_level(next_form)
		var state := RunState.new()
		state.current_form_id = current_form
		state.absorbed_souls = int(GameRules.FORMS[current_form]["threshold"])
		state.highest_unlocked_form_index = index
		state.soul_level = maxi(0, required - 2)
		state.carried_souls = 999
		state.hp = maxi(1, state.get_max_hp() - 1)
		if required > state.get_effective_soul_level():
			var before := [state.current_form_id, state.absorbed_souls, state.carried_souls, state.hp, state.highest_unlocked_form_index]
			var blocked := state.evolve_at_cradle()
			_expect(
				not bool(blocked.get("ok", true)) and blocked.get("reason") == "soul_level"
				and int(blocked.get("required_soul_level", 0)) == required
				and int(blocked.get("soul_level", 0)) == state.get_effective_soul_level()
				and before == [state.current_form_id, state.absorbed_souls, state.carried_souls, state.hp, state.highest_unlocked_form_index],
				"%s → %s must fail by effective Soul Level without mutation" % [current_form, next_form],
			)
		state.soul_level = maxi(0, required - 1)
		state.carried_souls = GameRules.evolution_cost(current_form) - 1
		var soul_blocked := state.evolve_at_cradle()
		_expect(not bool(soul_blocked.get("ok", true)) and soul_blocked.get("reason") == "souls", "Soul checks must follow the Soul Level gate for %s" % next_form)
		state.carried_souls += 1
		_expect(bool(state.evolve_at_cradle().get("ok", false)) and state.current_form_id == next_form, "Eligible evolution must reach %s" % next_form)

	var maximum := RunState.new()
	maximum.current_form_id = "almost_human"
	maximum.soul_level = 1
	_expect(maximum.evolve_at_cradle().get("reason") == "maximum", "Maximum-form rejection must precede all other evolution gates")


func _test_campfire_and_permanence() -> void:
	var state := RunState.new()
	_expect(state.soul_level == 0 and state.get_effective_soul_level() == 1, "Fresh state must keep raw Soul Level 0 and display effective 1")
	state.resources = {"wood": 3, "stone": 3, "cloth": 0}
	state.hp = maxi(1, state.get_max_hp() - 2)
	var old_hp := state.hp
	var old_max_hp := state.get_max_hp()
	var built := state.build_camp_upgrade("campfire")
	_expect(
		bool(built.get("ok", false)) and state.soul_level == 1
		and state.get_effective_soul_level() == 2
		and state.hp == old_hp and state.get_max_hp() == old_max_hp,
		"Campfire must grant one Soul Level without maximum-HP contribution or healing",
	)
	_expect(not bool(state.build_camp_upgrade("campfire").get("ok", false)) and state.soul_level == 1, "Campfire Soul Level must be one-time")
	state.current_form_id = "ghoul"
	state.highest_unlocked_form_index = 2
	state.die()
	_expect(state.soul_level == 1, "Death must never reduce permanent Soul Level")
	_expect(state.get_effective_soul_level() == 2, "Death must preserve the one canonical jacket Soul Level bonus")


func _test_permanent_jacket_invariants() -> void:
	var state := RunState.new()
	state.configure_character("Jacket Invariants", GameRules.default_attributes())
	var jacket_key := GameRules.permanent_jacket_key()
	_expect(state.loadout.get("jacket", "") == jacket_key, "Fresh state must equip the canonical jacket")
	_expect(state.get_soul_bonus() == 0 and state.add_souls(3) == 3, "The jacket Soul Level bonus must not change per-kill soul rewards")
	_expect(not GameRules.available_equipment_ids(1).has(GameRules.PERMANENT_JACKET_ITEM_ID), "Permanent jacket must never enter the loot pool")
	_expect(state.add_item(GameRules.PERMANENT_JACKET_ITEM_ID) == "" and state.add_item_key(jacket_key) == "", "Public inventory additions must reject the jacket")
	_expect(not state.equip(jacket_key, "jacket").get("ok", true), "Direct equip must not replace the canonical jacket")
	_expect(not state.unequip("jacket").get("ok", true) and state.loadout.get("jacket", "") == jacket_key, "Unequip must not remove the canonical jacket")
	state.camp_upgrades.crusher = true
	state.camp_upgrades.whetstone = true
	state.camp_upgrades.ritual_table = true
	state.banked_souls = 100
	_expect(not state.can_bind_item(jacket_key, "equipped", "jacket"), "Jacket must not be bindable")
	_expect(not state.bind_item(jacket_key, "equipped", "jacket").get("ok", true), "Binding mutation must reject the jacket")
	_expect(not state.dismantle_item(jacket_key).get("ok", true), "Dismantle mutation must reject the jacket")
	_expect(not state.upgrade_weapon(jacket_key, 0.0, 0.0, "jacket").get("ok", true), "Upgrade mutation must reject the jacket")
	state.inventory[jacket_key] = 3
	state.loadout["right_hand"] = jacket_key
	var saved := state.to_save_data()
	_expect(not state.inventory.has(jacket_key) and not state.loadout.has("right_hand") and state.loadout.get("jacket", "") == jacket_key, "Current malformed duplicates must sanitize to exactly one canonical jacket")
	var roundtrip := RunState.new()
	_expect(roundtrip.restore_save_data(saved) and roundtrip.soul_level == state.soul_level and roundtrip.get_effective_soul_level() == state.get_effective_soul_level(), "Jacket and effective Soul Level must remain stable through a save roundtrip")
	var second := RunState.new()
	_expect(second.restore_save_data(roundtrip.to_save_data()) and second.get_effective_soul_level() == roundtrip.get_effective_soul_level(), "Two save roundtrips must not stack the jacket bonus")
	var malformed := RunState.new()
	_expect(malformed.restore_save_data({
		"character_name": "Malformed Jacket",
		"soul_level": 1,
		"inventory": {jacket_key: 4},
		"loadout": {"jacket": "bone_knife@0", "left_hand": jacket_key},
	}), "Malformed jacket save must restore")
	_expect(malformed.loadout.get("jacket", "") == jacket_key and malformed.inventory.get("bone_knife@0", 0) == 1 and not malformed.inventory.has(jacket_key), "Restore must return a displaced valid item and remove jacket duplicates")
	var before_death_effective := malformed.get_effective_soul_level()
	var returning := RunState.new()
	_expect(returning.restore_save_data(malformed.to_save_data()), "Safe-return jacket fixture must restore")
	returning.safe_return()
	_expect(returning.loadout.get("jacket", "") == jacket_key and returning.get_effective_soul_level() == before_death_effective, "Safe return must preserve the canonical jacket and its one effective bonus")
	var death := malformed.die()
	_expect(int(death.get("items", -1)) == 1 and malformed.get_effective_soul_level() == before_death_effective and malformed.loadout.get("jacket", "") == jacket_key, "Death must not count or lose the jacket")


func _test_current_soul_roundtrips() -> void:
	var state := RunState.new()
	state.configure_character("Current Soul v17", GameRules.default_attributes())
	state.resources = {"wood": 3, "stone": 3, "cloth": 0}
	_expect(bool(state.build_camp_upgrade("campfire").get("ok", false)), "Current Campfire fixture must build")
	state.resources.wood = 30
	_expect(bool(state.build_camp_upgrade("rocking_chair").get("ok", false)), "Current Rocking Chair fixture must build")
	state.record_enemy_defeat("minotaur")
	state.resources = {"wood": 12, "stone": 20, "cloth": 5}
	state.banked_souls = 60
	_expect(bool(state.build_camp_upgrade("mural").get("ok", false)), "Current Mural fixture must build")
	_expect(
		state.soul_level == 3 and state.get_effective_soul_level() == 4,
		"Campfire, Mural and Rocking Chair plus jacket must produce raw/effective 3/4",
	)
	var saved := state.to_save_data()
	var restored := RunState.new()
	_expect(
		restored.restore_save_data(saved)
		and restored.soul_level == 3 and restored.get_effective_soul_level() == 4,
		"Current v17 state-only roundtrip must preserve all one-time Soul sources exactly",
	)
	var before := restored.to_snapshot_data()
	var missing_sex := saved.duplicate(true)
	missing_sex.erase("character_sex")
	_expect(
		not restored.restore_save_data(missing_sex) and restored.to_snapshot_data() == before,
		"Current v17 data without character sex must reject without replay or mutation",
	)


func _test_slot_compatibility() -> void:
	var state := RunState.new()
	state.configure_character("Version Seventeen", GameRules.default_attributes())
	state.soul_level = 5
	_expect(bool(SaveSystem.save_slot(state, "soul-v17", "overwrite", ROOT, 900).get("ok", false)), "Current v17 Soul Level slot must save")
	var loaded := SaveSystem.load_slot("soul-v17", ROOT)
	var restored := RunState.new()
	_expect(bool(loaded.get("ok", false)) and restored.restore_save_data(loaded.get("state", {})) and restored.soul_level == 5, "Current v17 Soul Level slot must roundtrip")

	var legacy_state := {"character_name": "V8 Campfire", "highest_unlocked_form_index": 2, "camp_upgrades": {"campfire": true}}
	_write_text(ROOT + "/soul-v8.json", JSON.stringify({
		"envelope_version": SaveSystem.SLOT_ENVELOPE_VERSION,
		"version": 8,
		"metadata": {"slot_id": "soul-v8", "updated_at": 800, "character_name": "V8 Campfire", "lifetime_souls_earned": 0, "save_policy": "overwrite"},
		"state": legacy_state,
	}))
	var loaded_v8 := SaveSystem.load_slot("soul-v8", ROOT)
	var restored_v8 := RunState.new()
	_expect(not bool(loaded_v8.get("ok", false)) and restored_v8.soul_level == GameRules.SOUL_LEVEL_START, "Old v8 test slot is excluded without granting progression")


func _test_interface(tree: SceneTree) -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.character_name = "Soul UI"
	main.state.soul_level = 1
	main._show_base("")
	main._show_character()
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		main._apply_locale()
		main._select_character_panel("skills")
		_expect(not main.character_soul_level_label.visible, "Skills mode must reserve the full card and hide Soul Level stats in %s" % locale)
		main._select_character_panel("inventory")
		_expect(main.character_soul_level_label.visible and main.character_soul_level_label.text.contains("2"), "Effective Soul Level label must be visible in %s inventory mode" % locale)
		for key in ["MSG_CRADLE_NEEDS_SOUL_LEVEL", "CRADLE_CONFIRM_LEVEL_BLOCKED", "SOUL_LEVEL_LABEL", "MSG_CAMPFIRE_SOUL_LEVEL"]:
			_expect(Loc.STRINGS[locale].has(key), "Soul Level localization %s missing in %s" % [key, locale])
	main._close_character()
	main.screen = main.Screen.DUNGEON
	main._load_floor(99)
	main.state.current_form_id = "ghoul"
	main.state.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
	main.state.carried_souls = 99
	main.floor_data["cradle_used"] = false
	main._open_cradle_confirmation()
	_expect(main.cradle_confirmation_confirm_button.disabled and main.cradle_confirmation_description_label.text.contains("2"), "Cradle confirmation must distinctly block an insufficient Soul Level")
	main.state.soul_level = 2
	main._refresh_cradle_confirmation_interface()
	_expect(not main.cradle_confirmation_confirm_button.disabled, "Cradle confirmation must enable once both Soul Level and souls are sufficient")
	main.queue_free()
	await tree.process_frame
	Loc.set_locale("ru")


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.flush()


func _cleanup() -> void:
	_remove_tree(ROOT)


func _remove_tree(path: String) -> void:
	assert(path == ROOT or path.begins_with(ROOT + "/"), "Soul-level cleanup escaped its fixed nightly root")
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
