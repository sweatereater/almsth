extends SceneTree

const Loc := preload("res://scripts/localization/localization.gd")
const Artwork := preload("res://scripts/ui/character_artwork.gd")
var output := "res://.tmp/character-sex-previews"
var failed := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	main.settings_path = output.path_join("unused-settings.cfg")
	root.add_child(main)
	await process_frame
	for locale in ["ru", "en"]:
		Loc.set_locale(locale)
		for sex in Artwork.SEXES:
			main._reset_for_new_character()
			main._show_name_creation()
			main.sex_choice_panel.buttons[sex].pressed.emit()
			var character_name := ("Путница" if sex == "female" else "Путник") if locale == "ru" else "Wanderer"
			main.name_input.text = character_name
			main._apply_locale()
			main.sex_choice_panel.buttons["male" if sex == "female" else "female"].grab_focus()
			await _save(main, "creation-%s-%s" % [locale, sex])
			main.state.configure_character(character_name, GameRules.default_attributes())
			main.state.highest_unlocked_form_index = 4
			main.state.soul_level = 4
			main._show_base("", "none")
			main.character_panel_mode = "inventory"
			main._show_character()
			for form in Artwork.FORMS:
				if locale == "en" and form != "almost_human":
					continue
				main.state.current_form_id = form
				main._refresh_character_sheet()
				main._apply_locale()
				await _save(main, "sheet-%s-%s-%s" % [locale, sex, form])
			if locale == "ru":
				for zoom in [44, 66, 88]:
					main.set_dungeon_cell_size(zoom)
					await _save(main, "sheet-zoom%d-%s" % [zoom, sex])
	main.queue_free()
	quit(1 if failed else 0)


func _save(main, kind: String) -> void:
	main.queue_redraw()
	await process_frame
	await process_frame
	var capture := root.get_texture().get_image()
	if capture == null or capture.is_empty():
		push_error("Preview needs a non-headless renderer")
		failed = true
		return
	var path := output.path_join("%s-%dx%d.png" % [kind, root.size.x, root.size.y])
	failed = capture.save_png(path) != OK or failed
