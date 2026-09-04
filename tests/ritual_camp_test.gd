class_name RitualCampTestSuite
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const PanelClass := preload("res://scripts/ui/inventory_panel.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const BaseLayout := preload("res://scripts/ui/base_layout.gd")
const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_bound_item_model()
	_test_death_and_campfire()
	_test_build_registry_and_prerequisites()
	await _test_ritual_interface(tree)
	Loc.set_locale("ru")
	return failures


func _test_bound_item_model() -> void:
	var normal_key := GameRules.make_item_key("bone_knife", 2)
	var bound_key := GameRules.bound_item_key(normal_key)
	_expect(bound_key == "bone_knife@2:bound", "Binding must produce a stable explicit item key")
	_expect(
		GameRules.is_item_bound(bound_key)
		and GameRules.base_item_id(bound_key) == "bone_knife"
		and GameRules.item_upgrade_level(bound_key) == 2,
		"Bound keys must preserve base id and upgrade level",
	)

	var state := RunState.new()
	state.camp_upgrades["ritual_table"] = true
	state.banked_souls = 100
	state.add_item("bone_knife", 0, 2)
	var result := state.bind_item("bone_knife@0", "inventory")
	_expect(
		bool(result.get("ok", false))
		and state.banked_souls == 75
		and int(state.inventory.get("bone_knife@0", 0)) == 1
		and int(state.inventory.get("bone_knife@0:bound", 0)) == 1,
		"A ritual must bind exactly one stack instance and charge 25 souls",
	)
	_expect(
		not bool(state.bind_item("bone_knife@0:bound", "inventory").get("ok", false)),
		"An already bound instance must not be charged twice",
	)
	_expect(state.equip_from_inventory("bone_knife@0:bound")["ok"], "A bound item must remain equippable")
	_expect(
		state.unequip("right_hand")["ok"]
		and int(state.inventory.get("bone_knife@0:bound", 0)) == 1,
		"Unequipping must preserve the bound identity",
	)

	state.camp_upgrades["crusher"] = true
	_expect(
		state.dismantle_item("bone_knife@0:bound").get("reason", "") == "bound",
		"Crusher must reject a bound item",
	)
	var bulk := state.dismantle_all_items()
	_expect(
		bool(bulk.get("ok", false))
		and int(bulk.get("count", 0)) == 1
		and state.inventory == {"bone_knife@0:bound": 1},
		"Dismantle All must salvage only unbound items and preserve bound stacks",
	)

	state.camp_upgrades["whetstone"] = true
	state.add_resources(GameRules.WEAPON_UPGRADE_COST)
	var upgraded := state.upgrade_weapon("bone_knife@0:bound", 0.0, 1.0)
	_expect(
		bool(upgraded.get("ok", false))
		and upgraded.get("item_key", "") == "bone_knife@1:bound"
		and state.inventory == {"bone_knife@1:bound": 1},
		"Whetstone upgrades must carry the binding to the transformed item key",
	)

	state.character_name = "Bound save"
	var restored := RunState.new()
	_expect(restored.restore_save_data(state.to_save_data()), "A save containing bound gear must restore")
	_expect(
		restored.inventory == state.inventory
		and bool(restored.camp_upgrades["ritual_table"]),
		"Bound item identity and Ritual Table must survive a save round-trip",
	)


func _test_death_and_campfire() -> void:
	var fire := RunState.new()
	fire.hp = maxi(1, fire.get_max_hp() - 2)
	fire.add_resources({"wood": 3, "stone": 3})
	var old_max_hp := fire.get_max_hp()
	var old_hp := fire.hp
	var old_soul_level := fire.soul_level
	var built := fire.build_camp_upgrade("campfire")
	_expect(
		bool(built.get("ok", false))
		and fire.get_max_hp() == old_max_hp
		and fire.hp == old_hp
		and fire.soul_level == old_soul_level + 1,
		"The one-time Campfire must add one Soul Level without HP or healing",
	)
	_expect(
		not bool(fire.build_camp_upgrade("campfire").get("ok", false))
		and not fire.can_upgrade_base(),
		"The Campfire must be one-time and replace repeatable base upgrading",
	)
	var legacy := RunState.new()
	legacy.character_name = "Legacy shelter"
	_expect(
		legacy.restore_save_data({"character_name": "Legacy shelter", "base_level": 3})
		and legacy.base_level == 3
		and not bool(legacy.camp_upgrades["campfire"]),
		"Old base levels must remain effective without fabricating a Campfire",
	)

	var dying := RunState.new()
	dying.current_form_id = "almost_human"
	dying.highest_unlocked_form_index = 4
	dying.camp_upgrades["ritual_table"] = true
	dying.banked_souls = 100
	dying.add_item("bone_knife")
	dying.equip_from_inventory("bone_knife@0")
	dying.bind_item("bone_knife@0", "equipped", "right_hand")
	dying.add_item("rotting_mail")
	dying.equip_from_inventory("rotting_mail@0")
	dying.bind_item("rotting_mail@0", "equipped", "body")
	dying.add_item("grave_mace", 0, 2)
	dying.carried_souls = 7
	var losses := dying.die()
	_expect(
		losses == {"souls": 7, "items": 2}
		and dying.loadout.get("right_hand", "") == "bone_knife@0:bound"
		and int(dying.inventory.get("rotting_mail@0:bound", 0)) == 1
		and not dying.inventory.has("grave_mace@0"),
		"Death must keep bound gear, move locked-form gear to inventory and lose ordinary loot",
	)


func _test_build_registry_and_prerequisites() -> void:
	var expected_ids := [
		"campfire", "kettle", "bunk", "crusher", "whetstone", "ritual_table", "mural",
		"workbench", "writing_set", "textile_area", "rocking_chair", "record_player",
		"storage_chest",
	]
	var actual_ids := GameRules.CAMP_UPGRADES.keys()
	actual_ids.sort()
	expected_ids.sort()
	_expect(actual_ids == expected_ids, "Camp registry must contain exactly the 13 stable IDs")
	var state := RunState.new()
	var before := state.to_snapshot_data()
	_expect(
		state.build_camp_upgrade("kettle").get("reason", "") == "prerequisite"
		and state.to_snapshot_data() == before,
		"Kettle must require Campfire before any resource mutation",
	)
	_expect(
		state.build_camp_upgrade("writing_set").get("reason", "") == "prerequisite",
		"Writing Set must require Workbench",
	)
	_expect(bool(state.build_camp_upgrade("workbench").get("ok", false)), "Workbench must be free")
	_expect(bool(state.build_camp_upgrade("writing_set").get("ok", false)), "Writing Set must become free after Workbench")
	_expect(bool(state.build_camp_upgrade("textile_area").get("ok", false)), "Textile Area must be free")
	_expect(bool(state.build_camp_upgrade("record_player").get("ok", false)), "Record Player must be free")
	_expect(state.resources == {"wood": 0, "stone": 0, "cloth": 0}, "Free modules must spend no resources")
	state.resources.wood = 29
	before = state.to_snapshot_data()
	_expect(
		not bool(state.build_camp_upgrade("rocking_chair").get("ok", false))
		and state.to_snapshot_data() == before,
		"Rocking Chair must reject at 29 wood without mutation",
	)
	state.resources.wood = 30
	_expect(
		bool(state.build_camp_upgrade("rocking_chair").get("ok", false))
		and state.resources.wood == 0 and state.soul_level == 1,
		"Rocking Chair must spend exactly 30 wood and grant raw Soul +1 once",
	)
	_expect(not state.is_camp_upgrade_revealed("mural"), "Mural must be completely hidden until the tail")


func _test_ritual_interface(tree: SceneTree) -> void:
	for locale in Loc.SUPPORTED_LOCALES:
		for key in [
			"CAMP_RITUAL_TABLE", "CAMP_CAMPFIRE", "CAMP_BUILD_RITUAL_TABLE",
			"CAMP_BUILD_CAMPFIRE", "INVENTORY_SERVICE_RITUAL",
			"INVENTORY_BIND_ACTION", "INVENTORY_BOUND_STATUS",
			"CAMP_OBJECT_RITUAL_TABLE_TOOLTIP",
		]:
			_expect(Loc.STRINGS[locale].has(key), "Ritual localization %s missing in %s" % [key, locale])

	var packed := load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.character_name = "Ritual QA"
	main._show_base("")
	_test_base_resource_strip(main)
	await _test_base_relayout(main, tree)
	_test_base_upgrade_list_absence(main)
	main.state.add_resources({"wood": 30, "stone": 30, "cloth": 10})
	main.state.banked_souls = 50
	main.state.add_item("bone_bow", 2)
	main.state.loadout["right_hand"] = "bone_knife@1"
	main._on_build_camp_upgrade("ritual_table")
	main._on_build_camp_upgrade("campfire")
	_expect(
		main.ritual_table_object_button.visible
		and bool(main.state.camp_upgrades["campfire"])
		and main.camp_build_button.visible
		and not main.upgrade_button.visible,
		"Built Ritual Table must become interactive while construction stays in the single modal button",
	)
	_expect(
		not Rect2(main.ritual_table_object_button.position, main.ritual_table_object_button.size).intersects(
			Rect2(main.crusher_object_button.position, main.crusher_object_button.size)
		)
		and not Rect2(main.ritual_table_object_button.position, main.ritual_table_object_button.size).intersects(
			Rect2(main.whetstone_object_button.position, main.whetstone_object_button.size)
		),
		"Ritual Table hitbox must not overlap the other service objects",
	)
	main.ritual_table_object_button.pressed.emit()
	_expect(
		main.inventory_service_mode == "ritual_table"
		and main.inventory_panel.mode == PanelClass.Mode.RITUAL,
		"The Ritual Table object must open its dedicated service mode",
	)
	var sources := PackedStringArray()
	for entry in main.inventory_panel.entries:
		sources.append("%s:%s" % [entry["key"], entry["source"]])
	_expect(
		sources.has("bone_bow@2:inventory") and sources.has("bone_knife@1:equipped"),
		"Ritual service must offer both inventory and equipped item identities",
	)
	main.inventory_panel.select_item("bone_bow@2", "inventory")
	main._on_inventory_bind_pressed()
	_expect(
		int(main.state.inventory.get("bone_bow@2:bound", 0)) == 1
		and main.state.get_total_souls() == 25
		and main.inventory_panel.selected_detail_label.text.contains(Loc.text("INVENTORY_BOUND_STATUS"))
		and main.inventory_panel.upgrade_button.disabled,
		"Binding through the service must update souls, selection and bound presentation immediately",
	)
	main._close_inventory_service()
	main.state.camp_upgrades["crusher"] = true
	main.state.camp_upgrades["whetstone"] = true
	main._refresh_interface()
	await _test_base_transitions(main, tree)
	main.queue_free()


func _test_base_resource_strip(main) -> void:
	var strip_rect: Rect2 = main.BASE_RESOURCE_STRIP_RECT
	var title_rect := Rect2(main.title_label.position, main.title_label.size)
	var soul_icon_rect := Rect2(main.soul_icon.position, main.soul_icon.size)
	var souls_rect := Rect2(main.souls_label.position, main.souls_label.size)
	var materials_rect := Rect2(
		main.material_resources_strip.position, main.material_resources_strip.size
	)
	var menu_rect := Rect2(main.menu_button.position, main.menu_button.size)
	var image_rect: Rect2 = BaseLayout.IMAGE_RECT
	var sidebar_rect: Rect2 = BaseLayout.SIDEBAR_RECT
	_expect(
		strip_rect == Rect2(520, 18, 326, 44)
		and title_rect == main.BASE_TITLE_RECT
		and soul_icon_rect == Rect2(520, 29, 22, 22)
		and souls_rect == Rect2(544, 18, 104, 44)
		and materials_rect == Rect2(648, 18, 198, 44),
		"Base resources must use the exact compact 1280x720 top-strip geometry",
	)
	_expect(
		strip_rect.encloses(soul_icon_rect)
		and strip_rect.encloses(souls_rect)
		and strip_rect.encloses(materials_rect)
		and not strip_rect.intersects(title_rect)
		and not strip_rect.intersects(menu_rect)
		and not strip_rect.intersects(image_rect)
		and not strip_rect.intersects(sidebar_rect),
		"Base resource strip must not overlap the title, menu, image or sidebar",
	)
	_expect(
		main.soul_icon.visible
		and main.souls_label.visible
		and main.material_resources_strip.visible
		and main.souls_label.mouse_filter == Control.MOUSE_FILTER_PASS
		and main.material_resources_strip.mouse_filter == Control.MOUSE_FILTER_PASS,
		"Base resource counters must be visible, tooltip-capable and non-blocking",
	)
	var expected_counter_rects := {
		"wood": Rect2(0, 0, 66, 44),
		"stone": Rect2(66, 0, 66, 44),
		"cloth": Rect2(132, 0, 66, 44),
	}
	var previous_counter_rect := Rect2()
	for resource_id in ["wood", "stone", "cloth"]:
		var counter = main.material_resources_strip.get_counter(resource_id)
		var counter_rect := Rect2(counter.position, counter.size)
		_expect(
			counter != null
			and counter.resource_id == resource_id
			and counter_rect == expected_counter_rects[resource_id]
			and Rect2(Vector2.ZERO, materials_rect.size).encloses(counter_rect)
			and counter.mouse_filter == Control.MOUSE_FILTER_PASS
			and counter.focus_mode == Control.FOCUS_ALL
			and counter.clip_contents
			and counter.value_label.get_theme_font_size("font_size") == 12
			and counter.value_label.get_theme_font("font").get_instance_id()
			== ThemeController.functional_font("regular", true).get_instance_id()
			and counter.value_label.get_theme_color("font_color")
			== Palette.color(Palette.WARM_ARCHIVE, "primary")
			and counter.normal_style.get_instance_id()
			== ThemeController.style_for(
				Palette.WARM_ARCHIVE, "material_counter", "normal"
			).get_instance_id()
			and counter.hover_style.get_instance_id()
			== ThemeController.style_for(
				Palette.WARM_ARCHIVE, "material_counter", "hover"
			).get_instance_id()
			and counter.focus_style.get_instance_id()
			== ThemeController.style_for(
				Palette.WARM_ARCHIVE, "material_counter", "focus"
			).get_instance_id()
			and not counter.focus_neighbor_left.is_empty()
			and not counter.focus_neighbor_right.is_empty()
			and Rect2(Vector2.ZERO, counter.size).encloses(counter.icon_rect())
			and Rect2(Vector2.ZERO, counter.size).encloses(
				Rect2(counter.value_label.position, counter.value_label.size)
			),
			"Each material must own one independent, clipped icon/value hit region",
		)
		if previous_counter_rect.has_area():
			_expect(
				not previous_counter_rect.intersects(counter_rect),
				"Material counter hit regions must never overlap",
			)
		previous_counter_rect = counter_rect

	var virtual_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 0),
		ProjectSettings.get_setting("display/window/size/viewport_height", 0),
	)
	var physical_size := Vector2(960, 540)
	var canvas_scale := physical_size.x / virtual_size.x
	var scaled_strip := Rect2(strip_rect.position * canvas_scale, strip_rect.size * canvas_scale)
	_expect(
		virtual_size == Vector2(1280, 720)
		and ProjectSettings.get_setting("display/window/stretch/mode", "") == "canvas_items"
		and ProjectSettings.get_setting("display/window/stretch/aspect", "") == "keep"
		and is_equal_approx(canvas_scale, 0.75)
		and scaled_strip == Rect2(390, 13.5, 244.5, 33)
		and scaled_strip.end.x <= physical_size.x
		and scaled_strip.end.y <= physical_size.y,
		"Base resource strip must scale predictably to the supported 960x540 canvas",
	)
	for resource_id in ["wood", "stone", "cloth"]:
		var counter = main.material_resources_strip.get_counter(resource_id)
		_expect(
			counter.icon_rect().size == Vector2(22, 22)
			and counter.ICON_STROKE_WIDTH * canvas_scale >= 2.0,
			"Material icon silhouettes must retain at least 2 physical px strokes at 960x540",
		)

	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		for key in [
			"BASE_RESOURCE_WOOD_TOOLTIP",
			"BASE_RESOURCE_STONE_TOOLTIP",
			"BASE_RESOURCE_CLOTH_TOOLTIP",
		]:
			_expect(Loc.STRINGS[locale].has(key), "Base resource localization %s missing in %s" % [key, locale])
		main.state.carried_souls = 0
		main.state.banked_souls = 0
		main.state.resources = {"wood": 0, "stone": 0, "cloth": 0}
		main._apply_locale()
		var zero_values_are_numeric := true
		for resource_id in ["wood", "stone", "cloth"]:
			zero_values_are_numeric = (
				zero_values_are_numeric
				and main.material_resources_strip.get_counter(resource_id).value_label.text == "0"
			)
		_expect(
			main.souls_label.text == "0 (0)" and zero_values_are_numeric,
			"Base resource strip must show zero-valued souls and materials in %s" % locale,
		)

		main.state.carried_souls = 4321
		main.state.banked_souls = 10000
		main.state.resources = {"wood": 9876, "stone": 5432, "cloth": 1000}
		main._refresh_interface()
		var expected_values := {"wood": 9876, "stone": 5432, "cloth": 1000}
		var tooltip_keys := {
			"wood": "BASE_RESOURCE_WOOD_TOOLTIP",
			"stone": "BASE_RESOURCE_STONE_TOOLTIP",
			"cloth": "BASE_RESOURCE_CLOTH_TOOLTIP",
		}
		var expected_souls_tooltip := Loc.text("BASE_SOULS_TOOLTIP", [4321, 14321])
		_expect(
			main.souls_label.text == "4321 (14321)",
			"Base resource strip must show four-digit RU/EN values without changing totals",
		)
		_expect(
			main.souls_label.tooltip_text == expected_souls_tooltip
			and main.souls_label.accessibility_name == expected_souls_tooltip,
			"Base soul counter must expose complete localized tooltip and accessibility text",
		)
		for resource_id in ["wood", "stone", "cloth"]:
			var counter = main.material_resources_strip.get_counter(resource_id)
			var expected_tooltip := Loc.text(
				tooltip_keys[resource_id], [expected_values[resource_id]]
			)
			_expect(
				counter.value_label.text == str(expected_values[resource_id])
				and counter.value_label.text.is_valid_int()
				and counter.tooltip_text == expected_tooltip
				and counter.accessibility_name == expected_tooltip,
				"Each icon-only counter must expose its localized full name and exact value",
			)
			var material_text_width: float = counter.value_label.get_theme_font(
				"font"
			).get_string_size(
				counter.value_label.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				counter.value_label.get_theme_font_size("font_size"),
			).x
			_expect(
				material_text_width <= counter.value_label.size.x,
				"Four-digit material values must fit without clipping in %s" % locale,
			)
		_expect(
			not main.camp_upgrades_label.text.begins_with(
				Loc.text("CAMP_RESOURCES", [9876, 5432, 1000])
			)
			and main.camp_upgrades_label.text.is_empty(),
			"Base sidebar reserves the old text area for the new construction controls",
		)
		var soul_text_width: float = main.souls_label.get_theme_font("font").get_string_size(
			main.souls_label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			main.souls_label.get_theme_font_size("font_size"),
		).x
		_expect(
			soul_text_width <= main.souls_label.size.x,
			"Four-digit soul totals must fit the compact base counter in %s" % locale,
		)

	main.state.carried_souls = 4321
	main.state.banked_souls = 6789
	main.state.safe_return()
	main._refresh_interface()
	_expect(
		main.souls_label.text == "0 (11110)"
		and main.souls_label.tooltip_text == Loc.text("BASE_SOULS_TOOLTIP", [0, 11110]),
		"Safe return must naturally bank carried souls before the base strip refreshes",
	)
	main.state.resources = {"wood": 0, "stone": 0, "cloth": 0}
	main.state.carried_souls = 0
	main.state.banked_souls = 0
	Loc.set_locale("ru")
	main._apply_locale()


func _test_base_relayout(main, tree: SceneTree) -> void:
	var image_rect: Rect2 = BaseLayout.IMAGE_RECT
	var sidebar_rect: Rect2 = BaseLayout.SIDEBAR_RECT
	_expect(
		image_rect == Rect2(28, 78, 818, 480)
		and image_rect.end.x == 846
		and sidebar_rect.position.x == 858
		and sidebar_rect.position.x - image_rect.end.x == 12,
		"Base image must use the exact 818x480 runtime target with a 12px sidebar gap",
	)
	_expect(
		main.BASE_IMAGE_RECT == image_rect
		and main.BASE_SIDEBAR_RECT == sidebar_rect
		and not image_rect.intersects(sidebar_rect)
		and not image_rect.intersects(main.BASE_RESOURCE_STRIP_RECT)
		and not sidebar_rect.intersects(main.BASE_RESOURCE_STRIP_RECT),
		"Image, sidebar and top resource strip must remain disjoint",
	)

	var sidebar_contracts := [
		[main.stats_label, BaseLayout.STATS_RECT],
		[main.status_strip, BaseLayout.STATUS_RECT],
		[main.sidebar_progress_label, BaseLayout.PROGRESS_RECT],
		[main.camp_upgrades_label, BaseLayout.CAMP_UPGRADES_RECT],
		[main.start_button, BaseLayout.START_RECT],
		[main.camp_build_button, BaseLayout.BUILD_RECT],
	]
	for contract in sidebar_contracts:
		var control: Control = contract[0]
		var expected_rect: Rect2 = contract[1]
		_expect(
			Rect2(control.position, control.size) == expected_rect
			and sidebar_rect.encloses(expected_rect),
			"Every base-only sidebar control must use the shared narrow-sidebar layout",
		)
	var ordered_sidebar_rects := [
		BaseLayout.STATS_RECT, BaseLayout.HP_RECT, BaseLayout.MANA_RECT,
		BaseLayout.STATUS_RECT, BaseLayout.PROGRESS_RECT, BaseLayout.CAMP_UPGRADES_RECT,
		BaseLayout.START_RECT, BaseLayout.BUILD_RECT,
	]
	for first_index in range(ordered_sidebar_rects.size()):
		for second_index in range(first_index + 1, ordered_sidebar_rects.size()):
			_expect(
				not ordered_sidebar_rects[first_index].intersects(
					ordered_sidebar_rects[second_index]
				),
				"Base sidebar rows must not overlap after narrowing",
			)
	_expect(
		BaseLayout.STATS_RECT == Rect2(876, 78, 362, 72)
		and BaseLayout.HP_RECT == Rect2(876, 158, 362, 28)
		and BaseLayout.MANA_RECT == Rect2(876, 196, 362, 28)
		and BaseLayout.STATUS_RECT == Rect2(876, 232, 362, 30)
		and BaseLayout.BUILD_CAMPFIRE_RECT.end.y == 699.0
		and sidebar_rect.encloses(BaseLayout.BUILD_CAMPFIRE_RECT),
		"The expanded identity block and shifted Base rows must keep their exact in-sidebar geometry",
	)
	var sequential_action_rects := [
		BaseLayout.START_RECT,
		BaseLayout.BUILD_CRUSHER_RECT,
		BaseLayout.BUILD_WHETSTONE_RECT,
		BaseLayout.BUILD_RITUAL_TABLE_RECT,
		BaseLayout.BUILD_CAMPFIRE_RECT,
	]
	for first_index in range(sequential_action_rects.size()):
		var first_rect: Rect2 = sequential_action_rects[first_index]
		_expect(sidebar_rect.encloses(first_rect), "Every Base action must remain inside the sidebar")
		for second_index in range(first_index + 1, sequential_action_rects.size()):
			_expect(
				not first_rect.intersects(sequential_action_rects[second_index]),
				"Base camp actions must remain visually disjoint after the identity row expands",
			)

	var original_name: String = main.state.character_name
	var original_form: String = main.state.current_form_id
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		main.state.character_name = (
			"Странница Архивов с именем длиннее границ старой летописи"
			if locale == "ru"
			else "The Archive Wanderer Whose Name Outlives the Old Chronicle"
		)
		main.state.current_form_id = "almost_human"
		main._apply_locale()
		await tree.process_frame
		RenderingServer.force_draw(false)
		await tree.process_frame
		var identity_font_size: int = main.stats_label.get_theme_font_size("font_size")
		var identity_line_count: int = main.stats_label.get_line_count()
		var visible_identity_lines: int = main.stats_label.get_visible_line_count()
		var identity_rect := Rect2(main.stats_label.position, main.stats_label.size)
		var form_text := Loc.text("SIDEBAR_FORM", [
			Loc.text(String(GameRules.FORMS["almost_human"]["name"])),
		])
		var visual_gap: float = BaseLayout.HP_RECT.position.y - identity_rect.end.y
		for output_size in [Vector2(1280, 720), Vector2(960, 540)]:
			var canvas_scale: float = output_size.x / 1280.0
			_expect(
				main.stats_label.text.begins_with(main.state.character_name + "\n")
				and main.stats_label.text.ends_with(form_text)
				and identity_line_count >= 3
				and visible_identity_lines == identity_line_count
				and ThemeController.is_approved_font_size(identity_font_size)
				and identity_font_size >= 12
				and visual_gap * canvas_scale >= 3.0
				and main.stats_label.clip_text
				and main.stats_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
				and main.stats_label.tooltip_text == main.stats_label.text
				and main.stats_label.accessibility_name == main.stats_label.text,
				"Full long %s Base identity and Form must remain readable above HP at %dx%d" % [
					locale, int(output_size.x), int(output_size.y),
				],
			)
	main.state.character_name = original_name
	main.state.current_form_id = original_form
	Loc.set_locale("ru")
	main._apply_locale()
	await tree.process_frame
	_expect(
		Rect2(main.character_button.position, main.character_button.size)
			== BaseLayout.CHARACTER_BUTTON_RECT
		and not BaseLayout.CHARACTER_BUTTON_RECT.intersects(
			Rect2(main.menu_button.position, main.menu_button.size)
		)
		and Rect2(main.hint_label.position, main.hint_label.size) == BaseLayout.HINT_RECT
		and Rect2(main.message_label.position, main.message_label.size) == BaseLayout.MESSAGE_RECT
		and not BaseLayout.HINT_RECT.intersects(sidebar_rect)
		and not BaseLayout.MESSAGE_RECT.intersects(sidebar_rect),
		"Base header, hint and message must remain inside the canvas without sidebar overlap",
	)

	for module_id in GameRules.CAMP_DRAW_ORDER:
		var local_rect: Rect2 = BaseLayout.CAMP_LAYER_LOCAL_RECTS[module_id]
		var mapped_overlay := BaseLayout.camp_layer_rect(module_id)
		_expect(
			mapped_overlay == Rect2(image_rect.position + local_rect.position, local_rect.size)
			and image_rect.encloses(mapped_overlay),
			"Every camp layer must use its exact documented local draw rect: %s" % module_id,
		)
	var station_buttons := {
		"crusher": main.crusher_object_button,
		"whetstone": main.whetstone_object_button,
		"ritual_table": main.ritual_table_object_button,
		"kettle": main.stage1_object_buttons["kettle"],
	}
	for station_id in station_buttons:
		var mapped_hitbox := BaseLayout.station_hitbox_rect(station_id)
		var actual_button: Button = station_buttons[station_id]
		var actual_rect := Rect2(actual_button.position, actual_button.size)
		_expect(
			_rect_approx(actual_rect, mapped_hitbox)
			and image_rect.encloses(mapped_hitbox)
			and mapped_hitbox.intersects(BaseLayout.camp_layer_rect(station_id))
			and actual_rect.has_point(actual_rect.get_center()),
			"Station %s must use its exact new-art hitbox inside the owning layer" % station_id,
		)

	main.state.active_statuses = {
		"rested": {"remaining_turns": 300, "temporary_hp": 5},
		"satiated": {"remaining_turns": 200, "temporary_hp": 3},
	}
	main._refresh_interface()
	_expect(
		main.status_strip.visible
		and Rect2(main.status_strip.position, main.status_strip.size) == BaseLayout.STATUS_RECT
		and main.status_strip.get_child_count() == 2,
		"Active statuses must remain visible in their non-overlapping base sidebar row",
	)
	main.state.active_statuses.clear()
	main._refresh_interface()

	var physical_scale := 0.75
	for rect in [
		image_rect, sidebar_rect, BaseLayout.CHARACTER_BUTTON_RECT,
		BaseLayout.HINT_RECT, BaseLayout.MESSAGE_RECT,
	]:
		var physical_rect := Rect2(rect.position * physical_scale, rect.size * physical_scale)
		_expect(
			physical_rect.end.x <= 960 and physical_rect.end.y <= 540,
			"Base composition must stay inside the 960x540 canvas after uniform scaling",
		)


func _test_base_upgrade_list_absence(main) -> void:
	var upgrade_states := [
		{},
		{"crusher": true},
		{
			"crusher": true,
			"whetstone": true,
			"ritual_table": true,
			"campfire": true,
		},
	]
	var service_buttons := {
		"crusher": main.crusher_object_button,
		"whetstone": main.whetstone_object_button,
		"ritual_table": main.ritual_table_object_button,
	}
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		_expect(
			not Loc.STRINGS[locale].has("CAMP_INSTALLED")
			and not Loc.STRINGS[locale].has("CAMP_INSTALLED_NONE"),
			"Removed installed-upgrades list localization must stay absent in %s" % locale,
		)
		for upgrade_state in upgrade_states:
			for upgrade_id in GameRules.CAMP_UPGRADES:
				main.state.camp_upgrades[upgrade_id] = bool(upgrade_state.get(upgrade_id, false))
			main._apply_locale()
			_expect(
				main.camp_upgrades_label.text.is_empty()
				and not main.camp_upgrades_label.text.contains("Установленные улучшения")
				and not main.camp_upgrades_label.text.contains("Installed upgrades"),
				"Base must omit the textual installed list with none, some or all upgrades",
			)
			for service_id in service_buttons:
				_expect(
					service_buttons[service_id].visible
						== bool(upgrade_state.get(service_id, false)),
					"Removing the list must not change installed station visibility",
				)
			_expect(
				main.camp_build_button.text == Loc.text("CAMP_BUILD_BUTTON")
				and main.camp_build_button.visible
				and not main.upgrade_button.visible
				and not main.build_crusher_button.visible
				and not main.build_whetstone_button.visible
				and not main.build_ritual_table_button.visible,
				"Base must expose exactly one permanent Build entry point below Start",
			)
	for upgrade_id in GameRules.CAMP_UPGRADES:
		main.state.camp_upgrades[upgrade_id] = false
	main.state.trophies.minotaur_tail = 0
	main._open_camp_build_panel()
	_expect(
		main.camp_build_panel.visible
		and main.camp_build_panel.rows.size() == 12
		and not main.camp_build_panel.rows.has("mural")
		and main.camp_build_panel.rows.has("record_player")
		and main.camp_build_panel.rows.has("storage_chest")
		and main.camp_build_panel.rows["writing_set"].button.disabled
		and main.camp_build_panel.rows["storage_chest"].panel.get_index()
			== main.camp_build_panel.rows_box.get_child_count() - 1,
		"Blocking Build modal must list all revealed rows, hide Mural and keep the last row scroll-reachable",
	)
	main.state.trophies.minotaur_tail = 1
	main.camp_build_panel.refresh()
	_expect(main.camp_build_panel.rows.has("mural"), "Mural row must appear immediately after tail reveal")
	main.camp_build_panel.close()
	Loc.set_locale("ru")
	main._apply_locale()


func _test_base_transitions(main, tree: SceneTree) -> void:
	main.camp_build_button.grab_focus()
	main._open_camp_build_panel()
	await tree.process_frame
	_expect(
		main.camp_build_panel.visible
		and not main.start_button.visible
		and main.camp_build_panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		"Build modal must block and cover the underlying Base controls",
	)
	main.camp_build_panel.close()
	await tree.process_frame
	_expect(
		not main.camp_build_panel.visible
		and main.start_button.visible
		and main.camp_build_button.visible
		and tree.root.get_viewport().gui_get_focus_owner() == main.camp_build_button,
		"Closing Build with Esc/B/close semantics must restore focus to the Build button",
	)
	var station_modes := {
		"crusher": PanelClass.Mode.CRUSHER,
		"whetstone": PanelClass.Mode.WHETSTONE,
		"ritual_table": PanelClass.Mode.RITUAL,
	}
	var station_buttons := {
		"crusher": main.crusher_object_button,
		"whetstone": main.whetstone_object_button,
		"ritual_table": main.ritual_table_object_button,
	}
	for station_id in station_buttons:
		var button: Button = station_buttons[station_id]
		_expect(
			button.visible and button.focus_mode == Control.FOCUS_ALL and not button.disabled,
			"Every installed station must remain focusable and clickable after relayout",
		)
		button.pressed.emit()
		_expect(
			main.inventory_service_mode == station_id
			and main.inventory_panel.mode == station_modes[station_id]
			and Rect2(0, 0, 1280, 720).encloses(
				Rect2(main.inventory_panel.position, main.inventory_panel.size)
			),
			"Each mapped station hitbox must still open its uncropped service menu",
		)
		main._close_inventory_service()
		await tree.process_frame
		_expect(
			main.screen == main.Screen.BASE
			and _rect_approx(
				Rect2(button.position, button.size), BaseLayout.station_hitbox_rect(station_id)
			)
			and main.start_button.visible
			and main.start_button.focus_mode == Control.FOCUS_ALL,
			"Closing %s must restore Base: screen=%s rect=%s expected=%s visible=%s focus_mode=%s" % [
				station_id, main.screen, Rect2(button.position, button.size),
				BaseLayout.station_hitbox_rect(station_id), main.start_button.visible,
				main.start_button.focus_mode,
			],
		)

	main._show_character()
	_expect(main.screen == main.Screen.CHARACTER, "Relayout must preserve the Base-to-Character transition")
	main._close_character()
	_expect(
		main.screen == main.Screen.BASE
		and Rect2(main.stats_label.position, main.stats_label.size) == BaseLayout.STATS_RECT
		and Rect2(main.start_button.position, main.start_button.size) == BaseLayout.START_RECT,
		"Closing Character must restore the exact relaid-out Base sidebar",
	)
	main._open_main_menu()
	_expect(main.main_menu_open, "Relayout must preserve opening the Base menu")
	main._resume_from_main_menu()
	_expect(
		not main.main_menu_open
		and main.screen == main.Screen.BASE
		and Rect2(main.camp_upgrades_label.position, main.camp_upgrades_label.size)
			== BaseLayout.CAMP_UPGRADES_RECT,
		"Closing the menu must restore the exact relaid-out Base composition",
	)


func _rect_approx(first: Rect2, second: Rect2) -> bool:
	return (
		first.position.distance_to(second.position) <= 0.0001
		and first.size.distance_to(second.size) <= 0.0001
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
