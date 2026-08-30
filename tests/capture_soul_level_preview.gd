extends SceneTree

const Loc := preload("res://scripts/localization/localization.gd")

var locale := "ru"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--locale=en":
			locale = "en"
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	root.add_child(main)
	await process_frame
	Loc.set_locale(locale)
	main.state = RunState.new()
	main.state.character_name = "Хранитель долгой души" if locale == "ru" else "Keeper of the Long Returning Soul"
	main.state.soul_level = 4
	main.state.current_form_id = "almost_human"
	main.state.absorbed_souls = 80
	main.state.highest_unlocked_form_index = 4
	main._show_base("")
	main._apply_locale()
	main._show_character()
	main._select_character_panel("skills")
	await _save("character-skills")
	main._select_character_panel("inventory")
	await _save("character-inventory")

	main._close_character()
	main.screen = main.Screen.DUNGEON
	main._load_floor(99)
	main.state.current_form_id = "zombie"
	main.state.absorbed_souls = 10
	main.state.highest_unlocked_form_index = 1
	main.state.soul_level = 1
	main.state.carried_souls = 99
	main.floor_data["cradle_used"] = false
	main._open_cradle_confirmation()
	await _save("cradle-blocked")
	main.state.soul_level = 2
	main._refresh_cradle_confirmation_interface()
	await _save("cradle-allowed")
	main._close_cradle_confirmation()

	main.state = RunState.new()
	main.state.character_name = "Хранитель огня" if locale == "ru" else "Keeper of the First Campfire"
	main._show_base("")
	main.state.add_resources({"wood": 3, "stone": 3})
	main._on_upgrade_pressed()
	await _save("base-campfire")
	main.queue_free()
	quit(0)


func _save(kind: String) -> void:
	await process_frame
	await process_frame
	var viewport_size := root.size
	var path := "res://builds/previews/soul-level-%s-%dx%d-%s.png" % [
		locale, viewport_size.x, viewport_size.y, kind,
	]
	var image := root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(path)
