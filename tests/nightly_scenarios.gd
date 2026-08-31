extends RefCounted

const Save := preload("res://scripts/system/persistence.gd")
const Snapshot := preload("res://scripts/system/run_snapshot.gd")
const ACTION_LIMIT := 5000
var failures: Array[String] = []
var case_root := ""
var phase := ""
var seed_value := 0
var action_count := 0
var slot_serial := 0
var journal: FileAccess


func run(tree: SceneTree, phase_value: String, seed_argument: int) -> Array[String]:
	phase = phase_value
	seed_value = seed_argument
	case_root = OS.get_environment("ALMSTH_NIGHTLY_ROOT").path_join("fixtures").path_join(str(seed_value))
	DirAccess.make_dir_recursive_absolute(case_root)
	journal = FileAccess.open(case_root.path_join(phase + ".trace.jsonl"), FileAccess.WRITE)
	_record("scenario", {"phase": phase, "seed": seed_value, "action_limit": ACTION_LIMIT, "process_id": OS.get_process_id()})
	match phase:
		"settings": await _settings(tree)
		"prepare": await _prepare(tree)
		"resume": await _resume_and_die(tree)
		"death-resume": await _death_resume(tree)
		"auto": await _auto_and_speed(tree)
		_: _expect(false, "Unknown nightly phase " + phase)
	_record("result", {"failures": failures, "actions": action_count})
	journal.close()
	return failures


func _new_main(tree: SceneTree, suffix := ""):
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	main.save_slots_directory = case_root.path_join("saves" + suffix)
	main.legacy_save_path = case_root.path_join("missing-legacy.json")
	main.settings_path = case_root.path_join("settings" + suffix + ".cfg")
	main.save_time_provider = func() -> int: return 2000
	main.save_id_factory = func() -> String:
		slot_serial += 1
		return "%s-%d" % [phase, slot_serial]
	tree.root.add_child(main)
	await tree.process_frame
	main.state.configure_character("Nightly %d" % seed_value, GameRules.default_attributes())
	main._show_base("nightly fixture", "none")
	main.rng.seed = seed_value
	main.persistence_enabled = true
	return main


func _settings(tree: SceneTree) -> void:
	# This default path is private: the entry guard ran before opening any file.
	var sentinel := "[nightly_sentinel]\nvalue=\"unchanged\"\n[audio]\nbackground_volume=37\n"
	var file := FileAccess.open(Save.SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(sentinel)
	file.close()
	var private_path := case_root.path_join("injected-settings.cfg")
	Save.save_settings({"audio": {"background_volume": 11}}, private_path)
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = true
	main.audio_playback_enabled = false
	main.settings_path = private_path
	main.save_slots_directory = case_root.path_join("settings-slots")
	main.legacy_save_path = case_root.path_join("no-legacy.json")
	tree.root.add_child(main)
	await tree.process_frame
	_expect(main.background_volume == 11, "Main must read the injected settings path before ready")
	main.background_volume = 23
	main._open_settings()
	main._close_settings()
	_expect(Save.load_settings(private_path).get("audio", {}).get("background_volume") == 23, "Closing settings must write the injected path")
	_expect(FileAccess.get_file_as_string(Save.SETTINGS_PATH) == sentinel, "Settings injection must leave the private default sentinel unchanged")
	main.queue_free()
	await tree.process_frame
	# Exercise the formerly leaking existing fixture, including its settings UI.
	failures.append_array(await preload("res://tests/save_slots_test.gd").new().run(tree))
	_expect(FileAccess.get_file_as_string(Save.SETTINGS_PATH) == sentinel, "Existing save-slot suite must never write default settings")
	_record("settings sentinel", {"default_path": ProjectSettings.globalize_path(Save.SETTINGS_PATH), "unchanged": FileAccess.get_file_as_string(Save.SETTINGS_PATH) == sentinel})


func _prepare(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.save_policy_overwrite = false
	main.state.current_form_id = "zombie"
	main.state.absorbed_souls = 10
	main.state.highest_unlocked_form_index = 4
	main.state.soul_level = 8
	main.state.skill_levels.choose_appearance = 1
	main.state.banked_souls = 200
	main.state.carried_souls = 80
	main.state.lifetime_souls_earned = 500
	main.state.food = 5
	main.state.cradle_miss_streak = 100
	_record("fixture setup", {"previously_unlocked_forms": 5, "body": "zombie", "absorbed": 10, "banked": 200, "carried": 80, "lifetime": 500, "soul_level": 8, "appearance_learned": true, "guaranteed_cradle": true})
	main._save_game_at_base("create")
	main._begin_expedition_at(95)
	_record_floor(main)
	var victim: Dictionary = main.floor_data.enemies[0].duplicate(true)
	var direction := _adjacent_direction(main)
	victim.pos = main.player_pos + direction
	victim.hp = 1
	victim.damage = 0
	victim.has_seen_player = true
	victim.last_seen_player = main.player_pos
	main.floor_data.enemies = [victim]
	_record("fixture combat", {"enemy": victim, "removed_other_enemies": true})
	var souls_before: int = main.state.carried_souls
	for _attempt in range(20):
		if main.floor_data.enemies.is_empty():
			break
		_move(main, direction)
	_expect(main.floor_data.enemies.is_empty(), "Bounded real attacks must kill the fixture enemy")
	_expect(main.state.carried_souls == souls_before + int(victim.souls), "A real kill must award carried souls without banking them")
	var chest: Dictionary = main.floor_data.items[0].duplicate(true)
	var shortest_route: int = main._find_floor_path(main.player_pos, chest.pos).size()
	for candidate in main.floor_data.items:
		var route: Array[Vector2i] = main._find_floor_path(main.player_pos, candidate.pos)
		if not route.is_empty() and route.size() < shortest_route:
			chest = candidate.duplicate(true)
			shortest_route = route.size()
	# The nearest reachable chest has no other chest earlier on its shortest
	# route, so the strict one-chest material delta is meaningful on every seed.
	var chest_key := GameRules.make_item_key(chest.id)
	_record("generated chest target", chest)
	var inventory_before: int = main.state.inventory.get(chest_key, 0)
	var wood_before: int = main.state.resources.wood
	_move_to(main, chest.pos)
	_expect(main.state.inventory.get(chest_key, 0) == inventory_before + 1 and main.state.resources.wood == wood_before + int(chest.wood), "Walking to an actual generated chest must grant item and materials")
	_move_to(main, main.floor_data.cradle)
	var carried_before: int = main.state.carried_souls
	var banked_before: int = main.state.banked_souls
	_evolve(main)
	_expect(main.state.current_form_id == "ghoul" and main.state.absorbed_souls == 24 and main.state.carried_souls == carried_before - 14 and main.state.banked_souls == banked_before, "Cradle evolution must charge carried souls and update only body progress")
	_expect(not main.state.uses_hunger() and not main.state.has_hearing(), "Actual ghoul requires Stomach/Ears purchases")
	var total_before: int = main.state.get_total_souls()
	main._show_character()
	main._on_skill_purchase_pressed("stomach")
	_record("purchase", {"skill": "stomach", "state": main.state.to_snapshot_data()})
	main._on_skill_purchase_pressed("ears")
	main._close_character()
	_expect(main.state.uses_hunger() and main.state.has_hearing() and main.state.get_total_souls() == total_before - 40, "Expedition skill purchases must spend souls and immediately enable their actual-form systems")
	# Explicit combat/survival checkpoint fixture: the restart must handle live,
	# damaged pursuit and hidden attack memory, not just an empty explored floor.
	var pursuer: Dictionary = victim.duplicate(true)
	pursuer.uid = "restart-pursuer"
	pursuer.pos = main.player_pos + _adjacent_direction(main)
	pursuer.hp = 12
	pursuer.max_hp = 20
	pursuer.damage = 1
	pursuer.accuracy = 100
	pursuer.vision = 10
	pursuer.attack_type = "melee"
	pursuer.last_seen_player = main.player_pos
	main.floor_data.enemies = [pursuer]
	var hidden: Dictionary = victim.duplicate(true)
	hidden.uid = "restart-hidden"
	hidden.pos = _unoccupied_hall_cell(main, true)
	hidden.hp = 2
	hidden.max_hp = 3
	hidden.vision = 0
	hidden.has_seen_player = false
	hidden.erase("last_seen_player")
	main.floor_data.enemies.append(hidden)
	if main.floor_data.items.is_empty():
		main.floor_data.items.append({"uid": "restart-chest", "id": "bone_bow", "pos": _unoccupied_hall_cell(main), "wood": 1, "stone": 1, "appearance": "chest"})
	main.state.skill_levels.dash = 1
	main.state.ability_cooldowns = {"dash": 5}
	main.state.add_or_refresh_status("rested", 12, 2)
	main.state.hp = main.state.get_max_hp() - 2
	main.state.hunger = 63
	main.state.hunger_turn_progress = 9
	main._update_player_visibility(false)
	main.hearing_contacts.record_hidden_attack(hidden.uid, hidden.pos, main.state.total_turns)
	_record("restart fixture", {"pursuer": pursuer, "hidden": hidden, "statuses": main.state.active_statuses, "cooldowns": main.state.ability_cooldowns, "hunger": 63, "hunger_progress": 9, "remaining_items": main.floor_data.items, "hearing": main.hearing_contacts.to_snapshot_data()})
	_expect(main.floor_data.enemies.size() == 2 and not main.floor_data.items.is_empty() and main.hearing_contacts.attack_memory_count() == 1, "Restart fixture must include live enemies, remaining loot and hidden attack TTL")
	_expect(main._save_game_at_base(), "Nonempty restart fixture must save successfully")
	# Keep one file family frozen for the next process while this session continues.
	var frozen_dir := case_root.path_join("restart-slots")
	DirAccess.make_dir_recursive_absolute(frozen_dir)
	var frozen_id: String = main.active_save_slot_id
	DirAccess.copy_absolute(main.save_slots_directory.path_join(frozen_id + ".json"), frozen_dir.path_join(frozen_id + ".json"))
	var checkpoint := {"slot_id": frozen_id, "world": _world(main), "prepare_pid": OS.get_process_id()}
	main.persistence_enabled = false
	main._on_wait_pressed()
	checkpoint.next_world = _world(main)
	_expect(main.state.cooldown_remaining("dash") == 4 and main.state.status_remaining("rested") == 11 and main.hearing_contacts.attack_memory_count() == 0, "The uninterrupted next round must tick real status/cooldown and hearing TTL")
	main._on_save_slot_load_requested(frozen_id)
	main.persistence_enabled = true
	main.floor_data.enemies.clear()
	main._clear_hearing_context()
	_record("fixture teardown", {"removed_restart_combat_actors": true, "reason": "finish uncontested route to base after freezing combat checkpoint"})
	_move_to(main, main.floor_data.base_gate)
	var delivered: int = main.state.carried_souls
	banked_before = main.state.banked_souls
	var statuses_before_return: Dictionary = main.state.active_statuses.duplicate(true)
	main._on_interact_pressed()
	_record("safe return", {"delivered": delivered, "state": main.state.to_snapshot_data()})
	_expect(delivered > 0 and main.screen == main.Screen.BASE and main.state.carried_souls == 0 and main.state.banked_souls == banked_before + delivered and main.state.rope_floor == 95, "Safe return must bank only carried souls and anchor the rope")
	_expect(main.state.active_statuses == statuses_before_return and main.state.camp_preparation.pending and main.state.hp == main.state.get_max_hp() and main.state.hunger == 100, "Real safe return heals and earns departure effects without refreshing timed buffs")
	checkpoint.base_world = _world(main)
	checkpoint.base_slot = main.active_save_slot_id
	_write_checkpoint("prepare", checkpoint)
	main.queue_free()
	await tree.process_frame


func _resume_and_die(tree: SceneTree) -> void:
	var checkpoint := _read_checkpoint("prepare")
	_expect(int(checkpoint.get("prepare_pid", 0)) != OS.get_process_id(), "Restart check must execute in a genuinely different process")
	var main = await _new_main(tree)
	var active_dir: String = main.save_slots_directory
	main.save_slots_directory = case_root.path_join("restart-slots")
	main._on_save_slot_load_requested(checkpoint.slot_id)
	_expect(_world(main) == checkpoint.world, "Process restart must retain the complete dungeon world and RNG")
	_expect(not main.auto_travel_active and not main.auto_explore_active, "Process restart must not resume AUTO")
	main._on_wait_pressed()
	_record("post-restart wait", {"world": _world(main)})
	_expect(_world(main) == checkpoint.next_world, "The first real action after process restart must equal uninterrupted execution")
	main.save_slots_directory = active_dir
	main._show_startup()
	main.save_menu_panel.continue_button.pressed.emit()
	_expect(main.active_save_slot_id == checkpoint.base_slot and _world(main) == checkpoint.base_world, "Same-second startup Continue must load the latest safe return without extra buffs")
	main._on_start_pressed()
	main._on_rope_ascent_pressed()
	_record_floor(main)
	_expect(main.state.current_floor == 95 and main.state.current_form_id == "ghoul", "Rope ascent after restart must retain form and return to floor 95")
	_expect(main.state.status_remaining("satiated") == 400 and main.state.status_remaining("rested") == 500 and not main.state.camp_preparation.pending, "Departure after process restart grants earned effects exactly once")
	var bound_knife := GameRules.make_item_key("bone_knife", 0, true)
	var bound_gloves := GameRules.make_item_key("leather_gloves", 0, true)
	main.state.add_item_key(bound_knife)
	main.state.add_item_key(bound_gloves)
	main.state.add_item("grave_mace")
	_expect(main.state.inventory.has(GameRules.make_item_key("grave_mace")), "Death fixture must contain the unbound item before the lethal action")
	main._show_character()
	for item in [bound_knife, bound_gloves]:
		main.inventory_panel.bind_state(main.state, false)
		main.inventory_panel.select_item(item, "inventory")
		main._on_inventory_equip_pressed()
	main._close_character()
	_expect(main.state.loadout.get("right_hand") == bound_knife and main.state.loadout.get("hands") == bound_gloves, "Death fixture must equip bound compatible and incompatible items through equipment handlers")
	var attacker: Dictionary = main.floor_data.enemies[0].duplicate(true)
	attacker.pos = main.player_pos + _adjacent_direction(main)
	attacker.damage = 1000
	attacker.accuracy = 1000
	attacker.vision = 10
	attacker.attack_type = "melee"
	attacker.has_seen_player = true
	attacker.last_seen_player = main.player_pos
	main.floor_data.enemies = [attacker]
	main.state.hp = 1
	main.state.carried_souls = 17
	_record("fixture lethal enemy", {"enemy": attacker, "carried": 17, "hp": 1, "bound_knife": bound_knife, "bound_gloves": bound_gloves, "unbound_added": "grave_mace"})
	var permanent := {"banked": main.state.banked_souls, "rope": main.state.rope_floor, "skills": main.state.skill_levels.duplicate(true), "soul_level": main.state.soul_level}
	main._on_wait_pressed()
	_record("lethal completed action", {"screen": main.screen, "state": main.state.to_snapshot_data(), "slot": main.active_save_slot_id})
	_expect(main.screen == main.Screen.STORY and main.story_kind == "death", "An actual enemy response must reach death story")
	_expect(Save.latest_slot(main.save_slots_directory).get("slot_id") == main.active_save_slot_id, "Same-second death must be the latest durable history slot")
	_write_checkpoint("death", {"state": main.state.to_snapshot_data(), "slot": main.active_save_slot_id, "permanent": permanent, "knife": bound_knife, "gloves": bound_gloves, "death_pid": OS.get_process_id()})
	# No story dismissal and no _request_exit(): terminate this process with the
	# automatic death write as the sole durable boundary under test.
	main.queue_free()
	await tree.process_frame


func _death_resume(tree: SceneTree) -> void:
	var expected := _read_checkpoint("death")
	_expect(int(expected.death_pid) != OS.get_process_id(), "Death recovery must use a different process")
	var main = await _new_main(tree)
	main._show_startup()
	main.save_menu_panel.continue_button.pressed.emit()
	_expect(main.active_save_slot_id == expected.slot and main.state.to_snapshot_data() == expected.state, "Restart before death-story dismissal must load exactly the applied losses")
	_expect(main.screen == main.Screen.BASE and main.state.current_form_id == "skeleton" and main.state.carried_souls == 0 and main.state.absorbed_souls == 0, "Death must reset body and carried souls without a resurrection rollback")
	_expect(main.state.loadout.get("right_hand") == expected.knife and main.state.inventory.get(expected.gloves) == 1 and not main.state.inventory.has(GameRules.make_item_key("grave_mace")), "Death must retain compatible bound equipment, move incompatible bound equipment and remove unbound loot")
	_expect(main.state.banked_souls == expected.permanent.banked and main.state.rope_floor == expected.permanent.rope and main.state.skill_levels == expected.permanent.skills, "Death must preserve bank, rope and learned skills")
	_expect(main.state.soul_level == expected.permanent.soul_level and main.state.loadout.get("jacket") == GameRules.permanent_jacket_key(), "Death must preserve Soul Level and the permanent jacket")
	_expect(main.state.active_statuses.is_empty() and main.state.ability_cooldowns.is_empty(), "Death must clear temporary status and cooldown state")
	main.state.set_display_form_id("ghoul")
	_record("cosmetic fixture", {"display": "ghoul", "actual": "skeleton", "appearance_previously_learned": true})
	_expect(not main.state.uses_hunger() and not main.state.has_hearing(), "Cosmetic Ghoul must not activate learned Stomach/Ears on a skeleton")
	# Delete the loaded active slot, then exercise menu-only exit suppression.
	var deleted_id: String = main.active_save_slot_id
	main._open_main_menu()
	main._on_save_slot_delete_requested(deleted_id)
	var exit_calls: Array[int] = []
	main.exit_request_hook = func() -> void: exit_calls.append(1)
	main._request_exit()
	_expect(exit_calls.size() == 1 and not Save.load_slot(deleted_id, main.save_slots_directory).get("ok", false), "Deleting a loaded active slot and exiting must not recreate it")
	main._resume_from_main_menu()
	main.state.carried_souls = 100
	main.state.cradle_miss_streak = 100
	_record("reevolution fixture", {"carried": 100, "guaranteed_cradles": true, "enemies_removed_for_route": true})
	main._begin_expedition_at(95)
	_expect(main.active_save_slot_id != deleted_id and not main.active_save_slot_id.is_empty(), "The next expedition after Continue must create a fresh slot")
	for target_form in ["zombie", "ghoul"]:
		main.floor_data.enemies.clear()
		main._clear_hearing_context()
		_record_floor(main)
		_move_to(main, main.floor_data.cradle)
		_evolve(main)
		_expect(main.state.current_form_id == target_form, "Reevolution must follow the existing body sequence")
		_expect(main.state.uses_hunger() == (target_form == "ghoul") and main.state.has_hearing() == (target_form == "ghoul"), "Retained Stomach/Ears must reactivate only at the actual Ghoul stage")
		if target_form == "zombie":
			_move_to(main, main.floor_data.exit)
			main.state.cradle_miss_streak = 100
			main._on_ascend_pressed()
	_write_checkpoint("deleted", {"deleted_id": deleted_id, "replacement_id": main.active_save_slot_id, "process_id": OS.get_process_id()})
	main.queue_free()
	await tree.process_frame


func _auto_and_speed(tree: SceneTree) -> void:
	var deleted := _read_checkpoint("deleted")
	_expect(int(deleted.process_id) != OS.get_process_id(), "Deletion must also be checked after a real process restart")
	_expect(not Save.load_slot(deleted.deleted_id, case_root.path_join("saves")).get("ok", false), "A deleted slot must remain absent in the next process")
	_expect(not Save.list_slots(case_root.path_join("saves")).any(func(row: Dictionary) -> bool: return row.slot_id == deleted.deleted_id), "Deleted slot must not reappear in the restarted slot list")
	var main = await _new_main(tree, "-auto")
	main.state.cradle_miss_streak = 100
	main._begin_expedition_at(99)
	main.floor_data.enemies.clear()
	main._clear_hearing_context()
	_record_floor(main)
	_record("AUTO fixture", {"enemies_removed": true, "generated_items_and_rooms_retained": true, "body": "skeleton", "max_steps": ACTION_LIMIT})
	main.auto_step_delay_override = 0.12
	main._on_auto_explore_pressed()
	await tree.create_timer(0.02).timeout
	_expect(main.auto_explore_active, "Generated AUTO must be awaiting its asynchronous timer")
	var turns_before: int = main.state.total_turns
	main._on_wait_pressed()
	var stopped_position: Vector2i = main.player_pos
	await tree.create_timer(0.18).timeout
	_expect(not main.auto_travel_active and main.state.total_turns == turns_before + 1 and main.player_pos == stopped_position, "Manual wait during AUTO timer must execute once with no stale automatic step")
	_record("manual AUTO interruption", {"before_turns": turns_before, "after_turns": main.state.total_turns, "position": main.player_pos})
	main._on_auto_explore_pressed()
	await tree.create_timer(0.02).timeout
	var slot: String = main.active_save_slot_id
	main._on_save_slot_load_requested(slot)
	turns_before = main.state.total_turns
	stopped_position = main.player_pos
	await tree.create_timer(0.18).timeout
	_expect(not main.auto_travel_active and main.state.total_turns == turns_before and main.player_pos == stopped_position, "Load during AUTO timer must invalidate the old coroutine")
	# Complete the actual coroutine, not a copy of its pathfinding loop. Save I/O
	# was covered above; removing its cost keeps the traversal bound practical.
	main.persistence_enabled = false
	main.auto_step_delay_override = 0.0
	var began := Time.get_ticks_msec()
	main._on_auto_explore_pressed()
	var observed_turns: int = main.state.total_turns
	while main.auto_explore_active and main.state.total_turns - turns_before < ACTION_LIMIT and Time.get_ticks_msec() - began < 90000:
		await tree.process_frame
		if main.state.total_turns != observed_turns:
			_record("AUTO step", {"turn": main.state.total_turns, "position": main.player_pos})
			observed_turns = main.state.total_turns
	_expect(not main.auto_explore_active, "Actual generated AUTO must finish within 5000 actions and 90 seconds")
	main._cancel_automatic_actions()
	for room in main.floor_data.rooms:
		_expect(main.floor_data.tiles[room.door] == "floor", "Actual AUTO completion must open every accessible generated room")
	_expect(main.state.current_floor == 99 and not main.floor_data.cradle_used and main.state.absorbed_souls == 0, "AUTO must not use stairs or Cradle")
	_expect(main.state.carried_souls == 0 and main.floor_data.enemies.is_empty(), "Empty-floor AUTO must not invent attacks or soul rewards")
	_record("AUTO completed", {"turns": main.state.total_turns, "elapsed_ms": Time.get_ticks_msec() - began, "rooms": main.floor_data.rooms.size()})
	main.queue_free()
	await tree.process_frame
	var reference := {}
	var previous_delay := INF
	for speed in [100, 150, 200, 225]:
		var paced = await _new_main(tree, "-speed-%d" % speed)
		paced.persistence_enabled = false
		paced._begin_expedition_at(99)
		paced.floor_data.enemies.clear()
		paced._clear_hearing_context()
		paced.auto_movement_speed_percent = speed
		var delay: float = paced._automatic_step_delay_seconds()
		_expect(delay < previous_delay, "Higher movement speed must reduce only the timer delay")
		previous_delay = delay
		var speed_started := Time.get_ticks_msec()
		paced._on_auto_explore_pressed()
		while paced.auto_explore_active and paced.state.total_turns < 5 and Time.get_ticks_msec() - speed_started < 10000:
			await tree.process_frame
		paced._cancel_automatic_actions()
		_expect(paced.state.total_turns == 5, "Each speed must complete exactly five actual AUTO actions within its bound")
		paced._on_wait_pressed()
		await tree.create_timer(delay + 0.02).timeout
		_expect(paced.state.total_turns == 6, "Canceled speed trace must not execute a delayed seventh action")
		var world := _world(paced)
		if reference.is_empty(): reference = world
		else: _expect(world == reference, "100/150/200/225 speed must preserve the identical short command trace state and RNG")
		_record("speed trace", {"speed": speed, "delay": delay, "elapsed_ms": Time.get_ticks_msec() - speed_started, "turns": paced.state.total_turns})
		paced.queue_free()
		await tree.process_frame


func _move_to(main, target: Vector2i) -> void:
	var path: Array[Vector2i] = main._find_floor_path(main.player_pos, target)
	_expect(not path.is_empty(), "Scenario target must be reachable: %s" % target)
	for index in range(1, path.size()):
		if action_count >= ACTION_LIMIT or main.screen != main.Screen.DUNGEON:
			_expect(false, "Scenario route exceeded its bound or left dungeon")
			return
		_move(main, path[index] - main.player_pos)
		if main.player_pos != path[index]:
			_expect(false, "Accepted route command failed to reach %s" % path[index])
			return


func _move(main, direction: Vector2i) -> void:
	action_count += 1
	var before: int = main.state.total_turns
	main._attempt_player_action(direction)
	_record("move/attack", {"direction": direction, "position": main.player_pos, "turn_before": before, "turn_after": main.state.total_turns})


func _evolve(main) -> void:
	main._on_interact_pressed()
	_expect(main.cradle_confirmation_open, "Interaction at generated Cradle must open confirmation")
	main._confirm_cradle_evolution()
	_record("confirm cradle", {"position": main.player_pos, "state": main.state.to_snapshot_data()})


func _adjacent_direction(main) -> Vector2i:
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if main.floor_data.tiles.get(main.player_pos + direction) == "floor" and main._enemy_index_at(main.player_pos + direction) < 0:
			return direction
	_expect(false, "Fixture requires an adjacent unoccupied floor cell")
	return Vector2i.ZERO


func _unoccupied_hall_cell(main, hidden := false) -> Vector2i:
	for cell in main.floor_data.tiles:
		if main.floor_data.tiles[cell] != "floor" or cell == main.player_pos or main._enemy_index_at(cell) >= 0:
			continue
		if main.GridNavigation.is_in_sealed_room(main.floor_data, cell) or (hidden and main._is_cell_visible(cell)):
			continue
		if main.floor_data.items.any(func(item: Dictionary) -> bool: return item.pos == cell):
			continue
		return cell
	_expect(false, "Restart fixture needs a free hall cell")
	return Vector2i(-1, -1)


func _world(main) -> Dictionary:
	return {"context": main._save_context(), "state": main.state.to_snapshot_data(),
		"floor": main.floor_data.duplicate(true) if main._save_context() == "dungeon" else {},
		"position": main.player_pos if main._save_context() == "dungeon" else Vector2i.ZERO,
		"rng_seed": str(main.rng.seed), "rng_state": str(main.rng.state),
		"hearing": main.hearing_contacts.to_snapshot_data() if main._save_context() == "dungeon" else {}}


func _record_floor(main) -> void:
	_record("generated floor", {"floor": main.state.current_floor, "actual_floor_seed": main.floor_data.seed, "player": main.player_pos, "cradle": main.floor_data.cradle})


func _record(event: String, details: Dictionary) -> void:
	journal.store_line(JSON.stringify(Snapshot.encode({"event": event, "details": details})))
	journal.flush()


func _write_checkpoint(name: String, data: Dictionary) -> void:
	var file := FileAccess.open(case_root.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(Snapshot.encode(data)))
	file.close()


func _read_checkpoint(name: String) -> Dictionary:
	var errors: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(case_root.path_join(name + ".json")))
	var result: Variant = Snapshot.decode(parsed, errors)
	_expect(errors.is_empty() and result is Dictionary, "Checkpoint must decode without error: " + name)
	return result if result is Dictionary else {}


func _expect(value: bool, text: String) -> void:
	if not value:
		failures.append(text)
		_record("assertion failed", {"message": text})
