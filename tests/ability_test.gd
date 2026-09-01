class_name AbilityTestSuite
extends RefCounted

const AbilitySystem := preload("res://scripts/game/skill_system.gd")
const CombatSystem := preload("res://scripts/game/combat_system.gd")
const GridNavigation := preload("res://scripts/world/grid_navigation.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	_test_registry_progression_and_chances()
	_test_save_migration_and_sanitation()
	_test_dash_geometry()
	await _test_dash_targeting_and_commit(tree)
	await _test_attack_dispatch_and_multi_hit_rewards(tree)
	await _test_passive_attack_thresholds(tree)
	await _test_circular_attack_and_boss_reward(tree)
	await _test_minotaur_dash(tree)
	await _test_magic_dispatch_and_ui_contracts(tree)
	return failures


func _test_registry_progression_and_chances() -> void:
	for ability_id in [
		"basic_attack", "magic_missile", "dash", "double_attack", "circular_attack",
	]:
		_expect(AbilitySystem.ABILITIES.has(ability_id), "Ability registry must contain %s" % ability_id)
	_expect(
		AbilitySystem.slot_accepts("attack", "double_attack")
		and AbilitySystem.slot_accepts("attack", "circular_attack")
		and not AbilitySystem.slot_accepts("active_1", "double_attack")
		and AbilitySystem.slot_accepts("active_1", "dash"),
		"Attack and utility abilities must be restricted to compatible loadout slots",
	)
	var boss_floor := FixedFloor90.create()
	_expect(
		GameRules.ENEMIES["minotaur"].get("abilities", []).has("dash")
		and boss_floor["enemies"][0].get("abilities", []).has("dash"),
		"Minotaur rules and the fixed-floor entity must reference the shared Dash id",
	)
	var progression := RunState.new()
	progression.banked_souls = 5000
	_expect(
		progression.purchase_skill("dash")["reason"] == "stage_locked",
		"Dash must remain locked before ghoul is unlocked",
	)
	progression.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	_expect(
		progression.purchase_skill("dash") == {"ok": true, "level": 1, "cost": 50}
		and progression.purchase_skill("double_attack") == {"ok": true, "level": 1, "cost": 75},
		"Ghoul active abilities must use their exact one-time costs",
	)
	progression.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
	for expected_level in range(1, 12):
		var result := progression.purchase_skill("almost_double_strike")
		_expect(
			bool(result.get("ok", false))
			and int(result["level"]) == expected_level
			and int(result["cost"]) == 50 + (expected_level - 1) * 10,
			"Almost-human passive level %d must use the 50 + 10/level cost" % expected_level,
		)
	_expect(
		progression.purchase_skill("almost_double_strike")["reason"] == "max_level",
		"Almost-human repeat strike must stop at level eleven",
	)
	_expect(
		is_equal_approx(AbilitySystem.almost_double_strike_chance(1), 0.10)
		and AbilitySystem.chance_succeeds(0.099, 0.10)
		and not AbilitySystem.chance_succeeds(0.10, 0.10)
		and is_equal_approx(AbilitySystem.almost_double_strike_chance(11), 0.30)
		and AbilitySystem.chance_succeeds(0.299, 0.30)
		and not AbilitySystem.chance_succeeds(0.30, 0.30),
		"Repeat-strike chance must use strict roll < chance at levels 1 and 11",
	)


func _test_save_migration_and_sanitation() -> void:
	var old_save := {
		"character_name": "Old",
		"attributes": GameRules.default_attributes(),
		"absorbed_souls": 0,
		"highest_unlocked_form_index": GameRules.FORM_ORDER.find("ghoul"),
		"skill_levels": {"magic_missile": 1, "dash": 1, "double_attack": 1},
	}
	var migrated := RunState.new()
	_expect(migrated.restore_save_data(old_save), "A pre-loadout save must still restore")
	_expect(
		migrated.get_slotted_ability("attack") == "basic_attack"
		and migrated.get_slotted_ability("active_1") == "magic_missile",
		"A missing loadout must migrate to safe attack and learned legacy missile defaults",
	)
	var new_save: Dictionary = migrated.to_save_data()
	new_save["ability_loadout"] = {
		"attack": "double_attack",
		"active_1": "dash",
		"active_2": "dash",
		"active_3": "almost_double_strike",
	}
	var sanitized := RunState.new()
	_expect(sanitized.restore_save_data(new_save), "A current loadout save must restore")
	_expect(
		sanitized.get_slotted_ability("attack") == "double_attack"
		and sanitized.get_slotted_ability("active_1") == "dash"
		and sanitized.get_slotted_ability("active_2").is_empty()
		and sanitized.get_slotted_ability("active_3").is_empty(),
		"Duplicate, passive and incompatible saved assignments must be sanitized",
	)
	var roundtrip := RunState.new()
	_expect(
		roundtrip.restore_save_data(sanitized.to_save_data())
		and roundtrip.ability_loadout == sanitized.ability_loadout,
		"A sanitized four-slot loadout must survive a save round-trip",
	)
	sanitized.die()
	_expect(
		sanitized.get_slotted_ability("attack") == "double_attack"
		and sanitized.get_slotted_ability("active_1") == "dash"
		and sanitized.current_form_id == "skeleton",
		"Death must preserve learned abilities and assignments while resetting the body",
	)


func _test_dash_geometry() -> void:
	var open_tiles := {}
	var open_known := {}
	for y in range(7):
		for x in range(7):
			var open_cell := Vector2i(x, y)
			open_tiles[open_cell] = "floor"
			open_known[open_cell] = true
	var open_origin := Vector2i(3, 3)
	var partition := AbilitySystem.dash_partition(
		open_tiles, open_origin, open_known, open_known, {}, 3,
	)
	var all_targets: Array = partition["valid"]
	_expect(
		all_targets.size() == 48
		and all_targets.has(Vector2i(5, 4))
		and all_targets.has(Vector2i(6, 5))
		and all_targets.has(Vector2i(6, 6)),
		"Player Dash must expose all 48 Chebyshev-radius cells, including off-axis targets",
	)
	var occupied_partition := AbilitySystem.dash_partition(
		open_tiles, open_origin, open_known, open_known, {Vector2i(4, 3): true}, 3,
	)
	_expect(
		String(occupied_partition["invalid"].get(Vector2i(4, 3), "")) == "occupied_endpoint"
		and String(occupied_partition["invalid"].get(Vector2i(6, 3), "")) == "occupied_path",
		"A creature must invalidate both its Dash endpoint and every path crossing it",
	)
	var hidden_known := open_known.duplicate()
	var hidden_visible := open_known.duplicate()
	hidden_visible.erase(Vector2i(5, 4))
	var hidden_partition := AbilitySystem.dash_partition(
		open_tiles, open_origin, hidden_known, hidden_visible, {}, 3,
	)
	_expect(
		String(hidden_partition["invalid"].get(Vector2i(5, 4), "")) == "hidden"
		and not hidden_partition["valid"].has(Vector2i(5, 4)),
		"Known but currently hidden Dash cells must be invalid without revealing geometry",
	)
	var unexplored := open_known.duplicate()
	unexplored.erase(Vector2i(5, 4))
	var unexplored_partition := AbilitySystem.dash_partition(
		open_tiles, open_origin, unexplored, open_known, {}, 3,
	)
	_expect(
		not unexplored_partition["valid"].has(Vector2i(5, 4))
		and not unexplored_partition["invalid"].has(Vector2i(5, 4)),
		"Unexplored Dash cells must be omitted from both render partitions",
	)
	_expect(
		not GridNavigation.has_clear_line(
			open_tiles, Vector2i(1, 3), Vector2i(5, 3), {Vector2i(3, 3): true},
		)
		and CombatSystem.is_ranged_target_valid(
			open_tiles, Vector2i(1, 3), Vector2i(5, 3), 5,
		),
		"Shared LOS must let Dash block creatures without changing arrows-through-creatures balance",
	)
	var tiles := {}
	var explored := {}
	for y in range(5):
		for x in range(9):
			var cell := Vector2i(x, y)
			tiles[cell] = "floor" if x > 0 and x < 8 and y > 0 and y < 4 else "wall"
			if tiles[cell] == "floor":
				explored[cell] = true
	var origin := Vector2i(4, 2)
	var clear := AbilitySystem.dash_targets_in_direction(
		tiles, origin, Vector2i.RIGHT, explored, {},
	)
	_expect(
		clear == [Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2)],
		"Dash geometry must expose exact one-, two- and three-cell endpoints",
	)
	_expect(
		AbilitySystem.dash_targets_in_direction(
			tiles, origin, Vector2i.RIGHT, explored, {Vector2i(6, 2): true},
		) == [Vector2i(5, 2)],
		"A creature must block its cell and every Dash endpoint beyond it",
	)
	tiles[Vector2i(6, 2)] = "boss_door_closed"
	_expect(
		AbilitySystem.dash_targets_in_direction(
			tiles, origin, Vector2i.RIGHT, explored, {},
		) == [Vector2i(5, 2)],
		"A closed boss door must block Dash like every non-floor tile",
	)
	tiles[Vector2i(6, 2)] = "floor"
	explored.erase(Vector2i(6, 2))
	_expect(
		AbilitySystem.dash_targets_in_direction(
			tiles, origin, Vector2i.RIGHT, explored, {},
		) == [Vector2i(5, 2)],
		"Player Dash must never cross an unexplored intermediate cell",
	)

	var diagonal_tiles := {}
	var diagonal_explored := {}
	for y in range(9):
		for x in range(9):
			var diagonal_cell := Vector2i(x, y)
			diagonal_tiles[diagonal_cell] = (
				"floor" if x > 0 and x < 8 and y > 0 and y < 8 else "wall"
			)
			if diagonal_tiles[diagonal_cell] == "floor":
				diagonal_explored[diagonal_cell] = true
	var diagonal_origin := Vector2i(4, 4)
	_expect(
		AbilitySystem.dash_targets_in_direction(
			diagonal_tiles, diagonal_origin, Vector2i(1, -1), diagonal_explored, {},
		) == [Vector2i(5, 3), Vector2i(6, 2), Vector2i(7, 1)]
		and AbilitySystem.direction_to_straight_endpoint(
			diagonal_origin, Vector2i(7, 1),
		) == Vector2i(1, -1)
		and AbilitySystem.dash_distance(diagonal_origin, Vector2i(7, 1)) == 3,
		"Dash geometry must expose one-, two- and three-cell diagonal endpoints",
	)
	_expect(
		AbilitySystem.dash_targets_in_direction(
			diagonal_tiles,
			diagonal_origin,
			Vector2i(1, -1),
			diagonal_explored,
			{Vector2i(6, 2): true},
		) == [Vector2i(5, 3)],
		"A creature on a diagonal must block that endpoint and everything beyond it",
	)
	diagonal_tiles[Vector2i(5, 4)] = "wall"
	_expect(
		AbilitySystem.dash_targets_in_direction(
			diagonal_tiles, diagonal_origin, Vector2i(1, -1), diagonal_explored, {},
		).is_empty(),
		"A diagonal Dash must not cut through a blocked corner",
	)


func _test_dash_targeting_and_commit(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	_configure_form(main, "ghoul")
	main.state.skill_levels["dash"] = 1
	main.state.assign_ability("active_1", "dash")
	main.floor_data = _floor_fixture(9, 7)
	main.player_pos = Vector2i(4, 3)
	_reveal_floor(main)
	var turns_before: int = main.state.total_turns
	_expect(
		not main._activate_ability_slot("active_1")
		and main.ability_targeting_id == "dash"
		and main.state.total_turns == turns_before,
		"Entering Dash targeting must consume zero turns",
	)
	main._cancel_ability_targeting()
	_expect(
		main.ability_targeting_id.is_empty() and main.state.total_turns == turns_before,
		"Cancelling Dash targeting must consume zero turns",
	)
	main._activate_ability_slot("active_1")
	var initial_cursor: Vector2i = main.ability_target_cursor
	await _push_key(main, tree, KEY_D)
	var keyboard_cursor: Vector2i = main.ability_target_cursor
	await _push_joypad_button(main, tree, JOY_BUTTON_DPAD_UP)
	_expect(
		keyboard_cursor.x > initial_cursor.x
		and main.ability_target_cursor.y < keyboard_cursor.y
		and main.ability_target_cells.has(main.ability_target_cursor),
		"Keyboard and gamepad directions must move spatially among legal Dash cells",
	)
	var target := Vector2i(7, 3)
	main.floor_data["items"] = [{
		"uid": "dash_chest", "id": "bone_knife", "pos": target, "wood": 0, "stone": 0,
	}]
	main.player_map_presentation.activate("female", "ghoul")
	main.player_map_presentation.begin_step(Vector2i.LEFT, 0.2)
	_expect(
		main._confirm_dash(target)
		and main.player_pos == target
		and main.state.total_turns == turns_before + 1
		and main.state.inventory.has(GameRules.make_item_key("bone_knife"))
		and not main.player_map_presentation.moving
		and main.player_map_presentation.visual().offset_cells == Vector2.ZERO,
		"Confirming a three-cell Dash must reset unfinished walk presentation, spend one turn and collect only its endpoint chest",
	)
	var diagonal_turns: int = main.state.total_turns
	main._begin_dash_targeting()
	_expect(
		main._confirm_dash(Vector2i(5, 1))
		and main.player_pos == Vector2i(5, 1)
		and main.state.total_turns == diagonal_turns + 1,
		"Mouse/touch target confirmation must commit a legal off-axis Dash in one turn",
	)
	main.queue_free()
	await tree.process_frame


func _test_attack_dispatch_and_multi_hit_rewards(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	_configure_form(main, "ghoul")
	main.state.attributes["perception"] = 100
	main.state.skill_levels["double_attack"] = 1
	main.state.assign_ability("attack", "double_attack")
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(3, 3)
	main.floor_data["enemies"] = [_enemy("move_target", Vector2i(4, 3), 3, "grave_rat")]
	_reveal_floor(main)
	var turns_before: int = main.state.total_turns
	main.player_map_presentation.activate("female", "ghoul")
	main.player_map_presentation.begin_step(Vector2i.LEFT, 0.2)
	main._attempt_player_action(Vector2i.RIGHT)
	_expect(
		main.floor_data["enemies"].is_empty()
		and main.state.carried_souls == 1
		and main.state.food == 1
		and not main.message.contains(Loc.text("MSG_FOOD_GAINED", [1]))
		and main.state.total_turns == turns_before + 1
		and not main.player_map_presentation.moving
		and main.player_map_presentation.visual().offset_cells == Vector2.ZERO,
		"A melee attack must snap unfinished walk presentation while resolving one reward and turn",
	)
	main.state.ability_cooldowns.erase("double_attack")
	main.floor_data["enemies"] = [_enemy("f_target", Vector2i(4, 3), 5, "hollow_guard")]
	var f_turn: int = main.state.total_turns
	var f_event := InputEventKey.new()
	f_event.pressed = true
	f_event.keycode = KEY_F
	f_event.physical_keycode = KEY_F
	main.get_viewport().push_input(f_event, true)
	await tree.process_frame
	_expect(
		int(main.floor_data["enemies"][0]["hp"]) == 1
		and main.state.total_turns == f_turn + 1,
		"The F binding must dispatch the assigned Double Attack instead of hard-coded basic melee",
	)
	main.state.ability_cooldowns.erase("double_attack")
	main.floor_data["enemies"] = [_enemy("two_rolls", Vector2i(4, 3), 6, "hollow_guard")]
	main.floor_data["enemies"][0]["dodge"] = 95
	var second_turn: int = main.state.total_turns
	main._activate_ability_slot("attack", {
		"target_uid": "two_rolls", "attack_rolls": [1, 20],
	})
	_expect(
		int(main.floor_data["enemies"][0]["hp"]) == 4
		and main.state.total_turns == second_turn + 1,
		"Double Attack must make two independent rolls but complete one player turn",
	)
	main.state.ability_cooldowns.erase("double_attack")
	main.floor_data["enemies"] = [_enemy("single_reward", Vector2i(4, 3), 1, "grave_rat")]
	var souls_before: int = main.state.carried_souls
	main._activate_ability_slot("attack", {
		"target_uid": "single_reward", "attack_rolls": [20, 20],
	})
	_expect(
		main.state.carried_souls == souls_before + 1,
		"A lethal first Double Attack strike must not retarget or reward its second strike",
	)
	main.state.current_form_id = "skeleton"
	main.floor_data["enemies"] = [_enemy("fallback_target", Vector2i(4, 3), 5, "hollow_guard")]
	main.floor_data["enemies"][0]["damage"] = 0
	main._on_attack_pressed()
	_expect(
		int(main.floor_data["enemies"][0]["hp"]) == 4
		and main._effective_attack_ability() == "basic_attack",
		"F must safely fall back to Basic Attack when the preserved physical slot needs a later form",
	)
	main.queue_free()
	await tree.process_frame


func _test_circular_attack_and_boss_reward(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	_configure_form(main, "almost_human")
	main.state.attributes["perception"] = 100
	main.state.skill_levels["circular_attack"] = 1
	main.state.assign_ability("attack", "circular_attack")
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(3, 3)
	var enemies: Array = []
	var expected_souls := 0
	var cells := AbilitySystem.circular_target_cells(main.player_pos)
	for index in range(cells.size()):
		var enemy_id := "minotaur" if index == 0 else "grave_rat"
		var uid := "boss_circle" if index == 0 else "circle_%d" % index
		enemies.append(_enemy(uid, cells[index], 1, enemy_id))
		expected_souls += int(GameRules.ENEMIES[enemy_id]["souls"])
	main.floor_data["enemies"] = enemies
	main.floor_data["boss_uid"] = "boss_circle"
	main.floor_data["boss_door"] = Vector2i(3, 1)
	main.floor_data["boss_door_open"] = false
	main.floor_data["tiles"][Vector2i(3, 1)] = "boss_door_closed"
	_reveal_floor(main)
	var turns_before: int = main.state.total_turns
	_expect(
		main._activate_ability_slot("attack", {"attack_rolls": [20, 20, 20, 20, 20, 20, 20, 20]})
		and main.floor_data["enemies"].is_empty()
		and main.state.carried_souls == expected_souls
		and bool(main.floor_data["boss_door_open"])
		and main.floor_data["tiles"][Vector2i(3, 1)] == "floor"
		and main.state.total_turns == turns_before + 1,
		"Circular Attack must safely remove eight targets, reward each once and open a slain boss door",
	)
	var empty_turn: int = main.state.total_turns
	_expect(
		not main._activate_ability_slot("attack") and main.state.total_turns == empty_turn,
		"Circular Attack without targets must not consume a turn",
	)
	main.queue_free()
	await tree.process_frame


func _test_passive_attack_thresholds(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	_configure_form(main, "almost_human")
	main.state.attributes["perception"] = 100
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(3, 3)
	_reveal_floor(main)
	for fixture in [
		{"level": 1, "roll": 0.099, "expected_hp": 14},
		{"level": 1, "roll": 0.10, "expected_hp": 17},
		{"level": 11, "roll": 0.299, "expected_hp": 14},
		{"level": 11, "roll": 0.30, "expected_hp": 17},
	]:
		main.state.skill_levels["almost_double_strike"] = int(fixture["level"])
		main.floor_data["enemies"] = [_enemy("passive_target", Vector2i(4, 3), 20, "hollow_guard")]
		main.floor_data["enemies"][0]["damage"] = 0
		main._activate_ability_slot("attack", {
			"target_uid": "passive_target",
			"attack_rolls": [20, 20],
			"passive_roll": fixture["roll"],
		})
		_expect(
			int(main.floor_data["enemies"][0]["hp"]) == int(fixture["expected_hp"]),
			"Basic-attack passive threshold failed at level %d roll %.3f" % [
				fixture["level"], fixture["roll"],
			],
		)
	main.state.skill_levels["double_attack"] = 1
	main.state.assign_ability("attack", "double_attack")
	main.floor_data["enemies"] = [_enemy("non_recursive", Vector2i(4, 3), 20, "hollow_guard")]
	main.floor_data["enemies"][0]["damage"] = 0
	main._activate_ability_slot("attack", {
		"target_uid": "non_recursive", "attack_rolls": [20, 20, 20], "passive_roll": 0.0,
	})
	_expect(
		int(main.floor_data["enemies"][0]["hp"]) == 14,
		"Almost-human passive must not trigger after Double Attack or recurse",
	)
	main.queue_free()
	await tree.process_frame


func _test_minotaur_dash(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.floor_data = _floor_fixture(9, 7)
	main.player_pos = Vector2i(6, 3)
	main.floor_data["enemies"] = [_enemy("minotaur_dash", Vector2i(2, 3), 36, "minotaur")]
	_reveal_floor(main)
	var hp_before: int = main.state.hp
	main._enemy_turn()
	_expect(
		main.floor_data["enemies"][0]["pos"] == Vector2i(5, 3)
		and main.state.hp == hp_before,
		"A visible aligned Minotaur must Dash up to three cells and never attack in the same action",
	)
	main.floor_data = _floor_fixture(9, 9)
	main.player_pos = Vector2i(5, 5)
	main.floor_data["enemies"] = [_enemy("minotaur_diagonal", Vector2i(2, 2), 36, "minotaur")]
	_reveal_floor(main)
	hp_before = main.state.hp
	main._enemy_turn()
	_expect(
		main.floor_data["enemies"][0]["pos"] == Vector2i(4, 4)
		and main.state.hp == hp_before,
		"Minotaur must use the same diagonal Dash geometry without attacking in that turn",
	)
	main.floor_data = _floor_fixture(9, 7)
	main.player_pos = Vector2i(6, 3)
	main.floor_data["enemies"] = [
		_enemy("minotaur_blocked", Vector2i(2, 3), 36, "minotaur"),
		_enemy("blocker", Vector2i(4, 3), 20, "hollow_guard"),
	]
	main._enemy_turn()
	_expect(
		main.floor_data["enemies"][0]["pos"] != Vector2i(5, 3),
		"A blocked Minotaur Dash must fall back to normal pathfinding",
	)
	main.queue_free()
	await tree.process_frame


func _test_magic_dispatch_and_ui_contracts(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.state.skill_levels["magic_awakening"] = 1
	main.state.skill_levels["magic_missile"] = 1
	main.state.assign_ability("active_1", "magic_missile")
	main.state.mana = main.state.get_max_mana()
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(2, 3)
	main.floor_data["enemies"] = [_enemy("spell_target", Vector2i(4, 3), 10, "hollow_guard")]
	_reveal_floor(main)
	main.player_map_presentation.activate("female", "ghoul")
	main.player_map_presentation.begin_step(Vector2i.RIGHT, 0.2)
	main.player_map_presentation.update(0.04)
	_expect(
		main.player_map_presentation.moving
		and main.player_map_presentation.step_duration == 0.10
		and main.player_map_presentation.visual().offset_cells != Vector2.ZERO,
		"Magic Missile reset fixture must begin inside an active capped movement transient",
	)
	var mana_before: int = main.state.mana
	var turns_before: int = main.state.total_turns
	_expect(
		main._activate_ability_slot("active_1", {"ricochet_roll": 1.0})
		and int(main.floor_data["enemies"][0]["hp"]) == 7
		and main.state.mana == mana_before - GameRules.MAGIC_MISSILE_MANA_COST
		and main.state.total_turns == turns_before + 1
		and main.magic_traces.size() == 1,
		"Magic Missile must retain its damage, mana, visibility, trace and one-turn dispatcher contract",
	)
	_expect(
		not main.player_map_presentation.moving
		and main.player_map_presentation.visual().offset_cells == Vector2.ZERO,
		"Magic Missile must snap an unfinished map step before casting without another turn",
	)
	_expect(
		main.hotbar_ability_buttons.size() == 4
		and main.ghoul_tab_button != null
		and main.almost_human_tab_button != null,
		"Dungeon UI must expose four ability slots and both new stage tabs",
	)
	main._refresh_hotbar()
	_expect(
		main.attack_button.text.begins_with("F · ")
		and main.spell_button.text.begins_with("Q · ")
		and not main.active_2_button.text.begins_with("2 · ")
		and not main.active_3_button.text.begins_with("3 · "),
		"The hotbar must only advertise the implemented F and Q keyboard shortcuts",
	)
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	main._show_character()
	main._select_skill_stage("ghoul")
	_expect(
		main.skill_node_buttons["dash"].node_kind == "active"
		and main.skill_node_buttons["strong_bones"].node_kind == "passive"
		and main.skill_node_buttons["dash"].text.is_empty()
		and main.skill_node_buttons["strong_bones"].text.is_empty()
		and main.skill_node_buttons["dash"].display_name == Loc.text("SKILL_DASH")
		and main.skill_node_buttons["strong_bones"].display_name == Loc.text("SKILL_STRONG_BONES"),
		"Active diamonds and passive circles must be code-drawn nodes containing only icon and localized name",
	)
	for locale_key in [
		"SKILL_DASH", "SKILL_DOUBLE_ATTACK", "SKILL_ALMOST_DOUBLE_STRIKE",
		"SKILL_CIRCULAR_ATTACK", "ABILITY_SLOT_ACTIVE_3", "MSG_DASH_TARGETING",
	]:
		_expect(
			Loc.STRINGS["ru"].has(locale_key) and Loc.STRINGS["en"].has(locale_key),
			"Ability localization key %s must exist in Russian and English" % locale_key,
		)
	main.queue_free()
	await tree.process_frame


func _new_main(tree: SceneTree):
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	main.persistence_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state = RunState.new()
	# Enter through the UI lifecycle so hidden creation controls cannot consume
	# native keyboard/controller events intended for ability targeting.
	main._show_base("", "none")
	main._show_dungeon_interface()
	return main


func _configure_form(main, form_id: String) -> void:
	main.state.current_form_id = form_id
	main.state.absorbed_souls = int(GameRules.FORMS[form_id]["threshold"])
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find(form_id)
	main.state.hp = main.state.get_max_hp()
	main.state.mana = main.state.get_max_mana()


func _floor_fixture(width := 7, height := 7) -> Dictionary:
	var tiles := {}
	for y in range(height):
		for x in range(width):
			tiles[Vector2i(x, y)] = (
				"floor" if x > 0 and x < width - 1 and y > 0 and y < height - 1 else "wall"
			)
	return {
		"width": width,
		"height": height,
		"tiles": tiles,
		"start": Vector2i(2, 3),
		"base_gate": Vector2i(1, 1),
		"exit": Vector2i(width - 2, height - 2),
		"exit_known": false,
		"cradle": Vector2i(-1, -1),
		"cradle_known": false,
		"cradle_pity_resolved": true,
		"cradle_used": false,
		"items": [],
		"enemies": [],
		"visible_cells": {},
		"explored_cells": {},
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


func _enemy(uid: String, position: Vector2i, hp: int, enemy_id: String) -> Dictionary:
	var rules: Dictionary = GameRules.ENEMIES[enemy_id]
	return {
		"uid": uid,
		"id": enemy_id,
		"pos": position,
		"hp": hp,
		"max_hp": maxi(hp, int(rules["max_hp"])),
		"damage": int(rules["damage"]),
		"accuracy": int(rules["accuracy"]),
		"dodge": int(rules["dodge"]),
		"vision": int(rules["vision"]),
		"has_seen_player": true, # Combat fixtures start after the first-sight pause.
		"souls": int(rules["souls"]),
	}


func _push_key(main, tree: SceneTree, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	main.get_viewport().push_input(event, true)
	await tree.process_frame


func _push_joypad_button(main, tree: SceneTree, button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = button_index
	main.get_viewport().push_input(event, true)
	await tree.process_frame


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		failures.append(failure_message)
