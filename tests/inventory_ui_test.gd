class_name InventoryUiTestSuite
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const PanelClass := preload("res://scripts/ui/inventory_panel.gd")
const CharacterSheetLayout := preload("res://scripts/ui/character_sheet_layout.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_presentation_model()
	await _test_panel_state(tree)
	await _test_main_mark_input_routing(tree)
	await _test_main_integration(tree)
	Loc.set_locale("ru")
	return failures


func _test_presentation_model() -> void:
	var expected_filters: Array[String] = [
		"all", "weapons", "offhand", "armor", "accessories", "backpack",
	]
	_expect(
		PanelClass.available_filter_order() == expected_filters,
		"Character inventory must expose the exact six aggregate presentation filters",
	)
	var expected_service_filters: Array[String] = ["all"]
	expected_service_filters.append_array(GameRules.EQUIPMENT_CATEGORY_ORDER)
	_expect(
		PanelClass.service_filter_order() == expected_service_filters,
		"Service modes must retain the centralized internal category IDs",
	)
	_expect(
		PanelClass.CHARACTER_FILTER_CATEGORIES == {
			"all": [],
			"weapons": ["weapon"],
			"offhand": ["offhand"],
			"armor": ["head", "body", "hands", "legs", "feet"],
			"accessories": ["talisman", "ring"],
			"backpack": ["back"],
		},
		"Aggregate filters must map to existing serialized/internal category IDs",
	)
	var panel_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_panel.gd")
	_expect(
		not panel_source.contains("const FILTER_ORDER"),
		"InventoryPanel must not duplicate the central equipment-category order",
	)
	var mark_overlay_source := FileAccess.get_file_as_string(
		"res://scripts/ui/inventory_mark_overlay.gd"
	)
	_expect(
		not mark_overlay_source.contains(".lightened(")
		and not mark_overlay_source.contains(".darkened(")
		and mark_overlay_source.contains(
			'Palette.color(Palette.WARM_ARCHIVE, "raised")'
		),
		"Card mark hover must use the exact raised token without derived UI colors",
	)
	_expect(
		Loc.STRINGS["ru"]["ITEM_UNEXPECTEDLY_COMFORTABLE_JACKET"] == "Уютный пиджак"
		and Loc.STRINGS["en"]["ITEM_UNEXPECTEDLY_COMFORTABLE_JACKET"] == "Cozy Jacket"
		and Loc.STRINGS["ru"]["SLOT_JACKET"] == "Плащ"
		and Loc.STRINGS["en"]["SLOT_JACKET"] == "Cloak"
		and Loc.STRINGS["ru"]["INVENTORY_PERMANENT_LOCKED"] == "Не хочется снимать"
		and Loc.STRINGS["en"]["INVENTORY_PERMANENT_LOCKED"] == "Too cozy to take off",
		"Cozy jacket item, physical Cloak slot and lock copy must match the approved RU/EN literals",
	)
	for stale_copy in ["Неожиданно удобный пиджак", "Unexpectedly Comfortable Jacket", "Нельзя снять", "Cannot be removed"]:
		_expect(not Loc.STRINGS["ru"].values().has(stale_copy) and not Loc.STRINGS["en"].values().has(stale_copy), "Obsolete jacket copy must be absent: %s" % stale_copy)
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
			"INVENTORY_FILTER_ALL", "INVENTORY_FILTER_WEAPONS", "INVENTORY_FILTER_OFFHAND",
			"INVENTORY_FILTER_ARMOR", "INVENTORY_FILTER_ACCESSORIES", "INVENTORY_FILTER_BACKPACK",
			"INVENTORY_SELECTED_PANEL", "INVENTORY_EQUIPPED_PANEL",
			"INVENTORY_EMPTY", "INVENTORY_SERVICE_CRUSHER", "INVENTORY_SERVICE_WHETSTONE",
			"INVENTORY_CLOSE_SERVICE", "INVENTORY_UPGRADE_SELECT_SHORT", "INVENTORY_UPGRADE_WEAPON_ONLY",
			"INVENTORY_SELECTION_STALE", "MSG_EQUIP_ITEM_MISSING", "MSG_EQUIP_SLOT_CHOICE_REQUIRED", "MSG_EQUIP_SLOT_LOCKED",
			"CAMP_OBJECT_CRUSHER_TOOLTIP", "CAMP_OBJECT_WHETSTONE_TOOLTIP",
		]:
			_expect(Loc.STRINGS[locale].has(key), "Inventory UI localization %s missing in %s" % [key, locale])
	var pagination_state := RunState.new()
	for item_id in [
		"rusty_sabre", "short_crossbow", "bone_buckler", "gravediggers_lamp",
		"watchmans_cap", "archivists_mask", "wanderers_gambeson", "lamellar_vest",
		"scouts_trousers", "heavy_leg_wraps", "pilgrims_boots", "aiming_ring", "expedition_backpack",
	]:
		pagination_state.add_item(item_id)
	var pagination_keys: Array = pagination_state.inventory.keys()
	for amount in [0, 1, 6, 7, 12, 13]:
		var subset := RunState.new()
		for index in range(amount):
			var key := String(pagination_keys[index])
			subset.inventory[key] = pagination_state.inventory[key]
		var page_count := maxi(1, ceili(
			PanelClass.build_entries(subset, PanelClass.Mode.CHARACTER, "all").size()
			/ float(PanelClass.PAGE_SIZE)
		))
		_expect(page_count == maxi(1, ceili(amount / 6.0)), "Six-card pagination must be exact for %d entries" % amount)


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
	var state_before_jacket_selection: Dictionary = state.to_save_data()
	panel.select_equipment_slot("jacket", true)
	var only_all_pressed: bool = bool(panel.filter_buttons["all"].button_pressed)
	for category_id in PanelClass.available_filter_order():
		if category_id == "all":
			continue
		only_all_pressed = only_all_pressed and not panel.filter_buttons[category_id].button_pressed
	_expect(
		panel.filter_id == "all"
		and panel.page == 0
		and panel.selected_destination_slot() == "jacket"
		and panel.selected_equipped_slot() == "jacket"
		and panel.selected_item_key() == GameRules.permanent_jacket_key()
		and only_all_pressed
		and state.to_save_data() == state_before_jacket_selection,
		"Selecting the occupied permanent jacket must preserve selection/state while forcing only All pressed",
	)
	panel.select_equipment_slot("head", false)
	_expect(panel.filter_id == "armor" and panel.filter_buttons["armor"].button_pressed, "Head must map to the aggregate Armor filter")
	panel.select_equipment_slot("back", false)
	_expect(panel.filter_id == "backpack" and panel.filter_buttons["backpack"].button_pressed, "Back must map to the aggregate Backpack filter")
	panel.set_filter("all")
	var keys := PackedStringArray()
	for entry in panel.entries:
		keys.append(String(entry["key"]))
	_expect(
		keys == PackedStringArray(["bone_bow@2", "bone_knife@3", "rotting_mail@0", "soul_locket@0"]),
		"Inventory rows must use stable explicit slot/key order",
	)
	_expect("×2" in panel.row_property_labels[0].text, "One stack key must render as one card with its count")
	panel.set_filter("offhand")
	_expect(panel.entries.is_empty() and panel.page_label.text == Loc.text("INVENTORY_EMPTY_FILTER"), "Empty filters need an explicit state")
	panel.set_filter("armor")
	panel.select_item("rotting_mail@0", "inventory")
	_expect(
		panel.equipped_detail_label.text.contains(Loc.text("INVENTORY_SLOT_LOCKED")),
		"An inventory item targeting a locked form slot must show Locked in the comparison panel",
	)
	panel.select_equipment_slot("body", false)
	_expect(
		panel.filter_id == "armor"
		and panel.selected_detail_label.text.contains(Loc.text("INVENTORY_SLOT_LOCKED")),
		"Selecting a locked mannequin slot must switch to Armor and explain that it is locked",
	)
	panel.set_filter("weapons")
	panel.select_visible_index(0)
	state.remove_item("bone_knife@3")
	state.loadout["right_hand"] = "bone_knife@3"
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
	_expect(
		panel.size == PanelClass.PANEL_SIZE
		and panel.close_button.visible
		and Rect2(panel.mode_title_label.position, panel.mode_title_label.size).end.x
		< panel.close_button.position.x
		and Rect2(panel.close_button.position, panel.close_button.size).end
		<= PanelClass.PANEL_SIZE,
		"Service title and compact 42x42 close button must fit the 1280 design-canvas panel without overlap",
	)
	var scaled_service_rect := Rect2(Vector2(85, 405) * 0.75, PanelClass.PANEL_SIZE * 0.75)
	_expect(
		scaled_service_rect.end.x <= 960.0 and scaled_service_rect.end.y <= 540.0,
		"Inventory service panel must remain inside the 960x540 canvas-items scaling contract",
	)
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
		_expect(
			panel.close_button.tooltip_text == Loc.text("INVENTORY_CLOSE_SERVICE")
			and panel.close_button.get_meta("accessible_name", "") == Loc.text("INVENTORY_CLOSE_SERVICE"),
			"Service close control needs synchronized localized tooltip/accessibility in %s" % locale,
		)
		panel.select_item("bone_bow@2", "equipped", "right_hand")
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
	panel.set_mode(PanelClass.Mode.CHARACTER)
	_expect(not panel.close_button.visible, "Embedded Character inventory must not show the service close button")
	_expect(
		panel.size == CharacterSheetLayout.INVENTORY_PANEL_RECT.size
		and panel.row_buttons[0].position == Vector2(0, 48)
		and panel.row_buttons[0].size == PanelClass.CHARACTER_ROW_SIZE,
		"Embedded Character inventory must use six 270x84 cards in its isolated 549x546 region",
	)
	var filter_order := PanelClass.available_filter_order()
	for index in range(filter_order.size()):
		var filter_button: Button = panel.filter_buttons[filter_order[index]]
		_expect(
			filter_button.position.y == 0.0
			and filter_button.size.y == 40.0
			and filter_button.position.x + filter_button.size.x <= PanelClass.CHARACTER_PANEL_SIZE.x + 0.1,
			"Six aggregate Character inventory filters must fit in one measured row",
		)
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		panel.apply_locale()
		for current_filter in filter_order:
			var filter_button: Button = panel.filter_buttons[current_filter]
			var normal_style := filter_button.get_theme_stylebox("normal")
			var text_width := filter_button.get_theme_font("font").get_string_size(
				filter_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				filter_button.get_theme_font_size("font_size"),
			).x
			var usable_width := filter_button.size.x - normal_style.get_content_margin(SIDE_LEFT) - normal_style.get_content_margin(SIDE_RIGHT)
			_expect(
				filter_button.theme_type_variation == "CompactButton"
				and filter_button.get_theme_font_size("font_size") >= 12
				and text_width <= usable_width,
				"Character filter %s must not clip inside cached compact margins in %s" % [current_filter, locale],
			)
		if locale == "ru":
			_expect(
				panel.filter_buttons["offhand"].text == "Вторая рука",
				"The RU Off-hand aggregate tab must render its exact synchronized label",
			)
	Loc.set_locale("ru")
	panel.apply_locale()
	var card_state := RunState.new()
	var card_item_ids := [
		"rusty_sabre", "short_crossbow", "bone_buckler", "gravediggers_lamp",
		"watchmans_cap", "archivists_mask", "wanderers_gambeson", "lamellar_vest",
		"scouts_trousers", "heavy_leg_wraps", "pilgrims_boots", "aiming_ring", "expedition_backpack",
	]
	for item_id in card_item_ids:
		card_state.add_item(String(item_id))
	var upgraded_bound_key := GameRules.make_item_key("old_claymore", 3, true)
	card_state.add_item_key(upgraded_bound_key, 2)
	card_state.set_item_mark("rusty_sabre@0", "keep")
	card_state.set_item_mark("short_crossbow@0", "salvage")
	panel.bind_state(card_state, true)
	panel.set_filter("all")
	_expect(
		panel.entries.size() == 14
		and panel.row_buttons.all(func(button: Button) -> bool: return button.visible)
		and panel.previous_button.disabled
		and not panel.next_button.disabled,
		"Character inventory must render exactly six cards on the first page and enable deterministic paging",
	)
	for index in range(6):
		var expected_position := Vector2((index % 2) * 279, 48 + (index / 2) * 88)
		_expect(
			panel.row_buttons[index].position == expected_position
			and panel.row_buttons[index].size == Vector2(270, 84)
			and panel.row_icons[index].size == Vector2(44, 44)
			and panel.row_name_labels[index].get_theme_font_size("font_size") == 14
			and panel.row_property_labels[index].get_theme_font_size("font_size") >= 12,
			"Card %d must follow the two-column/three-row 44px-icon typography contract" % index,
		)
	var interactive_overlay_count := 0
	var active_mark_count := 0
	for overlay in panel.row_mark_overlays:
		if overlay.visible:
			interactive_overlay_count += 1
			if not overlay.mark.is_empty():
				active_mark_count += 1
			_expect(
				overlay.interactive
				and overlay.size == overlay.INTERACTIVE_SIZE
				and overlay.custom_minimum_size == overlay.INTERACTIVE_SIZE
				and overlay.keep_button.visible
				and overlay.salvage_button.visible
				and overlay.keep_button.mouse_filter == Control.MOUSE_FILTER_STOP
				and overlay.salvage_button.mouse_filter == Control.MOUSE_FILTER_STOP,
				"Each visible Character card needs two independent corner controls",
			)
	_expect(
		interactive_overlay_count == 6
		and active_mark_count == 2
		and not panel.keep_button.visible
		and not panel.salvage_mark_button.visible,
		"Keep/Salvage must live on all six cards, with no global Character mark controls",
	)
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		panel.apply_locale()
		for overlay in panel.row_mark_overlays:
			if not overlay.visible:
				continue
			_expect(
				overlay.keep_button.tooltip_text == Loc.text("INVENTORY_MARK_KEEP")
				and overlay.keep_button.accessibility_name == Loc.text("INVENTORY_MARK_KEEP")
				and overlay.salvage_button.tooltip_text == Loc.text("INVENTORY_MARK_SALVAGE")
				and overlay.salvage_button.accessibility_name == Loc.text("INVENTORY_MARK_SALVAGE"),
				"Card mark tooltip/accessibility copy must stay synchronized in %s" % locale,
			)
	Loc.set_locale("ru")
	panel.apply_locale()
	panel.select_item(upgraded_bound_key, "inventory")
	var full_long_name := "Старинный церемониальный клеймор архивариуса +3"
	var long_name_contract := false
	for index in range(panel.row_buttons.size()):
		var row: Button = panel.row_buttons[index]
		var name_label: Label = panel.row_name_labels[index]
		var absolute_index: int = panel.page * PanelClass.PAGE_SIZE + index
		if (
			not row.visible
			or absolute_index >= panel.entries.size()
			or String(panel.entries[absolute_index].get("key", "")) != upgraded_bound_key
		):
			continue
		name_label.text = full_long_name
		row.tooltip_text = "%s\n%s" % [full_long_name, row.tooltip_text]
		row.accessibility_name = "%s. %s" % [full_long_name, row.accessibility_name]
		var measured_width := name_label.get_theme_font("font").get_string_size(
			full_long_name, HORIZONTAL_ALIGNMENT_LEFT, -1,
			name_label.get_theme_font_size("font_size"),
		).x
		long_name_contract = (
			measured_width > name_label.size.x
			and name_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
			and row.tooltip_text.contains(full_long_name)
			and row.accessibility_name.contains(full_long_name)
			and row.tooltip_text.contains(Loc.text("INVENTORY_BOUND_STATUS"))
		)
		break
	_expect(
		long_name_contract,
		"A long bound +3 name must ellipsize visually while preserving its full tooltip/accessibility",
	)
	panel.refresh()
	panel.set_filter("all")
	panel.select_item("rusty_sabre@0", "inventory")
	var rusty_index := _visible_card_index(panel, "rusty_sabre@0")
	var rusty_overlay = panel.row_mark_overlays[rusty_index]
	rusty_overlay.keep_button.grab_focus()
	await tree.process_frame
	var selected_card := panel._selected_row_button()
	_expect(
		selected_card != null
		and selected_card.button_pressed
		and rusty_overlay.keep_button.button_pressed
		and panel.get_viewport().gui_get_focus_owner() == rusty_overlay.keep_button,
		"Selected card and focused active Keep control geometry must coexist",
	)
	var keyboard_accept := InputEventAction.new()
	keyboard_accept.action = "ui_accept"
	keyboard_accept.pressed = true
	_expect(
		panel.handle_input(keyboard_accept)
		and card_state.item_mark("rusty_sabre@0").is_empty(),
		"Keyboard ui_accept on an active card Keep control must toggle it off",
	)
	rusty_overlay = panel.row_mark_overlays[_visible_card_index(panel, "rusty_sabre@0")]
	var touch_salvage := InputEventScreenTouch.new()
	touch_salvage.index = 31
	touch_salvage.pressed = true
	touch_salvage.position = rusty_overlay.salvage_button.get_global_rect().get_center()
	_expect(
		panel.handle_input(touch_salvage)
		and card_state.item_mark("rusty_sabre@0") == "salvage",
		"ScreenTouch must activate the exact card-corner Salvage control",
	)
	panel.select_item("short_crossbow@0", "inventory")
	rusty_overlay = panel.row_mark_overlays[_visible_card_index(panel, "rusty_sabre@0")]
	await _click_mouse(panel, tree, rusty_overlay.keep_button.get_global_rect().get_center())
	_expect(
		card_state.item_mark("rusty_sabre@0") == "keep"
		and panel.selected_item_key() == "short_crossbow@0",
		"Mouse must promote Salvage to Keep atomically without selecting the parent card",
	)
	rusty_overlay = panel.row_mark_overlays[_visible_card_index(panel, "rusty_sabre@0")]
	var keep_state_before_rejected_salvage: Dictionary = card_state.to_save_data()
	_expect(
		not rusty_overlay.activate_action("salvage")
		and card_state.to_save_data() == keep_state_before_rejected_salvage,
		"Keep -> Salvage must be rejected until Keep is explicitly removed",
	)
	rusty_overlay.keep_button.grab_focus()
	_expect(
		panel.handle_input(keyboard_accept)
		and card_state.item_mark("rusty_sabre@0").is_empty(),
		"The focused Keep control must explicitly remove Keep",
	)
	rusty_overlay = panel.row_mark_overlays[_visible_card_index(panel, "rusty_sabre@0")]
	rusty_overlay.keep_button.grab_focus()
	var dpad_right := InputEventJoypadButton.new()
	dpad_right.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad_right.pressed = true
	_expect(
		panel.handle_input(dpad_right)
		and panel.get_viewport().gui_get_focus_owner() == rusty_overlay.salvage_button,
		"Gamepad D-pad must move focus between the card's two corner controls",
	)
	var gamepad_accept := InputEventJoypadButton.new()
	gamepad_accept.button_index = JOY_BUTTON_A
	gamepad_accept.pressed = true
	_expect(
		panel.handle_input(gamepad_accept)
		and card_state.item_mark("rusty_sabre@0") == "salvage",
		"Gamepad ui_accept/A must activate the focused exact-card Salvage control",
	)
	panel.select_item("short_crossbow@0", "inventory")
	card_state.set_item_mark("short_crossbow@0", "keep")
	_expect(
		panel.validated_selected_identity().is_empty()
		and panel.selected_item_key().is_empty(),
		"A stale immutable selection fingerprint must still clear after an external mark change",
	)
	panel.select_item("rusty_sabre@0", "inventory")
	panel.selection_generation -= 1
	_expect(
		panel.validated_selected_identity().is_empty()
		and panel.selected_item_key().is_empty(),
		"A stale selection generation must clear rather than retarget",
	)
	rusty_overlay = panel.row_mark_overlays[_visible_card_index(panel, "rusty_sabre@0")]
	var stale_overlay = rusty_overlay
	var stale_identity: Dictionary = stale_overlay.bound_identity.duplicate(true)
	var stale_generation: int = stale_overlay.bound_generation
	var stale_row_index := _visible_card_index(panel, "rusty_sabre@0")
	panel.change_page(1)
	var reused_overlay = panel.row_mark_overlays[stale_row_index]
	var marks_before_stale_request: Dictionary = card_state.inventory_marks.duplicate(true)
	stale_overlay.mark_requested.emit("keep", stale_identity, stale_generation)
	stale_overlay.mark_requested.emit("keep", stale_identity, panel.refresh_generation)
	_expect(
		panel.page == 1
		and not panel.previous_button.disabled
		and reused_overlay == stale_overlay
		and reused_overlay.bound_identity != stale_identity
		and card_state.inventory_marks == marks_before_stale_request,
		"A reused card must reject both stale generation and stale identity without retargeting",
	)
	var current_identity: Dictionary = reused_overlay.bound_identity.duplicate(true)
	var current_key := String(current_identity.get("key", ""))
	var current_previous_mark := card_state.item_mark(current_key)
	reused_overlay.activate_action("keep")
	_expect(
		card_state.item_mark(current_key) == ("" if current_previous_mark == "keep" else "keep"),
		"After paging, a fresh control must still apply only to its current identity",
	)
	for key_to_remove in ["watchmans_cap@0", "archivists_mask@0", "wanderers_gambeson@0", "lamellar_vest@0", "scouts_trousers@0", "heavy_leg_wraps@0", "pilgrims_boots@0", "aiming_ring@0", "expedition_backpack@0", upgraded_bound_key]:
		card_state.remove_item(String(key_to_remove), int(card_state.inventory.get(key_to_remove, 0)))
	panel.refresh()
	_expect(panel.page == 0 and panel.next_button.disabled, "Removing the last page must clamp to the remaining first page")
	panel.set_filter("backpack")
	_expect(
		panel.entries.is_empty()
		and panel.page_label.text == Loc.text("INVENTORY_EMPTY_FILTER")
		and panel.previous_button.disabled and panel.next_button.disabled
		and panel.equip_button.disabled
		and not panel.keep_button.visible and not panel.salvage_mark_button.visible
		and panel.row_mark_overlays.all(func(overlay) -> bool: return not overlay.visible),
		"An empty aggregate group must expose a localized empty state with disabled pager/actions",
	)
	var character_direction := InputEventAction.new()
	character_direction.action = "ui_right"
	character_direction.pressed = true
	_expect(
		panel.handle_input(character_direction),
		"Embedded Character inventory must consume D-pad navigation through its focus graph",
	)
	panel.set_filter("all")
	for service_mode in [
		PanelClass.Mode.CRUSHER,
		PanelClass.Mode.WHETSTONE,
		PanelClass.Mode.RITUAL,
	]:
		panel.set_mode(service_mode)
		panel.bind_state(card_state, true)
		var marked_service_overlays := 0
		for row_index in range(panel.row_buttons.size()):
			var row: Button = panel.row_buttons[row_index]
			if not row.visible:
				continue
			var overlay = panel.row_mark_overlays[row_index]
			var overlay_rect := Rect2(overlay.position, overlay.size)
			var overlay_center := overlay_rect.get_center()
			if overlay.visible:
				marked_service_overlays += 1
			_expect(
				overlay.size == overlay.PASSIVE_SIZE
				and overlay.custom_minimum_size == Vector2.ZERO
				and not overlay.interactive
				and not overlay.keep_button.visible
				and not overlay.salvage_button.visible
				and Rect2(Vector2.ZERO, row.size).encloses(overlay_rect)
				and Rect2(Vector2.ZERO, row.size).has_point(overlay_center)
				and overlay_center == Vector2(604, 13),
				"Service mode %d must keep its passive mark at exact 20x20 in-row geometry" % service_mode,
			)
		_expect(
			marked_service_overlays >= 1,
			"Service mode %d must exercise at least one visible passive mark" % service_mode,
		)
	panel.set_mode(PanelClass.Mode.CHARACTER)
	panel.bind_state(card_state, true)
	panel.set_filter("all")
	var restored_character_overlay = panel.row_mark_overlays[0]
	_expect(
		restored_character_overlay.size == restored_character_overlay.INTERACTIVE_SIZE
		and restored_character_overlay.custom_minimum_size
		== restored_character_overlay.INTERACTIVE_SIZE
		and Rect2(Vector2.ZERO, panel.row_buttons[0].size).encloses(Rect2(
			restored_character_overlay.position,
			restored_character_overlay.size,
		)),
		"Returning from services must restore exact 58x28 Character corner controls",
	)
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


func _test_main_mark_input_routing(tree: SceneTree) -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.character_name = "Mark Input QA"
	main.state.add_item("rusty_sabre")
	main.state.add_item("short_crossbow")
	main._show_base("", "none")
	main._show_character()
	main._select_character_panel("inventory")
	await tree.process_frame
	var panel = main.inventory_panel
	panel.set_filter("all")
	var target_key := "rusty_sabre@0"
	var sibling_key := "short_crossbow@0"
	var target_index := _visible_card_index(panel, target_key)
	var sibling_index := _visible_card_index(panel, sibling_key)
	_expect(
		target_index >= 0 and sibling_index >= 0,
		"Integrated mark routing fixture must expose both exact physical cards",
	)
	if target_index < 0 or sibling_index < 0:
		main.queue_free()
		return

	var mark_signal_count: Array[int] = [0]
	panel.mark_changed.connect(func(): mark_signal_count[0] += 1)
	panel.select_item(sibling_key, "inventory")
	var target_overlay = panel.row_mark_overlays[target_index]
	target_overlay.keep_button.grab_focus()
	await tree.process_frame
	var signal_before := mark_signal_count[0]
	await _push_key_cycle(main, tree, KEY_ENTER)
	_expect(
		main.state.inventory_marks.size() == 1
		and main.state.inventory_marks.get(target_key, "") == "keep"
		and mark_signal_count[0] == signal_before + 1
		and panel.selected_item_key() == sibling_key,
		"Viewport/Main raw Enter down/up must mutate exactly one mark once without selecting its card",
	)

	target_index = _visible_card_index(panel, target_key)
	target_overlay = panel.row_mark_overlays[target_index]
	target_overlay.keep_button.grab_focus()
	await tree.process_frame
	signal_before = mark_signal_count[0]
	await _push_key_cycle(main, tree, KEY_SPACE)
	_expect(
		main.state.inventory_marks.is_empty()
		and mark_signal_count[0] == signal_before + 1
		and panel.selected_item_key() == sibling_key,
		"Viewport/Main raw Space down/up must mutate exactly one mark once without selecting its card",
	)

	target_index = _visible_card_index(panel, target_key)
	target_overlay = panel.row_mark_overlays[target_index]
	target_overlay.keep_button.grab_focus()
	await tree.process_frame
	signal_before = mark_signal_count[0]
	await _push_action_cycle(main, tree, "ui_accept")
	_expect(
		main.state.inventory_marks.size() == 1
		and main.state.inventory_marks.get(target_key, "") == "keep"
		and mark_signal_count[0] == signal_before + 1
		and panel.selected_item_key() == sibling_key,
		"Viewport/Main keyboard ui_accept must mutate exactly one mark once without selecting its card",
	)

	target_index = _visible_card_index(panel, target_key)
	target_overlay = panel.row_mark_overlays[target_index]
	signal_before = mark_signal_count[0]
	await _tap_touch(main, tree, target_overlay.keep_button.get_global_rect().get_center())
	_expect(
		main.state.inventory_marks.is_empty()
		and mark_signal_count[0] == signal_before + 1
		and panel.selected_item_key() == sibling_key,
		"Viewport/Main ScreenTouch press/release must toggle exactly one active Keep mark off",
	)

	target_index = _visible_card_index(panel, target_key)
	target_overlay = panel.row_mark_overlays[target_index]
	target_overlay.keep_button.grab_focus()
	await tree.process_frame
	var marks_before_dpad: Dictionary = main.state.inventory_marks.duplicate(true)
	signal_before = mark_signal_count[0]
	await _push_joy_cycle(main, tree, JOY_BUTTON_DPAD_RIGHT)
	_expect(
		main.get_viewport().gui_get_focus_owner() == target_overlay.salvage_button
		and main.state.inventory_marks == marks_before_dpad
		and mark_signal_count[0] == signal_before,
		"Viewport/Main gamepad D-pad press/release must move focus without mutating a mark",
	)
	await _push_joy_cycle(main, tree, JOY_BUTTON_A)
	_expect(
		main.state.inventory_marks.size() == 1
		and main.state.inventory_marks.get(target_key, "") == "salvage"
		and mark_signal_count[0] == signal_before + 1
		and panel.selected_item_key() == sibling_key,
		"Viewport/Main gamepad A press/release must mutate exactly one focused Salvage mark once",
	)

	target_index = _visible_card_index(panel, target_key)
	target_overlay = panel.row_mark_overlays[target_index]
	signal_before = mark_signal_count[0]
	await _tap_touch(main, tree, target_overlay.keep_button.get_global_rect().get_center())
	_expect(
		main.state.inventory_marks.size() == 1
		and main.state.inventory_marks.get(target_key, "") == "keep"
		and mark_signal_count[0] == signal_before + 1
		and panel.selected_item_key() == sibling_key,
		"Viewport/Main touch must replace Salvage with exactly one Keep mutation",
	)

	target_index = _visible_card_index(panel, target_key)
	target_overlay = panel.row_mark_overlays[target_index]
	var marks_before_rejected_touch: Dictionary = main.state.inventory_marks.duplicate(true)
	signal_before = mark_signal_count[0]
	await _tap_touch(main, tree, target_overlay.salvage_button.get_global_rect().get_center())
	_expect(
		main.state.inventory_marks == marks_before_rejected_touch
		and mark_signal_count[0] == signal_before
		and panel.selected_item_key() == sibling_key,
		"Disabled Keep -> Salvage touch must be consumed without mutation, signal, or parent-card click-through",
	)
	main.queue_free()
	await tree.process_frame


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
	main._on_build_camp_upgrade("ritual_table")
	_expect(
		main.crusher_object_button.visible
		and main.whetstone_object_button.visible
		and main.ritual_table_object_button.visible,
		"Built camp services must become visible interactive objects",
	)
	_expect(
		not Rect2(main.crusher_object_button.position, main.crusher_object_button.size).intersects(
			Rect2(main.whetstone_object_button.position, main.whetstone_object_button.size)
		)
		and main.whetstone_object_button.position.x + main.whetstone_object_button.size.x < 828.0,
		"Camp service hitboxes must not overlap each other or the sidebar",
	)
	await _test_service_close_matrix(main, tree)
	await _test_programmatic_menu_from_service(main, tree)
	await _push_action(main, tree, "game_menu")
	_expect(
		main.main_menu_open and not main.settings_open,
		"Generic Base game-menu input must open the unified Main Menu instead of Settings",
	)
	main._resume_from_main_menu()
	await tree.process_frame
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
	main.state.loadout["right_hand"] = "bone_bow@2"
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
	await _push_key(main, tree, KEY_ESCAPE)
	_expect(
		not main.dismantle_all_confirmation_pending and main.inventory_service_mode == "crusher",
		"First physical Esc during destructive confirmation must cancel only that confirmation",
	)
	main._on_inventory_dismantle_all_pressed()
	await _push_joy_button(main, tree, JOY_BUTTON_B)
	_expect(
		not main.dismantle_all_confirmation_pending and main.inventory_service_mode == "crusher",
		"First physical B during destructive confirmation must cancel only that confirmation",
	)
	await _push_joy_button(main, tree, JOY_BUTTON_B)
	_expect(main.inventory_service_mode.is_empty(), "Second physical B must close the Crusher service")
	main.crusher_object_button.pressed.emit()
	await tree.process_frame
	main._on_inventory_dismantle_all_pressed()
	main._on_inventory_dismantle_all_pressed()
	_expect(
		main.state.inventory.is_empty() and main.state.loadout["right_hand"] == "bone_bow@2",
		"Confirmed Dismantle All must ignore the current filter and preserve loadout",
	)
	await _push_key(main, tree, KEY_ESCAPE)
	_expect(main.inventory_service_mode.is_empty(), "Second physical Esc must return from the service to base")
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
	var original_name: String = main.state.character_name
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		main.state.character_name = "Путник с очень долгим именем" if locale == "ru" else "The Long-Named Soulwalker"
		main._apply_locale()
		main._refresh_character_sheet()
		var expected_header := "%s · %s" % [
			main.state.character_name,
			Loc.text(String(GameRules.FORMS[main.state.current_form_id]["name"])),
		]
		_expect(
			(main.title_label.text == expected_header or main.title_label.text.ends_with("…"))
			and main.title_label.tooltip_text.contains(main.state.character_name)
			and main.title_label.get_theme_font_size("font_size") >= 18,
			"Long Character name/form header must ellipsize with full RU/EN tooltip in %s" % locale,
		)
	Loc.set_locale("ru")
	main.state.character_name = original_name
	main._apply_locale()
	main._refresh_character_sheet()
	var geometry_by_zoom: Array[Dictionary] = []
	for zoom in [44, 66, 88]:
		main.dungeon_cell_size = zoom
		main._refresh_character_sheet()
		geometry_by_zoom.append({
			"panel": Rect2(main.inventory_panel.position, main.inventory_panel.size),
			"head": Rect2(main.character_equipment_buttons["head"].position, main.character_equipment_buttons["head"].size),
		})
	_expect(
		geometry_by_zoom[0] == geometry_by_zoom[1] and geometry_by_zoom[1] == geometry_by_zoom[2],
		"Character UI geometry must remain independent from dungeon zoom 44/66/88",
	)
	main._select_character_panel("skills")
	var skills_has_character_residue: bool = main.inventory_panel.visible
	for slot_id in GameRules.EQUIPMENT_SLOT_ORDER:
		skills_has_character_residue = skills_has_character_residue or main.character_equipment_buttons[slot_id].visible
	_expect(not skills_has_character_residue, "Skills must contain zero visible Character inventory or slot controls")
	_expect(not main.character_status_strip.visible, "Skills must hide the Character status strip")
	for child in main.character_status_strip.get_children():
		_expect(not (child as Control).is_visible_in_tree(), "Skills must hide every focusable Character status descendant")
	for control in main.inventory_panel.focusable_controls():
		_expect(not control.is_visible_in_tree(), "Skills must exclude hidden inventory controls from the live focus graph")
	main._select_character_panel("inventory")
	_expect(
		main.inventory_panel.equip_button.visible
		and main.inventory_panel.dismantle_button.visible
		and main.inventory_panel.upgrade_button.visible,
		"Base character sheet must retain equip, Crusher and Whetstone shortcuts",
	)
	main.inventory_panel.select_equipment_slot("jacket", true)
	main.inventory_panel.refresh()
	var state_before_localized_jacket: Dictionary = main.state.to_save_data()
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		main._apply_locale()
		main.inventory_panel.select_equipment_slot("jacket", true)
		main.inventory_panel.refresh()
		var jacket_details: String = main.inventory_panel.selected_detail_label.text
		var jacket_slot_line := Loc.text("INVENTORY_SLOT_LINE", [Loc.text("SLOT_JACKET")])
		var jacket_bonus_line := Loc.text("INVENTORY_SOUL_LEVEL_BONUS", [1])
		var jacket_lock_line := Loc.text("INVENTORY_PERMANENT_LOCKED")
		var expected_item_name := "Уютный пиджак" if locale == "ru" else "Cozy Jacket"
		var expected_slot_name := "Плащ" if locale == "ru" else "Cloak"
		var expected_lock_copy := "Не хочется снимать" if locale == "ru" else "Too cozy to take off"
		var jacket_panels: Array[Label] = [
			main.inventory_panel.selected_detail_label,
			main.inventory_panel.equipped_detail_label,
		]
		var both_panels_exact := true
		for detail_panel in jacket_panels:
			both_panels_exact = (
				both_panels_exact
				and detail_panel.text.contains(expected_item_name)
				and detail_panel.text.contains(jacket_slot_line)
				and detail_panel.text.count(jacket_bonus_line) == 1
				and detail_panel.text.count(jacket_lock_line) == 1
			)
		_expect(
			both_panels_exact
			and jacket_details.contains(expected_item_name)
			and jacket_slot_line.contains(expected_slot_name)
			and jacket_details.contains(expected_lock_copy)
			and jacket_details.contains(jacket_slot_line)
			and jacket_details.count(jacket_bonus_line) == 1
			and jacket_details.count(jacket_lock_line) == 1
			and main.inventory_panel.filter_id == "all"
			and main.inventory_panel.filter_buttons["all"].button_pressed
			and main.state.to_save_data() == state_before_localized_jacket
			and main.inventory_panel.equip_button.disabled
			and main.inventory_panel.equip_button.tooltip_text == expected_lock_copy
			and main.inventory_panel.equip_button.accessibility_name == expected_lock_copy
			and main.inventory_panel.dismantle_button.disabled
			and main.inventory_panel.dismantle_button.tooltip_text == expected_lock_copy
			and main.inventory_panel.dismantle_button.accessibility_name == expected_lock_copy
			and main.inventory_panel.upgrade_button.disabled
			and main.inventory_panel.upgrade_button.text == expected_lock_copy
			and main.inventory_panel.upgrade_button.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
			and main.inventory_panel.upgrade_button.tooltip_text == expected_lock_copy
			and main.inventory_panel.upgrade_button.accessibility_name == expected_lock_copy
			and main.character_equipment_buttons["jacket"].tooltip_text.contains(expected_lock_copy)
			and main.character_equipment_buttons["jacket"].accessibility_name == main.character_equipment_buttons["jacket"].tooltip_text,
			"Selected jacket must show its physical slot and each localized bonus/lock line exactly once in %s" % locale,
		)
	Loc.set_locale("ru")
	main._apply_locale()
	main.inventory_panel.set_filter("armor")
	main.inventory_panel.select_item("rotting_mail@0", "inventory")
	var shortcut_cloth_before := int(main.state.resources["cloth"])
	main._on_inventory_dismantle_pressed()
	_expect(
		int(main.state.resources["cloth"]) == shortcut_cloth_before + 2,
		"Character-sheet Crusher shortcut must use the same exact salvage rules as the station",
	)
	main._close_character()
	await _test_character_focus_and_close(main, tree)
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
	main.auto_travel_active = true
	await _push_action(main, tree, "game_menu")
	_expect(
		main.main_menu_open and not main.auto_travel_active,
		"Game menu must remain reachable during auto-travel and cancel the transient travel state",
	)
	main._resume_from_main_menu()
	main.queue_free()


func _test_character_focus_and_close(main, tree: SceneTree) -> void:
	main.character_button.grab_focus()
	main._show_character()
	main._select_character_panel("skills")
	await tree.process_frame
	var skills_clean: bool = not main.inventory_panel.visible
	for slot_id in GameRules.EQUIPMENT_SLOT_ORDER:
		skills_clean = skills_clean and not main.character_equipment_buttons[slot_id].visible
	_expect(
		skills_clean,
		"Skills must expose only its own focus graph and no Inventory slot residue",
	)
	await _push_joy_button(main, tree, JOY_BUTTON_B)
	await tree.process_frame
	_expect(
		main.screen == main.Screen.BASE
		and main.get_viewport().gui_get_focus_owner() == main.character_button,
		"Physical B must close Skills and restore the prior valid Base focus",
	)
	main._show_character()
	main._select_character_panel("inventory")
	await tree.process_frame
	var offhand_button: Button = main.character_equipment_buttons["left_hand"]
	var offhand_ghost: TextureRect = main.character_equipment_ghosts["left_hand"]
	var state_before_ghost_redirect: Dictionary = main.state.to_save_data()
	_expect(
		offhand_ghost.visible
		and offhand_ghost.texture != null
		and is_equal_approx(offhand_ghost.modulate.a, 0.40)
		and is_equal_approx(offhand_button.modulate.a, 1.0)
		and offhand_button.icon == null
		and offhand_button.tooltip_text.contains(Loc.text("WEAPON_GHOST_TOOLTIP"))
		and offhand_button.accessibility_name.contains(Loc.text("WEAPON_GHOST_TOOLTIP")),
		"Two-handed Off Hand must use only a 40% icon layer while frame, focus, hit rect and accessible explanation stay full strength",
	)
	offhand_button.pressed.emit()
	await tree.process_frame
	_expect(
		main.inventory_panel.selected_destination_slot() == "right_hand"
		and main.state.to_save_data() == state_before_ghost_redirect,
		"Selecting the UI-only Off Hand ghost must redirect to real Main Hand without model/save mutation",
	)
	main.character_equipment_buttons["right_hand"].grab_focus()
	await _push_action(main, tree, "ui_accept")
	_expect(
		main.inventory_panel.selected_destination_slot() == "right_hand",
		"Gamepad A on a physical slot must route to the exact destination slot",
	)
	var state_before_jacket_accept: Dictionary = main.state.to_save_data()
	main.character_equipment_buttons["jacket"].grab_focus()
	await _push_action(main, tree, "ui_accept")
	_expect(
		main.inventory_panel.selected_destination_slot() == "jacket"
		and main.inventory_panel.selected_equipped_slot() == "jacket"
		and main.inventory_panel.selected_item_key() == GameRules.permanent_jacket_key()
		and main.inventory_panel.filter_id == "all"
		and main.inventory_panel.filter_buttons["all"].button_pressed
		and main.state.to_save_data() == state_before_jacket_accept,
		"Gamepad A on the Cozy Jacket slot must select the exact physical slot and force All without gameplay mutation",
	)
	# Regression: selecting a physical item after the permanent jacket must discard
	# the incompatible stale Cloak destination and resolve the item's real slot.
	var knife_key: String = main.state.add_item("bone_knife")
	var displaced_weapon := String(main.state.loadout.get("right_hand", ""))
	main.inventory_panel.refresh()
	main.inventory_panel.set_filter("all")
	var knife_visible_index := -1
	for entry_index in range(main.inventory_panel.entries.size()):
		var entry: Dictionary = main.inventory_panel.entries[entry_index]
		if String(entry.get("key", "")) == knife_key and String(entry.get("source", "")) == "inventory":
			knife_visible_index = entry_index - main.inventory_panel.page * main.inventory_panel.PAGE_SIZE
			break
	_expect(knife_visible_index >= 0, "Jacket-to-knife regression fixture must expose the knife row")
	if knife_visible_index >= 0:
		main.inventory_panel.select_visible_index(knife_visible_index)
		main._sync_inventory_panel_state()
		_expect(
			main.inventory_panel.selected_equipped_slot().is_empty()
			and main.inventory_panel.selected_destination_slot().is_empty()
			and (
				displaced_weapon.is_empty()
				or main.inventory_panel.equipped_detail_label.text.contains(
					PanelClass.display_name(displaced_weapon)
				)
			),
			"Inventory selection must clear stale jacket state and compare against the actual Main Hand",
		)
		main._on_inventory_equip_pressed()
		_expect(
			main.state.loadout.get("right_hand", "") == knife_key
			and (
				displaced_weapon.is_empty()
				or int(main.state.inventory.get(displaced_weapon, 0)) >= 1
			),
			"Jacket → Bone Knife → Equip must equip the knife in the real Main Hand",
		)
	var locked_item_key: String = main.state.add_item("rotting_mail")
	var locked_result: Dictionary = main.state.equip_from_inventory(locked_item_key)
	_expect(
		not bool(locked_result.get("ok", true))
		and locked_result.get("reason", "") == "slot_locked"
		and locked_result.get("slot", "") == "body"
		and int(main.state.inventory.get(locked_item_key, 0)) >= 1,
		"Skeleton + Rotting Mail must return the exact locked physical Body slot without mutation",
	)
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		var locked_reason: String = main._inventory_equip_failure_text(
			locked_result, locked_item_key,
		)
		var choice_reason: String = main._inventory_equip_failure_text(
			{"reason": "slot_choice_required", "slots": ["ring_1", "ring_2"]},
			"aiming_ring@0",
		)
		_expect(
			locked_reason == Loc.text("MSG_EQUIP_SLOT_LOCKED", [
				PanelClass.display_name(locked_item_key),
				Loc.text("SLOT_BODY"),
				Loc.text(String(main.state.get_form().name)),
			])
			and choice_reason.contains(Loc.text("SLOT_RING_1"))
			and choice_reason.contains(Loc.text("SLOT_RING_2")),
			"Structured equip failures must retain exact localized physical-slot reasons in %s" % locale,
		)
	Loc.set_locale("ru")
	main._apply_locale()
	var skills_click_position: Vector2 = (
		main.skills_mode_button.global_position + main.skills_mode_button.size * 0.5
	)
	await _click_mouse(main, tree, skills_click_position)
	_expect(main.character_panel_mode == "skills", "Mouse must switch Character to the Skills tab")
	await _tap_touch(
		main, tree,
		main.inventory_mode_button.global_position + main.inventory_mode_button.size * 0.5,
	)
	_expect(main.character_panel_mode == "inventory", "ScreenTouch must switch Character back to Inventory")
	await _push_key(main, tree, KEY_ESCAPE)
	_expect(main.screen == main.Screen.BASE and not main.inventory_panel.visible, "Physical Esc must close Character without click-through")


func _test_service_close_matrix(main, tree: SceneTree) -> void:
	var close_signal_count: Array[int] = [0]
	main.inventory_panel.close_requested.connect(func(): close_signal_count[0] += 1)
	var service_specs := [
		["crusher", main.crusher_object_button, PanelClass.Mode.CRUSHER, "all"],
		["whetstone", main.whetstone_object_button, PanelClass.Mode.WHETSTONE, "weapon"],
		["ritual_table", main.ritual_table_object_button, PanelClass.Mode.RITUAL, "all"],
	]
	for spec in service_specs:
		for close_method in ["escape", "gamepad_b", "mouse", "touch", "focus"]:
			var close_count_before: int = close_signal_count[0]
			var inventory_before: Dictionary = main.state.inventory.duplicate(true)
			var resources_before: Dictionary = main.state.resources.duplicate(true)
			var loadout_before: Dictionary = main.state.loadout.duplicate(true)
			var turns_before: int = main.state.total_turns
			(spec[1] as Button).pressed.emit()
			await tree.process_frame
			await tree.process_frame
			_expect(
				main.inventory_service_mode == spec[0]
				and main.inventory_panel.mode == spec[2]
				and main.inventory_panel.filter_id == spec[3]
				and main.inventory_panel.visible
				and main.inventory_panel.close_button.visible
				and main.inventory_panel._focusable_controls().has(
					main.get_viewport().gui_get_focus_owner()
				),
				"Reopened %s service must restore mode, filter, close control and focus" % spec[0],
			)
			match close_method:
				"escape":
					await _push_key(main, tree, KEY_ESCAPE, false, false)
					await _push_key(main, tree, KEY_ESCAPE, true, true)
					_expect(not main.inventory_service_mode.is_empty(), "Esc release/echo must not close %s" % spec[0])
					await _push_key(main, tree, KEY_ESCAPE)
				"gamepad_b":
					await _push_joy_button(main, tree, JOY_BUTTON_B, false)
					_expect(not main.inventory_service_mode.is_empty(), "B release must not close %s" % spec[0])
					await _push_joy_button(main, tree, JOY_BUTTON_B)
				"mouse":
					await _click_mouse(main, tree, _service_close_center(main))
				"touch":
					await _tap_touch(main, tree, _service_close_center(main))
				"focus":
					main.inventory_panel.close_button.grab_focus()
					await _push_action(main, tree, "ui_accept")
			await tree.process_frame
			_expect(
				main.inventory_service_mode.is_empty()
				and not main.inventory_panel.visible
				and not main.main_menu_open
				and main.screen == main.Screen.BASE
				and main.start_button.visible and main.camp_build_button.visible
				and not main.upgrade_button.visible
				and not main.build_crusher_button.visible and not main.build_whetstone_button.visible
				and not main.build_ritual_table_button.visible and main.character_button.visible
				and main.menu_button.visible and main.camp_upgrades_label.visible
				and main.hint_label.visible and main.message_label.visible
				and main.crusher_object_button.visible
				and main.whetstone_object_button.visible
				and main.ritual_table_object_button.visible
				and main.get_viewport().gui_get_focus_owner() == spec[1],
				"%s close via %s must symmetrically restore the complete Base UI and source-service focus" % [spec[0], close_method],
			)
			_expect(
				close_signal_count[0] == close_count_before + 1,
				"%s close via %s must emit exactly one close request" % [spec[0], close_method],
			)
			_expect(
				main.state.inventory == inventory_before
				and main.state.resources == resources_before
				and main.state.loadout == loadout_before
				and main.state.total_turns == turns_before,
				"Closing %s via %s must not mutate inventory, resources, loadout or turns" % [spec[0], close_method],
			)


func _test_programmatic_menu_from_service(main, tree: SceneTree) -> void:
	var state_before: Dictionary = main.state.to_save_data()
	main.ritual_table_object_button.pressed.emit()
	await tree.process_frame
	main._open_main_menu()
	await tree.process_frame
	_expect(
		main.main_menu_open
		and main.inventory_service_mode.is_empty()
		and not main.inventory_panel.visible
		and main.start_button.visible and main.menu_button.visible
		and main.camp_upgrades_label.visible and main.hint_label.visible and main.message_label.visible,
		"Programmatic Main Menu opening must close the active service through its symmetric lifecycle",
	)
	main._resume_from_main_menu()
	await tree.process_frame
	await tree.process_frame
	_expect(
		not main.main_menu_open
		and main.screen == main.Screen.BASE
		and main.get_viewport().gui_get_focus_owner() == main.ritual_table_object_button
		and main.state.to_save_data() == state_before,
		"Resume after service-to-menu transition must restore exact in-memory Base state and focus",
	)


func _service_close_center(main) -> Vector2:
	return (
		main.inventory_panel.global_position
		+ main.inventory_panel.close_button.position
		+ main.inventory_panel.close_button.size * 0.5
	)


func _push_key(
	main,
	tree: SceneTree,
	keycode: Key,
	pressed := true,
	echo := false,
) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	main.get_viewport().push_input(event, true)
	await tree.process_frame


func _push_key_cycle(main, tree: SceneTree, keycode: Key) -> void:
	for pressed in [true, false]:
		await _push_key(main, tree, keycode, pressed)


func _push_joy_button(main, tree: SceneTree, button: JoyButton, pressed := true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	main.get_viewport().push_input(event, true)
	await tree.process_frame


func _push_action(main, tree: SceneTree, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	main.get_viewport().push_input(event, true)
	await tree.process_frame


func _push_action_cycle(main, tree: SceneTree, action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		event.strength = 1.0 if pressed else 0.0
		main.get_viewport().push_input(event, true)
		await tree.process_frame


func _push_joy_cycle(main, tree: SceneTree, button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		event.pressure = 1.0 if pressed else 0.0
		main.get_viewport().push_input(event, true)
		await tree.process_frame


func _click_mouse(main, tree: SceneTree, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	main.get_viewport().push_input(motion, true)
	await tree.process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		main.get_viewport().push_input(event, true)
		await tree.process_frame


func _tap_touch(main, tree: SceneTree, position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.pressed = pressed
		event.position = position
		main.get_viewport().push_input(event, true)
		await tree.process_frame


func _visible_card_index(panel, item_key: String) -> int:
	for index in range(panel.row_buttons.size()):
		if not panel.row_buttons[index].visible:
			continue
		var absolute_index: int = panel.page * panel.PAGE_SIZE + index
		if (
			absolute_index < panel.entries.size()
			and String(panel.entries[absolute_index].get("key", "")) == item_key
		):
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
