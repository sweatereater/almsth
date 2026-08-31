class_name SkillTreeUiTestSuite
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const Rules := preload("res://scripts/game/game_rules.gd")
const PanelClass := preload("res://scripts/ui/skill_tree_panel.gd")
const Layout := preload("res://scripts/ui/character_sheet_layout.gd")
const SaveSystem := preload("res://scripts/system/persistence.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_static_contracts()
	await _test_panel_states(tree)
	await _test_main_selection_and_purchase(tree)
	Loc.set_locale("ru")
	return failures


func _test_static_contracts() -> void:
	var expected := {
		"skeleton": [
			["strong_bones", "fundamentals", "skeleton_soon_1", "skeleton_soon_2"],
			["magic_awakening", "magic_missile", "magic_missile_range", "magic_ricochet"],
		],
		"zombie": [["flesh_regeneration", "zombie_soon_1", "zombie_soon_2", "zombie_soon_3"]],
		"ghoul": [["dash", "ghoul_maneuver_soon"], ["double_attack", "ghoul_combat_soon"], ["stomach", "ears", "nervous_system"]],
		"revenant": [["sharp_vision", "revenant_soon_1", "revenant_soon_2", "revenant_soon_3"]],
		"almost_human": [["almost_double_strike"], ["circular_attack"], ["choose_appearance", "almost_soon_2"]],
	}
	for stage_id in expected:
		var actual_branches: Array = PanelClass.STAGE_BRANCHES[stage_id]
		_expect(actual_branches.size() <= 3, "%s must render no more than three branches" % stage_id)
		_expect(actual_branches.size() == expected[stage_id].size(), "%s branch count must match the approved topology" % stage_id)
		for index in range(mini(actual_branches.size(), expected[stage_id].size())):
			_expect(actual_branches[index]["nodes"] == expected[stage_id][index], "%s branch %d node order must match the approved topology" % [stage_id, index])
	var stomach: Dictionary = Rules.SKILLS.get("stomach", {})
	_expect(
		stomach.get("stage") == "ghoul" and stomach.get("kind") == "passive"
		and int(stomach.get("max_level", 0)) == 1
		and int(stomach.get("base_cost", 0)) == 20 and int(stomach.get("cost_step", -1)) == 0
		and (stomach.get("requires", {}) as Dictionary).is_empty(),
		"Stomach must be an independent one-level Ghoul passive costing exactly 20 souls",
	)
	var ears: Dictionary = Rules.SKILLS.get("ears", {})
	_expect(
		ears.get("stage") == "ghoul" and ears.get("kind") == "passive"
		and int(ears.get("max_level", 0)) == 1
		and int(ears.get("base_cost", 0)) == 20 and int(ears.get("cost_step", -1)) == 0
		and (ears.get("requires", {}) as Dictionary).is_empty(),
		"Ears must be an independent one-level Ghoul passive costing exactly 20 souls",
	)
	_expect(
		Layout.INVENTORY_TAB_RECT == Rect2(406, 16, 172, 44)
		and Layout.SKILLS_TAB_RECT == Rect2(588, 16, 172, 44),
		"Character top tabs must be visually ordered Inventory then Skills",
	)
	_expect(SaveSystem.STATE_ONLY_VERSION >= 13 and SaveSystem.SAVE_VERSION >= 14, "State-only saves must retain v13 skills while exact gameplay snapshots use v14 or newer")
	_expect(
		ProjectSettings.get_setting("display/window/size/viewport_width") == 1280
		and ProjectSettings.get_setting("display/window/size/viewport_height") == 720
		and ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items"
		and ProjectSettings.get_setting("display/window/stretch/aspect") == "keep",
		"Character geometry must remain a 1280x720 canvas that scales intact to 960x540",
	)
	for locale in Loc.SUPPORTED_LOCALES:
		for key in [
			"SKILL_BRANCH_BONES", "SKILL_BRANCH_MANEUVER", "SKILL_BRANCH_APPEARANCE",
			"SKILL_DETAIL_EFFECT", "SKILL_DETAIL_MANA", "SKILL_DETAIL_COOLDOWN",
			"SKILL_DETAIL_REQUIREMENT", "SKILL_ACTION_LEARN", "SKILL_ACTION_UPGRADE",
			"SKILL_STATUS_PLACEHOLDER",
			"SKILL_STOMACH", "SKILL_STOMACH_DESC", "SKILL_STOMACH_DETAIL",
			"SKILL_EARS", "SKILL_EARS_DESC", "SKILL_EARS_DETAIL",
		]:
			_expect(Loc.STRINGS[locale].has(key), "Skill tree localization %s missing in %s" % [key, locale])


func _test_panel_states(tree: SceneTree) -> void:
	var state := RunState.new()
	state.banked_souls = 500
	state.highest_unlocked_form_index = Rules.FORM_ORDER.find("almost_human")
	state.current_form_id = "ghoul"
	var panel := PanelClass.new()
	panel.size = Vector2(1280, 646)
	tree.root.add_child(panel)
	await tree.process_frame
	panel.set_context(state, "skeleton")
	var selected_style := panel.stage_buttons["skeleton"].get_theme_stylebox("pressed") as StyleBoxFlat
	_expect(
		panel.stage_buttons["skeleton"].position == Vector2(36, 164)
		and panel.stage_buttons["skeleton"].size == Vector2(236, 42)
		and selected_style != null
		and selected_style.border_width_bottom == 0
		and selected_style.bg_color == panel.COLOR_PANEL,
		"Selected stage tab must overlap the tree surface with panel fill and no bottom seam",
	)
	_expect(
		panel.node_buttons["strong_bones"].position == Vector2(150, 214)
		and panel.node_buttons["fundamentals"].position == Vector2(350, 214)
		and panel.node_buttons["magic_awakening"].position == Vector2(150, 294),
		"Skill nodes must follow the approved branch tracks and 200-pixel chain spacing",
	)
	_expect(
		panel.branch_labels["skeleton"][0].horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
		and panel.node_buttons["strong_bones"].purchasable,
		"Branch labels must point toward the chain and every purchasable node must carry its gold cost badge",
	)
	panel.select_node("fundamentals")
	_expect(
		panel.selected_node_id == "fundamentals"
		and not panel.node_buttons["fundamentals"].disabled
		and panel.node_buttons["fundamentals"].visual_state == "locked"
		and panel.action_button.disabled
		and panel.status_label.text == Loc.text("SKILL_NEEDS_PREVIOUS"),
		"Prerequisite-locked nodes must remain selectable while their purchase action stays unavailable",
	)
	state.banked_souls = 0
	panel.select_node("strong_bones")
	_expect(
		panel.status_label.text == Loc.text("SKILL_NEEDS_SOULS", [5])
		and panel.action_button.disabled,
		"A selected affordable-stage skill must explain insufficient souls without purchasing",
	)
	state.banked_souls = 500
	panel.select_node("skeleton_soon_1")
	_expect(
		panel.selected_node_id == "skeleton_soon_1"
		and not panel.node_buttons["skeleton_soon_1"].disabled
		and panel.node_buttons["skeleton_soon_1"].visual_state == "placeholder"
		and panel.detail_title_label.text == Loc.text("SKILL_PLACEHOLDER_NAME")
		and panel.action_button.disabled,
		"Placeholder diamonds must be selectable and update the persistent detail panel",
	)
	state.skill_levels["strong_bones"] = 10
	panel.select_node("strong_bones")
	_expect(
		panel.node_buttons["strong_bones"].visual_state == "max"
		and not panel.node_buttons["strong_bones"].disabled
		and panel.action_button.disabled
		and panel.status_label.text == Loc.text("SKILL_ALREADY_MAX"),
		"Maxed passive circles must stay selectable and show a distinct max state",
	)
	state.skill_levels["fundamentals"] = 1
	panel.refresh()
	_expect(
		PanelClass.connector_style_for_states(
			panel._node_presentation("fundamentals")["state"],
			panel._node_presentation("skeleton_soon_1")["state"],
		) == "locked",
		"A maxed Fundamentals source must still lead to its placeholder with a locked dashed connector",
	)
	state.skill_levels["choose_appearance"] = 1
	panel.set_context(state, "almost_human")
	_expect(
		PanelClass.connector_style_for_states(
			panel._node_presentation("choose_appearance")["state"],
			panel._node_presentation("almost_soon_2")["state"],
		) == "locked",
		"A learned/max node in another branch must also use a dashed connector into a placeholder",
	)
	state.highest_unlocked_form_index = 0
	panel.set_context(state, "zombie")
	panel.select_node("flesh_regeneration")
	_expect(
		panel.node_buttons["flesh_regeneration"].visual_state == "locked"
		and not panel.node_buttons["flesh_regeneration"].disabled
		and panel.status_label.text == Loc.text("SKILL_STAGE_LOCKED")
		and panel.action_button.disabled,
		"Stage-locked skill details must remain inspectable without enabling purchase",
	)
	state.highest_unlocked_form_index = Rules.FORM_ORDER.find("almost_human")
	panel.set_context(state, "ghoul")
	panel.select_node("stomach")
	_expect(
		panel.node_buttons["stomach"].position == Vector2(150, 374)
		and panel.node_buttons["ears"].position == Vector2(350, 374)
		and panel.node_buttons["nervous_system"].position == Vector2(550, 374)
		and panel.node_buttons["stomach"].visual_state == "available"
		and panel.node_buttons["ears"].visual_state == "available"
		and panel.node_buttons["stomach"].purchasable
		and panel.action_button.text.contains("20"),
		"Stomach must lead the Ghoul Body branch as a visible purchasable passive",
	)
	panel.select_node("nervous_system")
	_expect(
		panel.node_buttons["nervous_system"].visual_state == "intrinsic_owned"
		and not panel.node_buttons["nervous_system"].disabled
		and panel.action_button.disabled,
		"Intrinsic body features must remain selectable but never purchasable",
	)
	var controls := panel.focusable_controls()
	_expect(
		controls.has(panel.node_buttons["stomach"])
		and controls.has(panel.node_buttons["ears"])
		and controls.has(panel.node_buttons["nervous_system"])
		and controls.has(panel.loadout_buttons["attack"]),
		"Visible nodes and loadout controls must remain keyboard/gamepad focusable",
	)
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		panel.apply_locale()
		panel.select_node("stomach")
		_expect(
			panel.detail_title_label.text == Loc.text("SKILL_STOMACH")
			and panel.detail_description_label.text.contains(Loc.text("SKILL_STOMACH_DESC")),
			"Stomach details must refresh fully in %s" % locale,
		)
		panel.select_node("ears")
		_expect(
			panel.detail_title_label.text == Loc.text("SKILL_EARS")
			and panel.detail_description_label.text.contains(Loc.text("SKILL_EARS_DESC")),
			"Ears details must refresh fully in %s" % locale,
		)
		panel.select_node("nervous_system")
		_expect(
			panel.detail_title_label.text == Loc.text("FEATURE_NERVOUS_SYSTEM")
			and panel.detail_stats_label.text.contains(Loc.text("SKILL_DETAIL_MANA", [0])),
			"Persistent skill details must refresh fully in %s" % locale,
		)
	panel.queue_free()
	await tree.process_frame


func _test_main_selection_and_purchase(tree: SceneTree) -> void:
	Loc.set_locale("ru")
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.configure_character("Skill Tree", Rules.default_attributes())
	main.state.carried_souls = 10
	main.screen = main.Screen.BASE
	main._show_character()
	main._select_character_panel("skills")
	var before_dict: Dictionary = main.state.to_save_data()
	main._on_skill_pressed("strong_bones")
	_expect(
		main.state.to_save_data() == before_dict
		and main.skill_tree_panel.selected_node_id == "strong_bones"
		and main.skill_tree_panel.detail_title_label.text == Loc.text("SKILL_STRONG_BONES"),
		"Node activation must only select and must not mutate or persist gameplay state",
	)
	main.skill_tree_panel.action_button.pressed.emit()
	_expect(
		main.state.get_skill_level("strong_bones") == 1
		and main.state.carried_souls == 5,
		"One Learn activation must perform exactly one existing RunState purchase",
	)
	main.state.banked_souls = 200
	main._on_skill_pressed("fundamentals")
	main.skill_tree_panel.action_button.grab_focus()
	main.skill_tree_panel.action_button.pressed.emit()
	await tree.process_frame
	_expect(
		main.state.get_skill_level("fundamentals") == 1
		and main.state.unspent_attribute_points == 5
		and tree.root.gui_get_focus_owner() == main.skill_node_buttons["fundamentals"],
		"A maxed-on-purchase action must keep Fundamentals side effects and return focus to its selected node",
	)
	main._on_skill_pressed("magic_awakening")
	main._on_skill_purchase_pressed("magic_awakening")
	main._on_skill_pressed("magic_missile")
	main._on_skill_purchase_pressed("magic_missile")
	main.skill_tree_panel.loadout_buttons["active_1"].pressed.emit()
	_expect(
		main.state.get_skill_level("magic_missile") == 1
		and main.state.get_slotted_ability("active_1") == "magic_missile",
		"A newly purchased active skill must immediately enter the existing loadout choices",
	)
	main.state.current_form_id = "ghoul"
	main.state.absorbed_souls = int(Rules.FORMS["ghoul"]["threshold"])
	main.state.highest_unlocked_form_index = Rules.FORM_ORDER.find("ghoul")
	main.state.hunger = 13
	main.state.hunger_turn_progress = 7
	main.state.active_statuses.erase("satiated")
	main._refresh_character_sheet()
	_expect(
		not main.state.uses_hunger()
		and not main.character_derived_label.text.contains(Loc.text("SIDEBAR_HUNGER", [13]).get_slice(":", 0)),
		"A Ghoul without Stomach must hide Satiety from the character UI",
	)
	main._select_skill_stage("ghoul")
	main._on_skill_pressed("stomach")
	var souls_before_stomach: int = main.state.get_total_souls()
	main.skill_tree_panel.action_button.pressed.emit()
	_expect(
		main.state.get_skill_level("stomach") == 1
		and main.state.get_total_souls() == souls_before_stomach - 20
		and main.state.hunger == 100 and main.state.hunger_turn_progress == 0
		and not main.state.has_status("satiated") and main.state.uses_hunger()
		and main.character_derived_label.text.contains(Loc.text("SIDEBAR_HUNGER", [100]).get_slice(":", 0)),
		"Buying Stomach must reveal initialized Satiety without granting the camp status",
	)
	var stomach_restored := RunState.new()
	_expect(
		stomach_restored.restore_save_data(main.state.to_save_data())
		and stomach_restored.get_skill_level("stomach") == 1
		and stomach_restored.uses_hunger() and not stomach_restored.has_status("satiated"),
		"Learned Stomach must round-trip additively in save version 13",
	)
	await _test_remapped_interact_dispatch(tree, main)
	_expect(
		not main.state.to_save_data().has("selected_skill")
		and not main.state.to_save_data().has("selected_skill_stage"),
		"Skill and stage selection must remain transient UI state",
	)
	main.queue_free()
	await tree.process_frame




func _test_remapped_interact_dispatch(tree: SceneTree, main) -> void:
	var original_events: Array[InputEvent] = InputMap.action_get_events("interact")
	InputMap.action_erase_events("interact")
	var remapped := InputEventKey.new()
	remapped.keycode = KEY_F9
	InputMap.action_add_event("interact", remapped)
	var event := InputEventKey.new()
	event.keycode = KEY_F9
	event.pressed = true

	main.state.highest_unlocked_form_index = Rules.FORM_ORDER.find("almost_human")
	main._refresh_character_sheet()
	main.ghoul_tab_button.grab_focus()
	main._unhandled_input(event)
	_expect(main.selected_skill_stage == "ghoul", "A physically remapped interact key must activate focused descendant stage tabs")

	main._select_skill_stage("skeleton")
	main._on_skill_pressed("strong_bones")
	main.skill_node_buttons["magic_awakening"].grab_focus()
	main._unhandled_input(event)
	_expect(main.skill_tree_panel.selected_node_id == "magic_awakening", "A physically remapped interact key must activate focused descendant skill nodes")

	var loadout_before: String = main.state.get_slotted_ability("active_1")
	main.skill_tree_panel.loadout_buttons["active_1"].grab_focus()
	main._unhandled_input(event)
	_expect(main.state.get_slotted_ability("active_1") != loadout_before, "A physically remapped interact key must activate focused descendant loadout buttons")

	main.state.banked_souls = 300
	main._select_skill_stage("revenant")
	main._on_skill_pressed("sharp_vision")
	main.skill_tree_panel.action_button.grab_focus()
	main._unhandled_input(event)
	_expect(main.state.get_skill_level("sharp_vision") == 1, "One remapped interact press on the focused purchase action must buy exactly one level")

	InputMap.action_erase_events("interact")
	for original_event in original_events:
		InputMap.action_add_event("interact", original_event)
	main.state.banked_souls = 300
	main.skill_tree_panel.action_button.grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	main._unhandled_input(enter)
	_expect(main.state.get_skill_level("sharp_vision") == 2, "Default Enter/A overlap between interact and ui_accept must still dispatch only one purchase")
	await tree.process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
