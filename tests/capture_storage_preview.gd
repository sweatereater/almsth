extends SceneTree

## Deterministic Stage 1B visual-review fixtures. Run with a rendering driver;
## headless mode uses the dummy renderer and is unsuitable for screenshots.
const Loc := preload("res://scripts/localization/localization.gd")
const OUT := "res://.tmp/storage-previews/"

var captures: Array[String] = []


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	root.add_child(main)
	await process_frame
	for viewport_size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = viewport_size
		await process_frame
		for locale in Loc.SUPPORTED_LOCALES:
			Loc.set_locale(locale)
			main.state = _state(locale)
			main._show_base("", "none")
			main._apply_locale()
			await _save(main, "%s-base-built" % locale)
			main.storage_chest_object_button.pressed.emit()
			await process_frame
			main.storage_panel.inventory_rows[0].grab_focus()
			await process_frame
			await _save(main, "%s-storage-two-lists" % locale)
			main.storage_panel._set_filter("hands")
			await _save(main, "%s-storage-empty-category" % locale)
			main.storage_panel.close()
			await process_frame
	var manifest := FileAccess.open(OUT + "manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({
		"captures": captures,
		"asset": "assets/art/camp-2026-09-01/camp-storage-chest.png",
		"asset_sha256": FileAccess.get_sha256(
			"res://assets/art/camp-2026-09-01/camp-storage-chest.png"
		),
		"source_hashes": {
			"scripts/main.gd": FileAccess.get_sha256("res://scripts/main.gd"),
			"scripts/ui/storage_panel.gd": FileAccess.get_sha256("res://scripts/ui/storage_panel.gd"),
			"scripts/ui/base_layout.gd": FileAccess.get_sha256("res://scripts/ui/base_layout.gd"),
			"scripts/localization/localization.gd": FileAccess.get_sha256("res://scripts/localization/localization.gd"),
		},
	}, "\t"))
	main.queue_free()
	await process_frame
	Loc.set_locale("ru")
	print("STORAGE PREVIEWS CAPTURED: %d" % captures.size())
	quit(0)


func _state(locale: String) -> RunState:
	var state := RunState.new()
	state.configure_character(
		"Хранитель" if locale == "ru" else "The Patient Storekeeper",
		GameRules.default_attributes(),
	)
	state.current_form_id = "almost_human"
	state.highest_unlocked_form_index = 4
	state.resources = {"wood": 80, "stone": 30, "cloth": 20}
	state.camp_upgrades.storage_chest = true
	state.add_item("bone_knife", 3, 12)
	state.add_item("rotting_mail", 0, 2)
	state.add_item("aiming_ring", 0, 8)
	state.add_item("expedition_backpack", 0, 1)
	state.set_item_mark("bone_knife@3", "keep")
	state.set_item_mark("aiming_ring@0", "salvage")
	state.storage["bone_bow@2:bound"] = 3
	state.storage["lamellar_vest@0"] = 2
	state.storage["thickblood_ring@0"] = 6
	state.storage_marks["bone_bow@2:bound"] = "keep"
	state.storage_marks["thickblood_ring@0"] = "salvage"
	state.hp = state.get_max_hp()
	state.mana = state.get_max_mana()
	return state


func _save(main, label: String) -> void:
	main._refresh_interface()
	main.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OUT + "%dx%d-%s.png" % [root.size.x, root.size.y, label]
	var image := root.get_texture().get_image()
	if image.is_empty() or image.save_png(path) != OK:
		push_error("Failed Storage preview: " + path)
		quit(1)
		return
	captures.append(path)
	print(path)
