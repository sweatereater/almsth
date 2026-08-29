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
	main._apply_locale()
	main._open_settings()
	main.audio_muted = false
	main.background_volume = 50
	main.actions_volume = 75
	main._apply_audio_settings()
	main._refresh_settings_interface()
	main.settings_background_slider.grab_focus()
	await _save(main, "settings-on-mid-focus")

	main.audio_muted = true
	main.background_volume = 0
	main.actions_volume = 100
	main._apply_audio_settings()
	main._refresh_settings_interface()
	main.settings_actions_slider.grab_focus()
	await _save(main, "settings-off-extremes-focus")
	main.queue_free()
	quit(0)


func _save(main, kind: String) -> void:
	main.queue_redraw()
	await process_frame
	await process_frame
	var viewport_size := root.size
	var path := "res://builds/previews/audio-%s-%dx%d-%s.png" % [
		locale, viewport_size.x, viewport_size.y, kind,
	]
	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("Empty audio Settings preview for %s" % kind)
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save audio Settings preview to %s (error %d)" % [path, error])
