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
	main.state = RunState.new()
	main.state.character_name = "Собиратель душ" if locale == "ru" else "Soul Collector"
	main.state.current_form_id = "almost_human"
	main.state.highest_unlocked_form_index = 4
	main.state.carried_souls = 240
	main.state.banked_souls = 160
	main.state.unspent_attribute_points = 7
	main._show_base("")
	main._show_character()
	main._select_character_panel("skills")
	main._apply_locale()

	await _capture_stage(main, "skeleton", "strong_bones", "skeleton-purchasable")
	await _capture_stage(main, "skeleton", "fundamentals", "skeleton-prerequisite-locked")
	main.state.skill_levels["strong_bones"] = 1
	main._refresh_character_sheet()
	await _capture_stage(main, "skeleton", "strong_bones", "skeleton-learned-upgrade")
	main.state.skill_levels["strong_bones"] = 10
	main.state.skill_levels["fundamentals"] = 1
	main._refresh_character_sheet()
	await _capture_stage(main, "skeleton", "strong_bones", "skeleton-max")
	main.state.skill_levels["strong_bones"] = 0
	main.state.skill_levels["fundamentals"] = 0
	main.state.carried_souls = 0
	main.state.banked_souls = 0
	main._refresh_character_sheet()
	await _capture_stage(main, "skeleton", "magic_awakening", "skeleton-insufficient-souls")
	main.state.carried_souls = 240
	main.state.banked_souls = 160
	main._refresh_character_sheet()
	await _capture_stage(main, "ghoul", "nervous_system", "ghoul-three-branches")
	await _capture_stage(main, "almost_human", "almost_soon_2", "almost-human-placeholder")

	var zoom_hashes := PackedInt64Array()
	for zoom in [44, 66, 88]:
		main.set_dungeon_cell_size(zoom)
		main._select_skill_stage("skeleton")
		main._on_skill_pressed("strong_bones")
		var image := await _screen_image(main)
		zoom_hashes.append(hash(image.get_data()))
		_save_image(image, "skeleton-zoom%d" % zoom)
	if zoom_hashes[0] != zoom_hashes[1] or zoom_hashes[1] != zoom_hashes[2]:
		push_error("Character skill tree changed between dungeon zoom 44/66/88")
		main.queue_free()
		quit(1)
		return

	main.queue_free()
	quit(0)


func _capture_stage(main, stage_id: String, node_id: String, kind: String) -> void:
	main._select_skill_stage(stage_id)
	main._on_skill_pressed(node_id)
	_save_image(await _screen_image(main), kind)


func _screen_image(main) -> Image:
	main.queue_redraw()
	await process_frame
	await process_frame
	return root.get_texture().get_image()


func _save_image(image: Image, kind: String) -> void:
	if image == null or image.is_empty():
		push_error("Skill tree preview requires a rendered viewport: %s" % kind)
		return
	var path := "res://builds/previews/skill-tree-%s-%dx%d-%s.png" % [
		locale, root.size.x, root.size.y, kind,
	]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save skill tree preview %s (error %d)" % [path, error])
