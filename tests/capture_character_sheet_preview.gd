extends SceneTree

const Loc := preload("res://scripts/localization/localization.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")

var locale := "ru"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--locale=en":
			locale = "en"
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))
	Loc.set_locale(locale)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.audio_playback_enabled = false
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	_configure_almost_human(main)
	main._show_base("")
	main._show_character()
	main._apply_locale()
	for zoom in [44, 66, 88]:
		main.set_dungeon_cell_size(zoom)
		for panel_mode in ["inventory", "skills"]:
			main._select_character_panel(panel_mode)
			await _save(main, "zoom%d-%s" % [zoom, panel_mode])
	if locale == "ru":
		main._select_character_panel("inventory")
		for form_id in GameRules.FORM_ORDER:
			main.state.current_form_id = form_id
			main.state.display_form_id = ""
			main._refresh_character_sheet()
			await _save(main, "form-%s-inventory" % form_id)
		main.state.current_form_id = "almost_human"
		main._refresh_character_sheet()
	main.state.add_or_refresh_status("rested", 500, 5)
	main._select_character_panel("inventory")
	main._on_equipment_slot_pressed("jacket")
	main._refresh_character_sheet()
	await process_frame
	main.character_equipment_buttons["jacket"].grab_focus()
	await _save(main, "rested-jacket-selected")
	main._select_character_panel("skills")
	await _save(main, "rested-skills-hidden")

	main._select_character_panel("inventory")
	main.state.character_name = "Путник с очень долгим именем" if locale == "ru" else "The Long-Named Soulwalker"
	main._refresh_character_sheet()
	main.character_equipment_buttons["ring_2"].grab_focus()
	await _save(main, "almost-human-all-slots-long-name")

	main.inventory_panel.set_filter("weapon")
	main.inventory_panel.select_item("bone_bow@2", "inventory")
	main._refresh_character_sheet()
	await _save(main, "equipped-selected-details")

	main.state.display_form_id = "skeleton"
	main._refresh_character_sheet()
	await _save(main, "actual-almost-human-display-skeleton")

	main.state.current_form_id = "skeleton"
	main.state.display_form_id = ""
	main.state.loadout = {
		"jacket": GameRules.permanent_jacket_key(),
		"right_hand": "bone_knife@0",
		"left_hand": "pilgrim_shield@0",
		"talisman": "soul_locket@0",
	}
	main._refresh_character_sheet()
	main.character_equipment_buttons["body"].grab_focus()
	await _save(main, "skeleton-locked-focus")

	_write_asset_sheet()
	main.queue_free()
	quit(0)


func _configure_almost_human(main) -> void:
	main.state = RunState.new()
	main.state.character_name = "Собиратель душ" if locale == "ru" else "Soul Collector"
	main.state.current_form_id = "almost_human"
	main.state.highest_unlocked_form_index = 4
	main.state.soul_level = 4
	main.state.carried_souls = 217
	main.state.banked_souls = 83
	main.state.unspent_attribute_points = 7
	main.state.add_resources({"wood": 99, "stone": 99, "cloth": 99})
	main.state.camp_upgrades["crusher"] = true
	main.state.camp_upgrades["whetstone"] = true
	for item in [
		["bone_bow", 2], ["bone_knife", 1], ["grave_mace", 0], ["soul_locket", 0],
		["rotting_mail", 0], ["leather_gloves", 0], ["hollow_lantern", 0],
		["pilgrim_shield", 0],
	]:
		main.state.add_item(item[0], item[1], 2)
	main.state.loadout = {
		"jacket": GameRules.permanent_jacket_key(),
		"right_hand": "bone_knife@1",
		"left_hand": "pilgrim_shield@0",
		"body": "rotting_mail@0",
		"hands": "leather_gloves@0",
		"talisman": "soul_locket@0",
		# Preview-only physical-slot fixture; it does not enter save/gameplay rules.
		"ring_1": "soul_locket@0",
		"ring_2": "hollow_lantern@0",
	}


func _save(main, kind: String) -> void:
	main.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Character preview requires a non-headless display driver: %s" % kind)
		return
	var path := "res://builds/previews/character-%s-%dx%d-%s.png" % [
		locale, root.size.x, root.size.y, kind,
	]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save Character preview %s (error %d)" % [path, error])


func _write_asset_sheet() -> void:
	var sheet := Image.create(1320, 1408, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("11151c"))
	for y in range(0, 704, 16):
		for x in range(0, 1320, 16):
			sheet.fill_rect(
				Rect2i(x, y, 16, 16),
				Color("c8c8c8") if int(x / 16 + y / 16) % 2 == 0 else Color("8d8d8d"),
			)
	var forms := ["skeleton", "zombie", "ghoul", "revenant", "almost_human"]
	for index in range(forms.size()):
		var texture: Texture2D = Renderer.FORM_FULLBODY[forms[index]]
		var figure := texture.get_image()
		sheet.blend_rect(figure, Rect2i(Vector2i.ZERO, figure.get_size()), Vector2i(index * 264, 0))
		sheet.blend_rect(figure, Rect2i(Vector2i.ZERO, figure.get_size()), Vector2i(index * 264, 704))
	var path := "res://builds/previews/character-assets-checker-dark.png"
	var error := sheet.save_png(path)
	if error != OK:
		push_error("Could not save Character asset review sheet (error %d)" % error)
