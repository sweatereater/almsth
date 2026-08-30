class_name AppearanceTestSuite
extends RefCounted

const AbilitySystem := preload("res://scripts/game/skill_system.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const Loc := preload("res://scripts/localization/localization.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_registry_purchase_and_state()
	_test_save_sanitize_and_death()
	await _test_modal_integration(tree)
	return failures


func _test_registry_purchase_and_state() -> void:
	var skill: Dictionary = GameRules.SKILLS.get("choose_appearance", {})
	var ability: Dictionary = AbilitySystem.ability("choose_appearance")
	_expect(
		skill.get("stage") == "almost_human" and skill.get("kind") == "active"
		and skill.get("ability_id") == "choose_appearance" and int(skill.get("base_cost", 0)) == 100
		and int(skill.get("max_level", 0)) == 1 and (skill.get("requires", {}) as Dictionary).is_empty(),
		"Choose Appearance skill must keep its Almost Human active/cost/max contract",
	)
	_expect(
		ability.get("slot_kind") == "active" and ability.get("target_kind") == "appearance_choice"
		and ability.get("required_stage") == "almost_human"
		and int(ability.get("mana_cost", -1)) == 0 and int(ability.get("turn_cost", -1)) == 0,
		"Choose Appearance ability must be an active zero-cost appearance choice",
	)
	var state := RunState.new()
	state.banked_souls = 100
	_expect(state.purchase_skill("choose_appearance").get("reason") == "stage_locked", "Choose Appearance purchase must respect its stage gate")
	state.current_form_id = "almost_human"
	state.absorbed_souls = 80
	state.highest_unlocked_form_index = 4
	state.soul_level = 4
	_expect(bool(state.purchase_skill("choose_appearance").get("ok", false)) and state.get_total_souls() == 0, "Choose Appearance must cost exactly 100 souls")
	_expect(state.assign_ability("active_2", "choose_appearance") and state.get_slotted_ability("active_2") == "choose_appearance", "Choose Appearance must fit a normal active slot")
	_expect(state.available_display_form_ids() == GameRules.FORM_ORDER, "Almost Human must be able to choose all five unlocked forms")
	var gameplay_before := JSON.stringify({
		"form": state.current_form_id,
		"rules": state.get_form(),
		"derived": state.get_derived_stats(),
		"hunger": state.uses_hunger(),
		"ability": state.can_use_ability("circular_attack"),
	})
	_expect(state.set_display_form_id("zombie") and state.get_display_form_id() == "zombie", "A learned appearance must select an unlocked cosmetic form")
	var gameplay_after := JSON.stringify({
		"form": state.current_form_id,
		"rules": state.get_form(),
		"derived": state.get_derived_stats(),
		"hunger": state.uses_hunger(),
		"ability": state.can_use_ability("circular_attack"),
	})
	_expect(gameplay_before == gameplay_after and Renderer.player_visual_form_id(state) == "zombie", "Appearance must affect only the renderer selector, never gameplay state")
	_expect(not state.set_display_form_id("unknown") and state.get_display_form_id() == "zombie", "Unknown appearances must be rejected without mutation")
	_expect(state.set_display_form_id("almost_human") and state.display_form_id.is_empty(), "Choosing the actual form must restore follow-current mode")


func _test_save_sanitize_and_death() -> void:
	var state := _appearance_state()
	state.assign_ability("active_1", "choose_appearance")
	state.set_display_form_id("ghoul")
	var restored := RunState.new()
	_expect(restored.restore_save_data(state.to_save_data()) and restored.display_form_id == "ghoul", "Appearance override must roundtrip in version 9 state")
	var no_skill := state.to_save_data()
	(no_skill["skill_levels"] as Dictionary)["choose_appearance"] = 0
	var sanitized_no_skill := RunState.new()
	_expect(sanitized_no_skill.restore_save_data(no_skill) and sanitized_no_skill.display_form_id.is_empty(), "An override without the learned skill must sanitize to follow-current")
	var locked := state.to_save_data()
	locked["absorbed_souls"] = 10
	locked["highest_unlocked_form_index"] = 1
	locked["display_form_id"] = "revenant"
	var sanitized_locked := RunState.new()
	_expect(sanitized_locked.restore_save_data(locked) and sanitized_locked.display_form_id.is_empty(), "A locked saved appearance must sanitize to follow-current")
	state.set_display_form_id("skeleton")
	var learned_before := state.get_skill_level("choose_appearance")
	var loadout_before := state.get_slotted_ability("active_1")
	state.die()
	_expect(
		state.current_form_id == "skeleton" and state.display_form_id.is_empty()
		and state.get_skill_level("choose_appearance") == learned_before
		and state.get_slotted_ability("active_1") == loadout_before,
		"Death must clear appearance while preserving learned skill and loadout",
	)


func _test_modal_integration(tree: SceneTree) -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state = _appearance_state()
	main.state.assign_ability("active_1", "choose_appearance")
	main.screen = main.Screen.DUNGEON
	main._load_floor(99)
	var before := _runtime_snapshot(main)
	main.held_direction = Vector2i.RIGHT
	main.auto_explore_active = true
	main.auto_travel_active = true
	_expect(main._activate_ability_slot("active_1") and main.appearance_choice_panel.visible, "Ability activation must open the appearance modal")
	_expect(main.held_direction == Vector2i.ZERO and not main.auto_explore_active and not main.auto_travel_active, "Opening appearance choice must stop held and automatic movement")
	_expect(before == _runtime_snapshot(main), "Opening appearance choice must spend no turn, mana, HP, survival, or enemy action")
	_expect(main.appearance_choice_panel.available_forms.size() == 5, "Appearance modal must list all five unlocked localized forms")
	var player_before: Vector2i = main.player_pos
	main._handle_board_cell(player_before + Vector2i.RIGHT)
	_expect(main.player_pos == player_before and before == _runtime_snapshot(main), "Appearance modal must block dungeon click-through")

	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		main._apply_locale()
		_expect(
			main.appearance_choice_panel.hint_label.text == Loc.text("APPEARANCE_COSMETIC_HINT")
			and main.appearance_choice_panel.form_buttons.size() == 5,
			"Appearance modal must retain RU/EN labels and cosmetic warning",
		)

	var start_index: int = main.appearance_choice_panel.selected_index
	_expect(main.appearance_choice_panel.handle_input(_action("move_down")) and main.appearance_choice_panel.selected_index != start_index, "WASD action must navigate the modal")
	_expect(main.appearance_choice_panel.handle_input(_key(KEY_UP)) and main.appearance_choice_panel.selected_index == start_index, "Arrow keys must navigate the modal")
	_expect(main.appearance_choice_panel.handle_input(_joy_button(JOY_BUTTON_DPAD_DOWN)), "Gamepad D-pad must navigate the modal")
	_expect(main.appearance_choice_panel.handle_input(_joy_axis(JOY_AXIS_LEFT_Y, -0.9)), "Gamepad stick must navigate the modal")
	main.appearance_choice_panel.form_buttons[1].pressed.emit()
	await _touch_control(main, tree, main.appearance_choice_panel.confirm_button)
	_expect(not main.appearance_choice_panel.visible and main.state.get_display_form_id() == "zombie", "Mouse selection and touch confirmation must apply the selected appearance")
	_expect(before == _runtime_snapshot(main), "Confirming appearance must remain a zero-turn zero-mana action")

	main._activate_ability_slot("active_1")
	_expect(main.appearance_choice_panel.handle_input(_key(KEY_ESCAPE)) and not main.appearance_choice_panel.visible, "Esc/B cancellation must close without changing appearance")
	_expect(main.state.get_display_form_id() == "zombie" and before == _runtime_snapshot(main), "Cancel must preserve appearance and gameplay state")
	main._activate_ability_slot("active_1")
	_expect(main.appearance_choice_panel.handle_input(_joy_button(JOY_BUTTON_B)) and not main.appearance_choice_panel.visible, "Gamepad B must cancel appearance choice")

	main.state.current_form_id = "revenant"
	main.screen = main.Screen.DUNGEON
	_expect(not main._activate_ability_slot("active_1") and not main.appearance_choice_panel.visible, "Only the actual Almost Human form may activate appearance choice")
	main.queue_free()
	await tree.process_frame
	Loc.set_locale("ru")


func _appearance_state() -> RunState:
	var state := RunState.new()
	state.configure_character("Appearance", GameRules.default_attributes())
	state.current_form_id = "almost_human"
	state.absorbed_souls = 80
	state.highest_unlocked_form_index = 4
	state.soul_level = 4
	state.skill_levels["choose_appearance"] = 1
	return state


func _runtime_snapshot(main) -> String:
	var enemy_state: Array = []
	for enemy in main.floor_data.get("enemies", []):
		enemy_state.append([enemy.get("uid", ""), enemy.get("pos"), enemy.get("hp", 0)])
	return JSON.stringify({
		"turns": main.state.total_turns,
		"mana": main.state.mana,
		"hp": main.state.hp,
		"hunger": main.state.hunger,
		"hunger_progress": main.state.hunger_turn_progress,
		"regeneration": main.state.regeneration_progress,
		"enemies": enemy_state,
	})


func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _touch_control(main, tree: SceneTree, control: Control) -> void:
	var position := control.global_position + control.size * 0.5
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = true
	main.appearance_choice_panel._input(event)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	main.appearance_choice_panel._input(event)
	await tree.process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
