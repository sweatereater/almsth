extends SceneTree

## Deterministic 2026-09-01 visual QA harness. Run with a normal renderer, never headless.
const Loc := preload("res://scripts/localization/localization.gd")

const VIEWPORTS := [Vector2i(1280, 720), Vector2i(960, 540)]
const ZOOMS := [44, 66, 88]
const SEXES := ["female", "male"]
const CAMP_PAIRS := [
	["campfire", "kettle"],
	["workbench", "writing_set"],
	["crusher", "whetstone"],
]

var output := "res://.tmp/nightly/previews-20260901/raw"
var batch := "all"
var captured: Array[String] = []
var failures: Array[String] = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--batch="):
			batch = argument.trim_prefix("--batch=")
	call_deferred("_capture")


func _capture() -> void:
	if batch not in ["all", "map", "character", "camp"]:
		push_error("Unknown nightly preview batch: %s" % batch)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	main.settings_path = output.path_join("unused-settings.cfg")
	root.add_child(main)
	await process_frame
	# Freeze gameplay presentation time. The harness advances gait phases explicitly.
	main.set_process(false)
	main.main_menu_open = false
	main.save_menu_panel.close()
	if batch in ["all", "map"]:
		await _capture_map_matrix(main)
	if batch in ["all", "character"]:
		await _capture_character_matrix(main)
	if batch in ["all", "camp"]:
		await _capture_camp_matrix(main)
	_write_manifest()
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("NIGHTLY PREVIEW BATCH %s: %d raw captures, %d failures" % [
		batch, captured.size(), failures.size(),
	])
	quit(0 if failures.is_empty() else 1)


func _capture_map_matrix(main) -> void:
	Loc.set_locale("ru")
	main.state = _preview_state("female", "skeleton", "Карта")
	main.floor_data = _floor_fixture()
	main.player_pos = Vector2i(10, 7)
	main._hide_game_interface()
	main._set_controls_visible(main.creation_controls, false)
	main._set_controls_visible(main.character_controls, false)
	main.title_label.visible = false
	main.menu_button.visible = false
	main._show_dungeon_interface()
	main._apply_locale()
	_reveal(main)
	for viewport_size in VIEWPORTS:
		await _set_viewport_size(viewport_size)
		for zoom in ZOOMS:
			main.set_dungeon_cell_size(zoom)
			for sex in SEXES:
				for form_id in GameRules.FORM_ORDER:
					_configure_map_identity(main, sex, form_id)
					main.player_pos = Vector2i(10, 7)
					main.player_map_presentation.activate(sex, form_id)
					main.player_map_presentation.reset(true)
					await _save(main, "map", "%s-%s-z%d-idle" % [sex, form_id, zoom])
					main.player_map_presentation.begin_step(Vector2i.LEFT, 0.2)
					main.player_map_presentation.update(0.05)
					await _save(main, "map", "%s-%s-z%d-mid-left" % [sex, form_id, zoom])
					main.player_map_presentation.reset()

			# Representative direction, interaction and camera-edge checks at every scale.
			_configure_map_identity(main, "male", "almost_human")
			main.player_pos = Vector2i(10, 7)
			main.player_map_presentation.activate("male", "almost_human")
			main.player_map_presentation.face(Vector2i.RIGHT)
			main.player_map_presentation.begin_step(Vector2i.RIGHT, 0.2)
			main.player_map_presentation.update(0.05)
			await _save(main, "map-extra", "male-almost-human-z%d-mirror-right" % zoom)
			main.player_map_presentation.reset()
			main.player_map_presentation.face(Vector2i.RIGHT)
			main.player_map_presentation.begin_step(Vector2i.UP, 0.2)
			main.player_map_presentation.update(0.05)
			await _save(main, "map-extra", "male-almost-human-z%d-vertical-keeps-right" % zoom)
			main.player_map_presentation.reset()
			main.player_map_presentation.face(Vector2i.LEFT)
			main.player_map_presentation.begin_step(Vector2i.LEFT, 0.2)
			main.player_map_presentation.update(0.025)
			main.player_map_presentation.reset()
			await _save(main, "map-extra", "male-almost-human-z%d-stop-snaps-to-cell" % zoom)
			main.player_map_presentation.begin_step(Vector2i.LEFT, 0.2)
			main.player_map_presentation.update(0.025)
			main.player_map_presentation.begin_step(Vector2i.UP, 0.2)
			main.player_map_presentation.update(0.05)
			await _save(main, "map-extra", "male-almost-human-z%d-mid-direction-change" % zoom)
			main.player_map_presentation.reset()

			_configure_map_identity(main, "female", "ghoul")
			main.player_pos = Vector2i(9, 7)
			main.player_map_presentation.activate("female", "ghoul")
			main.player_map_presentation.reset(true)
			await _save(main, "map-extra", "female-ghoul-z%d-door" % zoom)
			main.player_pos = Vector2i(11, 7)
			await _save(main, "map-extra", "female-ghoul-z%d-chest" % zoom)
			main.player_pos = Vector2i(1, 1)
			await _save(main, "map-extra", "female-ghoul-z%d-top-left-edge" % zoom)
	main.player_map_presentation.reset(true)


func _capture_character_matrix(main) -> void:
	for viewport_size in VIEWPORTS:
		await _set_viewport_size(viewport_size)
		for locale in ["ru", "en"]:
			Loc.set_locale(locale)
			for sex in SEXES:
				for form_id in GameRules.FORM_ORDER:
					main.state = _preview_state(
						sex, form_id,
						("Путница" if sex == "female" else "Путник") if locale == "ru" else "Wanderer",
					)
					main._show_base("", "none")
					main._show_character()
					main._select_character_panel("inventory")
					main._apply_locale()
					await _save(main, "character", "%s-%s-%s" % [locale, sex, form_id])

			# Character geometry must be pixel-identical while only dungeon zoom changes.
			main.state = _preview_state("female", "almost_human", "Путница" if locale == "ru" else "Wanderer")
			main._show_base("", "none")
			main._show_character()
			main._select_character_panel("inventory")
			main._apply_locale()
			var zoom_hashes := PackedStringArray()
			for zoom in ZOOMS:
				main.set_dungeon_cell_size(zoom)
				var path := await _save(main, "character-zoom", "%s-female-almost-human-z%d" % [locale, zoom])
				if not path.is_empty():
					zoom_hashes.append(FileAccess.get_sha256(path))
			if zoom_hashes.size() == 3 and (zoom_hashes[0] != zoom_hashes[1] or zoom_hashes[1] != zoom_hashes[2]):
				failures.append("Character Sheet changed between dungeon zooms for %s at %s" % [locale, viewport_size])

			# Hands: empty, one-handed, both two-handed attack classes, ghost release,
			# replacement, and the real 44x44 Old Claymore inventory-list context.
			main.state.loadout = {"jacket": GameRules.permanent_jacket_key()}
			main._refresh_character_sheet()
			await _save(main, "hands", "%s-empty" % locale)
			main.state.loadout = {
				"jacket": GameRules.permanent_jacket_key(),
				"right_hand": "rusty_sabre@0",
				"left_hand": "bone_buckler@0",
			}
			main._refresh_character_sheet()
			await _save(main, "hands", "%s-one-handed-pair" % locale)
			main.state.loadout = {
				"jacket": GameRules.permanent_jacket_key(),
				"right_hand": "old_claymore@0",
			}
			main._refresh_character_sheet()
			main.character_equipment_buttons["left_hand"].grab_focus()
			await _save(main, "hands", "%s-two-handed-ghost-focus" % locale)
			main.state.loadout = {
				"jacket": GameRules.permanent_jacket_key(),
				"right_hand": "bone_bow@0",
			}
			main._refresh_character_sheet()
			await _save(main, "hands", "%s-ranged-two-handed-ghost" % locale)
			main.state.loadout = {"jacket": GameRules.permanent_jacket_key()}
			main._refresh_character_sheet()
			await _save(main, "hands", "%s-two-handed-removed-offhand-free" % locale)
			main.state.loadout = {
				"jacket": GameRules.permanent_jacket_key(),
				"right_hand": "rusty_sabre@0",
			}
			main._refresh_character_sheet()
			await _save(main, "hands", "%s-two-handed-replaced-one-handed" % locale)
			main.state.inventory = {"old_claymore@0": 1}
			main.inventory_panel.set_filter("weapon")
			main.inventory_panel.select_item("old_claymore@0", "inventory")
			main.inventory_panel.refresh()
			await _save(main, "hands", "%s-old-claymore-44-list" % locale)


func _capture_camp_matrix(main) -> void:
	for viewport_size in VIEWPORTS:
		await _set_viewport_size(viewport_size)
		for locale in ["ru", "en"]:
			Loc.set_locale(locale)
			main.state = _camp_state(locale)
			main._show_base("", "none")
			main._apply_locale()
			_set_camp_modules(main.state, [])
			await _save(main, "camp", "%s-empty" % locale)
			for module_id in GameRules.CAMP_DRAW_ORDER:
				_set_camp_modules(main.state, [module_id])
				await _save(main, "camp-module", "%s-%s-only" % [locale, module_id])
			for pair in CAMP_PAIRS:
				_set_camp_modules(main.state, pair)
				await _save(main, "camp-pair", "%s-%s-%s" % [locale, pair[0], pair[1]])
			_set_camp_modules(main.state, [
				"mural", "bunk", "workbench", "writing_set", "crusher", "campfire", "kettle",
			])
			await _save(main, "camp", "%s-mixed" % locale)
			_set_camp_modules(main.state, GameRules.CAMP_DRAW_ORDER)
			await _save(main, "camp", "%s-all" % locale)

			# One modal state simultaneously exposes built, free/available,
			# insufficient-resource, and prerequisite-blocked rows.
			_set_camp_modules(main.state, ["workbench"])
			main.state.resources = {"wood": 0, "stone": 0, "cloth": 0}
			main._show_base("", "none")
			main._open_camp_build_panel()
			main.camp_build_panel.scroll.scroll_vertical = 0
			await process_frame
			await _save(main, "camp-modal", "%s-mixed-top" % locale)
			var bar: VScrollBar = main.camp_build_panel.scroll.get_v_scroll_bar()
			main.camp_build_panel.scroll.scroll_vertical = int(bar.max_value)
			await process_frame
			await _save(main, "camp-modal", "%s-mixed-bottom" % locale)
			main.camp_build_panel.close()

			# Camp state must not alter the explicit old death background/composition.
			_set_camp_modules(main.state, [])
			main._show_story("death", "")
			var before_path := await _save(main, "death", "%s-before-camp-replacement" % locale)
			main._show_base("", "none")
			_set_camp_modules(main.state, GameRules.CAMP_DRAW_ORDER)
			main._show_story("death", "")
			var after_path := await _save(main, "death", "%s-after-all-modules" % locale)
			if not before_path.is_empty() and not after_path.is_empty():
				if FileAccess.get_sha256(before_path) != FileAccess.get_sha256(after_path):
					failures.append("Death composition changed with camp state for %s at %s" % [locale, viewport_size])


func _preview_state(sex: String, form_id: String, name: String) -> RunState:
	var state := RunState.new()
	state.configure_character(name, GameRules.default_attributes())
	state.character_sex = sex
	state.current_form_id = form_id
	state.absorbed_souls = int(GameRules.FORMS[form_id].threshold)
	state.highest_unlocked_form_index = 4
	state.soul_level = 3
	state.carried_souls = 217
	state.banked_souls = 83
	state.resources = {"wood": 99, "stone": 99, "cloth": 99}
	state.hp = state.get_max_hp()
	state.mana = state.get_max_mana()
	return state


func _camp_state(locale: String) -> RunState:
	var state := _preview_state("female", "almost_human", "Хранительница лагеря" if locale == "ru" else "Camp Keeper")
	state.resources = {"wood": 999, "stone": 999, "cloth": 999}
	state.banked_souls = 999
	state.milestones.minotaur_defeated = true
	state.milestones.minotaur_tail_awarded = true
	state.trophies.minotaur_tail = 1
	return state


func _configure_map_identity(main, sex: String, form_id: String) -> void:
	main.state.character_sex = sex
	main.state.current_form_id = form_id
	main.state.display_form_id = ""
	main.state.absorbed_souls = int(GameRules.FORMS[form_id].threshold)
	main.state.highest_unlocked_form_index = 4
	main.state.soul_level = 3
	main.state.hp = main.state.get_max_hp()
	main.state.mana = main.state.get_max_mana()
	main._refresh_interface()


func _set_camp_modules(state: RunState, built_ids: Array) -> void:
	for module_id in GameRules.CAMP_DRAW_ORDER:
		state.camp_upgrades[module_id] = module_id in built_ids


func _floor_fixture() -> Dictionary:
	var width := 20
	var height := 14
	var tiles := {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			tiles[cell] = "wall" if x == 0 or y == 0 or x == width - 1 or y == height - 1 else "floor"
	tiles[Vector2i(8, 7)] = "door_closed"
	return {
		"width": width, "height": height, "tiles": tiles,
		"start": Vector2i(10, 7), "base_gate": Vector2i(2, 11),
		"exit": Vector2i(17, 2), "exit_known": true,
		"cradle": Vector2i(17, 11), "cradle_known": true,
		"cradle_pity_resolved": true, "cradle_used": false,
		"items": [{
			"uid": "nightly-chest", "id": "bone_knife", "item_id": "bone_knife",
			"pos": Vector2i(12, 7), "wood": 0, "stone": 0, "appearance": "chest",
		}],
		"enemies": [], "rooms": [], "decorations": {},
		"visible_cells": {}, "explored_cells": {}, "observed_cells": {},
	}


func _reveal(main) -> void:
	var cells := {}
	for cell in main.floor_data.tiles:
		cells[cell] = true
	main.floor_data.visible_cells = cells.duplicate(true)
	main.floor_data.explored_cells = cells.duplicate(true)
	main.floor_data.observed_cells = cells.duplicate(true)


func _set_viewport_size(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	await process_frame
	await process_frame


func _save(main, category: String, kind: String) -> String:
	main._refresh_interface()
	main.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var viewport_size := root.size
	var path := output.path_join("%s-%dx%d-%s.png" % [
		category, viewport_size.x, viewport_size.y, kind.replace("_", "-"),
	])
	if image == null or image.is_empty():
		failures.append("Normal-renderer capture is empty: %s" % path)
		return ""
	if image.get_size() != viewport_size:
		failures.append("Capture size mismatch for %s: %s" % [path, image.get_size()])
	if image.save_png(path) != OK:
		failures.append("Could not save capture: %s" % path)
		return ""
	captured.append(path)
	print("NIGHTLY RAW PREVIEW: %s" % path)
	return path


func _write_manifest() -> void:
	var records: Array[Dictionary] = []
	for path in captured:
		records.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	var manifest_path := output.path_join("manifest-%s.json" % batch)
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write preview manifest: %s" % manifest_path)
		return
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"batch": batch,
		"normal_renderer_required": true,
		"captures": records,
	}, "  ", false, true) + "\n")
