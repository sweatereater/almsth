extends RefCounted

const View := preload("res://scripts/ui/dungeon_viewport.gd")
const AbilitySystem := preload("res://scripts/game/skill_system.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	var generator := FloorGenerator.new()
	for seed_value in range(24):
		var floor_number := 99 - seed_value * 4
		var data := generator.generate(floor_number, seed_value, 1.0)
		failures.append_array(validate_generated(data, floor_number))
		_expect(data == generator.generate(floor_number, seed_value, 1.0), "Generation must repeat seed %d" % seed_value)
	await _test_doors_and_isolation(tree)
	await _test_first_sight(tree)
	await _test_auto_and_camera(tree)
	await _test_generated_auto(tree)
	_test_boss_rewards()
	return failures


static func validate_generated(data: Dictionary, floor_number: int) -> Array[String]:
	var errors: Array[String] = []
	var generator := FloorGenerator.new()
	var tiles: Dictionary = data["tiles"]
	var rooms: Array = data.get("rooms", [])
	if data["width"] != 40 or data["height"] != 40 or rooms.size() < 2 or rooms.size() > 3:
		errors.append("Normal floors need 40x40 cells and exactly 2–3 rooms")
	var hall := generator._reachable_floor_cells(tiles, data["start"])
	if hall.size() < 650:
		errors.append("The connected main hall must dominate the floor")
	for landmark in [data["exit"], data["base_gate"], data["cradle"]]:
		if landmark.x >= 0 and not hall.has(landmark):
			errors.append("Landmarks must be reachable without opening optional rooms")
	var covered := hall.duplicate()
	for room in rooms:
		var door: Vector2i = room["door"]
		var outward: Vector2i = room["outward"]
		var sideways := Vector2i(-outward.y, outward.x)
		if (
			tiles.get(door) != "door_closed" or not hall.has(door + outward)
			or not room["cells"].has(door - outward)
			or tiles.get(door + sideways) != "wall" or tiles.get(door - sideways) != "wall"
		):
			errors.append("Each room needs one airtight door between two floors and two walls")
		var interior := generator._reachable_floor_cells(tiles, door - outward)
		if interior.size() != room["cells"].size():
			errors.append("A closed room must be one isolated connected component")
		for cell in room["cells"]:
			if not interior.has(cell) or covered.has(cell):
				errors.append("Room interiors must not leak into another room or the hall")
			covered[cell] = true
		var enemy_count := _count_in(data["enemies"], room["cells"])
		var chest_count := _count_in(data["items"], room["cells"])
		if enemy_count < 2 or enemy_count > 3 or chest_count > 1:
			errors.append("Every room needs 2–3 extra enemies and 0–1 extra chests")
	if covered.size() != generator._get_floor_cells(tiles).size():
		errors.append("No stray or disconnected floor cells may exist")
	if not generator._all_floor_cells_connected(tiles, true):
		errors.append("Opening ordinary doors must connect the entire floor")
	if _count_in(data["enemies"], hall) != FloorGenerator.enemy_count_for_depth(100 - floor_number):
		errors.append("Hall enemy count must follow its own 5–12 depth curve")
	var hall_chests := _count_in(data["items"], hall)
	if hall_chests < 1 or hall_chests > 2:
		errors.append("Main hall needs 1–2 chests independently of room loot")
	var occupied := {data["start"]: true, data["exit"]: true, data["base_gate"]: true}
	if data["cradle"].x >= 0:
		occupied[data["cradle"]] = true
	var uids := {}
	for entity in data["enemies"] + data["items"]:
		if occupied.has(entity["pos"]) or uids.has(entity["uid"]) or tiles.get(entity["pos"]) != "floor":
			errors.append("Enemies, chests and landmarks must have unique positions and UIDs")
		occupied[entity["pos"]] = true
		uids[entity["uid"]] = true
	return errors


static func _count_in(entities: Array, cells: Dictionary) -> int:
	var count := 0
	for entity in entities:
		count += int(cells.has(entity["pos"]))
	return count


func _test_doors_and_isolation(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.floor_data = _fixture()
	main.player_pos = Vector2i(3, 3)
	var enemy := _enemy("room", Vector2i(5, 3))
	main.floor_data["enemies"] = [enemy]
	main._update_player_visibility(false)
	var tiles: Dictionary = main.floor_data["tiles"]
	_expect(not main._is_cell_visible(enemy["pos"]), "A door must block sight before opening")
	_expect(main.hearing_contacts.presentation_positions().is_empty(), "Sealed rooms must hide even Ears contacts")
	_expect(main._nearest_automatic_inspection_target().get("kind") != "enemy", "Sealed inhabitants must not become inspection targets")
	_expect(main._nearest_enemy_index_from(Vector2i(3, 3), 5) == -1, "Ricochet must not choose a sealed-room target")
	_expect(GridNavigation.find_path(tiles, main.player_pos, enemy["pos"]).is_empty(), "Enemy pathfinding must not open doors")
	_expect(not GridNavigation.find_path(tiles, main.player_pos, enemy["pos"], {}, false, {}, true).is_empty(), "Player routes may opt into ordinary doors")
	_expect(not GridNavigation.has_clear_line(tiles, main.player_pos, enemy["pos"]), "Doors must block projectile lines")
	var known := {}
	for cell in tiles:
		known[cell] = true
	var dash := AbilitySystem.dash_targets_in_direction(tiles, main.player_pos, Vector2i.RIGHT, known, {})
	_expect(dash.is_empty(), "Dash must not open or cross a closed door")
	main._enemy_turn()
	_expect(not enemy.get("has_seen_player", false) and enemy["pos"] == Vector2i(5, 3), "A sealed enemy cannot see or approach the player")
	var turns_before: int = main.state.total_turns
	var hp_before: int = main.state.hp
	main._attempt_player_action(Vector2i.RIGHT)
	_expect(main.player_pos == Vector2i(4, 3) and tiles[Vector2i(4, 3)] == "floor", "An ordinary step must open and enter the door")
	_expect(main.state.total_turns == turns_before + 1 and main.state.hp == hp_before, "Opening costs one ordinary turn and newly seeing enemies cannot attack immediately")
	_expect(enemy.get("has_seen_player", false), "Opening must trigger the adjacent enemy's first sight")
	main._enemy_turn()
	_expect(main.state.hp == hp_before - 1, "An adjacent enemy attacks normally on its next action")
	main.player_pos = Vector2i(3, 2)
	enemy["pos"] = Vector2i(5, 2)
	main._update_player_visibility(false)
	_expect(main.hearing_contacts.has_contact_at(enemy["pos"]), "After opening, room inhabitants can be heard through a side wall")
	_expect(main._nearest_enemy_index_from(Vector2i(3, 2), 5) == 0, "After opening, ordinary through-wall ricochet remains allowed")
	# Walls outside rooms retain the original hearing and ricochet behavior.
	main.floor_data["rooms"] = []
	tiles[Vector2i(4, 3)] = "door_closed"
	main._update_player_visibility(false)
	_expect(main.hearing_contacts.has_contact_at(enemy["pos"]), "Walls outside sealed rooms must not suppress hearing")
	main.queue_free()
	await tree.process_frame


func _test_first_sight(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	for enemy_id in ["grave_rat", "skeletal_archer", "minotaur"]:
		main.floor_data = _fixture(false)
		main.player_pos = Vector2i(3, 3)
		var distance := 1 if enemy_id == "grave_rat" else 3
		var enemy := _enemy(enemy_id, main.player_pos + Vector2i(distance, 0), enemy_id)
		main.floor_data["enemies"] = [enemy]
		main._update_player_visibility(false)
		_expect(not enemy.get("has_seen_player", false), "Player visibility/hearing alone cannot consume first sight")
		var old_pos: Vector2i = enemy["pos"]
		var old_hp: int = main.state.hp
		main._enemy_turn()
		_expect(enemy.get("has_seen_player", false) and enemy.get("last_seen_player") == main.player_pos, "First sight must persist for %s" % enemy_id)
		_expect(enemy["pos"] == old_pos and main.state.hp == old_hp, "First sight skips movement, ranged, melee and Dash for %s" % enemy_id)
		main._enemy_turn()
		_expect(enemy["pos"] != old_pos if enemy_id == "minotaur" else main.state.hp == old_hp - 1, "Next action must resume normally for %s" % enemy_id)
		# Losing the target and reaching the remembered cell clears pursuit only.
		enemy["vision"] = 0
		enemy["last_seen_player"] = enemy["pos"]
		main._enemy_turn()
		_expect(not enemy.has("last_seen_player") and enemy["has_seen_player"], "Pursuit expiry must not rearm first sight")
		enemy["vision"] = 8
		enemy["pos"] = main.player_pos + Vector2i.RIGHT
		old_hp = main.state.hp
		main._enemy_turn()
		_expect(main.state.hp == old_hp - 1, "Reacquiring the player must not skip again")
	main.floor_data = _fixture(false)
	main.player_pos = Vector2i(3, 3)
	var veteran := _enemy("veteran", Vector2i(2, 3))
	veteran["has_seen_player"] = true
	var newcomer := _enemy("newcomer", Vector2i(4, 3))
	main.floor_data["enemies"] = [veteran, newcomer]
	var old_hp: int = main.state.hp
	main._enemy_turn()
	_expect(main.state.hp == old_hp - 1 and newcomer["has_seen_player"], "Each enemy owns its independent first-sight pause")
	main.queue_free()
	await tree.process_frame


func _test_auto_and_camera(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.floor_data = _fixture()
	main.player_pos = Vector2i(3, 3)
	# Even when geometry was mapped, the closed door is an explicit AUTO goal.
	for cell in main.floor_data["tiles"]:
		main.floor_data["explored_cells"][cell] = true
	main.floor_data["enemies"] = [_enemy("auto-room", Vector2i(5, 3))]
	main._update_player_visibility(false)
	_expect(main._find_nearest_exploration_path() == [Vector2i(3, 3), Vector2i(4, 3)], "AUTO must target a known door even without unrevealed geometry")
	var hp_before: int = main.state.hp
	main._on_auto_explore_pressed()
	_expect(main.player_pos == Vector2i(4, 3) and not main.auto_explore_active and main.state.hp == hp_before, "AUTO opens doors, then stops at newly seen enemies after their hesitation")
	main.floor_data = FloorGenerator.new().generate(99, 731, 0.0)
	for cell_size in [44, 66, 88]:
		main.set_dungeon_cell_size(cell_size)
		for cell in [Vector2i(1, 1), Vector2i(38, 38), Vector2i(20, 20)]:
			main.player_pos = cell
			main._refresh_dungeon_viewport()
			var view = main.dungeon_viewport
			var local: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size - view.camera + view.padding
			_expect(view.screen_to_world_cell(local + view.position) == cell, "40x40 camera/input roundtrip must hold at zoom %d" % cell_size)
	main.set_dungeon_cell_size(66)
	main.queue_free()
	await tree.process_frame


func _test_boss_rewards() -> void:
	var data := FixedFloor90.create()
	_expect(data["width"] == 20 and data["height"] == 14 and data["boss_door"] == Vector2i(10, 3), "Boss arena dimensions and gate must remain unchanged")
	_expect(data["items"].size() == 2, "Boss reward room needs two chests")
	for item in data["items"]:
		_expect(item["pos"] != data["exit"] and item["pos"].y <= 2 and GameRules.EQUIPMENT.has(item["id"]), "Boss rewards must be ordinary chests behind the gate")
	_expect(data["items"][0]["pos"] != data["items"][1]["pos"], "Boss chests must not overlap")
	_expect(GridNavigation.find_path(data["tiles"], data["start"], data["exit"], {}, false, {}, true).is_empty(), "Ordinary player door permissions must never unlock the boss gate")
	for x in range(7, 14):
		_expect(data["tiles"][Vector2i(x, 1)] == "floor", "Reward room must be seven tiles wide")


func _test_generated_auto(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.floor_data = FloorGenerator.new().generate(99, 812, 0.0)
	main.floor_data["enemies"].clear()
	main.floor_data["items"].clear()
	main.player_pos = main.floor_data["start"]
	main._update_player_visibility(false)
	var began := Time.get_ticks_msec()
	var steps := 0
	var completed := false
	# Run the same goal selection and accepted steps without presentation delays.
	for _step in range(3200):
		var path: Array[Vector2i] = main._find_nearest_exploration_path()
		if path.size() < 2:
			completed = true
			break
		var expected := path[1]
		main._attempt_player_action(expected - main.player_pos)
		steps += 1
		if main.player_pos != expected:
			break
	_expect(completed, "AUTO must finish an empty generated 40x40 floor within its bounded step limit")
	for room in main.floor_data["rooms"]:
		_expect(main.floor_data["tiles"][room["door"]] == "floor", "Full AUTO must open every accessible room before reporting completion")
	print("ROOM AUTO: %d steps, %d ms, %d rooms" % [steps, Time.get_ticks_msec() - began, main.floor_data["rooms"].size()])
	main.queue_free()
	await tree.process_frame


func _new_main(tree: SceneTree):
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.main_menu_open = false
	main.save_menu_panel.close()
	main.screen = main.Screen.DUNGEON
	main.state = RunState.new()
	main.state.configure_character("Room Test", GameRules.default_attributes())
	main.state.current_form_id = "ghoul"
	main.state.absorbed_souls = 24
	main.state.highest_unlocked_form_index = 2
	main.state.skill_levels["ears"] = 1
	main.state.attributes["vitality"] = 100
	main.state.hp = main.state.get_max_hp()
	main._apply_dungeon_layout(true)
	return main


func _fixture(with_room := true) -> Dictionary:
	var tiles := {}
	var cells := {}
	for y in range(7):
		for x in range(9):
			var cell := Vector2i(x, y)
			tiles[cell] = "floor" if x > 0 and x < 8 and y > 0 and y < 6 else "wall"
			if with_room and x == 4:
				tiles[cell] = "wall"
			if x > 4 and x < 8 and y > 0 and y < 6:
				cells[cell] = true
	if with_room:
		tiles[Vector2i(4, 3)] = "door_closed"
	return {
		"width": 9, "height": 7, "tiles": tiles,
		"rooms": [{"door": Vector2i(4, 3), "outward": Vector2i.LEFT, "cells": cells}] if with_room else [],
		"start": Vector2i(1, 1), "base_gate": Vector2i(1, 5), "exit": Vector2i(3, 5),
		"exit_known": false, "cradle": Vector2i(-1, -1), "cradle_known": false,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [], "enemies": [], "visible_cells": {}, "explored_cells": {}, "observed_cells": {},
	}


func _enemy(uid: String, pos: Vector2i, enemy_id := "grave_rat") -> Dictionary:
	var rules: Dictionary = GameRules.ENEMIES[enemy_id]
	return {
		"uid": uid, "id": enemy_id, "pos": pos, "hp": 50, "max_hp": 50,
		"damage": 1, "accuracy": 100, "dodge": 0, "vision": 8, "souls": 1,
		"attack_type": rules.get("attack_type", "melee"), "range": rules.get("range", 1),
		"abilities": rules.get("abilities", []),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
