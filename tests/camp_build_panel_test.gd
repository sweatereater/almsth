class_name CampBuildPanelTestSuite
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const BaseLayout := preload("res://scripts/ui/base_layout.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")

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
	# Stage 1E keeps all thirteen silhouettes drawable but deliberately gives
	# input ownership only to the five pre-existing service objects.
	_expect(
		main.camp_silhouette_overlay != null
		and main.camp_silhouette_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and main.camp_silhouette_overlay.cache_cardinality() == 13
		and [main.crusher_object_button, main.whetstone_object_button, main.ritual_table_object_button, main.stage1_object_buttons["kettle"], main.storage_chest_object_button].all(func(button): return button != null),
		"All 13 cached silhouette resources must be pointer-transparent while only five existing service hitboxes remain live",
	)
	_expect(main.camp_silhouette_overlay.OUTER == Color("f2e8d4") and main.camp_silhouette_overlay.SELECTED == Color("67cdc5") and main.camp_silhouette_overlay.FOCUS == Color("e1b965"), "Camp silhouette state colors must retain exact warm/teal/gold values")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/camp_silhouette_overlay.gd")
	var draw_body := overlay_source.substr(overlay_source.find("func _draw()"), overlay_source.find("func _draw_chevron") - overlay_source.find("func _draw()"))
	_expect(not overlay_source.contains("func _process") and not draw_body.contains("Image.new") and not draw_body.contains("ImageTexture.create") and not draw_body.contains("ShaderMaterial.new") and not draw_body.contains("StyleBox"), "Overlay draw path must allocate/mutate no image, material, or style resource")
	_expect(
		BaseLayout.CAMP_INTERACTIVE_HITBOX_LOCAL_RECTS == {
			"crusher": Rect2(54, 304, 142, 105), "whetstone": Rect2(237, 298, 93, 91),
			"ritual_table": Rect2(430, 181, 132, 77), "kettle": Rect2(397, 268, 72, 66),
			"storage_chest": Rect2(230, 395, 96, 60),
		},
		"Stage 1E must retain exactly the five existing service hitboxes and no decorative input rectangles",
	)
	var live_service_buttons := {
		"crusher": main.crusher_object_button,
		"whetstone": main.whetstone_object_button,
		"ritual_table": main.ritual_table_object_button,
		"kettle": main.stage1_object_buttons["kettle"],
		"storage_chest": main.storage_chest_object_button,
	}
	_expect(live_service_buttons.size() == 5, "Only the five approved camp services may own live Buttons")
	for service_id in live_service_buttons:
		var service_button: Button = live_service_buttons[service_id]
		var world_rect := BaseLayout.station_hitbox_rect(service_id)
		var local_rect: Rect2 = BaseLayout.CAMP_INTERACTIVE_HITBOX_LOCAL_RECTS[service_id]
		_expect(service_button.position == world_rect.position and service_button.size == world_rect.size and service_button.position - BaseLayout.IMAGE_RECT.position == local_rect.position, "Live service hitbox must retain exact local/world placement: %s" % service_id)
	for decorative_id in ["mural", "bunk", "textile_area", "workbench", "writing_set", "campfire", "rocking_chair", "record_player"]:
		_expect(not live_service_buttons.has(decorative_id) and not main.stage1_object_buttons.has(decorative_id), "Decorative camp art must not gain an interaction Button: %s" % decorative_id)
	var cached_masks := {}
	for id in main.camp_silhouette_overlay.IDS:
		var entry: Dictionary = main.camp_silhouette_overlay.cached_outlines[id]
		var masks: Dictionary = entry.masks
		cached_masks[id] = [entry.source_hash, masks[2].get_instance_id(), masks[4].get_instance_id(), masks["inner"].get_instance_id()]
		var source: Texture2D = Renderer.CAMP_LAYER_ART[id]
		var source_size := source.get_size()
		_expect(masks[2].get_size() == source_size + Vector2(4, 4) and masks[4].get_size() == source_size + Vector2(8, 8) and masks["inner"].get_size() == source_size, "Cached silhouette morphology must use native inner/+2/+4 dimensions: %s" % id)
		var source_image := source.get_image()
		var hover_image: Image = masks[2].get_image()
		var focus_image: Image = masks[4].get_image()
		var inner_image: Image = masks["inner"].get_image()
		var hover_pixels := 0
		var focus_pixels := 0
		var inner_ok := true
		for y in source_size.y:
			for x in source_size.x:
				var source_alpha := source_image.get_pixel(x, y).a >= (32.0 / 255.0)
				if hover_image.get_pixel(x + 2, y + 2).a > 0.0:
					hover_pixels += 1
					inner_ok = inner_ok and not source_alpha
				if inner_image.get_pixel(x, y).a > 0.0:
					inner_ok = inner_ok and source_alpha
		for y in focus_image.get_height():
			for x in focus_image.get_width():
				if focus_image.get_pixel(x, y).a > 0.0:
					focus_pixels += 1
		_expect(hover_pixels > 0 and focus_pixels > 0 and inner_ok, "Cached silhouette rings must exclude source interior while inner remains within source: %s" % id)
	for state_name in ["normal", "hover", "focus", "selected", "selected_focus", "disabled_unbuilt"]:
		for id in main.camp_silhouette_overlay.IDS:
			main.camp_silhouette_overlay.set_state(id, state_name)
		main.camp_silhouette_overlay.queue_redraw()
		await tree.process_frame
	for id in main.camp_silhouette_overlay.IDS:
		var entry: Dictionary = main.camp_silhouette_overlay.cached_outlines[id]
		var masks: Dictionary = entry.masks
		_expect(cached_masks[id] == [entry.source_hash, masks[2].get_instance_id(), masks[4].get_instance_id(), masks["inner"].get_instance_id()] and main.camp_silhouette_overlay.cache_cardinality() == 13, "All silhouette state redraws must retain the original cached resources: %s" % id)
	main.state.camp_upgrades.crusher = true
	main._refresh_interface()
	main._open_inventory_service("crusher")
	await tree.process_frame
	_expect(
		main.camp_silhouette_overlay.states.get("crusher") == "selected_focus",
		"Opening a live service must select/focus its cached silhouette without creating a decorative hitbox",
	)
	main._close_inventory_service()
	await tree.process_frame
	await tree.process_frame
	_expect(
		main.get_viewport().gui_get_focus_owner() == main.crusher_object_button,
		"Closing a service must restore focus to its source service control",
	)
	main.state.camp_upgrades.kettle = true
	main.state.camp_preparation.kettle_selected = true
	main.stage1_object_buttons.kettle.grab_focus()
	main._refresh_camp_silhouette_overlay()
	_expect(
		main.camp_silhouette_overlay.states.get("kettle") == "selected_focus",
		"The actual kettle prop hitbox must expose selected+focus before generic focus/hover precedence",
	)
	main.camp_build_button.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	var panel = main.camp_build_panel
	_expect(panel.visible and not main.start_button.visible, "Build modal must block the underlying base actions")
	_expect(
		panel.rows.size() == 12 and not panel.rows.has("mural")
		and panel.rows.has("record_player") and panel.rows.has("storage_chest")
		and panel.row_order[-1] == "storage_chest",
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
	main.state.camp_upgrades.crusher = true
	main.state.camp_upgrades.whetstone = true
	main.state.camp_upgrades.ritual_table = true
	main._refresh_interface()
	for service in [["crusher", main.crusher_object_button], ["whetstone", main.whetstone_object_button], ["ritual_table", main.ritual_table_object_button]]:
		var source: Button = service[1]
		source.grab_focus()
		source.pressed.emit()
		await tree.process_frame
		_expect(main.inventory_service_mode == service[0] and main.camp_silhouette_overlay.states.get(service[0]) == "selected_focus", "Real service button must open its matching selected-focus overlay: %s" % service[0])
		main._close_inventory_service()
		await tree.process_frame
		await tree.process_frame
		_expect(main.get_viewport().gui_get_focus_owner() == source, "Real service close must restore exact source focus: %s" % service[0])
	main.state.camp_upgrades.storage_chest = true
	main.state.camp_upgrades.kettle = true
	main.state.camp_preparation.pending = true
	main.state.camp_preparation.satiated = true
	main.state.food = GameRules.CAMP_KETTLE_FOOD_COST
	main._refresh_interface()
	var storage_source: Button = main.storage_chest_object_button
	storage_source.grab_focus()
	storage_source.pressed.emit()
	await tree.process_frame
	_expect(main.storage_panel.visible and main.camp_silhouette_overlay.states.get("storage_chest") == "selected_focus", "Real storage prop button must open storage with selected-focus overlay")
	main.storage_panel.close()
	await tree.process_frame
	await tree.process_frame
	_expect(main.get_viewport().gui_get_focus_owner() == storage_source, "Storage close must restore exact chest prop focus")
	var kettle_source: Button = main.stage1_object_buttons["kettle"]
	main.state.camp_preparation.kettle_selected = false
	main._refresh_interface()
	kettle_source.grab_focus()
	kettle_source.pressed.emit()
	await tree.process_frame
	_expect(main.state.camp_preparation.kettle_selected and main.camp_silhouette_overlay.states.get("kettle") == "selected_focus" and main.get_viewport().gui_get_focus_owner() == kettle_source, "Actual kettle prop action must retain source focus and selected-focus precedence")
	kettle_source.pressed.emit()
	await tree.process_frame
	_expect(not main.state.camp_preparation.kettle_selected and main.get_viewport().gui_get_focus_owner() == kettle_source, "Actual kettle prop action must toggle preparation off without sidebar focus")
	for service_id in live_service_buttons:
		main.state.camp_upgrades[service_id] = false
	main._refresh_interface()
	for service_id in live_service_buttons:
		var unbuilt_source: Button = live_service_buttons[service_id]
		unbuilt_source.pressed.emit()
		await tree.process_frame
		_expect(main.camp_silhouette_overlay.states.get(service_id) == "disabled_unbuilt" and not main.storage_panel.visible and main.inventory_service_mode.is_empty() and not main.state.camp_preparation.kettle_selected, "Unbuilt service must remain noninteractive and draw no live overlay: %s" % service_id)
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
