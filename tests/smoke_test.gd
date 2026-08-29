extends SceneTree

const Loc := preload("res://scripts/localization/localization.gd")
const InputProfile := preload("res://scripts/system/input_bindings.gd")
const StoreBridge := preload("res://scripts/platform/store_gateway.gd")
const RegressionSuite := preload("res://tests/regression_test.gd")
const AbilitySuite := preload("res://tests/ability_test.gd")
const RangedCombatSuite := preload("res://tests/ranged_combat_test.gd")
const InventoryUiSuite := preload("res://tests/inventory_ui_test.gd")
const RitualCampSuite := preload("res://tests/ritual_camp_test.gd")
const AudioSuite := preload("res://tests/audio_test.gd")
const DungeonViewportSuite := preload("res://tests/dungeon_viewport_test.gd")
const WikiContractSuite := preload("res://tests/wiki_contract_test.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_localization()
	_test_platform_foundations()
	_test_run_state()
	_test_floor_generation()
	var regression_failures: Array[String] = await RegressionSuite.new().run(self)
	failures.append_array(regression_failures)
	var ability_failures: Array[String] = await AbilitySuite.new().run(self)
	failures.append_array(ability_failures)
	var ranged_failures: Array[String] = await RangedCombatSuite.new().run(self)
	failures.append_array(ranged_failures)
	var inventory_ui_failures: Array[String] = await InventoryUiSuite.new().run(self)
	failures.append_array(inventory_ui_failures)
	var ritual_camp_failures: Array[String] = await RitualCampSuite.new().run(self)
	failures.append_array(ritual_camp_failures)
	var audio_failures: Array[String] = await AudioSuite.new().run(self)
	failures.append_array(audio_failures)
	var dungeon_viewport_failures: Array[String] = await DungeonViewportSuite.new().run(self)
	failures.append_array(dungeon_viewport_failures)
	var wiki_contract_failures: Array[String] = WikiContractSuite.new().run(self)
	failures.append_array(wiki_contract_failures)
	await _test_main_scene()

	if failures.is_empty():
		print("SMOKE TEST PASSED")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	print("SMOKE TEST FAILED: %d failure(s)" % failures.size())
	quit(1)


func _test_localization() -> void:
	for key in Loc.STRINGS["ru"]:
		_expect(Loc.STRINGS["en"].has(key), "English dictionary must contain localization key %s" % key)
	for key in Loc.STRINGS["en"]:
		_expect(Loc.STRINGS["ru"].has(key), "Russian dictionary must contain localization key %s" % key)
	Loc.set_locale("ru")


func _test_platform_foundations() -> void:
	InputProfile.ensure_defaults()
	for action in InputProfile.GAMEPLAY_ACTIONS:
		_expect(InputMap.has_action(action), "Input action %s must exist" % action)
		_expect(not InputMap.action_get_events(action).is_empty(), "Input action %s must have defaults" % action)
	var has_gamepad_movement := false
	var has_e_character_binding := false
	var has_g_ascend_binding := false
	var has_q_magic_binding := false
	var has_x_explore_binding := false
	var has_l3_explore_binding := false
	for event in InputMap.action_get_events("move_up"):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			has_gamepad_movement = true
	_expect(has_gamepad_movement, "Movement actions must include gamepad bindings")
	for event in InputMap.action_get_events("character_sheet"):
		if event is InputEventKey and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
			has_e_character_binding = true
	_expect(has_e_character_binding, "E must open the character sheet")
	for event in InputMap.action_get_events("ascend_floor"):
		if event is InputEventKey and (event.keycode == KEY_G or event.physical_keycode == KEY_G):
			has_g_ascend_binding = true
	_expect(has_g_ascend_binding, "G must activate ascent to the stairs")
	for event in InputMap.action_get_events("cast_spell"):
		if event is InputEventKey and (event.keycode == KEY_Q or event.physical_keycode == KEY_Q):
			has_q_magic_binding = true
	_expect(has_q_magic_binding, "Q must cast the selected spell")
	for event in InputMap.action_get_events("auto_explore"):
		if event is InputEventKey and (event.keycode == KEY_X or event.physical_keycode == KEY_X):
			has_x_explore_binding = true
		elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_STICK:
			has_l3_explore_binding = true
	_expect(has_x_explore_binding, "X must start automatic exploration")
	_expect(has_l3_explore_binding, "L3 must start automatic exploration on a gamepad")
	_expect(not InputProfile.GAMEPLAY_ACTIONS.has("evolve_form"), "Evolution must not keep a separate E action")
	_expect(
		ProjectSettings.get_setting("display/window/size/viewport_width") == 1280
		and ProjectSettings.get_setting("display/window/size/viewport_height") == 720,
		"The virtual canvas must use a 16:9 design resolution",
	)
	_expect(
		ProjectSettings.get_setting("display/window/stretch/aspect") == "keep",
		"Non-16:9 windows must preserve the designed aspect ratio",
	)
	var presets := ConfigFile.new()
	_expect(presets.load("res://export_presets.cfg") == OK, "Export presets must load")
	_expect(
		presets.get_value("preset.1", "platform", "") == "Windows Desktop",
		"A standalone Windows export preset must be available",
	)
	var store_gateway = StoreBridge.new()
	store_gateway.configure_for_current_build()
	_expect(store_gateway.initialize(), "The store-neutral gateway must initialize without a store SDK")
	_expect(Loc.text("FORM_SKELETON") == "Скелет", "Russian localization must resolve data keys")
	Loc.set_locale("en")
	_expect(Loc.text("FORM_SKELETON") == "Skeleton", "English localization must resolve data keys")
	_expect(Loc.text("FREE_POINTS", [5]) == "Free points: 5", "Localized templates must format values")
	_expect(Loc.text("MISSING_TEST_KEY") == "MISSING_TEST_KEY", "Missing translations must fail visibly")
	Loc.set_locale("ru")


func _test_run_state() -> void:
	var run := RunState.new()
	_expect(run.current_form_id == "skeleton", "A new body must start as a skeleton")
	_expect(run.get_max_hp() == 8, "Skeleton HP must include base form and vitality")
	_expect(run.get_damage() == 1, "Strength must produce rounded melee damage")
	_expect(run.mana == run.get_max_mana(), "A new body must start with full mana")
	_expect(run.get_accuracy() == 1 and run.get_dodge() == 1, "Perception and agility must drive combat ratings")
	_expect(run.get_vision_radius() == 4, "A new character must see four cells")
	_expect(run.get_derived_stats()["regeneration"] == 0, "A skeleton must have no regeneration stat")
	_expect(
		GameRules.ENEMIES["hollow_guard"]["max_hp"] == 4
		and GameRules.ENEMIES["soul_leech"]["max_hp"] == 5,
		"Enemies stronger than the Grave Rat must receive the small HP increase",
	)
	_expect(
		GameRules.SLOT_NAMES.has("hands") and not GameRules.SLOT_NAMES.has("mutation"),
		"The old mutation equipment slot must be replaced by hands",
	)
	var glove_rules: Dictionary = GameRules.EQUIPMENT["leather_gloves"]
	var ghoul_without_gloves := GameRules.calculate_derived_stats(
		GameRules.default_attributes(), "ghoul"
	)
	var ghoul_with_gloves := GameRules.calculate_derived_stats(
		GameRules.default_attributes(),
		"ghoul",
		{"hands": GameRules.make_item_key("leather_gloves")},
	)
	_expect(
		glove_rules["slot"] == "hands"
		and glove_rules["damage"] == 0
		and ghoul_with_gloves["damage"] == ghoul_without_gloves["damage"],
		"Leather Gloves must occupy hands and grant no damage",
	)
	_expect(is_equal_approx(run.get_cradle_chance(), 0.05), "A new run must start with a five-percent Cradle chance")
	run.record_cradle_result(false)
	_expect(is_equal_approx(run.get_cradle_chance(), 0.10), "A floor without a Cradle must add five percentage points")
	run.record_cradle_result(true)
	_expect(is_equal_approx(run.get_cradle_chance(), 0.05), "Finding a Cradle must reset its chance")
	var high_attributes := {
		"strength": 6,
		"agility": 6,
		"perception": 6,
		"vitality": 6,
		"wisdom": 6,
	}
	var high_derived := GameRules.calculate_derived_stats(high_attributes, "skeleton")
	_expect(high_derived["damage"] == 3, "Strength coefficient must round to whole damage")
	_expect(high_derived["accuracy"] == 6 and high_derived["dodge"] == 6, "Accuracy and dodge coefficients must be direct")
	_expect(high_derived["max_hp"] == 18, "Vitality must add two HP per point to form HP")
	_expect(high_derived["mana"] == 30, "Wisdom must add five mana per point")
	_expect(
		high_derived["spell_power"] == 1 and high_derived["regeneration"] == 0,
		"Skeleton Wisdom may grant spell power, but bones must never regenerate",
	)
	_expect(high_derived["ranged_damage"] == 3, "Perception must add rounded ranged damage")
	_expect(
		high_derived["mana_regeneration_percent"] == 3,
		"Every full five Wisdom must add one percentage point of mana regeneration",
	)

	var mana_regeneration := RunState.new()
	mana_regeneration.mana = 0
	var mana_restored_total := 0
	for _index in range(10):
		mana_restored_total += int(mana_regeneration.advance_survival_turn()["mana_restored"])
	_expect(
		mana_restored_total == 1 and mana_regeneration.mana == 1,
		"Two-percent mana regeneration must retain fractions instead of rounding every turn",
	)
	var wise_regeneration := RunState.new()
	wise_regeneration.attributes["wisdom"] = 5
	wise_regeneration.mana = 0
	for _index in range(4):
		wise_regeneration.advance_survival_turn()
	_expect(
		wise_regeneration.get_mana_regeneration_percent() == 3 and wise_regeneration.mana == 3,
		"Five Wisdom must regenerate three percent of maximum mana per turn",
	)

	var vision_progression := RunState.new()
	vision_progression.configure_character("Sharp Sight", GameRules.default_attributes())
	vision_progression.banked_souls = 200
	var locked_sharp_vision := vision_progression.purchase_skill("sharp_vision")
	_expect(
		not locked_sharp_vision["ok"] and locked_sharp_vision["reason"] == "stage_locked",
		"Sharp Vision must remain locked until the revenant stage is reached",
	)
	vision_progression.highest_unlocked_form_index = GameRules.FORM_ORDER.find("revenant")
	var first_sharp_vision := vision_progression.purchase_skill("sharp_vision")
	var second_sharp_vision := vision_progression.purchase_skill("sharp_vision")
	_expect(
		first_sharp_vision["ok"] and first_sharp_vision["cost"] == 80
		and second_sharp_vision["ok"] and second_sharp_vision["cost"] == 120
		and vision_progression.get_vision_radius() == 6,
		"Two Sharp Vision levels must cost 80/120 souls and extend vision to six cells",
	)
	_expect(
		vision_progression.purchase_skill("sharp_vision")["reason"] == "max_level",
		"Sharp Vision must stop at level two",
	)
	var restored_vision_progression := RunState.new()
	restored_vision_progression.restore_save_data(vision_progression.to_save_data())
	_expect(
		restored_vision_progression.get_skill_level("sharp_vision") == 2
		and restored_vision_progression.get_vision_radius() == 6,
		"Sharp Vision levels and their bonus must survive saving",
	)

	var magic_progression := RunState.new()
	magic_progression.banked_souls = 1000
	var mana_before_awakening := magic_progression.get_max_mana()
	var awakening := magic_progression.purchase_skill("magic_awakening")
	_expect(
		awakening["ok"] and awakening["cost"] == 40
		and magic_progression.get_max_mana() == mana_before_awakening + 5,
		"Magic Awakening must cost 40 souls and grant five maximum mana",
	)
	_expect(
		magic_progression.purchase_skill("magic_missile")["ok"]
		and magic_progression.get_magic_missile_damage() == 3
		and magic_progression.get_magic_missile_range() == 3,
		"First-level Magic Missile must deal three base damage at three-cell range",
	)
	magic_progression.purchase_skill("magic_missile")
	magic_progression.purchase_skill("magic_missile")
	_expect(magic_progression.get_magic_missile_damage() == 5, "Each additional missile level must add one damage")
	_expect(
		magic_progression.purchase_skill("magic_missile_range")["ok"]
		and magic_progression.get_magic_missile_range() == 5,
		"The missile range skill must add exactly two cells",
	)
	for _index in range(4):
		magic_progression.purchase_skill("magic_ricochet")
	_expect(
		is_equal_approx(magic_progression.get_magic_ricochet_chance(), 0.35),
		"Ricochet must start at twenty percent and gain five points through level four",
	)

	run.add_souls(12)
	var first_evolution := run.evolve_at_cradle()
	_expect(first_evolution["ok"], "Ten carried souls at a Cradle must unlock zombie form")
	_expect(run.current_form_id == "zombie", "A Cradle must advance exactly to the next form")
	_expect(run.carried_souls == 2, "Evolution cost must be removed from carried souls")

	var equipment := run.equip("rotting_mail")
	_expect(equipment["ok"], "Zombie form must be able to equip armor")
	run.current_floor = 87
	var delivered := run.safe_return()
	_expect(delivered == 2 and run.banked_souls == 2, "Safe return must bank every carried soul")
	_expect(run.rope_floor == 87, "A safe return must anchor the rope at the best reached floor")
	run.current_floor = 92
	run.safe_return()
	_expect(run.rope_floor == 87, "Returning from a deeper floor must not move the rope backward")
	run.begin_expedition(run.rope_floor)
	_expect(run.current_floor == 87, "The rope destination must be a valid expedition start")

	run.add_souls(3)
	run.cradle_miss_streak = 4
	var losses := run.die()
	_expect(losses["souls"] == 3, "Death must report unbanked souls as lost")
	_expect(run.banked_souls == 2, "Death must never remove banked souls")
	_expect(run.current_form_id == "skeleton", "Death must rebuild the player as a skeleton")
	_expect(run.loadout.is_empty(), "Death must remove equipped gear")
	_expect(run.cradle_miss_streak == 0, "Death must reset accumulated Cradle chance")

	var inventory_run := RunState.new()
	var knife_key := inventory_run.add_item("bone_knife", 0, 2)
	_expect(
		inventory_run.inventory.get(knife_key, 0) == 2,
		"Identical items at the same upgrade level must stack",
	)
	_expect(inventory_run.equip_from_inventory(knife_key)["ok"], "Inventory equipment must move into a body slot")
	_expect(
		inventory_run.inventory.get(knife_key, 0) == 1
		and inventory_run.loadout.get("weapon", "") == knife_key,
		"Equipping must consume one stack entry without duplicating it",
	)
	_expect(inventory_run.unequip("weapon")["ok"], "Equipped items must return to inventory")
	_expect(inventory_run.inventory.get(knife_key, 0) == 2, "Unequipping must restore the stack count")
	inventory_run.add_resources({"wood": 20, "stone": 20, "cloth": 5})
	_expect(inventory_run.build_camp_upgrade("crusher")["ok"], "Crusher must be buildable for 5 wood and 5 stone")
	_expect(
		inventory_run.resources["wood"] == 15 and inventory_run.resources["stone"] == 15,
		"Crusher construction must spend its exact material cost",
	)
	_expect(inventory_run.build_camp_upgrade("whetstone")["ok"], "Whetstone must use wood, stone and cloth")
	_expect(
		inventory_run.resources == {"wood": 5, "stone": 5, "cloth": 0},
		"Whetstone construction must spend 10 wood, 10 stone and 5 cloth",
	)
	var armor_key := inventory_run.add_item("rotting_mail")
	var dismantled := inventory_run.dismantle_item(armor_key)
	_expect(
		dismantled["ok"] and inventory_run.resources["cloth"] == 2,
		"Dismantling armor in the Crusher must be the prototype source of cloth",
	)
	inventory_run.add_resources({"wood": 10, "stone": 50, "cloth": 5})
	var resources_before_upgrade: Dictionary = inventory_run.resources.duplicate(true)
	var upgraded := inventory_run.upgrade_weapon(knife_key, 1.0, 1.0)
	_expect(
		upgraded["ok"] and upgraded["new_level"] == 1,
		"The first weapon upgrade must always reach +1",
	)
	_expect(
		inventory_run.resources["wood"] == int(resources_before_upgrade["wood"]) - 2
		and inventory_run.resources["stone"] == int(resources_before_upgrade["stone"]) - 10
		and inventory_run.resources["cloth"] == int(resources_before_upgrade["cloth"]) - 1,
		"Every weapon-upgrade attempt must cost 2 wood, 10 stone and 1 cloth",
	)
	var plus_one_key := String(upgraded["item_key"])
	var downgraded := inventory_run.upgrade_weapon(plus_one_key, 0.9, 0.01)
	_expect(
		downgraded["outcome"] == "downgraded" and downgraded["new_level"] == 0,
		"A failed upgrade must have a five-percent chance to lose one level",
	)
	upgraded = inventory_run.upgrade_weapon(String(downgraded["item_key"]), 0.0, 1.0)
	upgraded = inventory_run.upgrade_weapon(String(upgraded["item_key"]), 0.49, 1.0)
	_expect(upgraded["new_level"] == 2, "The +2 upgrade must use a fifty-percent success chance")
	upgraded = inventory_run.upgrade_weapon(String(upgraded["item_key"]), 0.14, 1.0)
	_expect(upgraded["new_level"] == 3, "The +3 upgrade must use a fifteen-percent success chance")
	var upgraded_stats := GameRules.calculate_derived_stats(
		GameRules.default_attributes(), "skeleton", {"weapon": upgraded["item_key"]}
	)
	_expect(
		upgraded_stats["damage"] == 5 and upgraded_stats["accuracy"] == 5,
		"Each weapon upgrade must add one damage and one accuracy",
	)
	var equipped_upgrade := RunState.new()
	equipped_upgrade.camp_upgrades["whetstone"] = true
	equipped_upgrade.add_resources(GameRules.WEAPON_UPGRADE_COST)
	var equipped_knife_key := equipped_upgrade.add_item("bone_knife")
	_expect(
		equipped_upgrade.equip_from_inventory(equipped_knife_key)["ok"],
		"Equipped-upgrade test must place the weapon in the character's hand",
	)
	var equipped_upgrade_result := equipped_upgrade.upgrade_weapon(
		equipped_knife_key, 1.0, 1.0, "weapon"
	)
	_expect(
		equipped_upgrade_result["ok"]
		and GameRules.item_upgrade_level(equipped_upgrade.loadout["weapon"]) == 1
		and equipped_upgrade.inventory.is_empty(),
		"Sharpening an equipped weapon must keep its upgraded version equipped",
	)
	var bulk_salvage := RunState.new()
	bulk_salvage.camp_upgrades["crusher"] = true
	bulk_salvage.add_item("rotting_mail", 0, 2)
	bulk_salvage.add_item("bone_knife", 0, 3)
	var bulk_result := bulk_salvage.dismantle_all_items()
	_expect(
		bulk_result["ok"] and bulk_result["count"] == 5
		and bulk_salvage.inventory.is_empty()
		and bulk_salvage.resources == {"wood": 3, "stone": 3, "cloth": 4},
		"Dismantle all must salvage every stacked inventory item but not equipment",
	)

	var progression := RunState.new()
	progression.configure_character("Progression", GameRules.default_attributes())
	progression.banked_souls = 100
	var anywhere_purchase := RunState.new()
	anywhere_purchase.carried_souls = 3
	anywhere_purchase.banked_souls = 3
	_expect(anywhere_purchase.purchase_skill("strong_bones")["ok"], "Skills must use all available souls")
	_expect(
		anywhere_purchase.carried_souls == 0 and anywhere_purchase.banked_souls == 1,
		"A skill learned during an expedition must spend carried souls before stored souls",
	)
	var locked_fundamentals := progression.purchase_skill("fundamentals")
	_expect(
		not locked_fundamentals["ok"] and locked_fundamentals["reason"] == "prerequisite",
		"Skeleton skills must follow their prerequisite chain",
	)
	var hp_before_bones := progression.get_max_hp()
	var bones_purchase := progression.purchase_skill("strong_bones")
	_expect(bones_purchase["ok"], "Sturdy Bones must be purchasable with banked souls")
	_expect(
		progression.get_max_hp() == hp_before_bones + 3,
		"Each Sturdy Bones level must add exactly three maximum HP",
	)
	var fundamentals_purchase := progression.purchase_skill("fundamentals")
	_expect(fundamentals_purchase["ok"], "Develop Fundamentals must unlock after Sturdy Bones")
	_expect(progression.unspent_attribute_points == 5, "Develop Fundamentals must grant five attribute points once")
	var vitality_before := int(progression.attributes["vitality"])
	_expect(progression.spend_attribute_point("vitality"), "Granted attribute points must be spendable")
	_expect(
		progression.attributes["vitality"] == vitality_before + 1
		and progression.unspent_attribute_points == 4,
		"Spending an attribute point must update the stat and remaining pool",
	)
	var locked_regeneration := progression.purchase_skill("flesh_regeneration")
	_expect(
		not locked_regeneration["ok"] and locked_regeneration["reason"] == "stage_locked",
		"Zombie skills must remain locked until the zombie stage is reached",
	)
	progression.add_souls(10)
	_expect(progression.evolve_at_cradle()["ok"], "The Cradle must unlock zombie for progression tests")
	_expect(progression.is_stage_unlocked("zombie"), "Reaching zombie must permanently unlock its skill tab")
	_expect(
		progression.get_derived_stats()["regeneration"] == 1,
		"The zombie form must provide one base point of regeneration",
	)
	progression.hp = progression.get_max_hp() - 2
	var regeneration_hp_before_skill := progression.hp
	var regeneration_before_skill := progression.advance_survival_turn()
	_expect(
		regeneration_before_skill["healed"] == 0 and progression.hp == regeneration_hp_before_skill,
		"Zombie regeneration must remain inactive until its skill is learned",
	)
	_expect(progression.purchase_skill("flesh_regeneration")["ok"], "Zombie regeneration must be purchasable")
	progression.attributes["vitality"] = 1000
	progression.hp = progression.get_max_hp() - 2
	var regeneration_turn := progression.advance_survival_turn()
	_expect(regeneration_turn["healed"] == 1, "Regeneration 100 must restore one HP each turn")
	progression.hunger = 100
	progression.hunger_turn_progress = 0
	for _index in range(10):
		progression.advance_survival_turn()
	_expect(progression.hunger == 99, "Hunger must decrease by one percent every ten turns")
	progression.food = 1
	progression.hunger = 80
	var camp_result := progression.camp_and_eat()
	_expect(
		camp_result["ok"] and progression.hunger == 90 and progression.food == 0,
		"One food at camp must restore ten percent hunger",
	)
	progression.hunger = 0
	progression.hp = progression.get_max_hp()
	var hp_before_starvation := progression.hp
	var starvation := progression.advance_survival_turn()
	_expect(
		starvation["starvation_damage"] == ceili(progression.get_max_hp() * 0.02)
		and progression.hp == hp_before_starvation - int(starvation["starvation_damage"]),
		"Zero hunger must disable regeneration and deal two percent maximum-HP damage",
	)
	progression.food = 3
	progression.cradle_miss_streak = 3
	var progression_restored := RunState.new()
	_expect(
		progression_restored.restore_save_data(progression.to_save_data()),
		"Skill and survival progression must restore from save data",
	)
	_expect(
		progression_restored.get_skill_level("strong_bones") == 1
		and progression_restored.get_skill_level("fundamentals") == 1
		and progression_restored.get_skill_level("flesh_regeneration") == 1
		and progression_restored.unspent_attribute_points == 4
		and progression_restored.highest_unlocked_form_index == progression.highest_unlocked_form_index
		and progression_restored.food == 3
		and progression_restored.hunger == 0
		and progression_restored.cradle_miss_streak == 3,
		"Save data must preserve skills, free stats, survival and the Cradle chance streak",
	)
	var unlocked_before_death := progression.highest_unlocked_form_index
	progression.die()
	_expect(
		progression.get_skill_level("strong_bones") == 1
		and progression.highest_unlocked_form_index == unlocked_before_death,
		"Death must preserve learned skills and unlocked stage tabs",
	)

	run.configure_character("Saved", high_attributes)
	run.banked_souls = 17
	run.absorbed_souls = 10
	run.current_form_id = "zombie"
	run.loadout = {"armor": "rotting_mail"}
	var restored := RunState.new()
	_expect(restored.restore_save_data(run.to_save_data()), "Versioned run data must restore")
	_expect(
		restored.character_name == "Saved"
		and restored.banked_souls == 17
		and restored.rope_floor == 87
		and restored.current_form_id == "zombie"
		and GameRules.base_item_id(restored.loadout.get("armor", "")) == "rotting_mail",
		"Save data must preserve permanent progress, form and valid equipment",
	)
	var legacy_gloves_data := run.to_save_data()
	legacy_gloves_data["character_name"] = "Legacy Gloves"
	legacy_gloves_data["absorbed_souls"] = 24
	legacy_gloves_data["loadout"] = {"mutation": "iron_claws@0"}
	legacy_gloves_data["inventory"] = {"iron_claws@0": 2}
	var migrated_gloves := RunState.new()
	_expect(migrated_gloves.restore_save_data(legacy_gloves_data), "Legacy claw save data must restore")
	_expect(
		GameRules.base_item_id(migrated_gloves.loadout.get("hands", "")) == "leather_gloves"
		and migrated_gloves.inventory.get(GameRules.make_item_key("leather_gloves"), 0) == 2,
		"Old mutation slots and Iron Claws must migrate to hands and Leather Gloves",
	)


func _test_floor_generation() -> void:
	var floor_generator := FloorGenerator.new()
	var forced_cradle_floor := floor_generator.generate(99, 1001, 1.0)
	_expect(
		forced_cradle_floor["width"] == 20 and forced_cradle_floor["height"] == 14,
		"The expanded prototype field must be 20 by 14 cells",
	)
	var forced_cradle: Vector2i = forced_cradle_floor["cradle"]
	_expect(
		not forced_cradle_floor.get("exit_known", true)
		and forced_cradle_floor.get("visible_cells", {}).is_empty()
		and forced_cradle_floor.get("explored_cells", {}).is_empty()
		and forced_cradle_floor.get("observed_cells", {}).is_empty(),
		"Generated floors must begin unexplored with an unknown exit",
	)
	_expect(
		GameRules.ENEMIES["grave_rat"]["vision"] == 3
		and GameRules.ENEMIES["hollow_guard"]["vision"] == 5
		and GameRules.ENEMIES["soul_leech"]["vision"] == 4,
		"Enemy types must have distinct vision ranges",
	)
	_expect(forced_cradle.x >= 0, "A one-hundred-percent Cradle roll must place the object")
	_expect(
		forced_cradle_floor["tiles"].get(forced_cradle, "void") == "floor",
		"The Cradle must spawn on a walkable floor cell",
	)
	_expect(
		forced_cradle != forced_cradle_floor["start"]
		and forced_cradle != forced_cradle_floor["exit"]
		and forced_cradle != forced_cradle_floor["base_gate"],
		"The Cradle must not overlap mandatory level cells",
	)
	for seed_value in range(1, 101):
		var floor_data := floor_generator.generate(99, seed_value)
		var start: Vector2i = floor_data["start"]
		var exit: Vector2i = floor_data["exit"]
		var base_gate: Vector2i = floor_data["base_gate"]
		_expect(start != exit and start != base_gate and exit != base_gate, "Special cells must be unique")
		_expect(
			floor_generator._has_path(floor_data["tiles"], start, exit),
			"Generated floor %d must have a path to the surface" % seed_value,
		)
		_expect(
			floor_generator._has_path(floor_data["tiles"], start, base_gate),
			"Generated floor %d must have a path back to base" % seed_value,
		)
		_expect(
			floor_generator._all_floor_cells_connected(floor_data["tiles"]),
			"Generated floor %d must not contain unreachable floor pockets" % seed_value,
		)
		_expect(
			floor_data["tiles"].values().has("void"),
			"Generated floor %d must have an irregular outer edge" % seed_value,
		)
		for enemy in floor_data["enemies"]:
			_expect(floor_data["tiles"][enemy["pos"]] == "floor", "Enemies must spawn on walkable cells")
		for chest in floor_data["items"]:
			_expect(floor_data["tiles"][chest["pos"]] == "floor", "Chests must spawn on walkable cells")
			_expect(GameRules.EQUIPMENT.has(chest["id"]), "Every chest must contain a valid item")
			_expect(
				int(chest.get("wood", 0)) in range(0, 3)
				and int(chest.get("stone", 0)) in range(0, 3)
				and not chest.has("cloth"),
				"Chests may drop small wood and stone amounts, but never cloth",
			)


func _test_main_scene() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_expect(packed_scene != null, "Main scene must load")
	if packed_scene == null:
		return
	var main := packed_scene.instantiate()
	_expect(main.get_script() != null, "Main scene script must compile and attach")
	if main.get_script() == null:
		main.queue_free()
		return
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	_expect(main.screen == main.Screen.NAME_CREATION, "The game must open at character naming")
	_expect(not main.language_button.visible, "Language switch must not occupy the permanent top bar")
	_expect(main.menu_button.visible, "Menu must be available in the upper-right corner")
	main._open_settings()
	_expect(
		main.settings_open and main.settings_close_button.visible and main.language_button.visible,
		"Menu must contain the language switch and settings controls",
	)
	_expect(
		main.settings_input_label.size.y >= 44
		and main.settings_input_label.clip_text
		and main.settings_close_button.has_theme_stylebox_override("hover"),
		"Settings text must stay inside a tall clipped label and buttons must have hover styling",
	)
	main._on_language_pressed()
	_expect(Loc.current_locale == "en", "Language button in the menu must switch the active locale")
	_expect(main.title_label.text == "Character Creation — Name", "Visible UI must refresh after a language switch")
	_expect(main.attribute_name_labels["strength"].text == "Strength", "Attribute labels must be localized")
	main._on_language_pressed()
	_expect(
		main.settings_controls_button.visible
		and main.settings_controls_button.focus_mode == Control.FOCUS_ALL,
		"Settings must expose a keyboard-focusable controls screen entry",
	)
	main.settings_display_button.grab_focus()
	for _step in range(2):
		var settings_down := InputEventAction.new()
		settings_down.action = "ui_down"
		settings_down.pressed = true
		main.get_viewport().push_input(settings_down, true)
		await process_frame
	_expect(
		main.get_viewport().gui_get_focus_owner() == main.settings_controls_button,
		"Settings must reach the controls entry through keyboard or D-pad navigation",
	)
	var open_controls_key := InputEventKey.new()
	open_controls_key.pressed = true
	open_controls_key.keycode = KEY_ENTER
	main.get_viewport().push_input(open_controls_key, true)
	await process_frame
	var remap_panel = main.controls_remap_panel
	_expect(
		main.controls_remap_open
		and remap_panel.visible
		and remap_panel.keyboard_buttons.size() == InputProfile.GAMEPLAY_ACTIONS.size()
		and remap_panel.gamepad_buttons.size() == InputProfile.GAMEPLAY_ACTIONS.size(),
		"The controls screen must display keyboard and gamepad bindings for every action",
	)
	_expect(
		remap_panel.title_label.text == "Управление"
		and not remap_panel.keyboard_buttons["move_up"].text.is_empty()
		and not remap_panel.gamepad_buttons["move_up"].text.is_empty(),
		"The controls screen must localize its title and display current bindings",
	)
	_expect(
		main.get_viewport().gui_get_focus_owner() == remap_panel.keyboard_buttons["move_up"],
		"Opening controls without a mouse must focus the first keyboard binding",
	)
	var focus_right := InputEventAction.new()
	focus_right.action = "ui_right"
	focus_right.pressed = true
	main.get_viewport().push_input(focus_right, true)
	await process_frame
	_expect(
		main.get_viewport().gui_get_focus_owner() == remap_panel.gamepad_buttons["move_up"],
		"Keyboard or D-pad navigation must move focus between device columns",
	)
	var focus_down := InputEventAction.new()
	focus_down.action = "ui_down"
	focus_down.pressed = true
	main.get_viewport().push_input(focus_down, true)
	await process_frame
	_expect(
		main.get_viewport().gui_get_focus_owner() == remap_panel.gamepad_buttons["move_down"],
		"Keyboard or D-pad navigation must move focus between action rows",
	)
	var focus_accept := InputEventKey.new()
	focus_accept.pressed = true
	focus_accept.keycode = KEY_ENTER
	main.get_viewport().push_input(focus_accept, true)
	await process_frame
	_expect(
		remap_panel.capture_action == "move_down"
		and remap_panel.capture_device == InputProfile.DEVICE_GAMEPAD,
		"Activating a focused binding must enter next-input waiting mode",
	)
	var cancel_capture := InputEventKey.new()
	cancel_capture.pressed = true
	cancel_capture.keycode = KEY_ESCAPE
	main.get_viewport().push_input(cancel_capture, true)
	await process_frame
	_expect(
		remap_panel.capture_action.is_empty() and main.controls_remap_open,
		"Esc must cancel a pending change without leaving the controls screen",
	)
	Loc.set_locale("en")
	remap_panel.apply_locale()
	_expect(
		remap_panel.title_label.text == "Controls"
		and remap_panel.action_name_labels["character_sheet"].text == "Character Sheet",
		"The controls screen must refresh every visible label in English",
	)
	Loc.set_locale("ru")
	remap_panel.apply_locale()
	_expect(
		_has_key_binding("cast_spell", KEY_Q),
		"Conflict UI test requires the default Q spell binding",
	)
	remap_panel.keyboard_buttons["attack"].pressed.emit()
	_expect(
		remap_panel.capture_device == InputProfile.DEVICE_KEYBOARD,
		"The keyboard binding column must wait for keyboard input",
	)
	var conflicting_key := InputEventKey.new()
	conflicting_key.pressed = true
	conflicting_key.keycode = KEY_Q
	_expect(
		InputProfile.find_conflicts("attack", conflicting_key).has("cast_spell"),
		"Conflict UI test requires InputBindings to report Q on the spell action",
	)
	_expect(
		not conflicting_key.is_action_pressed("ui_cancel"),
		"Conflict UI test key must not be interpreted as menu cancellation",
	)
	main.get_viewport().push_input(conflicting_key, true)
	await process_frame
	_expect(
		remap_panel.capture_action == "attack",
		"A conflicting input must keep the selected target action in capture mode",
	)
	_expect(
		remap_panel.pending_conflicts.has("cast_spell"),
		"A conflicting input must identify the action that already owns the binding",
	)
	_expect(
		remap_panel.status_label.text.contains("уже назначено"),
		"A conflicting input must explain the conflict before confirmation",
	)
	main.get_viewport().push_input(cancel_capture, true)
	await process_frame
	_expect(
		remap_panel.capture_action.is_empty()
		and _has_key_binding("cast_spell", KEY_Q),
		"Cancelling a conflict must retain the previous action binding",
	)
	var close_controls := InputEventJoypadButton.new()
	close_controls.pressed = true
	close_controls.button_index = JOY_BUTTON_B
	main.get_viewport().push_input(close_controls, true)
	await process_frame
	_expect(
		not main.controls_remap_open
		and main.settings_open
		and main.settings_controls_button.visible,
		"Gamepad B must return from controls to settings without requiring a mouse",
	)
	main._change_inspection_radius(1)
	_expect(main.inspection_radius == 7, "Inspection radius must be adjustable from settings")
	main._change_inspection_radius(-1)
	_expect(main.settings_exit_button.visible, "Settings menu must contain an exit button")
	main._on_exit_pressed()
	_expect(main.exit_confirmation_pending, "Exit must require a confirming second click")
	main._close_settings()
	_expect(
		not main.settings_open and main.inspection_radius == 6 and not main.language_button.visible,
		"Closing settings must hide its language control and keep the chosen radius",
	)
	main.name_input.text = "Тестовый"
	main._on_name_confirmed()
	_expect(main.screen == main.Screen.STAT_CREATION, "A valid name must open attribute allocation")
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		main._change_pending_attribute(attribute_id, 1)
	_expect(main.free_attribute_points == 0, "Character creation must spend exactly five free points")
	main._on_attributes_confirmed()
	_expect(main.screen == main.Screen.STORY, "Finished character creation must open the three-frame intro")
	_expect(main.state.character_name == "Тестовый", "Character name must be stored in run state")
	_expect(main.state.attributes["strength"] == 2, "Allocated attributes must be stored in run state")
	_expect(main.story_index == 0, "The intro must begin with the wandering skeleton frame")
	main._advance_story()
	_expect(main.screen == main.Screen.STORY and main.story_index == 1, "The first click must show the poncho frame")
	main._advance_story()
	_expect(main.screen == main.Screen.STORY and main.story_index == 2, "The second click must show the awakening frame")
	main._advance_story()
	_expect(main.screen == main.Screen.BASE, "The third intro click must open the level 100 base")
	_expect(
		main.camp_upgrades_label.visible and not main.equipment_label.visible,
		"Base sidebar must show camp materials and installed upgrades instead of run equipment",
	)
	_expect(
		main.build_crusher_button.disabled and main.build_whetstone_button.disabled,
		"Camp construction must remain disabled without enough materials",
	)
	main._show_character()
	var cheat_points_before: int = main.state.unspent_attribute_points
	_expect(
		main.character_cheat_stats_button.visible
		and main.character_cheat_stats_button.text == Loc.text("BTN_CHEAT_ADD_STATS"),
		"The temporary +5 stat test button must be visible and localized on the character sheet",
	)
	main._on_cheat_add_stats_pressed()
	_expect(
		main.state.unspent_attribute_points == cheat_points_before + 5,
		"The temporary stat test button must grant exactly five spendable points",
	)
	_expect(main.skills_title_label.visible, "Character sheet must include the large skills block")
	_expect(main.skill_node_buttons["strong_bones"].visible, "Skeleton skill tree must be visible by default")
	_expect(
		main.skill_node_buttons["magic_awakening"].visible
		and main.skill_node_buttons["magic_ricochet"].visible,
		"Skeleton skill tab must include its second magic branch",
	)
	_expect(main.zombie_tab_button.disabled, "Zombie skill tab must be locked before reaching zombie")
	_expect(main.revenant_tab_button.disabled, "Revenant skill tab must be locked before reaching revenant")
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("revenant")
	main._refresh_character_sheet()
	main._select_skill_stage("revenant")
	_expect(
		not main.revenant_tab_button.disabled
		and main.skill_node_buttons["sharp_vision"].visible,
		"Unlocking revenant must reveal the Sharp Vision skill node",
	)
	main.state.highest_unlocked_form_index = 0
	main._select_skill_stage("skeleton")
	_expect(
		main.character_equipment_label.position.x < main.character_derived_label.position.x,
		"Equipment must occupy the center card and derived parameters the right card",
	)
	_expect(
		main.character_equipment_buttons.size() == GameRules.SLOT_NAMES.size(),
		"The skeleton equipment portrait must display every equipment slot",
	)
	_expect(main.SKELETON_EQUIPMENT_ART != null, "The equipment card must use the generated pencil skeleton art")
	var primary_header_width: float = main.character_primary_label.get_theme_font("font").get_string_size(
		Loc.text("PRIMARY_ATTRIBUTES"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		main.character_primary_label.get_theme_font_size("font_size"),
	).x
	_expect(
		primary_header_width <= main.character_primary_label.size.x
		and main.character_primary_label.clip_text
		and main.character_derived_label.get_theme_constant("line_spacing") < 0,
		"Character headings and dense parameters must fit inside their cards",
	)
	_expect(
		main.DUNGEON_FLOOR_TEXTURE != null
		and main.DUNGEON_WALL_TEXTURE != null
		and main.DUNGEON_CHEST_SPRITE != null
		and main.PLAYER_SKELETON_SPRITE != null
		and main.ENEMY_SPRITES.size() == GameRules.ENEMIES.size(),
		"Dungeon rendering must preload floor, wall, chest, player and every enemy prototype asset",
	)
	_expect(
		main.character_attribute_spend_buttons["agility"].position.y
		- main.character_attribute_spend_buttons["strength"].position.y == 27,
		"Attribute plus buttons must follow the text line spacing exactly",
	)
	main._close_character()
	main.state.add_resources({"wood": 20, "stone": 20, "cloth": 5})
	main._refresh_interface()
	main._on_build_camp_upgrade("crusher")
	main._on_build_camp_upgrade("whetstone")
	_expect(
		main.state.camp_upgrades["crusher"] and main.state.camp_upgrades["whetstone"],
		"Camp construction buttons must install both prototype upgrades",
	)
	var ui_knife_key: String = main.state.add_item("bone_knife", 0, 2)
	main._show_character()
	main._select_character_panel("inventory")
	_expect(
		main.inventory_stack_buttons[0].visible
		and "×2" in main.inventory_stack_buttons[0].text,
		"Character inventory must render identical items as one stack slot",
	)
	main._on_inventory_stack_pressed(0)
	_expect(
		main.selected_inventory_key == ui_knife_key
		and not main.inventory_equip_button.disabled,
		"Selecting an inventory slot must open its equipment details and actions",
	)
	main._on_inventory_equip_pressed()
	_expect(
		main.state.loadout.get("weapon", "") == ui_knife_key
		and main.state.inventory.get(ui_knife_key, 0) == 1,
		"The character sheet must equip exactly one item from a stack",
	)
	main._on_equipment_slot_pressed("weapon")
	_expect(
		main.selected_equipment_slot == "weapon"
		and Loc.text("ITEM_BONE_KNIFE") in main.inventory_detail_label.text,
		"Selecting a humanoid equipment slot must show that item's details below",
	)
	main.state.add_resources(GameRules.WEAPON_UPGRADE_COST)
	var ui_resources_before_upgrade: Dictionary = main.state.resources.duplicate(true)
	main._refresh_character_sheet()
	_expect(
		not main.inventory_upgrade_button.disabled,
		"The Whetstone action must be available for a selected equipped weapon",
	)
	main._on_inventory_upgrade_pressed()
	_expect(
		GameRules.item_upgrade_level(main.state.loadout["weapon"]) == 1
		and main.selected_equipment_slot == "weapon",
		"The Whetstone action must apply guaranteed +1 without unequipping the weapon",
	)
	_expect(
		main.state.resources["stone"] == int(ui_resources_before_upgrade["stone"]) - 10,
		"The inventory Whetstone action must spend its material price",
	)
	main.state.add_item("rotting_mail")
	main._refresh_character_sheet()
	main._on_inventory_dismantle_all_pressed()
	_expect(
		main.dismantle_all_confirmation_pending and not main.state.inventory.is_empty(),
		"Dismantle all must require a confirming second press",
	)
	main._on_inventory_dismantle_all_pressed()
	_expect(
		main.state.inventory.is_empty()
		and GameRules.item_upgrade_level(main.state.loadout["weapon"]) == 1,
		"Confirmed dismantle all must clear inventory while preserving equipped upgraded gear",
	)
	main._close_character()
	main._on_start_pressed()
	_expect(
		main.screen == main.Screen.BASE and main.expedition_choice_open,
		"Starting an expedition must first ask for its starting floor",
	)
	_expect(main.expedition_rope_button.disabled, "The rope must be unavailable before the first safe return")
	# Keep the integration route independent from the process-wide random seed.
	main.rng.seed = 1001
	main._on_beginning_ascent_pressed()
	await process_frame
	_expect(main.screen == main.Screen.DUNGEON, "Start expedition must open a dungeon floor")
	_expect(not main.floor_data.is_empty(), "Starting an expedition must generate floor data")
	_expect(
		main.floor_data["width"] == 20 and main.floor_data["height"] == 14,
		"Dungeon UI must use the expanded field dimensions",
	)
	_expect(
		main._is_cell_visible(main.player_pos)
		and main._is_cell_explored(main.player_pos),
		"Entering a floor must reveal and remember the player's cell",
	)
	var found_unexplored_cell := false
	for visibility_cell in main.floor_data["tiles"]:
		if main.floor_data["tiles"][visibility_cell] == "void":
			continue
		if main._is_cell_visible(visibility_cell):
			_expect(
				main._manhattan(main.player_pos, visibility_cell) <= main.PLAYER_VISION_RADIUS,
				"Player visibility must never exceed four cells",
			)
		elif not main._is_cell_explored(visibility_cell):
			found_unexplored_cell = true
	_expect(found_unexplored_cell, "A new floor must retain unexplored cells behind fog of war")
	_expect(
		not main.camp_upgrades_label.visible and main.equipment_label.visible,
		"Dungeon sidebar must switch back from camp upgrades to worn equipment",
	)
	_expect(
		Loc.text("SIDEBAR_CRADLE_CHANCE").get_slice(":", 0) not in main.sidebar_progress_label.text,
		"The accumulated Cradle chance must remain hidden from the player",
	)
	var inventory_before_chest: int = main.state.inventory.size()
	main.floor_data["items"].append({
		"uid": "test_chest", "id": "soul_locket", "pos": main.player_pos,
		"wood": 2, "stone": 1,
	})
	var wood_before_chest: int = main.state.resources["wood"]
	_expect(main._pick_up_item_at_player(), "Standing on a chest must open it")
	_expect(
		main.state.inventory.size() >= inventory_before_chest
		and main.state.inventory.has(GameRules.make_item_key("soul_locket"))
		and main.state.resources["wood"] == wood_before_chest + 2,
		"Opened chests must add their item and material contents to the run",
	)
	_expect(main.wait_button.visible, "Wait action must be available on the mobile interface")
	_expect(main.wait_count_button.visible, "Wait action must include a compact duration selector")
	_expect(main.auto_explore_button.visible, "Automatic exploration must be available in the action bar")
	_expect(main.wait_button.text == Loc.text("BTN_WAIT_ONE"), "Waiting must default to one turn")
	main._cycle_wait_turn_count()
	_expect(main.wait_turn_count == 10, "The wait selector must cycle from one to ten turns")
	main._cycle_wait_turn_count()
	_expect(main.wait_turn_count == 100, "The wait selector must cycle from ten to one hundred turns")
	var wait_text_width: float = main.wait_button.get_theme_font("font").get_string_size(
		main.wait_button.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		main.wait_button.get_theme_font_size("font_size"),
	).x
	_expect(
		wait_text_width <= main.wait_button.size.x - 16
		and main.wait_button.position.x + main.wait_button.size.x < main.wait_count_button.position.x
		and main.wait_count_button.text == "›",
		"The hundred-turn label and its compact selector must not overlap",
	)
	main._cycle_wait_turn_count()
	_expect(main.wait_turn_count == 1, "The wait selector must cycle back to one turn")
	_expect(
		main.attack_button.visible and main.spell_button.visible and main.camp_button.visible,
		"Attack, magic and camp buttons must be in the dungeon action bar",
	)
	_expect(
		main.attack_button.position.y == 674 and main.interact_button.position.y == 674,
		"Dungeon actions must occupy the dedicated strip below the enlarged map",
	)
	var action_bar_buttons := [
		main.attack_button, main.spell_button, main.active_2_button, main.active_3_button,
		main.wait_button, main.wait_count_button,
		main.auto_explore_button,
		main.camp_button, main.character_action_button, main.interact_button,
	]
	for action_index in range(action_bar_buttons.size() - 1):
		_expect(
			action_bar_buttons[action_index].position.x + action_bar_buttons[action_index].size.x
			< action_bar_buttons[action_index + 1].position.x,
			"Dungeon action buttons must remain separated after adding automatic exploration",
		)
	for action_button in action_bar_buttons + [main.menu_button]:
		_expect(action_button.focus_mode == Control.FOCUS_NONE, "Arrow keys must not focus action buttons")
	_expect(main.hint_label.visible, "The latest dungeon hint must remain inside the history rail")
	_expect(main.camp_button.disabled, "Camp must be unavailable while the player is a skeleton")
	var primary_magic_cell := Vector2i(-1, -1)
	var ricochet_magic_cell := Vector2i(-1, -1)
	for cell in main.floor_data["tiles"]:
		if (
			main.floor_data["tiles"][cell] == "floor"
			and cell != main.player_pos
			and main._manhattan(main.player_pos, cell) <= 3
			and main._has_clear_spell_line(main.player_pos, cell)
		):
			primary_magic_cell = cell
			break
	if primary_magic_cell.x >= 0:
		for cell in main.floor_data["tiles"]:
			if (
				main.floor_data["tiles"][cell] == "floor"
				and cell != main.player_pos
				and cell != primary_magic_cell
				and main._manhattan(primary_magic_cell, cell) <= 4
				and main._has_clear_spell_line(primary_magic_cell, cell)
			):
				ricochet_magic_cell = cell
				break
	_expect(
		primary_magic_cell.x >= 0 and ricochet_magic_cell.x >= 0,
		"Magic integration test requires two valid floor targets",
	)
	if primary_magic_cell.x >= 0 and ricochet_magic_cell.x >= 0:
		main.floor_data["enemies"] = [
			{
				"uid": "magic_primary", "id": "grave_rat", "pos": primary_magic_cell,
				"hp": 9, "max_hp": 9, "damage": 0, "accuracy": 0, "dodge": 99, "souls": 1,
			},
			{
				"uid": "magic_ricochet", "id": "hollow_guard", "pos": ricochet_magic_cell,
				"hp": 9, "max_hp": 9, "damage": 0, "accuracy": 0, "dodge": 99, "souls": 1,
			},
		]
		main.state.skill_levels["magic_awakening"] = 1
		main.state.skill_levels["magic_missile"] = 1
		main.state.assign_ability("active_1", "magic_missile")
		main.state.skill_levels["magic_ricochet"] = 1
		main.state.mana = main.state.get_max_mana()
		main.inspected_target = {
			"kind": "enemy", "uid": "magic_primary", "entity": main.floor_data["enemies"][0],
		}
		var mana_before_cast: int = main.state.mana
		var turns_before_cast: int = main.state.total_turns
		main._on_spell_pressed(0.0)
		var primary_hp := -1
		var ricochet_hp := -1
		for enemy in main.floor_data["enemies"]:
			if enemy["uid"] == "magic_primary":
				primary_hp = int(enemy["hp"])
			elif enemy["uid"] == "magic_ricochet":
				ricochet_hp = int(enemy["hp"])
		_expect(
			primary_hp == 6 and ricochet_hp == 6,
			"Magic Missile must hit automatically and a successful Ricochet must damage the second target",
		)
		_expect(
			main.state.mana == mana_before_cast - 10
			and main.state.total_turns == turns_before_cast + 1,
			"Casting must spend ten mana and one complete turn",
		)
		_expect(main.magic_traces.size() == 2, "Primary and ricochet missiles must each leave a visible trace")
		main._update_magic_traces(0.5)
		_expect(main.magic_traces.size() == 2, "Magic traces must remain visible during their one-second lifetime")
		main._update_magic_traces(0.51)
		_expect(main.magic_traces.is_empty(), "Magic traces must disappear after one second")
		main.inspected_target.clear()
	var character_event := InputEventKey.new()
	character_event.keycode = KEY_E
	character_event.pressed = true
	main._unhandled_input(character_event)
	_expect(main.screen == main.Screen.CHARACTER, "E must replace evolution and open the character sheet")
	main.state.carried_souls = 5
	main._on_skill_pressed("strong_bones")
	_expect(
		main.state.get_skill_level("strong_bones") == 1 and main.state.carried_souls == 0,
		"A skill must be learnable from the dungeon using carried souls",
	)
	main.state.unspent_attribute_points = 1
	var dungeon_strength_before: int = main.state.attributes["strength"]
	main._refresh_character_sheet()
	_expect(
		main.character_attribute_spend_buttons["strength"].visible,
		"Attribute plus buttons must be available from the dungeon character sheet",
	)
	main._on_spend_attribute_point("strength")
	_expect(
		main.state.attributes["strength"] == dungeon_strength_before + 1
		and main.state.unspent_attribute_points == 0,
		"Free attribute points must be spendable during an expedition",
	)
	main._close_character()
	var generated_floor: Dictionary = main.floor_data
	var generated_player_position: Vector2i = main.player_pos
	var vision_test_tiles := {}
	for y in range(3):
		for x in range(9):
			vision_test_tiles[Vector2i(x, y)] = "wall"
	for x in range(1, 8):
		vision_test_tiles[Vector2i(x, 1)] = "floor"
	main.floor_data = {
		"width": 9,
		"height": 3,
		"tiles": vision_test_tiles,
		"start": Vector2i(1, 1),
		"base_gate": Vector2i(1, 1),
		"exit": Vector2i(7, 1),
		"exit_known": false,
		"cradle": Vector2i(-1, -1),
		"cradle_known": false,
		"cradle_pity_resolved": false,
		"cradle_used": false,
		"items": [{"uid": "mapped_chest", "id": "bone_knife", "pos": Vector2i(6, 1)}],
		"visible_cells": {},
		"explored_cells": {},
		"observed_cells": {},
		"enemies": [],
	}
	main.player_pos = Vector2i(1, 1)
	main.state.skill_levels["sharp_vision"] = 0
	main._update_player_visibility(false)
	_expect(
		not main._is_cell_visible(Vector2i(6, 1))
		and main._is_cell_explored(Vector2i(6, 1))
		and not main._is_cell_observed(Vector2i(6, 1))
		and main._is_cell_explored(Vector2i(5, 2))
		and not main._is_cell_visible(Vector2i(5, 2)),
		"The extra mapping ring must reveal geometry without revealing cell contents",
	)
	main._select_inspection_target(Vector2i(6, 1))
	_expect(
		main._get_inspection_target().get("kind", "") == "tile",
		"A chest in the mapping-only ring must remain unidentified",
	)
	main.state.skill_levels["sharp_vision"] = 1
	main._update_player_visibility(false)
	_expect(
		main._is_cell_visible(Vector2i(6, 1)) and main._is_cell_observed(Vector2i(6, 1)),
		"One Sharp Vision level must reveal a clear cell at distance five",
	)
	main._select_inspection_target(Vector2i(6, 1))
	_expect(
		main._get_inspection_target().get("kind", "") == "item",
		"A chest must become identifiable after entering true vision",
	)
	main.state.skill_levels["sharp_vision"] = 2
	main._update_player_visibility(false)
	_expect(
		main._is_cell_visible(Vector2i(7, 1)),
		"Two Sharp Vision levels must reveal a clear cell at distance six",
	)
	main.state.skill_levels["sharp_vision"] = 0
	var path_test_tiles := {}
	for y in range(5):
		for x in range(5):
			path_test_tiles[Vector2i(x, y)] = "wall"
	for path_cell in [Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2)]:
		path_test_tiles[path_cell] = "floor"
	main.floor_data = {
		"width": 5,
		"height": 5,
		"tiles": path_test_tiles,
		"start": Vector2i(1, 2),
		"base_gate": Vector2i(1, 1),
		"exit": Vector2i(3, 2),
		"exit_known": false,
		"cradle": Vector2i(3, 1),
		"cradle_known": false,
		"cradle_pity_resolved": false,
		"cradle_used": false,
		"items": [{"uid": "remembered_chest", "id": "bone_knife", "pos": Vector2i(1, 1)}],
		"visible_cells": {},
		"explored_cells": {},
		"enemies": [],
	}
	main.state.cradle_miss_streak = 3
	main.player_pos = Vector2i(1, 2)
	main._update_player_visibility(false)
	_expect(
		main._is_cell_visible(Vector2i(2, 2))
		and main._is_cell_explored(Vector2i(2, 2))
		and not main.floor_data["exit_known"]
		and not main.floor_data["cradle_known"]
		and main.state.cradle_miss_streak == 3,
		"A visible wall must be remembered while hiding cells behind it",
	)
	main.player_pos = Vector2i(3, 2)
	main._update_player_visibility(false)
	_expect(
		main._is_cell_explored(Vector2i(0, 2))
		and not main._is_cell_visible(Vector2i(0, 2))
		and main._is_cell_explored(Vector2i(1, 1))
		and not main._is_cell_visible(Vector2i(1, 1))
		and main.floor_data["cradle_known"]
		and main.state.cradle_miss_streak == 0,
		"Explored walls and items must remain in memory after leaving sight range",
	)
	main._select_inspection_target(Vector2i(1, 1))
	_expect(
		main._get_inspection_target().get("kind", "") == "item",
		"A remembered item must remain selectable outside current visibility",
	)
	main.floor_data["enemies"] = [{
		"uid": "blocked_primary", "id": "grave_rat", "pos": Vector2i(1, 2),
		"hp": 2, "max_hp": 2, "damage": 1, "accuracy": 2, "dodge": 2,
		"vision": 3, "souls": 1,
	}]
	_expect(
		not main._has_clear_spell_line(Vector2i(1, 2), Vector2i(3, 2)),
		"A wall intersecting the grid ray must block Magic Missile",
	)
	_expect(
		not main._enemy_can_see_player(main.floor_data["enemies"][0]),
		"Enemy vision must not pass through walls",
	)
	main._enemy_turn()
	_expect(
		main.floor_data["enemies"][0]["pos"] == Vector2i(1, 2),
		"An enemy without sight or a remembered target must remain idle",
	)
	main.floor_data["enemies"].append({
		"uid": "blocked_ricochet", "id": "hollow_guard", "pos": Vector2i(3, 2),
		"hp": 4, "max_hp": 4, "damage": 1, "accuracy": 3, "dodge": 1,
		"vision": 5, "souls": 2,
	})
	_expect(
		main._has_clear_spell_line(Vector2i(1, 1), Vector2i(3, 1)),
		"A clear row of floor cells must allow Magic Missile",
	)
	main.player_pos = Vector2i(3, 1)
	_expect(
		not main._enemy_can_see_player({"id": "grave_rat", "pos": Vector2i(1, 1), "vision": 1})
		and main._enemy_can_see_player({"id": "hollow_guard", "pos": Vector2i(1, 1), "vision": 5}),
		"Different enemy vision values must change whether the player is detected",
	)
	main.player_pos = Vector2i(3, 2)
	_expect(
		main._nearest_enemy_index_from(Vector2i(1, 2), 4, "blocked_primary", false) == 1,
		"Ricochet target selection must ignore walls between the two enemies",
	)
	_expect(
		main._enemy_step_toward_player(0) == Vector2i(1, 1),
		"Enemies must route around a wall even when the first step increases Manhattan distance",
	)
	main.floor_data = generated_floor
	main.player_pos = generated_player_position
	main._update_player_visibility(false)
	main.floor_data["enemies"].clear()
	main.floor_data["items"].clear()
	main.player_pos = main.floor_data["start"]
	main._update_player_visibility(false)
	var input_direction := Vector2i.ZERO
	for candidate_action in [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
	]:
		if main.floor_data["tiles"].get(main.player_pos + candidate_action, "void") == "floor":
			input_direction = candidate_action
			break
	_expect(input_direction != Vector2i.ZERO, "Input integration test requires an adjacent floor cell")
	if input_direction != Vector2i.ZERO:
		var input_origin: Vector2i = main.player_pos
		var movement_keys := {
			Vector2i.UP: KEY_W,
			Vector2i.DOWN: KEY_S,
			Vector2i.LEFT: KEY_A,
			Vector2i.RIGHT: KEY_D,
		}
		var press_event := InputEventKey.new()
		press_event.physical_keycode = movement_keys[input_direction]
		press_event.pressed = true
		main.get_viewport().push_input(press_event, true)
		await process_frame
		_expect(main.player_pos == input_origin + input_direction, "A physical WASD press must move the player")
		var release_event := InputEventKey.new()
		release_event.physical_keycode = movement_keys[input_direction]
		release_event.pressed = false
		main.get_viewport().push_input(release_event, true)
		await process_frame

	var mouse_target := Vector2i(-1, -1)
	for cell in main.floor_data["tiles"]:
		if (
			main.floor_data["tiles"][cell] == "floor"
			and main._manhattan(main.player_pos, cell) > 1
			and main._is_cell_visible(cell)
		):
			mouse_target = cell
			break
	_expect(mouse_target.x >= 0, "Mouse integration test requires a distant floor cell")
	if mouse_target.x >= 0:
		main.floor_data["enemies"] = [{
			"uid": "mouse_target",
			"id": "grave_rat",
			"pos": mouse_target,
			"hp": 2,
			"max_hp": 2,
			"damage": 1,
			"accuracy": 2,
			"dodge": 2,
			"souls": 1,
		}]
		main.inspected_target.clear()
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		mouse_event.pressed = true
		main._refresh_dungeon_viewport()
		mouse_event.position = main.dungeon_viewport.world_to_screen_center(mouse_target)
		main.get_viewport().push_input(mouse_event, true)
		await process_frame
		var mouse_selection: Dictionary = main._get_inspection_target()
		_expect(
			mouse_selection.get("kind", "") == "enemy" and mouse_selection.get("manual", false),
			"A real board click must manually select the clicked target",
		)
	main.floor_data["enemies"].clear()
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_W
	key_event.pressed = true
	_expect(main._movement_direction_from_event(key_event) == Vector2i.UP, "W must map to upward held movement")
	var gamepad_event := InputEventJoypadButton.new()
	gamepad_event.button_index = JOY_BUTTON_DPAD_RIGHT
	gamepad_event.pressed = true
	_expect(
		main._movement_direction_from_event(gamepad_event) == Vector2i.RIGHT,
		"Gamepad D-pad must use the same movement path as the keyboard",
	)
	var wall_origin := Vector2i(-1, -1)
	var wall_direction := Vector2i.ZERO
	for cell in main.floor_data["tiles"]:
		if main.floor_data["tiles"][cell] != "floor":
			continue
		if (
			cell == main.floor_data["start"]
			or cell == main.floor_data["base_gate"]
			or cell == main.floor_data["exit"]
		):
			continue
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if main.floor_data["tiles"].get(cell + direction, "void") != "floor":
				wall_origin = cell
				wall_direction = direction
				break
		if wall_origin.x >= 0:
			break
	_expect(wall_origin.x >= 0, "Generated floor must provide a wall collision case")
	if wall_origin.x >= 0:
		main.floor_data["enemies"].clear()
		main.floor_data["items"].clear()
		main.floor_data["cradle"] = Vector2i(-1, -1)
		main.player_pos = main.floor_data["start"]
		main._update_player_visibility(false)
		main.inspected_target.clear()
		var automatic_landmark: Dictionary = main._get_inspection_target()
		_expect(
			automatic_landmark.get("kind", "") == "start",
			"Auto-inspection must fall back to a nearby important tile when no enemies or items remain",
		)
		main.player_pos = wall_origin
		main._update_player_visibility(false)
		_expect(not main._attempt_player_action(wall_direction), "Held movement must stop when it reaches a wall")
		_expect(main.player_pos == wall_origin, "Wall collision must not move the player")
	var adjacent_floor := Vector2i(-1, -1)
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var candidate: Vector2i = main.player_pos + direction
		if (
			main.floor_data["tiles"].get(candidate, "void") == "floor"
			and candidate != main.floor_data["start"]
			and candidate != main.floor_data["base_gate"]
			and candidate != main.floor_data["exit"]
		):
			adjacent_floor = candidate
			break
	_expect(adjacent_floor.x >= 0, "Player start must have an adjacent walkable cell")
	if adjacent_floor.x >= 0:
		var held_attack_direction: Vector2i = adjacent_floor - main.player_pos
		var held_attack_origin: Vector2i = main.player_pos
		var held_attack_damage: int = maxi(main.state.get_damage(), 1)
		var held_enemy_hp: int = held_attack_damage * 3
		main.floor_data["enemies"] = [{
			"uid": "held_enemy",
			"id": "grave_rat",
			"pos": adjacent_floor,
			"hp": held_enemy_hp,
			"max_hp": held_enemy_hp,
			"damage": 0,
			"accuracy": -100,
			"dodge": -100,
			"souls": 1,
		}]
		_expect(
			main._attempt_player_action(held_attack_direction),
			"Held movement into an enemy must remain active after an attack",
		)
		_expect(
			main.floor_data["enemies"][0]["hp"] == held_enemy_hp - held_attack_damage,
			"The held movement action must perform the attack",
		)
		_expect(main._attempt_player_action(held_attack_direction), "Held attack must continue while the enemy survives")
		_expect(main._attempt_player_action(held_attack_direction), "Held attack must continue through the killing blow")
		_expect(main.floor_data["enemies"].is_empty(), "Continuous held attacks must kill the blocking enemy")
		_expect(main._attempt_player_action(held_attack_direction), "Held movement must resume after the enemy dies")
		_expect(main.player_pos == adjacent_floor, "The player must step into the vacated cell without releasing movement")
		main.player_pos = held_attack_origin
		main.floor_data["enemies"] = [{
			"uid": "test_enemy",
			"id": "grave_rat",
			"pos": adjacent_floor,
			"hp": 2,
			"max_hp": 2,
			"damage": 1,
			"accuracy": 100,
			"dodge": 2,
			"souls": 1,
		}]
		main.inspected_target.clear()
		var automatic_enemy: Dictionary = main._get_inspection_target()
		_expect(automatic_enemy.get("kind", "") == "enemy", "Nearest enemy must be the automatic inspection target")
		main._select_inspection_target(adjacent_floor)
		var selected_enemy: Dictionary = main._get_inspection_target()
		_expect(
			selected_enemy.get("kind", "") == "enemy" and selected_enemy.get("manual", false),
			"Clicking an enemy cell must pin it as the inspection target",
		)
		var hp_before_wait: int = main.state.hp
		main._on_wait_pressed()
		_expect(main.state.hp == hp_before_wait - 1, "Waiting must spend a turn and let adjacent enemies attack")
		main._cycle_wait_turn_count()
		var turns_before_interrupted_wait: int = main.state.total_turns
		var hp_before_interrupted_wait: int = main.state.hp
		main._on_wait_pressed()
		_expect(
			main.state.total_turns == turns_before_interrupted_wait
			and main.state.hp == hp_before_interrupted_wait,
			"Ten-turn waiting must stop immediately when an enemy is visible",
		)
		main._cycle_wait_turn_count()
		var turns_before_hundred_combat_wait: int = main.state.total_turns
		var hp_before_hundred_combat_wait: int = main.state.hp
		main._on_wait_pressed()
		_expect(
			main.state.total_turns == turns_before_hundred_combat_wait + 1
			and main.state.hp == hp_before_hundred_combat_wait - 1,
			"Hundred-turn waiting must fall back to one combat turn when an enemy is visible",
		)
		main._cycle_wait_turn_count()
		main.floor_data["enemies"].clear()
		main._cycle_wait_turn_count()
		var turns_before_ten_wait: int = main.state.total_turns
		main._on_wait_pressed()
		_expect(
			main.state.total_turns == turns_before_ten_wait + 10,
			"Ten-turn waiting must execute every turn when no enemy is visible",
		)
		main._cycle_wait_turn_count()
		main._cycle_wait_turn_count()
	main.floor_data["cradle"] = main.player_pos
	main.floor_data["cradle_used"] = false
	main.state.carried_souls = 10
	main._on_interact_pressed()
	_expect(main.cradle_confirmation_open, "An unused Cradle must ask for evolution confirmation")
	_expect(
		main.cradle_confirmation_description_label.text.contains(Loc.text("FORM_SKELETON"))
		and main.cradle_confirmation_description_label.text.contains(Loc.text("FORM_ZOMBIE"))
		and main.cradle_confirmation_description_label.text.contains("10"),
		"Cradle confirmation must show the old form, new form and exact soul cost",
	)
	main._close_cradle_confirmation()
	_expect(
		main.state.current_form_id == "skeleton" and main.state.carried_souls == 10,
		"Cancelling Cradle confirmation must not change the body or spend souls",
	)
	main._on_interact_pressed()
	main._confirm_cradle_evolution()
	_expect(main.state.current_form_id == "zombie", "Interacting with a Cradle must purchase the next form")
	_expect(main.state.carried_souls == 0, "The Cradle must consume the current stage cost")
	main.state.hunger = 0
	main.state.hp = main.state.get_max_hp()
	main._cycle_wait_turn_count()
	var turns_before_starving_wait: int = main.state.total_turns
	var hp_before_starving_wait: int = main.state.hp
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == turns_before_starving_wait + 1
		and main.state.hp < hp_before_starving_wait,
		"Long waiting must stop after the first turn that reduces HP",
	)
	main.state.hunger = 100
	main._cycle_wait_turn_count()
	main._cycle_wait_turn_count()
	main.state.carried_souls = 20
	main._on_interact_pressed()
	_expect(main.state.current_form_id == "zombie", "One Cradle must permit only one stage upgrade")
	main._show_character()
	_expect(main.screen == main.Screen.CHARACTER, "Character button must open the separate character sheet")
	main._close_character()
	_expect(main.screen == main.Screen.DUNGEON, "Closing the character sheet must return to the same dungeon")
	main.floor_data["enemies"].clear()
	main.floor_data["cradle"] = Vector2i(-1, -1)
	main.player_pos = main.floor_data["start"]
	main._update_player_visibility(false)
	main.floor_data["exit_known"] = false
	main._refresh_interface()
	_expect(main.interact_button.disabled, "An unknown exit must not enable the next-floor action")
	main.floor_data["exit_known"] = true
	var discovered_route: Array[Vector2i] = main._find_floor_path(
		main.player_pos, main.floor_data["exit"]
	)
	for route_cell in discovered_route:
		main.floor_data["explored_cells"][route_cell] = true
	var idle_enemy_cell := Vector2i(-1, -1)
	for candidate_cell in main.floor_data["tiles"]:
		if (
			main.floor_data["tiles"][candidate_cell] == "floor"
			and not discovered_route.has(candidate_cell)
			and candidate_cell != main.floor_data["base_gate"]
			and candidate_cell != main.floor_data["start"]
		):
			idle_enemy_cell = candidate_cell
			break
	_expect(idle_enemy_cell.x >= 0, "Ascent test requires an enemy cell outside the remembered route")
	if idle_enemy_cell.x >= 0:
		main.floor_data["enemies"] = [{
			"uid": "idle_ascent_enemy", "id": "grave_rat", "pos": idle_enemy_cell,
			"hp": 2, "max_hp": 2, "damage": 0, "accuracy": 0, "dodge": 0,
			"vision": 0, "souls": 1,
		}]
	main._refresh_interface()
	_expect(
		not main.interact_button.disabled and main.interact_button.text == Loc.text("BTN_ASCEND"),
		"Discovering the stairs must enable ascent even while an enemy remains alive",
	)
	var cleared_floor_number: int = main.state.current_floor
	var ascent_path: Array[Vector2i] = main._find_floor_path(
		main.player_pos, main.floor_data["exit"], true
	)
	var turns_before_ascent: int = main.state.total_turns
	var ascent_steps := ascent_path.size() - 1
	main._on_ascend_pressed()
	var ascent_frames := 0
	while main.auto_travel_active and ascent_frames < 100:
		await process_frame
		ascent_frames += 1
	_expect(
		main.state.current_floor == cleared_floor_number
		and main.player_pos == main.floor_data["exit"],
		"Automatic ascent must stop on the stairs without entering the next floor",
	)
	_expect(
		main.state.total_turns == turns_before_ascent + ascent_steps,
		"Automatic ascent must walk to the stairs and spend one turn per cell",
	)
	main._on_ascend_pressed()
	_expect(
		main.state.current_floor == cleared_floor_number - 1,
		"Using ascent again while standing on the stairs must load the following floor",
	)
	for index in range(7):
		main._log_action("History %d" % index)
	_expect(main.action_history.size() == 5, "Action history must retain exactly five latest entries")
	_expect(main.action_history[0] == "History 6", "Newest action must be displayed first")
	main.state.carried_souls = 4
	main.player_pos = main.floor_data["base_gate"]
	var expected_rope_floor: int = main.state.current_floor
	main._on_interact_pressed()
	_expect(main.screen == main.Screen.BASE, "Base gate must safely finish an expedition")
	_expect(main.state.banked_souls == 4, "Base gate must deliver carried souls")
	_expect(main.state.rope_floor == expected_rope_floor, "Returning to base must remember the rope floor")

	main._on_start_pressed()
	_expect(
		main.expedition_choice_open and not main.expedition_rope_button.disabled,
		"A safe return must unlock the rope option in the expedition window",
	)
	main._on_rope_ascent_pressed()
	_expect(main.state.current_floor == expected_rope_floor, "The rope option must resume from its saved floor")
	main.state.carried_souls = 3
	main.state.equip("bone_knife")
	main._handle_death()
	_expect(main.screen == main.Screen.STORY and main.story_kind == "death", "Death must show the fallen-bones illustration")
	main._advance_story()
	_expect(main.screen == main.Screen.BASE, "Acknowledging the death illustration must return the player to base")
	_expect(main.state.banked_souls == 4, "Death after a new run must preserve previously banked souls")
	_expect(main.state.carried_souls == 0 and main.state.loadout.is_empty(), "Death must clear run loot")
	main._open_settings()
	main._on_new_game_pressed()
	_expect(
		main.new_game_confirmation_pending and main.state.character_name == "Тестовый",
		"New game must ask for confirmation before discarding progress",
	)
	main._on_new_game_pressed()
	_expect(
		main.screen == main.Screen.NAME_CREATION and main.state.character_name.is_empty(),
		"Confirmed new game must reset state and return to character creation",
	)
	main.queue_free()


func _has_key_binding(action: String, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if (
			event is InputEventKey
			and (event.keycode == keycode or event.physical_keycode == keycode)
		):
			return true
	return false


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		failures.append(failure_message)
