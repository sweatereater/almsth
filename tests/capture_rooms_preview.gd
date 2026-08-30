extends SceneTree

const Renderer := preload("res://scripts/ui/game_renderer.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const OUT := "res://builds/previews/rooms/"

class Overview extends Node2D:
	var data: Dictionary
	var state: RunState
	func _draw() -> void:
		Renderer.draw_dungeon(self, data, state, data["start"], [], [], Vector2i(-1, -1), false, false)


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	root.add_child(main)
	await process_frame
	main.main_menu_open = false
	main.save_menu_panel.close()
	Loc.set_locale("ru")
	main.state.configure_character("Путник", GameRules.default_attributes())
	main._hide_game_interface()
	main.name_prompt_label.visible = false
	main.name_input.visible = false
	main.name_confirm_button.visible = false
	main._set_controls_visible(main.creation_controls, false)
	main.screen = main.Screen.DUNGEON
	main.state.current_floor = 99
	main._apply_dungeon_layout(true)
	for control in [
		main.title_label, main.souls_label, main.soul_icon, main.stats_label,
		main.sidebar_progress_label, main.inspection_label, main.message_label,
		main.attack_button, main.spell_button, main.active_2_button, main.active_3_button,
		main.character_action_button, main.interact_button, main.wait_button,
		main.wait_count_button, main.auto_explore_button, main.camp_button,
	]:
		control.visible = true
	main.equipment_label.visible = false
	var data: Dictionary
	var generator := FloorGenerator.new()
	for seed_value in range(100):
		data = generator.generate(99, seed_value, 1.0)
		if data["rooms"].size() == 3:
			break
	print("Preview generated floor seed=%d rooms=%d" % [data["seed"], data["rooms"].size()])
	main.floor_data = data.duplicate(true)
	main.set_dungeon_cell_size(44)
	await _overview(main)
	for cell_size in [44, 66, 88]:
		main.set_dungeon_cell_size(cell_size)
		for room_index in range(data["rooms"].size()):
			main.floor_data = data.duplicate(true)
			var room: Dictionary = main.floor_data["rooms"][room_index]
			main.player_pos = room["door"] + room["outward"]
			main._update_player_visibility(false)
			main.action_history.clear()
			main._log_action(Loc.text("MSG_ENTER_FLOOR", [99]))
			main._select_inspection_target(room["door"])
			await _save(main, "closed-%d" % room_index, cell_size)
			main.inspected_target.clear()
			await _save(main, "closed-%d-unselected" % room_index, cell_size)
		var room: Dictionary = data["rooms"][0]
		main.floor_data = data.duplicate(true)
		main.floor_data["tiles"][room["door"]] = "floor"
		main.player_pos = room["door"]
		main._update_player_visibility(false)
		main.inspected_target = {"kind": "tile", "pos": room["door"]}
		main._log_action(Loc.text("MSG_DOOR_OPENED"))
		await _save(main, "open-hero", cell_size)
		main.player_pos = room["door"] + room["outward"]
		main._update_player_visibility(false)
		await _save(main, "open-clear", cell_size)
		main.inspected_target.clear()
		await _save(main, "open-clear-unselected", cell_size)
		main.floor_data["visible_cells"] = {}
		await _save(main, "open-memory", cell_size)
		main.floor_data = data.duplicate(true)
		main.player_pos = room["door"] + room["outward"]
		main._update_player_visibility(false)
		main.floor_data["visible_cells"] = {}
		await _save(main, "closed-memory", cell_size)
		main.floor_data = FixedFloor90.create()
		main.state.current_floor = 90
		main.player_pos = Vector2i(10, 4)
		main._update_player_visibility(false)
		main.inspected_target = {"kind": "tile", "pos": Vector2i(10, 3)}
		await _save(main, "boss-closed", cell_size)
		main.floor_data["enemies"].clear()
		main.floor_data["tiles"][Vector2i(10, 3)] = "floor"
		main.floor_data["boss_door_open"] = true
		main.floor_data["boss_defeated"] = true
		main.player_pos = Vector2i(10, 2)
		main._update_player_visibility(false)
		await _save(main, "boss-rewards", cell_size)
		main.state.current_floor = 99
	main.queue_free()
	print("ROOM PREVIEWS CAPTURED")
	quit(0)


func _save(main, kind: String, cell_size: int) -> void:
	main._refresh_interface()
	main.queue_redraw()
	await process_frame
	await process_frame
	var path := OUT + "%dx%d-%d-%s.png" % [root.size.x, root.size.y, cell_size, kind]
	var image := root.get_texture().get_image()
	if image.is_empty() or image.save_png(path) != OK:
		push_error("Failed room preview: " + path)
	print(path)


func _overview(main) -> void:
	var data: Dictionary = main.floor_data.duplicate(true)
	for cell in data["tiles"]:
		data["visible_cells"][cell] = true
		data["explored_cells"][cell] = true
		data["observed_cells"][cell] = true
	data["exit_known"] = true
	data["cradle_known"] = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1760, 1760)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Overview.new()
	canvas.data = data
	canvas.state = main.state
	viewport.add_child(canvas)
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if not image.is_empty():
		image.save_png(OUT + "overview-40x40-seed-%d.png" % data["seed"])
	viewport.queue_free()
	await process_frame
