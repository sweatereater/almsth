class_name RangedCombatTestSuite
extends RefCounted

const Combat := preload("res://scripts/game/combat_system.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const Loc := preload("res://scripts/localization/localization.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	_test_weapon_rules_and_save()
	_test_combat_primitives()
	await _test_player_targeting_turns_and_fallback(tree)
	await _test_ranged_boss_reward(tree)
	await _test_skeletal_archer_ai(tree)
	await _test_trace_lifecycle_and_ui(tree)
	return failures


func _test_weapon_rules_and_save() -> void:
	var bow_rules: Dictionary = GameRules.EQUIPMENT["bone_bow"]
	_expect(
		GameRules.weapon_type("bone_bow@0") == "ranged"
		and GameRules.weapon_range("bone_bow@3") == 5
		and GameRules.weapon_type("bone_knife@0") == "melee"
		and int(bow_rules.get("damage", -1)) == 0
		and int(bow_rules.get("ranged_damage", 0)) == 1
		and int(bow_rules.get("accuracy", -1)) == 0
		and bow_rules.get("salvage", {}) == {"wood": 2, "cloth": 1},
		"Bone Bow must be a range-five ranged weapon with exact base and salvage rules",
	)
	_expect(
		not bow_rules.has("ammo") and not bow_rules.has("arrows") and not bow_rules.has("reload"),
		"Bow rules must not introduce ammunition or reload state",
	)
	var attributes := GameRules.default_attributes()
	var bow_zero := GameRules.calculate_derived_stats(
		attributes, "skeleton", {"right_hand": "bone_bow@0"},
	)
	var bow_three := GameRules.calculate_derived_stats(
		attributes, "skeleton", {"right_hand": "bone_bow@3"},
	)
	var knife_zero := GameRules.calculate_derived_stats(
		attributes, "skeleton", {"right_hand": "bone_knife@0"},
	)
	var knife_three := GameRules.calculate_derived_stats(
		attributes, "skeleton", {"right_hand": "bone_knife@3"},
	)
	_expect(
		int(bow_three["ranged_damage"]) == int(bow_zero["ranged_damage"]) + 3
		and int(bow_three["accuracy"]) == int(bow_zero["accuracy"]) + 3
		and int(bow_three["damage"]) == int(bow_zero["damage"])
		and int(knife_three["damage"]) == int(knife_zero["damage"]) + 3
		and int(knife_three["ranged_damage"]) == int(knife_zero["ranged_damage"]),
		"Weapon upgrades must improve only the matching melee or ranged damage plus accuracy",
	)

	var original := RunState.new()
	original.character_name = "Bow save"
	original.loadout["right_hand"] = "bone_bow@2"
	original.add_item("bone_bow", 3, 2)
	var saved := original.to_save_data()
	var restored := RunState.new()
	_expect(
		not saved.has("ammo")
		and restored.restore_save_data(saved)
		and restored.loadout.get("right_hand", "") == "bone_bow@2"
		and int(restored.inventory.get("bone_bow@3", 0)) == 2
		and restored.has_ranged_weapon()
		and restored.get_ranged_range() == 5,
		"Equipped and stacked upgraded bows must round-trip without new save fields",
	)
	_expect(
		GameRules.enemy_pool(94).has("skeletal_archer")
		and not GameRules.enemy_pool(95).has("skeletal_archer")
		and GameRules.enemy_pool(80).has("skeletal_archer")
		and Renderer.ENEMY_SPRITES.get("skeletal_archer") != null,
		"Skeletal Archer must enter the procedural pool at depth six with its own sprite",
	)


func _test_combat_primitives() -> void:
	var tiles := _open_tiles(10, 7)
	var origin := Vector2i(2, 3)
	_expect(
		Combat.is_ranged_target_valid(tiles, origin, Vector2i(7, 3), 5)
		and not Combat.is_ranged_target_valid(tiles, origin, Vector2i(8, 3), 5),
		"Ranged target validation must accept Manhattan range five and reject range six",
	)
	tiles[Vector2i(4, 3)] = "wall"
	_expect(
		not Combat.is_ranged_target_valid(tiles, origin, Vector2i(7, 3), 5),
		"A wall must block a ranged line",
	)
	tiles[Vector2i(4, 3)] = "boss_door_closed"
	_expect(
		not Combat.is_ranged_target_valid(tiles, origin, Vector2i(7, 3), 5),
		"A closed boss door must block a ranged line",
	)
	var equality := Combat.resolve_attack(8, 3, 1)
	var miss := Combat.resolve_attack(7, 3, 1)
	_expect(
		bool(equality["hit"])
		and int(equality["attack_total"]) == 11
		and int(equality["defense_target"]) == 11
		and not bool(miss["hit"]),
		"Shared attack rolls must hit on equality and miss one point below defense",
	)


func _test_player_targeting_turns_and_fallback(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.state.loadout["right_hand"] = "bone_bow@0"
	main.floor_data = _floor_fixture(12, 9)
	main.player_pos = Vector2i(3, 4)
	_reveal_floor(main)
	var near_enemy := _enemy("near", Vector2i(5, 4), 40, "hollow_guard")
	var selected_enemy := _enemy("selected", Vector2i(7, 4), 40, "hollow_guard")
	near_enemy["vision"] = 0
	selected_enemy["vision"] = 0
	selected_enemy["dodge"] = -100
	main.floor_data["enemies"] = [near_enemy, selected_enemy]
	main.inspected_target = {
		"kind": "enemy", "uid": "selected", "entity": selected_enemy,
	}
	var ranged_damage: int = main.state.get_ranged_damage()
	var turns_before: int = main.state.total_turns
	var attack_event := InputEventKey.new()
	attack_event.pressed = true
	attack_event.keycode = KEY_F
	attack_event.physical_keycode = KEY_F
	main.get_viewport().push_input(attack_event, true)
	await tree.process_frame
	_expect(
		int(main.floor_data["enemies"][0]["hp"]) == 40
		and int(main.floor_data["enemies"][1]["hp"]) == 40 - ranged_damage
		and main.state.total_turns == turns_before + 1
		and main.projectile_traces.size() == 1,
		"A manually selected valid enemy must override a nearer target and spend exactly one turn",
	)
	main.floor_data["enemies"][1]["dodge"] = 100
	var miss_turn: int = main.state.total_turns
	var miss_target_hp := int(main.floor_data["enemies"][1]["hp"])
	_expect(
		main._activate_ability_slot("attack", {"attack_rolls": [1]})
		and main.state.total_turns == miss_turn + 1
		and int(main.floor_data["enemies"][1]["hp"]) == miss_target_hp,
		"A player ranged miss must still spend exactly one turn without applying damage",
	)

	main.floor_data["enemies"] = [
		_enemy("fallback", Vector2i(5, 4), 40, "hollow_guard"),
		_enemy("invalid_selected", Vector2i(9, 4), 40, "hollow_guard"),
	]
	for enemy in main.floor_data["enemies"]:
		enemy["vision"] = 0
	main.inspected_target = {
		"kind": "enemy", "uid": "invalid_selected",
		"entity": main.floor_data["enemies"][1],
	}
	var invalid_turn: int = main.state.total_turns
	_expect(
		not main._activate_ability_slot("attack", {"attack_rolls": [20]})
		and main.state.total_turns == invalid_turn
		and int(main.floor_data["enemies"][0]["hp"]) == 40,
		"An invalid selected ranged target must never be replaced or consume a turn",
	)
	main.floor_data["enemies"][1]["pos"] = Vector2i(7, 4)
	main.floor_data["visible_cells"].erase(Vector2i(7, 4))
	var hidden_selected_turn: int = main.state.total_turns
	_expect(
		not main._activate_ability_slot("attack", {"attack_rolls": [20]})
		and main.state.total_turns == hidden_selected_turn
		and int(main.floor_data["enemies"][0]["hp"]) == 40,
		"A hidden selected target must not be replaced by a visible fallback or spend a turn",
	)
	main.floor_data["visible_cells"][Vector2i(7, 4)] = true
	main.floor_data["tiles"][Vector2i(5, 4)] = "wall"
	main.inspected_target = {
		"kind": "enemy", "uid": "invalid_selected",
		"entity": main.floor_data["enemies"][1],
	}
	var blocked_selected_turn: int = main.state.total_turns
	_expect(
		not main._activate_ability_slot("attack", {"attack_rolls": [20]})
		and main.state.total_turns == blocked_selected_turn,
		"A selected target behind a wall must not consume a turn",
	)
	main.floor_data["tiles"][Vector2i(5, 4)] = "floor"
	main.floor_data["enemies"].clear()
	main.inspected_target.clear()
	var no_target_turn: int = main.state.total_turns
	_expect(
		not main._activate_ability_slot("attack", {"attack_rolls": [20]})
		and main.state.total_turns == no_target_turn,
		"A shot without any valid target must consume zero turns",
	)

	_reveal_floor(main)
	main.floor_data["enemies"] = [
		_enemy("lower", Vector2i(3, 6), 40, "hollow_guard"),
		_enemy("upper", Vector2i(3, 2), 40, "hollow_guard"),
	]
	var stable_target: Dictionary = main._resolve_ranged_target("")
	_expect(
		bool(stable_target.get("ok", false))
		and String(main.floor_data["enemies"][int(stable_target["enemy_index"])]["uid"]) == "upper",
		"Automatic ranged targeting must use a stable position tie-break",
	)

	main.floor_data["enemies"] = [_enemy("adjacent", Vector2i(4, 4), 40, "hollow_guard")]
	main.floor_data["enemies"][0]["vision"] = 0
	main.floor_data["enemies"][0]["dodge"] = -100
	main.inspected_target.clear()
	main.projectile_traces.clear()
	var adjacent_turn: int = main.state.total_turns
	var adjacent_hp := int(main.floor_data["enemies"][0]["hp"])
	main._attempt_player_action(Vector2i.RIGHT)
	_expect(
		main.player_pos == Vector2i(3, 4)
		and int(main.floor_data["enemies"][0]["hp"]) == adjacent_hp - ranged_damage
		and main.state.total_turns == adjacent_turn + 1,
		"Movement into an adjacent enemy with a bow must shoot once without moving",
	)

	main.state.current_form_id = "almost_human"
	main.state.absorbed_souls = int(GameRules.FORMS["almost_human"]["threshold"])
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
	main.state.skill_levels["almost_double_strike"] = 11
	main.state.skill_levels["circular_attack"] = 1
	main.state.ability_loadout["attack"] = "circular_attack"
	main.state.hp = main.state.get_max_hp()
	main.floor_data["enemies"] = [_enemy("passive", Vector2i(6, 4), 80, "hollow_guard")]
	main.floor_data["enemies"][0]["vision"] = 0
	main.inspected_target = {
		"kind": "enemy", "uid": "passive", "entity": main.floor_data["enemies"][0],
	}
	var almost_damage: int = main.state.get_ranged_damage()
	var passive_hp := int(main.floor_data["enemies"][0]["hp"])
	main._activate_ability_slot("attack", {
		"attack_rolls": [20, 20], "passive_roll": 0.0,
	})
	_expect(
		int(main.floor_data["enemies"][0]["hp"]) == passive_hp - almost_damage
		and main.state.get_slotted_ability("attack") == "circular_attack"
		and main._effective_attack_ability() == "basic_attack",
		"A bow must safely fall back to one Basic Shot without passive repeats or loadout loss",
	)
	main.state.loadout["right_hand"] = "bone_knife@0"
	_expect(
		main._effective_attack_ability() == "circular_attack",
		"The assigned physical attack must return immediately after equipping a melee weapon",
	)
	main.state.current_form_id = "skeleton"
	main.state.absorbed_souls = 0
	main.state.ability_loadout["attack"] = "basic_attack"
	main.floor_data["enemies"] = [_enemy("melee", Vector2i(4, 4), 40, "hollow_guard")]
	main.floor_data["enemies"][0]["vision"] = 0
	var melee_damage: int = main.state.get_damage()
	var melee_hp := int(main.floor_data["enemies"][0]["hp"])
	main._activate_ability_slot("attack", {"target_uid": "melee", "attack_rolls": [20]})
	_expect(
		int(main.floor_data["enemies"][0]["hp"]) == melee_hp - melee_damage,
		"Legacy melee Basic Attack must retain its original damage path",
	)
	main.queue_free()
	await tree.process_frame


func _test_ranged_boss_reward(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.state.loadout["right_hand"] = "bone_bow@0"
	main.state.attributes["perception"] = 20
	main.floor_data = _floor_fixture(12, 9)
	main.player_pos = Vector2i(3, 4)
	var door := Vector2i(9, 2)
	main.floor_data["tiles"][door] = "boss_door_closed"
	main.floor_data["boss_uid"] = "boss"
	main.floor_data["boss_door"] = door
	main.floor_data["boss_door_open"] = false
	main.floor_data["boss_defeated"] = false
	var boss := _enemy("boss", Vector2i(7, 4), 1, "minotaur")
	boss["vision"] = 0
	main.floor_data["enemies"] = [boss]
	_reveal_floor(main)
	main.inspected_target = {"kind": "enemy", "uid": "boss", "entity": boss}
	var souls_before: int = main.state.carried_souls
	var turn_before: int = main.state.total_turns
	_expect(
		main._activate_ability_slot("attack", {"attack_rolls": [20]})
		and main.floor_data["enemies"].is_empty()
		and bool(main.floor_data["boss_door_open"])
		and main.floor_data["tiles"][door] == "floor"
		and main.state.carried_souls == souls_before + 12
		and main.state.total_turns == turn_before + 1,
		"A ranged Minotaur kill must reward once, open the boss door and spend one turn",
	)
	main._damage_enemy_by_uid("boss", 999)
	_expect(
		main.state.carried_souls == souls_before + 12,
		"A removed ranged target must never grant its reward twice",
	)
	main.queue_free()
	await tree.process_frame


func _test_skeletal_archer_ai(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.floor_data = _floor_fixture(12, 9)
	main.player_pos = Vector2i(3, 4)
	_reveal_floor(main)
	main.state.current_form_id = "almost_human"
	main.state.absorbed_souls = int(GameRules.FORMS["almost_human"]["threshold"])
	main.state.hp = main.state.get_max_hp()

	for archer_x in [4, 8]:
		main.projectile_traces.clear()
		main.state.hp = main.state.get_max_hp()
		var archer := _enemy("archer_%d" % archer_x, Vector2i(archer_x, 4), 4, "skeletal_archer")
		archer["accuracy"] = 100
		main.floor_data["enemies"] = [archer]
		var hp_before: int = main.state.hp
		main._enemy_turn()
		_expect(
			main.floor_data["enemies"][0]["pos"] == Vector2i(archer_x, 4)
			and main.state.hp == hp_before - 1
			and main.projectile_traces.size() == 1,
			"A Skeletal Archer at range %d must shoot once without moving" % (archer_x - 3),
		)

	main.projectile_traces.clear()
	main.state.hp = main.state.get_max_hp()
	var distant := _enemy("range_six", Vector2i(9, 4), 4, "skeletal_archer")
	distant["accuracy"] = 100
	main.floor_data["enemies"] = [distant]
	var distant_hp: int = main.state.hp
	main._enemy_turn()
	_expect(
		main.floor_data["enemies"][0]["pos"] == Vector2i(8, 4)
		and main.state.hp == distant_hp
		and main.projectile_traces.is_empty(),
		"An archer at range six must pursue instead of moving and shooting",
	)

	main.floor_data = _floor_fixture(12, 9)
	main.player_pos = Vector2i(3, 4)
	_reveal_floor(main)
	main.floor_data["tiles"][Vector2i(5, 4)] = "wall"
	var blocked := _enemy("blocked", Vector2i(8, 4), 4, "skeletal_archer")
	blocked["accuracy"] = 100
	main.floor_data["enemies"] = [blocked]
	var blocked_hp: int = main.state.hp
	main._enemy_turn()
	_expect(
		main.state.hp == blocked_hp and main.projectile_traces.is_empty(),
		"A wall must prevent an archer shot",
	)

	main.floor_data = _floor_fixture(12, 9)
	main.player_pos = Vector2i(3, 4)
	_reveal_floor(main)
	var miss_archer := _enemy("miss", Vector2i(8, 4), 4, "skeletal_archer")
	miss_archer["accuracy"] = -100
	main.floor_data["enemies"] = [miss_archer]
	main.projectile_traces.clear()
	var miss_hp: int = main.state.hp
	main._enemy_turn()
	_expect(
		main.state.hp == miss_hp and main.projectile_traces.size() == 1,
		"An archer miss must still consume its action and create a visible trace",
	)

	main.floor_data = _floor_fixture(12, 9)
	main.player_pos = Vector2i(3, 4)
	main.floor_data["visible_cells"] = {main.player_pos: true}
	main.floor_data["explored_cells"] = {main.player_pos: true}
	main.floor_data["observed_cells"] = {main.player_pos: true}
	var hidden := _enemy("hidden", Vector2i(8, 4), 4, "skeletal_archer")
	hidden["accuracy"] = 100
	main.floor_data["enemies"] = [hidden]
	main.projectile_traces.clear()
	main.auto_explore_active = true
	main.auto_travel_active = true
	var hidden_hp: int = main.state.hp
	main._enemy_turn()
	_expect(
		main.state.hp == hidden_hp - 1
		and main.projectile_traces.is_empty()
		and not main.floor_data["visible_cells"].has(hidden["pos"])
		and not main.auto_explore_active
		and not main.auto_travel_active,
		"A hidden shooter must interrupt exploration without a trace or fog information leak",
	)

	main.state.hp = main.state.get_max_hp()
	hidden["accuracy"] = -100
	main.floor_data["enemies"] = [hidden]
	main.wait_turn_count = 10
	var wait_turn: int = main.state.total_turns
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == wait_turn + 1,
		"Long waiting must stop after the first incoming ranged attack, including a miss",
	)
	main.queue_free()
	await tree.process_frame


func _test_trace_lifecycle_and_ui(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.floor_data = _floor_fixture(12, 9)
	main.player_pos = Vector2i(3, 4)
	_reveal_floor(main)
	main._add_magic_trace(Vector2i(3, 4), Vector2i(5, 4))
	main._add_projectile_trace(Vector2i(3, 4), Vector2i(8, 4))
	var original_remaining := float(main.projectile_traces[0]["remaining"])
	main._update_projectile_traces(0.20)
	_expect(
		main.projectile_traces.size() == 1
		and float(main.projectile_traces[0]["remaining"]) < original_remaining
		and main.magic_traces.size() == 1,
		"Projectile traces must advance independently while magic traces coexist",
	)
	main._update_projectile_traces(0.30)
	_expect(
		main.projectile_traces.is_empty() and main.magic_traces.size() == 1,
		"Projectile traces must expire after approximately 0.45 seconds",
	)

	main.state.loadout["right_hand"] = "bone_bow@2"
	main.state.add_item("bone_bow", 2)
	main.selected_inventory_key = "bone_bow@2"
	main.selected_equipment_slot = ""
	main.character_panel_mode = "inventory"
	main.previous_screen = main.Screen.BASE
	main.screen = main.Screen.CHARACTER
	var required_locale_keys := [
		"ITEM_BONE_BOW", "ENEMY_SKELETAL_ARCHER", "GLYPH_SKELETAL_ARCHER",
		"PARAM_RANGED_RANGE", "INVENTORY_RANGED_ITEM_DETAIL", "ABILITY_BASIC_SHOT",
		"MSG_PLAYER_RANGED_HIT", "MSG_ENEMY_RANGED_HIT", "MSG_HIDDEN_RANGED_HIT",
	]
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		main._apply_locale()
		main._refresh_character_sheet()
		main._refresh_hotbar()
		await tree.process_frame
		_expect(
			main.inventory_detail_label.text.contains(Loc.text("PARAM_RANGED_DAMAGE"))
			or main.inventory_detail_label.text.contains(
				"Дальний урон" if locale == "ru" else "Ranged damage"
			),
			"Bow inventory details must show ranged damage in %s" % locale,
		)
		_expect(
			main.inventory_detail_label.text.contains("5")
			and main.character_derived_label.text.contains(Loc.text("PARAM_RANGED_RANGE"))
			and main.attack_button.text.contains(Loc.text("ABILITY_BASIC_SHOT")),
			"Character and hotbar UI must show bow range and contextual Basic Shot in %s" % locale,
		)
		for key in required_locale_keys:
			_expect(
				Loc.STRINGS[locale].has(key),
				"Ranged localization key %s must exist in %s" % [key, locale],
			)
		for skill_id in [
			"magic_awakening", "magic_missile", "magic_missile_range", "magic_ricochet",
		]:
			var skill_button: Button = main.skill_node_buttons[skill_id]
			_expect(
				skill_button.position.y + skill_button.size.y
				<= Renderer.CHARACTER_SKILLS_CARD.end.y,
				"Lower skill node %s must stay inside the skills card in %s" % [
					skill_id, locale,
				],
			)
	Loc.set_locale("ru")
	main._add_projectile_trace(Vector2i(1, 1), Vector2i(2, 1))
	main._load_floor(99)
	_expect(main.projectile_traces.is_empty(), "Changing floor must clear projectile traces")
	main._add_projectile_trace(Vector2i(1, 1), Vector2i(2, 1))
	main._handle_death()
	_expect(main.projectile_traces.is_empty(), "Death must clear projectile traces")
	main.projectile_traces.append({
		"from": Vector2i(1, 1), "to": Vector2i(2, 1), "remaining": 0.4,
	})
	main._show_base("base")
	_expect(main.projectile_traces.is_empty(), "Returning to base must clear projectile traces")
	main.queue_free()
	await tree.process_frame


func _new_main(tree: SceneTree):
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	main.persistence_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.screen = main.Screen.DUNGEON
	main.state = RunState.new()
	return main


func _floor_fixture(width := 10, height := 8) -> Dictionary:
	return {
		"width": width,
		"height": height,
		"tiles": _open_tiles(width, height),
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


func _open_tiles(width: int, height: int) -> Dictionary:
	var tiles := {}
	for y in range(height):
		for x in range(width):
			tiles[Vector2i(x, y)] = (
				"floor" if x > 0 and x < width - 1 and y > 0 and y < height - 1 else "wall"
			)
	return tiles


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
		"has_seen_player": true, # These fixtures exercise attacks and pursuit.
		"souls": int(rules["souls"]),
		"attack_type": String(rules.get("attack_type", "melee")),
		"range": int(rules.get("range", 1)),
	}


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		failures.append(failure_message)
