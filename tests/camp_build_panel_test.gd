class_name CampBuildPanelTestSuite
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	if main.get_script() == null:
		failures.append("Main script failed to load")
		main.queue_free()
		return failures
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.configure_character("Builder", GameRules.default_attributes())
	main._show_base("", "none")
	await tree.process_frame
	_expect(
		main.camp_build_button.visible
		and not main.build_crusher_button.visible
		and not main.build_whetstone_button.visible
		and not main.build_ritual_table_button.visible
		and not main.upgrade_button.visible
		and main.stage1_build_buttons.is_empty(),
		"Base must expose one Build button and no permanent construction list",
	)
	_expect(
		main.stage1_object_buttons.keys() == ["kettle"],
		"Decorative bunk/mural must have no invented hitboxes; kettle preparation remains",
	)
	main.camp_build_button.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	var panel = main.camp_build_panel
	_expect(panel.visible and not main.start_button.visible, "Build modal must block the underlying base actions")
	_expect(
		panel.rows.size() == 11 and not panel.rows.has("mural")
		and panel.rows.has("record_player"),
		"Modal must list every revealed entry, keep mural hidden, and include its last row",
	)
	_expect(
		panel.rows_box.size.y > panel.scroll.size.y,
		"Fixed modal must scroll far enough to reach the final row at 960x540 scaling",
	)
	_expect(panel.rows.writing_set.button.disabled, "Writing Set button must expose its unmet Workbench dependency")
	_expect(
		panel.rows.writing_set.label.text.contains(Loc.text("CAMP_BUILD_STATUS_REQUIRES", [
			Loc.text(String(GameRules.CAMP_UPGRADES.workbench.name)),
		]))
		and panel.rows.campfire.label.text.contains(Loc.text("CAMP_BUILD_STATUS_INSUFFICIENT"))
		and panel.rows.textile_area.label.text.contains(Loc.text("CAMP_BUILD_STATUS_AVAILABLE")),
		"Rows must distinguish prerequisite, insufficient-resource and available statuses",
	)
	_expect(
		main.get_viewport().gui_get_focus_owner() == panel.rows.textile_area.button,
		"Initial modal focus must select the first enabled row, not a disabled entry",
	)
	await _push_gamepad(main, tree, JOY_BUTTON_DPAD_DOWN)
	_expect(
		main.get_viewport().gui_get_focus_owner() == panel.rows.workbench.button,
		"D-pad must navigate only actionable Build rows",
	)
	await _push_action(main, tree, "character_sheet")
	_expect(
		panel.visible and main.screen == main.Screen.BASE,
		"Unrelated actions must not open another screen through the blocking modal",
	)
	await _push_gamepad(main, tree, JOY_BUTTON_START)
	_expect(
		not panel.visible and not main.main_menu_open and main.camp_build_button.has_focus(),
		"Physical Start/game-menu must close only the Build modal and restore focus",
	)
	main.camp_build_button.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	await _click(main, tree, panel.rows.textile_area.button.get_global_rect().get_center())
	_expect(bool(main.state.camp_upgrades.textile_area), "Mouse must activate an available Build row")
	await _touch(main, tree, panel.rows.workbench.button.get_global_rect().get_center())
	_expect(
		bool(main.state.camp_upgrades.workbench)
		and not panel.rows.writing_set.button.disabled
		and main.get_viewport().gui_get_focus_owner() == panel.rows.writing_set.button,
		"Touch must build Workbench, refresh live, unlock Writing Set and advance focus",
	)
	await _push_gamepad(main, tree, JOY_BUTTON_A)
	_expect(
		bool(main.state.camp_upgrades.writing_set)
		and main.get_viewport().gui_get_focus_owner() == panel.rows.record_player.button,
		"Physical A must build the focused row, refresh live and advance to the next actionable row",
	)
	main.state.milestones.minotaur_defeated = true
	main.state.milestones.minotaur_tail_awarded = true
	main.state.trophies.minotaur_tail = 1
	panel.refresh()
	_expect(panel.rows.has("mural"), "Mural row must appear only after the tail is present")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = main.start_button.position + Vector2(4, 4)
	_expect(not panel.handle_input(mouse), "Pointer must remain in GUI dispatch instead of manual double handling")
	await _click(main, tree, mouse.position)
	_expect(panel.visible and not main.expedition_choice_open, "Full-screen modal shade must block pointer click-through")
	await _touch(main, tree, panel.close_button.get_global_rect().get_center())
	await tree.process_frame
	_expect(
		main.camp_build_button.visible and main.camp_build_button.has_focus(),
		"Touch Close must restore base actions and focus to Build",
	)
	main.camp_build_button.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	await _push_gamepad(main, tree, JOY_BUTTON_B)
	_expect(
		not panel.visible and main.camp_build_button.visible and main.camp_build_button.has_focus(),
		"Physical B must close the modal and restore Build focus",
	)
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		main._apply_locale()
		main._refresh_interface()
		var forbidden := "рюкзак" if locale == "ru" else "backpack"
		_expect(
			not main.start_button.tooltip_text.to_lower().contains(forbidden),
			"Start tooltip alone must omit the backpack mention in %s" % locale,
		)
		_expect(
			Loc.text("CAMP_ROCKING_CHAIR_DESC").to_lower().contains("skeleton" if locale == "en" else "скелет"),
			"Rocking Chair identity/Soul description must exist in %s" % locale,
		)
	Loc.set_locale("ru")
	main.queue_free()
	await tree.process_frame
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _push_gamepad(main, tree: SceneTree, button_index: int) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button_index
	press.pressed = true
	main.get_viewport().push_input(press, true)
	await tree.process_frame
	var release := InputEventJoypadButton.new()
	release.button_index = button_index
	release.pressed = false
	main.get_viewport().push_input(release, true)
	for _frame in range(4):
		await tree.process_frame


func _push_action(main, tree: SceneTree, action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	main.get_viewport().push_input(press, true)
	await tree.process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	main.get_viewport().push_input(release, true)
	for _frame in range(4):
		await tree.process_frame


func _click(main, tree: SceneTree, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	main.get_viewport().push_input(press, true)
	await tree.process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	main.get_viewport().push_input(release, true)
	for _frame in range(4):
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
	for _frame in range(4):
		await tree.process_frame
