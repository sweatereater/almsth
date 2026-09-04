class_name AutomaticMovementInputTestSuite
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	await _test_manual_command_matrix(main, tree)
	await _test_physical_direction_sources(main, tree)
	_test_two_direction_chords(main)
	_test_held_retaliation(main)
	await _test_pointer_and_hud_parity(main, tree)
	_test_stop_only_and_ignored_inputs(main)
	await _test_no_stale_step_after_manual_cancel(main, tree)
	main.queue_free()
	await tree.process_frame
	Loc.set_locale("ru")
	return failures


func _test_manual_command_matrix(main, _tree: SceneTree) -> void:
	for explore_mode in [true, false]:
		_prepare_dungeon(main)
		_arm(main, explore_mode)
		var before_turns: int = main.state.total_turns
		var keyboard_move := _key(KEY_D)
		main._unhandled_input(keyboard_move)
		_expect(
			main.player_pos == Vector2i(4, 3)
			and main.state.total_turns == before_turns + 1
			and not main.auto_travel_active
			and is_equal_approx(main.movement_repeat_timer, main.MOVE_REPEAT_INITIAL_DELAY),
			"Keyboard movement must cancel %s first, execute once and retain manual hold timing"
			% _mode_name(explore_mode),
		)

		_prepare_dungeon(main)
		_arm(main, explore_mode)
		before_turns = main.state.total_turns
		var gamepad_move := InputEventJoypadButton.new()
		gamepad_move.button_index = JOY_BUTTON_DPAD_RIGHT
		gamepad_move.pressed = true
		main._unhandled_input(gamepad_move)
		_expect(
			main.player_pos == Vector2i(4, 3)
			and main.state.total_turns == before_turns + 1
			and not main.auto_travel_active,
			"Gamepad movement must cancel %s and execute exactly once" % _mode_name(explore_mode),
		)

		for input_command in [
			{"name": "keyboard attack", "event": _key(KEY_F), "message": "MSG_NO_ADJACENT_ENEMY"},
			{"name": "keyboard cast", "event": _key(KEY_Q), "message": "MSG_ABILITY_SLOT_EMPTY"},
			{
				"name": "gamepad attack",
				"event": _joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0),
				"message": "MSG_NO_ADJACENT_ENEMY",
			},
			{
				"name": "gamepad cast",
				"event": _joy_button(JOY_BUTTON_X),
				"message": "MSG_ABILITY_SLOT_EMPTY",
			},
		]:
			_prepare_dungeon(main)
			_arm(main, explore_mode)
			before_turns = main.state.total_turns
			main._unhandled_input(input_command["event"])
			_expect(
				not main.auto_travel_active
				and main.state.total_turns == before_turns
				and main.message == Loc.text(String(input_command["message"])),
				"%s must cancel %s before normal feedback" % [
					input_command["name"], _mode_name(explore_mode),
				],
			)

		for command in [
			{"name": "attack", "call": Callable(main, "_on_attack_pressed"), "message": "MSG_NO_ADJACENT_ENEMY"},
			{"name": "cast", "call": Callable(main, "_on_spell_pressed"), "message": "MSG_ABILITY_SLOT_EMPTY"},
			{"name": "ability slot", "call": Callable(main, "_on_ability_slot_pressed").bind("active_2"), "message": "MSG_ABILITY_SLOT_EMPTY"},
		]:
			_prepare_dungeon(main)
			_arm(main, explore_mode)
			before_turns = main.state.total_turns
			(command["call"] as Callable).call()
			_expect(
				not main.auto_travel_active
				and main.state.total_turns == before_turns
				and main.message == Loc.text(String(command["message"])),
				"Unsuccessful manual %s must cancel %s before normal feedback"
				% [command["name"], _mode_name(explore_mode)],
			)
		for input_command in [
			{
				"name": "camp",
				"event": _device_command(explore_mode, KEY_R, JOY_BUTTON_B),
				"message": "MSG_CAMP_SKELETON",
			},
			{
				"name": "interact",
				"event": _device_command(explore_mode, KEY_SPACE, JOY_BUTTON_A),
				"message": "MSG_NOTHING_TO_USE",
			},
		]:
			_prepare_dungeon(main)
			_arm(main, explore_mode)
			before_turns = main.state.total_turns
			main._unhandled_input(input_command["event"])
			_expect(
				not main.auto_travel_active
				and main.state.total_turns == before_turns
				and main.message == Loc.text(String(input_command["message"])),
				"Manual %s input must cancel %s before normal feedback" % [
					input_command["name"], _mode_name(explore_mode),
				],
			)

		_prepare_dungeon(main)
		main.state.current_form_id = "ghoul"
		main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
		main.state.skill_levels["stomach"] = 1
		main.state.hunger = 100
		main.state.food = 1
		_arm(main, explore_mode)
		main._unhandled_input(_device_command(explore_mode, KEY_R, JOY_BUTTON_B))
		_expect(
			not main.auto_travel_active
			and main.message == Loc.text("MSG_CAMP_FULL")
			and main.state.hunger == 100 and main.state.food == 1,
			"A full-Satiety camp attempt must still cancel %s and report its normal failure"
			% _mode_name(explore_mode),
		)

		_prepare_dungeon(main)
		_arm(main, explore_mode)
		before_turns = main.state.total_turns
		main._unhandled_input(_device_command(explore_mode, KEY_T, JOY_BUTTON_Y))
		_expect(
			not main.auto_travel_active and main.state.total_turns == before_turns + 1,
			"Manual wait must cancel %s and spend exactly one turn" % _mode_name(explore_mode),
		)

		_prepare_dungeon(main)
		_arm(main, explore_mode)
		main._unhandled_input(_device_command(
			explore_mode, KEY_E, JOY_BUTTON_RIGHT_SHOULDER,
		))
		_expect(
			not main.auto_travel_active and main.screen == main.Screen.CHARACTER,
			"Character sheet must cancel %s before opening" % _mode_name(explore_mode),
		)

		_prepare_dungeon(main)
		_arm(main, explore_mode)
		main._unhandled_input(_device_command(explore_mode, KEY_ESCAPE, JOY_BUTTON_START))
		_expect(
			not main.auto_travel_active and main.main_menu_open,
			"Game menu must cancel %s before opening" % _mode_name(explore_mode),
		)


func _test_pointer_and_hud_parity(main, tree: SceneTree) -> void:
	for explore_mode in [true, false]:
		_prepare_dungeon(main)
		_arm(main, explore_mode)
		var before_turns: int = main.state.total_turns
		var touch := InputEventScreenTouch.new()
		touch.index = 4
		touch.pressed = true
		var target: Vector2i = main.player_pos + Vector2i.RIGHT
		touch.position = (
			main.dungeon_viewport.world_to_screen_center(target)
			- main.dungeon_viewport.global_position
		)
		main.dungeon_viewport._gui_input(touch)
		_expect(
			main.player_pos == target
			and main.state.total_turns == before_turns + 1
			and not main.auto_travel_active,
			"Adjacent board touch must cancel %s and move exactly once" % _mode_name(explore_mode),
		)

		_prepare_dungeon(main)
		_arm(main, explore_mode)
		main.inspected_target = {"kind": "tile", "pos": Vector2i(1, 1)}
		main._handle_board_cell(main.player_pos + Vector2i(2, 0))
		_expect(
			main.auto_travel_active
			and main.player_pos == Vector2i(3, 3)
			and main.inspected_target.get("pos") == Vector2i(1, 1),
			"Far inspection click must stay blocked without cancelling %s" % _mode_name(explore_mode),
		)

		_prepare_dungeon(main)
		_arm(main, explore_mode)
		before_turns = main.state.total_turns
		main.wait_button.visible = true
		var center: Vector2 = main.wait_button.get_global_rect().get_center()
		if explore_mode:
			await _click_mouse(main, tree, center)
		else:
			await _tap_touch(main, tree, center)
		_expect(
			not main.auto_travel_active and main.state.total_turns == before_turns + 1,
			"HUD %s wait must cancel %s and execute once" % [
				"mouse" if explore_mode else "touch", _mode_name(explore_mode),
			],
		)


func _test_two_direction_chords(main) -> void:
	_prepare_dungeon(main)
	var tiles := {}
	for y in range(5):
		for x in range(6):
			tiles[Vector2i(x, y)] = "wall"
	for floor_cell in [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2),
	]:
		tiles[floor_cell] = "floor"
	main.floor_data["tiles"] = tiles
	main.floor_data["start"] = Vector2i(1, 1)
	main.floor_data["base_gate"] = Vector2i(0, 0)
	main.floor_data["exit"] = Vector2i(5, 4)
	main.floor_data["visible_cells"] = {}
	main.floor_data["explored_cells"] = {}
	main.floor_data["observed_cells"] = {}
	for cell_variant in tiles:
		main.floor_data["visible_cells"][cell_variant] = true
		main.floor_data["explored_cells"][cell_variant] = true
		main.floor_data["observed_cells"][cell_variant] = true
	main.player_pos = Vector2i(1, 1)
	var turns_before: int = main.state.total_turns
	main._unhandled_input(_action("move_right"))
	main._unhandled_input(_action("move_down"))
	_expect(
		main.player_pos == Vector2i(3, 1)
		and main.held_direction == Vector2i.RIGHT
		and main.held_directions == [Vector2i.RIGHT, Vector2i.DOWN]
		and main.state.total_turns == turns_before + 2
		and main.message != Loc.text("MSG_WALL"),
		"Newest held direction must lead, then geometry-only fallback must use the previous orthogonal direction without a wall action",
	)
	main._attempt_held_movement()
	_expect(
		main.player_pos == Vector2i(3, 2)
		and main.held_direction == Vector2i.DOWN
		and main.state.total_turns == turns_before + 3,
		"A successful fallback must become lead and switch back at the next obstacle",
	)
	var corner_turns: int = main.state.total_turns
	var corner_message: String = main.message
	_expect(
		not main._attempt_held_movement()
		and main.state.total_turns == corner_turns
		and main.message == corner_message
		and main.held_directions.size() == 2,
		"Two blocked held directions must spend no turn, add no wall log, and remain tracked until release",
	)

	# A creature is an ordinary attack target, never a geometry fallback signal.
	_prepare_dungeon(main)
	main.player_pos = Vector2i(3, 3)
	var enemy_rules: Dictionary = GameRules.ENEMIES["hollow_guard"]
	main.floor_data["enemies"] = [{
		"uid": "held-target", "id": "hollow_guard", "pos": Vector2i(4, 3),
		"hp": 50, "max_hp": 50, "damage": 0, "accuracy": 0, "dodge": -100,
		"vision": 0, "souls": int(enemy_rules.souls), "attack_type": "melee", "range": 1,
	}]
	main._register_held_direction(Vector2i.DOWN)
	main._register_held_direction(Vector2i.RIGHT)
	turns_before = main.state.total_turns
	main._attempt_held_movement()
	_expect(
		main.player_pos == Vector2i(3, 3)
		and main.state.total_turns == turns_before + 1
		and bool(main.floor_data["enemies"][0].get("has_seen_player", false)),
		"A live enemy in the leading cell must be attacked instead of triggering fallback",
	)

	# Releasing the lead changes only the lead; movement resumes on the next repeat.
	_prepare_dungeon(main)
	turns_before = main.state.total_turns
	main._unhandled_input(_action("move_right"))
	main._unhandled_input(_action("move_down"))
	var position_before_release: Vector2i = main.player_pos
	var turns_before_release: int = main.state.total_turns
	main._unhandled_input(_action("move_down", false))
	_expect(
		main.player_pos == position_before_release
		and main.state.total_turns == turns_before_release
		and main.held_direction == Vector2i.RIGHT
		and main.held_directions == [Vector2i.RIGHT],
		"Releasing the lead must retain the remaining direction without an immediate extra step",
	)
	main._attempt_held_movement()
	_expect(
		main.player_pos == position_before_release + Vector2i.RIGHT
		and main.state.total_turns == turns_before_release + 1,
		"The remaining held direction must continue on the next repeat",
	)
	main._begin_automatic_action(true)
	main._cancel_automatic_actions_for_manual_command()
	_expect(
		main.held_direction == Vector2i.ZERO and main.held_directions.is_empty()
		and is_equal_approx(main.MOVE_REPEAT_INITIAL_DELAY, 0.28)
		and is_equal_approx(main.MOVE_REPEAT_INTERVAL, 0.11),
		"Stopping transient movement must clear the full held set without changing repeat timing",
	)


func _test_physical_direction_sources(main, tree: SceneTree) -> void:
	# A cardinal stick event releases the opposite axis binding and presses its
	# intended binding at once. Run the complete neutral/cardinal matrix through
	# Godot's real Input singleton so both halves reach production dispatch.
	for fixture in [
		{"axis": JOY_AXIS_LEFT_X, "value": 1.0, "direction": Vector2i.RIGHT},
		{"axis": JOY_AXIS_LEFT_X, "value": -1.0, "direction": Vector2i.LEFT},
		{"axis": JOY_AXIS_LEFT_Y, "value": 1.0, "direction": Vector2i.DOWN},
		{"axis": JOY_AXIS_LEFT_Y, "value": -1.0, "direction": Vector2i.UP},
	]:
		_prepare_dungeon(main)
		main.get_viewport().gui_release_focus()
		var before_position: Vector2i = main.player_pos
		var before_turns: int = main.state.total_turns
		await _parse_input(tree, _joy_motion(fixture.axis, fixture.value))
		_expect(
			main.player_pos == before_position + fixture.direction
			and main.state.total_turns == before_turns + 1
			and main.held_direction == fixture.direction
			and main.held_directions == [fixture.direction],
			"Stick cardinal %s must survive its simultaneous opposite release and move once"
			% fixture.direction,
		)
		await _parse_input(tree, _joy_motion(fixture.axis, 0.0))
		_expect(
			main.held_direction == Vector2i.ZERO and main.held_directions.is_empty(),
			"Stick neutral must release the active cardinal on axis %s" % fixture.axis,
		)

	_prepare_dungeon(main)
	main.get_viewport().gui_release_focus()
	await _parse_input(tree, _joy_motion(JOY_AXIS_LEFT_X, 1.0))
	await _parse_input(tree, _joy_motion(JOY_AXIS_LEFT_Y, -1.0))
	var cross_position: Vector2i = main.player_pos
	var cross_turns: int = main.state.total_turns
	await _parse_input(tree, _joy_motion(JOY_AXIS_LEFT_Y, 0.0))
	_expect(
		main.player_pos == cross_position
		and main.state.total_turns == cross_turns
		and main.held_direction == Vector2i.RIGHT
		and main.held_directions == [Vector2i.RIGHT],
		"Neutral on one stick axis must retain the held cardinal on the other axis",
	)
	main._attempt_held_movement()
	_expect(
		main.player_pos == cross_position + Vector2i.RIGHT
		and main.state.total_turns == cross_turns + 1,
		"The retained cross-axis cardinal must continue on the next repeat",
	)
	await _parse_input(tree, _joy_motion(JOY_AXIS_LEFT_X, 0.0))

	# Move Right has two default keyboard sources (D and Right Arrow). Releasing
	# one must not erase the unique cardinal while the action stays held by the other.
	_prepare_dungeon(main)
	main.get_viewport().gui_release_focus()
	await _parse_input(tree, _key_state(KEY_D, true))
	await _parse_input(tree, _key_state(KEY_RIGHT, true))
	var duplicate_position: Vector2i = main.player_pos
	var duplicate_turns: int = main.state.total_turns
	await _parse_input(tree, _key_state(KEY_D, false))
	_expect(
		main.player_pos == duplicate_position
		and main.state.total_turns == duplicate_turns
		and Input.is_action_pressed("move_right")
		and main.held_direction == Vector2i.RIGHT
		and main.held_directions == [Vector2i.RIGHT],
		"Releasing one physical binding must retain a direction held by another binding",
	)
	main._attempt_held_movement()
	_expect(
		main.player_pos == duplicate_position + Vector2i.RIGHT
		and main.state.total_turns == duplicate_turns + 1,
		"The duplicate-bound action must continue on the next repeat",
	)
	await _parse_input(tree, _key_state(KEY_RIGHT, false))
	_expect(
		not Input.is_action_pressed("move_right")
		and main.held_direction == Vector2i.ZERO
		and main.held_directions.is_empty(),
		"Releasing the final physical binding must clear the unique cardinal",
	)


func _test_held_retaliation(main) -> void:
	_prepare_dungeon(main)
	var rules: Dictionary = GameRules.ENEMIES.hollow_guard
	main.floor_data.enemies = [{
		"uid": "held-retaliator", "id": "hollow_guard", "pos": Vector2i(4, 3),
		"hp": 50, "max_hp": 50, "damage": 1, "accuracy": 100, "dodge": -100,
		"vision": 8, "souls": int(rules.souls), "attack_type": "melee", "range": 1,
		"has_seen_player": true, "last_seen_player": main.player_pos,
	}]
	var hp_before: int = main.state.hp
	var turns_before: int = main.state.total_turns
	main._unhandled_input(_action("move_right"))
	var enemy_hp_after_first: int = main.floor_data.enemies[0].hp
	_expect(
		main.player_pos == Vector2i(3, 3)
		and main.state.total_turns == turns_before + 1
		and main.state.hp == hp_before - 1
		and enemy_hp_after_first < 50
		and main.held_direction == Vector2i.RIGHT
		and main.held_directions == [Vector2i.RIGHT]
		and is_equal_approx(main.movement_repeat_timer, main.MOVE_REPEAT_INITIAL_DELAY),
		"A surviving adjacent retaliator must not clear the held attack or its timing",
	)
	main._attempt_held_movement()
	_expect(
		main.state.total_turns == turns_before + 2
		and main.state.hp == hp_before - 2
		and int(main.floor_data.enemies[0].hp) < enemy_hp_after_first
		and main.held_direction == Vector2i.RIGHT
		and main.held_directions == [Vector2i.RIGHT],
		"The next held repeat must attack and allow retaliation again",
	)
	main._stop_held_movement()


func _test_stop_only_and_ignored_inputs(main) -> void:
	for explore_mode in [true, false]:
		for action in ["auto_explore", "ascend_floor"]:
			_prepare_dungeon(main)
			_arm(main, explore_mode)
			var before_generation: int = main.automatic_action_generation
			var before_turns: int = main.state.total_turns
			main._unhandled_input(_action(action))
			_expect(
				not main.auto_travel_active
				and not main.auto_explore_active
				and main.automatic_action_generation == before_generation + 1
				and main.state.total_turns == before_turns
				and main.player_pos == Vector2i(3, 3),
				"%s during %s must be stop-only in the same press" % [
					action, _mode_name(explore_mode),
				],
			)

	_prepare_dungeon(main)
	_arm(main, false)
	main.auto_explore_button.pressed.emit()
	_expect(
		not main.auto_travel_active and main.state.total_turns == 0,
		"Auto Explore HUD button must stop a stairs route without switching modes",
	)
	_prepare_dungeon(main, true)
	_arm(main, true)
	main.interact_button.pressed.emit()
	_expect(
		not main.auto_travel_active and main.state.total_turns == 0,
		"Ascend HUD button must stop auto-explore without starting a route",
	)

	_prepare_dungeon(main)
	_arm(main, true)
	var generation: int = main.automatic_action_generation
	var release := _action("move_right", false)
	main._unhandled_input(release)
	var echo := _key(KEY_D)
	echo.echo = true
	main._unhandled_input(echo)
	var deadzone := InputEventJoypadMotion.new()
	deadzone.axis = JOY_AXIS_LEFT_X
	deadzone.axis_value = 0.2
	main._unhandled_input(deadzone)
	main._handle_board_cell(Vector2i(-1, -1))
	_expect(
		main.auto_travel_active and main.automatic_action_generation == generation,
		"Release, echo, sub-deadzone input and invalid taps must not cancel automation",
	)


func _test_no_stale_step_after_manual_cancel(main, tree: SceneTree) -> void:
	for explore_mode in [true, false]:
		_prepare_corridor(main, explore_mode)
		main.auto_step_delay_override = 0.05
		var before_turns: int = main.state.total_turns
		if explore_mode:
			main._on_auto_explore_pressed()
		else:
			main._on_ascend_pressed()
		_expect(
			main.player_pos == Vector2i(2, 1)
			and main.state.total_turns == before_turns + 1
			and main.auto_travel_active,
			"%s must take its first step before awaiting" % _mode_name(explore_mode),
		)
		main._unhandled_input(_action("move_right"))
		var manual_position: Vector2i = main.player_pos
		var turns_after_manual: int = main.state.total_turns
		_expect(
			manual_position == Vector2i(3, 1)
			and turns_after_manual == before_turns + 2
			and not main.auto_travel_active,
			"Manual movement must execute once while cancelling awaited %s" % _mode_name(explore_mode),
		)
		await tree.create_timer(0.08).timeout
		_expect(
			main.player_pos == manual_position and main.state.total_turns == turns_after_manual,
			"Cancelled %s coroutine must not take a stale post-await step" % _mode_name(explore_mode),
		)
	main.auto_step_delay_override = 0.0


func _prepare_dungeon(main, exit_known := false) -> void:
	if main.main_menu_open:
		main._resume_from_main_menu()
	if main.screen == main.Screen.CHARACTER:
		main._close_character()
	main._cancel_automatic_actions()
	main.state = RunState.new()
	main.state.configure_character("Manual override", GameRules.default_attributes())
	main.state.current_floor = 99
	main.screen = main.Screen.DUNGEON
	main.floor_data = _open_floor(exit_known)
	main.player_pos = Vector2i(3, 3)
	main._stop_held_movement()
	main.wait_turn_count = 1
	main.action_history.clear()
	main.message = ""
	main.inspected_target.clear()
	main.ability_targeting_id = ""
	main._apply_dungeon_layout(true)
	main.dungeon_viewport.visible = true
	main.wait_button.visible = true
	main.interact_button.visible = true
	main.auto_explore_button.visible = true
	main._refresh_interface()


func _prepare_corridor(main, explore_mode: bool) -> void:
	_prepare_dungeon(main, not explore_mode)
	var tiles := {}
	for y in range(3):
		for x in range(8):
			tiles[Vector2i(x, y)] = "wall"
	for x in range(1, 7):
		tiles[Vector2i(x, 1)] = "floor"
	main.floor_data = {
		"width": 8, "height": 3, "tiles": tiles,
		"start": Vector2i(1, 1), "base_gate": Vector2i(0, 0),
		"exit": Vector2i(6, 1), "exit_known": not explore_mode,
		"cradle": Vector2i(-1, -1), "cradle_known": false,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [], "enemies": [], "visible_cells": {},
		"explored_cells": {}, "observed_cells": {},
	}
	main.player_pos = Vector2i(1, 1)
	for x in range(1, 7):
		main.floor_data["visible_cells"][Vector2i(x, 1)] = true
		main.floor_data["explored_cells"][Vector2i(x, 1)] = true
		main.floor_data["observed_cells"][Vector2i(x, 1)] = true
	main._refresh_interface()


func _open_floor(exit_known: bool) -> Dictionary:
	var tiles := {}
	var known := {}
	for y in range(7):
		for x in range(7):
			var cell := Vector2i(x, y)
			tiles[cell] = "floor"
			known[cell] = true
	return {
		"width": 7, "height": 7, "tiles": tiles,
		"start": Vector2i(3, 3), "base_gate": Vector2i(0, 0),
		"exit": Vector2i(6, 6), "exit_known": exit_known,
		"cradle": Vector2i(-1, -1), "cradle_known": false,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [], "enemies": [],
		"visible_cells": known.duplicate(true),
		"explored_cells": known.duplicate(true),
		"observed_cells": known.duplicate(true),
	}


func _arm(main, explore_mode: bool) -> void:
	main._begin_automatic_action(explore_mode)
	main._refresh_interface()


func _action(action: String, pressed := true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _joy_button(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	return event


func _joy_motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _key_state(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


func _parse_input(tree: SceneTree, event: InputEvent) -> void:
	Input.parse_input_event(event)
	await tree.process_frame


func _device_command(
	keyboard_mode: bool, keycode: Key, button_index: JoyButton,
) -> InputEvent:
	return _key(keycode) if keyboard_mode else _joy_button(button_index)


func _click_mouse(main, tree: SceneTree, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	main.get_viewport().push_input(press, true)
	var release := press.duplicate()
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await tree.process_frame


func _tap_touch(main, tree: SceneTree, position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 6
	press.pressed = true
	press.position = position
	main.get_viewport().push_input(press, true)
	var release := press.duplicate()
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await tree.process_frame


func _mode_name(explore_mode: bool) -> String:
	return "auto-explore" if explore_mode else "stairs route"


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
