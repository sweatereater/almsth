class_name SaveSlotsTestSuite
extends RefCounted

const SaveSystem := preload("res://scripts/system/persistence.gd")
const Loc := preload("res://scripts/localization/localization.gd")

const ROOT := "res://.tmp/save-slots-regression"
const LEGACY_PATH := ROOT + "/legacy.json"
const SLOTS_PATH := ROOT + "/slots"

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_cleanup()
	_test_lifetime_counter()
	_test_atomic_backup_and_listing()
	_test_legacy_import_once()
	_test_failure_does_not_publish_slot()
	_test_permanent_slot_deletion()
	await _test_main_and_panel(tree)
	_cleanup()
	return failures


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
		and int((recovered.get("state", {}) as Dictionary).get("lifetime_souls_earned", 0)) == 5
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
	var imported := SaveSystem.import_legacy_once(LEGACY_PATH, SLOTS_PATH, 300, func() -> String: return "legacy-slot")
	_expect(bool(imported.get("ok", false)) and bool(imported.get("imported", false)), "A valid v1 legacy save must import once")
	var imported_load := SaveSystem.load_slot("legacy-slot", SLOTS_PATH)
	_expect(
		bool(imported_load.get("ok", false))
		and int((imported_load.get("state", {}) as Dictionary).get("lifetime_souls_earned", 0)) == 33,
		"Legacy import must preserve state and establish its lower-bound lifetime total",
	)
	var count_before := SaveSystem.list_slots(SLOTS_PATH).size()
	var repeated := SaveSystem.import_legacy_once(LEGACY_PATH, SLOTS_PATH, 400, func() -> String: return "duplicate")
	_expect(
		bool(repeated.get("ok", false)) and not bool(repeated.get("imported", true))
		and SaveSystem.list_slots(SLOTS_PATH).size() == count_before,
		"Legacy import must not duplicate a save on later startups",
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
		"version": 1, "state": {"character_name": "Imported Delete", "absorbed_souls": 1},
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
	main.legacy_save_path = ROOT + "/missing-legacy.json"
	var ids := ["single", "history-a", "history-b", "history-c"]
	var times := [1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800]
	main.save_id_factory = func() -> String: return String(ids.pop_front())
	main.save_time_provider = func() -> int: return int(times.pop_front())
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
	await _push_key(main, tree, KEY_DOWN)
	_expect(main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.new_game_button, "Keyboard arrows must navigate startup controls")
	main.save_menu_panel.continue_button.grab_focus()
	await _push_gamepad(main, tree, JOY_BUTTON_DPAD_DOWN)
	_expect(main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.new_game_button, "Gamepad D-pad must navigate startup controls")
	await _click(main, tree, main.save_menu_panel.load_button.get_global_rect().get_center())
	_expect(main.save_menu_panel.list_mode, "Mouse input must open the explicit save list")
	main.save_menu_panel.slot_buttons[-1].grab_focus()
	await _push_key(main, tree, KEY_DOWN)
	_expect(main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.next_button, "Keyboard focus must reach the next-page control")
	main.save_menu_panel.slot_buttons[-1].grab_focus()
	await _push_gamepad(main, tree, JOY_BUTTON_DPAD_DOWN)
	_expect(main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.next_button, "Gamepad focus must reach the next-page control")
	await _click(main, tree, main.save_menu_panel.next_button.get_global_rect().get_center())
	await tree.process_frame
	_expect(main.save_menu_panel.page == 1 and main.save_menu_panel.slot_buttons.size() == 2, "Mouse pagination must expose the seventh and eighth saves")
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
	await _panel_action(main.save_menu_panel, tree, "ui_cancel")
	_expect(
		not main.save_menu_panel.delete_modal_open
		and main.get_viewport().gui_get_focus_owner() == main.save_menu_panel.trash_buttons[0],
		"Esc/B must cancel deletion and restore the original Trash focus",
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
	main.save_menu_panel.settings_button.pressed.emit()
	_expect(
		main.settings_open and not main.save_menu_panel.visible
		and main.settings_new_game_button.visible
		and not main.settings_exit_button.visible,
		"Settings opened from the main menu must replace only the top menu layer",
	)
	main._close_settings()
	_expect(
		main.main_menu_open and main.save_menu_panel.visible and not main.settings_open,
		"Settings Back must return to the main menu rather than gameplay",
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

	# Save failure is localized and never advances the active id.
	var valid_factory: Callable = main.save_id_factory
	main.active_save_slot_id = ""
	main.save_id_factory = func() -> String: return "../invalid"
	_expect(not main._save_game_at_base("death"), "Unwritable injected path must surface a save failure")
	_expect(main.active_save_slot_id.is_empty() and not main.last_save_error.is_empty(), "Failed saves must not advance active ids and must expose localized feedback")
	main.save_id_factory = valid_factory

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
		"Injected dungeon Exit must request shutdown once without publishing a dungeon snapshot",
	)
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


func _floor_fixture() -> Dictionary:
	var tiles := {}
	for y in range(5):
		for x in range(5):
			tiles[Vector2i(x, y)] = "floor"
	return {
		"width": 5, "height": 5, "tiles": tiles, "start": Vector2i(1, 1),
		"base_gate": Vector2i(0, 0), "exit": Vector2i(4, 4), "exit_known": false,
		"cradle": Vector2i(-1, -1), "items": [], "enemies": [],
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


func _push_key(main, tree: SceneTree, keycode: Key) -> void:
	var action := "ui_down" if keycode == KEY_DOWN else "ui_up"
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	var handled: bool = main.save_menu_panel.handle_input(press)
	_expect(handled, "Startup panel must consume synthetic keyboard navigation")
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
