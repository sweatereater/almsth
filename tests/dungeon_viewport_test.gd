class_name DungeonViewportTestSuite
extends RefCounted

const DungeonView := preload("res://scripts/ui/dungeon_viewport.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const Loc := preload("res://scripts/localization/localization.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_camera_math()
	await _test_main_integration(tree)
	return failures


func _test_camera_math() -> void:
	_expect(DungeonView.VIEW_RECT == Rect2(8, 8, 1056, 660), "Dungeon viewport rect must match the 16x10-cell contract")
	_expect(DungeonView.CELL_SIZE == Renderer.CELL_SIZE, "Camera, input and rendering must share one cell-size source")
	_expect(Renderer.CELL_SIZE == 66, "Dungeon cells must be exactly 66 virtual pixels")
	var large := Vector2i(20, 14)
	_expect(DungeonView.world_pixel_size(large) == Vector2(1320, 924), "20x14 world size must be 1320x924")
	_expect(DungeonView.max_camera(large) == Vector2(264, 264), "20x14 maximum camera must be 264x264")
	_expect(DungeonView.camera_for(large, Vector2i(10, 7)) == Vector2(165, 165), "Centered 20x14 camera must use the specified rounded offset")
	_expect(DungeonView.camera_for(large, Vector2i.ZERO) == Vector2.ZERO, "Top-left focus must clamp to zero")
	_expect(DungeonView.camera_for(large, Vector2i(19, 13)) == Vector2(264, 264), "Bottom-right focus must clamp to maximum")
	_expect(DungeonView.camera_for(large, Vector2i(19, 0)) == Vector2(264, 0), "Top-right focus must clamp each axis independently")
	_expect(DungeonView.camera_for(large, Vector2i(0, 13)) == Vector2(0, 264), "Bottom-left focus must clamp each axis independently")
	_expect(DungeonView.padding_for(Vector2i(5, 5)) == Vector2(363, 165), "5x5 map padding must be 363x165")
	_expect(DungeonView.padding_for(Vector2i(16, 10)) == Vector2.ZERO, "A 16x10 map must exactly fill the viewport")
	_expect(DungeonView.padding_for(Vector2i(17, 3)) == Vector2(0, 231), "17x3 map must pan horizontally and center vertically")
	_expect(DungeonView.max_camera(Vector2i(17, 3)) == Vector2(66, 0), "17x3 camera must clamp only its large axis")
	_expect(DungeonView.padding_for(Vector2i(1, 1)) == Vector2(495, 297), "1x1 map must center on both axes")
	_expect(is_equal_approx(DungeonView.VIEW_RECT.get_area() / (1280.0 * 720.0), 0.75625), "Dungeon map must occupy the specified canvas share")

	var rect := DungeonView.VIEW_RECT
	_expect(DungeonView.world_cell_from_screen(rect.end, rect, large, Vector2i(10, 7)) == Vector2i(-1, -1), "Right/bottom viewport boundary must be exclusive")
	_expect(DungeonView.world_cell_from_screen(Vector2(rect.end.x, rect.position.y), rect, large, Vector2i(10, 7)) == Vector2i(-1, -1), "Right viewport boundary must be exclusive")
	_expect(DungeonView.world_cell_from_screen(Vector2(rect.position.x, rect.end.y), rect, large, Vector2i(10, 7)) == Vector2i(-1, -1), "Bottom viewport boundary must be exclusive")

	for dimensions in [Vector2i(20, 14), Vector2i(17, 3), Vector2i(5, 5), Vector2i(1, 1)]:
		for focus in [Vector2i.ZERO, dimensions / 2, dimensions - Vector2i.ONE]:
			var origin := DungeonView.child_origin_for(dimensions, focus)
			for y in range(dimensions.y):
				for x in range(dimensions.x):
					var cell := Vector2i(x, y)
					var screen_center := rect.position + origin + (Vector2(cell) + Vector2(0.5, 0.5)) * DungeonView.CELL_SIZE
					if rect.has_point(screen_center):
						_expect(
							DungeonView.world_cell_from_screen(screen_center, rect, dimensions, focus) == cell,
							"Visible cell-center roundtrip failed for %s at %s" % [dimensions, cell],
						)


func _test_main_integration(tree: SceneTree) -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.configure_character("Viewport", GameRules.default_attributes())
	main._hide_game_interface()
	main.name_prompt_label.visible = false
	main.name_input.visible = false
	main.name_confirm_button.visible = false
	main._set_controls_visible(main.creation_controls, false)
	main.screen = main.Screen.DUNGEON
	main.floor_data = _floor_fixture(20, 14)
	main.player_pos = Vector2i(10, 7)
	_reveal_floor(main)
	main._apply_dungeon_layout(true)
	main._refresh_interface()
	await tree.process_frame
	_expect(main.dungeon_viewport.visible and main.dungeon_viewport.clip_contents, "Dungeon screen must use a visible clipping Control")
	_expect(main.dungeon_viewport.camera == Vector2(165, 165), "Integrated camera must use the player-centered transform")
	_expect(main.dungeon_viewport.world_canvas.position == -Vector2(165, 165), "Large-map canvas origin must be padding minus camera")

	# Mouse selection travels through the viewport signal and shared inverse.
	var selected_cell := Vector2i(12, 7)
	await _push_mouse(main, tree, main.dungeon_viewport.world_to_screen_center(selected_cell))
	_expect(main.inspected_target.get("kind", "") == "tile" and main.inspected_target.get("pos") == selected_cell, "Viewport mouse input must select the transformed world cell")

	# A neighboring touch performs the existing movement action and moves the camera.
	var turns_before: int = main.state.total_turns
	var adjacent: Vector2i = main.player_pos + Vector2i.RIGHT
	await _push_touch(main, tree, main.dungeon_viewport.world_to_screen_center(adjacent))
	_expect(main.player_pos == adjacent and main.state.total_turns == turns_before + 1, "Neighboring ScreenTouch must keep movement and turn semantics")
	_expect(main.dungeon_viewport.camera == DungeonView.camera_for(Vector2i(20, 14), main.player_pos), "Camera must follow a normal movement immediately")

	# The first automatic-exploration step updates the same camera before its frame yield.
	main.player_pos = Vector2i(10, 7)
	main.floor_data["explored_cells"] = {
		main.player_pos: true, main.player_pos + Vector2i.RIGHT: true,
	}
	main.floor_data["visible_cells"] = main.floor_data["explored_cells"].duplicate(true)
	main.floor_data["observed_cells"] = main.floor_data["explored_cells"].duplicate(true)
	main._refresh_dungeon_viewport()
	main._on_auto_explore_pressed()
	_expect(main.player_pos == Vector2i(11, 7), "Automatic exploration fixture must take its deterministic first step")
	_expect(main.dungeon_viewport.camera == DungeonView.camera_for(Vector2i(20, 14), main.player_pos), "Camera must follow automatic exploration immediately")
	main._clear_auto_explore_state()
	_reveal_floor(main)

	# Dash confirmation uses the same transformed endpoint and camera update.
	main.state.current_form_id = "ghoul"
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	main.state.skill_levels["dash"] = 1
	main.player_pos = Vector2i(10, 7)
	main._refresh_interface()
	turns_before = main.state.total_turns
	main._begin_dash_targeting()
	_expect(main.ability_targeting_id == "dash", "Dash integration fixture must enter targeting")
	var dash_target := Vector2i(12, 7)
	await _push_mouse(main, tree, main.dungeon_viewport.world_to_screen_center(dash_target))
	_expect(main.player_pos == dash_target and main.state.total_turns == turns_before + 1, "Viewport click must confirm a valid Dash endpoint once")
	_expect(main.dungeon_viewport.camera == DungeonView.camera_for(Vector2i(20, 14), dash_target), "Camera must follow committed Dash movement")

	# Inspection and both trace families share Renderer.cell_rect through one canvas origin.
	var probe := Vector2i(13, 8)
	var renderer_center: Vector2 = main.dungeon_viewport.global_position + main.dungeon_viewport.world_canvas.position + Renderer.cell_rect(probe).get_center()
	_expect(renderer_center == main.dungeon_viewport.world_to_screen_center(probe), "Inspection, magic, projectile and entity transforms must share one cell center")

	# Sidebar, hotbar gap and other outside clicks neither spend turns nor clear selection.
	main.inspected_target = {"kind": "tile", "pos": probe}
	turns_before = main.state.total_turns
	await _push_mouse(main, tree, Vector2(1068, 300))
	await _push_mouse(main, tree, Vector2(1100, 300))
	await _push_mouse(main, tree, Vector2(1100, 600))
	_expect(main.inspected_target.get("pos") == probe and main.state.total_turns == turns_before, "Outside/sidebar clicks must not clear inspection or consume a turn")

	# A small-map matte is clipped input space but not an interactive world cell.
	main.floor_data = _floor_fixture(5, 5)
	main.player_pos = Vector2i(2, 2)
	_reveal_floor(main)
	main._refresh_interface()
	main.inspected_target = {"kind": "tile", "pos": Vector2i(1, 1)}
	turns_before = main.state.total_turns
	await _push_touch(main, tree, DungeonView.VIEW_RECT.position + Vector2(8, 8))
	_expect(main.inspected_target.get("pos") == Vector2i(1, 1) and main.state.total_turns == turns_before, "Centered small-map matte must be noninteractive")
	_expect(main.dungeon_viewport.padding == Vector2(363, 165), "Integrated 5x5 map must use the specified centering padding")

	# Loading a generated floor derives camera bounds from floor width/height, not explored cells.
	main.rng.seed = 77123
	main._load_floor(88)
	_expect(
		main.dungeon_viewport.map_size == Vector2i(main.floor_data["width"], main.floor_data["height"])
		and main.dungeon_viewport.camera == DungeonView.camera_for(main.dungeon_viewport.map_size, main.player_pos),
		"Floor load must refresh camera from rectangular floor dimensions",
	)

	main.floor_data = _floor_fixture(20, 14)
	main.player_pos = Vector2i(10, 7)
	_reveal_floor(main)
	_show_dungeon_controls(main)
	main._apply_dungeon_layout(true)
	main.action_history.clear()
	for history_text in [
		"The latest complete action remains readable in the narrow history rail.",
		"A second full action line is retained without an ellipsis.",
		"A third dungeon event records a distant skeletal archer miss.",
		"A fourth entry remembers the opened chest and all recovered materials.",
		"A fifth previous action remains present, dimmer but still complete.",
	]:
		main.action_history.append(history_text)
	main._refresh_action_history()
	_test_dungeon_geometry(main)
	var previous_locale: String = Loc.current_locale
	for test_locale in ["ru", "en"]:
		Loc.set_locale(test_locale)
		main._refresh_interface()
		_expect(
			main.title_label.get_theme_font("font").get_string_size(
				main.title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				main.title_label.get_theme_font_size("font_size"),
			).x <= main.title_label.size.x,
			"Localized dungeon floor title must fit the marked rail rectangle without clipping",
		)
	Loc.set_locale(previous_locale)
	main._apply_locale()
	_expect(main.action_history.size() == 5, "Dungeon history must retain five complete newest-first entries")
	for history_entry in main.action_history:
		_expect(main.message_label.text.contains(history_entry), "Dungeon history must contain every complete entry without ellipsis")

	# Mouse and touch over an action control must produce exactly one action and no map inspection side effect.
	main.inspected_target = {"kind": "tile", "pos": Vector2i(13, 8)}
	main.wait_turn_count = 1
	turns_before = main.state.total_turns
	await _click_mouse(main, tree, Rect2(main.wait_button.position, main.wait_button.size).get_center())
	_expect(main.state.total_turns == turns_before + 1 and main.inspected_target.get("pos") == Vector2i(13, 8), "Mouse action click must spend exactly one turn without reaching the map")
	turns_before = main.state.total_turns
	await _tap_touch(main, tree, Rect2(main.wait_button.position, main.wait_button.size).get_center())
	_expect(main.state.total_turns == turns_before + 1 and main.inspected_target.get("pos") == Vector2i(13, 8), "Touch action tap must spend exactly one turn without reaching the map")

	# Dungeon overlays consume input instead of forwarding it to the enlarged map.
	var position_before: Vector2i = main.player_pos
	turns_before = main.state.total_turns
	main._open_settings()
	await _click_mouse(main, tree, Vector2(100, 100))
	_expect(main.player_pos == position_before and main.state.total_turns == turns_before, "Settings overlay must prevent dungeon click-through")
	main._close_settings()
	main._show_character()
	await _click_mouse(main, tree, Vector2(100, 100))
	_expect(main.player_pos == position_before and main.state.total_turns == turns_before, "Character overlay must prevent dungeon click-through")
	main._show_character()
	_expect(
		main.screen == main.Screen.CHARACTER
		and not main.dungeon_viewport.visible
		and main.title_label.size == Vector2(790, 48),
		"Character screen opened from Dungeon must retain its original wide layout",
	)
	main._close_character()
	_expect(
		main.screen == main.Screen.DUNGEON
		and main.dungeon_viewport.visible
		and Rect2(main.title_label.position, main.title_label.size) == Rect2(1080, 56, 184, 42),
		"Closing Character must restore the compact Dungeon layout and viewport",
	)
	main._show_base("")
	_expect(
		not main.dungeon_viewport.visible
		and main.stats_label.position == Vector2(846, 78)
		and main.stats_label.size == Vector2(400, 56)
		and main.equipment_label.position == Vector2(846, 338)
		and main.inspection_label.position == Vector2(860, 508)
		and main.message_label.size == Vector2(790, 106),
		"Leaving Dungeon must restore the unchanged wide base layout",
	)
	main.queue_free()
	await tree.process_frame


func _push_mouse(main, tree: SceneTree, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	main.get_viewport().push_input(event, true)
	await tree.process_frame


func _click_mouse(main, tree: SceneTree, position: Vector2) -> void:
	await _push_mouse(main, tree, position)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	main.get_viewport().push_input(release, true)
	await tree.process_frame


func _push_touch(main, tree: SceneTree, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = position
	main.get_viewport().push_input(event, true)
	await tree.process_frame


func _tap_touch(main, tree: SceneTree, position: Vector2) -> void:
	await _push_touch(main, tree, position)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = position
	main.get_viewport().push_input(release, true)
	await tree.process_frame


func _show_dungeon_controls(main) -> void:
	for control in [
		main.title_label, main.souls_label, main.menu_button, main.stats_label,
		main.sidebar_progress_label, main.equipment_label, main.inspection_label,
		main.hint_label, main.message_label, main.attack_button, main.spell_button,
		main.active_2_button, main.active_3_button, main.wait_button,
		main.wait_count_button, main.auto_explore_button, main.camp_button,
		main.character_action_button, main.interact_button,
	]:
		control.visible = true


func _test_dungeon_geometry(main) -> void:
	var map_rect := Renderer.DUNGEON_VIEW_RECT
	var rail_rect := Renderer.DUNGEON_SIDEBAR_RECT
	var expected_controls := {
		main.souls_label: Rect2(1080, 16, 88, 34), main.menu_button: Rect2(1174, 16, 90, 34),
		main.title_label: Rect2(1080, 56, 184, 42), main.stats_label: Rect2(1080, 104, 184, 48),
		main.sidebar_progress_label: Rect2(1080, 222, 184, 54), main.equipment_label: Rect2(1080, 282, 184, 108),
		main.inspection_label: Rect2(1088, 404, 168, 88), main.hint_label: Rect2(1088, 514, 168, 22),
		main.message_label: Rect2(1088, 540, 168, 154),
	}
	for control in expected_controls:
		var rect: Rect2 = Rect2(control.position, control.size)
		_expect(rect == expected_controls[control], "Dungeon rail control must use its exact marked geometry")
		_expect(rail_rect.encloses(rect) and not rect.intersects(map_rect), "Dungeon rail control must stay inside the rail and outside the map")
	for frame in [Renderer.DUNGEON_HP_RECT, Renderer.DUNGEON_MANA_RECT, Renderer.DUNGEON_INSPECTION_RECT, Renderer.DUNGEON_HISTORY_RECT]:
		_expect(rail_rect.encloses(frame) and not frame.intersects(map_rect), "Dungeon status frame must stay inside the rail and outside the map")
	var action_controls := [
		main.attack_button, main.spell_button, main.active_2_button, main.active_3_button,
		main.wait_button, main.wait_count_button, main.auto_explore_button, main.camp_button,
		main.character_action_button, main.interact_button,
	]
	var expected_actions := [
		Rect2(8, 674, 112, 38), Rect2(122, 674, 120, 38), Rect2(244, 674, 100, 38),
		Rect2(346, 674, 100, 38), Rect2(448, 674, 106, 38), Rect2(556, 674, 28, 38),
		Rect2(586, 674, 110, 38), Rect2(698, 674, 82, 38), Rect2(782, 674, 126, 38),
		Rect2(910, 674, 154, 38),
	]
	for index in range(action_controls.size()):
		var action: Control = action_controls[index]
		var rect := Rect2(action.position, action.size)
		_expect(rect == expected_actions[index], "Dungeon action control must use its exact marked geometry")
		_expect(not rect.intersects(map_rect) and action.focus_mode == Control.FOCUS_NONE and rect.size.y >= 38.0, "Dungeon actions must be touch-sized, unfocusable and outside the map")
		for other_index in range(index):
			_expect(not rect.intersects(expected_actions[other_index]), "Dungeon action controls must remain pairwise disjoint")


func _floor_fixture(width: int, height: int) -> Dictionary:
	var tiles := {}
	for y in range(height):
		for x in range(width):
			tiles[Vector2i(x, y)] = "floor"
	return {
		"width": width, "height": height, "tiles": tiles,
		"start": Vector2i(1, 1), "base_gate": Vector2i(0, 0),
		"exit": Vector2i(width - 1, height - 1), "exit_known": true,
		"cradle": Vector2i(-1, -1), "cradle_known": false,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [], "enemies": [], "visible_cells": {},
		"explored_cells": {}, "observed_cells": {},
	}


func _reveal_floor(main) -> void:
	var cells := {}
	for cell in main.floor_data["tiles"]:
		cells[cell] = true
	main.floor_data["visible_cells"] = cells.duplicate(true)
	main.floor_data["explored_cells"] = cells.duplicate(true)
	main.floor_data["observed_cells"] = cells.duplicate(true)


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
