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
	main.state = _appearance_state()
	main.screen = main.Screen.DUNGEON
	main._load_floor(99)
	main._apply_locale()
	main._refresh_interface()
	main.queue_redraw()

	main._open_appearance_choice()
	await _save("modal-current")
	main.appearance_choice_panel._select_index(3)
	await _save("modal-selected")
	main._cancel_appearance_choice()

	main.state.set_display_form_id("zombie")
	main._show_character()
	main._select_character_panel("skills")
	await _save("character-override")
	main._close_character()

	for form_id in GameRules.FORM_ORDER:
		main.state.set_display_form_id(form_id)
		main._refresh_interface()
		main.queue_redraw()
		await _save("dungeon-%s" % form_id)

	main.queue_free()
	quit(0)


func _appearance_state() -> RunState:
	var state := RunState.new()
	state.configure_character(
		"Хранитель множества обликов" if locale == "ru" else "Keeper of Many Remembered Forms",
		GameRules.default_attributes(),
	)
	state.current_form_id = "almost_human"
	state.absorbed_souls = 80
	state.highest_unlocked_form_index = 4
	state.soul_level = 4
	state.skill_levels["choose_appearance"] = 1
	state.assign_ability("active_3", "choose_appearance")
	state.carried_souls = 9999
	return state


func _save(kind: String) -> void:
	await process_frame
	await process_frame
	var viewport_size := root.size
	var path := "res://builds/previews/appearance-%s-%dx%d-%s.png" % [
		locale, viewport_size.x, viewport_size.y, kind,
	]
	var image := root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(path)
