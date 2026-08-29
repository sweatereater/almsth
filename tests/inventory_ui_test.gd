class_name InventoryUiTestSuite
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const PanelClass := preload("res://scripts/ui/inventory_panel.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_presentation_model()
	await _test_panel_state(tree)
	await _test_main_integration(tree)
	Loc.set_locale("ru")
	return failures


func _test_presentation_model() -> void:
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		var bow_stats := PanelClass.primary_stats("bone_bow@2")
		var knife_stats := PanelClass.primary_stats("bone_knife@2")
		_expect(
			bow_stats.size() == 3
			and bow_stats[0].contains("3")
			and bow_stats[1].contains("2")
			and bow_stats[2].contains("5"),
			"Bow +2 card must show ranged damage 3, accuracy 2 and range 5 in %s" % locale,
		)
		_expect(
			knife_stats.size() == 2
			and knife_stats[0].contains("3")
			and knife_stats[1].contains("3"),
			"Knife +2 card must show melee damage 3 and accuracy 3 in %s" % locale,
		)
		for key in [
			"INVENTORY_FILTER_ALL", "INVENTORY_SELECTED_PANEL", "INVENTORY_EQUIPPED_PANEL",
			"INVENTORY_EMPTY", "INVENTORY_SERVICE_CRUSHER", "INVENTORY_SERVICE_WHETSTONE",
			"INVENTORY_UPGRADE_SELECT_SHORT", "INVENTORY_UPGRADE_WEAPON_ONLY",
			"CAMP_OBJECT_CRUSHER_TOOLTIP", "CAMP_OBJECT_WHETSTONE_TOOLTIP",
		]:
			_expect(Loc.STRINGS[locale].has(key), "Inventory UI localization %s missing in %s" % [key, locale])


func _test_panel_state(tree: SceneTree) -> void:
	Loc.set_locale("ru")
	var state := RunState.new()
	state.current_form_id = "skeleton"
	state.add_item("rotting_mail")
	state.add_item("bone_bow", 2, 2)
	state.add_item("bone_knife", 3)
	state.add_item("soul_locket")
	var panel := PanelClass.new()
	tree.root.add_child(panel)
	await tree.process_frame
	panel.bind_state(state, false)
	var keys := PackedStringArray()
	for entry in panel.entries:
		keys.append(String(entry["key"]))
	_expect(
		keys == PackedStringArray(["bone_bow@2", "bone_knife@3", "soul_locket@0", "rotting_mail@0"]),
		"Inventory rows must use stable explicit slot/key order",
	)
	_expect("×2" in panel.row_buttons[0].text, "One stack key must render as one row with its count")
	panel.set_filter("hands")
	_expect(panel.entries.is_empty() and panel.page_label.text == Loc.text("INVENTORY_EMPTY_FILTER"), "Empty filters need an explicit state")
	panel.set_filter("armor")
	panel.select_visible_index(0)
	_expect(
		panel.equipped_detail_label.text.contains(Loc.text("INVENTORY_SLOT_LOCKED")),
		"An inventory item targeting a locked form slot must show Locked in the comparison panel",
	)
	panel.select_equipment_slot("armor", false)
	_expect(
		panel.filter_id == "armor"
		and panel.selected_detail_label.text.contains(Loc.text("INVENTORY_SLOT_LOCKED")),
		"Selecting a locked mannequin slot must switch its filter and explain that it is locked",
	)
	panel.set_filter("weapon")
	panel.select_visible_index(0)
	state.remove_item("bone_knife@3")
	state.loadout["weapon"] = "bone_knife@3"
	var replacement := state.equip_from_inventory(panel.selected_item_key())
	_expect(bool(replacement.get("ok", false)), "Panel selection must remain a valid RunState equip request")
	panel.refresh()
	_expect(
		int(state.inventory.get("bone_bow@2", 0)) == 1
		and int(state.inventory.get("bone_knife@3", 0)) == 1,
		"Equipping from a stack must remove one item and return the replaced weapon",
	)
	state.remove_item("bone_bow@2")
	panel.refresh()
	_expect(panel.selected_item_key().is_empty(), "Stale inventory selection must clear after its stack disappears")
	state.add_item("bone_bow", 2)
	panel.set_mode(PanelClass.Mode.WHETSTONE)
	panel.bind_state(state, true)
	var bow_sources := PackedStringArray()
	for entry in panel.entries:
		if String(entry["key"]) == "bone_bow@2":
			bow_sources.append(String(entry["source"]))
	_expect(
		bow_sources == PackedStringArray(["inventory", "equipped"]),
		"Whetstone must keep identical inventory and equipped weapon keys as separate candidates",
	)
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		panel.apply_locale()
		panel.select_item("bone_bow@2", "equipped", "weapon")
		var equipped_name := PanelClass.display_name("bone_bow@2")
		_expect(
			panel.selected_detail_label.text.contains(equipped_name)
			and panel.selected_detail_label.text.contains(Loc.text("INVENTORY_SOURCE_EQUIPPED"))
			and panel.equipped_detail_label.text.contains(equipped_name)
			and panel.equipped_detail_label.text.contains(Loc.text("INVENTORY_SOURCE_EQUIPPED"))
			and not panel.equipped_detail_label.text.ends_with(Loc.text("INVENTORY_EMPTY")),
			"Selected equipped item must remain visible in both distinct identity panels in %s" % locale,
		)
	Loc.set_locale("ru")
	panel.apply_locale()
	var forge := RunState.new()
	forge.camp_upgrades["whetstone"] = true
	forge.add_resources({"wood": 20, "stone": 40, "cloth": 4})
	var forge_key := forge.add_item("bone_knife", 1)
	var unchanged := forge.upgrade_weapon(forge_key, 0.9, 0.9)
	_expect(
		unchanged.get("outcome", "") == "unchanged"
		and int(forge.inventory.get(forge_key, 0)) == 1,
		"A failed Whetstone roll must preserve one item and its selection key",
	)
	var downgraded := forge.upgrade_weapon(forge_key, 0.9, 0.01)
	_expect(
		downgraded.get("outcome", "") == "downgraded"
		and int(forge.inventory.get("bone_knife@0", 0)) == 1,
		"The 5% failure branch must return the transformed downgraded key without duplication",
	)
	panel.queue_free()


func _test_main_integration(tree: SceneTree) -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	main.persistence_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.character_name = "Inventory QA"
	main._show_base("")
	await tree.process_frame
	_expect(
		main.get_viewport().gui_get_focus_owner() == main.start_button,
		"Opening the base must establish deterministic keyboard/gamepad focus",
	)
	_expect(
		not main.crusher_object_button.visible and not main.whetstone_object_button.visible,
		"Unbuilt camp services must have no visible hitbox or focus target",
	)
	main.state.add_resources({"wood": 30, "stone": 80, "cloth": 12})
	main._on_build_camp_upgrade("crusher")
	main._on_build_camp_upgrade("whetstone")
	_expect(
		main.crusher_object_button.visible and main.whetstone_object_button.visible,
		"Built camp services must become visible interactive objects",
	)
	_expect(
		not Rect2(main.crusher_object_button.position, main.crusher_object_button.size).intersects(
			Rect2(main.whetstone_object_button.position, main.whetstone_object_button.size)
		)
		and main.whetstone_object_button.position.x + main.whetstone_object_button.size.x < 828.0,
		"Camp service hitboxes must not overlap each other or the sidebar",
	)
	var saved: Dictionary = main.state.to_save_data()
	_expect(not saved.has("inventory_ui") and not saved.has("inventory_filter"), "Save data must not persist ephemeral inventory UI state")
	var restored := RunState.new()
	_expect(restored.restore_save_data(saved), "A complete inventory/base save must restore")
	_expect(
		bool(restored.camp_upgrades["crusher"]) and bool(restored.camp_upgrades["whetstone"]),
		"Camp service availability must restore from existing camp_upgrades fields",
	)
	main.state.add_item("bone_knife", 0, 2)
	main.state.add_item("rotting_mail")
	main.state.loadout["weapon"] = "bone_bow@2"
	main.crusher_object_button.pressed.emit()
	_expect(
		main.inventory_service_mode == "crusher"
		and main.inventory_panel.mode == PanelClass.Mode.CRUSHER
		and not main.start_button.visible,
		"Clicking the built Crusher object must open its focus-trapped service menu",
	)
	main.inventory_panel.set_filter("weapon")
	main.inventory_panel.select_visible_index(0)
	var count_before := int(main.state.inventory.get(main.inventory_panel.selected_item_key(), 0))
	main._on_inventory_dismantle_pressed()
	_expect(
		int(main.state.inventory.get("bone_knife@0", 0)) == count_before - 1,
		"Crusher Dismantle 1 must remove exactly one inventory item",
	)
	main._on_inventory_dismantle_all_pressed()
	_expect(
		main.dismantle_all_confirmation_pending and not main.state.inventory.is_empty(),
		"Crusher Dismantle All must require a second localized confirmation",
	)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	_expect(main.inventory_panel.handle_input(escape), "Service back input must be handled locally")
	_expect(
		not main.dismantle_all_confirmation_pending and main.inventory_service_mode == "crusher",
		"First Back during destructive confirmation must cancel only that confirmation",
	)
	main._on_inventory_dismantle_all_pressed()
	main._on_inventory_dismantle_all_pressed()
	_expect(
		main.state.inventory.is_empty() and main.state.loadout["weapon"] == "bone_bow@2",
		"Confirmed Dismantle All must ignore the current filter and preserve loadout",
	)
	main.inventory_panel.handle_input(escape)
	_expect(main.inventory_service_mode.is_empty(), "Second service Back must return to the base")
	main.state.add_item("bone_bow", 2)
	main.state.add_item("bone_knife", 0)
	main.whetstone_object_button.grab_focus()
	var gamepad_accept := InputEventJoypadButton.new()
	gamepad_accept.button_index = JOY_BUTTON_A
	gamepad_accept.pressed = true
	main.get_viewport().push_input(gamepad_accept, true)
	await tree.process_frame
	_expect(
		main.inventory_service_mode == "whetstone"
		and main.inventory_panel.mode == PanelClass.Mode.WHETSTONE,
		"Focused Whetstone object must open from gamepad A without a mouse",
	)
	var identities := PackedStringArray()
	for entry in main.inventory_panel.entries:
		identities.append("%s:%s" % [entry["key"], entry["source"]])
	_expect(
		identities.has("bone_bow@2:inventory") and identities.has("bone_bow@2:equipped"),
		"Whetstone UI must preserve source identity for equal weapon keys",
	)
	main.inventory_panel.select_item("bone_knife@0", "inventory")
	main.rng.seed = 1
	var resources_before: Dictionary = main.state.resources.duplicate(true)
	main._on_inventory_upgrade_pressed()
	_expect(
		main.state.inventory.get("bone_knife@1", 0) == 1
		and main.state.resources["stone"] == int(resources_before["stone"]) - 10,
		"Whetstone service must transform exactly one inventory weapon and charge the existing exact cost",
	)
	main.state.add_item("bone_bow", 3)
	main.inventory_panel.select_item("bone_bow@3", "inventory")
	main.inventory_panel.refresh()
	_expect(
		main.inventory_panel.upgrade_button.disabled
		and main.inventory_panel.upgrade_button.text == Loc.text("INVENTORY_UPGRADE_MAX"),
		"Maximum weapons must disable upgrade with a reason",
	)
	main.inventory_panel.select_item("", "locked", "hands")
	main.inventory_panel.refresh()
	_expect(
		main.inventory_panel.upgrade_button.disabled
		and main.inventory_panel.upgrade_button.text == Loc.text("INVENTORY_UPGRADE_SELECT_SHORT")
		and main.inventory_panel.upgrade_button.tooltip_text == Loc.text("INVENTORY_UPGRADE_WEAPON_ONLY"),
		"Empty or locked categories need a compact button label and the full localized reason tooltip",
	)
	main.inventory_panel.select_item("bone_bow@2", "inventory")
	main.state.resources = {"wood": 0, "stone": 0, "cloth": 0}
	main.inventory_panel.refresh()
	_expect(
		main.inventory_panel.upgrade_button.disabled
		and main.inventory_panel.upgrade_button.text == Loc.text("INVENTORY_REASON_RESOURCES"),
		"Whetstone must disable an unaffordable attempt with an explicit localized reason",
	)
	main._close_inventory_service()
	main.state.add_item("rotting_mail")
	main._show_character()
	main._select_character_panel("inventory")
	_expect(
		main.inventory_panel.equip_button.visible
		and main.inventory_panel.dismantle_button.visible
		and main.inventory_panel.upgrade_button.visible,
		"Base character sheet must retain equip, Crusher and Whetstone shortcuts",
	)
	main.inventory_panel.set_filter("armor")
	main.inventory_panel.select_visible_index(0)
	var shortcut_cloth_before := int(main.state.resources["cloth"])
	main._on_inventory_dismantle_pressed()
	_expect(
		int(main.state.resources["cloth"]) == shortcut_cloth_before + 2,
		"Character-sheet Crusher shortcut must use the same exact salvage rules as the station",
	)
	main._close_character()
	main._begin_expedition_at(99)
	main.floor_data["enemies"].clear()
	main._show_character()
	main._select_character_panel("inventory")
	await tree.process_frame
	_expect(
		main.inventory_panel.equip_button.visible
		and not main.inventory_panel.dismantle_button.visible
		and not main.inventory_panel.upgrade_button.visible,
		"Dungeon inventory must remain view/equip only without station actions",
	)
	var movement_direction := Vector2i.ZERO
	var movement_action := ""
	for candidate in [
		[Vector2i.UP, "move_up"], [Vector2i.DOWN, "move_down"],
		[Vector2i.LEFT, "move_left"], [Vector2i.RIGHT, "move_right"],
	]:
		if main.floor_data["tiles"].get(main.player_pos + candidate[0], "void") == "floor":
			movement_direction = candidate[0]
			movement_action = candidate[1]
			break
	_expect(movement_direction != Vector2i.ZERO, "Generated dungeon start needs a legal movement regression cell")
	var position_before_close: Vector2i = main.player_pos
	var close_sheet := InputEventAction.new()
	close_sheet.action = "character_sheet"
	close_sheet.pressed = true
	main.get_viewport().push_input(close_sheet, true)
	var move_after_close := InputEventAction.new()
	move_after_close.action = movement_action
	move_after_close.pressed = true
	main.get_viewport().push_input(move_after_close, true)
	await tree.process_frame
	_expect(
		main.screen == main.Screen.DUNGEON
		and not main.inventory_panel.visible
		and main.player_pos == position_before_close + movement_direction,
		"Closing Dungeon inventory must immediately release focus/input so the next movement action moves",
	)
	main.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
