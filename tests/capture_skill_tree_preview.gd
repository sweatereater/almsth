extends SceneTree

## Deterministic body-skill tree visual QA. Run with a normal renderer.
const Loc := preload("res://scripts/localization/localization.gd")
const IconClass := preload("res://scripts/ui/skill_tree_icon.gd")

const VIEWPORTS := [Vector2i(1280, 720), Vector2i(960, 540)]
const LOCALES := ["ru", "en"]
const STAGES := ["skeleton", "zombie", "ghoul", "revenant", "almost_human"]
const ZOOMS := [44, 66, 88]

var output := "res://art/reviews/body-skills/2026-09-01/ui"
var captures: Array[Dictionary] = []
var failures: Array[String] = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	main.settings_path = output.path_join("unused-settings.cfg")
	root.add_child(main)
	await process_frame
	main.set_process(false)

	for viewport_size in VIEWPORTS:
		await _set_viewport_size(viewport_size)
		for locale in LOCALES:
			for stage_id in STAGES:
				await _configure_stage(main, stage_id, locale)
				await _save(main, "matrix", {
					"locale": locale, "stage": stage_id,
					"viewport": [viewport_size.x, viewport_size.y],
				})

			await _configure_stage(main, "ghoul", locale)
			var zoom_hashes := PackedStringArray()
			for zoom in ZOOMS:
				main.set_dungeon_cell_size(zoom)
				var zoom_path := await _save(main, "zoom", {
					"locale": locale, "stage": "ghoul", "zoom": zoom,
					"viewport": [viewport_size.x, viewport_size.y],
				})
				if not zoom_path.is_empty():
					zoom_hashes.append(FileAccess.get_sha256(zoom_path))
			if zoom_hashes.size() != 3 or zoom_hashes[0] != zoom_hashes[1] or zoom_hashes[1] != zoom_hashes[2]:
				failures.append("Ghoul Character Sheet changed between dungeon zooms for %s at %s" % [locale, viewport_size])

	main.visible = false
	await _set_viewport_size(Vector2i(1280, 720))
	await _capture_state_sheet()
	_write_manifest()
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("BODY SKILL PREVIEW: %d captures, %d failures" % [captures.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)


func _configure_stage(main, stage_id: String, locale: String) -> void:
	Loc.set_locale(locale)
	main.state = _fixture(stage_id, locale)
	main._show_base("", "none")
	main._show_character()
	main._select_character_panel("skills")
	main._apply_locale()
	if stage_id == "revenant":
		# Locked content remains inspectable without granting its tab or skill.
		main.selected_skill_stage = stage_id
		main.skill_tree_panel.set_context(main.state, stage_id)
	else:
		main._select_skill_stage(stage_id)
	var selected_id := _selected_id(stage_id)
	main._on_skill_pressed(selected_id)
	var focus_id := _focus_id(stage_id)
	if main.skill_node_buttons.has(focus_id):
		main.skill_node_buttons[focus_id].grab_focus()
	main._refresh_character_sheet()
	await process_frame


func _fixture(stage_id: String, locale: String) -> RunState:
	var state := RunState.new()
	state.configure_character("Собирательница душ" if locale == "ru" else "Soul Collector", GameRules.default_attributes())
	state.current_form_id = stage_id
	state.absorbed_souls = int(GameRules.FORMS[stage_id]["threshold"])
	state.highest_unlocked_form_index = GameRules.FORM_ORDER.size() - 1
	state.carried_souls = 217
	state.banked_souls = 183
	state.unspent_attribute_points = 5
	match stage_id:
		"skeleton":
			state.skill_levels["strong_bones"] = 1
		"zombie":
			state.skill_levels["muscle_fibers"] = 1
		"ghoul":
			state.skill_levels["stomach"] = 1
		"revenant":
			state.current_form_id = "ghoul"
			state.absorbed_souls = int(GameRules.FORMS["ghoul"]["threshold"])
			state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("ghoul")
		"almost_human":
			state.skill_levels["choose_appearance"] = 1
	state.hp = state.get_max_hp()
	state.mana = state.get_max_mana()
	return state


func _selected_id(stage_id: String) -> String:
	match stage_id:
		"skeleton": return "strong_bones"
		"zombie": return "muscle_fibers"
		"ghoul": return "flesh_regeneration"
		"revenant": return "nervous_system"
	return "fundamentals"


func _focus_id(stage_id: String) -> String:
	match stage_id:
		"skeleton": return "strong_spine"
		"zombie": return "sharp_vision"
		"ghoul": return "ears"
		"revenant": return "nervous_system"
	return "choose_appearance"


func _capture_state_sheet() -> void:
	var sheet := Control.new()
	sheet.name = "BodySkillStateSheet"
	sheet.size = Vector2(1280, 720)
	root.add_child(sheet)
	var background := ColorRect.new()
	background.color = Color("111720")
	background.size = sheet.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(background)
	_add_label(sheet, Rect2(24, 14, 1232, 30), "Body raster states · 54×54 nodes · 64×64 detail", 20, HORIZONTAL_ALIGNMENT_CENTER)
	var columns := ["locked", "available", "learned", "max", "selected", "focused", "detail 64"]
	for column in range(columns.size()):
		_add_label(sheet, Rect2(220 + column * 142, 50, 120, 24), columns[column], 13, HORIZONTAL_ALIGNMENT_CENTER)
	var rows := [
		["sharp_vision", "Sharp Vision"],
		["ears", "Ears"],
		["flesh_regeneration", "Circulation"],
		["nervous_system", "Nervous System"],
		["strong_bones", "Strong Bones 1/5"],
		["strong_bones", "Strong Bones 5/5"],
	]
	var focused_icon = null
	for row in range(rows.size()):
		var y := 82 + row * 101
		_add_label(sheet, Rect2(20, y + 18, 184, 40), rows[row][1], 14, HORIZONTAL_ALIGNMENT_RIGHT)
		for column in range(6):
			var icon := IconClass.new()
			icon.position = Vector2(232 + column * 142, y)
			icon.size = Vector2(96, 76)
			sheet.add_child(icon)
			var state_name := String(columns[column])
			if state_name in ["selected", "focused"]:
				state_name = "learned" if row == 4 else ("max" if row == 5 else "available")
			icon.set_presentation(rows[row][0], rows[row][1], "passive", state_name, column == 4)
			if column == 5 and row == 3:
				focused_icon = icon
		var detail := IconClass.new()
		detail.position = Vector2(1082, y + 6)
		detail.size = Vector2(64, 64)
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.focus_mode = Control.FOCUS_NONE
		sheet.add_child(detail)
		detail.set_presentation(rows[row][0], rows[row][1], "passive", "available", false, false, true)
	if focused_icon != null:
		focused_icon.grab_focus()
	await process_frame
	await _save_control(sheet, "state-sheet", {"viewport": [1280, 720]})
	sheet.queue_free()
	await process_frame


func _add_label(parent: Control, rect: Rect2, text_value: String, size_value: int, alignment: HorizontalAlignment) -> void:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", Color("e6e2d8"))
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _set_viewport_size(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	await process_frame
	await process_frame


func _save(main, category: String, metadata: Dictionary) -> String:
	main._refresh_interface()
	main.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return _save_image(root.get_texture().get_image(), category, metadata)


func _save_control(control: Control, category: String, metadata: Dictionary) -> String:
	control.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return _save_image(root.get_texture().get_image(), category, metadata)


func _save_image(image: Image, category: String, metadata: Dictionary) -> String:
	var viewport: Array = metadata.get("viewport", [root.size.x, root.size.y])
	var suffix := ""
	if category == "matrix":
		suffix = "%s-%dx%d-%s" % [metadata["locale"], viewport[0], viewport[1], metadata["stage"]]
	elif category == "zoom":
		suffix = "%s-%dx%d-ghoul-z%d" % [metadata["locale"], viewport[0], viewport[1], metadata["zoom"]]
	else:
		suffix = "1280x720"
	var path := output.path_join("%s-%s.png" % [category, suffix])
	if image == null or image.is_empty():
		failures.append("Normal-renderer capture is empty: %s" % path)
		return ""
	if image.get_size() != Vector2i(int(viewport[0]), int(viewport[1])):
		failures.append("Capture size mismatch for %s: %s" % [path, image.get_size()])
	if image.save_png(path) != OK:
		failures.append("Could not save capture: %s" % path)
		return ""
	var record := metadata.duplicate(true)
	record["category"] = category
	record["path"] = path.trim_prefix("res://")
	record["sha256"] = FileAccess.get_sha256(path)
	captures.append(record)
	print("BODY SKILL PREVIEW: %s" % path)
	return path


func _write_manifest() -> void:
	var manifest_path := output.path_join("manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write body-skill preview manifest: %s" % manifest_path)
		return
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"normal_renderer_required": true,
		"matrix_contract": "5 stages x RU/EN x 1280x720/960x540",
		"zoom_contract": "Ghoul Character Sheet pixel-identical at dungeon zoom 44/66/88",
		"captures": captures,
	}, "  ", false, true) + "\n")
