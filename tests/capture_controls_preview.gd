extends SceneTree

## Local visual QA helper for the controls screen at supported window sizes.


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var target_size := Vector2i(1280, 720)
	var show_conflict := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--minimum-window":
			target_size = Vector2i(960, 540)
		elif argument == "--conflict":
			show_conflict = true
	DisplayServer.window_set_size(target_size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.audio_playback_enabled = false
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main._open_settings()
	main._open_controls_remap()
	if show_conflict:
		main.controls_remap_panel.keyboard_buttons["attack"].pressed.emit()
		var conflicting_key := InputEventKey.new()
		conflicting_key.pressed = true
		conflicting_key.keycode = KEY_Q
		main.controls_remap_panel.handle_input(conflicting_key)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	var suffix := "960x540" if target_size == Vector2i(960, 540) else "1280x720"
	if show_conflict:
		suffix += "-conflict"
	var path := "res://builds/previews/controls-%s.png" % suffix
	var error := image.save_png(path)
	print("CONTROLS PREVIEW: %s (%dx%d), error=%d" % [
		path,
		image.get_width(),
		image.get_height(),
		error,
	])
	quit(0 if error == OK else 1)
