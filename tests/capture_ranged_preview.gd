extends SceneTree

const Loc := preload("res://scripts/localization/localization.gd")

var locale := "ru"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--locale=en":
			locale = "en"
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.audio_playback_enabled = false
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	Loc.set_locale(locale)
	main.state = RunState.new()
	main.state.character_name = "Морвен" if locale == "ru" else "The Forgotten Bowman"
	main.state.loadout["weapon"] = "bone_bow@2"
	main.state.add_item("bone_bow", 2)
	main.state.hp = main.state.get_max_hp()
	main._show_base(Loc.text("MSG_GAME_LOADED"))
	main._apply_locale()
	main._show_character()
	await _save_after_draw(main, "character")
	main._select_character_panel("inventory")
	main.selected_inventory_key = "bone_bow@2"
	main._refresh_character_sheet()
	await _save_after_draw(main, "inventory")

	main._close_character()
	main._begin_expedition_at(99)
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(6, 7)
	_reveal_floor(main)
	main.floor_data["enemies"] = [
		_enemy("preview_guard", Vector2i(10, 7), 20, "hollow_guard"),
	]
	main.floor_data["enemies"][0]["vision"] = 0
	main.inspected_target.clear()
	main._refresh_interface()
	main.queue_redraw()
	await _save_after_draw(main, "hotbar")

	main.inspected_target = {
		"kind": "enemy",
		"uid": "preview_guard",
		"entity": main.floor_data["enemies"][0],
	}
	main._activate_ability_slot("attack", {"attack_rolls": [20]})
	await _save_after_draw(main, "player-shot")

	main.floor_data["enemies"] = [
		_enemy("preview_archer", Vector2i(11, 7), 4, "skeletal_archer"),
	]
	main.floor_data["enemies"][0]["accuracy"] = 100
	main.projectile_traces.clear()
	main.inspected_target.clear()
	main._enemy_turn()
	main._refresh_interface()
	await _save_after_draw(main, "archer-shot")

	main.projectile_traces.clear()
	main.floor_data["visible_cells"] = _visibility_circle(main.player_pos, 3)
	main.floor_data["observed_cells"] = main.floor_data["visible_cells"].duplicate(true)
	main.floor_data["explored_cells"] = _visibility_circle(main.player_pos, 5)
	main.state.hp = main.state.get_max_hp()
	main._enemy_turn()
	main._refresh_interface()
	await _save_after_draw(main, "fog-non-leak")
	quit(0)


func _save_after_draw(main, kind: String) -> void:
	main.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var size := root.size
	var path := "res://builds/previews/ranged-%s-%dx%d-%s.png" % [
		locale, size.x, size.y, kind,
	]
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save ranged preview to %s (error %d)" % [path, error])


func _floor_fixture() -> Dictionary:
	var width := 20
	var height := 14
	var tiles := {}
	for y in range(height):
		for x in range(width):
			tiles[Vector2i(x, y)] = (
				"floor" if x > 0 and x < width - 1 and y > 0 and y < height - 1 else "wall"
			)
	for y in range(3, 11):
		tiles[Vector2i(15, y)] = "wall"
	return {
		"width": width,
		"height": height,
		"tiles": tiles,
		"start": Vector2i(6, 7),
		"base_gate": Vector2i(2, 11),
		"exit": Vector2i(17, 2),
		"exit_known": true,
		"cradle": Vector2i(-1, -1),
		"cradle_known": false,
		"cradle_pity_resolved": true,
		"cradle_used": false,
		"items": [{"uid": "bow_chest", "id": "bone_bow", "pos": Vector2i(4, 4)}],
		"enemies": [],
		"visible_cells": {},
		"explored_cells": {},
		"observed_cells": {},
	}


func _reveal_floor(main) -> void:
	var all_cells := {}
	for cell_variant in main.floor_data["tiles"]:
		var cell: Vector2i = cell_variant
		if main.floor_data["tiles"][cell] != "void":
			all_cells[cell] = true
	main.floor_data["visible_cells"] = all_cells.duplicate(true)
	main.floor_data["explored_cells"] = all_cells.duplicate(true)
	main.floor_data["observed_cells"] = all_cells.duplicate(true)


func _visibility_circle(origin: Vector2i, radius: int) -> Dictionary:
	var result := {}
	for y in range(14):
		for x in range(20):
			var cell := Vector2i(x, y)
			if absi(cell.x - origin.x) + absi(cell.y - origin.y) <= radius:
				result[cell] = true
	return result


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
		"souls": int(rules["souls"]),
		"attack_type": String(rules.get("attack_type", "melee")),
		"range": int(rules.get("range", 1)),
	}
