extends SceneTree

## Fresh Stage 1D-expanded semantic-UI review matrix. This must run with a normal renderer:
## the captured viewport is the actual Main scene and actual Control instances.

const Loc := preload("res://scripts/localization/localization.gd")
const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")
const InputProfile := preload("res://scripts/system/input_bindings.gd")
const SkillTreeIconClass := preload("res://scripts/ui/skill_tree_icon.gd")
const SkillTreePanelClass := preload("res://scripts/ui/skill_tree_panel.gd")

const VIEWPORTS := [Vector2i(1280, 720), Vector2i(960, 540)]
const LOCALES := ["ru", "en"]
const ZOOMS := [44, 66, 88]
const SCENARIOS_PER_PROFILE := 57
const PREVIEW_OUTPUT_ROOT := "res://.tmp/stage1c-previews"
const STAGE1D_HISTORY_SEMANTICS := [
	"neutral", "loot", "incoming", "outgoing",
	"neutral", "loot", "incoming", "outgoing",
]
const STAGE1D_HISTORY_TEXT := {
	"ru": [
		"Коридор тих.", "Найден костяной нож.", "Болт: 3 урона.",
		"Магия попала.", "Дверь открыта.", "Клеймор +3 найден.",
		"Лучник промахнулся.", "Круг: цель А.",
	],
	"en": [
		"Corridor quiet.", "Bone Knife recovered.", "Bolt: 3 damage.",
		"Magic hit.", "Door opened.", "Claymore +3 found.",
		"Archer missed.", "Circle: target A.",
	],
}
const STAGE1D_HISTORY_APPENDS := {
	"ru": [[" Цель Б.", "outgoing"], [" Ответ: 1 урон.", "incoming"]],
	"en": [[" Target B.", "outgoing"], [" Retaliation: 1.", "incoming"]],
}

var output := PREVIEW_OUTPUT_ROOT
var records: Array[Dictionary] = []
var failures: Array[String] = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("_capture")


func _capture() -> void:
	if not _is_safe_preview_output(output):
		push_error("PREVIEW OUTPUT REJECTED: output must resolve exactly to %s" % PREVIEW_OUTPUT_ROOT)
		quit(2)
		return
	output = PREVIEW_OUTPUT_ROOT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	_remove_stale_outputs()
	for viewport_size in VIEWPORTS:
		await _set_viewport_size(viewport_size)
		for locale in LOCALES:
			Loc.set_locale(locale)
			var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
			main.persistence_enabled = false
			main.audio_playback_enabled = false
			main.settings_path = output.path_join("capture-settings-%s-%dx%d.cfg" % [
				locale, viewport_size.x, viewport_size.y,
			])
			main.save_slots_directory = output.path_join("unused-saves")
			root.add_child(main)
			await process_frame
			main.set_process(false)
			main._apply_locale()
			await _capture_profile(main, locale, viewport_size)
			main.queue_free()
			await process_frame

	var expected := VIEWPORTS.size() * LOCALES.size() * SCENARIOS_PER_PROFILE
	if records.size() != expected:
		failures.append("Expected %d fresh captures, wrote %d" % [expected, records.size()])
	_validate_fresh_outputs(expected)
	_write_manifest(expected)
	Loc.set_locale("ru")
	for failure in failures:
		push_error(failure)
	print("STAGE 1D UI PREVIEWS: %d captures, %d failures" % [records.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)


func _is_safe_preview_output(value: String) -> bool:
	# The capture removes stale PNGs. Require both the exact public URI and the
	# exact canonical filesystem root before any directory creation or cleanup.
	# This deliberately rejects traversal and sibling-prefix lookalikes.
	if value != PREVIEW_OUTPUT_ROOT:
		return false
	var resolved := ProjectSettings.globalize_path(value).simplify_path().replace("\\", "/")
	var expected := ProjectSettings.globalize_path(PREVIEW_OUTPUT_ROOT).simplify_path().replace("\\", "/")
	return resolved.nocasecmp_to(expected) == 0


func _capture_profile(main, locale: String, viewport_size: Vector2i) -> void:
	InputProfile.reset_to_defaults()
	var slots := _mixed_slots(locale)
	_reset_overlays(main)
	main._show_startup()
	main.save_menu_panel.set_slots(slots)
	main.save_menu_panel.set_active_slot_id("current-v18")
	main.save_menu_panel.show_startup()
	main.save_menu_panel.continue_button.grab_focus()
	await _save("startup-ready", locale, viewport_size, Palette.WARM_ARCHIVE)

	main.save_menu_panel.close()
	main.main_menu_open = false
	main.state = _base_state(locale, false)
	main._show_base("", "none")
	main._open_main_menu()
	main.save_menu_panel.set_slots(slots)
	main.save_menu_panel.set_active_slot_id("current-v18")
	main.save_menu_panel.show_menu(true)
	await _save("startup-from-game", locale, viewport_size, Palette.WARM_ARCHIVE)

	_reset_overlays(main)
	main._reset_for_new_character()
	main._show_name_creation()
	main.sex_choice_panel.set_sex("female")
	main.sex_choice_panel.buttons.male.grab_focus()
	await _save("sex-female-selected-male-focus", locale, viewport_size, Palette.WARM_ARCHIVE)
	main.sex_choice_panel.set_sex("male")
	main.sex_choice_panel.buttons.female.grab_focus()
	await _save("sex-male-selected-female-focus", locale, viewport_size, Palette.WARM_ARCHIVE)

	main.name_input.text = "Нерождённая" if locale == "ru" else "The Unborn"
	main._on_name_confirmed()
	main.attribute_plus_buttons[GameRules.ATTRIBUTE_ORDER[0]].grab_focus()
	await _save("stat-lower-bounds-focus", locale, viewport_size, Palette.WARM_ARCHIVE)
	var changed_id: String = GameRules.ATTRIBUTE_ORDER[0]
	main.pending_attributes = GameRules.default_attributes()
	main.pending_attributes[changed_id] = (
		int(main.pending_attributes[changed_id]) + GameRules.STARTING_FREE_ATTRIBUTE_POINTS
	)
	main.free_attribute_points = 0
	main._refresh_creation_preview()
	main.attribute_minus_buttons[changed_id].grab_focus()
	await _save("stat-upper-changed-finish", locale, viewport_size, Palette.WARM_ARCHIVE)

	_reset_overlays(main)
	main.state = _base_state(locale, true)
	for index in range(GameRules.ATTRIBUTE_ORDER.size()):
		main.state.attributes[GameRules.ATTRIBUTE_ORDER[index]] = 99999 - index
	main.state.unspent_attribute_points = 5
	main._show_base("", "none")
	await process_frame
	var material_counters: Array[Control] = main.material_resources_strip.focusable_controls()
	if material_counters.size() != 3:
		failures.append("Base maximum-material scenario did not build three real counters")
	else:
		material_counters[1].grab_focus()
		for counter in material_counters:
			var value_font: Font = counter.get("value_font")
			var value_label: Label = counter.get("value_label")
			var measured_width: float = value_font.get_string_size(
				value_label.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
			).x
			if measured_width > value_label.size.x:
				failures.append("Base maximum material value clips: %s" % counter.get("resource_id"))
	await _save(
		"base-materials-max-values-focus", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"maximum_values": 9999, "custom_draw_cached": true, "external_focus": true},
	)
	main.character_button.pressed.emit()
	main.inventory_mode_button.pressed.emit()
	main._refresh_character_sheet()
	main.character_attribute_spend_buttons[GameRules.ATTRIBUTE_ORDER[0]].grab_focus()
	if (
		main.title_label.get_theme_font_size("font_size") != 20
		or main.title_label.get_theme_font("font").get_instance_id()
		!= ThemeController.functional_font("semibold").get_instance_id()
	):
		failures.append("Long character heading did not use Noto Sans SemiBold 20: %s %s" % [
			locale, viewport_size,
		])
	await _save("character-long-name-max-values", locale, viewport_size, Palette.WARM_ARCHIVE)
	main.state.active_statuses = {
		"rested": {"remaining_turns": 312, "temporary_hp": 3},
		"satiated": {"remaining_turns": 227, "temporary_hp": 2},
	}
	main._refresh_character_sheet()
	await process_frame
	var character_status_controls: Array[Control] = main.character_status_strip.focusable_controls()
	if character_status_controls.size() != 2:
		failures.append("Active character status scenario did not build two real chips")
	else:
		character_status_controls[0].grab_focus()
	await _save(
		"character-active-statuses-focus", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"active_statuses": true, "custom_draw_cached": true},
	)

	main.close_character_button.pressed.emit()
	main.settings_controls_button.grab_focus()
	main._open_settings()
	main.background_volume = 0
	main.actions_volume = 100
	main._refresh_settings_interface()
	main.settings_zoom_button.grab_focus()
	await _save("settings-boundaries-focus", locale, viewport_size, Palette.WARM_ARCHIVE)
	main.settings_background_slider.grab_focus()
	await _save(
		"settings-slider-focus", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"semantic_slider": true, "external_focus": true},
	)

	main._open_controls_remap()
	await _save("remap-normal", locale, viewport_size, Palette.WARM_ARCHIVE)
	var capture_action: String = InputProfile.GAMEPLAY_ACTIONS[0]
	main.controls_remap_panel._begin_capture(
		capture_action,
		InputProfile.DEVICE_KEYBOARD,
		main.controls_remap_panel.keyboard_buttons[capture_action],
	)
	await _save("remap-capture", locale, viewport_size, Palette.WARM_ARCHIVE)
	var conflict_event := InputEventKey.new()
	conflict_event.keycode = KEY_S
	conflict_event.physical_keycode = KEY_S
	conflict_event.pressed = true
	main.get_viewport().push_input(conflict_event, true)
	await process_frame
	await _save(
		"remap-conflict-danger", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"required_exact_colors": [
			Palette.color(Palette.WARM_ARCHIVE, "danger").to_html(false),
			Palette.color(Palette.WARM_ARCHIVE, "danger_surface").to_html(false),
		]},
	)
	main.controls_remap_panel.set_open(true)
	main.controls_remap_panel._on_reset_pressed()
	main.controls_remap_panel.reset_button.grab_focus()
	await _save(
		"remap-reset-danger", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"required_exact_colors": [
			Palette.color(Palette.WARM_ARCHIVE, "danger").to_html(false),
			Palette.color(Palette.WARM_ARCHIVE, "danger_surface").to_html(false),
		]},
	)
	main.get_viewport().gui_release_focus()
	var reset_position := _control_screen_center(main.controls_remap_panel.reset_button)
	await _push_mouse_motion(main, reset_position)
	if not main.controls_remap_panel.reset_button.is_hovered():
		failures.append("Actual danger-hover capture did not hover Reset")
	await _save(
		"remap-reset-danger-hover", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"danger_state": "hover", "actual_pointer": true, "required_exact_colors": [
			Palette.color(Palette.WARM_ARCHIVE, "danger").to_html(false),
			Palette.color(Palette.WARM_ARCHIVE, "danger_surface").to_html(false),
		]},
	)
	await _push_mouse_button(main, reset_position, true)
	if not main.controls_remap_panel.reset_button.is_pressed():
		failures.append("Actual danger-pressed capture did not hold Reset pressed")
	await _save(
		"remap-reset-danger-pressed", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"danger_state": "pressed", "actual_pointer": true, "required_exact_colors": [
			Palette.color(Palette.WARM_ARCHIVE, "danger").to_html(false),
			Palette.color(Palette.WARM_ARCHIVE, "danger_surface").to_html(false),
		]},
	)
	await _push_mouse_button(main, reset_position, false)

	_reset_overlays(main)
	main.save_menu_panel.set_slots(slots)
	main.save_menu_panel.set_active_slot_id("current-v18")
	main.save_menu_panel.show_menu(true)
	main.save_menu_panel.show_load_list()
	await process_frame
	main.save_menu_panel.slot_buttons[0].grab_focus()
	await _save("save-mixed-v18-v17-v16-corrupt", locale, viewport_size, Palette.WARM_ARCHIVE)
	main.save_menu_panel.set_error(Loc.text("MSG_SAVE_WRITE_VERIFICATION_FAILED", [ERR_FILE_CORRUPT]))
	_verify_save_error_bounds(main, "error-16")
	await _save(
		"save-diagnostic-error-16", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"diagnostic_bounds_verified": true},
	)
	main.save_menu_panel.set_error("")
	main.save_menu_panel._open_delete_modal(2)
	await process_frame
	main.save_menu_panel.delete_no_button.grab_focus()
	await _save("save-delete-no-default-focus", locale, viewport_size, Palette.WARM_ARCHIVE)
	main.save_menu_panel.delete_yes_button.grab_focus()
	await _save("save-delete-yes-danger-focus", locale, viewport_size, Palette.WARM_ARCHIVE)
	main.save_menu_panel.complete_delete(
		{"ok": false, "error": ERR_CANT_CREATE},
		slots,
		Loc.text("SAVE_MENU_DELETE_ERROR", [ERR_CANT_CREATE]),
	)
	await process_frame
	_verify_save_error_bounds(main, "delete-failure")
	await _save(
		"save-delete-failure-restores-trash", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"diagnostic_bounds_verified": true},
	)

	_reset_overlays(main)
	main.state = _storage_state(locale, true, false)
	main._show_base("", "none")
	main.storage_panel.open_for(main.state)
	await process_frame
	main.storage_panel.inventory_rows[0].grab_focus()
	await _save("storage-populated", locale, viewport_size, Palette.WARM_ARCHIVE)
	main.storage_panel.close()
	main.state = _storage_state(locale, false, false)
	main._show_base("", "none")
	main.storage_panel.open_for(main.state)
	await process_frame
	main.storage_panel.close_button.grab_focus()
	await _save("storage-empty", locale, viewport_size, Palette.WARM_ARCHIVE)
	main.storage_panel.close()
	main.state = _storage_state(locale, true, true)
	main._show_base("", "none")
	main.storage_panel.open_for(main.state)
	await process_frame
	main.storage_panel.storage_rows[0].grab_focus()
	await _save("storage-over-built-camp", locale, viewport_size, Palette.WARM_ARCHIVE)

	main.storage_panel.close()
	await _prepare_dungeon(main, locale)
	main._open_main_menu()
	main.save_menu_panel.set_slots(slots)
	main.save_menu_panel.show_menu(true)
	await _save("dungeon-menu-warm-over-cold", locale, viewport_size, Palette.WARM_ARCHIVE, {"underlay": Palette.COLD_DUNGEON})
	main._resume_from_main_menu()
	main._open_settings()
	main.settings_zoom_button.grab_focus()
	await _save("dungeon-settings-warm-over-cold", locale, viewport_size, Palette.WARM_ARCHIVE, {"underlay": Palette.COLD_DUNGEON})
	main._close_settings()

	for zoom in ZOOMS:
		main.set_dungeon_cell_size(zoom)
		main._open_main_menu()
		main.save_menu_panel.set_slots(slots)
		main.save_menu_panel.show_menu(true)
		await _save(
			"overlay-separation-z%d" % zoom,
			locale,
			viewport_size,
			Palette.WARM_ARCHIVE,
			{"underlay": Palette.COLD_DUNGEON, "dungeon_zoom": zoom, "runtime": true},
		)
		main._resume_from_main_menu()

	var restored_floor: Dictionary = main.floor_data.duplicate(true)
	var restored_player: Vector2i = main.player_pos
	var restored_viewport_modulate: Color = main.dungeon_viewport.modulate
	main.state.active_statuses = {
		"rested": {"remaining_turns": 88, "temporary_hp": 3},
		"satiated": {"remaining_turns": 66, "temporary_hp": 2},
	}
	await _push_action(main, "character_sheet")
	if main.screen != main.Screen.CHARACTER or (
		main.theme.get_instance_id()
		!= ThemeController.theme_for(Palette.COLD_DUNGEON).get_instance_id()
	) or not main.dungeon_viewport.visible or (
		main.inventory_panel.theme.get_instance_id()
		!= ThemeController.theme_for(Palette.WARM_ARCHIVE).get_instance_id()
	):
		failures.append("Actual Dungeon→Character transition did not retain Cold beneath Warm")
	await _save(
		"dungeon-character-warm-shell", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"underlay": Palette.COLD_DUNGEON, "actual_transition": true},
	)
	await _push_joypad(main, JOY_BUTTON_B)
	if (
		main.screen != main.Screen.DUNGEON
		or main.theme.get_instance_id()
		!= ThemeController.theme_for(Palette.COLD_DUNGEON).get_instance_id()
		or main.floor_data != restored_floor
		or main.player_pos != restored_player
		or main.dungeon_viewport.modulate != restored_viewport_modulate
	):
		failures.append("Actual Character→Dungeon transition did not restore the same cold world")
	await _save(
		"dungeon-character-context-restored", locale, viewport_size, Palette.COLD_DUNGEON,
		{"actual_transition": true, "world_unchanged": true},
	)

	for context in [Palette.WARM_ARCHIVE, Palette.COLD_DUNGEON]:
		var sheet := _build_state_sheet(context, locale, viewport_size)
		main.visible = false
		root.add_child(sheet)
		await process_frame
		await _save("state-sheet-%s" % context, locale, viewport_size, context, {"actual_controls": true})
		sheet.queue_free()
		await process_frame
		main.visible = true

	var stage1d_start := records.size()
	await _capture_stage1d_profile(main, locale, viewport_size)
	if records.size() - stage1d_start != 23:
		failures.append("Stage 1D profile must add exactly 23 scenarios, added %d" % [
			records.size() - stage1d_start,
		])


func _capture_stage1d_profile(main, locale: String, viewport_size: Vector2i) -> void:
	# Eight real Character inventory states.
	_reset_overlays(main)
	main.state = _stage1d_inventory_state(locale)
	main._show_base("", "none")
	main._show_character()
	main._select_character_panel("inventory")
	main.inventory_panel.set_filter("all")
	main.inventory_panel.select_item("bone_bow@0", "inventory")
	main.inventory_panel.focus_selected_card()
	await process_frame
	await _save(
		"inventory-all-page1-marks-focus", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"stage1d": true, "aggregate_filter": "all", "selected_focus": true, "marks": ["keep", "salvage"]},
	)

	main.inventory_panel.set_filter("weapons")
	main.inventory_panel.select_item(GameRules.make_item_key("old_claymore", 3, true), "inventory")
	main.inventory_panel.focus_selected_card()
	await process_frame
	if main.inventory_panel.page != 1:
		failures.append("Stage 1D long/bound/upgraded weapon did not resolve to page 2")
	# Preview-only localized copy deliberately exceeds the real 14px card line;
	# item identity, bound state, upgrade and every action path stay real.
	var full_claymore_name := (
		"Старинный церемониальный клеймор архивариуса +3"
		if locale == "ru"
		else "Archivist's Ceremonial Expedition Claymore +3"
	)
	var long_name_evidence := false
	for index in range(main.inventory_panel.row_buttons.size()):
		var row: Button = main.inventory_panel.row_buttons[index]
		var name_label: Label = main.inventory_panel.row_name_labels[index]
		var absolute_index: int = main.inventory_panel.page * main.inventory_panel.PAGE_SIZE + index
		if (
			not row.visible
			or absolute_index >= main.inventory_panel.entries.size()
			or String(main.inventory_panel.entries[absolute_index].get("key", ""))
			!= GameRules.make_item_key("old_claymore", 3, true)
		):
			continue
		name_label.text = full_claymore_name
		row.tooltip_text = "%s\n%s" % [full_claymore_name, row.tooltip_text]
		row.accessibility_name = "%s. %s" % [full_claymore_name, row.accessibility_name]
		var measured_width := name_label.get_theme_font("font").get_string_size(
			full_claymore_name, HORIZONTAL_ALIGNMENT_LEFT, -1,
			name_label.get_theme_font_size("font_size"),
		).x
		long_name_evidence = (
			measured_width > name_label.size.x
			and name_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
			and row.tooltip_text.contains(full_claymore_name)
			and row.accessibility_name.contains(full_claymore_name)
		)
		break
	if not long_name_evidence:
		failures.append("Stage 1D page-2 fixture must visibly ellipsize a genuinely long name while exposing its full tooltip/accessibility")
	await _save(
		"inventory-weapons-page2-long-bound-upgraded", locale, viewport_size, Palette.WARM_ARCHIVE,
		{
			"stage1d": true, "aggregate_filter": "weapons", "page": 2,
			"bound": true, "upgrade": 3, "long_name_ellipsis": true,
			"full_name_accessible": true,
		},
	)
	main.inventory_panel.refresh()

	main.inventory_panel.set_filter("offhand")
	main._refresh_character_sheet()
	main.character_equipment_buttons["left_hand"].grab_focus()
	await process_frame
	if not main.character_equipment_ghosts["left_hand"].visible:
		failures.append("Stage 1D two-handed preview lacks the real Off-hand ghost")
	await _save(
		"inventory-offhand-two-handed-ghost", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"stage1d": true, "aggregate_filter": "offhand", "two_handed_ghost": true},
	)

	main.inventory_panel.select_item("hollow_lantern@0", "inventory")
	main._sync_inventory_panel_state()
	main._on_inventory_equip_pressed()
	await process_frame
	if (
		String(main.state.loadout.get("left_hand", "")) != "hollow_lantern@0"
		or not String(main.state.loadout.get("right_hand", "")).is_empty()
		or int(main.state.inventory.get("bone_bow@2", 0)) < 1
	):
		failures.append("Stage 1D offhand conflict preview did not use the real atomic equip path")
	await _save(
		"inventory-offhand-conflict-resolved", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"stage1d": true, "aggregate_filter": "offhand", "atomic_conflict_resolved": true},
	)

	for spec in [
		["armor", "watchmans_cap@0", "inventory-armor-populated"],
		["accessories", "soul_locket@0", "inventory-accessories-populated"],
		["backpack", "expedition_backpack@0", "inventory-backpack-populated"],
	]:
		main.inventory_panel.set_filter(String(spec[0]))
		main.inventory_panel.select_item(String(spec[1]), "inventory")
		main.inventory_panel.focus_selected_card()
		await process_frame
		await _save(
			String(spec[2]), locale, viewport_size, Palette.WARM_ARCHIVE,
			{"stage1d": true, "aggregate_filter": String(spec[0])},
		)

	main.state = _stage1d_empty_inventory_state(locale)
	main._refresh_character_sheet()
	main.inventory_panel.set_filter("weapons")
	main.inventory_panel.filter_buttons["weapons"].grab_focus()
	await process_frame
	if (
		not main.inventory_panel.entries.is_empty()
		or not main.inventory_panel.previous_button.disabled
		or not main.inventory_panel.next_button.disabled
		or not main.inventory_panel.equip_button.disabled
	):
		failures.append("Stage 1D empty inventory preview does not expose disabled pager/actions")
	await _save(
		"inventory-empty-disabled-actions", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"stage1d": true, "aggregate_filter": "weapons", "empty": true, "disabled_actions": true},
	)
	main._close_character()
	await process_frame

	# Four live skill compositions plus two explicit actual-icon sheets.
	main.state = _stage1d_skill_state(locale)
	main._show_base("", "none")
	main._show_character()
	main._select_character_panel("skills")
	main._select_skill_stage("skeleton")
	main._on_skill_pressed("magic_missile")
	# Opening the character panel restores its tab focus on the next frame. Let
	# that deterministic restore settle, then capture the node's external focus.
	await process_frame
	main.skill_node_buttons["magic_missile"].grab_focus()
	await process_frame
	await _save(
		"skill-skeleton-mixed-states-focus", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"stage1d": true, "skill_states": ["available", "learned", "max", "selected_focus"]},
	)
	main._select_skill_stage("ghoul")
	main._on_skill_pressed("ears")
	main.skill_node_buttons["ears"].grab_focus()
	await process_frame
	await _save(
		"skill-ghoul-three-branches-selected", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"stage1d": true, "branches": 3, "selected_focus": true},
	)
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	main._select_skill_stage("revenant")
	main._on_skill_pressed("nervous_system")
	main.skill_node_buttons["nervous_system"].grab_focus()
	await process_frame
	await _save(
		"skill-revenant-locked-inspection", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"stage1d": true, "locked_inspectable": true, "disabled_purchase_reason": true},
	)
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
	main._select_skill_stage("almost_human")
	main._on_skill_pressed("fundamentals")
	main.skill_node_buttons["fundamentals"].grab_focus()
	await process_frame
	await _save(
		"skill-almost-human-loadout-max", locale, viewport_size, Palette.WARM_ARCHIVE,
		{"stage1d": true, "max": true, "loadout": true, "selected_focus": true},
	)

	for sheet_spec in [
		["skill-state-sheet", _build_skill_state_sheet(locale, viewport_size), "SkillSelectedFocus"],
		["skill-all-icons", _build_skill_all_icons_sheet(locale, viewport_size), "SkillAllIconsFocus"],
	]:
		var sheet: Control = sheet_spec[1]
		main.visible = false
		root.add_child(sheet)
		await process_frame
		var focus_target := sheet.find_child(String(sheet_spec[2]), true, false) as Control
		if focus_target != null:
			focus_target.grab_focus()
		await process_frame
		var sheet_metadata := {"stage1d": true, "actual_skill_icons": true}
		if String(sheet_spec[0]) == "skill-state-sheet":
			var disabled_specimen = sheet.find_child("SkillState_disabled", true, false)
			var disabled_reason := sheet.find_child("SkillDisabledReason", true, false) as Label
			if (
				disabled_specimen == null
				or disabled_reason == null
				or disabled_specimen.visual_state != "disabled"
				or not disabled_specimen.disabled
				or disabled_specimen.accessibility_description != disabled_reason.text
				or disabled_reason.get_theme_font_size("font_size") < 12
			):
				failures.append("Stage 1D state sheet must expose a distinct depressed disabled specimen and reason")
			sheet_metadata["disabled_specimen"] = true
			sheet_metadata["non_color_depressed_geometry"] = true
		await _save(
			String(sheet_spec[0]), locale, viewport_size, Palette.WARM_ARCHIVE,
			sheet_metadata,
		)
		sheet.queue_free()
		await process_frame
		main.visible = true
	main._close_character()
	await process_frame

	# Three Cold HUD zooms with one shared resource dictionary and eight
	# structured newest-first actions, followed by both Warm modals at each zoom.
	await _prepare_stage1d_dungeon(main, locale)
	for zoom in ZOOMS:
		main.set_dungeon_cell_size(zoom)
		await _save(
			"dungeon-cold-hud-resources-history-z%d" % zoom,
			locale,
			viewport_size,
			Palette.COLD_DUNGEON,
			{
				"stage1d": true, "dungeon_zoom": zoom, "history_entries": 8,
				"materials": [0, 9999, 123], "localized_history_bodies": locale,
				"history_fits": true, "hud_identity_visible": true,
			},
		)

	for zoom in ZOOMS:
		main.set_dungeon_cell_size(zoom)
		var floor_before: Dictionary = main.floor_data.duplicate(true)
		var player_before: Vector2i = main.player_pos
		var camera_before: Vector2 = main.dungeon_viewport.camera
		main._show_character()
		main._select_character_panel("inventory")
		main.inventory_panel.set_filter("all")
		main.inventory_panel.select_item("bone_bow@0", "inventory")
		main.inventory_panel.focus_selected_card()
		await process_frame
		await _save(
			"dungeon-inventory-warm-over-cold-z%d" % zoom,
			locale,
			viewport_size,
			Palette.WARM_ARCHIVE,
			{"stage1d": true, "underlay": Palette.COLD_DUNGEON, "dungeon_zoom": zoom, "neutral_scrim": true},
		)
		main._select_character_panel("skills")
		main._select_skill_stage("skeleton")
		main._on_skill_pressed("magic_missile")
		main.skill_node_buttons["magic_missile"].grab_focus()
		await process_frame
		await _save(
			"dungeon-skills-warm-over-cold-z%d" % zoom,
			locale,
			viewport_size,
			Palette.WARM_ARCHIVE,
			{"stage1d": true, "underlay": Palette.COLD_DUNGEON, "dungeon_zoom": zoom, "neutral_scrim": true},
		)
		main._close_character()
		await process_frame
		if (
			main.floor_data != floor_before
			or main.player_pos != player_before
			or main.dungeon_viewport.camera != camera_before
			or main.dungeon_cell_size != zoom
		):
			failures.append("Warm-over-Cold preview changed frozen dungeon at zoom %d" % zoom)


func _reset_overlays(main) -> void:
	main.get_viewport().gui_release_focus()
	main.main_menu_open = false
	main.save_menu_panel.close()
	main.settings_open = false
	main.controls_remap_open = false
	main.controls_remap_panel.set_open(false)
	main._set_controls_visible(main.settings_controls, false)
	if main.storage_panel.visible:
		main.storage_panel.close()
	if main.camp_build_panel.visible:
		main.camp_build_panel.close()
	main.appearance_choice_panel.close()
	main.cradle_confirmation_open = false
	main.boss_warning_open = false
	main.expedition_choice_open = false
	main._set_controls_visible(main.cradle_confirmation_controls, false)
	main._set_controls_visible(main.boss_warning_controls, false)
	main._set_controls_visible(main.expedition_choice_controls, false)


func _base_state(locale: String, maximums: bool) -> RunState:
	var state := RunState.new()
	state.configure_character(
		(
			"Странница Архивов с именем длиннее границ старой летописи"
			if locale == "ru"
			else "The Archive Wanderer Whose Name Outlives the Old Chronicle"
		) if maximums else ("Странница" if locale == "ru" else "Wanderer"),
		GameRules.default_attributes(),
	)
	state.character_sex = "female"
	state.current_form_id = "almost_human"
	state.highest_unlocked_form_index = 4
	state.soul_level = 999 if maximums else 4
	state.carried_souls = 999999 if maximums else 217
	state.banked_souls = 999999 if maximums else 83
	state.lifetime_souls_earned = 999999 if maximums else 300
	state.resources = {"wood": 9999, "stone": 9999, "cloth": 9999}
	state.hp = state.get_max_hp()
	state.mana = state.get_max_mana()
	return state


func _stage1d_inventory_state(locale: String) -> RunState:
	var state := _base_state(locale, false)
	state.current_form_id = "almost_human"
	state.absorbed_souls = int(GameRules.FORMS["almost_human"]["threshold"])
	state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
	state.banked_souls = 999
	for upgrade_id in ["crusher", "whetstone", "ritual_table"]:
		state.camp_upgrades[upgrade_id] = true
	for item_spec in [
		["bone_bow", 0, 1], ["bone_bow", 1, 1], ["bone_bow", 2, 2], ["bone_bow", 3, 1],
		["bone_knife", 0, 4], ["bone_knife", 1, 1],
		["bone_buckler", 0, 1], ["gravediggers_lamp", 0, 1], ["hollow_lantern", 0, 1],
		["watchmans_cap", 0, 1], ["archivists_mask", 0, 1], ["rotting_mail", 0, 2],
		["leather_gloves", 0, 1], ["scouts_trousers", 0, 1], ["pilgrims_boots", 0, 1],
		["soul_locket", 0, 1], ["aiming_ring", 0, 2], ["expedition_backpack", 0, 1],
	]:
		state.add_item(String(item_spec[0]), int(item_spec[1]), int(item_spec[2]))
	state.add_item_key(GameRules.make_item_key("old_claymore", 3, true), 1, "keep")
	state.add_item_key(GameRules.make_item_key("short_crossbow", 3, true), 1)
	state.set_item_mark("bone_bow@0", "keep")
	state.set_item_mark("bone_knife@0", "salvage")
	var equip_result := state.equip_from_inventory("bone_bow@2", "right_hand")
	if not bool(equip_result.get("ok", false)):
		failures.append("Stage 1D inventory fixture could not equip its two-handed weapon")
	state.skill_levels["strong_bones"] = 5
	state.skill_levels["magic_awakening"] = 1
	state.skill_levels["magic_missile"] = 1
	return state


func _stage1d_empty_inventory_state(locale: String) -> RunState:
	var state := _stage1d_inventory_state(locale)
	state.inventory.clear()
	state.inventory_marks.clear()
	state.equipped_marks.clear()
	for slot_id in GameRules.EQUIPMENT_SLOT_ORDER:
		var item_key := String(state.loadout.get(slot_id, ""))
		if item_key.is_empty() or GameRules.is_item_permanent(item_key):
			continue
		state.loadout[slot_id] = ""
	return state


func _stage1d_skill_state(locale: String) -> RunState:
	var state := _base_state(locale, false)
	state.current_form_id = "almost_human"
	state.absorbed_souls = int(GameRules.FORMS["almost_human"]["threshold"])
	state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
	state.banked_souls = 999
	state.skill_levels["strong_bones"] = 5
	state.skill_levels["flexible_joints"] = 1
	state.skill_levels["magic_awakening"] = 1
	state.skill_levels["magic_missile"] = 1
	state.skill_levels["stomach"] = 1
	state.skill_levels["dash"] = 1
	state.skill_levels["choose_appearance"] = 1
	state.skill_levels["fundamentals"] = 1
	state.assign_ability("active_1", "magic_missile")
	state.assign_ability("active_2", "dash")
	return state


func _build_skill_state_sheet(locale: String, viewport_size: Vector2i) -> Control:
	var sheet := Control.new()
	sheet.name = "Stage1DSkillStateSheet"
	sheet.size = Vector2(1280, 720)
	sheet.theme = ThemeController.theme_for(Palette.WARM_ARCHIVE)
	var background := ColorRect.new()
	background.size = sheet.size
	background.color = Palette.color(Palette.WARM_ARCHIVE, "background")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(background)
	var panel := Panel.new()
	panel.position = Vector2(36, 34)
	panel.size = Vector2(1208, 650)
	panel.theme_type_variation = "WarmPanel"
	sheet.add_child(panel)
	var title := Ui.make_label(panel, Vector2(24, 18), Vector2(1160, 34), 20)
	title.text = "%s · %s · %dx%d" % [
		"Состояния навыков" if locale == "ru" else "Skill states",
		locale.to_upper(), viewport_size.x, viewport_size.y,
	]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var state_specs: Array[Dictionary] = [
		{"id": "locked", "state": "locked", "selected": false, "name": "Locked / Замок"},
		{"id": "available", "state": "available", "selected": false, "name": "Available / + Cost"},
		{"id": "learned", "state": "learned", "selected": false, "name": "Learned / ✓"},
		{"id": "max", "state": "max", "selected": false, "name": "MAX / Double"},
		{"id": "selected", "state": "available", "selected": true, "name": "Selected / Soul"},
		{"id": "focused", "state": "available", "selected": false, "name": "Focused / Gold"},
		{"id": "selected_focus", "state": "learned", "selected": true, "name": "Selected + focus"},
		{
			"id": "disabled", "state": "disabled", "selected": false,
			"name": "Отключено / —" if locale == "ru" else "Disabled / —",
		},
	]
	var disabled_reason_text := (
		"Покупка недоступна: форма не открыта"
		if locale == "ru"
		else "Purchase disabled: form is locked"
	)
	for index in range(state_specs.size()):
		var spec: Dictionary = state_specs[index]
		var node := SkillTreeIconClass.new()
		node.name = "SkillSelectedFocus" if spec.id == "selected_focus" else "SkillState_%s" % spec.id
		node.position = Vector2(80 + (index % 4) * 280, 100 + (index / 4) * 210)
		node.size = SkillTreePanelClass.NODE_SIZE
		node.set_presentation(
			"strong_bones", String(spec.name), "passive", String(spec.state),
			bool(spec.selected), spec.state == "available", false, spec.state == "available",
		)
		if spec.id == "disabled":
			node.disabled = true
			node.accessibility_description = disabled_reason_text
		panel.add_child(node)
		if spec.id in ["focused", "selected_focus"]:
			var focus_ring := Panel.new()
			focus_ring.position = Vector2(-4, -4)
			focus_ring.size = node.size + Vector2(8, 8)
			focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			focus_ring.add_theme_stylebox_override(
				"panel", ThemeController.style_for(Palette.WARM_ARCHIVE, "button", "focus"),
			)
			node.add_child(focus_ring)
	var disabled_reason := Ui.make_label(panel, Vector2(870, 420), Vector2(196, 58), 12)
	disabled_reason.name = "SkillDisabledReason"
	disabled_reason.text = disabled_reason_text
	disabled_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disabled_reason.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disabled_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reason := Ui.make_label(panel, Vector2(80, 530), Vector2(1040, 54), 12)
	reason.text = (
		"Покупка отключена: форма ещё не открыта · узел остаётся доступен для осмотра"
		if locale == "ru"
		else "Purchase disabled: form is still locked · node remains inspectable"
	)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return sheet


func _build_skill_all_icons_sheet(locale: String, viewport_size: Vector2i) -> Control:
	var sheet := Control.new()
	sheet.name = "Stage1DSkillAllIcons"
	sheet.size = Vector2(1280, 720)
	sheet.theme = ThemeController.theme_for(Palette.WARM_ARCHIVE)
	var background := ColorRect.new()
	background.size = sheet.size
	background.color = Palette.color(Palette.WARM_ARCHIVE, "background")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(background)
	var title := Ui.make_label(sheet, Vector2(40, 22), Vector2(1200, 42), 20)
	title.text = "%s · 19 / 11 · %s · %dx%d" % [
		"Все значки навыков" if locale == "ru" else "All skill icons",
		locale.to_upper(), viewport_size.x, viewport_size.y,
	]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var all_ids: Array[String] = []
	for stage_id in SkillTreePanelClass.STAGE_ORDER:
		for branch in SkillTreePanelClass.STAGE_BRANCHES[stage_id]:
			for skill_id in branch["nodes"]:
				all_ids.append(String(skill_id))
	if all_ids.size() != 19 or GameRules.BODY_SKILL_IDS.size() != 11:
		failures.append("Stage 1D all-icons sheet requires exact 19/11 registries")
	for index in range(all_ids.size()):
		var skill_id := all_ids[index]
		var rules: Dictionary = GameRules.SKILLS[skill_id]
		var node := SkillTreeIconClass.new()
		node.name = "SkillAllIconsFocus" if index == 0 else "SkillAllIcon_%s" % skill_id
		node.position = Vector2(54 + (index % 5) * 244, 82 + (index / 5) * 146)
		node.size = SkillTreePanelClass.NODE_SIZE
		node.set_presentation(
			skill_id, Loc.text(String(rules.name)), String(rules.get("kind", "passive")),
			"learned" if GameRules.BODY_SKILL_IDS.has(skill_id) else "available",
			index == 0, false, false, false,
		)
		sheet.add_child(node)
	return sheet


func _prepare_stage1d_dungeon(main, locale: String) -> void:
	_reset_overlays(main)
	main.state = _stage1d_inventory_state(locale)
	main.state.begin_expedition(12)
	main.state.resources = {"wood": 0, "stone": 9999, "cloth": 123}
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(10, 7)
	main._hide_game_interface()
	main._set_controls_visible(main.creation_controls, false)
	main._set_controls_visible(main.character_controls, false)
	main._show_dungeon_interface()
	_reveal_floor(main)
	main._apply_locale()
	main.action_history.clear()
	var history_text: Array = STAGE1D_HISTORY_TEXT[locale]
	for index in range(history_text.size()):
		main._log_action(String(history_text[index]), String(STAGE1D_HISTORY_SEMANTICS[index]))
	for append_spec in STAGE1D_HISTORY_APPENDS[locale]:
		main._append_to_latest_action(String(append_spec[0]), String(append_spec[1]))
	main._refresh_interface()
	await process_frame
	if (
		not main.souls_label.visible
		or main.souls_label.text.strip_edges().is_empty()
		or not main.stats_label.visible
		or main.stats_label.text != main.state.character_name
		or not main.sidebar_progress_label.visible
		or not main.sidebar_progress_label.text.contains(
			Loc.text("SOUL_LEVEL_LABEL", [main.state.get_effective_soul_level()])
		)
	):
		failures.append("Stage 1D Cold HUD fixture must visibly populate souls, character name, and Soul Level")
	if main.action_history.size() != 8:
		failures.append("Stage 1D Cold HUD fixture must retain exactly eight action entries")
	for body in history_text:
		if not main.message_label.accessibility_name.contains(String(body)):
			failures.append("Localized Stage 1D history body is missing from accessible text: %s" % body)
	if locale == "ru" and main.message_label.accessibility_name.contains("Corridor quiet"):
		failures.append("Russian Stage 1D history fixture must not contain literal English bodies")
	if main.message_label.get_content_height() > main.message_label.size.y:
		failures.append("All eight Stage 1D history records must fit the visible Cold history region")


func _storage_state(locale: String, populated: bool, all_camp: bool) -> RunState:
	var state := _base_state(locale, false)
	state.camp_upgrades.storage_chest = true
	if all_camp:
		for module_id in GameRules.CAMP_DRAW_ORDER:
			state.camp_upgrades[module_id] = true
	if populated:
		state.add_item("bone_knife", 3, 12)
		state.add_item("rotting_mail", 0, 2)
		state.add_item("aiming_ring", 0, 8)
		state.set_item_mark("bone_knife@3", "keep")
		state.storage["bone_bow@2:bound"] = 3
		state.storage["lamellar_vest@0"] = 2
		state.storage_marks["bone_bow@2:bound"] = "keep"
	return state


func _mixed_slots(locale: String) -> Array[Dictionary]:
	return [
		{
			"slot_id": "current-v18", "updated_at": 1788012300,
			"character_name": "Текущая летопись" if locale == "ru" else "Current Chronicle",
			"lifetime_souls_earned": 8800, "save_policy": "overwrite",
			"version": 18, "compatible": true, "locked": false,
		},
		{
			"slot_id": "legacy-v17", "updated_at": 1787925900,
			"character_name": "Наследие v17" if locale == "ru" else "Legacy v17",
			"lifetime_souls_earned": 1700, "save_policy": "history",
			"version": 17, "compatible": true, "locked": false,
		},
		{
			"slot_id": "unsupported-v16", "updated_at": 1787839500,
			"character_name": "Старая v16" if locale == "ru" else "Old v16",
			"version": 16, "compatible": false, "locked": true,
			"incompatible_version": 16,
		},
		{
			"slot_id": "corrupt-family", "updated_at": 1787753100,
			"character_name": "", "compatible": false, "locked": true,
			"corrupt": true,
		},
		{
			"slot_id": "history-v18-a", "updated_at": 1787666700,
			"character_name": "Запасная летопись" if locale == "ru" else "Reserve Chronicle",
			"lifetime_souls_earned": 720, "save_policy": "history",
			"version": 18, "compatible": true, "locked": false,
		},
		{
			"slot_id": "history-v18-b", "updated_at": 1787580300,
			"character_name": "Шестая летопись" if locale == "ru" else "Sixth Chronicle",
			"lifetime_souls_earned": 360, "save_policy": "history",
			"version": 18, "compatible": true, "locked": false,
		},
	]


func _prepare_dungeon(main, locale: String) -> void:
	_reset_overlays(main)
	main.state = _base_state(locale, false)
	main.state.begin_expedition(12)
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(10, 7)
	main._hide_game_interface()
	main._set_controls_visible(main.creation_controls, false)
	main._set_controls_visible(main.character_controls, false)
	main._show_dungeon_interface()
	_reveal_floor(main)
	main._apply_locale()
	main._refresh_interface()
	await process_frame


func _floor_fixture() -> Dictionary:
	var width := 20
	var height := 14
	var tiles := {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			tiles[cell] = "wall" if x == 0 or y == 0 or x == width - 1 or y == height - 1 else "floor"
	tiles[Vector2i(8, 7)] = "door_closed"
	return {
		"width": width, "height": height, "tiles": tiles,
		"start": Vector2i(10, 7), "base_gate": Vector2i(2, 11),
		"exit": Vector2i(17, 2), "exit_known": true,
		"cradle": Vector2i(17, 11), "cradle_known": true,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [{
			"uid": "stage1c-chest", "id": "bone_knife", "item_id": "bone_knife",
			"pos": Vector2i(12, 7), "wood": 0, "stone": 0, "appearance": "chest",
		}],
		"enemies": [],
		"rooms": [], "decorations": {},
		"visible_cells": {}, "explored_cells": {}, "observed_cells": {},
	}


func _reveal_floor(main) -> void:
	var cells := {}
	for cell in main.floor_data.tiles:
		cells[cell] = true
	main.floor_data.visible_cells = cells.duplicate(true)
	main.floor_data.explored_cells = cells.duplicate(true)
	main.floor_data.observed_cells = cells.duplicate(true)


func _build_state_sheet(context: String, locale: String, viewport_size: Vector2i) -> Control:
	var sheet := Control.new()
	sheet.name = "Stage1CStateSheet_%s" % context
	sheet.size = Vector2(1280, 720)
	sheet.theme = ThemeController.theme_for(context)
	var background := ColorRect.new()
	background.size = sheet.size
	background.color = Palette.color(context, "background")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(background)
	var panel := Panel.new()
	panel.position = Vector2(150, 34)
	panel.size = Vector2(980, 650)
	panel.theme_type_variation = "WarmPanel"
	sheet.add_child(panel)
	var title := Ui.make_label(panel, Vector2(40, 24), Vector2(900, 44), 20)
	title.text = "%s · %s · RU + EN · %dx%d" % [
		"Warm Archive" if context == Palette.WARM_ARCHIVE else "Cold Dungeon",
		locale.to_upper(), viewport_size.x, viewport_size.y,
	]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var states: Array[Dictionary] = [
		{"id": "normal", "text": "Normal / Обычное"},
		{"id": "hover", "text": "Hover / Наведение"},
		{"id": "selected", "text": "✓ Selected / Выбрано"},
		{"id": "focus", "text": "Focus / Фокус"},
		{"id": "selected_focus", "text": "✓ Selected + focus / Выбрано + фокус"},
		{"id": "disabled", "text": "× Unavailable / Недоступно"},
		{"id": "danger", "text": "× Delete / Удалить"},
	]
	for index in range(states.size()):
		var state: Dictionary = states[index]
		var button := Ui.make_button(
			panel, Vector2(150, 82 + index * 76), String(state.text), Vector2(680, 52),
		)
		button.name = "State_%s" % String(state.id)
		Ui.enable_keyboard_focus(button)
		var semantic_state := String(state.id)
		if semantic_state == "selected_focus":
			semantic_state = "selected"
		if semantic_state == "danger":
			button.theme_type_variation = "DangerButton"
		else:
			var style := ThemeController.style_for(context, "button", semantic_state)
			for style_name in ["normal", "hover", "pressed", "hover_pressed"]:
				button.add_theme_stylebox_override(style_name, style)
		if String(state.id) in ["selected", "selected_focus"]:
			button.toggle_mode = true
			button.set_pressed_no_signal(true)
		if String(state.id) == "disabled":
			button.disabled = true
		if String(state.id) in ["focus", "selected_focus"]:
			var focus_ring := Panel.new()
			focus_ring.name = "ExternalFocusOutline"
			focus_ring.position = Vector2.ZERO
			focus_ring.size = button.size
			focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			focus_ring.add_theme_stylebox_override(
				"panel", ThemeController.style_for(context, "button", "focus"),
			)
			button.add_child(focus_ring)
	return sheet


func _set_viewport_size(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	await process_frame
	await process_frame


func _control_screen_center(control: Control) -> Vector2:
	return control.get_screen_transform() * (control.size * 0.5)


func _push_action(main: Control, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	main.get_viewport().push_input(press, true)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await process_frame


func _push_joypad(main: Control, button_index: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button_index
	press.pressed = true
	main.get_viewport().push_input(press, true)
	await process_frame
	var release := InputEventJoypadButton.new()
	release.button_index = button_index
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await process_frame


func _push_mouse_motion(main: Control, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	main.get_viewport().push_input(event, true)
	await process_frame


func _push_mouse_button(main: Control, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = position
	event.global_position = position
	event.pressed = pressed
	main.get_viewport().push_input(event, true)
	await process_frame


func _verify_save_error_bounds(main, scenario: String) -> void:
	var panel = main.save_menu_panel
	var label: Label = panel.error_label
	var measured := label.get_theme_font("font").get_multiline_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_CENTER,
		label.size.x,
		label.get_theme_font_size("font_size"),
	)
	if (
		not panel.error_banner.visible
		or panel.error_banner.size.y < 64.0
		or panel.error_banner.size.y > 72.0
		or measured.y > label.size.y
	):
		failures.append("Save %s text exceeds its multiline banner: %s > %s" % [
			scenario, measured, label.size,
		])
	if panel.slot_buttons.size() != panel.PAGE_SIZE or panel.trash_buttons.size() != panel.PAGE_SIZE:
		failures.append("Save %s must render exactly six load/trash rows" % scenario)
	if not panel.slot_buttons.is_empty():
		var first: Control = panel.slot_buttons[0]
		var last: Control = panel.slot_buttons[-1]
		if (
			first.position.y < panel.error_banner.position.y + panel.error_banner.size.y + 4.0
			or last.position.y + last.size.y > panel.previous_button.position.y - 2.0
		):
			failures.append("Save %s banner overlaps its six-row/paging layout" % scenario)
		var banner_rect := Rect2(panel.error_banner.position, panel.error_banner.size)
		var paging_rects := [
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
				failures.append("Save %s banner intersects row %d" % [scenario, index])
			for paging_rect in paging_rects:
				if paging_rect.intersects(row_rect) or paging_rect.intersects(trash_rect):
					failures.append("Save %s row %d intersects paging/back controls" % [scenario, index])


func _remove_stale_outputs() -> void:
	var directory := DirAccess.open(output)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir() and (
			entry.get_extension().to_lower() == "png" or entry == "manifest.json"
		):
			directory.remove(entry)
		entry = directory.get_next()
	directory.list_dir_end()


func _validate_fresh_outputs(expected: int) -> void:
	var expected_paths := {}
	for record in records:
		var path := "res://" + String(record.path)
		if expected_paths.has(path):
			failures.append("Duplicate preview record: %s" % path)
		expected_paths[path] = true
		if not FileAccess.file_exists(path):
			failures.append("Manifest candidate is missing: %s" % path)
			continue
		if FileAccess.get_sha256(path) != String(record.sha256):
			failures.append("Fresh preview hash changed before manifest write: %s" % path)
		var image := Image.load_from_file(path)
		if image == null or image.get_size() != Vector2i(int(record.width), int(record.height)):
			failures.append("Fresh preview dimensions changed before manifest write: %s" % path)
	var directory := DirAccess.open(output)
	var png_count := 0
	if directory != null:
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if not directory.current_is_dir() and entry.get_extension().to_lower() == "png":
				png_count += 1
				var path := output.path_join(entry)
				if not expected_paths.has(path):
					failures.append("Stale/unmanifested PNG survived capture: %s" % path)
			entry = directory.get_next()
		directory.list_dir_end()
	if png_count != expected or expected_paths.size() != expected:
		failures.append("Fresh PNG set mismatch: files=%d records=%d expected=%d" % [
			png_count, expected_paths.size(), expected,
		])


func _source_hashes() -> Dictionary:
	var paths: Array[String] = []
	for root_path in ["res://scripts", "res://scenes", "res://assets"]:
		_collect_source_files(root_path, paths)
	for explicit_path in [
		"res://project.godot",
		"res://tests/capture_stage1c_ui_preview.gd",
		"res://tools/capture_stage1c_previews.ps1",
	]:
		if FileAccess.file_exists(explicit_path) and not paths.has(explicit_path):
			paths.append(explicit_path)
	paths.sort()
	var result := {}
	for path in paths:
		result[path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	return result


func _collect_source_files(path: String, result: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry not in [".", ".."]:
			var child := path.path_join(entry)
			if directory.current_is_dir():
				_collect_source_files(child, result)
			elif not result.has(child):
				result.append(child)
		entry = directory.get_next()
	directory.list_dir_end()


func _image_contains_exact_color(image: Image, html: String) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).to_html(false) == html:
				return true
	return false


func _save(
	scenario: String,
	locale: String,
	viewport_size: Vector2i,
	context: String,
	extra: Dictionary = {},
) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output.path_join("%s-%dx%d-%s.png" % [
		locale, viewport_size.x, viewport_size.y, scenario,
	])
	if image == null or image.is_empty():
		failures.append("Normal-renderer capture is empty: %s" % path)
		return
	if image.get_size() != viewport_size:
		failures.append("Capture size mismatch for %s: %s" % [path, image.get_size()])
	if image.save_png(path) != OK:
		failures.append("Could not save capture: %s" % path)
		return
	for html in extra.get("required_exact_colors", []):
		if not _image_contains_exact_color(image, String(html)):
			failures.append("Capture %s lacks required exact semantic pixel #%s" % [path, html])
	var record := {
		"path": path.trim_prefix("res://"),
		"sha256": FileAccess.get_sha256(path),
		"locale": locale,
		"width": viewport_size.x,
		"height": viewport_size.y,
		"scenario": scenario,
		"ui_context": context,
		"real_controls": true,
	}
	for key in extra:
		record[key] = extra[key]
	records.append(record)
	print("STAGE1D PREVIEW: %s" % path)


func _write_manifest(expected: int) -> void:
	var path := output.path_join("manifest.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write preview manifest: %s" % path)
		return
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"stage": "1D",
		"generated_utc": Time.get_datetime_string_from_system(true, true),
		"normal_renderer_required": true,
		"fresh_actual_control_render_paths": true,
		"expected_capture_count": expected,
		"capture_count": records.size(),
		"profiles": ["ru-1280x720", "en-1280x720", "ru-960x540", "en-960x540"],
		"captures": records,
		"source_hashes": _source_hashes(),
	}, "  ", false, true) + "\n")
