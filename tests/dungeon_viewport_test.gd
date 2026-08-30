class_name DungeonViewportTestSuite
extends RefCounted

const DungeonView := preload("res://scripts/ui/dungeon_viewport.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const Presentation := preload("res://scripts/system/presentation_settings.gd")
const MainScript := preload("res://scripts/main.gd")
const BaseLayout := preload("res://scripts/ui/base_layout.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_camera_math()
	await _test_main_integration(tree)
	return failures


func _test_camera_math() -> void:
	_expect(
		is_equal_approx(MainScript.MOVE_REPEAT_INITIAL_DELAY, 0.28)
		and is_equal_approx(MainScript.MOVE_REPEAT_INTERVAL, 0.11)
		and is_equal_approx(MainScript.AUTO_STEP_DELAY, 0.275)
		and is_equal_approx(
			MainScript.AUTO_STEP_DELAY, MainScript.MOVE_REPEAT_INTERVAL * 2.5
		),
		"Automatic movement must use one exact 2.5x delay without changing manual repeat timing",
	)
	_expect(DungeonView.VIEW_RECT == Rect2(8, 8, 1056, 660), "Dungeon viewport rect must match the 16x10-cell contract")
	_expect(DungeonView.CELL_SIZE == Renderer.CELL_SIZE, "Camera, input and rendering must share one cell-size source")
	_expect(Renderer.CELL_SIZE == 66, "Dungeon cells must be exactly 66 virtual pixels")
	_expect(
		Presentation.sanitize_cell_size(44) == 44
		and Presentation.sanitize_cell_size(66) == 66
		and Presentation.sanitize_cell_size(88) == 88
		and Presentation.sanitize_cell_size(33) == 66
		and Presentation.sanitize_cell_size("88") == 66,
		"Dungeon zoom must accept only 44/66/88 and sanitize everything else to 66",
	)
	_expect(
		Presentation.clamped_cell_size_step(44, -1) == 44
		and Presentation.clamped_cell_size_step(44, 1) == 66
		and Presentation.clamped_cell_size_step(66, -1) == 44
		and Presentation.clamped_cell_size_step(66, 1) == 88
		and Presentation.clamped_cell_size_step(88, 1) == 88,
		"Dungeon zoom hotkey steps must clamp at 44/88 instead of wrapping",
	)
	_expect(
		Presentation.AUTO_MOVEMENT_SPEED_PERCENTS == [100, 150, 200, 225]
		and Presentation.DEFAULT_AUTO_MOVEMENT_SPEED_PERCENT == 100
		and Presentation.sanitize_auto_movement_speed_percent(100) == 100
		and Presentation.sanitize_auto_movement_speed_percent(150) == 150
		and Presentation.sanitize_auto_movement_speed_percent(200) == 200
		and Presentation.sanitize_auto_movement_speed_percent(225) == 225
		and Presentation.sanitize_auto_movement_speed_percent(175) == 100
		and Presentation.sanitize_auto_movement_speed_percent(150.5) == 100
		and Presentation.sanitize_auto_movement_speed_percent("225") == 100,
		"Automatic movement speed must accept only the exact global 100/150/200/225 contract",
	)
	_expect(
		Presentation.next_auto_movement_speed_percent(100) == 150
		and Presentation.next_auto_movement_speed_percent(150) == 200
		and Presentation.next_auto_movement_speed_percent(200) == 225
		and Presentation.next_auto_movement_speed_percent(225) == 100
		and is_equal_approx(Presentation.auto_movement_speed_multiplier(225), 2.25),
		"Automatic movement speed must cycle Base/+50/+100/+125 and expose one multiplier",
	)
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
	var expected_zoom_geometry := {
		44: {"world": Vector2(880, 616), "max": Vector2.ZERO, "camera": Vector2.ZERO, "padding": Vector2(88, 22)},
		66: {"world": Vector2(1320, 924), "max": Vector2(264, 264), "camera": Vector2(165, 165), "padding": Vector2.ZERO},
		88: {"world": Vector2(1760, 1232), "max": Vector2(704, 572), "camera": Vector2(396, 330), "padding": Vector2.ZERO},
	}
	for cell_size in [44, 66, 88]:
		var geometry: Dictionary = expected_zoom_geometry[cell_size]
		_expect(DungeonView.world_pixel_size(large, cell_size) == geometry["world"], "World pixel size must follow zoom %d" % cell_size)
		_expect(DungeonView.max_camera(large, DungeonView.VIEW_RECT.size, cell_size) == geometry["max"], "Camera maximum must follow zoom %d" % cell_size)
		_expect(DungeonView.camera_for(large, Vector2i(10, 7), DungeonView.VIEW_RECT.size, cell_size) == geometry["camera"], "Centered camera must follow zoom %d" % cell_size)
		_expect(DungeonView.padding_for(Vector2i(20, 14), DungeonView.VIEW_RECT.size, cell_size) == geometry["padding"], "Small-at-this-zoom maps must center at zoom %d" % cell_size)
		var expected_capacity := Vector2(1056.0 / cell_size, 660.0 / cell_size)
		_expect(expected_capacity == Vector2(DungeonView.VIEW_RECT.size) / cell_size, "Viewport cell capacity must stay presentation-only at zoom %d" % cell_size)
	var soul_image := Renderer.SOUL_ICON_TEXTURE.get_image()
	var has_blue := false
	var has_white := false
	for y in range(0, soul_image.get_height(), maxi(1, soul_image.get_height() / 24)):
		for x in range(0, soul_image.get_width(), maxi(1, soul_image.get_width() / 24)):
			var pixel := soul_image.get_pixel(x, y)
			has_blue = has_blue or (pixel.a > 0.7 and pixel.b > pixel.r * 1.25)
			has_white = has_white or (pixel.a > 0.7 and pixel.r > 0.85 and pixel.g > 0.85 and pixel.b > 0.85)
	_expect(
		not soul_image.is_empty() and soul_image.get_size() == Vector2i(64, 64)
		and soul_image.get_pixel(0, 0).a < 0.05
		and has_blue and has_white,
		"Soul icon must remain a 64x64 RGBA source with transparent corners and readable blue/white artwork",
	)

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
	for cell_size in [44, 66, 88]:
		for focus in [Vector2i.ZERO, large / 2, large - Vector2i.ONE]:
			var origin := DungeonView.child_origin_for(large, focus, DungeonView.VIEW_RECT.size, cell_size)
			for cell in [Vector2i.ZERO, Vector2i(10, 7), large - Vector2i.ONE]:
				var screen_center: Vector2 = DungeonView.VIEW_RECT.position + origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size
				if DungeonView.VIEW_RECT.has_point(screen_center):
					_expect(
						DungeonView.world_cell_from_screen(screen_center, DungeonView.VIEW_RECT, large, focus, cell_size) == cell,
						"World/screen cell-center roundtrip must hold at zoom %d" % cell_size,
					)


func _test_main_integration(tree: SceneTree) -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	main.auto_step_delay_override = 0.0
	tree.root.add_child(main)
	await tree.process_frame
	main.auto_step_delay_override = -1.0
	var expected_auto_delays := {
		100: 0.275,
		150: 0.275 / 1.5,
		200: 0.1375,
		225: 0.275 / 2.25,
	}
	for speed_percent in expected_auto_delays:
		main.auto_movement_speed_percent = speed_percent
		_expect(
			is_equal_approx(
				main._automatic_step_delay_seconds(), expected_auto_delays[speed_percent],
			),
			"Both automatic loops must use the shared effective delay at %d%%" % speed_percent,
		)
	main.auto_movement_speed_percent = 225
	main.auto_step_delay_override = 0.03125
	_expect(
		is_equal_approx(main._automatic_step_delay_seconds(), 0.03125),
		"An absolute automatic-step test override must never be divided by the global speed",
	)
	main.auto_step_delay_override = 0.0
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
	main.inspected_target = {"kind": "tile", "pos": Vector2i(12, 7)}
	for cell_size in [44, 66, 88]:
		main.set_dungeon_cell_size(cell_size)
		_expect(
			main.dungeon_cell_size == cell_size
			and main.dungeon_viewport.runtime_cell_size == cell_size
			and main.inspected_target.get("pos") == Vector2i(12, 7),
			"Zoom %d must update one runtime transform without clearing inspection" % cell_size,
		)
		await _push_mouse(main, tree, main.dungeon_viewport.world_to_screen_center(Vector2i(12, 7)))
		_expect(main.inspected_target.get("pos") == Vector2i(12, 7), "Mouse inverse transform must select the same cell at zoom %d" % cell_size)
	main.set_dungeon_cell_size(66)
	await _test_zoom_hotkeys(main, tree)

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
	main.state.character_name = "Keeper of the Long Soul"
	main.state.current_form_id = "almost_human"
	main.state.absorbed_souls = 80
	main.state.highest_unlocked_form_index = 4
	main.state.skill_levels["choose_appearance"] = 1
	main.state.display_form_id = "skeleton"
	main.state.carried_souls = 9999
	main.state.banked_souls = 9999
	var previous_locale: String = Loc.current_locale
	for test_locale in ["ru", "en"]:
		Loc.set_locale(test_locale)
		main._refresh_interface()
		_expect(
			main.stats_label.get_theme_font("font").get_string_size(
				main.stats_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				main.stats_label.get_theme_font_size("font_size"),
			).x <= main.stats_label.size.x,
			"Long dungeon character name must fit its own rail line without clipping",
		)
		_expect(
			main.title_label.text == Loc.text("FORM_ALMOST_HUMAN")
			and main.souls_label.text == "9999 (19998)"
			and not main.souls_label.text.contains("Souls")
			and not main.souls_label.text.contains("Души"),
			"Dungeon form must remain actual under a cosmetic override and soul text must be numbers only",
		)
		_expect(
			main.inspection_label.text.begins_with(Loc.text("TITLE_FLOOR", [main.state.current_floor]))
			and not main.inspection_label.text.to_lower().contains("path to the surface")
			and not main.inspection_label.text.to_lower().contains("путь к поверхности"),
			"Dungeon inspection must begin with the short level and contain no path-to-surface phrase",
		)
	Loc.set_locale(previous_locale)
	main._apply_locale()
	var expected_level := Loc.text("TITLE_FLOOR", [main.state.current_floor])
	main.inspected_target.clear()
	main._refresh_inspection_panel()
	_expect(main.inspection_label.text.begins_with(expected_level), "Automatic inspection must keep the short level as its first line")
	var saved_enemies: Array = main.floor_data["enemies"]
	var saved_items: Array = main.floor_data["items"]
	var saved_cradle: Vector2i = main.floor_data["cradle"]
	var saved_start: Vector2i = main.floor_data["start"]
	var saved_base_gate: Vector2i = main.floor_data["base_gate"]
	var saved_exit: Vector2i = main.floor_data["exit"]
	main.floor_data["enemies"] = []
	main.floor_data["items"] = []
	main.floor_data["cradle"] = Vector2i(0, 0)
	main.floor_data["start"] = Vector2i(0, 0)
	main.floor_data["base_gate"] = Vector2i(0, 0)
	main.floor_data["exit"] = Vector2i(0, 0)
	main.inspected_target.clear()
	main._refresh_inspection_panel()
	_expect(main.inspection_label.text.begins_with(expected_level), "Empty inspection must keep the short level as its first line")
	main.floor_data["cradle"] = main.player_pos + Vector2i.RIGHT
	main.inspected_target = {"kind": "cradle", "pos": main.floor_data["cradle"]}
	main._refresh_inspection_panel()
	_expect(main.inspection_label.text.begins_with(expected_level) and main.inspection_label.text.contains(Loc.text("INSPECT_CRADLE")), "Cradle inspection must keep level first and retain contextual requirements")
	main.floor_data["enemies"] = saved_enemies
	main.floor_data["items"] = saved_items
	main.floor_data["cradle"] = saved_cradle
	main.floor_data["start"] = saved_start
	main.floor_data["base_gate"] = saved_base_gate
	main.floor_data["exit"] = saved_exit
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

	# Settings cancel an in-flight delayed step, and the stale coroutine cannot
	# resume after the modal closes.
	main.floor_data = _floor_fixture(20, 14)
	main.player_pos = Vector2i(2, 2)
	main.floor_data["explored_cells"] = {Vector2i(2, 2): true, Vector2i(3, 2): true}
	main.floor_data["visible_cells"] = main.floor_data["explored_cells"].duplicate(true)
	main.floor_data["observed_cells"] = main.floor_data["explored_cells"].duplicate(true)
	main.floor_data["enemies"] = []
	main._refresh_dungeon_viewport()
	main.auto_step_delay_override = 0.05
	turns_before = main.state.total_turns
	main._on_auto_explore_pressed()
	var first_auto_position: Vector2i = main.player_pos
	var turns_after_first_auto_step: int = main.state.total_turns
	_expect(
		turns_after_first_auto_step == turns_before + 1 and main.auto_explore_active,
		"Auto-explore must take its first turn immediately before using the shared delay",
	)
	await tree.process_frame
	_expect(
		main.player_pos == first_auto_position
		and main.state.total_turns == turns_after_first_auto_step
		and main.auto_explore_active,
		"Auto-explore must wait for its configured delay before a second turn",
	)
	main._open_settings()
	await tree.create_timer(0.08).timeout
	_expect(
		main.player_pos == first_auto_position
		and main.state.total_turns == turns_after_first_auto_step
		and not main.auto_explore_active and not main.auto_travel_active,
		"Opening Settings during the delay must cancel auto-explore without a stale extra turn",
	)
	main._close_settings()
	await tree.create_timer(0.08).timeout
	_expect(
		main.player_pos == first_auto_position
		and main.state.total_turns == turns_after_first_auto_step,
		"Closing Settings must not revive the cancelled auto-explore coroutine",
	)
	main.auto_step_delay_override = 0.0

	# Dungeon overlays consume input instead of forwarding it to the enlarged map.
	var position_before: Vector2i = main.player_pos
	turns_before = main.state.total_turns
	main._open_settings()
	_expect(main.soul_icon.visible and not main.equipment_label.visible, "Dungeon settings overlay must preserve the compact HUD beneath its blocker")
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
		and not main.soul_icon.visible
		and main.title_label.position == Vector2(20, 14)
		and main.title_label.size == Vector2(365, 34),
		"Character screen opened from Dungeon must use the fixed Character header layout",
	)
	main._close_character()
	_expect(
		main.screen == main.Screen.DUNGEON
		and main.dungeon_viewport.visible
		and main.soul_icon.visible and not main.equipment_label.visible
		and Rect2(main.title_label.position, main.title_label.size) == Rect2(1080, 86, 184, 20),
		"Closing Character must restore the compact Dungeon layout and viewport (screen=%s viewport=%s icon=%s equipment=%s title=%s)" % [
			main.screen, main.dungeon_viewport.visible, main.soul_icon.visible,
			main.equipment_label.visible, Rect2(main.title_label.position, main.title_label.size),
		],
	)
	main._show_base("")
	_expect(
		not main.dungeon_viewport.visible
		and main.soul_icon.visible
		and Rect2(main.soul_icon.position, main.soul_icon.size) == main.BASE_SOUL_ICON_RECT
		and Rect2(main.souls_label.position, main.souls_label.size) == main.BASE_SOULS_RECT
		and main.material_resources_strip.visible
		and Rect2(
			main.material_resources_strip.position, main.material_resources_strip.size
		) == main.BASE_MATERIALS_RECT
		and Rect2(main.stats_label.position, main.stats_label.size) == BaseLayout.STATS_RECT
		and main.equipment_label.position == Vector2(846, 338)
		and main.inspection_label.position == Vector2(860, 508)
		and Rect2(main.hint_label.position, main.hint_label.size) == BaseLayout.HINT_RECT
		and Rect2(main.message_label.position, main.message_label.size) == BaseLayout.MESSAGE_RECT,
		"Leaving Dungeon must restore the base layout and its compact resource strip",
	)
	main.queue_free()
	await tree.process_frame


func _test_zoom_hotkeys(main, tree: SceneTree) -> void:
	main.set_dungeon_cell_size(44)
	await _push_key(main, tree, KEY_EQUAL, 43, true)
	_expect(main.dungeon_cell_size == 66, "Shift+= must zoom the dungeon from 44 to 66")
	await _push_key(main, tree, KEY_KP_SUBTRACT)
	await _push_key(main, tree, KEY_PLUS)
	_expect(main.dungeon_cell_size == 66, "KEY_PLUS fallback must zoom the dungeon from 44 to 66")
	await _push_key(main, tree, KEY_NONE, 43)
	_expect(main.dungeon_cell_size == 88, "Unicode plus must zoom the dungeon from 66 to 88")
	await _push_key(main, tree, KEY_KP_ADD)
	_expect(main.dungeon_cell_size == 88, "Numpad add must clamp dungeon zoom at 88")
	_expect(
		main._handle_dungeon_zoom_hotkey(_zoom_key(KEY_KP_ADD))
		and main.dungeon_cell_size == 88,
		"A recognized zoom key at the upper boundary must be consumed without wrapping",
	)
	await _push_key(main, tree, KEY_MINUS, 45)
	_expect(main.dungeon_cell_size == 66, "Main minus must zoom the dungeon from 88 to 66")
	await _push_key(main, tree, KEY_KP_SUBTRACT)
	_expect(main.dungeon_cell_size == 44, "Numpad subtract must zoom the dungeon from 66 to 44")
	await _push_key(main, tree, KEY_KP_SUBTRACT)
	_expect(main.dungeon_cell_size == 44, "Numpad subtract must clamp dungeon zoom at 44")

	# Release, echo, unsupported modifiers and an unshifted equals key are not presentation commands.
	for ignored_event in [
		_zoom_key(KEY_PLUS, 43, false, false, false),
		_zoom_key(KEY_PLUS, 43, false, true, true),
		_zoom_key(KEY_PLUS, 43, false, false, true, true),
		_zoom_key(KEY_PLUS, 43, false, false, true, false, true),
		_zoom_key(KEY_PLUS, 43, false, false, true, false, false, true),
		_zoom_key(KEY_EQUAL),
	]:
		main.get_viewport().push_input(ignored_event, true)
		await tree.process_frame
		_expect(main.dungeon_cell_size == 44, "Release/echo/modifier/non-plus key must not change dungeon zoom")

	# Blocking overlays and non-dungeon screens retain input priority.
	main._open_settings()
	await _push_key(main, tree, KEY_KP_ADD)
	_expect(main.dungeon_cell_size == 44, "Settings must block fixed dungeon zoom hotkeys")
	main._close_settings()
	main.screen = main.Screen.BASE
	await _push_key(main, tree, KEY_KP_ADD)
	_expect(main.dungeon_cell_size == 44, "Dungeon zoom hotkeys must be a no-op outside Dungeon")
	main.screen = main.Screen.DUNGEON

	# Zoom is processed before Dash/automatic movement early returns and changes presentation only.
	main.set_dungeon_cell_size(66)
	main.inspected_target = {"kind": "tile", "pos": Vector2i(12, 7)}
	main.ability_targeting_id = "dash"
	main.ability_target_cells.clear()
	main.ability_target_cells.append_array([Vector2i(11, 7), Vector2i(12, 7)])
	main.ability_unavailable_cells = {Vector2i(13, 7): "blocked"}
	main.ability_target_cursor = Vector2i(12, 7)
	main.auto_explore_active = true
	main.auto_travel_active = true
	main.magic_traces.clear()
	main.magic_traces.append({
		"from": Vector2i(10, 7), "to": Vector2i(12, 7), "remaining": 100.0,
	})
	main.projectile_traces.clear()
	main.projectile_traces.append({
		"from": Vector2i(9, 7), "to": Vector2i(13, 7), "remaining": 100.0,
	})
	var turns_before: int = main.state.total_turns
	var position_before: Vector2i = main.player_pos
	var visible_before: Dictionary = main.floor_data["visible_cells"].duplicate(true)
	var explored_before: Dictionary = main.floor_data["explored_cells"].duplicate(true)
	await _push_key(main, tree, KEY_KP_ADD)
	_expect(main.dungeon_cell_size == 88, "Zoom hotkeys must remain active during Dash and automatic movement")
	_expect(
		main.state.total_turns == turns_before
		and main.player_pos == position_before
		and main.inspected_target.get("pos") == Vector2i(12, 7)
		and main.ability_targeting_id == "dash"
		and main.ability_target_cells == [Vector2i(11, 7), Vector2i(12, 7)]
		and main.ability_unavailable_cells.has(Vector2i(13, 7))
		and main.ability_target_cursor == Vector2i(12, 7)
		and main.auto_explore_active and main.auto_travel_active
		and main.magic_traces.size() == 1
		and main.magic_traces[0]["from"] == Vector2i(10, 7)
		and main.magic_traces[0]["to"] == Vector2i(12, 7)
		and main.projectile_traces.size() == 1
		and main.projectile_traces[0]["from"] == Vector2i(9, 7)
		and main.projectile_traces[0]["to"] == Vector2i(13, 7)
		and main.floor_data["visible_cells"] == visible_before
		and main.floor_data["explored_cells"] == explored_before,
		"Zoom hotkeys must preserve targeting, automation, inspection, traces and gameplay state",
	)
	main.ability_targeting_id = ""
	main.ability_target_cells.clear()
	main.ability_unavailable_cells.clear()
	main.ability_target_cursor = Vector2i(-1, -1)
	main.auto_explore_active = false
	main.auto_travel_active = false
	main.magic_traces.clear()
	main.projectile_traces.clear()
	main.set_dungeon_cell_size(66)


func _zoom_key(
	keycode: Key,
	unicode_value := 0,
	shift := false,
	echo := false,
	pressed := true,
	ctrl := false,
	alt := false,
	meta := false,
) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.unicode = unicode_value
	event.shift_pressed = shift
	event.echo = echo
	event.pressed = pressed
	event.ctrl_pressed = ctrl
	event.alt_pressed = alt
	event.meta_pressed = meta
	return event


func _push_key(
	main,
	tree: SceneTree,
	keycode: Key,
	unicode_value := 0,
	shift := false,
) -> void:
	main.get_viewport().push_input(_zoom_key(keycode, unicode_value, shift), true)
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
		main.title_label, main.souls_label, main.soul_icon, main.menu_button, main.stats_label,
		main.sidebar_progress_label, main.inspection_label,
		main.hint_label, main.message_label, main.attack_button, main.spell_button,
		main.active_2_button, main.active_3_button, main.wait_button,
		main.wait_count_button, main.auto_explore_button, main.camp_button,
		main.character_action_button, main.interact_button,
	]:
		control.visible = true
	main.equipment_label.visible = false


func _test_dungeon_geometry(main) -> void:
	var map_rect := Renderer.DUNGEON_VIEW_RECT
	var rail_rect := Renderer.DUNGEON_SIDEBAR_RECT
	var expected_controls := {
		main.soul_icon: Rect2(1080, 22, 22, 22), main.souls_label: Rect2(1106, 16, 64, 34),
		main.menu_button: Rect2(1174, 16, 90, 34), main.stats_label: Rect2(1080, 60, 184, 24),
		main.title_label: Rect2(1080, 86, 184, 20), main.sidebar_progress_label: Rect2(1080, 208, 184, 26),
		main.status_strip: Rect2(1080, 146, 184, 30), main.inspection_label: Rect2(1088, 246, 168, 246), main.hint_label: Rect2(1088, 514, 168, 22),
		main.message_label: Rect2(1088, 540, 168, 154),
	}
	for control in expected_controls:
		var rect: Rect2 = Rect2(control.position, control.size)
		_expect(rect == expected_controls[control], "Dungeon rail control must use its exact marked geometry")
		_expect(rail_rect.encloses(rect) and not rect.intersects(map_rect), "Dungeon rail control must stay inside the rail and outside the map")
	for frame in [Renderer.DUNGEON_HP_RECT, Renderer.DUNGEON_STATUS_RECT, Renderer.DUNGEON_MANA_RECT, Renderer.DUNGEON_INSPECTION_RECT, Renderer.DUNGEON_HISTORY_RECT]:
		_expect(rail_rect.encloses(frame) and not frame.intersects(map_rect), "Dungeon status frame must stay inside the rail and outside the map")
	_expect(
		Renderer.DUNGEON_HP_RECT == Rect2(1080, 116, 184, 26)
		and Renderer.DUNGEON_STATUS_RECT == Rect2(1080, 146, 184, 30)
		and Renderer.DUNGEON_MANA_RECT == Rect2(1080, 180, 184, 26)
		and Renderer.DUNGEON_INSPECTION_RECT == Rect2(1080, 238, 184, 262)
		and Renderer.DUNGEON_HISTORY_RECT == Rect2(1080, 506, 184, 196),
		"Dungeon status and enlarged inspection frames must keep their exact HUD geometry",
	)
	_expect(not main.equipment_label.visible and main.soul_icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Dungeon equipment must stay hidden and the soul icon must never intercept input")
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
