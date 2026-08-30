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
	Loc.set_locale(locale)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.audio_playback_enabled = false
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.state.configure_character(
		(
			"Путник с чрезвычайно длинным именем"
			if locale == "ru" else "The Wanderer With An Exceptionally Long Name"
		),
		GameRules.default_attributes(),
	)
	main.state.current_form_id = "almost_human"
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
	main.state.skill_levels["stomach"] = 1
	main.state.unspent_attribute_points = 7
	for index in range(GameRules.ATTRIBUTE_ORDER.size()):
		main.state.attributes[GameRules.ATTRIBUTE_ORDER[index]] = 100000 + index
	main.state.add_or_refresh_status("rested", 321, 5)
	main.state.add_or_refresh_status("satiated", 200, 3)
	main._show_base("")
	main._show_character()
	main._select_character_panel("inventory")
	main._apply_locale()
	main.character_attribute_spend_buttons["wisdom"].grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://builds/previews/character-attributes-%s-%dx%d.png" % [
		locale, root.size.x, root.size.y,
	]
	if image == null or image.is_empty():
		push_error("Character attributes preview requires a rendered viewport")
		main.queue_free()
		quit(1)
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save Character attributes preview %s (error %d)" % [path, error])
		main.queue_free()
		quit(1)
		return
	print("CHARACTER ATTRIBUTES PREVIEW: %s" % path)
	main.queue_free()
	quit(0)
