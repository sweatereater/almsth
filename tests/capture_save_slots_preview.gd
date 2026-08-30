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
	main.screen = main.Screen.STARTUP
	main._hide_game_interface()
	main.title_label.visible = false
	main.menu_button.visible = false
	var preview_slots: Array[Dictionary] = [
		{"slot_id": "newest", "updated_at": 1788012300, "character_name": "Aldren of the Last Quiet Passage", "lifetime_souls_earned": 9999, "save_policy": "overwrite"},
	]
	for index in range(1, 8):
		preview_slots.append({
			"slot_id": "older-%d" % index,
			"updated_at": 1788012300 - index * 86400,
			"character_name": "Chronicle Wanderer With A Long Name %d" % index,
			"lifetime_souls_earned": 9999 - index,
			"save_policy": "history",
		})
	main.save_menu_panel.set_slots(preview_slots)
	main.save_menu_panel.set_active_slot_id("newest")
	main.save_menu_panel.show_startup()
	await _save("startup")
	main.save_menu_panel.show_load_list()
	await _save("delete-list-long")
	main.save_menu_panel.trash_buttons[0].grab_focus()
	var hover := InputEventMouseMotion.new()
	hover.position = main.save_menu_panel.trash_buttons[0].get_global_rect().get_center()
	root.push_input(hover, true)
	await _save("delete-trash-hover-focus")
	main.save_menu_panel.set_active_slot_id("newest")
	main.save_menu_panel.trash_buttons[0].pressed.emit()
	if not main.save_menu_panel.delete_modal_body.text.contains(Loc.text("SAVE_MENU_DELETE_ACTIVE_WARNING")):
		push_error("Active deletion preview warning missing: active=%s pending=%s" % [
			main.save_menu_panel.active_slot_id, main.save_menu_panel.pending_delete_slot_id,
		])
	await _save("delete-modal-cancel-focus")
	main.save_menu_panel.delete_yes_button.grab_focus()
	await _save("delete-modal-confirm-focus")
	main.save_menu_panel._cancel_delete_modal(false)
	main.save_menu_panel.show_load_list()
	main.save_menu_panel._open_delete_modal(0)
	main.save_menu_panel.complete_delete({"ok": true}, _without_index(preview_slots, 0))
	await _save("delete-after")
	var one_slot: Array[Dictionary] = [preview_slots[0].duplicate(true)]
	main.save_menu_panel.set_slots(one_slot)
	main.save_menu_panel.show_load_list()
	main.save_menu_panel._open_delete_modal(0)
	var no_slots: Array[Dictionary] = []
	main.save_menu_panel.complete_delete({"ok": true}, no_slots)
	await _save("delete-last-empty")
	var seven_slots := _without_index(preview_slots, 7)
	main.save_menu_panel.set_slots(seven_slots)
	main.save_menu_panel.show_load_list()
	main.save_menu_panel._change_page(1)
	main.save_menu_panel._open_delete_modal(6)
	main.save_menu_panel.complete_delete({"ok": true}, _without_index(seven_slots, 6))
	await _save("delete-page-clamp")
	main.save_menu_panel.set_slots(preview_slots)
	main.save_menu_panel.show_load_list()
	main.save_menu_panel._open_delete_modal(0)
	main.save_menu_panel.complete_delete(
		{"ok": false, "error": ERR_CANT_CREATE}, preview_slots,
		Loc.text("SAVE_MENU_DELETE_ERROR", [ERR_CANT_CREATE]),
	)
	await _save("delete-error")
	main.save_menu_panel.close()
	main._reset_for_new_character()
	main._show_name_creation()
	await _save("name-policy")
	main.queue_free()
	quit(0)


func _without_index(source: Array[Dictionary], removed_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(source.size()):
		if index != removed_index:
			result.append(source[index].duplicate(true))
	return result


func _save(kind: String) -> void:
	await process_frame
	await process_frame
	var viewport_size := root.size
	var path := "res://builds/previews/save-slots-%s-%dx%d-%s.png" % [
		locale, viewport_size.x, viewport_size.y, kind,
	]
	var image := root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(path)
