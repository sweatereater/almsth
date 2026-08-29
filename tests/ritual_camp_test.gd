class_name RitualCampTestSuite
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const PanelClass := preload("res://scripts/ui/inventory_panel.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_bound_item_model()
	_test_death_and_campfire()
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
		state.unequip("weapon")["ok"]
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
	var built := fire.build_camp_upgrade("campfire")
	_expect(
		bool(built.get("ok", false))
		and fire.get_max_hp() == old_max_hp + 1
		and fire.hp == old_hp + 1,
		"The one-time Campfire must add one maximum HP and fill the new point",
	)
	_expect(
		not bool(fire.build_camp_upgrade("campfire").get("ok", false))
		and not fire.can_upgrade_base(),
		"The Campfire must be one-time and replace repeatable base upgrading",
	)
	var legacy := RunState.new()
	legacy.character_name = "Legacy hearth"
	_expect(
		legacy.restore_save_data({"character_name": "Legacy hearth", "base_level": 3})
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
	dying.bind_item("bone_knife@0", "equipped", "weapon")
	dying.add_item("rotting_mail")
	dying.equip_from_inventory("rotting_mail@0")
	dying.bind_item("rotting_mail@0", "equipped", "armor")
	dying.add_item("grave_mace", 0, 2)
	dying.carried_souls = 7
	var losses := dying.die()
	_expect(
		losses == {"souls": 7, "items": 2}
		and dying.loadout.get("weapon", "") == "bone_knife@0:bound"
		and int(dying.inventory.get("rotting_mail@0:bound", 0)) == 1
		and not dying.inventory.has("grave_mace@0"),
		"Death must keep bound gear, move locked-form gear to inventory and lose ordinary loot",
	)


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
	main.state.add_resources({"wood": 30, "stone": 30, "cloth": 10})
	main.state.banked_souls = 50
	main.state.add_item("bone_bow", 2)
	main.state.loadout["weapon"] = "bone_knife@1"
	main._on_build_camp_upgrade("ritual_table")
	main._on_upgrade_pressed()
	_expect(
		main.ritual_table_object_button.visible
		and bool(main.state.camp_upgrades["campfire"])
		and main.upgrade_button.disabled,
		"Built Ritual Table must become interactive and Campfire construction must disable itself",
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
	main.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
