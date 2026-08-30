extends SceneTree

const Loc := preload("res://scripts/localization/localization.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")

var locale := "ru"
var capture_failed := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--locale=en":
			locale = "en"
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	root.add_child(main)
	await process_frame
	Loc.set_locale(locale)
	main._apply_locale()
	var ready_slots: Array[Dictionary] = [{
		"slot_id": "newest", "updated_at": 1788012300,
		"character_name": "Хранитель последнего тихого прохода" if locale == "ru" else "Aldren of the Last Quiet Passage",
		"lifetime_souls_earned": 98765, "save_policy": "overwrite",
	}]
	for index in range(1, 8):
		ready_slots.append({
			"slot_id": "history-%d" % index,
			"updated_at": 1788012300 - index * 86400,
			"character_name": (
				"Странник очень длинной летописи %d" % index if locale == "ru"
				else "Wanderer of a Very Long Chronicle %d" % index
			),
			"lifetime_souls_earned": 98765 - index,
			"save_policy": "history",
		})

	_prepare_startup(main, ready_slots)
	await _save("main-ready")
	var no_slots: Array[Dictionary] = []
	main.save_menu_panel.set_slots(no_slots)
	main.save_menu_panel.show_startup()
	await _save("main-empty")
	main.save_menu_panel.set_slots(ready_slots)
	main.save_menu_panel.show_load_list()
	await _save("load-long")
	main.save_menu_panel.show_startup()
	main._on_main_menu_settings_requested()
	await _save("settings-return")
	main._close_settings()

	_prepare_dungeon(main)
	main._open_main_menu()
	await _save("main-from-game")
	main._resume_from_main_menu()

	main.state.add_or_refresh_status("rested", 500, 5)
	main._refresh_interface()
	await process_frame
	var tooltip := _add_tooltip_preview(main)
	await _save("rested-500-tooltip")
	tooltip.queue_free()
	await process_frame
	main.state.active_statuses["rested"] = {"remaining_turns": 1, "temporary_hp": 1}
	await _save("rested-1")

	main.state.active_statuses.clear()
	main.state.ability_cooldowns = {"dash": 20, "double_attack": 15}
	await _save("cooldown-base-20-15")
	main.state.add_or_refresh_status("rested", 500, 5)
	main.state.ability_cooldowns = {"dash": 10, "double_attack": 10}
	await _save("cooldown-rested-10-10")
	main.state.ability_cooldowns = {"dash": 1, "double_attack": 1}
	await _save("cooldown-1")
	main.state.ability_cooldowns.clear()
	await _save("cooldown-ready")
	main.state.ability_loadout = {
		"attack": "basic_attack", "active_1": "", "active_2": "", "active_3": "",
	}
	await _save("cooldown-empty")

	main.state.ability_loadout = {
		"attack": "double_attack", "active_1": "dash", "active_2": "", "active_3": "",
	}
	main.floor_data["tiles"][Vector2i(10, 5)] = "wall"
	main.floor_data["enemies"] = [_enemy("dash-blocker", Vector2i(8, 3))]
	main.floor_data["visible_cells"].erase(Vector2i(6, 4))
	main._begin_dash_targeting()
	for cell_size in [44, 66, 88]:
		main.set_dungeon_cell_size(cell_size)
		await _save("dash-mixed-%d" % cell_size)

	main.queue_free()
	quit(1 if capture_failed else 0)


func _prepare_startup(main, slots: Array[Dictionary]) -> void:
	main.screen = main.Screen.STARTUP
	main.main_menu_open = true
	main._apply_dungeon_layout(false)
	main._hide_game_interface()
	main.title_label.visible = false
	main.menu_button.visible = false
	main.save_menu_panel.set_slots(slots)
	main.save_menu_panel.set_error("")
	main.save_menu_panel.show_startup()


func _prepare_dungeon(main) -> void:
	main.main_menu_open = false
	main.save_menu_panel.close()
	# Capture setup bypasses the normal expedition transition, so explicitly clear
	# startup/name-creation controls before exposing the dungeon composition.
	main._hide_game_interface()
	main._set_controls_visible(main.creation_controls, false)
	main.state = RunState.new()
	main.state.configure_character(
		"Костяной путник" if locale == "ru" else "The Bone Wanderer",
		GameRules.default_attributes(),
	)
	main.state.current_form_id = "ghoul"
	main.state.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	main.state.soul_level = 2
	main.state.skill_levels["dash"] = 1
	main.state.skill_levels["double_attack"] = 1
	main.state.assign_ability("active_1", "dash")
	main.state.assign_ability("attack", "double_attack")
	main.state.hp = main.state.get_max_hp()
	main.state.mana = main.state.get_max_mana()
	main.floor_data = _floor_fixture(16, 10)
	main.player_pos = Vector2i(8, 5)
	main.screen = main.Screen.DUNGEON
	main._apply_dungeon_layout(true)
	for control in [
		main.title_label, main.souls_label, main.soul_icon, main.stats_label,
		main.sidebar_progress_label, main.status_strip, main.inspection_label,
		main.message_label, main.attack_button, main.spell_button, main.active_2_button,
		main.active_3_button, main.character_action_button, main.interact_button,
		main.wait_button, main.wait_count_button, main.auto_explore_button, main.camp_button,
	]:
		control.visible = true
	main._refresh_interface()


func _add_tooltip_preview(main) -> Control:
	var panel := Panel.new()
	panel.name = "TooltipPreview"
	panel.position = Vector2(746, 112)
	panel.size = Vector2(320, 84)
	panel.add_theme_stylebox_override("panel", Ui.make_panel_style(Color("a97043")))
	main.add_child(panel)
	var label := Ui.make_label(panel, Vector2(12, 8), Vector2(296, 68), 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var chips: Array[Node] = main.status_strip.get_children()
	label.text = String(chips[0].tooltip_text) if not chips.is_empty() else Loc.text("STATUS_RESTED")
	return panel


func _floor_fixture(width: int, height: int) -> Dictionary:
	var tiles := {}
	var cells := {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			tiles[cell] = "wall" if x == 0 or y == 0 or x == width - 1 or y == height - 1 else "floor"
			cells[cell] = true
	return {
		"width": width, "height": height, "tiles": tiles,
		"start": Vector2i(1, 1), "base_gate": Vector2i(1, height - 2),
		"exit": Vector2i(width - 2, 1), "exit_known": true,
		"cradle": Vector2i(width - 2, height - 2), "cradle_known": true,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [{"uid": "preview-chest", "id": "bone_knife", "pos": Vector2i(11, 6)}],
		"enemies": [], "visible_cells": cells.duplicate(true),
		"explored_cells": cells.duplicate(true), "observed_cells": cells.duplicate(true),
	}


func _enemy(uid: String, cell: Vector2i) -> Dictionary:
	var rules: Dictionary = GameRules.ENEMIES["grave_rat"]
	return {
		"uid": uid, "id": "grave_rat", "pos": cell,
		"hp": int(rules["max_hp"]), "max_hp": int(rules["max_hp"]),
		"damage": int(rules["damage"]), "accuracy": int(rules["accuracy"]),
		"dodge": int(rules["dodge"]), "vision": int(rules["vision"]),
		"souls": int(rules["souls"]),
	}


func _save(kind: String) -> void:
	var main = root.get_child(root.get_child_count() - 1)
	if main.has_method("_refresh_interface"):
		main._refresh_interface()
		main.queue_redraw()
	await process_frame
	await process_frame
	var viewport_size := root.size
	var path := "res://builds/previews/status-menu-%s-%dx%d-%s.png" % [
		locale, viewport_size.x, viewport_size.y, kind,
	]
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Empty status/menu preview: %s" % kind)
		capture_failed = true
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s (error %d)" % [path, error])
		capture_failed = true
