class_name ExactResumeTestSuite
extends RefCounted

const SaveSystem := preload("res://scripts/system/persistence.gd")
const Snapshot := preload("res://scripts/system/run_snapshot.gd")
const FloorGeneratorScript := preload("res://scripts/world/floor_generator.gd")
const FixedFloor90Script := preload("res://scripts/world/fixed_floor_90.gd")
const ROOT := "res://.tmp/exact-resume-regression"
var failures: Array[String] = []
var next_id := 0


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_cleanup(ROOT)
	_test_strict_snapshot_schema()
	await _test_fractional_mana(tree)
	await _test_latest_history_publication(tree)
	await _test_exact_roundtrip(tree)
	await _test_mutations_and_lifecycle(tree)
	await _test_boss_and_rng(tree)
	await _test_corruption_and_legacy(tree)
	_cleanup(ROOT)
	return failures


func _test_strict_snapshot_schema() -> void:
	var state := RunState.new()
	state.configure_character("Strict snapshot", GameRules.default_attributes())
	state.current_floor = 99
	var random := RandomNumberGenerator.new()
	random.seed = 160099
	var floor: Dictionary = FloorGeneratorScript.new().generate(99, 160099, 0.0)
	var hearing := {"attack_memories": {}, "event_revision": 0}
	var snapshot := Snapshot.capture("dungeon", floor, floor.start, random, hearing)
	var state_data := state.to_snapshot_data()
	_expect(
		not Snapshot.restore(snapshot, state_data).is_empty(),
		"Canonical procedural v18 snapshot must validate",
	)

	var extra_state := state_data.duplicate(true)
	extra_state["intruder"] = true
	_expect(
		not RunState.is_snapshot_data_valid(extra_state)
		and Snapshot.restore(snapshot, extra_state).is_empty(),
		"Current v18 state must reject unknown top-level fields",
	)
	var extra_envelope := snapshot.duplicate(true)
	extra_envelope["intruder"] = true
	_expect(
		Snapshot.restore(extra_envelope, state_data).is_empty(),
		"Current v18 snapshot envelope must reject unknown fields",
	)
	var missing_rooms := floor.duplicate(true)
	missing_rooms.erase("rooms")
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", missing_rooms, missing_rooms.start, random, hearing),
			state_data,
		).is_empty(),
		"Procedural v18 floors must require the generated rooms collection",
	)
	var empty_rooms := floor.duplicate(true)
	empty_rooms.rooms = []
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", empty_rooms, empty_rooms.start, random, hearing),
			state_data,
		).is_empty(),
		"Procedural v18 floors must retain the generator's two or three rooms",
	)
	var fixed_bypass := missing_rooms.duplicate(true)
	fixed_bypass.fixed_layout = true
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", fixed_bypass, fixed_bypass.start, random, hearing),
			state_data,
		).is_empty(),
		"An ordinary floor cannot claim fixed_layout to bypass procedural rooms",
	)
	var collapsed_landmarks := floor.duplicate(true)
	collapsed_landmarks.exit = collapsed_landmarks.base_gate
	_expect(
		Snapshot.restore(
			Snapshot.capture(
				"dungeon", collapsed_landmarks, collapsed_landmarks.start, random, hearing,
			),
			state_data,
		).is_empty(),
		"Procedural landmarks must remain unique",
	)
	var duplicate_rooms := floor.duplicate(true)
	duplicate_rooms.rooms[1] = duplicate_rooms.rooms[0].duplicate(true)
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", duplicate_rooms, duplicate_rooms.start, random, hearing),
			state_data,
		).is_empty(),
		"Procedural room records and doors must remain distinct",
	)
	var empty_room_cells := floor.duplicate(true)
	empty_room_cells.rooms[0].cells = {}
	_expect(
		Snapshot.restore(
			Snapshot.capture(
				"dungeon", empty_room_cells, empty_room_cells.start, random, hearing,
			),
			state_data,
		).is_empty(),
		"Procedural room cells cannot be empty",
	)
	var partial_room_cells := floor.duplicate(true)
	partial_room_cells.rooms[0].cells.erase(partial_room_cells.rooms[0].cells.keys()[0])
	_expect(
		Snapshot.restore(
			Snapshot.capture(
				"dungeon", partial_room_cells, partial_room_cells.start, random, hearing,
			),
			state_data,
		).is_empty(),
		"Procedural room cells must describe the complete sealed component",
	)
	var enemy_stats := floor.duplicate(true)
	enemy_stats.enemies[0].damage = int(enemy_stats.enemies[0].damage) + 1
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", enemy_stats, enemy_stats.start, random, hearing),
			state_data,
		).is_empty(),
		"Generated enemy immutable stats must match its id and floor depth",
	)
	var enemy_capabilities := floor.duplicate(true)
	enemy_capabilities.enemies[0].attack_type = "ranged"
	enemy_capabilities.enemies[0].range = 100
	_expect(
		Snapshot.restore(
			Snapshot.capture(
				"dungeon", enemy_capabilities, enemy_capabilities.start, random, hearing,
			),
			state_data,
		).is_empty(),
		"Generated enemy attack capabilities must match immutable rules",
	)
	var missing_capability := floor.duplicate(true)
	missing_capability.enemies[0].erase("attack_type")
	_expect(
		Snapshot.restore(
			Snapshot.capture(
				"dungeon", missing_capability, missing_capability.start, random, hearing,
			),
			state_data,
		).is_empty(),
		"Generated enemies must retain their canonical attack capability fields",
	)
	var foreign_enemy_cooldown := floor.duplicate(true)
	foreign_enemy_cooldown.enemies[0].ability_cooldowns = {"dash": 1}
	_expect(
		Snapshot.restore(
			Snapshot.capture(
				"dungeon", foreign_enemy_cooldown, foreign_enemy_cooldown.start,
				random, hearing,
			),
			state_data,
		).is_empty(),
		"Enemy cooldowns must be limited to abilities declared by that enemy id",
	)
	var oversized_item := floor.duplicate(true)
	oversized_item.items[0].wood = 3
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", oversized_item, oversized_item.start, random, hearing),
			state_data,
		).is_empty(),
		"Generated chest resource rolls must remain within 0..2",
	)
	var item_under_player := floor.duplicate(true)
	item_under_player.items[0].pos = item_under_player.start
	_expect(
		Snapshot.restore(
			Snapshot.capture(
				"dungeon", item_under_player, item_under_player.start, random, hearing,
			),
			state_data,
		).is_empty(),
		"Items cannot share the player's or a landmark's cell",
	)

	var extra_hearing := hearing.duplicate(true)
	extra_hearing["intruder"] = true
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", floor, floor.start, random, extra_hearing), state_data,
		).is_empty(),
		"Current hearing snapshots must reject unknown fields",
	)
	var enemy: Dictionary = floor.enemies[0]
	var memory := {
		"uid": String(enemy.uid),
		"pos": enemy.pos,
		"expires_after_turn": state.total_turns + 1,
	}
	var hearing_with_memory := {
		"attack_memories": {String(enemy.uid): memory},
		"event_revision": 1,
	}
	var hearing_state := RunState.new()
	hearing_state.configure_character("Strict hearing", GameRules.default_attributes())
	hearing_state.current_floor = 99
	hearing_state.absorbed_souls = int(GameRules.FORMS.ghoul.threshold)
	hearing_state.lifetime_souls_earned = hearing_state.absorbed_souls
	hearing_state.current_form_id = "ghoul"
	hearing_state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	hearing_state.soul_level = 1
	hearing_state.skill_levels.ears = 1
	var hearing_state_data := hearing_state.to_snapshot_data()
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", floor, floor.start, random, hearing_with_memory),
			state_data,
		).is_empty(),
		"A state without Ears must reject nonempty hearing history",
	)
	_expect(
		not Snapshot.restore(
			Snapshot.capture("dungeon", floor, floor.start, random, hearing_with_memory),
			hearing_state_data,
		).is_empty(),
		"Canonical three-field hearing memory must validate",
	)
	var extra_memory_hearing := hearing_with_memory.duplicate(true)
	extra_memory_hearing.attack_memories[String(enemy.uid)]["intruder"] = true
	_expect(
		Snapshot.restore(
			Snapshot.capture("dungeon", floor, floor.start, random, extra_memory_hearing),
			hearing_state_data,
		).is_empty(),
		"Current hearing memories must reject unknown fields",
	)

	state.current_floor = 90
	var fixed_floor: Dictionary = FixedFloor90Script.create()
	_expect(not fixed_floor.has("rooms"), "Fixed-floor exception fixture must omit rooms")
	_expect(
		not Snapshot.restore(
			Snapshot.capture(
				"dungeon", fixed_floor, fixed_floor.start, random,
				{"attack_memories": {}, "event_revision": 0},
			),
			state.to_snapshot_data(),
		).is_empty(),
		"Canonical fixed floor 90 may omit procedural rooms",
	)
	var missing_boss_abilities := fixed_floor.duplicate(true)
	missing_boss_abilities.enemies[0].erase("abilities")
	_expect(
		Snapshot.restore(
			Snapshot.capture(
				"dungeon", missing_boss_abilities, missing_boss_abilities.start,
				random, {"attack_memories": {}, "event_revision": 0},
			),
			state.to_snapshot_data(),
		).is_empty(),
		"Generated enemies with intrinsic abilities must retain the canonical ability list",
	)
	var missing_boss_block := fixed_floor.duplicate(true)
	for field in ["boss_uid", "boss_defeated", "boss_door", "boss_door_open"]:
		missing_boss_block.erase(field)
	_expect(
		Snapshot.restore(
			Snapshot.capture(
				"dungeon", missing_boss_block, missing_boss_block.start, random,
				{"attack_memories": {}, "event_revision": 0},
			),
			state.to_snapshot_data(),
		).is_empty(),
		"Fixed floor 90 must retain the complete boss/door progression block",
	)
	var defeated_floor := fixed_floor.duplicate(true)
	defeated_floor.enemies.clear()
	defeated_floor.boss_defeated = true
	defeated_floor.boss_door_open = true
	defeated_floor.tiles[defeated_floor.boss_door] = "floor"
	_expect(
		Snapshot.restore(
			Snapshot.capture(
				"dungeon", defeated_floor, defeated_floor.start, random,
				{"attack_memories": {}, "event_revision": 0},
			),
			state.to_snapshot_data(),
		).is_empty(),
		"A defeated boss floor cannot load before its permanent milestone and tail reward",
	)
	var defeated_state := RunState.new()
	defeated_state.configure_character("Defeated boss", GameRules.default_attributes())
	defeated_state.current_floor = 90
	defeated_state.record_enemy_defeat("minotaur")
	_expect(
		not Snapshot.restore(
			Snapshot.capture(
				"dungeon", defeated_floor, defeated_floor.start, random,
				{"attack_memories": {}, "event_revision": 0},
			),
			defeated_state.to_snapshot_data(),
		).is_empty(),
		"A defeated boss floor must validate with its exact permanent milestone and tail reward",
	)


func _test_latest_history_publication(tree: SceneTree) -> void:
	var main = await _new_main(tree, "HistoryOrder")
	main.save_policy_overwrite = false
	main.save_time_provider = func() -> int: return 1000
	var ids := ["a-old", "b-death", "c-return"]
	main.save_id_factory = func() -> String: return String(ids.pop_front())
	_expect(main._save_game_at_base("create"), "Same-second history fixture must create its initial slot")
	main._begin_expedition_at(99)
	main.floor_data.enemies.clear()
	main._clear_hearing_context()
	main._complete_player_turn()
	main._handle_death()
	_expect(main.active_save_slot_id == "b-death", "Death must create the expected second history slot")
	_expect(SaveSystem.latest_slot(main.save_slots_directory).get("slot_id") == "b-death", "The newest death publication must win a same-second tie over the pre-death dungeon")
	var fresh = await _new_main(tree, "HistoryOrderFresh")
	fresh.save_slots_directory = main.save_slots_directory
	fresh._show_startup()
	fresh.save_menu_panel.continue_button.pressed.emit()
	_expect(fresh.screen == fresh.Screen.BASE and fresh.active_save_slot_id == "b-death", "Startup Continue must choose the latest same-second death snapshot")
	# A safe return is another milestone with the same ordering requirement.
	main._advance_story()
	main._begin_expedition_at(99)
	main.player_pos = main.floor_data.base_gate
	main._on_interact_pressed()
	_expect(main.active_save_slot_id == "c-return" and SaveSystem.latest_slot(main.save_slots_directory).get("slot_id") == "c-return", "A same-second safe return must become the latest history publication")
	main.queue_free()
	fresh.queue_free()
	await tree.process_frame


func _test_fractional_mana(tree: SceneTree) -> void:
	var main = await _new_main(tree, "FractionalMana")
	main.state.attributes.wisdom = 2
	main.state.skill_levels.magic_awakening = 1
	main._begin_expedition_at(99)
	main.floor_data.enemies.clear()
	main._clear_hearing_context()
	main.state.mana = 0
	_expect(main.state.get_max_mana() == 15 and main.state.get_mana_regeneration_percent() == 2, "Natural mana fixture must regenerate 0.3 mana per round")
	_expect(main._save_game_at_base(), "Fractional mana initial snapshot must save")
	var resumed = await _new_main(tree, "FractionalManaReload")
	resumed.save_slots_directory = main.save_slots_directory
	resumed.persistence_enabled = false
	resumed._on_save_slot_load_requested(main.active_save_slot_id)
	var saw_negative_remainder := false
	for turn in range(1, 61):
		# Both scenes execute the next full round, with the second scene reloaded
		# at every preceding boundary. Use naturally accumulated values, not a
		# manually assigned binary-exact fraction such as 0.5.
		main._complete_player_turn()
		resumed._complete_player_turn()
		_expect(_world(main) == _world(resumed), "Natural fractional mana next round must match after reload at turn %d" % turn)
		var progress: float = main.state.mana_regeneration_progress
		saw_negative_remainder = saw_negative_remainder or progress < 0.0
		var saved := SaveSystem.load_slot(main.active_save_slot_id, main.save_slots_directory)
		_expect(main.last_save_error.is_empty() and saved.get("state", {}).get("total_turns") == turn, "Every natural mana round must publish, including a tiny negative remainder at turn %d" % turn)
		resumed._on_save_slot_load_requested(main.active_save_slot_id)
		_expect(var_to_bytes(progress) == var_to_bytes(resumed.state.mana_regeneration_progress), "File reload must retain all fractional mana bits at turn %d" % turn)
	_expect(saw_negative_remainder, "Natural mana fixture must exercise the existing rounding epsilon")
	_expect(main.state.mana == main.state.get_max_mana(), "Repeated reloads must preserve the full-mana boundary")
	var invalid: Dictionary = main.state.to_snapshot_data()
	invalid.mana_regeneration_progress = -0.01
	_expect(not RunState.is_snapshot_data_valid(invalid), "Substantially negative mana progress remains invalid")
	invalid = main.state.to_snapshot_data()
	invalid.food = -1
	_expect(not RunState.is_snapshot_data_valid(invalid), "The mana epsilon must never admit a negative resource")
	main.queue_free()
	resumed.queue_free()
	await tree.process_frame


func _new_main(tree: SceneTree, name_value: String):
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	main.save_slots_directory = ROOT.path_join(name_value)
	main.settings_path = ROOT.path_join(name_value + "-settings.cfg")
	main.legacy_save_path = ROOT.path_join("missing-legacy.json")
	main.save_id_factory = func() -> String:
		next_id += 1
		return "slot-%d" % next_id
	tree.root.add_child(main)
	await tree.process_frame
	main.state.configure_character(name_value, GameRules.default_attributes())
	main._show_base("fixture", "none")
	main.persistence_enabled = true
	return main


func _ghoul(main) -> void:
	main.state.current_form_id = "ghoul"
	main.state.absorbed_souls = GameRules.FORMS.ghoul.threshold
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	main.state.soul_level = 8
	main.state.skill_levels.stomach = 1
	main.state.skill_levels.ears = 1
	main.state.skill_levels.flesh_regeneration = 1
	main.state.skill_levels.dash = 1
	main.state.skill_levels.double_attack = 1
	main.state.banked_souls = 200
	main.state.carried_souls = 200
	main.state.lifetime_souls_earned = (
		main.state.banked_souls + main.state.carried_souls + main.state.absorbed_souls
	)
	main.state.food = 3


func _test_exact_roundtrip(tree: SceneTree) -> void:
	var main = await _new_main(tree, "Roundtrip")
	_ghoul(main)
	main.state.current_form_id = "revenant"
	main.state.absorbed_souls = GameRules.FORMS.revenant.threshold
	main.state.skill_levels.nervous_system = 1
	main.state.character_sex = "female"
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
	main.state.lifetime_souls_earned = (
		main.state.banked_souls
		+ main.state.carried_souls
		+ main.state.absorbed_souls
		+ int(GameRules.FORMS.almost_human.threshold)
	)
	main.state.skill_levels.choose_appearance = 1
	main.state.display_form_id = "zombie"
	var claymore_key := GameRules.make_item_key("old_claymore", 3, true)
	var marked_inventory_key := GameRules.make_item_key("bone_knife", 2)
	main.state.loadout["right_hand"] = claymore_key
	main.state.loadout.erase("left_hand")
	main.state.equipped_marks["right_hand"] = "keep"
	main.state.inventory[marked_inventory_key] = 1
	main.state.inventory_marks[marked_inventory_key] = "salvage"
	var stored_key := GameRules.make_item_key("bone_bow", 2, true)
	main.state.storage[stored_key] = 3
	main.state.storage_marks[stored_key] = "keep"
	for upgrade_id in ["campfire", "kettle", "workbench", "writing_set", "storage_chest"]:
		main.state.camp_upgrades[upgrade_id] = true
	main.rng.seed = 9223372036854775701
	main._begin_expedition_at(97)
	# A full generated map with open/closed rooms, changed loot, a removed enemy,
	# damaged pursuit state and partially consumed survival resources.
	main.floor_data.tiles[main.floor_data.rooms[0].door] = "floor"
	main.floor_data.items.remove_at(0)
	main.floor_data.enemies.remove_at(main.floor_data.enemies.size() - 1)
	var enemy: Dictionary = main.floor_data.enemies[0]
	var attack_direction := Vector2i.ZERO
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var adjacent: Vector2i = main.player_pos + direction
		if main.floor_data.tiles.get(adjacent) == "floor" and main._enemy_index_at(adjacent) < 0:
			attack_direction = direction
			enemy.pos = adjacent
			break
	_expect(attack_direction != Vector2i.ZERO, "Combat fixture needs an adjacent floor cell")
	enemy.hp = int(enemy.max_hp)
	enemy.erase("has_seen_player")
	enemy.erase("last_seen_player")
	main.floor_data.enemies[0] = enemy
	var sleeping_bystander_uid := ""
	if main.floor_data.enemies.size() > 1:
		main.floor_data.enemies[1].erase("has_seen_player")
		main.floor_data.enemies[1].erase("last_seen_player")
		sleeping_bystander_uid = String(main.floor_data.enemies[1].uid)
	main._perform_melee_strike(String(enemy.uid), 1)
	_expect(
		bool(main.floor_data.enemies[0].get("has_seen_player", false))
		and main.floor_data.enemies[0].get("last_seen_player") == main.player_pos
		and (
			sleeping_bystander_uid.is_empty()
			or not bool(main.floor_data.enemies[1].get("has_seen_player", false))
		),
		"A real directed attack must create only the target's existing resumable awareness fields",
	)
	main.state.hp = maxi(1, main.state.get_max_hp() - 2)
	main.state.mana = 0
	main.state.hunger = 57
	main.state.hunger_turn_progress = 8
	main.state.regeneration_progress = 2
	main.state.mana_regeneration_progress = 0.735
	main.state.total_turns = 25
	main.state.carried_souls = 17
	main.state.ability_cooldowns = {"dash": 7, "double_attack": 3}
	main.state.add_or_refresh_status("rested", 3, 2)
	main.floor_data.cradle_used = true
	main._update_player_visibility(false)
	var hidden: Dictionary = {}
	for candidate in main.floor_data.enemies:
		if not main.floor_data.visible_cells.has(candidate.pos) and not main.GridNavigation.is_in_sealed_room(main.floor_data, candidate.pos):
			hidden = candidate
			break
	_expect(not hidden.is_empty(), "Generated fixture must have a hidden enemy")
	if not hidden.is_empty():
		main.hearing_contacts.record_hidden_attack(hidden.uid, hidden.pos, main.state.total_turns)
	_expect(main._save_game_at_base(), "Full generated snapshot must save: %s" % main.last_save_error)
	var current_saved := SaveSystem.load_slot(main.active_save_slot_id, main.save_slots_directory)
	_expect(
		current_saved.get("ok", false)
		and int(current_saved.get("version", 0)) == SaveSystem.SAVE_VERSION,
		"Exact full-run roundtrip fixture must publish the strict v18 envelope",
	)
	var expected := _world(main)
	var saved_id: String = main.active_save_slot_id
	var fresh = await _new_main(tree, "Fresh")
	fresh.save_slots_directory = main.save_slots_directory
	fresh.auto_travel_active = true
	fresh.auto_explore_active = true
	fresh.held_direction = Vector2i.RIGHT
	fresh.ability_targeting_id = "dash"
	fresh._on_save_slot_load_requested(saved_id)
	_expect(fresh.screen == fresh.Screen.DUNGEON, "A fresh scene must resume the dungeon, not camp")
	_expect(_world(fresh) == expected, "File roundtrip must retain floor geometry, fog, order, loot, pursuit, HP/mana/hunger/progress/statuses/cooldowns and RNG")
	_expect(
		fresh.state.character_sex == "female"
		and fresh.state.display_form_id == "zombie"
		and fresh.state.loadout.get("right_hand", "") == claymore_key
		and not fresh.state.loadout.has("left_hand")
		and fresh.state.item_mark(claymore_key, "equipped", "right_hand") == "keep"
		and fresh.state.item_mark(marked_inventory_key) == "salvage"
		and fresh.state.storage.get(stored_key, 0) == 3
		and fresh.state.item_mark(stored_key, "storage") == "keep"
		and bool(fresh.state.camp_upgrades.campfire)
		and bool(fresh.state.camp_upgrades.kettle)
		and bool(fresh.state.camp_upgrades.workbench)
		and bool(fresh.state.camp_upgrades.writing_set),
		"v18 roundtrip must retain sex/cosmetic identity, bound/upgraded inventory and Storage marks, and camp dependencies",
	)
	_expect(
		bool(fresh.floor_data.enemies[0].get("has_seen_player", false))
		and fresh.floor_data.enemies[0].get("last_seen_player") == fresh.player_pos
		and (
			sleeping_bystander_uid.is_empty()
			or not bool(fresh.floor_data.enemies[1].get("has_seen_player", false))
		),
		"Exact resume must retain attacked-target awareness without waking a bystander or adding a save field",
	)
	_expect(not fresh.auto_travel_active and not fresh.auto_explore_active and fresh.held_direction == Vector2i.ZERO and fresh.ability_targeting_id.is_empty(), "Loading must clear automation/held input/targeting")
	_expect(fresh.hearing_contacts.attack_memory_count() == main.hearing_contacts.attack_memory_count(), "Hidden-attack memory TTL must survive load")
	# Resume the identical next action from independent scenes, including all RNG
	# draws, enemy decisions, survival ticks and the completed-round autosave.
	var rng_before: int = main.rng.state
	main._attempt_player_action(attack_direction)
	fresh._attempt_player_action(attack_direction)
	_expect(_world(main) == _world(fresh), "Continuous next action must exactly equal the next action after reload")
	_expect(main.rng.state != rng_before, "Combat equivalence must exercise actual random rolls")
	_expect(
		fresh.state.get_temporary_hp() == main.state.get_temporary_hp(),
		"Reload must preserve the pursuing enemy's exact next response without another alert delay",
	)
	_expect(fresh.hearing_contacts.attack_memory_count() == 0, "A saved hidden attack must expire at the same completed-round boundary")
	var completed := SaveSystem.load_slot(fresh.active_save_slot_id, fresh.save_slots_directory)
	_expect(completed.get("state", {}) == fresh.state.to_snapshot_data(), "Round autosave must contain post-survival and post-cooldown values")
	# Actual file-backed generated-floor writes, independent of the persistence-off soak.
	main.floor_data.enemies.clear()
	main._clear_hearing_context()
	var started := Time.get_ticks_usec()
	for _index in range(8):
		main._complete_player_turn()
	var elapsed := Time.get_ticks_usec() - started
	print("EXACT RESUME FILE AUTOSAVE: 8 generated-floor rounds, %.1f ms total, %.1f ms/round" % [elapsed / 1000.0, elapsed / 8000.0])
	_expect(main.last_save_error.is_empty(), "File-backed completed rounds must autosave successfully")
	main.queue_free()
	fresh.queue_free()
	await tree.process_frame


func _test_mutations_and_lifecycle(tree: SceneTree) -> void:
	var main = await _new_main(tree, "Lifecycle")
	main.save_policy_overwrite = false
	_expect(main._save_game_at_base("create"), "History creation must save")
	var initial_id: String = main.active_save_slot_id
	_ghoul(main)
	main._begin_expedition_at(99)
	main.floor_data.enemies.clear()
	main._clear_hearing_context()
	main.state.hunger = 40
	main.state.hunger_turn_progress = 3
	var turns: int = main.state.total_turns
	main._on_camp_pressed()
	_expect(main.state.food == 2 and main.state.hunger > 40, "Food fixture must actually consume food and refill hunger")
	_assert_saved(main, "No-turn food consumption")
	_expect(main.state.total_turns == turns, "Eating must not gain or spend a turn through saving")
	# Cradle payment and its consumed flag publish together.
	var cradle_cell := Vector2i(-1, -1)
	for candidate_value in main.floor_data.tiles:
		var candidate: Vector2i = candidate_value
		if main.floor_data.tiles[candidate] != "floor":
			continue
		if candidate in [
			main.floor_data.start, main.floor_data.exit, main.floor_data.base_gate,
		]:
			continue
		if main._enemy_index_at(candidate) >= 0:
			continue
		var in_room := false
		for room in main.floor_data.rooms:
			in_room = in_room or room.cells.has(candidate)
		if in_room:
			continue
		var has_item := false
		for item in main.floor_data.items:
			has_item = has_item or item.pos == candidate
		if not has_item:
			cradle_cell = candidate
			break
	_expect(cradle_cell != Vector2i(-1, -1), "Cradle fixture needs a unique free floor cell")
	main.floor_data.cradle = cradle_cell
	main.player_pos = cradle_cell
	main.floor_data.cradle_known = true
	main.floor_data.cradle_pity_resolved = true
	main._use_cradle()
	_expect(main.floor_data.cradle_used, "Cradle fixture must evolve successfully")
	_assert_saved(main, "Cradle evolution and used flag")
	main._show_character()
	main.state.unspent_attribute_points = 1
	main._on_spend_attribute_point(GameRules.ATTRIBUTE_ORDER[0])
	_assert_saved(main, "Attribute allocation")
	main._on_skill_purchase_pressed("strong_bones")
	_expect(main.state.get_skill_level("strong_bones") == 1, "Skill fixture must purchase a rank")
	_assert_saved(main, "Dungeon skill purchase")
	main._cycle_ability_loadout("active_1")
	_assert_saved(main, "Ability slot assignment")
	main.state.unspent_attribute_points += 5
	main.state.soul_level += 1
	main.state.carried_souls += 100
	main.state.lifetime_souls_earned += 100
	main._save_game_at_base()
	_assert_saved(main, "Direct high-progression fixture")
	var key: String = main.state.add_item("bone_knife")
	main.character_panel_mode = "inventory"
	main.inventory_panel.bind_state(main.state, false)
	main.inventory_panel.select_item(key, "inventory")
	main._on_inventory_equip_pressed()
	_assert_saved(main, "Dungeon equipment change")
	var equipped_slot := ""
	for slot in main.state.loadout:
		if main.state.loadout[slot] == key:
			equipped_slot = slot
	_expect(not equipped_slot.is_empty(), "Equipment fixture must equip its knife")
	main.inventory_panel.select_item(key, "equipped", equipped_slot)
	main._on_inventory_equip_pressed()
	_assert_saved(main, "Dungeon unequip")
	_expect(not main.state.loadout.has(equipped_slot), "Unequip fixture must remove the equipped knife")
	main._close_character()
	main.state.current_form_id = "almost_human"
	main.state.absorbed_souls = GameRules.FORMS.almost_human.threshold
	main.state.highest_unlocked_form_index = 4
	main.state.lifetime_souls_earned = maxi(
		main.state.lifetime_souls_earned,
		main.state.banked_souls + main.state.carried_souls + main.state.absorbed_souls,
	)
	main.state.skill_levels.choose_appearance = 1
	_expect(main._open_appearance_choice(), "Appearance fixture must open the chooser")
	main._confirm_appearance_choice("skeleton")
	_expect(main.state.display_form_id == "skeleton", "Appearance fixture must change the cosmetic form")
	_assert_saved(main, "No-turn appearance change")
	_expect(main.active_save_slot_id == initial_id and SaveSystem.list_slots(main.save_slots_directory).size() == 1, "Rounds, floor entry and no-turn writes must update one active history slot")
	# Death is durable while its story is still displayed, not only after dismissal.
	main.state.carried_souls = 29
	main._handle_death()
	var death_id: String = main.active_save_slot_id
	var death := SaveSystem.load_slot(death_id, main.save_slots_directory)
	_expect(death_id != initial_id and main.screen == main.Screen.STORY and death.get("snapshot", {}).get("context") == "base", "Death must immediately publish one base-context history milestone")
	_expect(death.get("state", {}).get("carried_souls") == 0 and death.get("state", {}).get("current_form_id") == "skeleton", "Death snapshot must apply losses before any story click")
	var exits: Array[int] = []
	main.exit_request_hook = func() -> void: exits.append(1)
	main._request_exit()
	_expect(exits.size() == 1 and main.active_save_slot_id == death_id, "Quitting during death story must retain losses without a second milestone")
	main._advance_story()
	_expect(main.active_save_slot_id == death_id and SaveSystem.list_slots(main.save_slots_directory).size() == 2, "Death-story dismissal must not duplicate the history milestone")
	main._open_main_menu()
	main._on_save_slot_delete_requested(death_id)
	main._request_exit()
	_expect(not FileAccess.file_exists(main.save_slots_directory.path_join(death_id + ".json")), "Immediate exit after active deletion must not recreate it")
	main._resume_from_main_menu()
	main._open_main_menu()
	main._request_exit()
	_expect(main.active_save_slot_id.is_empty(), "Continue and menu navigation alone must not recreate a deleted slot")
	main._resume_from_main_menu()
	main._begin_expedition_at(99)
	_expect(not main.active_save_slot_id.is_empty() and main.active_save_slot_id != death_id, "The next meaningful write after Continue must get a fresh id")
	main.save_fault_injector = func(_stage: String) -> bool: return true
	var before_failure := SaveSystem.load_slot(main.active_save_slot_id, main.save_slots_directory)
	var exits_before := exits.size()
	main._request_exit()
	_expect(exits.size() == exits_before and main.main_menu_open and not main.last_save_error.is_empty(), "Failed exit save must leave the app open and show an error")
	_expect(SaveSystem.load_slot(main.active_save_slot_id, main.save_slots_directory).get("state") == before_failure.get("state"), "Failed exit save must retain the previous valid save")
	main.queue_free()
	await tree.process_frame


func _test_boss_and_rng(tree: SceneTree) -> void:
	var main = await _new_main(tree, "Boss")
	main.rng.seed = -9223372036854775701
	main._begin_expedition_at(90)
	var boss_save: String = main.active_save_slot_id
	var fresh = await _new_main(tree, "BossFresh")
	fresh.save_slots_directory = main.save_slots_directory
	fresh._on_save_slot_load_requested(boss_save)
	_expect(_world(fresh) == _world(main) and not fresh.floor_data.boss_door_open, "Boss arena before combat must resume unchanged")
	main._damage_enemy_by_uid(main.floor_data.enemies[0].uid, 100000)
	main._complete_player_turn()
	fresh._on_save_slot_load_requested(main.active_save_slot_id)
	_expect(fresh.floor_data.boss_door_open and fresh.floor_data.boss_defeated and fresh.floor_data.enemies.is_empty(), "Boss death, loot and open door must survive reload")
	_expect(_world(fresh) == _world(main), "Boss snapshot after combat must roundtrip")
	main._complete_floor_ascent()
	fresh._complete_floor_ascent()
	_expect(_world(fresh) == _world(main) and fresh.state.current_floor == 89, "Next generated floor and cradle roll must be deterministic across reload")
	main._load_floor(90)
	_expect(
		main.last_save_error.is_empty()
		and main.floor_data.boss_defeated
		and main.floor_data.boss_door_open
		and main.floor_data.enemies.is_empty(),
		"Re-entering floor 90 after the permanent boss milestone must publish the canonical cleared arena",
	)
	main._load_floor(1)
	main._complete_floor_ascent()
	fresh._on_save_slot_load_requested(main.active_save_slot_id)
	_expect(fresh.screen == fresh.Screen.VICTORY and fresh.state.current_floor == 1, "Victory must resume as victory, never base or another floor")
	main.queue_free()
	fresh.queue_free()
	await tree.process_frame


func _test_corruption_and_legacy(tree: SceneTree) -> void:
	var main = await _new_main(tree, "Corruption")
	main._begin_expedition_at(99)
	main._complete_player_turn()
	var id: String = main.active_save_slot_id
	var path: String = main.save_slots_directory.path_join(id + ".json")
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var corruptions: Array[Callable] = [
		func(data: Dictionary): data.erase("snapshot"),
		func(data: Dictionary): data.snapshot.rng_state = 9223372036854775807,
		func(data: Dictionary): data.snapshot.player_pos = {"$cell": [500, 500]},
		func(data: Dictionary): data.snapshot.floor_data.tiles["$cells"].remove_at(0),
		func(data: Dictionary): data.snapshot.floor_data.enemies[0].has_seen_player = [],
		func(data: Dictionary): data.snapshot.floor_data.erase("biome"),
		func(data: Dictionary): data.snapshot.floor_data.erase("initial_enemy_kinds"),
		func(data: Dictionary): data.snapshot.floor_data.erase("decorations"),
		func(data: Dictionary): data.snapshot.floor_data.items[0].erase("appearance"),
		func(data: Dictionary): data.state.active_statuses = {"rested": {"remaining_turns": 900, "temporary_hp": 99}},
		func(data: Dictionary): data.state.mana_regeneration_progress = {"$float64": "bad"},
		func(data: Dictionary): data.state.mana_regeneration_progress = {"$float64": "000000000000f87f"},
		func(data: Dictionary): data.state.loadout.clear(),
	]
	for corrupt in corruptions:
		var malformed := valid.duplicate(true)
		corrupt.call(malformed)
		_write(path, malformed)
		_write(path + ".bak", valid)
		var recovered := SaveSystem.load_slot(id, main.save_slots_directory)
		_expect(recovered.get("ok", false) and recovered.get("recovered_from_backup", false), "Malformed current snapshot must fall back before choosing primary")
		_write(path + ".bak", malformed)
		var unchanged := _world(main)
		main._on_save_slot_load_requested(id)
		_expect(_world(main) == unchanged and not main.last_save_error.is_empty(), "Both malformed current copies must preserve current state, floor and RNG")
	# No valid fallback must leave the current in-memory session untouched.
	_write(path + ".bak", {})
	var before := _world(main)
	main._on_save_slot_load_requested(id)
	_expect(_world(main) == before and not main.last_save_error.is_empty(), "Unrecoverable snapshot must error without changing the current session")
	var legacy: Dictionary = main.state.to_save_data()
	legacy.hp = 1
	legacy.active_statuses = {"rested": {"remaining_turns": 4, "temporary_hp": 1}}
	for version in range(1, SaveSystem.SAVE_VERSION):
		var envelope := valid.duplicate(true)
		envelope.version = version
		envelope.state = legacy
		envelope.erase("snapshot")
		_write(path, envelope)
		main._on_save_slot_load_requested(id)
		_expect(_world(main) == before and not main.last_save_error.is_empty(), "Old test schema v%d must not mutate the active session or silently restart at base" % version)
	main.queue_free()
	await tree.process_frame


func _world(main) -> Dictionary:
	return {"state": main.state.to_snapshot_data(), "floor": main.floor_data.duplicate(true),
		"position": main.player_pos, "rng_seed": str(main.rng.seed), "rng_state": str(main.rng.state),
		"hearing": main.hearing_contacts.to_snapshot_data()}


func _assert_saved(main, label: String) -> void:
	var saved := SaveSystem.load_slot(main.active_save_slot_id, main.save_slots_directory)
	_expect(saved.get("ok", false) and saved.get("state", {}) == main.state.to_snapshot_data(), label + " must autosave exact state")
	_expect(saved.get("snapshot", {}).get("floor_data", {}) == main.floor_data, label + " must autosave the current floor")


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _expect(condition: bool, message_value: String) -> void:
	if not condition:
		failures.append(message_value)


func _cleanup(path: String) -> void:
	assert(path == ROOT or path.begins_with(ROOT + "/"))
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file in directory.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(file)))
	for child in directory.get_directories():
		_cleanup(path.path_join(child))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
