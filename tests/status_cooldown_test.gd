class_name StatusCooldownTestSuite
extends RefCounted

const AbilitySystem := preload("res://scripts/game/skill_system.gd")
const StatusSystem := preload("res://scripts/game/status_system.gd")
const Loc := preload("res://scripts/localization/localization.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	_test_registry_and_sanitation()
	_test_status_lifecycle_and_damage()
	_test_cooldown_boundaries()
	_test_camp_entry_contract()
	await _test_action_integration(tree)
	return failures


func _test_registry_and_sanitation() -> void:
	_expect(
		AbilitySystem.base_cooldown("dash") == 20
		and AbilitySystem.base_cooldown("double_attack") == 15
		and AbilitySystem.base_cooldown("magic_missile") == 0,
		"Ability metadata must be the single base-cooldown source",
	)
	var cooldowns := AbilitySystem.sanitize_cooldowns({
		"dash": 999.9,
		"double_attack": 4.8,
		"magic_missile": 6,
		"unknown": 8,
		"bad_bool": true,
	})
	_expect(
		cooldowns == {"dash": 20, "double_attack": 4},
		"Cooldown sanitation must floor numeric fractions, clamp maxima and drop bool/unknown/zero values",
	)
	var statuses := StatusSystem.sanitize({
		"rested": {"remaining_turns": 999.7, "temporary_hp": 99.2, "damage": 100},
		"unknown": {"remaining_turns": 50},
	})
	_expect(
		statuses == {"rested": {"remaining_turns": 500, "temporary_hp": 5}},
		"Status saves must retain only sanitized mutable Rested fields",
	)
	_expect(
		StatusSystem.sanitize({"rested": {"remaining_turns": true, "temporary_hp": 5}}).is_empty()
		and StatusSystem.sanitize([]).is_empty(),
		"Malformed and boolean status durations must safely restore as empty",
	)
	var serialization_state := RunState.new()
	serialization_state.ability_cooldowns = {
		"dash": 999.4, "double_attack": false, "unknown": 2,
	}
	serialization_state.active_statuses = {
		"rested": {"remaining_turns": 42.9, "temporary_hp": 99, "damage": 999},
		"unknown": {"remaining_turns": 7},
	}
	var serialized := serialization_state.to_save_data()
	_expect(
		serialized["ability_cooldowns"] == {"dash": 20}
		and serialized["active_statuses"] == {
			"rested": {"remaining_turns": 42, "temporary_hp": 5},
		},
		"Serialization must sanitize cooldown/status dictionaries as strictly as restore",
	)


func _test_status_lifecycle_and_damage() -> void:
	var state := RunState.new()
	state.current_form_id = "ghoul"
	state.hp = state.get_max_hp()
	_expect(
		state.add_or_refresh_status("rested")
		and state.status_remaining("rested") == 500
		and state.get_temporary_hp() == 5,
		"Rested must grant its exact duration and own temporary-HP pool",
	)
	state.apply_damage(3)
	_expect(
		state.get_temporary_hp() == 2 and state.hp == state.get_max_hp(),
		"Temporary HP must absorb ordinary damage before permanent HP",
	)
	state.add_or_refresh_status("rested")
	_expect(
		state.status_remaining("rested") == 500 and state.get_temporary_hp() == 5,
		"Refreshing Rested must restore, not stack, duration and temporary HP",
	)
	var base_damage := GameRules.calculate_derived_stats(
		state.attributes, state.current_form_id, state.loadout, state.base_level,
	)
	_expect(
		state.get_damage() == int(base_damage["damage"]) + 1
		and state.get_ranged_damage() == int(base_damage["ranged_damage"]) + 1
		and state.get_magic_missile_damage() == 0,
		"Rested must modify physical melee/ranged damage without granting spell power",
	)
	state.hunger = 0
	state.active_statuses["rested"]["temporary_hp"] = 1
	var hp_before := state.hp
	var starvation := state.advance_survival_turn()
	_expect(
		int(starvation.get("temporary_hp_absorbed", 0)) == 1
		and state.hp == hp_before,
		"Starvation must use the centralized temporary-HP damage path",
	)
	state.active_statuses["rested"] = {"remaining_turns": 1, "temporary_hp": 4}
	var expiry_events := state.finish_completed_round()
	_expect(
		not state.has_status("rested") and state.get_temporary_hp() == 0 and state.hp == hp_before
		and expiry_events == [{"type": "expired", "status_id": "rested"}],
		"Status expiry must discard unused own temporary HP without reducing permanent HP",
	)
	state.add_or_refresh_status("rested", 2, 2)
	_expect(
		StatusSystem.remove(state.active_statuses, "rested")
		and not StatusSystem.remove(state.active_statuses, "rested"),
		"Generic status removal must report a real removal exactly once",
	)
	state.add_or_refresh_status("rested")
	state.ability_cooldowns = {"dash": 7}
	state.die()
	_expect(
		state.active_statuses.is_empty() and state.ability_cooldowns.is_empty(),
		"Death must clear statuses, temporary HP and player cooldowns",
	)


func _test_cooldown_boundaries() -> void:
	var state := RunState.new()
	state.current_form_id = "ghoul"
	state.hp = state.get_max_hp()
	state.add_or_refresh_status("rested", 1, 5)
	var pending_dash := state.effective_cooldown("dash")
	_expect(
		pending_dash == 10 and state.effective_cooldown("double_attack") == 10,
		"Rested must snapshot exact 10-turn Dash and Double Attack cooldowns",
	)
	state.finish_completed_round("dash", pending_dash)
	_expect(
		state.cooldown_remaining("dash") == 10 and not state.has_status("rested"),
		"A newly installed cooldown must remain full after its application round even when Rested expires",
	)
	state.finish_completed_round()
	_expect(state.cooldown_remaining("dash") == 9, "The next accepted player turn must tick Dash from 10 to 9")
	for _index in range(9):
		state.finish_completed_round()
	_expect(state.cooldown_remaining("dash") == 0, "Ten subsequent completed turns must make a 10-turn cooldown ready")
	state.finish_completed_round("dash", 20)
	for expected in range(19, -1, -1):
		state.finish_completed_round()
		_expect(
			state.cooldown_remaining("dash") == expected,
			"Base Dash cooldown must deterministically tick through %d" % expected,
		)


func _test_camp_entry_contract() -> void:
	var skeleton := RunState.new()
	skeleton.display_form_id = "ghoul"
	skeleton.safe_return()
	_expect(
		not skeleton.has_status("rested")
		and not GameRules.has_intrinsic_feature("skeleton", "nervous_system")
		and GameRules.has_intrinsic_feature("ghoul", "nervous_system")
		and GameRules.has_intrinsic_feature("almost_human", "nervous_system"),
		"Only the actual Ghoul+ form may own Nervous System and receive Rested; display form is cosmetic",
	)
	var zombie := RunState.new()
	zombie.current_form_id = "zombie"
	zombie.absorbed_souls = int(GameRules.FORMS["zombie"]["threshold"])
	zombie.hunger = 17
	zombie.safe_return()
	_expect(
		zombie.hunger == 100 and not zombie.has_status("rested"),
		"Actual Zombie camp entry must refill hunger for free without Rested",
	)
	var ghoul := RunState.new()
	ghoul.configure_character("Camp Tester", GameRules.default_attributes())
	ghoul.current_form_id = "ghoul"
	ghoul.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
	ghoul.hunger = 8
	ghoul.safe_return()
	_expect(
		ghoul.hunger == 100 and ghoul.status_remaining("rested") == 500
		and ghoul.get_temporary_hp() == 5,
		"Actual Ghoul+ camp entry must grant exact Rested 500/+5 and full hunger",
	)
	ghoul.active_statuses["rested"] = {"remaining_turns": 3, "temporary_hp": 1}
	ghoul.apply_camp_entry_effects()
	_expect(
		ghoul.status_remaining("rested") == 500 and ghoul.get_temporary_hp() == 5,
		"Repeated camp entry must refresh Rested exactly without stacking",
	)
	ghoul.active_statuses["rested"] = {"remaining_turns": 17, "temporary_hp": 2}
	ghoul.food = 1
	ghoul.hunger = 80
	ghoul.camp_and_eat()
	_expect(
		ghoul.status_remaining("rested") == 17 and ghoul.get_temporary_hp() == 2,
		"Field camp_and_eat must never grant or refresh Rested",
	)
	ghoul.hunger = 12
	var loaded := RunState.new()
	_expect(
		loaded.restore_save_data(ghoul.to_save_data())
		and loaded.hunger == 12
		and loaded.status_remaining("rested") == 17
		and loaded.get_temporary_hp() == 2,
		"Loading a base save must not refresh Rested (restore=%s hunger=%d turns=%d temp=%d)" % [
			loaded.character_name, loaded.hunger, loaded.status_remaining("rested"), loaded.get_temporary_hp(),
		],
	)


func _test_action_integration(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	_configure_form(main, "ghoul")
	main.state.skill_levels["dash"] = 1
	main.state.skill_levels["double_attack"] = 1
	main.state.assign_ability("active_1", "dash")
	main.state.assign_ability("attack", "double_attack")
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(3, 3)
	_reveal_floor(main)
	var turns_before: int = main.state.total_turns
	main._begin_dash_targeting()
	main._cancel_ability_targeting()
	_expect(
		main.state.total_turns == turns_before
		and main.state.cooldown_remaining("dash") == 0,
		"Dash target entry/cancel must consume zero turns and start no cooldown",
	)
	main._begin_dash_targeting()
	main.floor_data["enemies"] = [_enemy("blocker", Vector2i(5, 3), 50)]
	_expect(
		not main._confirm_dash(Vector2i(6, 3))
		and main.state.total_turns == turns_before
		and main.state.cooldown_remaining("dash") == 0,
		"Dash confirmation must revalidate blockers with zero-turn rejection",
	)
	main.floor_data["enemies"].clear()
	main._refresh_dash_partition()
	_expect(main._confirm_dash(Vector2i(5, 3)), "A valid Dash fixture must commit")
	_expect(
		main.state.total_turns == turns_before + 1
		and main.state.cooldown_remaining("dash") == 20,
		"Successful base Dash must install 20 only after its completed round",
	)
	var cooldown_turns: int = main.state.total_turns
	_expect(
		not main._activate_ability_slot("active_1")
		and main.state.total_turns == cooldown_turns
		and main.state.cooldown_remaining("dash") == 20,
		"Using a cooling active Dash must do nothing and tick nothing",
	)
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == cooldown_turns + 1
		and main.state.cooldown_remaining("dash") == 19,
		"An accepted wait must tick an already-running cooldown exactly once",
	)

	main.player_pos = Vector2i(3, 3)
	main.state.ability_cooldowns.erase("double_attack")
	main.floor_data["enemies"].clear()
	var no_target_turns: int = main.state.total_turns
	_expect(
		not main._activate_ability_slot("attack")
		and main.state.total_turns == no_target_turns
		and main.state.cooldown_remaining("double_attack") == 0,
		"Double Attack without a valid target must spend no turn and start no cooldown",
	)
	main.floor_data["enemies"] = [_enemy("target", Vector2i(4, 3), 50)]
	_expect(
		main._activate_ability_slot("attack", {
			"target_uid": "target", "attack_rolls": [1, 1],
		}),
		"A valid Double Attack target must commit even when both independent strikes miss",
	)
	_expect(
		main.state.cooldown_remaining("double_attack") == 15,
		"Committed Double Attack must start its exact 15-turn cooldown after misses",
	)
	main._refresh_hotbar()
	_expect(
		main._effective_attack_ability() == "basic_attack"
		and main.attack_button.text.contains(Loc.text("ABILITY_BASIC_ATTACK"))
		and main.attack_button.text.contains("15")
		and main.hotbar_cooldown_badges["attack"].visible,
		"A cooling assigned Double Attack must visibly fall back to usable Basic Attack",
	)
	main.state.loadout["right_hand"] = "bone_bow@0"
	main._refresh_hotbar()
	_expect(
		main._effective_attack_ability() == "basic_attack" and not main.attack_button.disabled,
		"A cooling physical skill must never disable the contextual Basic Shot from a bow",
	)
	main.state.loadout.erase("right_hand")
	main.state.add_or_refresh_status("rested", 500, 5)
	main._refresh_interface()
	await tree.process_frame
	var status_chips: Array[Node] = main.status_strip.get_children()
	_expect(
		main.status_strip.visible and status_chips.size() == 1
		and String(status_chips[0].tooltip_text).contains("500")
		and not String(status_chips[0].accessibility_name).is_empty(),
		"The dungeon status strip must expose a code-drawn Rested 500 chip with tooltip/accessibility",
	)
	main.queue_free()
	await tree.process_frame

	var boundary = await _new_main(tree)
	_configure_form(boundary, "ghoul")
	boundary.state.skill_levels["dash"] = 1
	boundary.floor_data = _floor_fixture()
	boundary.player_pos = Vector2i(3, 3)
	boundary.floor_data["enemies"] = [_enemy("response", Vector2i(4, 3), 50)]
	boundary.floor_data["enemies"][0]["accuracy"] = 100
	boundary.floor_data["enemies"][0]["damage"] = 6
	_reveal_floor(boundary)
	boundary.state.add_or_refresh_status("rested", 1, 5)
	var permanent_hp_before: int = boundary.state.hp
	boundary._complete_player_turn("dash", boundary.state.effective_cooldown("dash"))
	_expect(
		boundary.state.hp == permanent_hp_before - 1
		and not boundary.state.has_status("rested")
		and boundary.state.cooldown_remaining("dash") == 10,
		"Rested remaining1 must protect through enemy response, then expire after installing snapshotted Dash10",
	)
	boundary.queue_free()
	await tree.process_frame

	var lethal = await _new_main(tree)
	_configure_form(lethal, "ghoul")
	lethal.floor_data = _floor_fixture()
	lethal.player_pos = Vector2i(3, 3)
	lethal.floor_data["enemies"] = [_enemy("lethal-response", Vector2i(4, 3), 50)]
	lethal.floor_data["enemies"][0]["accuracy"] = 100
	lethal.floor_data["enemies"][0]["damage"] = lethal.state.hp + 50
	_reveal_floor(lethal)
	lethal._complete_player_turn("dash", 20)
	_expect(
		lethal.screen == lethal.Screen.STORY and lethal.story_kind == "death"
		and lethal.state.ability_cooldowns.is_empty()
		and lethal.state.active_statuses.is_empty(),
		"Death during enemy response must clear runtime effects and never install the pending cooldown",
	)
	lethal.queue_free()
	await tree.process_frame


func _new_main(tree: SceneTree):
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.screen = main.Screen.DUNGEON
	main.state = RunState.new()
	return main


func _configure_form(main, form_id: String) -> void:
	main.state.current_form_id = form_id
	main.state.absorbed_souls = int(GameRules.FORMS[form_id]["threshold"])
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find(form_id)
	main.state.hp = main.state.get_max_hp()
	main.state.mana = main.state.get_max_mana()


func _floor_fixture() -> Dictionary:
	var tiles := {}
	for y in range(7):
		for x in range(8):
			tiles[Vector2i(x, y)] = (
				"floor" if x > 0 and x < 7 and y > 0 and y < 6 else "wall"
			)
	return {
		"width": 8, "height": 7, "tiles": tiles,
		"start": Vector2i(2, 3), "base_gate": Vector2i(1, 1), "exit": Vector2i(6, 5),
		"exit_known": false, "cradle": Vector2i(-1, -1), "cradle_known": false,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [], "enemies": [], "visible_cells": {}, "explored_cells": {},
		"observed_cells": {},
	}


func _reveal_floor(main) -> void:
	var visible := {}
	for cell_variant in main.floor_data["tiles"]:
		var cell: Vector2i = cell_variant
		if main.floor_data["tiles"][cell] != "void":
			visible[cell] = true
	main.floor_data["visible_cells"] = visible.duplicate(true)
	main.floor_data["explored_cells"] = visible.duplicate(true)
	main.floor_data["observed_cells"] = visible.duplicate(true)


func _enemy(uid: String, position: Vector2i, hp: int) -> Dictionary:
	var rules: Dictionary = GameRules.ENEMIES["grave_rat"]
	return {
		"uid": uid, "id": "grave_rat", "pos": position, "hp": hp, "max_hp": hp,
		"damage": int(rules["damage"]), "accuracy": -100, "dodge": 100,
		"vision": int(rules["vision"]), "souls": int(rules["souls"]),
	}


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		failures.append(failure_message)
