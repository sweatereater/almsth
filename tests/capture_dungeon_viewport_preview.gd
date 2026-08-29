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
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	root.add_child(main)
	await process_frame
	Loc.set_locale(locale)
	main._apply_locale()
	main.state.configure_character("Aldren of the Last Quiet Passage", GameRules.default_attributes())
	main.state.current_form_id = "almost_human"
	main.state.absorbed_souls = 9999
	main.state.carried_souls = 9999
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
	main.state.loadout = {
		"weapon": "bone_bow@3", "charm": "soul_locket", "armor": "rotting_mail",
		"hands": "leather_gloves", "relic": "hollow_lantern", "offhand": "pilgrim_shield",
	}
	main.state.base_level += 9999 - main.state.get_max_hp()
	main.state.attributes["wisdom"] = 1996
	main.state.skill_levels["magic_awakening"] = 1
	main.state.skill_levels["magic_missile"] = 1
	main.state.skill_levels["dash"] = 1
	main.state.skill_levels["circular_attack"] = 1
	main.state.ability_loadout = {
		"attack": "circular_attack", "active_1": "magic_missile",
		"active_2": "dash", "active_3": "dash",
	}
	main.state.hp = 9999
	main.state.mana = 9999
	main._hide_game_interface()
	main.name_prompt_label.visible = false
	main.name_input.visible = false
	main.name_confirm_button.visible = false
	main._set_controls_visible(main.creation_controls, false)
	main.screen = main.Screen.DUNGEON
	main._apply_dungeon_layout(true)
	main.wait_turn_count = 100
	main.auto_explore_active = true
	for control in [
		main.title_label, main.souls_label, main.stats_label, main.sidebar_progress_label,
		main.equipment_label, main.inspection_label, main.message_label,
		main.attack_button, main.spell_button, main.active_2_button, main.active_3_button,
		main.character_action_button, main.interact_button, main.wait_button,
		main.wait_count_button, main.auto_explore_button, main.camp_button,
	]:
		control.visible = true

	main.floor_data = _floor_fixture(20, 14)
	_reveal(main)
	main.player_pos = Vector2i(10, 7)
	main.floor_data["exit"] = main.player_pos
	main.floor_data["enemies"] = [_enemy("inspection", "hollow_guard", Vector2i(12, 7))]
	main._select_inspection_target(Vector2i(12, 7))
	_fill_history(main)
	await _save(main, "center-long-sidebar")

	main.player_pos = Vector2i(1, 1)
	main.inspected_target = {"kind": "tile", "pos": Vector2i(0, 0)}
	await _save(main, "top-left")

	main.player_pos = Vector2i(18, 12)
	main.inspected_target = {"kind": "tile", "pos": Vector2i(19, 13)}
	await _save(main, "bottom-right")

	main.player_pos = Vector2i(10, 7)
	main.magic_traces.clear()
	main.magic_traces.append({"from": Vector2i(8, 7), "to": Vector2i(13, 7), "remaining": 0.8})
	main.projectile_traces.clear()
	main.projectile_traces.append({"from": Vector2i(10, 9), "to": Vector2i(14, 6), "remaining": 0.3})
	main.ability_targeting_id = "dash"
	main.ability_target_cells.clear()
	main.ability_target_cells.append_array([Vector2i(10, 6), Vector2i(10, 5), Vector2i(10, 4)])
	main.ability_target_cursor = Vector2i(10, 5)
	await _save(main, "traces-dash")

	main.magic_traces.clear()
	main.projectile_traces.clear()
	main.ability_targeting_id = ""
	main.ability_target_cells.clear()
	main.ability_target_cursor = Vector2i(-1, -1)
	main.player_pos = Vector2i(1, 1)
	main.floor_data["enemies"] = [_enemy("edge-boss", "minotaur", Vector2i(0, 0))]
	main._select_inspection_target(Vector2i(0, 0))
	await _save(main, "minotaur-edge")

	main.floor_data = _floor_fixture(5, 5)
	_reveal(main)
	main.player_pos = Vector2i(2, 2)
	main.inspected_target = {"kind": "tile", "pos": Vector2i(4, 4)}
	await _save(main, "small-5x5")

	main.floor_data = _floor_fixture(20, 14)
	_reveal(main)
	main.player_pos = Vector2i(10, 7)
	main.floor_data["exit"] = main.player_pos
	main.floor_data["enemies"] = [_enemy("inspection", "hollow_guard", Vector2i(12, 7))]
	main._select_inspection_target(Vector2i(12, 7))
	_fill_history(main)
	main._open_settings()
	await _save(main, "settings-overlay")
	main._close_settings()
	main._show_character()
	await _save(main, "character-overlay")
	main._close_character()
	main.queue_free()
	quit(0)


func _save(main, kind: String) -> void:
	main._refresh_interface()
	main.queue_redraw()
	await process_frame
	await process_frame
	var viewport_size := root.size
	var path := "res://builds/previews/dungeon-view-%s-%dx%d-%s.png" % [
		locale, viewport_size.x, viewport_size.y, kind,
	]
	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("Empty dungeon viewport preview for %s" % kind)
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save dungeon viewport preview %s (error %d)" % [path, error])


func _floor_fixture(width: int, height: int) -> Dictionary:
	var tiles := {}
	for y in range(height):
		for x in range(width):
			var perimeter := x == 0 or y == 0 or x == width - 1 or y == height - 1
			tiles[Vector2i(x, y)] = "wall" if perimeter else "floor"
	return {
		"width": width, "height": height, "tiles": tiles,
		"start": Vector2i(1, 1), "base_gate": Vector2i(1, height - 2),
		"exit": Vector2i(width - 2, 1), "exit_known": true,
		"cradle": Vector2i(width - 2, height - 2), "cradle_known": true,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [{"uid": "preview-chest", "pos": Vector2i(8, 8), "item_id": "bone_bow"}],
		"enemies": [], "visible_cells": {}, "explored_cells": {}, "observed_cells": {},
	}


func _reveal(main) -> void:
	var cells := {}
	for cell in main.floor_data["tiles"]:
		cells[cell] = true
	main.floor_data["visible_cells"] = cells.duplicate(true)
	main.floor_data["explored_cells"] = cells.duplicate(true)
	main.floor_data["observed_cells"] = cells.duplicate(true)


func _enemy(uid: String, enemy_id: String, cell: Vector2i) -> Dictionary:
	var rules: Dictionary = GameRules.ENEMIES[enemy_id]
	return {
		"uid": uid, "id": enemy_id, "pos": cell,
		"hp": int(rules["max_hp"]), "max_hp": int(rules["max_hp"]),
		"damage": int(rules["damage"]), "accuracy": int(rules["accuracy"]),
		"dodge": int(rules["dodge"]), "vision": int(rules["vision"]),
		"souls": int(rules["souls"]), "abilities": rules.get("abilities", []).duplicate(),
	}


func _fill_history(main) -> void:
	main.action_history.clear()
	for entry in [
		Loc.text("MSG_ENTER_FLOOR", [90]),
		Loc.text("MSG_PLAYER_RANGED_HIT", [Loc.text("ENEMY_HOLLOW_GUARD"), 12, 24]),
		Loc.text("MSG_CHEST_OPENED", [Loc.text("ITEM_BONE_BOW"), 2, 1]),
		Loc.text("MSG_EXPLORE_INTERRUPTED"),
		Loc.text("MSG_ASCEND_ARRIVED"),
	]:
		main.action_history.append(entry)
	main._refresh_action_history()
