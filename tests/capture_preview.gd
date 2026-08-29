extends SceneTree

const Loc := preload("res://scripts/localization/localization.gd")

## Local visual QA helper. It is not part of the exported game.


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.audio_playback_enabled = false
	main.persistence_enabled = false
	root.add_child(main)

	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/name-creation.png")

	main.name_input.text = "Морвен"
	main._on_name_confirmed()
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		main._change_pending_attribute(attribute_id, 1)
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/stat-creation.png")

	main._on_attributes_confirmed()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/intro-01.png")
	main._advance_story()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/intro-02.png")
	main._advance_story()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/intro-03.png")
	main._advance_story()
	main.state.add_resources({"wood": 20, "stone": 20, "cloth": 5})
	main.state.build_camp_upgrade("crusher")
	main.state.build_camp_upgrade("whetstone")
	main._refresh_interface()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/base.png")
	main.state.add_item("bone_knife", 0, 3)
	main.state.add_item("bone_knife", 2, 1)
	main.state.add_item("rotting_mail", 0, 1)
	main.state.add_item("soul_locket", 0, 1)
	main.state.add_resources(GameRules.WEAPON_UPGRADE_COST)
	main.state.unspent_attribute_points = 2
	main._show_character()
	main._select_character_panel("inventory")
	main._on_inventory_stack_pressed(0)
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/character-inventory.png")
	main._close_character()
	main.state.skill_levels["magic_awakening"] = 1
	main.state.skill_levels["magic_missile"] = 2
	main.state.skill_levels["magic_missile_range"] = 1
	main.state.skill_levels["magic_ricochet"] = 2
	main.state.assign_ability("active_1", "magic_missile")
	main.state.mana = main.state.get_max_mana()

	main._on_start_pressed()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/expedition-choice.png")
	main._on_beginning_ascent_pressed()
	for cell in main.floor_data["tiles"]:
		if (
			main.floor_data["tiles"][cell] == "floor"
			and cell != main.floor_data["start"]
			and cell != main.floor_data["exit"]
			and cell != main.floor_data["base_gate"]
		):
			main.floor_data["cradle"] = cell
			break
	main.floor_data["cradle_used"] = false
	main.state.record_cradle_result(true)
	main._refresh_interface()
	main._log_action(Loc.text("MSG_TURN_DONE"))
	main._log_action(Loc.text("MSG_ENTER_FLOOR", [main.state.current_floor]))
	main._log_action(Loc.text("MSG_PLAYER_MISS", [Loc.text("ENEMY_GRAVE_RAT"), 7, 12]))
	main._log_action(Loc.text("MSG_ITEM_EQUIPPED", [Loc.text("ITEM_BONE_KNIFE")]))
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/dungeon.png")
	var generated_floor: Dictionary = main.floor_data
	var generated_player_position: Vector2i = main.player_pos
	var generated_floor_number: int = main.state.current_floor
	var showcase_tiles := {}
	var showcase_visibility := {}
	for y in range(14):
		for x in range(20):
			var showcase_cell := Vector2i(x, y)
			showcase_tiles[showcase_cell] = (
				"wall" if x == 0 or y == 0 or x == 19 or y == 13 else "floor"
			)
			showcase_visibility[showcase_cell] = true
	main.floor_data = {
		"width": 20,
		"height": 14,
		"tiles": showcase_tiles,
		"start": Vector2i(10, 7),
		"base_gate": Vector2i(2, 11),
		"exit": Vector2i(17, 2),
		"exit_known": true,
		"cradle": Vector2i(16, 11),
		"cradle_known": true,
		"cradle_used": false,
		"items": [{"uid": "showcase_chest", "id": "bone_knife", "pos": Vector2i(4, 3)}],
		"visible_cells": showcase_visibility.duplicate(true),
		"explored_cells": showcase_visibility.duplicate(true),
		"observed_cells": showcase_visibility.duplicate(true),
		"enemies": [
			{
				"uid": "showcase_rat", "id": "grave_rat", "pos": Vector2i(7, 7),
				"hp": 2, "max_hp": 2, "damage": 1, "accuracy": 2, "dodge": 2,
				"vision": 3, "souls": 1,
			},
			{
				"uid": "showcase_guard", "id": "hollow_guard", "pos": Vector2i(13, 7),
				"hp": 4, "max_hp": 4, "damage": 2, "accuracy": 3, "dodge": 1,
				"vision": 5, "souls": 2,
			},
			{
				"uid": "showcase_leech", "id": "soul_leech", "pos": Vector2i(10, 4),
				"hp": 5, "max_hp": 5, "damage": 2, "accuracy": 4, "dodge": 2,
				"vision": 4, "souls": 3,
			},
		],
	}
	main.player_pos = Vector2i(10, 7)
	main.inspected_target.clear()
	main._refresh_interface()
	main.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/dungeon-assets.png")
	main.floor_data = FixedFloor90.create()
	var boss_floor_visibility := {}
	for boss_floor_cell in main.floor_data["tiles"]:
		if main.floor_data["tiles"][boss_floor_cell] != "void":
			boss_floor_visibility[boss_floor_cell] = true
	main.floor_data["visible_cells"] = boss_floor_visibility.duplicate(true)
	main.floor_data["explored_cells"] = boss_floor_visibility.duplicate(true)
	main.floor_data["observed_cells"] = boss_floor_visibility.duplicate(true)
	main.floor_data["exit_known"] = true
	main.state.current_floor = FixedFloor90.FLOOR_NUMBER
	main.player_pos = main.floor_data["start"]
	main.inspected_target.clear()
	main._refresh_interface()
	main.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/dungeon-boss-90.png")
	main.state.current_floor = FixedFloor90.FLOOR_NUMBER + 1
	main.player_pos = main.floor_data["exit"]
	main._on_ascend_pressed()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/boss-warning.png")
	main._close_boss_warning()
	main.floor_data = generated_floor
	main.player_pos = generated_player_position
	main.state.current_floor = generated_floor_number
	main._update_player_visibility(false)
	main._refresh_interface()
	var fog_route: Array[Vector2i] = []
	for cell in main.floor_data["tiles"]:
		if (
			main.floor_data["tiles"][cell] == "floor"
			and main._manhattan(main.player_pos, cell) > 6
		):
			fog_route = main._find_floor_path(main.player_pos, cell)
			if fog_route.size() > 6:
				break
	if fog_route.size() > 6:
		main.player_pos = fog_route[6]
		main._update_player_visibility(false)
		main._refresh_interface()
		await process_frame
		await RenderingServer.frame_post_draw
		_save_viewport("res://builds/previews/dungeon-fog-memory.png")
	var magic_target: Dictionary = {}
	for enemy in main.floor_data["enemies"]:
		if (
			main._manhattan(main.player_pos, enemy["pos"]) <= main.state.get_magic_missile_range()
			and main._has_clear_spell_line(main.player_pos, enemy["pos"])
		):
			magic_target = enemy
			break
	if magic_target.is_empty():
		for cell in main.floor_data["tiles"]:
			if (
				main.floor_data["tiles"][cell] == "floor"
				and cell != main.player_pos
				and main._manhattan(main.player_pos, cell) <= main.state.get_magic_missile_range()
				and main._has_clear_spell_line(main.player_pos, cell)
			):
				magic_target = {
					"uid": "preview_magic", "id": "hollow_guard", "pos": cell,
					"hp": 8, "max_hp": 8, "damage": 0, "accuracy": 0, "dodge": 0, "souls": 1,
				}
				main.floor_data["enemies"].append(magic_target)
				break
	if not magic_target.is_empty():
		main.inspected_target = {
			"kind": "enemy", "uid": magic_target["uid"], "entity": magic_target,
		}
		main.state.mana = main.state.get_max_mana()
		main._on_spell_pressed(1.0)
		await process_frame
		await RenderingServer.frame_post_draw
		_save_viewport("res://builds/previews/dungeon-magic.png")
		main.inspected_target.clear()
	var preview_player_position: Vector2i = main.player_pos
	main.player_pos = main.floor_data["cradle"]
	main.state.carried_souls = 10
	main._on_interact_pressed()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/cradle-confirmation.png")
	main._close_cradle_confirmation()
	main.player_pos = preview_player_position
	main.state.carried_souls = 0
	main._refresh_interface()
	main._cycle_wait_turn_count()
	main._cycle_wait_turn_count()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/dungeon-wait-100.png")
	main._cycle_wait_turn_count()
	main.floor_data["enemies"].clear()
	main._refresh_interface()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/dungeon-cleared.png")

	main._open_settings()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/settings.png")
	main._close_settings()

	main._show_character()
	main._select_character_panel("skills")
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/character.png")

	main.state.highest_unlocked_form_index = 1
	main.state.current_form_id = "zombie"
	main.state.hunger = 73
	main.state.food = 2
	main.state.hp = main.state.get_max_hp()
	main._select_skill_stage("zombie")
	main._apply_locale()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/character-zombie-skills.png")

	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("revenant")
	main.state.current_form_id = "revenant"
	main.state.skill_levels["sharp_vision"] = 1
	main.state.hp = main.state.get_max_hp()
	main._select_skill_stage("revenant")
	main._apply_locale()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/character-revenant-skills.png")

	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	main.state.current_form_id = "ghoul"
	main.state.skill_levels["dash"] = 1
	main.state.skill_levels["double_attack"] = 1
	main.state.assign_ability("attack", "double_attack")
	main.state.assign_ability("active_1", "dash")
	main._select_skill_stage("ghoul")
	main._apply_locale()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/character-ghoul-skills.png")

	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
	main.state.current_form_id = "almost_human"
	main.state.skill_levels["almost_double_strike"] = 6
	main.state.skill_levels["circular_attack"] = 1
	main.state.assign_ability("attack", "circular_attack")
	main._select_skill_stage("almost_human")
	main._apply_locale()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/character-almost-human-ru.png")
	main._on_language_pressed()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/character-almost-human-en.png")
	main._on_language_pressed()
	main._close_character()
	main._refresh_interface()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/dungeon-ability-hotbar.png")
	main.state.assign_ability("active_1", "dash")
	main._on_spell_pressed()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/dungeon-dash-targeting.png")
	main._cancel_ability_targeting(false)
	main._show_character()

	main.state.current_form_id = "zombie"
	main._select_skill_stage("zombie")
	main._apply_locale()
	main._on_language_pressed()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/character-en.png")
	main._on_language_pressed()
	main._handle_death()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_viewport("res://builds/previews/death.png")
	quit(0)


func _save_viewport(path: String) -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save preview to %s (error %d)" % [path, error])
