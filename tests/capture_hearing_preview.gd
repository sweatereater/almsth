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
	main.main_menu_open = false
	main.save_menu_panel.close()
	main.screen = main.Screen.DUNGEON
	main.state = RunState.new()
	main.state.configure_character("Слышащий" if locale == "ru" else "The Listener", GameRules.default_attributes())
	main._hide_game_interface()
	main.name_prompt_label.visible = false
	main.name_input.visible = false
	main.name_confirm_button.visible = false
	main._set_controls_visible(main.creation_controls, false)
	main._set_controls_visible(main.character_controls, false)
	main._set_controls_visible(main.story_controls, false)
	main._apply_dungeon_layout(true)
	for control in [
		main.title_label, main.souls_label, main.soul_icon, main.stats_label,
		main.sidebar_progress_label, main.inspection_label, main.message_label,
		main.attack_button, main.spell_button, main.active_2_button, main.active_3_button,
		main.character_action_button, main.interact_button, main.wait_button,
		main.wait_count_button, main.auto_explore_button, main.camp_button,
	]:
		control.visible = true
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(12, 8)
	main._update_player_visibility(false)

	for zoom in [44, 66, 88]:
		_configure_composite(main)
		main.set_dungeon_cell_size(zoom)
		await _save(main, "zoom-%d-composite" % zoom)

	main.set_dungeon_cell_size(66)
	_configure_transition(main)
	await _save(main, "sequence-hidden")
	main.floor_data["visible_cells"][Vector2i(18, 4)] = true
	main.floor_data["explored_cells"][Vector2i(18, 4)] = true
	main.floor_data["observed_cells"][Vector2i(18, 4)] = true
	main._sync_hearing_proximity()
	await _save(main, "sequence-visible-no-question")

	_configure_stale_expiry(main)
	await _save(main, "stale-before-successful-turn")
	main._log_action(Loc.text("MSG_WAIT"))
	main._complete_player_turn()
	await _save(main, "stale-after-successful-turn-gone")

	main.set_dungeon_cell_size(44)
	_configure_edge(main)
	await _save(main, "viewport-edge-zoom-44")
	main.queue_free()
	quit(0)


func _configure_composite(main) -> void:
	main.hearing_contacts.clear()
	main.floor_data["enemies"] = [_enemy("visible-guard", Vector2i(14, 8))]
	main.floor_data["items"] = []
	main.floor_data["explored_cells"][Vector2i(7, 8)] = true
	main.floor_data["explored_cells"][Vector2i(16, 10)] = true
	main.hearing_contacts.record_hidden_attack("unknown", Vector2i(16, 5), main.state.total_turns)
	main.hearing_contacts.record_hidden_attack("behind-wall", Vector2i(7, 8), main.state.total_turns)
	main.hearing_contacts.record_hidden_attack("stale", Vector2i(16, 10), main.state.total_turns)
	main.hearing_contacts.record_hidden_attack("multiple-a", Vector2i(9, 11), main.state.total_turns)
	main.hearing_contacts.record_hidden_attack("multiple-b", Vector2i(9, 11), main.state.total_turns)
	# This source deliberately shares a cell with an actually visible entity;
	# renderer suppression proves that no sprite + ? duplicate is produced.
	main.hearing_contacts.record_hidden_attack("suppressed", Vector2i(14, 8), main.state.total_turns)
	main.hearing_contacts.record_hidden_attack("edge", Vector2i(0, 0), main.state.total_turns)
	main.inspected_target = {"kind": "noise", "pos": Vector2i(16, 5)}
	main.action_history.clear()
	main.action_history.append(Loc.text("MSG_HEARING_MOVEMENT"))
	main.action_history.append(Loc.text("MSG_HEARING_HIDDEN_ATTACK"))
	main._refresh_action_history()


func _configure_transition(main) -> void:
	main.hearing_contacts.clear()
	main.floor_data["enemies"] = [_enemy("transition-owner", Vector2i(18, 4))]
	main.floor_data["visible_cells"].erase(Vector2i(18, 4))
	main.floor_data["observed_cells"].erase(Vector2i(18, 4))
	main.floor_data["explored_cells"].erase(Vector2i(18, 4))
	main.hearing_contacts.record_hidden_attack("transition-owner", Vector2i(18, 4), main.state.total_turns)
	main.inspected_target = {"kind": "noise", "pos": Vector2i(18, 4)}


func _configure_stale_expiry(main) -> void:
	main.hearing_contacts.clear()
	main.floor_data["enemies"] = [_enemy("stale-owner", Vector2i(20, 11))]
	main.floor_data["enemies"][0]["vision"] = 0
	main.hearing_contacts.record_hidden_attack("stale-owner", Vector2i(18, 10), main.state.total_turns)
	main.inspected_target = {"kind": "noise", "pos": Vector2i(18, 10)}


func _configure_edge(main) -> void:
	main.hearing_contacts.clear()
	main.floor_data["enemies"].clear()
	main.player_pos = Vector2i(1, 1)
	main.floor_data["visible_cells"].erase(Vector2i(0, 0))
	main.floor_data["observed_cells"].erase(Vector2i(0, 0))
	main.floor_data["explored_cells"].erase(Vector2i(0, 0))
	main.hearing_contacts.record_hidden_attack("edge", Vector2i(0, 0), main.state.total_turns)
	main.inspected_target = {"kind": "noise", "pos": Vector2i(0, 0)}


func _save(main, kind: String) -> void:
	main._refresh_interface()
	main.queue_redraw()
	await process_frame
	await process_frame
	var viewport_size := root.size
	var path := "res://builds/previews/hearing-%s-%dx%d-%s.png" % [
		locale, viewport_size.x, viewport_size.y, kind,
	]
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Hearing preview requires a rendering display for %s" % kind)
		return
	var image := viewport_texture.get_image()
	if image.is_empty():
		push_error("Empty hearing preview for %s" % kind)
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save hearing preview %s (error %d)" % [path, error])


func _floor_fixture() -> Dictionary:
	var width := 24
	var height := 16
	var tiles := {}
	for y in range(height):
		for x in range(width):
			var perimeter := x == 0 or y == 0 or x == width - 1 or y == height - 1
			tiles[Vector2i(x, y)] = "wall" if perimeter else "floor"
	for y in range(3, 13):
		tiles[Vector2i(8, y)] = "wall"
	return {
		"width": width, "height": height, "tiles": tiles,
		"start": Vector2i(2, 2), "base_gate": Vector2i(2, 13),
		"exit": Vector2i(21, 2), "exit_known": false,
		"cradle": Vector2i(-1, -1), "cradle_known": false,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [], "enemies": [], "visible_cells": {},
		"explored_cells": {}, "observed_cells": {},
	}


func _enemy(uid: String, pos: Vector2i) -> Dictionary:
	var rules: Dictionary = GameRules.ENEMIES["hollow_guard"]
	return {
		"uid": uid, "id": "hollow_guard", "pos": pos,
		"hp": int(rules["max_hp"]), "max_hp": int(rules["max_hp"]),
		"damage": 0, "accuracy": 0, "dodge": int(rules["dodge"]),
		"vision": 0, "souls": int(rules["souls"]),
	}
