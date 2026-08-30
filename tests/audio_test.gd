class_name AudioTestSuite
extends RefCounted

const Audio := preload("res://scripts/audio/audio_manager.gd")
const SaveSystem := preload("res://scripts/system/persistence.gd")
const InputProfile := preload("res://scripts/system/input_bindings.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const Presentation := preload("res://scripts/system/presentation_settings.gd")

const SETTINGS_PATH := "res://.tmp/audio-settings.cfg"
const AUDIO_FILES := [
	"base_ambience.wav", "dungeon_ambience.wav", "ui_confirm.wav", "ui_cancel.wav",
	"step.wav", "dash.wav", "melee_attack.wav", "player_hurt.wav", "ranged_shot.wav",
	"magic_cast.wav", "chest_open.wav", "world_transition.wav", "station_success.wav",
	"station_fail.wav", "evolution.wav", "death.wav",
]

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_settings_persistence()
	await _test_manager(tree)
	_test_audio_assets()
	await _test_main_semantics(tree)
	await _test_settings_input(tree)
	await _test_manager_recreation(tree)
	Loc.set_locale("ru")
	return failures


func _test_settings_persistence() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	SaveSystem.delete_settings(SETTINGS_PATH)
	var existing := ConfigFile.new()
	existing.set_value("custom", "retained", "platform-value")
	existing.save(SETTINGS_PATH)
	var bindings := {"attack": [{"type": "key", "keycode": int(KEY_Z)}]}
	_expect(SaveSystem.save_settings({
		"fullscreen": true,
		"inspection_radius": 9,
		"dungeon_cell_size": 44,
		"auto_movement_speed_percent": 225,
		"locale": "en",
		"bindings": bindings,
		"audio": {"muted": true, "background_volume": 35, "actions_volume": 80},
	}, SETTINGS_PATH) == OK, "Audio settings must save beside existing settings")
	var loaded := SaveSystem.load_settings(SETTINGS_PATH)
	var retained := ConfigFile.new()
	retained.load(SETTINGS_PATH)
	_expect(
		loaded.get("audio", {}) == {
			"muted": true, "background_volume": 35, "actions_volume": 80,
		}
		and loaded.get("bindings", {}) == bindings
		and int(loaded.get("dungeon_cell_size", 0)) == 44
		and int(loaded.get("auto_movement_speed_percent", 0)) == 225
		and retained.get_value("custom", "retained", "") == "platform-value",
		"Audio round-trip must preserve bindings and unrelated settings fields",
	)
	_expect(SaveSystem.save_settings({
		"audio": {"muted": false, "background_volume": 55, "actions_volume": 70},
	}, SETTINGS_PATH) == OK, "Audio-only settings updates must save safely")
	loaded = SaveSystem.load_settings(SETTINGS_PATH)
	_expect(
		loaded.get("fullscreen", false)
		and int(loaded.get("inspection_radius", 0)) == 9
		and String(loaded.get("locale", "")) == "en"
		and int(loaded.get("dungeon_cell_size", 0)) == 44
		and int(loaded.get("auto_movement_speed_percent", 0)) == 225
		and loaded.get("bindings", {}) == bindings
		and loaded.get("audio", {}) == {
			"muted": false, "background_volume": 55, "actions_volume": 70,
		},
		"A genuine partial audio update must preserve all existing gameplay, locale, and input keys",
	)
	SaveSystem.delete_settings(SETTINGS_PATH)
	_expect(SaveSystem.save_settings({
		"audio": {"background_volume": 25},
	}, SETTINGS_PATH) == OK, "Partial audio settings must also save to a new path")
	loaded = SaveSystem.load_settings(SETTINGS_PATH)
	_expect(
		not loaded["fullscreen"]
		and int(loaded["inspection_radius"]) == 6
		and int(loaded["dungeon_cell_size"]) == 66
		and int(loaded["auto_movement_speed_percent"]) == 100
		and String(loaded["locale"]) == "ru"
		and loaded["bindings"] == {}
		and loaded["audio"] == {
			"muted": false, "background_volume": 25, "actions_volume": 75,
		},
		"A new partial settings file must load defaults for every absent old and audio key",
	)

	var legacy := ConfigFile.new()
	legacy.set_value("display", "fullscreen", false)
	legacy.set_value("input", "bindings", bindings)
	legacy.save(SETTINGS_PATH)
	loaded = SaveSystem.load_settings(SETTINGS_PATH)
	_expect(
		loaded.get("audio", {}) == SaveSystem.DEFAULT_AUDIO_SETTINGS
		and int(loaded.get("dungeon_cell_size", 0)) == 66
		and int(loaded.get("auto_movement_speed_percent", 0)) == 100,
		"Legacy settings without an audio section must use documented defaults",
	)
	for cell_size in [44, 66, 88]:
		_expect(
			SaveSystem.save_settings({"dungeon_cell_size": cell_size}, SETTINGS_PATH) == OK
			and int(SaveSystem.load_settings(SETTINGS_PATH).get("dungeon_cell_size", 0)) == cell_size,
			"Dungeon cell-size setting must round-trip %d" % cell_size,
		)
	for speed_percent in Presentation.AUTO_MOVEMENT_SPEED_PERCENTS:
		_expect(
			SaveSystem.save_settings({
				"auto_movement_speed_percent": speed_percent,
			}, SETTINGS_PATH) == OK
			and int(SaveSystem.load_settings(SETTINGS_PATH).get(
				"auto_movement_speed_percent", 0,
			)) == speed_percent,
			"Automatic movement speed setting must round-trip %d" % speed_percent,
		)
	var partial_before := ConfigFile.new()
	partial_before.load(SETTINGS_PATH)
	partial_before.set_value("custom", "future_key", 713)
	partial_before.save(SETTINGS_PATH)
	_expect(
		SaveSystem.save_settings({"inspection_radius": 7}, SETTINGS_PATH) == OK,
		"A partial gameplay settings update must remain writable",
	)
	var partial_after := ConfigFile.new()
	partial_after.load(SETTINGS_PATH)
	_expect(
		int(SaveSystem.load_settings(SETTINGS_PATH).get(
			"auto_movement_speed_percent", 0,
		)) == 225
		and int(partial_after.get_value("custom", "future_key", 0)) == 713,
		"Partial settings writes must preserve automatic speed and unknown sections",
	)
	var malformed_zoom := ConfigFile.new()
	malformed_zoom.set_value("gameplay", "dungeon_cell_size", 99)
	malformed_zoom.save(SETTINGS_PATH)
	_expect(
		int(SaveSystem.load_settings(SETTINGS_PATH).get("dungeon_cell_size", 0)) == 66,
		"Malformed dungeon cell size must fall back to 66",
	)
	for malformed_speed in [175, 150.5, "225", null]:
		var malformed_auto_speed := ConfigFile.new()
		malformed_auto_speed.set_value(
			"gameplay", "auto_movement_speed_percent", malformed_speed,
		)
		malformed_auto_speed.save(SETTINGS_PATH)
		_expect(
			int(SaveSystem.load_settings(SETTINGS_PATH).get(
				"auto_movement_speed_percent", 0,
			)) == 100,
			"Malformed/unsupported automatic movement speed must fall back to 100",
		)
	var malformed := ConfigFile.new()
	malformed.set_value("audio", "muted", "yes")
	malformed.set_value("audio", "background_volume", "loud")
	malformed.set_value("audio", "actions_volume", 140.4)
	malformed.save(SETTINGS_PATH)
	loaded = SaveSystem.load_settings(SETTINGS_PATH)
	_expect(
		loaded["audio"] == {
			"muted": false, "background_volume": 50, "actions_volume": 100,
		},
		"Malformed audio values must default while numeric values clamp to 0..100",
	)
	malformed.set_value("audio", "background_volume", -20)
	malformed.save(SETTINGS_PATH)
	loaded = SaveSystem.load_settings(SETTINGS_PATH)
	_expect(int(loaded["audio"]["background_volume"]) == 0, "Negative audio volume must clamp to zero")
	SaveSystem.delete_settings(SETTINGS_PATH)


func _test_manager(tree: SceneTree) -> void:
	var master_index := AudioServer.get_bus_index(Audio.MASTER_BUS)
	var master_volume := AudioServer.get_bus_volume_db(master_index)
	var master_muted := AudioServer.is_bus_mute(master_index)
	Audio.ensure_audio_buses()
	var count_after_first := AudioServer.bus_count
	Audio.ensure_audio_buses()
	_expect(AudioServer.bus_count == count_after_first, "Audio bus creation must be idempotent")
	var game_index := AudioServer.get_bus_index(Audio.GAME_AUDIO_BUS)
	var background_index := AudioServer.get_bus_index(Audio.BACKGROUND_BUS)
	var actions_index := AudioServer.get_bus_index(Audio.ACTIONS_BUS)
	_expect(
		game_index >= 0 and background_index >= 0 and actions_index >= 0
		and AudioServer.get_bus_send(game_index) == Audio.MASTER_BUS
		and AudioServer.get_bus_send(background_index) == Audio.GAME_AUDIO_BUS
		and AudioServer.get_bus_send(actions_index) == Audio.GAME_AUDIO_BUS,
		"Audio buses must use the centralized Master -> GameAudio -> child routing",
	)
	_expect(
		is_equal_approx(AudioServer.get_bus_volume_db(master_index), master_volume)
		and AudioServer.is_bus_mute(master_index) == master_muted,
		"Creating game audio buses must never modify Master",
	)
	_expect(
		is_equal_approx(Audio.percent_to_db(0), -80.0)
		and is_equal_approx(Audio.percent_to_db(50), linear_to_db(0.5))
		and is_equal_approx(Audio.percent_to_db(100), 0.0),
		"0/50/100 percent must map to finite -80dB, linear_to_db(0.5), and 0dB",
	)

	var manager := Audio.new()
	manager.playback_enabled = false
	tree.root.add_child(manager)
	await tree.process_frame
	manager.apply_settings(true, 30, 65)
	_expect(
		manager.muted and manager.background_volume == 30 and manager.actions_volume == 65
		and AudioServer.is_bus_mute(game_index)
		and not AudioServer.is_bus_mute(background_index)
		and not AudioServer.is_bus_mute(actions_index),
		"Global Off must mute only GameAudio and preserve editable child levels",
	)
	manager.apply_settings(false, 0, 100)
	_expect(
		not AudioServer.is_bus_mute(game_index)
		and AudioServer.is_bus_mute(background_index)
		and is_equal_approx(AudioServer.get_bus_volume_db(background_index), -80.0)
		and not AudioServer.is_bus_mute(actions_index),
		"Zero child volume must combine finite -80dB with child bus mute",
	)
	_expect(
		Audio.is_headless_runtime()
		and manager.runtime_headless
		and manager.background_players.is_empty()
		and manager.action_players.is_empty(),
		"CLI headless mode must be detected before any playback nodes are created",
	)

	manager.set_background("base")
	manager.set_background("base")
	manager.set_background("dungeon")
	manager.set_background("dungeon")
	var half_crossfade := Audio.crossfade_levels(0.5)
	_expect(
		is_equal_approx(half_crossfade.x, -40.0)
		and is_equal_approx(half_crossfade.y, -40.0),
		"Background context changes must use the documented half-second crossfade",
	)
	manager.stop_background()
	manager.stop_background()
	_expect(
		manager.background_history == ["base", "dungeon", "stop"],
		"Identical background contexts must never restart or duplicate semantic dispatch",
	)
	var before_unknown := manager.action_history.size()
	_expect(not manager.play_action("unknown") and manager.action_history.size() == before_unknown, "Unknown audio ids must be safe no-ops")
	manager.playback_enabled = true
	_expect(manager.play_action("ui_confirm"), "A registered action with a missing stream must remain a safe semantic dispatch")
	manager.playback_enabled = false
	var clock := [10.0]
	manager.now_provider = func() -> float: return float(clock[0])
	manager.action_history.clear()
	_expect(manager.play_action("step"), "The first valid step sound must dispatch")
	clock[0] = 10.119
	_expect(not manager.play_action("step"), "Step sounds must observe at least a 0.12 second cooldown")
	clock[0] = 10.12
	_expect(manager.play_action("step") and manager.action_history.count("step") == 2, "Step cooldown must accept the 0.12 second boundary")
	_expect(
		manager.background_streams.is_empty()
		and manager.action_streams.is_empty()
		and manager.background_players.is_empty()
		and manager.action_players.is_empty(),
		"Headless semantics must never load streams or create AudioStreamPlayer playback objects",
	)
	manager.queue_free()
	await tree.process_frame


func _test_audio_assets() -> void:
	for file_name in AUDIO_FILES:
		var path := "res://assets/audio/%s" % file_name
		_expect(FileAccess.file_exists(path), "Generated audio asset %s must exist" % file_name)
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var bytes := file.get_buffer(file.get_length())
		file.close()
		var fmt := _find_riff_chunk(bytes, "fmt ")
		var data := _find_riff_chunk(bytes, "data")
		_expect(
			bytes.slice(0, 4).get_string_from_ascii() == "RIFF"
			and bytes.slice(8, 12).get_string_from_ascii() == "WAVE"
			and not fmt.is_empty() and not data.is_empty()
			and bytes.decode_u16(int(fmt["offset"])) == 1
			and bytes.decode_u16(int(fmt["offset"]) + 2) == 1
			and bytes.decode_u32(int(fmt["offset"]) + 4) == 22050
			and bytes.decode_u16(int(fmt["offset"]) + 14) == 16,
			"%s must be mono PCM WAV, 22050Hz, 16-bit" % file_name,
		)
		var peak := 0
		var data_start := int(data.get("offset", 0))
		var data_end := data_start + int(data.get("size", 0))
		for offset in range(data_start, data_end, 2):
			var sample := int(bytes.decode_u16(offset))
			if sample >= 32768:
				sample -= 65536
			peak = maxi(peak, absi(sample))
		_expect(peak <= 15729, "%s peak must remain at or below approximately -6dB" % file_name)
		if file_name.ends_with("ambience.wav"):
			_expect(not _find_riff_chunk(bytes, "smpl").is_empty(), "%s must contain loop metadata" % file_name)


func _test_main_semantics(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.audio_manager.action_history.clear()
	main.audio_manager.background_history.clear()
	main._apply_locale()
	main._refresh_interface()
	var restored_state := RunState.new()
	restored_state.restore_save_data(main.state.to_save_data())
	_expect(main.audio_manager.action_history.is_empty(), "Restore, locale, and UI refresh must not emit gameplay sounds")

	main._begin_expedition_at(99)
	main._load_floor(98)
	main.floor_data["enemies"].clear()
	main.player_pos = main.floor_data["base_gate"]
	main._on_interact_pressed()
	_expect(
		main.audio_manager.action_history.count("world_transition") == 3
		and main.audio_manager.background_history == ["dungeon", "base"],
		"Expedition, floor change, and safe return must each emit one transition while contexts change once",
	)

	main.screen = main.Screen.DUNGEON
	main.state = RunState.new()
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(3, 3)
	_reveal_floor(main)
	main.audio_manager.action_history.clear()
	main.floor_data["tiles"][Vector2i(2, 3)] = "wall"
	main._attempt_player_action(Vector2i.LEFT)
	_expect(main.audio_manager.action_history.is_empty(), "Walking into a wall must be silent")
	main._attempt_player_action(Vector2i.RIGHT)
	_expect(main.audio_manager.action_history.count("step") == 1, "Successful displacement must emit one step")
	main.audio_manager.action_history.clear()
	main.wait_turn_count = 100
	main._on_wait_pressed()
	_expect(main.audio_manager.action_history.is_empty(), "Long waits without outcomes must not spam action sounds")

	main.player_pos = Vector2i(3, 3)
	main.floor_data["enemies"] = [_enemy("melee", Vector2i(4, 3), 50, "hollow_guard")]
	main.floor_data["enemies"][0]["vision"] = 0
	main._execute_attack_ability("basic_attack", "melee", {"attack_rolls": [20], "passive_roll": 1.0})
	main._execute_attack_ability("double_attack", "melee", {"attack_rolls": [20, 20]})
	main.floor_data["enemies"].append(_enemy("circle", Vector2i(3, 2), 50, "hollow_guard"))
	main._execute_attack_ability("circular_attack", "", {"attack_rolls": [20, 20]})
	_expect(main.audio_manager.action_history.count("melee_attack") == 3, "Basic, Double, and Circular attacks must emit one swing per accepted activation")
	main.floor_data["enemies"].clear()
	var melee_before: int = main.audio_manager.action_history.count("melee_attack")
	main._execute_attack_ability("basic_attack")
	_expect(main.audio_manager.action_history.count("melee_attack") == melee_before, "Rejected melee attacks must be silent")

	main.state.loadout["right_hand"] = "bone_bow@0"
	main.floor_data["enemies"] = [_enemy("ranged", Vector2i(5, 3), 50, "hollow_guard")]
	main.floor_data["enemies"][0]["vision"] = 0
	main._execute_ranged_attack("ranged", {"attack_rolls": [1]})
	main.floor_data["enemies"].clear()
	var shots_before_invalid: int = main.audio_manager.action_history.count("ranged_shot")
	main._execute_ranged_attack("", {"attack_rolls": [20]})
	_expect(
		shots_before_invalid == 1 and main.audio_manager.action_history.count("ranged_shot") == 1,
		"Accepted player shots hit or miss once; invalid shots remain silent",
	)

	main.state.loadout["right_hand"] = ""
	main.state.skill_levels["magic_awakening"] = 1
	main.state.skill_levels["magic_missile"] = 1
	main.state.mana = main.state.get_max_mana()
	main.floor_data["enemies"] = [_enemy("magic", Vector2i(5, 3), 50, "hollow_guard")]
	main.floor_data["enemies"][0]["vision"] = 0
	main._cast_magic_missile(0.0)
	_expect(main.audio_manager.action_history.count("magic_cast") == 1, "Magic Missile and its ricochet path must emit only one cast")

	main.floor_data["enemies"].clear()
	main.ability_targeting_id = "dash"
	main.ability_target_cursor = Vector2i(5, 3)
	main._confirm_dash()
	_expect(main.audio_manager.action_history.count("dash") == 1, "A committed player Dash must emit once")
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(3, 4)
	_reveal_floor(main)
	main.floor_data["enemies"] = [_enemy("boss", Vector2i(3, 1), 36, "minotaur")]
	main._try_enemy_dash(0)
	_expect(main.audio_manager.action_history.count("dash") == 2, "A committed enemy Dash must use the same one-shot event")

	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(3, 3)
	_reveal_floor(main)
	main.floor_data["items"] = [{
		"uid": "chest", "id": "bone_knife", "pos": main.player_pos, "wood": 0, "stone": 0,
	}]
	main._pick_up_item_at_player()
	_expect(main.audio_manager.action_history.count("chest_open") == 1, "A collected chest must emit once")

	main.state = RunState.new()
	main.floor_data["cradle_used"] = false
	main.state.carried_souls = 100
	main._use_cradle()
	var evolution_count: int = main.audio_manager.action_history.count("evolution")
	main._use_cradle()
	_expect(evolution_count == 1 and main.audio_manager.action_history.count("evolution") == 1, "Only successful evolution must emit its sting")

	main._show_base("")
	main.audio_manager.action_history.clear()
	main.state.add_resources({"wood": 100, "stone": 100, "cloth": 100})
	main._on_build_camp_upgrade("crusher")
	main._on_build_camp_upgrade("whetstone")
	_expect(main.audio_manager.action_history.count("station_success") == 2, "Successful camp builds must emit station success once each")
	main.state.add_item("bone_knife")
	main.inventory_panel.bind_state(main.state, true)
	main.inventory_panel.select_item("bone_knife@0", "inventory")
	main._on_inventory_dismantle_pressed()
	_expect(main.audio_manager.action_history.count("station_success") == 3, "Successful dismantling must emit station success once")

	main.state.add_item("bone_knife")
	main.inventory_panel.select_item("bone_knife@0", "inventory")
	main.rng.seed = 1
	main._on_inventory_upgrade_pressed()
	_expect(main.audio_manager.action_history.count("station_success") == 4, "A successful weapon upgrade must emit station success")
	main.inventory_panel.select_item("bone_knife@1", "inventory")
	var failed_seed := _find_upgrade_failure_seed()
	main.rng.seed = failed_seed
	main._on_inventory_upgrade_pressed()
	_expect(main.audio_manager.action_history.count("station_fail") == 1, "An accepted failed weapon upgrade must emit station fail once")
	var station_actions_before_reject: int = main.audio_manager.action_history.size()
	main.state.resources = {"wood": 0, "stone": 0, "cloth": 0}
	main._on_inventory_upgrade_pressed()
	_expect(main.audio_manager.action_history.size() == station_actions_before_reject, "Rejected no-resource station attempts must be silent")

	main.screen = main.Screen.DUNGEON
	main.state = RunState.new()
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(3, 3)
	_reveal_floor(main)
	main.audio_manager.action_history.clear()
	var archer := _enemy("archer", Vector2i(3, 1), 10, "skeletal_archer")
	archer["accuracy"] = -100
	main.floor_data["enemies"] = [archer]
	main.floor_data["visible_cells"].erase(archer["pos"])
	main.projectile_traces.clear()
	main._try_enemy_ranged_attack(0, 1)
	_expect(
		main.audio_manager.action_history == ["ranged_shot"]
		and main.projectile_traces.is_empty(),
		"A hidden archer hit-or-miss shot must sound once without revealing a trace",
	)
	main.audio_manager.action_history.clear()
	var attacker := _enemy("attacker", Vector2i(4, 3), 10, "hollow_guard")
	attacker["accuracy"] = 100
	attacker["damage"] = 1
	main.floor_data["enemies"] = [attacker]
	main.state.hp = main.state.get_max_hp()
	main._enemy_turn()
	_expect(main.audio_manager.action_history == ["player_hurt"], "Nonlethal incoming melee damage must emit only player_hurt")
	main.screen = main.Screen.DUNGEON
	main.floor_data["enemies"] = [attacker]
	main.state.hp = 1
	main.audio_manager.action_history.clear()
	main._enemy_turn()
	_expect(main.audio_manager.action_history == ["death"], "Lethal incoming damage must emit death without player_hurt")
	main.queue_free()
	await tree.process_frame


func _test_settings_input(tree: SceneTree) -> void:
	var main = await _new_main(tree)
	main.screen = main.Screen.DUNGEON
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(3, 3)
	_reveal_floor(main)
	main._open_settings()
	await tree.process_frame
	_expect(
		main.get_viewport().gui_get_focus_owner() == main.settings_minus_button,
		"Opening Settings must begin at the radius controls",
	)
	_expect(
		main.settings_auto_movement_speed_button.size == Vector2(400, 42)
		and main.settings_auto_movement_speed_button.position == Vector2(440, 208)
		and main.settings_sound_button.position.y == 256
		and main.settings_sound_button.size.y >= 42
		and main.settings_background_slider.size.y >= 42
		and main.settings_actions_slider.size.y >= 42
		and Rect2(330, 40, 620, 670).encloses(Rect2(
			main.settings_auto_movement_speed_button.position,
			main.settings_auto_movement_speed_button.size,
		)),
		"Automatic speed and audio settings need ordered 42px touch targets inside the card",
	)
	var settings_card := Rect2(330, 40, 620, 670)
	var downstream_controls: Array[Control] = [
		main.settings_auto_movement_speed_button,
		main.settings_sound_button,
		main.settings_background_slider,
		main.settings_actions_slider,
		main.settings_display_button,
		main.language_button,
		main.settings_input_label,
		main.settings_controls_button,
		main.settings_new_game_button,
		main.settings_close_button,
	]
	for control in downstream_controls:
		_expect(
			settings_card.encloses(Rect2(control.position, control.size)),
			"Every downstream Settings row must remain inside the existing card",
		)
	for index in range(downstream_controls.size() - 1):
		_expect(
			not Rect2(
				downstream_controls[index].position, downstream_controls[index].size,
			).intersects(Rect2(
				downstream_controls[index + 1].position,
				downstream_controls[index + 1].size,
			)),
			"Consecutive Settings rows must not overlap after inserting automatic speed",
		)
	_expect(
		main.settings_minus_button.focus_neighbor_bottom == main.settings_zoom_button.get_path()
		and main.settings_zoom_button.focus_neighbor_bottom
		== main.settings_auto_movement_speed_button.get_path()
		and main.settings_auto_movement_speed_button.focus_neighbor_bottom
		== main.settings_sound_button.get_path()
		and main.settings_sound_button.focus_neighbor_bottom == main.settings_background_slider.get_path()
		and main.settings_background_slider.focus_neighbor_bottom == main.settings_actions_slider.get_path()
		and main.settings_actions_slider.focus_neighbor_bottom == main.settings_display_button.get_path()
		and main.settings_display_button.focus_neighbor_bottom == main.language_button.get_path()
		and main.language_button.focus_neighbor_bottom == main.settings_controls_button.get_path()
		and main.settings_controls_button.focus_neighbor_bottom == main.settings_new_game_button.get_path()
		and main.settings_new_game_button.focus_neighbor_bottom == main.settings_close_button.get_path(),
		"Settings focus order must include automatic speed, both audio sliders and unified return",
	)
	_expect(
		main.settings_auto_movement_speed_button.text == Loc.text("SETTINGS_AUTO_SPEED", [
			Loc.text("SETTINGS_AUTO_SPEED_BASE"),
		])
		and not main.settings_auto_movement_speed_button.tooltip_text.is_empty()
		and main.settings_auto_movement_speed_button.accessibility_name.contains(
			main.settings_auto_movement_speed_button.tooltip_text
		),
		"Automatic movement speed must expose its Base value, tooltip and accessibility text",
	)
	main.settings_auto_movement_speed_button.grab_focus()
	var speed_accept := InputEventAction.new()
	speed_accept.action = "ui_accept"
	speed_accept.pressed = true
	main.get_viewport().push_input(speed_accept, true)
	await tree.process_frame
	_expect(main.auto_movement_speed_percent == 150, "Keyboard Enter must cycle automatic speed to +50")
	speed_accept = speed_accept.duplicate()
	speed_accept.pressed = false
	main.get_viewport().push_input(speed_accept, true)
	await tree.process_frame
	var speed_gamepad_accept := InputEventJoypadButton.new()
	speed_gamepad_accept.button_index = JOY_BUTTON_A
	speed_gamepad_accept.pressed = true
	main.get_viewport().push_input(speed_gamepad_accept, true)
	await tree.process_frame
	_expect(main.auto_movement_speed_percent == 200, "Gamepad A must cycle automatic speed to +100")
	speed_gamepad_accept = speed_gamepad_accept.duplicate()
	speed_gamepad_accept.pressed = false
	main.get_viewport().push_input(speed_gamepad_accept, true)
	await tree.process_frame
	var speed_center: Vector2 = main.settings_auto_movement_speed_button.get_global_rect().get_center()
	var speed_click := InputEventMouseButton.new()
	speed_click.button_index = MOUSE_BUTTON_LEFT
	speed_click.pressed = true
	speed_click.position = speed_center
	main.get_viewport().push_input(speed_click, true)
	speed_click = speed_click.duplicate()
	speed_click.pressed = false
	main.get_viewport().push_input(speed_click, true)
	await tree.process_frame
	_expect(main.auto_movement_speed_percent == 225, "Mouse must cycle automatic speed to +125")
	var speed_touch := InputEventScreenTouch.new()
	speed_touch.index = 7
	speed_touch.pressed = true
	speed_touch.position = speed_center
	main.get_viewport().push_input(speed_touch, true)
	speed_touch = speed_touch.duplicate()
	speed_touch.pressed = false
	main.get_viewport().push_input(speed_touch, true)
	await tree.process_frame
	_expect(main.auto_movement_speed_percent == 100, "Touch must wrap automatic speed to Base")
	main.settings_sound_button.grab_focus()
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	main.get_viewport().push_input(accept, true)
	await tree.process_frame
	_expect(
		main.audio_muted and main.settings_sound_button.text == Loc.text("SETTINGS_SOUND_OFF"),
		"Keyboard Enter/A action must toggle Sound (muted=%s, label=%s)" % [
			main.audio_muted, main.settings_sound_button.text,
		],
	)
	accept = accept.duplicate()
	accept.pressed = false
	main.get_viewport().push_input(accept, true)
	await tree.process_frame
	var gamepad_accept := InputEventJoypadButton.new()
	gamepad_accept.button_index = JOY_BUTTON_A
	gamepad_accept.pressed = true
	main.get_viewport().push_input(gamepad_accept, true)
	await tree.process_frame
	_expect(not main.audio_muted, "Gamepad A must toggle Sound without a mouse")
	gamepad_accept = gamepad_accept.duplicate()
	gamepad_accept.pressed = false
	main.get_viewport().push_input(gamepad_accept, true)
	await tree.process_frame

	main.background_volume = 50
	main._refresh_settings_interface()
	main.settings_background_slider.grab_focus()
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	main.get_viewport().push_input(right, true)
	await tree.process_frame
	_expect(main.background_volume == 55, "Keyboard/D-pad slider navigation must change background volume by exactly 5")
	right = right.duplicate()
	right.pressed = false
	main.get_viewport().push_input(right, true)
	await tree.process_frame
	main.actions_volume = 95
	main._refresh_settings_interface()
	main.settings_actions_slider.grab_focus()
	var dpad_right := InputEventJoypadButton.new()
	dpad_right.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad_right.pressed = true
	main.get_viewport().push_input(dpad_right, true)
	await tree.process_frame
	_expect(
		main.actions_volume == 100,
		"Gamepad D-pad must change and clamp action volume in 5-point steps (got %d)" % main.actions_volume,
	)
	dpad_right = dpad_right.duplicate()
	dpad_right.pressed = false
	main.get_viewport().push_input(dpad_right, true)
	await tree.process_frame

	main.settings_background_slider.grab_focus()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = main.settings_background_slider.global_position + Vector2(2, 21)
	main.get_viewport().push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	main.get_viewport().push_input(click, true)
	await tree.process_frame
	_expect(main.background_volume <= 5, "Mouse interaction must be able to drag/click an audio slider to its zero end")
	main.actions_volume = 50
	main._refresh_settings_interface()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = main.settings_actions_slider.global_position + Vector2(2, 21)
	main.get_viewport().push_input(touch, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = main.settings_actions_slider.global_position + Vector2(
		main.settings_actions_slider.size.x - 2, 21,
	)
	drag.relative = Vector2(main.settings_actions_slider.size.x - 4, 0)
	main.get_viewport().push_input(drag, true)
	touch = touch.duplicate()
	touch.pressed = false
	touch.position = drag.position
	main.get_viewport().push_input(touch, true)
	await tree.process_frame
	_expect(main.actions_volume >= 95, "Touch drag must be able to move an audio slider to its upper end")

	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	main.get_viewport().push_input(cancel, true)
	var movement := InputEventAction.new()
	movement.action = "move_right"
	movement.pressed = true
	main.get_viewport().push_input(movement, true)
	await tree.process_frame
	_expect(
		not main.settings_open and main.player_pos == Vector2i(4, 3),
		"Closing Settings must immediately release focus so Dungeon movement is not intercepted",
	)
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		for speed_percent in Presentation.AUTO_MOVEMENT_SPEED_PERCENTS:
			main.auto_movement_speed_percent = speed_percent
			main._apply_locale()
			var option_key := Presentation.auto_movement_speed_locale_key(speed_percent)
			_expect(
				main.settings_auto_movement_speed_button.text == Loc.text(
					"SETTINGS_AUTO_SPEED", [Loc.text(option_key)],
				)
				and ["Base", "База", "+50", "+100", "+125"].has(Loc.text(option_key))
				and main.settings_auto_movement_speed_button.size == Vector2(400, 42),
				"Automatic speed option %d must fit the RU/EN settings row" % speed_percent,
			)
		for key in [
			"SETTINGS_SOUND_ON", "SETTINGS_SOUND_OFF", "SETTINGS_BACKGROUND_VOLUME",
			"SETTINGS_ACTIONS_VOLUME", "SETTINGS_AUTO_SPEED", "SETTINGS_AUTO_SPEED_BASE",
			"SETTINGS_AUTO_SPEED_PLUS_50", "SETTINGS_AUTO_SPEED_PLUS_100",
			"SETTINGS_AUTO_SPEED_PLUS_125", "SETTINGS_AUTO_SPEED_DESC",
		]:
			_expect(Loc.STRINGS[locale].has(key), "Audio Settings localization %s missing in %s" % [key, locale])
	main.queue_free()
	await tree.process_frame


func _test_manager_recreation(tree: SceneTree) -> void:
	var bus_count := AudioServer.bus_count
	var first = await _new_main(tree)
	_expect(first.audio_manager.background_history == ["base"], "A fresh Main must request base ambience once")
	first.queue_free()
	await tree.process_frame
	var second = await _new_main(tree)
	_expect(
		AudioServer.bus_count == bus_count
		and second.audio_manager.background_history == ["base"]
		and second.get_children().filter(func(child): return child is AudioManager).size() == 1,
		"Freeing and recreating Main must not duplicate buses or ambient players",
	)
	second.queue_free()
	await tree.process_frame


func _new_main(tree: SceneTree):
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	return main


func _floor_fixture(width := 8, height := 8) -> Dictionary:
	var tiles := {}
	for y in range(height):
		for x in range(width):
			tiles[Vector2i(x, y)] = (
				"floor" if x > 0 and x < width - 1 and y > 0 and y < height - 1 else "wall"
			)
	return {
		"width": width, "height": height, "tiles": tiles,
		"start": Vector2i(2, 3), "base_gate": Vector2i(1, 1),
		"exit": Vector2i(width - 2, height - 2), "exit_known": false,
		"cradle": Vector2i(-1, -1), "cradle_known": false,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [], "enemies": [], "visible_cells": {},
		"explored_cells": {}, "observed_cells": {},
	}


func _reveal_floor(main) -> void:
	var visible := {}
	for cell_variant in main.floor_data["tiles"]:
		var cell: Vector2i = cell_variant
		visible[cell] = true
	main.floor_data["visible_cells"] = visible.duplicate(true)
	main.floor_data["explored_cells"] = visible.duplicate(true)
	main.floor_data["observed_cells"] = visible.duplicate(true)


func _enemy(uid: String, position: Vector2i, hp: int, enemy_id: String) -> Dictionary:
	var rules: Dictionary = GameRules.ENEMIES[enemy_id]
	return {
		"uid": uid, "id": enemy_id, "pos": position, "hp": hp,
		"max_hp": maxi(hp, int(rules["max_hp"])), "damage": int(rules["damage"]),
		"accuracy": int(rules["accuracy"]), "dodge": int(rules["dodge"]),
		"vision": int(rules["vision"]), "souls": int(rules["souls"]),
		"attack_type": String(rules.get("attack_type", "melee")),
		"range": int(rules.get("range", 1)),
		"abilities": rules.get("abilities", []).duplicate(),
	}


func _find_upgrade_failure_seed() -> int:
	for seed_value in range(2, 10_000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() >= 0.5:
			return seed_value
	return 2


func _find_riff_chunk(bytes: PackedByteArray, chunk_id: String) -> Dictionary:
	var offset := 12
	while offset + 8 <= bytes.size():
		var current_id := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var chunk_size := int(bytes.decode_u32(offset + 4))
		if current_id == chunk_id:
			return {"offset": offset + 8, "size": chunk_size}
		offset += 8 + chunk_size + (chunk_size % 2)
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
