class_name StorageUiTestSuite
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const PanelClass := preload("res://scripts/ui/storage_panel.gd")
const SaveSystem := preload("res://scripts/system/persistence.gd")
const TEST_ROOT := "res://.tmp/storage-ui-test-stage1c"

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_cleanup(TEST_ROOT)
	_test_presentation_model()
	await _test_panel_and_main_integration(tree)
	_cleanup(TEST_ROOT)
	Loc.set_locale("ru")
	return failures


func _test_presentation_model() -> void:
	var expected_filters: Array[String] = ["all"]
	expected_filters.append_array(GameRules.EQUIPMENT_CATEGORY_ORDER)
	_expect(
		PanelClass.available_filter_order() == expected_filters,
		"Storage filters must derive from the centralized category registry",
	)
	var state := RunState.new()
	state.camp_upgrades.storage_chest = true
	state.inventory = {
		"rotting_mail@0": 1,
		"bone_knife@3:bound": 2,
		"aiming_ring@0": 4,
		GameRules.permanent_jacket_key(): 1,
	}
	state.inventory_marks = {"bone_knife@3:bound": "keep"}
	state.storage = {"bone_bow@2": 3}
	state.storage_marks = {"bone_bow@2": "salvage"}
	var inventory_entries := PanelClass.build_entries(state, "inventory", "all")
	var inventory_keys := PackedStringArray()
	for entry in inventory_entries:
		inventory_keys.append(String(entry.key))
	_expect(
		inventory_keys == PackedStringArray(["bone_knife@3:bound", "rotting_mail@0", "aiming_ring@0"])
		and String(inventory_entries[0].mark) == "keep",
		"Storage rows must sort by canonical category/key, preserve bound identity/marks, and exclude permanent gear",
	)
	_expect(
		PanelClass.build_entries(state, "storage", "weapon").size() == 1
		and PanelClass.build_entries(state, "storage", "ring").is_empty(),
		"The shared category filter must apply independently to both lists",
	)
	for locale in Loc.SUPPORTED_LOCALES:
		for key in [
			"CAMP_STORAGE_CHEST", "CAMP_STORAGE_CHEST_DESC",
			"CAMP_OBJECT_STORAGE_CHEST", "CAMP_OBJECT_STORAGE_CHEST_TOOLTIP",
			"STORAGE_TITLE", "STORAGE_PLAYER_INVENTORY", "STORAGE_HEADING",
			"STORAGE_EMPTY", "STORAGE_EMPTY_FILTER", "STORAGE_MOVE_ONE_TOOLTIP",
			"STORAGE_MOVE_ALL_TO_STORAGE", "STORAGE_MOVE_ALL_TO_INVENTORY",
			"STORAGE_REASON_ITEM", "STORAGE_SAVE_FAILED", "STORAGE_CLOSE",
		]:
			_expect(Loc.STRINGS[locale].has(key), "Storage localization %s missing in %s" % [key, locale])
	_expect(
		Loc.STRINGS.ru.CAMP_STORAGE_CHEST == "Сундук хранения"
		and Loc.STRINGS.ru.CAMP_BUILD_STORAGE_CHEST == "Сундук хранения: дерево 20, камень 4, ткань 3"
		and Loc.STRINGS.ru.CAMP_BUILT_STORAGE_CHEST == "Сундук хранения построен"
		and Loc.STRINGS.ru.CAMP_OBJECT_STORAGE_CHEST == "Сундук хранения\nОткрыть [Enter / A]"
		and Loc.STRINGS.ru.STORAGE_REASON_UNBUILT == "Сначала постройте сундук хранения."
		and Loc.STRINGS.en.CAMP_STORAGE_CHEST == "Storage Chest"
		and Loc.STRINGS.en.CAMP_BUILD_STORAGE_CHEST == "Storage Chest: wood 20, stone 4, cloth 3"
		and Loc.STRINGS.en.CAMP_BUILT_STORAGE_CHEST == "Storage Chest built"
		and Loc.STRINGS.en.CAMP_OBJECT_STORAGE_CHEST == "Storage Chest\nOpen [Enter / A]"
		and Loc.STRINGS.en.STORAGE_REASON_UNBUILT == "Build the Storage Chest first.",
		"Storage Chest must use the exact canonical RU name in every player-facing label while EN stays unchanged",
	)


func _test_panel_and_main_integration(tree: SceneTree) -> void:
	Loc.set_locale("en")
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	if main.get_script() == null:
		failures.append("Main script failed to load")
		main.queue_free()
		return
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.configure_character("Storekeeper", GameRules.default_attributes())
	main.state.inventory.clear()
	main.state.inventory_marks.clear()
	main.state.storage.clear()
	main.state.storage_marks.clear()
	main.state.add_item("bone_knife", 3, 5)
	main.state.add_item("rotting_mail", 0, 2)
	main.state.set_item_mark("bone_knife@3", "keep")
	main._show_base("", "none")
	await tree.process_frame
	_expect(
		not main.storage_chest_object_button.visible,
		"An unbuilt Storage Chest must have no rendered/focusable Base service",
	)
	main._open_storage_panel()
	_expect(not main.storage_panel.visible, "Unbuilt Storage Chest service must reject programmatic access")
	main.state.resources = {"wood": 20, "stone": 4, "cloth": 3}
	var build_result: Dictionary = main.state.build_camp_upgrade("storage_chest")
	main._refresh_interface()
	_expect(
		bool(build_result.get("ok", false))
		and main.storage_chest_object_button.visible
		and main.storage_chest_object_button.focus_mode == Control.FOCUS_ALL,
		"Built chest must become a visible and focusable Base-only service",
	)
	main.storage_chest_object_button.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	var panel: StoragePanel = main.storage_panel
	_expect(
		panel.visible
		and not main.start_button.visible
		and panel.inventory_heading.text == Loc.text("STORAGE_PLAYER_INVENTORY")
		and panel.storage_heading.text == Loc.text("STORAGE_HEADING")
		and panel.filter_buttons.size() == 1 + GameRules.EQUIPMENT_CATEGORY_ORDER.size()
		and panel.storage_empty_label.visible,
		"Storage must open as a blocking two-list modal with shared categories and an explicit empty state",
	)
	_expect(
		not panel.close_button.accessibility_name.is_empty()
		and not panel.inventory_previous_button.accessibility_name.is_empty()
		and not panel.storage_next_button.accessibility_name.is_empty(),
		"Storage close and paging controls must expose localized accessible labels",
	)
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		panel.apply_locale()
		await tree.process_frame
		var offhand_filter: Button = panel.filter_buttons.offhand
		var compact_label := Loc.text("SLOT_OFFHAND")
		var full_label := Loc.text(String(GameRules.EQUIPMENT_CATEGORY_NAMES.offhand))
		var expected_compact := "Вторая рука" if locale == "ru" else "Off hand"
		var label_width := offhand_filter.get_theme_font("font").get_string_size(
			offhand_filter.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			offhand_filter.get_theme_font_size("font_size"),
		).x
		var content_width := (
			offhand_filter.size.x
			- offhand_filter.get_theme_stylebox("normal").get_minimum_size().x
		)
		_expect(
			offhand_filter.text == compact_label
			and offhand_filter.text == expected_compact
			and offhand_filter.tooltip_text == Loc.text("STORAGE_FILTER_TOOLTIP", [full_label])
			and offhand_filter.accessibility_name == offhand_filter.tooltip_text
			and label_width <= content_width,
			"Storage Off Hand filter must use its compact visible %s label without ellipsis while tooltip/accessibility retain the full category wording"
			% locale,
		)
	Loc.set_locale("en")
	panel.apply_locale()
	await tree.process_frame
	var initial_state: Dictionary = main.state.to_save_data()
	var initial_rng_state: int = main.rng.state
	main._open_camp_build_panel()
	main._show_character()
	main._open_inventory_service("crusher")
	_expect(
		panel.visible and not main.camp_build_panel.visible
		and main.screen == main.Screen.BASE and main.inventory_service_mode.is_empty(),
		"Storage modal must not coexist with Build, Character, or another Base service",
	)
	await _click(main, tree, main.start_button.position + Vector2(8, 8))
	_expect(panel.visible and not main.expedition_choice_open, "Storage shade must block mouse click-through")
	var knife_inventory_index := _visible_index(panel, "inventory", "bone_knife@3")
	_expect(knife_inventory_index >= 0, "Storage fixture must expose the upgraded knife stack")
	if knife_inventory_index >= 0:
		await _click(main, tree, panel.inventory_rows[knife_inventory_index].get_global_rect().get_center())
	_expect(
		int(main.state.inventory.get("bone_knife@3", 0)) == 4
		and int(main.state.storage.get("bone_knife@3", 0)) == 1
		and main.state.inventory_marks.get("bone_knife@3", "") == "keep"
		and main.state.storage_marks.get("bone_knife@3", "") == "keep",
		"Mouse row activation must move exactly one and copy the source mark to the moved part",
	)
	var knife_storage_index := _visible_index(panel, "storage", "bone_knife@3")
	if knife_inventory_index >= 0 and knife_storage_index >= 0:
		var navigation_state: Dictionary = main.state.to_save_data()
		panel.inventory_rows[knife_inventory_index].grab_focus()
		await _push_key(main, tree, KEY_RIGHT)
		var keyboard_reached_storage := panel.storage_rows[knife_storage_index].has_focus()
		await _push_gamepad(main, tree, JOY_BUTTON_DPAD_LEFT)
		_expect(
			keyboard_reached_storage
			and panel.inventory_rows[knife_inventory_index].has_focus()
			and main.state.to_save_data() == navigation_state,
			"Keyboard arrows and native gamepad D-pad must navigate within Storage without mutation",
		)
	if knife_storage_index >= 0:
		await _touch(main, tree, panel.storage_rows[knife_storage_index].get_global_rect().get_center())
	_expect(
		int(main.state.inventory.get("bone_knife@3", 0)) == 5
		and not main.state.storage.has("bone_knife@3"),
		"Real ScreenTouch row activation must move exactly one back to Player Inventory",
	)
	knife_inventory_index = _visible_index(panel, "inventory", "bone_knife@3")
	if knife_inventory_index >= 0:
		panel.inventory_rows[knife_inventory_index].grab_focus()
		await tree.process_frame
		panel.move_to_storage_button.grab_focus()
		await _push_gamepad(main, tree, JOY_BUTTON_A)
	_expect(
		not main.state.inventory.has("bone_knife@3")
		and int(main.state.storage.get("bone_knife@3", 0)) == 5
		and panel.selected_item_source() == "storage",
		"Gamepad A on the valid directional arrow must move the entire selected stack and follow it",
	)
	knife_storage_index = _visible_index(panel, "storage", "bone_knife@3")
	if knife_storage_index >= 0:
		panel.storage_rows[knife_storage_index].grab_focus()
		await tree.process_frame
		panel.move_to_inventory_button.grab_focus()
		await _push_action(main, tree, "ui_accept")
	_expect(
		int(main.state.inventory.get("bone_knife@3", 0)) == 5
		and not main.state.storage.has("bone_knife@3")
		and panel.move_to_storage_button.disabled == false
		and panel.move_to_inventory_button.disabled,
		"Keyboard Enter on the valid reverse arrow must move all and enable only the new valid direction",
	)
	# Reentrant same-frame row activations collapse to one synchronous transfer.
	knife_inventory_index = _visible_index(panel, "inventory", "bone_knife@3")
	if knife_inventory_index >= 0:
		for _repeat in range(20):
			panel.inventory_rows[knife_inventory_index].pressed.emit()
	await tree.process_frame
	_expect(
		int(main.state.inventory.get("bone_knife@3", 0)) == 4
		and int(main.state.storage.get("bone_knife@3", 0)) == 1,
		"Rapid/reentrant activation must not duplicate or multiply a stack transfer",
	)
	# Persistence disabled by the test harness keeps a valid in-memory transfer.
	_expect(panel.feedback.contains(Loc.text("STORAGE_HEADING")), "Successful transfer needs localized feedback")
	var close_state: Dictionary = main.state.to_save_data()
	var close_rng_state: int = main.rng.state
	await _push_gamepad(main, tree, JOY_BUTTON_B)
	await tree.process_frame
	_expect(
		not panel.visible
		and main.storage_chest_object_button.visible
		and main.storage_chest_object_button.has_focus()
		and main.state.to_save_data() == close_state
		and main.rng.state == close_rng_state,
		"B must close without mutation and restore focus to the chest object",
	)
	main.storage_chest_object_button.pressed.emit()
	await tree.process_frame
	main.persistence_enabled = true
	main.save_slots_directory = TEST_ROOT
	main.save_id_factory = func() -> String: return "storage-ui-autosave"
	main._transfer_storage_item("inventory", "bone_knife@3", 1)
	var autosaved := SaveSystem.load_slot("storage-ui-autosave", main.save_slots_directory)
	_expect(
		autosaved.get("ok", false)
		and autosaved.get("version") == 18
		and autosaved.get("state", {}).get("inventory") == main.state.inventory
		and autosaved.get("state", {}).get("storage") == main.state.storage,
		"A successful transfer with persistence enabled must publish a current v18 update autosave",
	)
	var before_save_failure := {
		"inventory": main.state.inventory.duplicate(true),
		"inventory_marks": main.state.inventory_marks.duplicate(true),
		"storage": main.state.storage.duplicate(true),
		"storage_marks": main.state.storage_marks.duplicate(true),
	}
	main.save_fault_injector = func(_stage: String) -> bool: return true
	main._transfer_storage_item("inventory", "bone_knife@3", 1)
	_expect(
		main.state.inventory == before_save_failure.inventory
		and main.state.inventory_marks == before_save_failure.inventory_marks
		and main.state.storage == before_save_failure.storage
		and main.state.storage_marks == before_save_failure.storage_marks
		and panel.feedback == Loc.text("STORAGE_SAVE_FAILED"),
		"A failed autosave publication must restore all four stack dictionaries exactly and show localized feedback",
	)
	main.persistence_enabled = false
	main.save_fault_injector = Callable()
	await _push_key(main, tree, KEY_ESCAPE)
	await tree.process_frame
	_expect(
		not panel.visible and main.storage_chest_object_button.has_focus(),
		"Physical Esc must close Storage and restore chest focus",
	)
	main.screen = main.Screen.DUNGEON
	main.storage_chest_object_button.visible = false
	main._open_storage_panel()
	_expect(
		not panel.visible and not main.storage_chest_object_button.visible,
		"Storage service must remain inaccessible and absent in a dungeon",
	)
	_expect(
		initial_state != main.state.to_save_data()
		and initial_rng_state == main.rng.state,
		"Only explicit transfers/building may change state; storage UI operations must not consume RNG",
	)
	main.queue_free()
	await tree.process_frame


func _visible_index(panel: StoragePanel, source: String, item_key: String) -> int:
	var entries: Array = panel.entries_by_source[source]
	var page_value: int = panel.inventory_page if source == "inventory" else panel.storage_page
	for index in range(entries.size()):
		if String(entries[index].key) == item_key:
			var visible_index := index - page_value * panel.PAGE_SIZE
			return visible_index if visible_index >= 0 and visible_index < panel.PAGE_SIZE else -1
	return -1


func _click(main, tree: SceneTree, position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		main.get_viewport().push_input(event, true)
		await tree.process_frame
	for _frame in range(3):
		await tree.process_frame


func _touch(main, tree: SceneTree, position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 3
		event.pressed = pressed
		event.position = position
		main.get_viewport().push_input(event, true)
		await tree.process_frame
	for _frame in range(3):
		await tree.process_frame


func _push_gamepad(main, tree: SceneTree, button_index: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button_index
		event.pressed = pressed
		main.get_viewport().push_input(event, true)
		await tree.process_frame
	for _frame in range(3):
		await tree.process_frame


func _push_action(main, tree: SceneTree, action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		main.get_viewport().push_input(event, true)
		await tree.process_frame
	for _frame in range(3):
		await tree.process_frame


func _push_key(main, tree: SceneTree, keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		main.get_viewport().push_input(event, true)
		await tree.process_frame
	for _frame in range(3):
		await tree.process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _cleanup(path: String) -> void:
	assert(path == TEST_ROOT or path.begins_with(TEST_ROOT + "/"))
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_cleanup(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)
