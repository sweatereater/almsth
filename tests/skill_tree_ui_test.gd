class_name SkillTreeUiTestSuite
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const Rules := preload("res://scripts/game/game_rules.gd")
const PanelClass := preload("res://scripts/ui/skill_tree_panel.gd")
const IconClass := preload("res://scripts/ui/skill_tree_icon.gd")
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
			["strong_bones", "flexible_joints", "strong_spine"],
			["magic_awakening", "magic_missile", "magic_missile_range", "magic_ricochet"],
		],
		"zombie": [["sharp_vision", "muscle_fibers"]],
		"ghoul": [["stomach", "flesh_regeneration", "ears"], ["dash"], ["double_attack"]],
		"revenant": [["nervous_system"]],
		"almost_human": [["choose_appearance", "fundamentals"], ["almost_double_strike"], ["circular_attack"]],
	}
	var expected_branch_keys := {
		"skeleton": "SKILL_BRANCH_BODY_BONES", "zombie": "SKILL_BRANCH_BODY_FLESH",
		"ghoul": "SKILL_BRANCH_BODY_GUT", "revenant": "SKILL_BRANCH_BODY_CNS",
		"almost_human": "SKILL_BRANCH_BODY_APPEARANCE",
	}
	for stage_id in expected:
		var actual_branches: Array = PanelClass.STAGE_BRANCHES[stage_id]
		_expect(actual_branches.size() <= 3, "%s must render no more than three branches" % stage_id)
		_expect(actual_branches.size() == expected[stage_id].size(), "%s branch count must match the approved topology" % stage_id)
		for index in range(mini(actual_branches.size(), expected[stage_id].size())):
			_expect(actual_branches[index]["nodes"] == expected[stage_id][index], "%s branch %d node order must match the approved topology" % [stage_id, index])
		_expect(actual_branches[0]["label"] == expected_branch_keys[stage_id], "%s body branch must be first" % stage_id)
		for branch in actual_branches:
			for node_id in branch["nodes"]:
				_expect(not String(node_id).contains("soon") and node_id != "spinal_cord", "Soon and spinal-cord nodes must be absent from topology")
	_expect(Rules.SKILLS.size() == 19 and Rules.BODY_SKILL_IDS.size() == 11, "The clean registry must contain exactly 19 skills, including 11 body skills")
	var body_rules := {
		"strong_bones": ["skeleton", 5, 5, 5], "flexible_joints": ["skeleton", 1, 15, 0],
		"strong_spine": ["skeleton", 1, 20, 0], "sharp_vision": ["zombie", 1, 80, 0],
		"muscle_fibers": ["zombie", 2, 20, 10], "stomach": ["ghoul", 1, 20, 0],
		"flesh_regeneration": ["ghoul", 1, 20, 0], "ears": ["ghoul", 1, 20, 0],
		"nervous_system": ["revenant", 1, 80, 0], "choose_appearance": ["almost_human", 1, 100, 0],
		"fundamentals": ["almost_human", 1, 25, 0],
	}
	for skill_id in body_rules:
		var rules: Dictionary = Rules.SKILLS.get(skill_id, {})
		var contract: Array = body_rules[skill_id]
		_expect(
			rules.get("stage") == contract[0] and int(rules.get("max_level", 0)) == contract[1]
			and int(rules.get("base_cost", -1)) == contract[2] and int(rules.get("cost_step", -1)) == contract[3]
			and (rules.get("requires", {}) as Dictionary).is_empty()
			and String(rules.get("icon", "")) == "res://assets/ui/skill-icons/body/%s.png" % skill_id,
			"Body skill %s must keep its approved stage, levels, price, empty dependencies and stable icon path" % skill_id,
		)
	_test_icon_assets()
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
	_expect(
		SaveSystem.STATE_ONLY_VERSION == 17
		and SaveSystem.SAVE_VERSION == 17
		and SaveSystem.MIN_SUPPORTED_SAVE_VERSION == 17,
		"State-only and exact gameplay snapshots must share the strict v17 boundary",
	)
	_expect(
		ProjectSettings.get_setting("display/window/size/viewport_width") == 1280
		and ProjectSettings.get_setting("display/window/size/viewport_height") == 720
		and ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items"
		and ProjectSettings.get_setting("display/window/stretch/aspect") == "keep",
		"Character geometry must remain a 1280x720 canvas that scales intact to 960x540",
	)
	for locale in Loc.SUPPORTED_LOCALES:
		for key in [
			"SKILL_BRANCH_BODY_BONES", "SKILL_BRANCH_BODY_FLESH", "SKILL_BRANCH_BODY_GUT",
			"SKILL_BRANCH_BODY_CNS", "SKILL_BRANCH_BODY_APPEARANCE", "SKILL_BRANCH_MANEUVER",
			"SKILL_DETAIL_EFFECT", "SKILL_DETAIL_MANA", "SKILL_DETAIL_COOLDOWN",
			"SKILL_DETAIL_REQUIREMENT", "SKILL_ACTION_LEARN", "SKILL_ACTION_UPGRADE",
		]:
			_expect(Loc.STRINGS[locale].has(key), "Skill tree localization %s missing in %s" % [key, locale])
		for skill_id in Rules.BODY_SKILL_IDS:
			var name_key := String(Rules.SKILLS[skill_id]["name"])
			_expect(
				Loc.STRINGS[locale].has(name_key)
				and Loc.STRINGS[locale].has(String(Rules.SKILLS[skill_id]["description"]))
				and Loc.STRINGS[locale].has(name_key + "_DETAIL"),
				"Body skill localization %s must include name, short effect and detail in %s" % [skill_id, locale],
			)


func _test_icon_assets() -> void:
	for skill_id in Rules.BODY_SKILL_IDS:
		var icon_path := String(Rules.SKILLS[skill_id]["icon"])
		var image := Image.load_from_file(ProjectSettings.globalize_path(icon_path))
		var texture := IconClass.load_skill_texture(skill_id)
		_expect(
			image != null and image.get_size() == Vector2i(128, 128)
			and image.get_format() == Image.FORMAT_RGBA8,
			"Body icon %s must be a 128x128 RGBA8 runtime PNG" % skill_id,
		)
		_expect(
			texture != null and texture.get_size() == Vector2(128, 128),
			"Body icon %s must load safely through the stable registry path" % skill_id,
		)
		var import_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(icon_path + ".import"))
		_expect(
			import_text.contains("compress/mode=0")
			and import_text.contains("mipmaps/generate=false")
			and import_text.contains("process/fix_alpha_border=true"),
			"Body icon %s must use lossless import with mipmaps off and alpha-border repair" % skill_id,
		)
	var body_icon := IconClass.new()
	body_icon.set_presentation("strong_bones", "Body", "passive", "available", false)
	_expect(body_icon.uses_raster_texture(), "Body skills must use the registered raster texture")
	var glyph_icon := IconClass.new()
	glyph_icon.set_presentation("magic_awakening", "Magic", "passive", "available", false)
	_expect(not glyph_icon.uses_raster_texture(), "Non-body skills must retain their code-drawn glyph")
	var missing_icon := IconClass.new()
	missing_icon.set_presentation("missing_skill", "Fallback", "passive", "available", false)
	_expect(not missing_icon.uses_raster_texture(), "A missing texture mapping must safely fall back to the current glyph")
	body_icon.free()
	glyph_icon.free()
	missing_icon.free()


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
		and panel.node_buttons["flexible_joints"].position == Vector2(350, 214)
		and panel.node_buttons["strong_spine"].position == Vector2(550, 214)
		and panel.node_buttons["magic_awakening"].position == Vector2(150, 294),
		"Skill nodes must follow the approved branch tracks and 200-pixel chain spacing",
	)
	_expect(
		panel.branch_labels["skeleton"][0].horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
		and panel.node_buttons["strong_bones"].purchasable,
		"Branch labels must point toward the chain and every purchasable node must carry its gold cost badge",
	)
	panel.select_node("strong_spine")
	_expect(
		panel.selected_node_id == "strong_spine"
		and not panel.node_buttons["strong_spine"].disabled
		and panel.node_buttons["strong_spine"].visual_state == "available"
		and not panel.action_button.disabled,
		"Independent body nodes must remain selectable and purchasable without implicit prerequisites",
	)
	state.banked_souls = 0
	panel.select_node("strong_bones")
	_expect(
		panel.status_label.text == Loc.text("SKILL_NEEDS_SOULS", [5])
		and panel.action_button.disabled,
		"A selected affordable-stage skill must explain insufficient souls without purchasing",
	)
	state.banked_souls = 500
	state.skill_levels["strong_bones"] = 5
	panel.select_node("strong_bones")
	_expect(
		panel.node_buttons["strong_bones"].visual_state == "max"
		and not panel.node_buttons["strong_bones"].disabled
		and panel.action_button.disabled
		and panel.status_label.text == Loc.text("SKILL_ALREADY_MAX"),
		"Maxed passive circles must stay selectable and show a distinct max state",
	)
	state.skill_levels["flexible_joints"] = 1
	panel.refresh()
	_expect(
		PanelClass.connector_style_for_states(
			panel._node_presentation("strong_bones")["state"],
			panel._node_presentation("flexible_joints")["state"],
		) == "learned",
		"A maxed body node must keep the learned connector treatment",
	)
	state.skill_levels["choose_appearance"] = 1
	panel.set_context(state, "almost_human")
	_expect(
		PanelClass.connector_style_for_states(
			panel._node_presentation("choose_appearance")["state"],
			panel._node_presentation("fundamentals")["state"],
		) == "learned",
		"The appearance body branch must preserve learned connector state",
	)
	Loc.set_locale("en")
	panel.apply_locale()
	var appearance_node = panel.node_buttons["choose_appearance"]
	var followup_node = panel.node_buttons["almost_double_strike"]
	var followup_badge_local: Rect2 = followup_node.cost_badge_bounds()
	var followup_badge := Rect2(
		followup_node.position + followup_badge_local.position,
		followup_badge_local.size,
	)
	var appearance_lines: Array[Rect2] = appearance_node.name_line_bounds()
	var geometry_clear := appearance_lines.size() == 2
	for scale in [1.0, 0.75]:
		var scaled_badge := Rect2(
			followup_badge.position * scale,
			followup_badge.size * scale,
		)
		for local_line in appearance_lines:
			var line := Rect2(
				(appearance_node.position + local_line.position) * scale,
				local_line.size * scale,
			)
			geometry_clear = geometry_clear and not line.intersects(scaled_badge)
	_expect(
		geometry_clear,
		"Two-line Choose Appearance must not overlap the Follow-up Strike cost badge at 1280x720 or 960x540",
	)
	state.highest_unlocked_form_index = 0
	panel.set_context(state, "zombie")
	panel.select_node("sharp_vision")
	_expect(
		panel.node_buttons["sharp_vision"].visual_state == "locked"
		and not panel.node_buttons["sharp_vision"].disabled
		and panel.status_label.text == Loc.text("SKILL_STAGE_LOCKED")
		and panel.action_button.disabled,
		"Stage-locked skill details must remain inspectable without enabling purchase",
	)
	state.highest_unlocked_form_index = Rules.FORM_ORDER.find("almost_human")
	panel.set_context(state, "ghoul")
	panel.select_node("stomach")
	_expect(
		panel.node_buttons["stomach"].position == Vector2(150, 214)
		and panel.node_buttons["flesh_regeneration"].position == Vector2(350, 214)
		and panel.node_buttons["ears"].position == Vector2(550, 214)
		and panel.node_buttons["stomach"].visual_state == "available"
		and panel.node_buttons["ears"].visual_state == "available"
		and panel.node_buttons["stomach"].purchasable
		and panel.action_button.text.contains("20"),
		"Stomach must lead the Ghoul Body branch as a visible purchasable passive",
	)
	panel.set_context(state, "revenant")
	panel.select_node("nervous_system")
	_expect(
		panel.node_buttons["nervous_system"].visual_state == "available"
		and not panel.node_buttons["nervous_system"].disabled
		and not panel.action_button.disabled
		and panel.action_button.text.contains("80"),
		"Nervous System must be a normal purchasable Revenant passive",
	)
	panel.set_context(state, "ghoul")
	var controls := panel.focusable_controls()
	_expect(
		controls.has(panel.node_buttons["stomach"])
		and controls.has(panel.node_buttons["ears"])
		and controls.has(panel.node_buttons["flesh_regeneration"])
		and not controls.has(panel.node_buttons["nervous_system"])
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
			panel.detail_title_label.text == Loc.text("SKILL_NERVOUS_SYSTEM")
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
	main.state.highest_unlocked_form_index = Rules.FORM_ORDER.find("almost_human")
	main._select_skill_stage("almost_human")
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
		"Learned Stomach must round-trip in the current v17 state schema",
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
	main._select_skill_stage("zombie")
	main._on_skill_pressed("muscle_fibers")
	main.skill_tree_panel.action_button.grab_focus()
	main._unhandled_input(event)
	_expect(main.state.get_skill_level("muscle_fibers") == 1, "One remapped interact press on the focused purchase action must buy exactly one level")

	InputMap.action_erase_events("interact")
	for original_event in original_events:
		InputMap.action_add_event("interact", original_event)
	main.state.banked_souls = 300
	main.skill_tree_panel.action_button.grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	main._unhandled_input(enter)
	_expect(main.state.get_skill_level("muscle_fibers") == 2, "Default Enter/A overlap between interact and ui_accept must still dispatch only one purchase")
	await tree.process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
