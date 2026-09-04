class_name DungeonViewportTestSuite
extends RefCounted

const DungeonView := preload("res://scripts/ui/dungeon_viewport.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const Presentation := preload("res://scripts/system/presentation_settings.gd")
const MainScript := preload("res://scripts/main.gd")
const BaseLayout := preload("res://scripts/ui/base_layout.gd")
const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")
const AbilitySystem := preload("res://scripts/game/skill_system.gd")
const RunSnapshot := preload("res://scripts/system/run_snapshot.gd")
const SaveSystem := preload("res://scripts/system/persistence.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_camera_math()
	await _test_melee_lunge_contract(tree)
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
		"Automatic movement speed must cycle Normal/Faster/Very fast/Maximum and expose one multiplier",
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


func _test_melee_lunge_contract(tree: SceneTree) -> void:
	var origin := Vector2i(3, 3)
	var target := Vector2i(4, 3)
	var at_zero := Renderer._melee_lunge_offset({"direction": Vector2.RIGHT, "elapsed": 0.0})
	var at_cubic_mid := Renderer._melee_lunge_offset({"direction": Vector2.RIGHT, "elapsed": 0.0315})
	var at_peak := Renderer._melee_lunge_offset({"direction": Vector2.RIGHT, "elapsed": 0.063})
	var at_quad_mid := Renderer._melee_lunge_offset({"direction": Vector2.RIGHT, "elapsed": 0.1065})
	var at_end := Renderer._melee_lunge_offset({"direction": Vector2.RIGHT, "elapsed": 0.150})
	_expect(at_zero == Vector2.ZERO and is_equal_approx(at_peak.x, 0.15) and at_end == Vector2.ZERO,
		"Melee lunge must be an exact 0.15-cell cubic-out/quad-in 0/63/150ms transient")
	_expect(
		is_equal_approx(at_cubic_mid.x, 0.13125) and is_equal_approx(at_quad_mid.x, 0.1125),
		"Melee lunge must retain exact interior cubic-out (31.5ms=0.13125) and quadratic-in (106.5ms=0.1125) samples",
	)
	for cell_size in [44.0, 66.0, 88.0]:
		_expect(is_equal_approx(Renderer.lunge_pixel_offset(at_peak, cell_size).x, cell_size * 0.15) and Renderer.lunge_pixel_offset(at_zero, cell_size) == Vector2.ZERO and Renderer.lunge_pixel_offset(at_end, cell_size) == Vector2.ZERO, "Production lunge pixel geometry must be 6.6/9.9/13.2 at peak and zero at endpoints")
		Renderer.set_runtime_cell_size(int(cell_size))
		var logical := Renderer.cell_rect(origin, int(cell_size))
		var peak_cell := Renderer.lunge_cell_rect(origin, at_peak, int(cell_size))
		var end_cell := Renderer.lunge_cell_rect(origin, at_end, int(cell_size))
		var sprite_base := Renderer.entity_draw_rect(origin, Vector2(32, 48), Vector2(1.2, 1.5))
		var sprite_peak := Renderer.entity_draw_rect(origin, Vector2(32, 48), Vector2(1.2, 1.5), at_peak)
		var gait := Vector2(-0.05, 0.02)
		var gait_peak := Renderer.lunge_cell_rect(origin, gait + at_peak, int(cell_size))
		var delta := Vector2(cell_size * 0.15, 0)
		_expect((peak_cell.position - logical.position).is_equal_approx(delta) and end_cell.position.is_equal_approx(logical.position) and (sprite_peak.position - sprite_base.position).is_equal_approx(delta) and (gait_peak.position - Renderer.lunge_cell_rect(origin, gait, int(cell_size)).position).is_equal_approx(delta) and Renderer.cell_rect(origin, int(cell_size)) == logical, "Production cell/sprite/gait anchors must share the exact lunge delta while logical cell geometry remains fixed")
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.configure_character("Lunge contract", GameRules.default_attributes())
	var lunge_starts := {}
	main.melee_lunge_started.connect(func(actor_uid: String, _from: Vector2i, _target: Vector2i): lunge_starts[actor_uid] = int(lunge_starts.get(actor_uid, 0)) + 1)
	main._start_melee_lunge("player", origin, target)
	main._start_melee_lunge("enemy-a", target, origin)
	_expect(main.melee_lunges.size() == 2 and main.melee_lunges.player.direction == Vector2.RIGHT,
		"Player and enemy melee lunges must coexist and retain actor-neutral directions")
	main._start_melee_lunge("player", origin, Vector2i(3, 4))
	_expect(main.melee_lunges.size() == 2 and main.melee_lunges.player.direction == Vector2.DOWN and is_zero_approx(main.melee_lunges.player.elapsed),
		"A second action from the same actor must restart only that actor's lunge")
	main._update_hit_effects(0.150)
	_expect(main.melee_lunges.is_empty(), "Lunge entries must expire at 150ms without persistent state")
	main._start_melee_lunge("player", origin, target)
	main._clear_hit_effects()
	_expect(main.melee_lunges.is_empty(), "All transition/reset hit-effect clearing must also clear melee lunge transients")
	main.floor_data = _floor_fixture(8, 8)
	main.player_pos = origin
	main.floor_data["enemies"] = [{"uid": "direct-helper", "id": "hollow_guard", "pos": target, "hp": 4, "dodge": 0, "damage": 1, "accuracy": 1, "souls": 2}]
	main._perform_melee_strike("direct-helper", 1)
	_expect(main.melee_lunges.is_empty(), "Raw melee helper calls must remain presentation-free; only committed action entry points start a lunge")
	# Exercise the committed player classification rather than only the transient
	# helper: basic hit/miss and multi-strike share one presentation start.
	main.floor_data = _floor_fixture(8, 8)
	main.player_pos = origin
	_reveal_floor(main)
	main.floor_data["enemies"] = [{"uid": "committed", "id": "hollow_guard", "pos": target, "hp": 99, "dodge": 0, "damage": 1, "accuracy": 1, "souls": 2}]
	lunge_starts.clear()
	_expect(main._execute_attack_ability("basic_attack", "committed", {"attack_rolls": [20]}) and main.melee_lunges.has("player"), "Committed player hit must start exactly one lunge after target validation")
	_expect(int(lunge_starts.get("player", 0)) == 1, "Committed basic hit must invoke the transient start exactly once")
	main._clear_hit_effects()
	lunge_starts.clear()
	_expect(main._execute_attack_ability("basic_attack", "committed", {"attack_rolls": [1]}) and int(lunge_starts.get("player", 0)) == 1, "Committed basic miss must still start exactly one lunge")
	var direction_before: Vector2 = main.melee_lunges.player.direction
	lunge_starts.clear()
	main._execute_attack_ability("double_attack", "committed", {"attack_rolls": [1, 20]})
	_expect(main.melee_lunges.size() == 1 and main.melee_lunges.player.direction == direction_before and int(lunge_starts.get("player", 0)) == 1, "Committed multi-hit must start once per action, not once per subhit")
	main._clear_hit_effects()
	lunge_starts.clear()
	main.floor_data["enemies"][0].hp = 1
	_expect(main._execute_attack_ability("basic_attack", "committed", {"attack_rolls": [20]}) and int(lunge_starts.get("player", 0)) == 1, "Committed lethal melee must retain its one presentation start")
	main.floor_data["enemies"] = [{"uid": "circle-right", "id": "hollow_guard", "pos": target, "hp": 99, "dodge": 0, "damage": 1, "accuracy": 1, "souls": 2}, {"uid": "circle-left", "id": "hollow_guard", "pos": origin + Vector2i.LEFT, "hp": 99, "dodge": 0, "damage": 1, "accuracy": 1, "souls": 2}]
	main._clear_hit_effects()
	lunge_starts.clear()
	var circular_first := Vector2i.ZERO
	for cell in AbilitySystem.circular_target_cells(origin):
		if cell == target or cell == origin + Vector2i.LEFT:
			circular_first = cell
			break
	_expect(main._execute_attack_ability("circular_attack", "", {"attack_rolls": [1, 1]}) and int(lunge_starts.get("player", 0)) == 1 and main.melee_lunges.player.direction == Vector2(circular_first - origin).normalized(), "Circular melee must start once toward its deterministic first existing target")
	main._clear_hit_effects()
	main.floor_data["enemies"] = []
	_expect(not main._execute_attack_ability("basic_attack", "missing-uid", {"attack_rolls": [20]}) and main.melee_lunges.is_empty(), "Invalid committed target, like ranged/direct helper paths, must not create a lunge")
	main.floor_data["enemies"] = [{"uid": "committed", "id": "hollow_guard", "pos": target, "hp": 99, "dodge": 0, "damage": 1, "accuracy": 1, "souls": 2}]
	main._clear_hit_effects()
	main.floor_data["visible_cells"] = {}
	main.state.hp = main.state.get_max_hp()
	lunge_starts.clear()
	var hidden_hp: int = main.state.hp
	main._enemy_melee_strike(main.floor_data["enemies"][0], 1, 1, true)
	_expect(main.melee_lunges.is_empty() and main.state.hp == hidden_hp and int(lunge_starts.get("committed", 0)) == 0, "Hidden enemy melee must suppress presentation while retaining its forced-miss combat resolution")
	_reveal_floor(main)
	main.state.hp = main.state.get_max_hp()
	lunge_starts.clear()
	var visible_hit_hp: int = main.state.hp
	main._enemy_melee_strike(main.floor_data["enemies"][0], 1, 20, true)
	_expect(main.melee_lunges.has("committed") and int(lunge_starts.get("committed", 0)) == 1 and main.state.hp == visible_hit_hp - 1, "Visible forced-hit enemy melee must damage and start exactly one actor-neutral lunge")
	main._clear_hit_effects()
	main.state.hp = main.state.get_max_hp()
	lunge_starts.clear()
	var visible_miss_hp: int = main.state.hp
	main._enemy_melee_strike(main.floor_data["enemies"][0], 1, 1, true)
	_expect(main.melee_lunges.has("committed") and int(lunge_starts.get("committed", 0)) == 1 and main.state.hp == visible_miss_hp, "Visible forced-miss enemy melee must retain combat outcome and one actor-neutral lunge")
	main._clear_hit_effects()
	lunge_starts.clear()
	var enemy_turn: Dictionary = main.floor_data["enemies"][0]
	enemy_turn["has_seen_player"] = true
	enemy_turn["pos"] = target
	enemy_turn["accuracy"] = 100
	main.floor_data["enemies"] = [enemy_turn]
	main.state.hp = 999
	main.rng.seed = 4101
	var normal_enemy_hp: int = main.state.hp
	main._enemy_turn()
	_expect(int(lunge_starts.get("committed", 0)) == 1 and main.melee_lunges.get("committed", {}).get("direction", Vector2.ZERO) == Vector2.LEFT and main.state.hp == normal_enemy_hp - int(enemy_turn.damage), "Seeded actual adjacent enemy-turn melee must hit, damage, and start once toward the player")
	main._clear_hit_effects()
	lunge_starts.clear()
	main.floor_data["enemies"] = [{"uid": "arachnid-turn", "id": "arachnid", "pos": target, "hp": 7, "dodge": 3, "damage": 2, "accuracy": -100, "souls": 3, "has_seen_player": true, "ability_cooldowns": {}}]
	main.state.hp = 999
	main.rng.seed = 4102
	var arachnid_hp: int = main.state.hp
	main._enemy_turn()
	_expect(int(lunge_starts.get("arachnid-turn", 0)) == 1 and main.melee_lunges.get("arachnid-turn", {}).get("direction", Vector2.ZERO) == Vector2.LEFT and main.state.hp == arachnid_hp, "Seeded actual arachnid double-attack misses twice while emitting one first-strike lunge")
	main._clear_hit_effects()
	lunge_starts.clear()
	main.floor_data["enemies"] = [{"uid": "slag-turn", "id": "slag_smith", "pos": target, "hp": 10, "dodge": 0, "damage": 2, "accuracy": 100, "souls": 5, "has_seen_player": true}]
	main.state.hp = 999
	main.rng.seed = 4103
	main._enemy_turn()
	_expect(int(lunge_starts.get("slag-turn", 0)) == 0 and main.floor_data["enemies"][0].has("preparation"), "Actual slag-smith turn must prepare heavy melee without a lunge")
	var heavy_hp: int = main.state.hp
	main._enemy_turn()
	_expect(int(lunge_starts.get("slag-turn", 0)) == 1 and not main.floor_data["enemies"][0].has("preparation") and main.state.hp < heavy_hp, "Seeded prepared heavy release must hit and emit exactly one lunge")
	main._clear_hit_effects()
	lunge_starts.clear()
	main.floor_data["enemies"] = [{"uid": "crossbow-turn", "id": "bone_crossbowman", "pos": origin + Vector2i(3, 0), "hp": 5, "dodge": 0, "damage": 2, "accuracy": -100, "souls": 3, "has_seen_player": true}]
	main.state.hp = 999
	main.rng.seed = 4104
	main._enemy_turn()
	_expect(int(lunge_starts.get("crossbow-turn", 0)) == 0 and main.melee_lunges.is_empty() and main.floor_data["enemies"][0].has("preparation"), "Actual crossbow preparation must remain ranged and create no lunge")
	main._enemy_turn()
	main._enemy_turn()
	_expect(int(lunge_starts.get("crossbow-turn", 0)) == 0 and main.melee_lunges.is_empty() and int(main.floor_data["enemies"][0].get("special_cooldown", 0)) > 0, "Actual prepared crossbow release must retain ranged cooldown without a lunge")
	main._clear_hit_effects()
	lunge_starts.clear()
	main.floor_data["enemies"] = [{"uid": "archer-turn", "id": "skeletal_archer", "pos": origin + Vector2i(3, 0), "hp": 4, "dodge": 1, "damage": 1, "accuracy": 100, "souls": 2, "has_seen_player": true}]
	main.state.hp = 999
	main.rng.seed = 4105
	var archer_hp: int = main.state.hp
	main._enemy_turn()
	_expect(int(lunge_starts.get("archer-turn", 0)) == 0 and main.melee_lunges.is_empty() and main.incoming_ranged_attack_this_turn and main.state.hp < archer_hp, "Seeded skeletal-archer turn must hit by ranged behavior without a lunge")
	main.incoming_ranged_attack_this_turn = false
	main._clear_hit_effects()
	lunge_starts.clear()
	main.floor_data["enemies"] = [{"uid": "minotaur-turn", "id": "minotaur", "pos": origin + Vector2i(4, 0), "hp": 36, "dodge": 0, "damage": 2, "accuracy": 4, "souls": 12, "has_seen_player": true}]
	main.state.hp = 999
	main.rng.seed = 4106
	main._enemy_turn()
	_expect(int(lunge_starts.get("minotaur-turn", 0)) == 0 and main.melee_lunges.is_empty() and main.floor_data["enemies"][0].pos == origin + Vector2i.RIGHT, "Actual minotaur dash turn must move to its endpoint without a lunge")
	main._clear_hit_effects()
	lunge_starts.clear()
	main.floor_data["visible_cells"] = {}
	main.floor_data["enemies"] = [{"uid": "hidden-turn", "id": "hollow_guard", "pos": target, "hp": 4, "dodge": 0, "damage": 1, "accuracy": 100, "souls": 2, "has_seen_player": true}]
	main.state.hp = 999
	main.rng.seed = 4107
	var hidden_turn_hp: int = main.state.hp
	main._enemy_turn()
	_expect(int(lunge_starts.get("hidden-turn", 0)) == 0 and main.melee_lunges.is_empty() and main.state.hp < hidden_turn_hp, "Seeded hidden adjacent melee turn must resolve combat while suppressing lunge presentation")
	_reveal_floor(main)
	# Presentation transients must never mutate gameplay/save/RNG/floor state.
	main.state.hp = main.state.get_max_hp()
	var save_before: Dictionary = main.state.to_save_data()
	var snapshot_before: Dictionary = main.state.to_snapshot_data()
	var floor_before: Dictionary = main.floor_data.duplicate(true)
	var rng_before: int = main.rng.state
	var turns_before: int = main.state.total_turns
	var player_before: Vector2i = main.player_pos
	main._refresh_dungeon_viewport()
	var camera_before: Vector2 = main.dungeon_viewport.camera
	var canvas_before: Vector2 = main.dungeon_viewport.world_canvas.position
	var inspected_before: Dictionary = main.inspected_target.duplicate(true)
	var targeting_before := [main.ability_targeting_id, main.ability_target_cells.duplicate(), main.ability_unavailable_cells.duplicate(true), main.ability_target_cursor]
	var focus_before: Control = main.get_viewport().gui_get_focus_owner()
	var save_bytes := JSON.stringify(save_before, "", false, true)
	var snapshot_bytes := JSON.stringify(snapshot_before, "", false, true)
	var envelope_before := JSON.stringify(RunSnapshot.capture("dungeon", main.floor_data, main.player_pos, main.rng, main.hearing_contacts.to_snapshot_data()), "", false, true)
	var persistence_path := "user://stage1e-lunge-presentation-invariance.json"
	_expect(SaveSystem.save_game(main.state, persistence_path) == OK, "Presentation-only lunge fixture must serialize to its isolated persistence payload")
	var persistence_before := FileAccess.get_file_as_bytes(persistence_path)
	main._start_melee_lunge("presentation-only", origin, target)
	var envelope_start := JSON.stringify(RunSnapshot.capture("dungeon", main.floor_data, main.player_pos, main.rng, main.hearing_contacts.to_snapshot_data()), "", false, true)
	SaveSystem.save_game(main.state, persistence_path)
	var persistence_start := FileAccess.get_file_as_bytes(persistence_path)
	main._update_hit_effects(0.063)
	var envelope_peak := JSON.stringify(RunSnapshot.capture("dungeon", main.floor_data, main.player_pos, main.rng, main.hearing_contacts.to_snapshot_data()), "", false, true)
	SaveSystem.save_game(main.state, persistence_path)
	var persistence_peak := FileAccess.get_file_as_bytes(persistence_path)
	main._update_hit_effects(0.087)
	var envelope_end := JSON.stringify(RunSnapshot.capture("dungeon", main.floor_data, main.player_pos, main.rng, main.hearing_contacts.to_snapshot_data()), "", false, true)
	SaveSystem.save_game(main.state, persistence_path)
	var persistence_end := FileAccess.get_file_as_bytes(persistence_path)
	main._clear_hit_effects()
	var envelope_clear := JSON.stringify(RunSnapshot.capture("dungeon", main.floor_data, main.player_pos, main.rng, main.hearing_contacts.to_snapshot_data()), "", false, true)
	SaveSystem.save_game(main.state, persistence_path)
	var persistence_clear := FileAccess.get_file_as_bytes(persistence_path)
	_expect(main.melee_lunges.is_empty() and main.state.to_save_data() == save_before and main.state.to_snapshot_data() == snapshot_before and main.floor_data == floor_before and main.rng.state == rng_before and main.state.total_turns == turns_before and main.player_pos == player_before and main.dungeon_viewport.camera == camera_before and main.dungeon_viewport.world_canvas.position == canvas_before and main.inspected_target == inspected_before and [main.ability_targeting_id, main.ability_target_cells, main.ability_unavailable_cells, main.ability_target_cursor] == targeting_before and main.get_viewport().gui_get_focus_owner() == focus_before, "Lunge start/peak/end/clear must remain presentation-only across gameplay, camera, targeting and focus state")
	_expect(JSON.stringify(main.state.to_save_data(), "", false, true) == save_bytes and JSON.stringify(main.state.to_snapshot_data(), "", false, true) == snapshot_bytes and envelope_before == envelope_start and envelope_before == envelope_peak and envelope_before == envelope_end and envelope_before == envelope_clear and persistence_before == persistence_start and persistence_before == persistence_peak and persistence_before == persistence_end and persistence_before == persistence_clear and not JSON.stringify(main.state.to_save_data()).contains("melee_lunge") and not JSON.stringify(main.state.to_snapshot_data()).contains("melee_lunge") and not envelope_before.contains("melee_lunge"), "Lunge transient must never enter RunSnapshot or deterministic persistence payload bytes")
	# Each blocking opener receives a fresh valid dungeon fixture. This prevents a
	# preceding modal from satisfying a later assertion through leaked UI state.
	for modal_case in [
		{"name": "cradle", "open": func(candidate): candidate._open_cradle_confirmation(), "opened": func(candidate): return candidate.cradle_confirmation_open},
		{"name": "boss", "open": func(candidate): candidate._open_boss_warning(), "opened": func(candidate): return candidate.boss_warning_open},
		{"name": "appearance", "open": func(candidate): candidate._open_appearance_choice(), "opened": func(candidate): return candidate.appearance_choice_panel.visible},
		{"name": "story", "open": func(candidate): candidate._show_story("intro", ""), "opened": func(candidate): return candidate.screen == candidate.Screen.STORY},
		{"name": "victory", "open": func(candidate): candidate._show_victory(false), "opened": func(candidate): return candidate.screen == candidate.Screen.VICTORY},
		{"name": "character", "open": func(candidate): candidate._show_character(), "opened": func(candidate): return candidate.screen == candidate.Screen.CHARACTER},
		{"name": "main_menu", "open": func(candidate): candidate._open_main_menu(), "opened": func(candidate): return candidate.main_menu_open and candidate.save_menu_panel.visible},
		{"name": "settings", "open": func(candidate): candidate._open_settings(), "opened": func(candidate): return candidate.settings_open},
	]:
		var modal = await _new_lunge_modal_fixture(tree, origin)
		if String(modal_case.name) == "appearance":
			modal.state.current_form_id = "almost_human"
			modal.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
			modal.state.skill_levels["choose_appearance"] = 1
		modal._start_melee_lunge("modal-player", origin, target)
		modal._start_melee_lunge("modal-enemy", target, origin)
		modal_case.open.call(modal)
		_expect(bool(modal_case.opened.call(modal)) and modal.melee_lunges.is_empty(), "Blocking opener must open its real modal and synchronously clear player/enemy lunge presentation: %s" % String(modal_case.name))
		modal.queue_free()
		await tree.process_frame
	main.screen = main.Screen.DUNGEON
	main._start_melee_lunge("zoom-player", origin, target)
	main._start_melee_lunge("zoom-enemy", target, origin)
	main.set_dungeon_cell_size(66)
	_expect(main.melee_lunges.is_empty() and main.dungeon_cell_size == 66, "Dungeon zoom transition must clear presentation while retaining its requested logical zoom")
	main._start_melee_lunge("base-player", origin, target)
	main._start_melee_lunge("base-enemy", target, origin)
	main._show_base("", "none")
	_expect(main.melee_lunges.is_empty() and main.screen == main.Screen.BASE, "Leaving dungeon for the real base transition must synchronously clear presentation")
	main._start_melee_lunge("floor-player", origin, target)
	main._start_melee_lunge("floor-enemy", target, origin)
	main._load_floor(1)
	_expect(main.melee_lunges.is_empty() and main.state.current_floor == 1 and main.player_pos == main.floor_data.start, "Real floor load must clear presentation and install its generated logical start")
	main.floor_data = _floor_fixture(8, 8)
	main.player_pos = origin
	main.screen = main.Screen.DUNGEON
	main._start_melee_lunge("move-player", origin, target)
	main._start_melee_lunge("move-enemy", target, origin)
	_expect(main._attempt_player_action(Vector2i.RIGHT) and main.melee_lunges.is_empty() and main.player_pos == target, "Real player movement must clear lunges while retaining its logical step")
	main.floor_data["enemies"] = [{"uid": "doomed", "id": "hollow_guard", "pos": origin + Vector2i.RIGHT, "hp": 1, "dodge": 0, "damage": 1, "accuracy": 1, "souls": 2}]
	main._start_melee_lunge("doomed", origin + Vector2i.RIGHT, origin)
	main._start_melee_lunge("survivor", origin, origin + Vector2i.RIGHT)
	main._damage_enemy_by_uid("doomed", 1)
	_expect(not main.melee_lunges.has("doomed") and main.melee_lunges.has("survivor") and main._enemy_index_by_uid("doomed") < 0, "Lethal real enemy removal must prune only its matching transient UID")
	main._start_melee_lunge("death-player", origin, target)
	main._start_melee_lunge("death-enemy", target, origin)
	main._handle_death()
	_expect(main.melee_lunges.is_empty(), "Real death handling must synchronously clear every actor transient")
	main.queue_free()
	await tree.process_frame


func _test_main_integration(tree: SceneTree) -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	main.auto_step_delay_override = 0.0
	tree.root.add_child(main)
	await tree.process_frame
	main.auto_step_delay_override = -1.0
	var expected_auto_delays := {
		100: 0.229166667,
		150: 0.152777778,
		200: 0.114583333,
		225: 0.101851852,
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
	main.player_map_presentation.activate("male", "skeleton")
	main.player_map_presentation.begin_step(Vector2i.LEFT, 0.2)
	main._start_melee_lunge("resume-player", main.player_pos, main.player_pos + Vector2i.RIGHT)
	main._start_melee_lunge("resume-enemy", main.player_pos + Vector2i.RIGHT, main.player_pos)
	main._reset_resume_transients()
	_expect(
		not main.player_map_presentation.moving
		and main.player_map_presentation.visual().offset_cells == Vector2.ZERO
		and main.melee_lunges.is_empty(),
		"Load/resume transient reset must snap unfinished map presentation without a turn",
	)
	main._start_melee_lunge("new-player", main.player_pos, main.player_pos + Vector2i.RIGHT)
	main._start_melee_lunge("new-enemy", main.player_pos + Vector2i.RIGHT, main.player_pos)
	main._reset_for_new_character()
	_expect(main.melee_lunges.is_empty() and main.floor_data.is_empty() and main.state.character_name.is_empty(), "New-character reset must synchronously clear transient lunges and reset run data")
	main.state.configure_character("Viewport", GameRules.default_attributes())
	main.screen = main.Screen.DUNGEON
	main.floor_data = _floor_fixture(20, 14)
	main.player_pos = Vector2i(10, 7)
	_reveal_floor(main)
	main.player_map_presentation.begin_step(Vector2i.LEFT, 0.2)
	main._start_melee_lunge("form-player", main.player_pos, main.player_pos + Vector2i.RIGHT)
	main._start_melee_lunge("form-enemy", main.player_pos + Vector2i.RIGHT, main.player_pos)
	main.state.current_form_id = "zombie"
	main._player_map_visual()
	_expect(
		not main.player_map_presentation.moving
		and main.player_map_presentation.active_form == "zombie" and main.melee_lunges.is_empty(),
		"A real form change must reset the active map presentation set",
	)
	main.player_map_presentation.begin_step(Vector2i.LEFT, 0.2)
	main._start_melee_lunge("cosmetic-player", main.player_pos, main.player_pos + Vector2i.RIGHT)
	main._start_melee_lunge("cosmetic-enemy", main.player_pos + Vector2i.RIGHT, main.player_pos)
	main.state.display_form_id = "skeleton"
	main._player_map_visual()
	_expect(
		not main.player_map_presentation.moving
		and main.player_map_presentation.active_form == "skeleton" and main.melee_lunges.is_empty(),
		"A cosmetic form change must reset the active map presentation set",
	)
	main.state.display_form_id = ""

	# Exercise the real Main movement/round/presentation path, not only the
	# PlayerMapPresentation value object.  This deterministic empty four-cell loop
	# has exactly one legal logical cell and turn per command, no RNG consumer and
	# no survival mutation beyond total_turns.  The expected serialized state is
	# advanced deliberately instead of incorrectly asserting an untouched object.
	main.state = RunState.new()
	main.state.configure_character("Main presentation loop", GameRules.default_attributes())
	main.floor_data = _floor_fixture(7, 7)
	main.player_pos = Vector2i(3, 3)
	_reveal_floor(main)
	main.rng.seed = 440041
	var integration_rng_before: int = main.rng.state
	var integration_snapshot: Dictionary = main.state.to_snapshot_data()
	var expected_position: Vector2i = main.player_pos
	var integration_ok := true
	var loop_directions := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for step_index in range(1000):
		var direction: Vector2i = loop_directions[step_index % loop_directions.size()]
		expected_position += direction
		var action_ok: bool = main._attempt_player_action(direction)
		var expected_snapshot := integration_snapshot.duplicate(true)
		expected_snapshot["total_turns"] = step_index + 1
		var snapshot_after_action: Dictionary = main.state.to_snapshot_data()
		if (
			not action_ok
			or main.player_pos != expected_position
			or main.state.total_turns != step_index + 1
			or main.rng.state != integration_rng_before
			or snapshot_after_action != expected_snapshot
		):
			integration_ok = false
			break
		main.player_map_presentation.update(0.11)
		if (
			main.player_map_presentation.moving
			or main.player_map_presentation.visual().offset_cells != Vector2.ZERO
			or main.player_pos != expected_position
			or main.state.total_turns != step_index + 1
			or main.rng.state != integration_rng_before
			or main.state.to_snapshot_data() != snapshot_after_action
		):
			integration_ok = false
			break
	_expect(
		integration_ok
		and main.player_pos == Vector2i(3, 3)
		and main.state.total_turns == 1000,
		"One thousand real Main steps must preserve exact cell/turn/RNG/save cadence and finish every transient without drift",
	)
	main.floor_data = _floor_fixture(20, 14)
	main.player_pos = Vector2i(10, 7)
	_reveal_floor(main)
	main._refresh_interface()
	_expect(main.dungeon_viewport.visible and main.dungeon_viewport.clip_contents, "Dungeon screen must use a visible clipping Control")
	_expect(main.dungeon_viewport.camera == Vector2(165, 165), "Integrated camera must use the player-centered transform")
	_expect(main.dungeon_viewport.world_canvas.position == -Vector2(165, 165), "Large-map canvas origin must be padding minus camera")
	main.inspected_target = {"kind": "tile", "pos": Vector2i(12, 7)}
	var material_rect_before_zoom := Rect2(
		main.material_resources_strip.position, main.material_resources_strip.size,
	)
	for cell_size in [44, 66, 88]:
		main.set_dungeon_cell_size(cell_size)
		_expect(
			main.dungeon_cell_size == cell_size
			and main.dungeon_viewport.runtime_cell_size == cell_size
			and main.inspected_target.get("pos") == Vector2i(12, 7)
			and Rect2(main.material_resources_strip.position, main.material_resources_strip.size)
			== material_rect_before_zoom,
			"Zoom %d must update one world transform without clearing inspection or moving the Cold material strip" % cell_size,
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
	main.player_map_presentation.begin_step(Vector2i.LEFT, 0.2)
	main._load_floor(88)
	_expect(
		main.dungeon_viewport.map_size == Vector2i(main.floor_data["width"], main.floor_data["height"])
		and main.dungeon_viewport.camera == DungeonView.camera_for(main.dungeon_viewport.map_size, main.player_pos)
		and not main.player_map_presentation.moving
		and main.player_map_presentation.visual().offset_cells == Vector2.ZERO,
		"Floor transition must snap presentation and refresh camera from rectangular dimensions",
	)

	main.floor_data = _floor_fixture(20, 14)
	main.player_pos = Vector2i(10, 7)
	_reveal_floor(main)
	main._hide_game_interface()
	main._show_dungeon_interface()
	main._refresh_interface()
	_expect(
		main.message_label.visible
		and main.souls_label.visible
		and main.soul_icon.visible
		and main.stats_label.visible
		and main.sidebar_progress_label.visible
		and main.material_resources_strip.visible
		and not main.souls_label.text.strip_edges().is_empty()
		and main.stats_label.text == main.state.character_name
		and main.sidebar_progress_label.text.contains(
			Loc.text("SOUL_LEVEL_LABEL", [main.state.get_effective_soul_level()])
		),
		"Entering Dungeon after a hidden screen must restore every populated Cold HUD datum",
	)
	main._apply_dungeon_layout(true)
	await _test_history_contract(main, tree)
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
	_expect(main.action_history.size() == 1, "Mixed semantic segments must retain one top-level action entry")
	for history_entry in main.action_history:
		for segment in MainScript.action_entry_segments(history_entry):
			_expect(
				main.message_label.accessibility_name.contains(String(segment["text"])),
				"Dungeon history accessibility text must contain every complete semantic segment",
			)

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
	main.set_dungeon_cell_size(88)
	main.get_viewport().gui_release_focus()
	var dungeon_focus_before: Control = main.get_viewport().gui_get_focus_owner()
	var frozen_floor: Dictionary = main.floor_data.duplicate(true)
	var frozen_camera: Vector2 = main.dungeon_viewport.camera
	var frozen_cell_size: int = main.dungeon_cell_size
	main._show_character()
	await tree.process_frame
	await _click_mouse(main, tree, Vector2(100, 100))
	await _tap_touch(main, tree, Vector2(120, 120))
	await _push_action(main, tree, "move_right")
	await _push_action(main, tree, "ui_accept")
	await _push_key(main, tree, KEY_KP_SUBTRACT)
	_expect(
		main.screen == main.Screen.CHARACTER
		and main.dungeon_viewport.visible
		and main.soul_icon.visible
		and main.character_modal_backdrop.visible
		and main.character_modal_backdrop.mouse_filter == Control.MOUSE_FILTER_STOP
		and main.theme.get_instance_id() == ThemeController.theme_for(Palette.COLD_DUNGEON).get_instance_id()
		and main.inventory_panel.theme.get_instance_id() == ThemeController.theme_for(Palette.WARM_ARCHIVE).get_instance_id()
		and main.title_label.position == Vector2(20, 14)
		and main.title_label.size == Vector2(365, 34)
		and main.player_pos == position_before
		and main.state.total_turns == turns_before
		and main.floor_data == frozen_floor
		and main.dungeon_viewport.camera == frozen_camera
		and main.dungeon_cell_size == frozen_cell_size,
		"Warm Character modal must retain the exact frozen Cold dungeon and consume background click/touch/move/accept/zoom input",
	)
	main._select_character_panel("skills")
	_expect(
		main.skill_tree_panel.visible
		and main.skill_tree_panel.theme.get_instance_id() == ThemeController.theme_for(Palette.WARM_ARCHIVE).get_instance_id()
		and main.dungeon_viewport.visible and main.floor_data == frozen_floor,
		"Skills must remain Warm above the same frozen Cold dungeon",
	)
	await _push_action(main, tree, "ui_cancel")
	await tree.process_frame
	_expect(
		main.screen == main.Screen.DUNGEON
		and main.dungeon_viewport.visible
		and main.soul_icon.visible and not main.equipment_label.visible
		and Rect2(main.title_label.position, main.title_label.size) == Rect2(1080, 112, 184, 20)
		and main.player_pos == position_before and main.state.total_turns == turns_before
		and main.floor_data == frozen_floor and main.dungeon_cell_size == frozen_cell_size
		and main.dungeon_viewport.camera == frozen_camera
		and main.get_viewport().gui_get_focus_owner() == dungeon_focus_before,
		"Back must close one Character layer and restore the exact Dungeon camera/cell/focus state (screen=%s viewport=%s icon=%s equipment=%s title=%s)" % [
			main.screen, main.dungeon_viewport.visible, main.soul_icon.visible,
			main.equipment_label.visible, Rect2(main.title_label.position, main.title_label.size),
		],
	)
	main.player_map_presentation.begin_step(Vector2i.LEFT, 0.2)
	main._show_base("")
	_expect(
		not main.dungeon_viewport.visible
		and not main.player_map_presentation.moving
		and main.player_map_presentation.visual().offset_cells == Vector2.ZERO
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
	main.player_map_presentation.begin_step(Vector2i.LEFT, 0.2)
	main._handle_death()
	_expect(
		not main.player_map_presentation.moving
		and main.player_map_presentation.visual().offset_cells == Vector2.ZERO,
		"Death must snap unfinished map presentation before showing its scene",
	)
	main.queue_free()
	await tree.process_frame


func _test_history_contract(main, tree: SceneTree) -> void:
	var previous_locale := Loc.current_locale
	main.action_history.clear()
	main.message = ""
	main._refresh_action_history()
	_expect(
		main.action_history.is_empty()
		and main.message_label.text.is_empty()
		and main.message_label.accessibility_name.is_empty(),
		"Zero history entries must render an empty deterministic history surface",
	)
	Loc.set_locale("ru")
	main._log_action("[one]", "outgoing")
	_expect(
		main.action_history.size() == 1
		and MainScript.action_entry_plain_text(main.action_history[0]) == "[one]"
		and MainScript.action_entry_segments(main.action_history[0]) == [{"text": "[one]", "semantic": "outgoing"}]
		and main.message == "[one]"
		and main.message_label.text.contains("[lb]one[rb]")
		and main.message_label.accessibility_name.contains("↑ ИСХ: [one]"),
		"One outgoing entry must preserve plain text, explicit metadata, escaped BBCode and RU prefix",
	)
	main.action_history.clear()
	for index in range(9):
		var semantic: String = ["neutral", "outgoing", "incoming", "loot"][index % 4]
		main._log_action("entry-%d" % index, semantic)
	_expect(
		main.action_history.size() == 8
		and MainScript.action_entry_plain_text(main.action_history[0]) == "entry-8"
		and MainScript.action_entry_plain_text(main.action_history[7]) == "entry-1"
		and not main.message_label.accessibility_name.contains("entry-0"),
		"Nine actions must evict only the oldest and retain exactly eight newest-first entries",
	)
	var retained_before_locale: Array = main.action_history.duplicate(true)
	Loc.set_locale("en")
	main._refresh_action_history()
	_expect(
		main.action_history == retained_before_locale
		and main.message_label.accessibility_name.contains("entry-8")
		and (
			main.message_label.accessibility_name.contains("↑ OUT:")
			or main.message_label.accessibility_name.contains("↓ IN:")
			or main.message_label.accessibility_name.contains("▣ LOOT:")
		),
		"Semantic metadata and ordering must remain unchanged when locale changes its textual prefixes",
	)
	var localized_bodies := {
		"ru": [
			"Коридор тих.", "Найден костяной нож.", "Болт: 3 урона.",
			"Магия попала.", "Дверь открыта.", "Клеймор +3 найден.",
			"Лучник промахнулся.", "Круг: цель А.",
		],
		"en": [
			"Corridor quiet.", "Bone Knife recovered.", "Bolt: 3 damage.",
			"Magic hit.", "Door opened.", "Claymore +3 found.",
			"Archer missed.", "Circle: target A.",
		],
	}
	var semantic_order := [
		"neutral", "loot", "incoming", "outgoing",
		"neutral", "loot", "incoming", "outgoing",
	]
	for locale in ["ru", "en"]:
		Loc.set_locale(locale)
		main.action_history.clear()
		var bodies: Array = localized_bodies[locale]
		for index in range(bodies.size()):
			main._log_action(String(bodies[index]), String(semantic_order[index]))
		main._append_to_latest_action(
			" Цель Б." if locale == "ru" else " Target B.", "outgoing",
		)
		main._append_to_latest_action(
			" Ответ: 1 урон." if locale == "ru" else " Retaliation: 1.", "incoming",
		)
		await tree.process_frame
		var all_bodies_visible: bool = main.action_history.size() == 8
		for body in bodies:
			all_bodies_visible = (
				all_bodies_visible
				and main.message_label.accessibility_name.contains(String(body))
			)
		_expect(
			all_bodies_visible
			and main.message_label.get_content_height() <= main.message_label.size.y
			and main.message_label.get_theme_font_size("normal_font_size") >= 12,
			"All eight complete localized %s records must fit the visible >=12px history region" % locale,
		)
	main.action_history.clear()
	main._log_action("strike A", "outgoing")
	main._append_to_latest_action("; strike B", "outgoing")
	main._append_to_latest_action("; retaliation", "incoming")
	main._append_to_latest_action("; recovered stone", "loot")
	var mixed_segments: Array = MainScript.action_entry_segments(main.action_history[0])
	_expect(
		main.action_history.size() == 1
		and mixed_segments.map(func(segment: Dictionary): return segment["semantic"])
		== ["outgoing", "outgoing", "incoming", "loot"]
		and MainScript.action_entry_plain_text(main.action_history[0])
		== "strike A; strike B; retaliation; recovered stone"
		and main.message == "strike A; strike B; retaliation; recovered stone"
		and main.message_label.accessibility_name.contains("↑ OUT: strike A")
		and main.message_label.accessibility_name.contains("↓ IN: ; retaliation")
		and main.message_label.accessibility_name.contains("▣ LOOT: ; recovered stone"),
		"Multi-target and mixed combat segments must append in order inside one complete top-level action",
	)
	_expect(
		MainScript._action_color_role("outgoing") == "primary"
		and MainScript._action_color_role("incoming") == "danger"
		and MainScript._action_color_role("loot") == "focus"
		and MainScript._action_color_role("neutral") == "secondary",
		"History semantics must map directly to exact Cold roles rather than localized-text inference",
	)
	Loc.set_locale(previous_locale)
	main._refresh_action_history()


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


func _push_action(main, tree: SceneTree, action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		main.get_viewport().push_input(event, true)
		await tree.process_frame


func _push_mouse(main, tree: SceneTree, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	main.get_viewport().push_input(event, true)
	await tree.process_frame


func _click_mouse(main, tree: SceneTree, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	main.get_viewport().push_input(motion, true)
	await tree.process_frame
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
		main.menu_button: Rect2(1174, 16, 90, 34), main.material_resources_strip: Rect2(1080, 52, 184, 34),
		main.stats_label: Rect2(1080, 88, 184, 24), main.title_label: Rect2(1080, 112, 184, 20),
		main.sidebar_progress_label: Rect2(1080, 230, 184, 26), main.status_strip: Rect2(1080, 166, 184, 30),
		main.inspection_label: Rect2(1088, 268, 168, 124), main.hint_label: Rect2(1088, 424, 168, 22),
		main.message_label: Rect2(1088, 448, 168, 246),
	}
	for control in expected_controls:
		var rect: Rect2 = Rect2(control.position, control.size)
		_expect(rect == expected_controls[control], "Dungeon rail control must use its exact marked geometry")
		_expect(rail_rect.encloses(rect) and not rect.intersects(map_rect), "Dungeon rail control must stay inside the rail and outside the map")
	for frame in [Renderer.DUNGEON_HP_RECT, Renderer.DUNGEON_STATUS_RECT, Renderer.DUNGEON_MANA_RECT, Renderer.DUNGEON_INSPECTION_RECT, Renderer.DUNGEON_HISTORY_RECT]:
		_expect(rail_rect.encloses(frame) and not frame.intersects(map_rect), "Dungeon status frame must stay inside the rail and outside the map")
	_expect(
		Renderer.DUNGEON_HP_RECT == Rect2(1080, 136, 184, 26)
		and Renderer.DUNGEON_STATUS_RECT == Rect2(1080, 166, 184, 30)
		and Renderer.DUNGEON_MANA_RECT == Rect2(1080, 200, 184, 26)
		and Renderer.DUNGEON_INSPECTION_RECT == Rect2(1080, 260, 184, 152)
		and Renderer.DUNGEON_ENEMY_HP_RECT == Rect2(1090, 400, 164, 8)
		and Renderer.DUNGEON_HISTORY_RECT == Rect2(1080, 420, 184, 282),
		"Dungeon frames must preserve world/sidebar bounds while making room for materials and eight history entries",
	)
	main.state.resources = {"wood": 0, "stone": 9999, "cloth": 123}
	main.material_resources_strip.refresh(main.state.resources)
	var material_contract_ok: bool = (
		main.material_resources_strip.visible
		and main.material_resources_strip.ui_context == Palette.COLD_DUNGEON
		and main.material_resources_strip.compact
		and not main.material_resources_strip.interactive
		and main.material_resources_strip.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and main.material_resources_strip.theme.get_instance_id()
		== ThemeController.theme_for(Palette.COLD_DUNGEON).get_instance_id()
	)
	for resource_id in ["wood", "stone", "cloth"]:
		var counter = main.material_resources_strip.get_counter(resource_id)
		material_contract_ok = (
			material_contract_ok
			and counter.focus_mode == Control.FOCUS_NONE
			and counter.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and counter.value_label.text == str(main.state.resources[resource_id])
			and counter.value_label.get_theme_font_size("font_size") >= 12
			and counter.value_label.get_theme_font("font").get_instance_id()
			== ThemeController.functional_font("regular", true).get_instance_id()
			and Rect2(Vector2.ZERO, counter.size).encloses(counter.icon_rect())
		)
	_expect(material_contract_ok, "Cold compact material strip must read exact zero/large values with ignored input, 12px tabular text and code-drawn icons")
	_expect(not main.equipment_label.visible and main.soul_icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Dungeon equipment must stay hidden and decorative HUD controls must never intercept input")
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


func _new_lunge_modal_fixture(tree: SceneTree, origin: Vector2i):
	var fixture = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	fixture.persistence_enabled = false
	fixture.audio_playback_enabled = false
	tree.root.add_child(fixture)
	await tree.process_frame
	fixture.state.configure_character("Lunge modal", GameRules.default_attributes())
	fixture.screen = fixture.Screen.DUNGEON
	fixture.floor_data = _floor_fixture(8, 8)
	fixture.player_pos = origin
	_reveal_floor(fixture)
	fixture._apply_dungeon_layout(true)
	fixture._refresh_interface()
	return fixture


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
