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
	main.state.character_name = "Собиратель" if locale == "ru" else "Gatherer"
	main.state.current_form_id = "ghoul"
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
	main.state.skill_levels["stomach"] = 1
	main.state.hunger = 100
	main.state.hp = main.state.get_max_hp()
	main.state.carried_souls = 4321
	main.state.banked_souls = 10000
	main.state.resources = {"wood": 9876, "stone": 5432, "cloth": 1000}
	for upgrade_id in ["crusher", "whetstone", "ritual_table", "campfire"]:
		main.state.camp_upgrades[upgrade_id] = true
	main.state.add_or_refresh_status("rested", 321, 5)
	main.state.add_or_refresh_status("satiated", 200, 3)
	main._show_base("")
	main._apply_locale()
	await process_frame
	await RenderingServer.frame_post_draw
	var viewport_size := root.size
	var path := "res://builds/previews/base-resources-%s-%dx%d.png" % [
		locale, viewport_size.x, viewport_size.y,
	]
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Base resource preview requires a rendered viewport")
		main.queue_free()
		quit(1)
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save base resource preview %s (error %d)" % [path, error])
		main.queue_free()
		quit(1)
		return
	print("BASE RESOURCE PREVIEW: %s" % path)
	main.queue_free()
	quit(0)
