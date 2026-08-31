extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const SaveSystem := preload("res://scripts/system/persistence.gd")
const InputProfile := preload("res://scripts/system/input_bindings.gd")
const GridNavigation := preload("res://scripts/world/grid_navigation.gd")
const BossFloor90 := preload("res://scripts/world/fixed_floor_90.gd")
const UiFactory := preload("res://scripts/ui/ui_factory.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")

const TEST_DIRECTORY := "res://.tmp"
const SAVE_PATH := TEST_DIRECTORY + "/regression-save.json"
const MALFORMED_SAVE_PATH := TEST_DIRECTORY + "/regression-malformed-save.json"
const CONTROLS_SETTINGS_PATH := TEST_DIRECTORY + "/regression-controls.cfg"

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	Loc.set_locale("ru")
	_test_full_state_persistence()
	_test_malformed_and_versioned_saves()
	_test_v12_to_v13_additive_ids()
	_test_input_binding_serialization_conflicts_and_reset()
	_test_grid_navigation_contracts()
	await _test_fixed_boss_floor_contracts(tree)
	_test_extracted_ui_contracts()
	_test_evolution_and_skill_boundaries()
	_test_inventory_failure_and_upgrade_boundaries()
	_test_survival_accumulators()
	_test_death_return_and_rope_invariants()
	await _test_magic_visibility_and_ricochet_boundaries(tree)
	await _test_automatic_exploration_and_visible_waiting(tree)
	Loc.set_locale("ru")
	return failures


func _test_fixed_boss_floor_contracts(tree: SceneTree) -> void:
	var first := BossFloor90.create()
	var second := BossFloor90.create()
	var door: Vector2i = first["boss_door"]
	var boss: Dictionary = first["enemies"][0]
	_expect(
		first["fixed_layout"]
		and first["width"] == 20
		and first["height"] == 14
		and first["tiles"] == second["tiles"]
		and first["start"] == second["start"]
		and first["base_gate"] == Vector2i(-1, -1)
		and boss["pos"] == second["enemies"][0]["pos"],
		"Level 90 must use one deterministic layout without a safe route to base",
	)
	_expect(
		boss["id"] == BossFloor90.BOSS_ID
		and boss["uid"] == first["boss_uid"]
		and boss["max_hp"] == 36
		and Vector2(GameRules.ENEMIES[boss["id"]].get("draw_footprint", Vector2.ONE)) == Vector2(1.5, 2.0),
		"Level 90 must contain the 36 HP oversized Minotaur on one logical position",
	)
	_expect(
		first["tiles"].get(door, "void") == BossFloor90.DOOR_TILE
		and GridNavigation.find_path(first["tiles"], first["start"], first["exit"]).is_empty()
		and not GridNavigation.find_path(first["tiles"], first["start"], boss["pos"]).is_empty(),
		"The level 90 exit must be sealed while the boss arena remains reachable",
	)

	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.screen = main.Screen.DUNGEON
	main.state = RunState.new()
	main._load_floor(BossFloor90.FLOOR_NUMBER)
	main.floor_data["enemies"][0]["hp"] = 1
	var result: Dictionary = main._apply_magic_damage(0, 1)
	_expect(
		bool(result["killed"])
		and main.floor_data["enemies"].is_empty()
		and main.floor_data["boss_defeated"]
		and main.floor_data["boss_door_open"]
		and main.floor_data["tiles"].get(door, "void") == "floor"
		and not GridNavigation.find_path(
			main.floor_data["tiles"], main.player_pos, main.floor_data["exit"]
		).is_empty(),
		"Killing the Minotaur through shared damage resolution must open the route onward",
	)

	main.state.current_floor = BossFloor90.FLOOR_NUMBER + 1
	main.player_pos = main.floor_data["exit"]
	main.floor_data["exit_known"] = true
	main._on_ascend_pressed()
	_expect(
		main.boss_warning_open
		and main.state.current_floor == BossFloor90.FLOOR_NUMBER + 1
		and main.boss_warning_description_label.text.contains(str(BossFloor90.FLOOR_NUMBER)),
		"The ascent from level 91 must pause at a localized powerful-soul warning",
	)
	main._close_boss_warning()
	_expect(
		not main.boss_warning_open
		and main.state.current_floor == BossFloor90.FLOOR_NUMBER + 1,
		"Cancelling the boss warning must leave the player on level 91",
	)
	main._on_ascend_pressed()
	main._confirm_boss_ascent()
	_expect(
		not main.boss_warning_open
		and main.state.current_floor == BossFloor90.FLOOR_NUMBER
		and bool(main.floor_data.get("fixed_layout", false)),
		"Confirming the warning must load the fixed level 90 boss arena",
	)
	main.queue_free()
	await tree.process_frame


func _test_input_binding_serialization_conflicts_and_reset() -> void:
	InputProfile.reset_to_defaults()
	var defaults := InputProfile.export_bindings().duplicate(true)

	var keyboard_event := InputEventKey.new()
	keyboard_event.pressed = true
	keyboard_event.keycode = KEY_K
	keyboard_event.ctrl_pressed = true
	var first_result := InputProfile.replace_device_binding("attack", keyboard_event)
	_expect(
		bool(first_result.get("ok", false))
		and InputProfile.get_device_events("attack", InputProfile.DEVICE_KEYBOARD).size() == 1,
		"A supported keyboard event must replace only the selected device binding",
	)
	var conflict_result := InputProfile.replace_device_binding("cast_spell", keyboard_event)
	_expect(
		not bool(conflict_result.get("ok", false))
		and String(conflict_result.get("reason", "")) == "conflict"
		and conflict_result.get("conflicts", []).has("attack"),
		"A duplicate keyboard assignment must report its conflicting action before mutation",
	)
	_expect(
		_binding_exists("attack", keyboard_event)
		and not _binding_exists("cast_spell", keyboard_event),
		"An unconfirmed conflict must leave both actions unchanged",
	)
	var resolved_result := InputProfile.replace_device_binding("cast_spell", keyboard_event, true)
	_expect(
		bool(resolved_result.get("ok", false))
		and not _binding_exists("attack", keyboard_event)
		and _binding_exists("cast_spell", keyboard_event),
		"Confirming a conflict must move the binding away from the previous action",
	)

	var gamepad_event := InputEventJoypadButton.new()
	gamepad_event.pressed = true
	gamepad_event.button_index = JOY_BUTTON_RIGHT_STICK
	_expect(
		bool(InputProfile.replace_device_binding("game_menu", gamepad_event).get("ok", false)),
		"A gamepad button must be assignable independently from keyboard controls",
	)
	var customized := InputProfile.export_bindings().duplicate(true)
	_expect(
		SaveSystem.save_settings({
			"fullscreen": false,
			"locale": "ru",
			"bindings": customized,
		}, CONTROLS_SETTINGS_PATH) == OK,
		"Customized bindings must be writable through the settings format",
	)
	InputProfile.reset_to_defaults()
	var loaded_settings := SaveSystem.load_settings(CONTROLS_SETTINGS_PATH)
	InputProfile.import_bindings(loaded_settings.get("bindings", {}))
	_expect(
		_binding_exists("cast_spell", keyboard_event)
		and _binding_exists("game_menu", gamepad_event),
		"Keyboard modifiers and gamepad bindings must survive a settings round-trip",
	)

	InputProfile.reset_to_defaults()
	_expect(
		JSON.stringify(InputProfile.export_bindings()) == JSON.stringify(defaults),
		"Resetting controls must restore every default keyboard and gamepad event",
	)
	InputProfile.import_bindings({
		"attack": [{"type": "key", "keycode": 0, "physical_keycode": 0}],
	})
	var default_attack := InputEventKey.new()
	default_attack.pressed = true
	default_attack.keycode = KEY_F
	_expect(
		_binding_exists("attack", default_attack),
		"Malformed bindings in an old settings file must not erase working defaults",
	)

	var legacy_bindings := defaults.duplicate(true)
	legacy_bindings["character_sheet"] = [{
		"type": "key",
		"keycode": int(KEY_Z),
		"physical_keycode": 0,
	}]
	legacy_bindings["evolve_form"] = [{"type": "key", "keycode": int(KEY_E)}]
	InputProfile.import_bindings(legacy_bindings)
	var migrated_e := InputEventKey.new()
	migrated_e.pressed = true
	migrated_e.keycode = KEY_E
	_expect(
		_binding_exists("character_sheet", migrated_e),
		"Legacy settings with the removed evolution action must retain E on the character sheet",
	)
	InputProfile.reset_to_defaults()
	_expect(
		SaveSystem.delete_settings(CONTROLS_SETTINGS_PATH) == OK,
		"The controls settings fixture must be deleted after the test",
	)


func _test_grid_navigation_contracts() -> void:
	var corridor_tiles: Dictionary = {
		Vector2i(1, 2): "floor",
		Vector2i(1, 1): "floor",
		Vector2i(2, 1): "floor",
		Vector2i(3, 1): "floor",
		Vector2i(3, 2): "floor",
	}
	var known_cells: Dictionary = {}
	for cell in corridor_tiles:
		known_cells[cell] = true
	var expected_path: Array[Vector2i] = [
		Vector2i(1, 2),
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(3, 1),
		Vector2i(3, 2),
	]
	_expect(
		GridNavigation.find_path(
			corridor_tiles,
			Vector2i(1, 2),
			Vector2i(3, 2),
			known_cells,
			true,
		) == expected_path,
		"Known-floor routing must preserve the complete deterministic path",
	)
	var incomplete_knowledge := known_cells.duplicate()
	incomplete_knowledge.erase(Vector2i(2, 1))
	_expect(
		GridNavigation.find_path(
			corridor_tiles,
			Vector2i(1, 2),
			Vector2i(3, 2),
			incomplete_knowledge,
			true,
		).is_empty(),
		"Known-only routing must not cross an unexplored cell",
	)
	_expect(
		GridNavigation.find_path(
			corridor_tiles,
			Vector2i(1, 2),
			Vector2i(3, 2),
			{},
			false,
			{Vector2i(2, 1): true},
		).is_empty(),
		"Occupied intermediate cells must block player routing",
	)
	_expect(
		GridNavigation.next_step(
			corridor_tiles,
			Vector2i(1, 2),
			Vector2i(3, 2),
			{Vector2i(3, 2): true},
		) == Vector2i(1, 1),
		"Enemy routing must allow an occupied target and preserve its first step",
	)

	var open_tiles: Dictionary = {}
	for y in range(5):
		for x in range(5):
			open_tiles[Vector2i(x, y)] = "floor"
	_expect(
		GridNavigation.has_clear_line(open_tiles, Vector2i(0, 2), Vector2i(4, 2)),
		"A straight unobstructed spell line must remain visible",
	)
	open_tiles[Vector2i(2, 2)] = "wall"
	_expect(
		not GridNavigation.has_clear_line(open_tiles, Vector2i(0, 2), Vector2i(4, 2)),
		"An intermediate wall must block a spell line",
	)
	open_tiles[Vector2i(2, 2)] = "floor"
	open_tiles[Vector2i(4, 2)] = "wall"
	_expect(
		GridNavigation.has_clear_line(open_tiles, Vector2i(0, 2), Vector2i(4, 2)),
		"The target cell itself must not block line of sight",
	)
	open_tiles[Vector2i(4, 2)] = "floor"
	open_tiles[Vector2i(2, 1)] = "wall"
	_expect(
		not GridNavigation.has_clear_line(open_tiles, Vector2i(1, 1), Vector2i(2, 2)),
		"A diagonal spell must not pass through an opaque corner",
	)
	_expect(
		GridNavigation.manhattan(Vector2i(-2, 5), Vector2i(3, 1)) == 9,
		"Grid distance must remain Manhattan distance",
	)


func _test_extracted_ui_contracts() -> void:
	var parent := Control.new()
	var label := UiFactory.make_label(parent, Vector2(12, 18), Vector2(90, 24), 17)
	var button := UiFactory.make_button(
		parent,
		Vector2(20, 30),
		"A deliberately long button label",
		Vector2(96, 42),
	)
	_expect(
		label.get_parent() == parent
		and label.position == Vector2(12, 18)
		and label.size == Vector2(90, 24)
		and label.clip_text,
		"Extracted label construction must preserve ownership, geometry, and clipping",
	)
	_expect(
		button.get_parent() == parent
		and button.position == Vector2(20, 30)
		and button.size == Vector2(96, 42)
		and button.focus_mode == Control.FOCUS_NONE
		and button.clip_text
		and button.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
		"Extracted button construction must preserve input focus and overflow behavior",
	)
	UiFactory.fit_button_text(button, 18, 10)
	var fitted_font_size := button.get_theme_font_size("font_size")
	_expect(
		fitted_font_size >= 10 and fitted_font_size <= 18,
		"Extracted button fitting must stay within its configured font-size bounds",
	)
	_expect(
		Renderer.cell_rect(Vector2i(3, 2)) == Rect2(
			Vector2(3, 2) * Renderer.CELL_SIZE,
			Vector2(Renderer.CELL_SIZE, Renderer.CELL_SIZE),
		),
		"Extracted renderer must use viewport-local dungeon cell coordinates",
	)
	_expect(
		Renderer.CAMP_ART != null
		and Renderer.DUNGEON_FLOOR_TEXTURE != null
		and Renderer.DUNGEON_WALL_TEXTURE != null
		and Renderer.DUNGEON_CHEST_SPRITE != null
		and Renderer.PLAYER_SKELETON_SPRITE != null
		and Renderer.ENEMY_SPRITES.size() == GameRules.ENEMIES.size()
		and Renderer.ENEMY_SPRITES.has(BossFloor90.BOSS_ID),
		"Extracted renderer must retain every required prototype art resource",
	)
	_expect(
		Renderer.WALL_TEXTURE_SAMPLE_SIZE >= 900
		and Renderer.WALL_MASONRY_DENSITY_FACTOR == 10
		and Renderer.COLOR_FOG_MEMORY.a >= 0.28
		and Renderer.COLOR_FOG_MEMORY.a <= 0.38
		and Renderer.COLOR_FOG_WALL_MEMORY.a >= 0.75
		and Renderer.COLOR_FOG_WALL_MEMORY.a > Renderer.COLOR_FOG_MEMORY.a,
		"Remembered floors must stay readable while remembered walls retain stronger fog contrast",
	)
	var wall_tints := {}
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(3, 2), Vector2i(7, 5)]:
		var tint := Renderer.wall_texture_tint(cell)
		wall_tints[tint.to_html()] = true
		_expect(
			absf(tint.get_luminance() - Color("d2d7df").get_luminance()) < 0.06,
			"Wall color dispersion must remain subtle",
		)
	_expect(wall_tints.size() >= 3, "Wall cells must use several deterministic tint variants")
	parent.free()


func _test_full_state_persistence() -> void:
	_expect(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY)) == OK,
		"Regression test directory must be available",
	)
	SaveSystem.delete_game(SAVE_PATH)

	var original := RunState.new()
	original.configure_character("Полное состояние", {
		"strength": 2,
		"agility": 3,
		"perception": 4,
		"vitality": 5,
		"wisdom": 6,
	})
	original.banked_souls = 101
	original.carried_souls = 37
	original.absorbed_souls = 80
	original.current_form_id = "almost_human"
	original.base_level = 7
	original.checkpoint_floor = 55
	original.rope_floor = 63
	original.loadout = {
		"right_hand": GameRules.make_item_key("bone_knife", 2, true),
		"talisman": GameRules.make_item_key("soul_locket"),
		"body": GameRules.make_item_key("rotting_mail"),
		"hands": GameRules.make_item_key("leather_gloves"),
		"left_hand": GameRules.make_item_key("pilgrim_shield"),
	}
	original.inventory = {
		GameRules.make_item_key("bone_knife", 1): 3,
		GameRules.make_item_key("grave_mace", 3, true): 2,
		GameRules.make_item_key("rotting_mail"): 4,
		GameRules.make_item_key("hollow_lantern"): 1,
	}
	original.resources = {"wood": 12, "stone": 34, "cloth": 5}
	original.camp_upgrades = {
		"crusher": true,
		"whetstone": true,
		"ritual_table": true,
		"campfire": true,
		"kettle": false, "bunk": false, "mural": false,
	}
	original.skill_levels = {
		"strong_bones": 4,
		"fundamentals": 1,
		"magic_awakening": 1,
		"magic_missile": 3,
		"magic_missile_range": 1,
		"magic_ricochet": 4,
		"flesh_regeneration": 1,
		"stomach": 1,
		"ears": 1,
		"sharp_vision": 2,
	}
	original.unspent_attribute_points = 3
	original.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
	original.food = 6
	original.hunger = 100
	original.hunger_turn_progress = 0
	original.regeneration_progress = 37
	original.mana_regeneration_progress = 0.375
	original.total_turns = 4321
	original.cradle_miss_streak = 9
	original.ability_cooldowns = {"dash": 7, "double_attack": 3}
	original.active_statuses = {
		"rested": {"remaining_turns": 321, "temporary_hp": 4},
		"satiated": {"remaining_turns": 222, "temporary_hp": 2},
	}
	original.hp = original.get_max_hp() - 3
	original.mana = original.get_max_mana() - 4

	_expect(SaveSystem.save_game(original, SAVE_PATH) == OK, "A complete state must be written to disk")
	var serialized = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_expect(
		serialized is Dictionary
		and int(serialized.get("version", 0)) == SaveSystem.STATE_ONLY_VERSION,
		"The state-only setup API must write the current schema with an explicit kind",
	)

	var restored := RunState.new()
	_expect(
		restored.restore_save_data(SaveSystem.load_game(SAVE_PATH)),
		"A complete state must load from the persisted file",
	)
	_expect(
		JSON.stringify(restored.to_save_data()) == JSON.stringify(original.to_save_data()),
		"Every persisted RunState field must survive a file round-trip",
	)
	_expect(
		SaveSystem.delete_game(SAVE_PATH) == OK and not FileAccess.file_exists(SAVE_PATH),
		"The persistence fixture must be deleted after the test",
	)


func _test_malformed_and_versioned_saves() -> void:
	_expect(_write_text(MALFORMED_SAVE_PATH, "{broken") == OK, "Malformed-save fixture must be writable")
	_expect(
		SaveSystem.load_game(MALFORMED_SAVE_PATH).is_empty(),
		"Malformed JSON must be rejected without returning partial state",
	)

	_expect(_write_json(MALFORMED_SAVE_PATH, {
		"version": SaveSystem.MIN_SUPPORTED_SAVE_VERSION - 1,
		"state": {"character_name": "Too Old"},
	}) == OK, "Outdated-save fixture must be writable")
	_expect(
		SaveSystem.load_game(MALFORMED_SAVE_PATH).is_empty(),
		"A save older than MIN_SUPPORTED_SAVE_VERSION must be rejected",
	)

	_expect(_write_json(MALFORMED_SAVE_PATH, {
		"version": SaveSystem.SAVE_VERSION + 1,
		"state": {"character_name": "Future"},
	}) == OK, "Future-save fixture must be writable")
	_expect(
		SaveSystem.load_game(MALFORMED_SAVE_PATH).is_empty(),
		"A save from a newer unsupported schema must be rejected",
	)

	_expect(_write_json(MALFORMED_SAVE_PATH, {
		"version": SaveSystem.SAVE_VERSION,
		"state": ["not", "a", "dictionary"],
	}) == OK, "Wrong-state-type fixture must be writable")
	_expect(
		SaveSystem.load_game(MALFORMED_SAVE_PATH).is_empty(),
		"A save with a non-dictionary state must be rejected",
	)
	for legacy_version in range(1, SaveSystem.SAVE_VERSION):
		_expect(_write_json(MALFORMED_SAVE_PATH, {
			"version": legacy_version,
			"state": {"character_name": "Legacy %d" % legacy_version},
		}) == OK, "Legacy version %d fixture must be writable" % legacy_version)
		_expect(
			SaveSystem.load_game(MALFORMED_SAVE_PATH).is_empty(),
			"Old test schema v%d must be excluded without migration" % legacy_version,
		)

	_expect(_write_json(MALFORMED_SAVE_PATH, {
		"version": SaveSystem.MIN_SUPPORTED_SAVE_VERSION,
		"kind": "state_only",
		"state": RunState.new().to_save_data().merged({
			"character_name": "Legacy",
			"attributes": {"strength": 3},
		}, true),
	}) == OK, "Old supported-save fixture must be writable")
	var legacy := RunState.new()
	_expect(
		legacy.restore_save_data(SaveSystem.load_game(MALFORMED_SAVE_PATH))
		and legacy.character_name == "Legacy"
		and legacy.attributes["strength"] == 3
		and legacy.attributes["agility"] == GameRules.STARTING_ATTRIBUTE_VALUE
		and legacy.current_form_id == "skeleton",
		"Explicit current state-only helper may use setup defaults",
	)
	_expect(
		SaveSystem.delete_game(MALFORMED_SAVE_PATH) == OK
		and not FileAccess.file_exists(MALFORMED_SAVE_PATH),
		"Version fixtures must be deleted after the test",
	)


func _test_v12_to_v13_additive_ids() -> void:
	var legacy_source := RunState.new()
	legacy_source.configure_character("Legacy v12", GameRules.default_attributes())
	legacy_source.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
	legacy_source.current_form_id = "ghoul"
	legacy_source.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	legacy_source.active_statuses = {
		"rested": {"remaining_turns": 123, "temporary_hp": 4},
	}
	var legacy_data := legacy_source.to_save_data()
	var legacy_skills: Dictionary = legacy_data["skill_levels"]
	legacy_skills.erase("stomach")
	legacy_skills.erase("ears")
	var legacy_statuses: Dictionary = legacy_data["active_statuses"]
	legacy_statuses.erase("satiated")
	_expect(
		_write_json(SAVE_PATH, {"version": 12, "state": legacy_data}) == OK,
		"A true v12 fixture without the additive v13 ids must be writable",
	)
	_expect(SaveSystem.load_game(SAVE_PATH).is_empty(), "Old v12 test files are deliberately excluded by v15")
	var migrated := RunState.new()
	_expect(
		migrated.restore_save_data(legacy_data)
		and migrated.get_skill_level("stomach") == 0
		and migrated.get_skill_level("ears") == 0
		and not migrated.uses_hunger()
		and not migrated.has_hearing()
		and not migrated.has_status("satiated")
		and migrated.has_status("rested")
		and migrated.status_remaining("rested") == 123,
		"The direct setup helper still accepts partial data with safe defaults",
	)
	_expect(
		SaveSystem.save_game(migrated, SAVE_PATH) == OK,
		"An explicitly constructed setup state publishes as the current schema",
	)
	var migrated_envelope = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	var migrated_roundtrip := RunState.new()
	_expect(
		migrated_envelope is Dictionary
		and int(migrated_envelope.get("version", 0)) == SaveSystem.SAVE_VERSION
		and migrated_envelope.get("kind") == "state_only"
		and migrated_roundtrip.restore_save_data(SaveSystem.load_game(SAVE_PATH))
		and migrated_roundtrip.get_skill_level("stomach") == 0
		and migrated_roundtrip.get_skill_level("ears") == 0
		and not migrated_roundtrip.has_status("satiated"),
		"A v15 state-only helper must round-trip without inventing new progression",
	)

	var current := RunState.new()
	current.configure_character("Current v13", GameRules.default_attributes())
	current.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
	current.current_form_id = "ghoul"
	current.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	current.skill_levels["stomach"] = 1
	current.skill_levels["ears"] = 1
	current.add_or_refresh_status("satiated", 222, 3)
	_expect(
		SaveSystem.save_game(current, SAVE_PATH) == OK,
		"A compatible v13 state-only save with additive ids must be writable",
	)
	var current_envelope = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	var current_roundtrip := RunState.new()
	_expect(
		current_envelope is Dictionary
		and int(current_envelope.get("version", 0)) == SaveSystem.STATE_ONLY_VERSION
		and current_roundtrip.restore_save_data(SaveSystem.load_game(SAVE_PATH))
		and current_roundtrip.get_skill_level("stomach") == 1
		and current_roundtrip.get_skill_level("ears") == 1
		and current_roundtrip.uses_hunger()
		and current_roundtrip.has_hearing()
		and current_roundtrip.has_status("satiated")
		and current_roundtrip.status_remaining("satiated") == 222
		and int(current_roundtrip.active_statuses["satiated"].get("temporary_hp", 0)) == 3,
		"A compatible v13 state-only save must preserve learned Stomach/Ears and Satiated exactly",
	)
	_expect(
		SaveSystem.delete_game(SAVE_PATH) == OK
		and not FileAccess.file_exists(SAVE_PATH)
		and not FileAccess.file_exists(SAVE_PATH + ".bak"),
		"v12/v13 migration fixtures must be deleted after the test",
	)


func _test_evolution_and_skill_boundaries() -> void:
	var insufficient := RunState.new()
	insufficient.carried_souls = 9
	var insufficient_result := insufficient.evolve_at_cradle()
	_expect(
		not insufficient_result["ok"]
		and insufficient_result["reason"] == "souls"
		and insufficient_result["cost"] == 10
		and insufficient.carried_souls == 9
		and insufficient.current_form_id == "skeleton",
		"Failed evolution must report its exact cost and leave state unchanged",
	)

	var evolution := RunState.new()
	evolution.carried_souls = 100
	var expected_costs := [10, 14, 24, 32]
	for index in range(expected_costs.size()):
		var expected_form: String = GameRules.FORM_ORDER[index + 1]
		evolution.soul_level = GameRules.required_soul_level(expected_form)
		var souls_before := evolution.carried_souls
		var result := evolution.evolve_at_cradle()
		_expect(
			result["ok"]
			and result["cost"] == expected_costs[index]
			and evolution.current_form_id == expected_form
			and evolution.carried_souls == souls_before - expected_costs[index]
			and evolution.absorbed_souls == GameRules.FORMS[expected_form]["threshold"],
			"Evolution step %d must advance one form for its exact cost" % (index + 1),
		)
	var maximum_result := evolution.evolve_at_cradle()
	_expect(
		not maximum_result["ok"]
		and maximum_result["reason"] == "maximum"
		and evolution.current_form_id == "almost_human"
		and evolution.carried_souls == 20,
		"The final form must reject further evolution without spending souls",
	)

	var skills := RunState.new()
	skills.banked_souls = 500
	var starting_hp := skills.get_max_hp()
	var total_strong_bones_cost := 0
	for level in range(10):
		var expected_cost := GameRules.skill_cost("strong_bones", level)
		var result := skills.purchase_skill("strong_bones")
		total_strong_bones_cost += expected_cost
		_expect(
			result["ok"] and result["level"] == level + 1 and result["cost"] == expected_cost,
			"Sturdy Bones level %d must use its deterministic cost" % (level + 1),
		)
	var souls_at_maximum := skills.get_total_souls()
	_expect(
		total_strong_bones_cost == 275
		and skills.get_max_hp() == starting_hp + 30
		and not skills.purchase_skill("strong_bones")["ok"]
		and skills.get_total_souls() == souls_at_maximum,
		"A maxed skill must grant its complete bonus and reject extra purchases for free",
	)
	var fundamentals := skills.purchase_skill("fundamentals")
	var souls_after_fundamentals := skills.get_total_souls()
	_expect(
		fundamentals["ok"]
		and fundamentals["cost"] == 25
		and skills.unspent_attribute_points == 5
		and not skills.purchase_skill("fundamentals")["ok"]
		and skills.get_total_souls() == souls_after_fundamentals,
		"Develop Fundamentals must grant five points exactly once",
	)


func _test_inventory_failure_and_upgrade_boundaries() -> void:
	var salvage := RunState.new()
	var armor_key := salvage.add_item("rotting_mail")
	var blocked_salvage := salvage.dismantle_item(armor_key)
	_expect(
		not blocked_salvage["ok"]
		and blocked_salvage["reason"] == "crusher"
		and salvage.inventory.get(armor_key, 0) == 1
		and salvage.resources == {"wood": 0, "stone": 0, "cloth": 0},
		"Dismantling without a Crusher must not consume the item",
	)
	salvage.camp_upgrades["crusher"] = true
	var salvaged := salvage.dismantle_item(armor_key)
	_expect(
		salvaged["ok"]
		and not salvage.inventory.has(armor_key)
		and salvage.resources == {"wood": 0, "stone": 0, "cloth": 2},
		"Dismantling armor must consume one item and grant its exact salvage",
	)

	var weapon_state := RunState.new()
	weapon_state.camp_upgrades["whetstone"] = true
	var weapon_key := weapon_state.add_item("bone_knife")
	var no_resources := weapon_state.upgrade_weapon(weapon_key, 0.0, 0.0)
	_expect(
		not no_resources["ok"]
		and no_resources["reason"] == "resources"
		and weapon_state.inventory.get(weapon_key, 0) == 1,
		"An unaffordable weapon upgrade must preserve the weapon",
	)
	weapon_state.add_resources({"wood": 10, "stone": 50, "cloth": 5})
	var plus_one := weapon_state.upgrade_weapon(weapon_key, 1.0, 1.0)
	_expect(
		plus_one["outcome"] == "upgraded" and plus_one["new_level"] == 1,
		"The guaranteed first upgrade must also succeed at the upper roll boundary",
	)
	var plus_one_key := String(plus_one["item_key"])
	var exact_half := weapon_state.upgrade_weapon(plus_one_key, 0.5, 1.0)
	_expect(
		exact_half["outcome"] == "unchanged"
		and exact_half["new_level"] == 1
		and weapon_state.inventory.get(plus_one_key, 0) == 1,
		"The +2 fifty-percent chance must exclude an exact 0.5 roll",
	)
	var plus_two := weapon_state.upgrade_weapon(plus_one_key, 0.499999, 1.0)
	_expect(plus_two["new_level"] == 2, "A roll immediately below 0.5 must reach +2")
	var plus_two_key := String(plus_two["item_key"])
	var exact_fifteen := weapon_state.upgrade_weapon(plus_two_key, 0.15, 1.0)
	_expect(
		exact_fifteen["outcome"] == "unchanged" and exact_fifteen["new_level"] == 2,
		"The +3 fifteen-percent chance must exclude an exact 0.15 roll",
	)
	var plus_three := weapon_state.upgrade_weapon(plus_two_key, 0.149999, 1.0)
	var maximum_resources: Dictionary = weapon_state.resources.duplicate(true)
	var maximum_attempt := weapon_state.upgrade_weapon(String(plus_three["item_key"]), 0.0, 0.0)
	_expect(
		plus_three["new_level"] == 3
		and not maximum_attempt["ok"]
		and maximum_attempt["reason"] == "maximum"
		and weapon_state.resources == maximum_resources,
		"A +3 weapon must reject further attempts without consuming materials",
	)


func _test_survival_accumulators() -> void:
	var regeneration := RunState.new()
	regeneration.current_form_id = "zombie"
	regeneration.absorbed_souls = 10
	regeneration.highest_unlocked_form_index = GameRules.FORM_ORDER.find("zombie")
	regeneration.skill_levels["flesh_regeneration"] = 1
	regeneration.attributes["vitality"] = 490
	regeneration.hp = regeneration.get_max_hp() - 2
	_expect(
		regeneration.get_derived_stats()["regeneration"] == 50,
		"The regeneration boundary fixture must provide exactly 50 regeneration",
	)
	var first_regeneration_turn := regeneration.advance_survival_turn()
	var second_regeneration_turn := regeneration.advance_survival_turn()
	_expect(
		first_regeneration_turn["healed"] == 0
		and second_regeneration_turn["healed"] == 1
		and regeneration.regeneration_progress == 0,
		"Regeneration 50 must heal exactly once every two turns without losing fractions",
	)

	var hunger := RunState.new()
	hunger.current_form_id = "ghoul"
	hunger.absorbed_souls = 24
	hunger.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	hunger.skill_levels["stomach"] = 1
	for _turn in range(9):
		hunger.advance_survival_turn()
	_expect(hunger.hunger == 100, "Satiety must not decrease before the tenth turn")
	hunger.advance_survival_turn()
	_expect(hunger.hunger == 99, "Satiety must decrease exactly on the tenth turn")

	var mana_cap := RunState.new()
	mana_cap.mana = mana_cap.get_max_mana() - 1
	mana_cap.mana_regeneration_progress = 0.95
	var mana_result := mana_cap.advance_survival_turn()
	_expect(
		mana_result["mana_restored"] == 1
		and mana_cap.mana == mana_cap.get_max_mana()
		and is_zero_approx(mana_cap.mana_regeneration_progress),
		"Mana regeneration must clamp at maximum and clear leftover progress",
	)


func _test_death_return_and_rope_invariants() -> void:
	var returning := RunState.new()
	returning.current_floor = 67
	returning.rope_floor = 80
	returning.banked_souls = 11
	returning.carried_souls = 9
	returning.hp = 1
	returning.mana = 0
	returning.mana_regeneration_progress = 0.75
	var delivered := returning.safe_return()
	_expect(
		delivered == 9
		and returning.banked_souls == 20
		and returning.carried_souls == 0
		and returning.rope_floor == 67
		and returning.hp == returning.get_max_hp()
		and returning.mana == returning.get_max_mana()
		and is_zero_approx(returning.mana_regeneration_progress),
		"Safe return must bank souls, improve the rope and fully restore HP and mana",
	)
	returning.current_floor = 75
	returning.safe_return()
	_expect(returning.rope_floor == 67, "A later deeper return must not move the rope backward")

	var dying := RunState.new()
	dying.banked_souls = 50
	dying.carried_souls = 13
	dying.absorbed_souls = 24
	dying.current_form_id = "ghoul"
	dying.rope_floor = 72
	dying.checkpoint_floor = 70
	dying.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	dying.skill_levels["strong_bones"] = 2
	dying.resources = {"wood": 8, "stone": 9, "cloth": 3}
	dying.camp_upgrades = {"crusher": true, "whetstone": false}
	dying.loadout = {
		"right_hand": GameRules.make_item_key("bone_knife", 1),
		"talisman": GameRules.make_item_key("soul_locket"),
	}
	dying.inventory = {
		GameRules.make_item_key("grave_mace"): 2,
		GameRules.make_item_key("rotting_mail"): 3,
	}
	dying.food = 4
	dying.hunger = 31
	dying.hunger_turn_progress = 7
	dying.regeneration_progress = 64
	dying.mana_regeneration_progress = 0.6
	dying.total_turns = 222
	dying.cradle_miss_streak = 6
	var losses := dying.die()
	_expect(
		losses == {"souls": 13, "items": 7}
		and dying.carried_souls == 0
		and dying.current_form_id == "skeleton"
		and dying.absorbed_souls == 0
		and dying.loadout == {GameRules.PERMANENT_JACKET_SLOT_ID: GameRules.permanent_jacket_key()}
		and dying.inventory.is_empty()
		and dying.food == 0
		and dying.hunger == 100
		and dying.hunger_turn_progress == 0
		and dying.regeneration_progress == 0
		and is_zero_approx(dying.mana_regeneration_progress)
		and dying.total_turns == 0
		and dying.cradle_miss_streak == 0,
		"Death must clear every expedition field and report all carried losses",
	)
	_expect(
		dying.banked_souls == 50
		and dying.rope_floor == 72
		and dying.checkpoint_floor == 70
		and dying.highest_unlocked_form_index == GameRules.FORM_ORDER.find("ghoul")
		and dying.skill_levels["strong_bones"] == 2
		and dying.resources == {"wood": 8, "stone": 9, "cloth": 3}
		and dying.camp_upgrades == {"crusher": true, "whetstone": false}
		and dying.hp == dying.get_max_hp()
		and dying.mana == dying.get_max_mana(),
		"Death must preserve permanent progress, the rope, materials and learned skills",
	)


func _test_magic_visibility_and_ricochet_boundaries(tree: SceneTree) -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	main.persistence_enabled = false
	tree.root.add_child(main)
	await tree.process_frame

	main.screen = main.Screen.DUNGEON
	main.state = RunState.new()
	main.state.skill_levels["magic_awakening"] = 1
	main.state.skill_levels["magic_missile"] = 1
	main.state.skill_levels["magic_ricochet"] = 1
	main.state.assign_ability("active_1", "magic_missile")
	main.state.mana = main.state.get_max_mana()
	main.player_pos = Vector2i(1, 2)
	main.floor_data = _magic_floor()
	main._update_player_visibility(false)
	_expect(
		main._is_cell_visible(Vector2i(3, 2))
		and not main._is_cell_visible(Vector2i(3, 4))
		and not main._has_clear_spell_line(Vector2i(3, 2), Vector2i(3, 4)),
		"The magic fixture must expose the primary target while hiding the ricochet target behind a wall",
	)

	_set_magic_enemies(main, 10, 10)
	_select_enemy(main, "primary")
	main._on_spell_pressed(0.0)
	_expect(
		_enemy_hp(main, "primary") == 7 and _enemy_hp(main, "ricochet") == 7,
		"A successful ricochet must damage a nearby enemy even when a wall blocks their line",
	)

	_reset_magic_cast(main)
	_set_magic_enemies(main, 10, 10)
	_select_enemy(main, "primary")
	main._on_spell_pressed(main.state.get_magic_ricochet_chance())
	_expect(
		_enemy_hp(main, "primary") == 7 and _enemy_hp(main, "ricochet") == 10,
		"An exact ricochet-threshold roll must fail because success uses a strict lower bound",
	)

	_reset_magic_cast(main)
	_set_magic_enemies(main, 10, -1)
	main.floor_data["tiles"][Vector2i(2, 2)] = "wall"
	main.floor_data["visible_cells"][Vector2i(3, 2)] = true
	_select_enemy(main, "primary")
	var blocked_mana: int = main.state.mana
	var blocked_turns: int = main.state.total_turns
	main._on_spell_pressed(0.0)
	_expect(
		_enemy_hp(main, "primary") == 10
		and main.state.mana == blocked_mana
		and main.state.total_turns == blocked_turns,
		"A wall-blocked primary missile must spend neither mana nor a turn",
	)

	_reset_magic_cast(main)
	main.floor_data = _magic_floor()
	main.floor_data["enemies"] = [_magic_enemy("far", Vector2i(5, 2), 10, "hollow_guard")]
	main.floor_data["visible_cells"] = {Vector2i(5, 2): true}
	_select_enemy(main, "far")
	var range_mana: int = main.state.mana
	var range_turns: int = main.state.total_turns
	main._on_spell_pressed(0.0)
	_expect(
		_enemy_hp(main, "far") == 10
		and main.state.mana == range_mana
		and main.state.total_turns == range_turns,
		"An out-of-range selected missile target must be rejected without cost",
	)

	_reset_magic_cast(main)
	main.floor_data = _magic_floor()
	main.floor_data["enemies"] = [_magic_enemy("hidden", Vector2i(3, 2), 10, "hollow_guard")]
	main.floor_data["visible_cells"] = {main.player_pos: true}
	main.inspected_target.clear()
	var hidden_mana: int = main.state.mana
	main._on_spell_pressed(0.0)
	_expect(
		_enemy_hp(main, "hidden") == 10 and main.state.mana == hidden_mana,
		"Automatic spell targeting must ignore enemies outside current visibility",
	)

	_reset_magic_cast(main)
	main.floor_data = _magic_floor()
	main.floor_data["enemies"] = [_magic_enemy("kill", Vector2i(3, 2), 3, "grave_rat")]
	main.floor_data["visible_cells"] = {main.player_pos: true, Vector2i(3, 2): true}
	main.state.carried_souls = 0
	main.state.food = 0
	_select_enemy(main, "kill")
	main._on_spell_pressed(1.0)
	_expect(
		main.floor_data["enemies"].is_empty()
		and main.state.carried_souls == 1
		and main.state.food == 1,
		"A lethal Magic Missile must remove the enemy and award its souls and meat",
	)

	main.queue_free()
	await tree.process_frame


func _test_automatic_exploration_and_visible_waiting(tree: SceneTree) -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	main.persistence_enabled = false
	main.auto_step_delay_override = 0.0
	tree.root.add_child(main)
	await tree.process_frame

	main.state = RunState.new()
	main.state.configure_character("Explorer", GameRules.default_attributes())
	main.state.current_form_id = "ghoul"
	main.state.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	main.state.skill_levels["ears"] = 1
	main.state.hp = main.state.get_max_hp()
	main.state.current_floor = 99
	main.screen = main.Screen.DUNGEON
	main.floor_data = _exploration_floor()
	main.player_pos = Vector2i(1, 1)
	main.floor_data["enemies"] = [{
		"uid": "exploration_guard",
		"id": "hollow_guard",
		"pos": Vector2i(13, 1),
		"hp": 4,
		"max_hp": 4,
		"damage": 0,
		"accuracy": 0,
		"dodge": 0,
		"vision": 0,
		"souls": 2,
	}]
	main._update_player_visibility(false)
	_expect(
		not main._has_visible_enemy(),
		"The exploration fixture enemy must begin outside true vision",
	)
	var turns_before_exploration: int = main.state.total_turns
	main._on_auto_explore_pressed()
	_expect(
		main.auto_explore_active
		and not main.auto_explore_button.disabled
		and main.auto_explore_button.text == Loc.text("BTN_AUTO_EXPLORE_STOP"),
		"Active exploration must keep an accessible stop button",
	)
	var frames := 0
	while main.auto_explore_active and frames < 100:
		await tree.process_frame
		frames += 1
	_expect(
		not main.auto_explore_active
		and not main.hearing_contacts.presentation_positions().is_empty()
		and main.state.total_turns > turns_before_exploration
		and main.auto_explore_button.text == Loc.text("BTN_AUTO_EXPLORE"),
		"Automatic exploration must spend normal turns and stop at a newly heard enemy",
	)
	_expect(
		main.player_pos != main.floor_data["enemies"][0]["pos"],
		"Automatic exploration must stop before entering an occupied cell",
	)

	# Preserve the pre-existing visible-enemy wait contract independently of the
	# earlier (and intentionally sooner) hearing interruption.
	var visible_enemy_cell: Vector2i = main.player_pos
	for visible_variant in main.floor_data["visible_cells"]:
		var candidate: Vector2i = visible_variant
		if candidate != main.player_pos and main.floor_data["tiles"].get(candidate) == "floor":
			visible_enemy_cell = candidate
			break
	main.floor_data["enemies"][0]["pos"] = visible_enemy_cell
	main._update_player_visibility(false)
	main.wait_turn_count = 10
	var turns_before_visible_wait: int = main.state.total_turns
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == turns_before_visible_wait,
		"Multi-turn waiting must stop for any visible enemy, even beyond two cells",
	)

	main.floor_data["enemies"].clear()
	main.inspected_target.clear()
	main._on_auto_explore_pressed()
	frames = 0
	while main.auto_explore_active and frames < 100:
		await tree.process_frame
		frames += 1
	var all_accessible_floor_mapped := true
	for cell_variant in main.floor_data["tiles"]:
		var cell: Vector2i = cell_variant
		if (
			main.floor_data["tiles"][cell] == "floor"
			and not main._is_cell_explored(cell)
		):
			all_accessible_floor_mapped = false
			break
	_expect(
		not main.auto_explore_active
		and all_accessible_floor_mapped
		and main.message == Loc.text("MSG_EXPLORE_COMPLETE"),
		"Automatic exploration must stop cleanly after mapping every accessible floor cell",
	)

	main.floor_data = _exploration_floor()
	main.player_pos = Vector2i(1, 1)
	main._update_player_visibility(false)
	main._on_auto_explore_pressed()
	main._on_auto_explore_pressed()
	_expect(
		not main.auto_explore_active
		and not main.auto_travel_active
		and main.message == Loc.text("MSG_EXPLORE_CANCELLED"),
		"Pressing automatic exploration again must cancel it without leaving input locked",
	)

	# Automatic routes stop before their first turn for either a visible enemy or
	# an already-present hearing contact, rather than only a newly created event.
	main.floor_data = _exploration_floor()
	main.player_pos = Vector2i(1, 1)
	main.floor_data["enemies"] = [{
		"uid": "heard-at-launch", "id": "grave_rat", "pos": Vector2i(6, 1),
		"hp": 2, "max_hp": 2, "damage": 0, "accuracy": -100, "dodge": 0,
		"vision": 0, "souls": 1,
	}]
	main._update_player_visibility(false)
	var turns_before_contact_launch: int = main.state.total_turns
	_expect(
		not main._has_visible_enemy() and main._has_presented_hearing_contact(),
		"The automatic-route contact fixture must be heard without being visible",
	)
	main._on_auto_explore_pressed()
	_expect(
		not main.auto_travel_active and main.state.total_turns == turns_before_contact_launch,
		"Auto-explore must not start or spend a turn while an existing hearing contact is present",
	)
	main.floor_data["exit_known"] = true
	for cell_variant in main.floor_data["tiles"]:
		if main.floor_data["tiles"][cell_variant] == "floor":
			main.floor_data["explored_cells"][cell_variant] = true
	main._on_ascend_pressed()
	_expect(
		not main.auto_travel_active and main.state.total_turns == turns_before_contact_launch,
		"Known-stairs travel must not start or spend a turn while an existing hearing contact is present",
	)

	# Without Ears, hearing alone cannot stop a route, but an enemy on the next
	# tile still cannot be attacked or consume a turn automatically.
	main.state.skill_levels["ears"] = 0
	main._clear_hearing_context()
	main.floor_data = _exploration_floor()
	main.player_pos = Vector2i(1, 1)
	main.floor_data["explored_cells"] = {Vector2i(1, 1): true, Vector2i(2, 1): true}
	main.hearing_contacts.record_hidden_attack("ignored-without-ears", Vector2i(6, 1), main.state.total_turns)
	var turns_before_earless_launch: int = main.state.total_turns
	main.auto_step_delay_override = 0.05
	main._on_auto_explore_pressed()
	_expect(
		main.auto_travel_active and main.state.total_turns == turns_before_earless_launch + 1,
		"Without Ears, a remembered hearing contact must not prevent automatic movement",
	)
	main._cancel_automatic_actions()
	main.floor_data = _exploration_floor()
	main.player_pos = Vector2i(1, 1)
	main.floor_data["explored_cells"] = {Vector2i(1, 1): true, Vector2i(2, 1): true}
	main.floor_data["enemies"] = [{
		"uid": "next-step-blocker", "id": "grave_rat", "pos": Vector2i(2, 1),
		"hp": 2, "max_hp": 2, "damage": 0, "accuracy": -100, "dodge": 0,
		"vision": 0, "souls": 1,
	}]
	var turns_before_next_step_block: int = main.state.total_turns
	main.auto_step_delay_override = 0.0
	main._on_auto_explore_pressed()
	_expect(
		not main.auto_travel_active
		and main.state.total_turns == turns_before_next_step_block
		and int(main.floor_data["enemies"][0]["hp"]) == 2,
		"Auto-explore must stop before attacking or taking a turn into an unseen next-step enemy without Ears",
	)

	# A route already under way must recheck its next cell after the shared delay.
	main.floor_data = _exploration_floor()
	main.player_pos = Vector2i(1, 1)
	main.floor_data["exit_known"] = true
	for cell_variant in main.floor_data["tiles"]:
		if main.floor_data["tiles"][cell_variant] == "floor":
			main.floor_data["explored_cells"][cell_variant] = true
	main.auto_step_delay_override = 0.0
	var turns_before_route_block: int = main.state.total_turns
	main._on_ascend_pressed()
	main.floor_data["enemies"] = [{
		"uid": "route-step-blocker", "id": "grave_rat", "pos": Vector2i(3, 1),
		"hp": 2, "max_hp": 2, "damage": 0, "accuracy": -100, "dodge": 0,
		"vision": 0, "souls": 1,
	}]
	await tree.process_frame
	_expect(
		main.player_pos == Vector2i(2, 1)
		and not main.auto_travel_active
		and main.state.total_turns == turns_before_route_block + 1
		and int(main.floor_data["enemies"][0]["hp"]) == 2,
		"Known-stairs travel must stop before attacking or taking its next turn into an enemy",
	)

	# The route to known stairs uses the same delayed-turn contract. Cancelling
	# during that delay must invalidate the old coroutine before its next step.
	main.floor_data = _exploration_floor()
	main.player_pos = Vector2i(1, 1)
	main.floor_data["exit_known"] = true
	for cell_variant in main.floor_data["tiles"]:
		if main.floor_data["tiles"][cell_variant] == "floor":
			main.floor_data["explored_cells"][cell_variant] = true
	main.floor_data["visible_cells"] = main.floor_data["explored_cells"].duplicate(true)
	main.floor_data["observed_cells"] = main.floor_data["explored_cells"].duplicate(true)
	main.auto_step_delay_override = 0.05
	var turns_before_route: int = main.state.total_turns
	main._on_ascend_pressed()
	var first_route_position: Vector2i = main.player_pos
	_expect(
		first_route_position == Vector2i(2, 1)
		and main.state.total_turns == turns_before_route + 1
		and main.auto_travel_active,
		"Known-stairs travel must take only its first turn before the shared delay",
	)
	await tree.process_frame
	_expect(
		main.player_pos == first_route_position
		and main.state.total_turns == turns_before_route + 1
		and main.auto_travel_active,
		"Known-stairs travel must wait for its configured delay before a second turn",
	)
	main._open_main_menu()
	await tree.create_timer(0.08).timeout
	_expect(
		main.player_pos == first_route_position
		and main.state.total_turns == turns_before_route + 1
		and not main.auto_travel_active,
		"Cancelling known-stairs travel during its delay must prevent a stale extra turn",
	)
	main._resume_from_main_menu()
	main.auto_step_delay_override = 0.0

	main.queue_free()
	await tree.process_frame


func _exploration_floor() -> Dictionary:
	var tiles := {}
	for y in range(3):
		for x in range(17):
			tiles[Vector2i(x, y)] = "wall"
	for x in range(1, 16):
		tiles[Vector2i(x, 1)] = "floor"
	return {
		"width": 17,
		"height": 3,
		"tiles": tiles,
		"start": Vector2i(1, 1),
		"base_gate": Vector2i(1, 1),
		"exit": Vector2i(15, 1),
		"exit_known": false,
		"cradle": Vector2i(-1, -1),
		"cradle_known": false,
		"cradle_pity_resolved": true,
		"cradle_used": false,
		"items": [],
		"visible_cells": {},
		"explored_cells": {},
		"observed_cells": {},
		"enemies": [],
	}


func _magic_floor() -> Dictionary:
	var tiles := {}
	for y in range(5):
		for x in range(7):
			tiles[Vector2i(x, y)] = "wall"
	for cell in [
		Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
		Vector2i(4, 2), Vector2i(5, 2), Vector2i(3, 4),
	]:
		tiles[cell] = "floor"
	return {
		"width": 7,
		"height": 5,
		"tiles": tiles,
		"start": Vector2i(1, 2),
		"base_gate": Vector2i(1, 2),
		"exit": Vector2i(5, 2),
		"exit_known": false,
		"cradle": Vector2i(-1, -1),
		"cradle_known": false,
		"cradle_pity_resolved": true,
		"cradle_used": false,
		"items": [],
		"visible_cells": {},
		"explored_cells": {},
		"enemies": [],
	}


func _set_magic_enemies(main, primary_hp: int, ricochet_hp: int) -> void:
	main.floor_data["enemies"] = [
		_magic_enemy("primary", Vector2i(3, 2), primary_hp, "grave_rat"),
	]
	if ricochet_hp >= 0:
		main.floor_data["enemies"].append(
			_magic_enemy("ricochet", Vector2i(3, 4), ricochet_hp, "hollow_guard")
		)


func _magic_enemy(uid: String, position: Vector2i, hp: int, enemy_id: String) -> Dictionary:
	return {
		"uid": uid,
		"id": enemy_id,
		"pos": position,
		"hp": hp,
		"max_hp": hp,
		"damage": 0,
		"accuracy": 0,
		"dodge": 99,
		"vision": 0,
		"souls": int(GameRules.ENEMIES[enemy_id]["souls"]),
	}


func _select_enemy(main, uid: String) -> void:
	for enemy in main.floor_data["enemies"]:
		if enemy["uid"] == uid:
			main.inspected_target = {"kind": "enemy", "uid": uid, "entity": enemy}
			return
	main.inspected_target.clear()


func _enemy_hp(main, uid: String) -> int:
	for enemy in main.floor_data["enemies"]:
		if enemy["uid"] == uid:
			return int(enemy["hp"])
	return -1


func _reset_magic_cast(main) -> void:
	main.state.mana = main.state.get_max_mana()
	main.state.mana_regeneration_progress = 0.0
	main.magic_traces.clear()
	main.inspected_target.clear()


func _binding_exists(action: String, expected: InputEvent) -> bool:
	for event in InputMap.action_get_events(action):
		if InputProfile.events_equivalent(event, expected):
			return true
	return false


func _write_json(path: String, data: Variant) -> Error:
	return _write_text(path, JSON.stringify(data))


func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	return OK


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		failures.append(failure_message)
