extends RefCounted

const Artwork := preload("res://scripts/ui/character_artwork.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const Saves := preload("res://scripts/system/persistence.gd")
const TEST_ROOT := "res://.tmp/nightly/character-sex-tests"
var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	_remove_tree(TEST_ROOT)
	_test_state()
	await _test_creation_and_files(tree)
	_remove_tree(TEST_ROOT)
	return failures


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _test_state() -> void:
	for locale in ["ru", "en"]:
		Loc.set_locale(locale)
		var hint := Loc.text("SEX_CHOICE_HINT", [Loc.text("SEX_MALE")])
		_expect(
			hint.contains("карте") if locale == "ru" else hint.contains("map"),
			"Sex-choice hint must explain the sex×form map-art matrix in %s" % locale,
		)
	Loc.set_locale("ru")
	for sex in Artwork.SEXES:
		var head := Artwork.texture(Artwork.head_path(sex))
		_expect(head != null and head.get_size() == Vector2(264, 264), "Creation must have the new %s head at 264x264" % sex)
		var state := RunState.new()
		state.character_sex = sex
		state.configure_character("Test", GameRules.default_attributes())
		var restored := RunState.new()
		_expect(restored.restore_save_data(state.to_save_data()) and restored.character_sex == sex, "State-only save must retain %s" % sex)
		var snapshot := state.to_snapshot_data()
		_expect(restored.restore_snapshot_data(snapshot) and restored.to_snapshot_data() == snapshot, "Exact snapshot must retain %s without changing gameplay" % sex)
		for form in Artwork.FORMS:
			state.current_form_id = form
			state.highest_unlocked_form_index = 4
			state.display_form_id = ""
			var body := Artwork.body(state)
			_expect(body != null and body.resource_path == Artwork.body_path(sex, form), "Sheet must resolve %s/%s" % [sex, form])
			if body != null:
				var pixels := body.get_image()
				var bounds := pixels.get_used_rect()
				_expect(body.get_height() >= 817 and pixels.detect_alpha() != Image.ALPHA_NONE, "Sheet figure must use native transparent detail: %s/%s" % [sex, form])
				_expect(bounds.has_area() and bounds.size.y > 790, "Native complete silhouette must remain available: %s/%s" % [sex, form])
			_expect(
				Renderer.player_visual_form_id(state) == form,
				"Form ID must remain the form dimension of the parallel sex×form map set",
			)
		state.skill_levels.choose_appearance = 1
		state.display_form_id = "zombie"
		var override_body := Artwork.body(state)
		_expect(override_body != null and override_body.resource_path == Artwork.body_path(sex, "zombie"), "Cosmetic override must stay within %s set" % sex)
		state.die()
		_expect(state.character_sex == sex and state.current_form_id == "skeleton", "Death resets body but retains %s" % sex)
	var legacy := RunState.new()
	legacy.configure_character("Legacy", GameRules.default_attributes())
	var data := legacy.to_snapshot_data()
	data.erase("character_sex")
	var restored := RunState.new()
	restored.character_sex = "female"
	var before_missing := restored.to_snapshot_data()
	_expect(
		not restored.restore_snapshot_data(data) and restored.to_snapshot_data() == before_missing,
		"Current snapshots without character sex must reject without mutation",
	)
	for invalid in ["unknown", "", 1, null, true, [], {}]:
		data.character_sex = invalid
		var before := restored.to_snapshot_data()
		_expect(not restored.restore_snapshot_data(data) and restored.to_snapshot_data() == before, "Invalid present sex must reject full snapshot without mutation: %s" % str(invalid))
		var soft := legacy.to_save_data()
		soft.character_sex = invalid
		before = restored.to_snapshot_data()
		_expect(
			not restored.restore_save_data(soft) and restored.to_snapshot_data() == before,
			"State restore must reject invalid cosmetic identity without mutation",
		)
	data.erase("character_sex")
	data.erase("hp")
	_expect(not RunState.is_snapshot_data_valid(data), "Sex migration must not excuse other missing fields")


func _test_creation_and_files(tree: SceneTree) -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	main.settings_path = TEST_ROOT.path_join("settings.cfg")
	main.save_slots_directory = TEST_ROOT.path_join("saves")
	main.legacy_save_path = TEST_ROOT.path_join("missing.json")
	tree.root.add_child(main)
	await tree.process_frame
	main._show_name_creation()
	_expect(main.title_label.visible and main.title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Name creation needs the centered Stage 1C heading")
	_expect(
		not main.sex_choice_panel.labels.female.visible
		and not main.sex_choice_panel.labels.male.visible
		and main.sex_choice_panel.selection_markers.female.visible
		and not main.sex_choice_panel.selection_markers.male.visible,
		"Portrait-only selector starts female with one non-color selection marker",
	)
	for sex in Artwork.SEXES:
		var button: Button = main.sex_choice_panel.buttons[sex]
		var portrait := button.get_child(0) as TextureRect
		_expect(button.size == Vector2(156, 160), "%s sex card must stay exactly 156x160" % sex)
		_expect(portrait != null and portrait.size == Vector2(120, 120), "%s portrait must stay exactly 120x120" % sex)
		_expect(not String(button.accessibility_name).is_empty() and not String(button.accessibility_description).is_empty(), "%s card needs an accessibility name and description" % sex)
	_expect(main.sex_choice_panel.buttons.male.position.x - main.sex_choice_panel.buttons.female.position.x == 176.0, "Sex cards need their exact 20 px gap")
	# Physical B/Back opens the blocking warm menu from creation and resume returns
	# to the exact unfinished creation state.
	await _joy(tree, JOY_BUTTON_B)
	_expect(main.main_menu_open and main.save_menu_panel.visible, "Gamepad B must back out from name/sex creation")
	main._resume_from_main_menu()
	_expect(main.screen == main.Screen.NAME_CREATION and not main.main_menu_open, "Resume must restore name/sex creation")
	# Pointer and touch activate the real cards, not test-only state hooks.
	await _mouse_click(tree, main.sex_choice_panel.buttons.female.get_global_rect().get_center())
	_expect(main.state.character_sex == "female", "Mouse click must select Female")
	await _touch(tree, main.sex_choice_panel.buttons.male.get_global_rect().get_center())
	_expect(main.state.character_sex == "male", "Touch tap must select Male")
	main.sex_choice_panel.buttons.female.grab_focus()
	await _key(tree, KEY_RIGHT)
	await _key(tree, KEY_ENTER)
	_expect(main.state.character_sex == "male", "Keyboard navigation + accept must select Male")
	await _joy(tree, JOY_BUTTON_DPAD_UP)
	await _joy(tree, JOY_BUTTON_DPAD_LEFT)
	await _joy(tree, JOY_BUTTON_A)
	_expect(main.state.character_sex == "female" and main.sex_choice_panel.selected_sex == "female" and main.sex_choice_panel.selection_markers.female.visible, "Native D-pad + A must select Female")
	await _joy(tree, JOY_BUTTON_A)
	_expect(main.sex_choice_panel.selection_markers.female.visible and not main.sex_choice_panel.selection_markers.male.visible, "Repeated gamepad confirm must keep exactly one sex selected")
	await _joy(tree, JOY_BUTTON_DPAD_RIGHT)
	await _joy(tree, JOY_BUTTON_A)
	_expect(main.state.character_sex == "male", "Native D-pad + A must select Male")
	main.save_policy_checkbox.grab_focus()
	var policy: bool = main.save_policy_checkbox.button_pressed
	await _joy(tree, JOY_BUTTON_A)
	_expect(main.save_policy_checkbox.button_pressed != policy, "Gamepad A must toggle the save policy")
	for key in [KEY_ENTER, KEY_SPACE]:
		policy = main.save_policy_checkbox.button_pressed
		await _key(tree, key)
		_expect(main.save_policy_checkbox.button_pressed != policy, "Native keyboard accept must toggle save policy exactly once")
	main.name_input.text = "Gamepad"
	main.name_confirm_button.grab_focus()
	await _joy(tree, JOY_BUTTON_A)
	_expect(main.screen == main.Screen.STAT_CREATION, "Gamepad A on Continue must submit the name")
	_expect(main.title_label.visible and main.creation_back_button.visible, "Attribute creation needs the centered title and stable Back control")
	_expect(
		main.creation_preview_label.text == Loc.text("SKELETON_PARAMETERS"),
		"The derived-stat block must use the localized Parameters heading",
	)
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		_expect(main.attribute_minus_buttons[attribute_id].name == "StatMinus_%s" % attribute_id, "Minus needs a stable name: %s" % attribute_id)
		_expect(main.attribute_plus_buttons[attribute_id].name == "StatPlus_%s" % attribute_id, "Plus needs a stable name: %s" % attribute_id)
		_expect(main.attribute_minus_buttons[attribute_id].disabled, "Minus must disable at its starting bound: %s" % attribute_id)
	_expect(main.creation_confirm_button.disabled, "Finish must disable while points remain")
	var first_attribute: String = GameRules.ATTRIBUTE_ORDER[0]
	main.attribute_plus_buttons[first_attribute].grab_focus()
	await _joy(tree, JOY_BUTTON_A)
	_expect(
		not main.attribute_minus_buttons[first_attribute].disabled
		and int(main.attribute_value_labels[first_attribute].text) > GameRules.STARTING_ATTRIBUTE_VALUE,
		"Gamepad A on plus must increase value text without requiring color marker",
	)
	await _joy(tree, JOY_BUTTON_B)
	_expect(
		main.screen == main.Screen.NAME_CREATION
		and main.name_input.text == "Gamepad"
		and int(main.pending_attributes[first_attribute]) == GameRules.STARTING_ATTRIBUTE_VALUE + 1,
		"Gamepad B/Back must preserve name and pending allocation",
	)
	main._on_name_confirmed()
	_expect(main.screen == main.Screen.STAT_CREATION, "Preserved creation data must return to the stat step")
	for sex in Artwork.SEXES:
		main._reset_for_new_character()
		main._show_name_creation()
		_expect(main.state.character_sex == "female", "New Game starts with female default")
		main.sex_choice_panel.buttons[sex].pressed.emit()
		_expect(main.state.character_sex == sex, "Creation button must set %s" % sex)
		for locale in ["ru", "en"]:
			Loc.set_locale(locale)
			main._apply_locale()
			_expect(main.sex_choice_panel.selected_sex == sex, "Locale change must retain sex")
		main.name_input.text = ""
		main._on_name_confirmed()
		_expect(main.screen == main.Screen.NAME_CREATION, "Empty name must not leave creation")
		main.name_input.text = "Creation " + sex
		main._on_name_confirmed()
		_expect(main.screen == main.Screen.STAT_CREATION and not main.sex_choice_panel.visible, "Sex selector hides during attribute creation")
		main.pending_attributes.strength += main.free_attribute_points
		main.free_attribute_points = 0
		main._on_attributes_confirmed()
		_expect(main.state.character_sex == sex and main.screen == main.Screen.STORY, "Final creation must retain sex")
		while main.screen == main.Screen.STORY:
			main._advance_story()
		main.persistence_enabled = true
		_expect(main._save_game_at_base("create"), "Full save must be written for %s" % sex)
		var slot: String = main.active_save_slot_id
		main.state.character_sex = "female" if sex == "male" else "male"
		main._on_save_slot_load_requested(slot)
		_expect(main.state.character_sex == sex, "Full file reload must restore selected sex")
		# An unsupported v16 family must remain visible/locked, never be migrated in place.
		var file_path: String = main.save_slots_directory.path_join(slot + ".json")
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file_path))
		raw.version = 16
		raw.state.erase("character_sex")
		var file := FileAccess.open(file_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(raw, "", false, true))
		file.close()
		var loaded := Saves.load_slot(slot, main.save_slots_directory)
		_expect(
			not bool(loaded.get("ok", false))
			and int(loaded.get("error", OK)) == ERR_FILE_CORRUPT,
			"Standalone v16 without sex must reject below the supported v17-v18 boundary",
		)
		var locked_row := {}
		for row in Saves.list_slots(main.save_slots_directory):
			if row.slot_id == slot:
				locked_row = row
		_expect(
			not locked_row.is_empty() and bool(locked_row.get("locked", false)),
			"Unsupported v16 family must remain visible as a locked deletable row",
		)
		main.persistence_enabled = false
	Loc.set_locale("ru")
	main.queue_free()
	await tree.process_frame


func _joy(tree: SceneTree, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	tree.root.push_input(event, true)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	tree.root.push_input(event, true)
	await tree.process_frame


func _key(tree: SceneTree, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	tree.root.push_input(event, true)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	tree.root.push_input(event, true)
	await tree.process_frame


func _mouse_click(tree: SceneTree, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = true
	tree.root.push_input(event, true)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	tree.root.push_input(event, true)
	await tree.process_frame


func _touch(tree: SceneTree, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = true
	tree.root.push_input(event, true)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	tree.root.push_input(event, true)
	await tree.process_frame


func _remove_tree(path: String) -> void:
	assert(path == TEST_ROOT or path.begins_with(TEST_ROOT + "/"), "Character-sex cleanup escaped its fixed nightly root")
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)
