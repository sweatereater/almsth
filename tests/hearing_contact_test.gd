class_name HearingContactTestSuite
extends RefCounted

const HearingContacts := preload("res://scripts/game/hearing_contact_system.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")

var failures: Array[String] = []


func run(_tree: SceneTree) -> Array[String]:
	_test_radius_contract()
	_test_proximity_without_los_or_fog_writes()
	_test_attack_memory_ttl_and_priority()
	_test_pruning_and_deduplication()
	_test_renderer_contracts()
	await _test_main_turn_input_and_automation(_tree)
	return failures


func _test_radius_contract() -> void:
	var state := RunState.new()
	_expect(
		state.get_vision_radius() == 4 and state.get_hearing_radius() == 5,
		"Base hearing radius must derive as current vision radius plus one",
	)
	state.skill_levels["sharp_vision"] = 2
	_expect(
		state.get_hearing_radius() == state.get_vision_radius() + 1,
		"Sharp Vision must automatically extend hearing through effective vision",
	)


func _test_proximity_without_los_or_fog_writes() -> void:
	var contacts := HearingContacts.new()
	var visible := {Vector2i(0, 0): true, Vector2i(1, 0): true}
	var visible_before := visible.duplicate(true)
	var enemies := [
		_enemy("d5", Vector2i(3, 2)),
		_enemy("d6", Vector2i(3, 3)),
		_enemy("visible", Vector2i(1, 0)),
		_enemy("dead", Vector2i(2, 0), 0),
	]
	var result := contacts.sync_proximity(enemies, Vector2i.ZERO, 5, visible)
	_expect(
		contacts.presentation_positions() == [Vector2i(3, 2)]
		and result["new_uids"] == ["d5"],
		"Hearing must use inclusive Manhattan distance and exclude visible/dead enemies",
	)
	_expect(visible == visible_before, "Hearing sync must never mutate visibility/fog dictionaries")
	var revision := contacts.event_revision
	contacts.sync_proximity(enemies, Vector2i.ZERO, 5, visible)
	_expect(contacts.event_revision == revision, "Continuous contacts must not retrigger every sync")
	contacts.sync_proximity([], Vector2i.ZERO, 5, visible)
	contacts.sync_proximity(enemies, Vector2i.ZERO, 5, visible)
	_expect(contacts.event_revision == revision + 1, "Disappearance and re-entry must rearm proximity")


func _test_attack_memory_ttl_and_priority() -> void:
	var contacts := HearingContacts.new()
	contacts.record_hidden_attack("archer", Vector2i(9, 9), 10)
	_expect(
		contacts.presentation_positions() == [Vector2i(9, 9)]
		and contacts.attack_memory_count() == 1,
		"A hidden attack must record its origin even outside hearing range",
	)
	contacts.sync_proximity([_enemy("archer", Vector2i(2, 1))], Vector2i.ZERO, 5, {})
	_expect(
		contacts.presentation_positions() == [Vector2i(2, 1)],
		"Current dynamic proximity position must override stale attack origin for one UID",
	)
	contacts.sync_proximity(
		[_enemy("archer", Vector2i(8, 8))], Vector2i.ZERO, 5,
		{Vector2i(9, 9): true},
	)
	_expect(
		contacts.presentation_positions() == [Vector2i(9, 9)],
		"Attack origin must survive after its living owner leaves proximity",
	)
	contacts.prune_after_round(10)
	_expect(contacts.attack_memory_count() == 1, "Attack memory must survive its attack round")
	contacts.prune_after_round(11)
	_expect(contacts.attack_memory_count() == 0, "Attack memory must expire after the next completed round")


func _test_pruning_and_deduplication() -> void:
	var contacts := HearingContacts.new()
	contacts.record_hidden_attack("a", Vector2i(7, 7), 1)
	contacts.record_hidden_attack("b", Vector2i(7, 7), 1)
	_expect(
		contacts.presentation_positions() == [Vector2i(7, 7)],
		"Multiple hidden attackers on one cell must produce one anonymous marker",
	)
	contacts.sync_proximity([_enemy("a", Vector2i(7, 7))], Vector2i.ZERO, 3, {})
	_expect(
		contacts.attack_memory_count() == 1,
		"Missing enemies must immediately lose their attack memories",
	)
	contacts.sync_proximity([_enemy("a", Vector2i(1, 0))], Vector2i.ZERO, 3, {Vector2i(1, 0): true})
	_expect(contacts.presentation_positions().is_empty(), "Visible owners must clear every hearing source")
	contacts.record_hidden_attack("a", Vector2i(1, 0), 2)
	contacts.remove_uid("a")
	_expect(contacts.presentation_positions().is_empty(), "Explicit removal must clear every source for a UID")
	contacts.clear()
	_expect(
		contacts.event_revision == 0 and contacts.presentation_positions().is_empty(),
		"Context clear must reset all ephemeral hearing state",
	)


func _test_renderer_contracts() -> void:
	_expect(
		Renderer.HEARING_MARKER_RADIUS == 13.0
		and Renderer.HEARING_MARKER_OUTLINE_WIDTH == 2.0
		and Renderer.HEARING_MARKER_FONT_SIZE == 22,
		"Hearing marker geometry must stay fixed in virtual pixels at every dungeon zoom",
	)
	var floor := _floor_fixture()
	var cell := Vector2i(6, 3)
	_expect(
		HearingContacts.is_contact_presented(true, floor, Vector2i(2, 3), cell),
		"An unknown or remembered empty contact cell must remain drawable",
	)
	floor["enemies"] = [_game_enemy("visible", cell, 0, 0, 0)]
	floor["visible_cells"][cell] = true
	_expect(
		not HearingContacts.is_contact_presented(true, floor, Vector2i(2, 3), cell),
		"A visible enemy must suppress an anonymous marker on the same cell",
	)
	floor["enemies"].clear()
	floor["items"] = [{"uid": "chest", "pos": cell, "id": "bone_knife"}]
	_expect(
		not HearingContacts.is_contact_presented(true, floor, Vector2i(2, 3), cell)
		and not HearingContacts.is_contact_presented(true, floor, cell, cell)
		and not HearingContacts.is_contact_presented(false, floor, Vector2i(2, 3), cell),
		"Visible items and the player must suppress a marker without revealing anything else",
	)
	var original_cell_size := Renderer.runtime_cell_size
	for zoom in [44, 66, 88]:
		Renderer.set_runtime_cell_size(zoom)
		_expect(
			Renderer.HEARING_MARKER_RADIUS == 13.0
			and Renderer.HEARING_MARKER_OUTLINE_WIDTH == 2.0,
			"Hearing marker radius/stroke must not scale with cell size %d" % zoom,
		)
	Renderer.set_runtime_cell_size(original_cell_size)


func _test_main_turn_input_and_automation(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.player_pos = Vector2i(2, 3)
	main.floor_data = _floor_fixture()
	main.floor_data["enemies"] = [_game_enemy("hidden_archer", Vector2i(8, 3), 0, 10, 10)]
	main._update_player_visibility(false)
	_expect(
		main.hearing_contacts.presentation_positions().is_empty(),
		"An enemy at Manhattan six must begin beyond base hearing",
	)

	main._log_action("fixture")
	var turns_before_wait: int = main.state.total_turns
	main.wait_turn_count = 10
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == turns_before_wait + 1
		and main.hearing_contacts.attack_memory_count() == 1,
		"A hidden attack during Wait 10 must finish exactly the current turn and then interrupt",
	)
	_expect(
		main.action_history.has(Loc.text("MSG_HEARING_HIDDEN_ATTACK"))
		and main.action_history[0] == Loc.text("MSG_WAIT_INTERRUPTED_RANGED", [1]),
		"A hidden ranged miss must preserve the incoming-ranged wait priority",
	)
	main.action_history.clear()
	main.floor_data["enemies"][0]["accuracy"] = 100
	main.floor_data["enemies"][0]["damage"] = 1
	var hp_before_hit_wait: int = main.state.get_effective_health()
	var turns_before_hundred_wait: int = main.state.total_turns
	main.wait_turn_count = 100
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == turns_before_hundred_wait + 1
		and main.state.get_effective_health() == hp_before_hit_wait - 1
		and main.action_history[0] == Loc.text("MSG_WAIT_INTERRUPTED_HP", [1]),
		"A hidden ranged hit must preserve HP-loss priority over ranged and hearing reasons",
	)

	# A moving melee enemy can create a pure hearing event without damage or a
	# ranged attack; that event must still stop a multi-turn wait.
	main.action_history.clear()
	main._clear_hearing_context()
	main.floor_data["enemies"] = [_melee_enemy("heard-only", Vector2i(8, 3), 10)]
	main._update_player_visibility(false)
	var hp_before_hearing_wait: int = main.state.get_effective_health()
	var turns_before_hearing_wait: int = main.state.total_turns
	main.wait_turn_count = 10
	main._on_wait_pressed()
	_expect(
		main.state.total_turns == turns_before_hearing_wait + 1
		and main.state.get_effective_health() == hp_before_hearing_wait
		and main.action_history[0] == Loc.text("MSG_WAIT_INTERRUPTED_HEARING", [1]),
		"A pure newly-heard movement event must retain the hearing wait reason",
	)
	main.floor_data["enemies"] = [_game_enemy("hidden_archer", Vector2i(8, 3), 0, 10, 10)]

	var revision_after_miss: int = main.hearing_contacts.event_revision
	main.floor_data["enemies"][0]["accuracy"] = 100
	main.floor_data["enemies"][0]["damage"] = 0
	main._try_enemy_ranged_attack(0, 20)
	_expect(
		main.hearing_contacts.event_revision == revision_after_miss + 1,
		"Both hidden misses and hidden hits must refresh the attack memory event",
	)
	var attack_origin := Vector2i(8, 3)
	main.floor_data["enemies"][0]["pos"] = Vector2i(9, 3)
	main.floor_data["enemies"][0]["vision"] = 0
	main.floor_data["enemies"][0]["range"] = 0
	main._sync_hearing_proximity()
	_expect(
		main.hearing_contacts.presentation_positions() == [attack_origin],
		"Attack memory must retain an exact origin while its hidden owner moves away",
	)

	var turn_before_noise_click: int = main.state.total_turns
	await _send_viewport_mouse_cell(main, tree, attack_origin)
	_expect(
		main.state.total_turns == turn_before_noise_click
		and main.inspected_target == {"kind": "noise", "pos": attack_origin}
		and main._get_inspection_target().get("kind", "") == "noise",
		"Clicking an exact contact must create only anonymous noise inspection and spend no turn",
	)

	# Raw stale contacts hidden under visible subjects are not presented and must
	# not intercept the real mouse/touch behavior for those subjects.
	var visible_enemy_cell := Vector2i(3, 3)
	main.floor_data["enemies"] = [_game_enemy("visible-subject", visible_enemy_cell, 0, 0, 0)]
	main.floor_data["visible_cells"][visible_enemy_cell] = true
	main.hearing_contacts.record_hidden_attack(
		"stale-under-enemy", visible_enemy_cell, main.state.total_turns,
	)
	var turn_before_enemy_mouse: int = main.state.total_turns
	await _send_viewport_mouse_cell(main, tree, visible_enemy_cell)
	_expect(
		main.state.total_turns == turn_before_enemy_mouse + 1
		and String(main.inspected_target.get("kind", "")) == "enemy",
		"A mouse click on a visible enemy must win over a suppressed raw hearing contact",
	)
	var visible_item_cell := Vector2i(5, 4)
	main.floor_data["items"] = [{
		"uid": "visible-item", "pos": visible_item_cell, "id": "bone_knife",
		"wood": 0, "stone": 0,
	}]
	main.floor_data["visible_cells"][visible_item_cell] = true
	main.floor_data["observed_cells"][visible_item_cell] = true
	main.hearing_contacts.record_hidden_attack(
		"stale-under-item", visible_item_cell, main.state.total_turns,
	)
	var turn_before_item_touch: int = main.state.total_turns
	await _send_viewport_touch_cell(main, tree, visible_item_cell)
	_expect(
		main.state.total_turns == turn_before_item_touch
		and String(main.inspected_target.get("kind", "")) == "item",
		"A touch on a visible item must win over a suppressed raw hearing contact",
	)
	main.hearing_contacts.record_hidden_attack("stale-under-player", main.player_pos, main.state.total_turns)
	main.inspected_target = {"kind": "noise", "pos": main.player_pos}
	var resolved_player_noise: Dictionary = main._get_inspection_target()
	_expect(
		main.inspected_target.is_empty()
		and String(resolved_player_noise.get("kind", "")) != "noise",
		"A contact suppressed by the player must not revalidate anonymous noise inspection",
	)
	main.floor_data["items"].clear()
	main.floor_data["enemies"] = [_game_enemy("hidden_archer", Vector2i(9, 3), 0, 0, 0)]
	var fallback_noise_cell := Vector2i(8, 3)
	main.hearing_contacts.record_hidden_attack(
		"selected-noise", fallback_noise_cell, main.state.total_turns,
	)
	main.inspected_target = {"kind": "noise", "pos": fallback_noise_cell}
	var visible_decoy := _game_enemy("visible-decoy", Vector2i(3, 3), 0, 0, 0)
	main.floor_data["enemies"].append(visible_decoy)
	main.floor_data["visible_cells"][Vector2i(3, 3)] = true
	main.state.loadout["right_hand"] = "bone_bow@0"
	main.state.skill_levels["magic_awakening"] = 1
	main.state.skill_levels["magic_missile"] = 1
	main.state.mana = main.state.get_max_mana()
	var mana_before_noise_cast: int = main.state.mana
	_expect(
		main._resolve_adjacent_enemy_uid().is_empty()
		and not bool(main._resolve_ranged_target().get("ok", false))
		and not main._cast_magic_missile()
		and main.state.mana == mana_before_noise_cast,
		"A selected noise contact must block melee/ranged/magic fallback to a different visible enemy",
	)
	main.floor_data["enemies"].pop_back()
	var memory_before_noop: int = main.hearing_contacts.attack_memory_count()
	main.ability_targeting_id = "dash"
	main._cancel_ability_targeting(false)
	var noop_turn: int = main.state.total_turns
	var noop_result: bool = main._attempt_player_action(Vector2i(-2, 0))
	_expect(
		not noop_result and main.state.total_turns == noop_turn
		and main.hearing_contacts.attack_memory_count() == memory_before_noop,
		"Cancel and rejected wall actions must not tick or expire attack memories",
	)

	var revision_before_overlays: int = main.hearing_contacts.event_revision
	var memories_before_overlays: int = main.hearing_contacts.attack_memory_count()
	main._open_main_menu()
	main._resume_from_main_menu()
	main._show_character()
	main._close_character()
	_expect(
		main.hearing_contacts.event_revision == revision_before_overlays
		and main.hearing_contacts.attack_memory_count() == memories_before_overlays,
		"Menus and Character must neither clear nor expire hearing memory",
	)

	# The next completed round expires an unrefreshed origin only after its enemy phase.
	main._log_action("expiry")
	main._complete_player_turn()
	_expect(
		main.hearing_contacts.attack_memory_count() == 0,
		"An unrefreshed attack origin must expire after the next complete enemy response",
	)

	# A newly continuous contact interrupts all repeating movement modes, but the
	# single manual move that caused it still commits its normal turn.
	main._clear_hearing_context()
	main.player_pos = Vector2i(2, 3)
	main.floor_data["enemies"] = [_game_enemy("approach", Vector2i(8, 3), 0, 0, 0)]
	main._update_player_visibility(false)
	main.held_direction = Vector2i.RIGHT
	main.auto_explore_active = true
	main.auto_travel_active = true
	var turns_before_move: int = main.state.total_turns
	var moved: bool = main._attempt_player_action(Vector2i.RIGHT)
	_expect(
		moved and main.player_pos == Vector2i(3, 3)
		and main.state.total_turns == turns_before_move + 1,
		"The manual action that discovers a hearing contact must still complete normally",
	)
	_expect(
		main.held_direction == Vector2i.ZERO
		and not main.auto_explore_active and not main.auto_travel_active,
		"A new proximity contact must stop held keyboard/gamepad movement and both automatic routes",
	)

	main.hearing_contacts.record_hidden_attack("clear-me", Vector2i(7, 7), main.state.total_turns)
	main.screen = main.Screen.DUNGEON
	main.player_pos = Vector2i(2, 3)
	main.floor_data["enemies"] = [_game_enemy("sharp-heard", Vector2i(8, 3), 0, 0, 0)]
	main.hearing_contacts.clear()
	main.state.skill_levels["sharp_vision"] = 0
	main._update_player_visibility(false)
	_expect(main.hearing_contacts.presentation_positions().is_empty(), "Distance six must be silent before Sharp Vision")
	main._show_character()
	main.state.skill_levels["sharp_vision"] = 1
	main._update_player_visibility(false)
	_expect(
		main.hearing_contacts.presentation_positions() == [Vector2i(8, 3)],
		"Sharp Vision learned from Character must immediately refresh effective hearing",
	)
	main._close_character()
	main.hearing_contacts.record_hidden_attack("clear-me", Vector2i(7, 7), main.state.total_turns)
	main._show_base("base", "none")
	_expect(main.hearing_contacts.presentation_positions().is_empty(), "Returning to base must clear hearing context")
	main.screen = main.Screen.DUNGEON
	main.hearing_contacts.record_hidden_attack("old-floor", Vector2i(7, 7), main.state.total_turns)
	main._load_floor(99)
	_expect(
		main.hearing_contacts.attack_memory_count() == 0,
		"Floor load must clear old attack snapshots before recomputing current proximity",
	)
	main.hearing_contacts.record_hidden_attack("victory", Vector2i(7, 7), main.state.total_turns)
	main._show_victory()
	_expect(main.hearing_contacts.presentation_positions().is_empty(), "Victory must clear hearing context")
	main.hearing_contacts.record_hidden_attack("new-game", Vector2i(7, 7), main.state.total_turns)
	main._reset_for_new_character()
	_expect(main.hearing_contacts.presentation_positions().is_empty(), "New game must clear hearing context")
	main.hearing_contacts.record_hidden_attack("death", Vector2i(7, 7), main.state.total_turns)
	main._handle_death()
	_expect(main.hearing_contacts.presentation_positions().is_empty(), "Death must clear hearing context")
	main.queue_free()
	await tree.process_frame


func _new_main(tree: SceneTree):
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	main.persistence_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.main_menu_open = false
	main.save_menu_panel.close()
	main.screen = main.Screen.DUNGEON
	main.state = RunState.new()
	main._apply_dungeon_layout(true)
	return main


func _floor_fixture() -> Dictionary:
	var tiles := {}
	for y in range(8):
		for x in range(12):
			tiles[Vector2i(x, y)] = "floor" if x > 0 and x < 11 and y > 0 and y < 7 else "wall"
	return {
		"width": 12, "height": 8, "tiles": tiles,
		"start": Vector2i(2, 3), "base_gate": Vector2i(1, 1), "exit": Vector2i(10, 6),
		"exit_known": false, "cradle": Vector2i(-1, -1), "cradle_known": false,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [], "enemies": [], "visible_cells": {}, "explored_cells": {},
		"observed_cells": {},
	}


func _game_enemy(uid: String, pos: Vector2i, damage: int, vision: int, attack_range: int) -> Dictionary:
	return {
		"uid": uid, "id": "skeletal_archer", "pos": pos,
		"hp": 4, "max_hp": 4, "damage": damage, "accuracy": -100, "dodge": 0,
		"vision": vision, "souls": 1, "attack_type": "ranged", "range": attack_range,
	}


func _melee_enemy(uid: String, pos: Vector2i, vision: int) -> Dictionary:
	return {
		"uid": uid, "id": "grave_rat", "pos": pos,
		"hp": 2, "max_hp": 2, "damage": 0, "accuracy": -100, "dodge": 0,
		"vision": vision, "souls": 1,
	}


func _send_viewport_mouse_cell(main, tree: SceneTree, cell: Vector2i) -> void:
	main._refresh_dungeon_viewport()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = (
		main.dungeon_viewport.world_to_screen_center(cell)
		- main.dungeon_viewport.global_position
	)
	main.dungeon_viewport._gui_input(event)
	await tree.process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = event.position
	main.dungeon_viewport._gui_input(release)
	await tree.process_frame


func _send_viewport_touch_cell(main, tree: SceneTree, cell: Vector2i) -> void:
	main._refresh_dungeon_viewport()
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = (
		main.dungeon_viewport.world_to_screen_center(cell)
		- main.dungeon_viewport.global_position
	)
	main.dungeon_viewport._gui_input(event)
	await tree.process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = event.position
	main.dungeon_viewport._gui_input(release)
	await tree.process_frame


func _enemy(uid: String, pos: Vector2i, hp := 1) -> Dictionary:
	return {"uid": uid, "pos": pos, "hp": hp}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
