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
	main.audio_playback_enabled = false
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	Loc.set_locale(locale)
	main.state = RunState.new()
	main.state.character_name = "Собиратель" if locale == "ru" else "The Patient Salvage Collector"
	main._show_base("")
	main._apply_locale()
	await _save(main, "base-empty")

	main.state.add_resources({"wood": 999, "stone": 999, "cloth": 999})
	main._on_build_camp_upgrade("crusher")
	main._on_build_camp_upgrade("whetstone")
	main._on_build_camp_upgrade("ritual_table")
	main._on_upgrade_pressed()
	main.ritual_table_object_button.grab_focus()
	await _save(main, "base-built-focus")

	main.state.current_form_id = "almost_human"
	main.state.highest_unlocked_form_index = 4
	main.state.add_item("bone_bow", 2, 999)
	main.state.add_item("bone_knife", 3, 12)
	main.state.add_item("soul_locket")
	main.state.add_item("rotting_mail")
	main.state.add_item("leather_gloves")
	main.state.add_item("hollow_lantern")
	main.state.add_item("pilgrim_shield")
	main.state.loadout["weapon"] = "bone_knife@3"
	main._show_character()
	main._select_character_panel("inventory")
	main.inventory_panel.set_filter("all")
	main.inventory_panel.select_visible_index(0)
	await _save(main, "inventory-all-long")
	main.inventory_panel.set_filter("weapon")
	main.inventory_panel.select_visible_index(0)
	await _save(main, "inventory-weapons")
	main.state.current_form_id = "skeleton"
	main.state.inventory.erase("leather_gloves@0")
	main.inventory_panel.bind_state(main.state, true)
	main.inventory_panel.set_filter("hands")
	main.inventory_panel.select_equipment_slot("hands", false)
	await _save(main, "inventory-empty-locked")

	main._close_character()
	main._open_inventory_service("crusher")
	main.inventory_panel.set_filter("armor")
	main.inventory_panel.select_visible_index(0)
	await _save(main, "crusher")
	main._on_inventory_dismantle_all_pressed()
	await _save(main, "crusher-confirm")
	main._reset_dismantle_all_confirmation()
	main._close_inventory_service()

	main.state.current_form_id = "almost_human"
	main._open_inventory_service("whetstone")
	main.inventory_panel.select_item("bone_bow@2", "inventory")
	await _save(main, "whetstone-inventory")
	main.inventory_panel.select_item("bone_knife@3", "equipped", "weapon")
	await _save(main, "whetstone-equipped-max")
	main.state.loadout["weapon"] = "bone_knife@1"
	main.state.resources = {"wood": 0, "stone": 0, "cloth": 0}
	main.inventory_panel.select_item("bone_knife@1", "equipped", "weapon")
	main.inventory_panel.refresh()
	await _save(main, "whetstone-no-resources")
	main._close_inventory_service()
	main.state.banked_souls = 75
	main.state.add_item("bone_bow", 2)
	main._open_inventory_service("ritual_table")
	main.inventory_panel.select_item("bone_bow@2", "inventory")
	await _save(main, "ritual-bind-ready")
	main._on_inventory_bind_pressed()
	await _save(main, "ritual-bound")
	main._close_inventory_service()
	main._show_story("death", "")
	await _save(main, "death-continuity")
	main.queue_free()
	quit(0)


func _save(main, kind: String) -> void:
	main.queue_redraw()
	await process_frame
	await process_frame
	var viewport_size := root.size
	var path := "res://builds/previews/inventory-%s-%dx%d-%s.png" % [
		locale, viewport_size.x, viewport_size.y, kind,
	]
	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("Empty inventory preview image for %s" % kind)
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save inventory preview to %s (error %d)" % [path, error])
