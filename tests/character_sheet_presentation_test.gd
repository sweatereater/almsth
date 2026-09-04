extends RefCounted

const Artwork := preload("res://scripts/ui/character_artwork.gd")
const Layout := preload("res://scripts/ui/character_sheet_layout.gd")
const Surface := preload("res://scripts/ui/character_sheet_surface.gd")
const Loc := preload("res://scripts/localization/localization.gd")
var failures: Array[String] = []

func run(tree: SceneTree) -> Array[String]:
	Artwork.prepare_sheet()
	Surface.prepare()
	var state := RunState.new()
	for sex in Artwork.SEXES:
		state.character_sex = sex
		var span := -1.0
		for form in Artwork.FORMS:
			state.current_form_id = form
			var placement := Artwork.sheet_placement(state)
			var source := "res://art/characters/sex-selection/cutouts/%s/%s.png" % [sex, form.replace("_", "-")]
			_expect(FileAccess.get_sha256(Artwork.body_path(sex, form)) == FileAccess.get_sha256(source), "Native source pixels must be unchanged: %s/%s" % [sex, form])
			_expect(placement.source == Rect2(placement.texture.get_image().get_used_rect()), "Portrait fit must include every alpha pixel")
			_expect(Layout.FIGURE_RECT.grow(-3.99).encloses(placement.destination), "Whole portrait must retain 4px niche clearance: %s/%s" % [sex, form])
			_expect(placement.destination.size.y >= 470.0, "Native portrait must dominate sheet height: %s/%s (%s)" % [sex, form, placement.destination.size])
			_expect(is_equal_approx(placement.destination.size.aspect(), placement.source.size.aspect()), "Portrait must preserve aspect ratio")
			_expect(placement.anchor.y == 620 and (span < 0 or is_equal_approx(span, placement.eye_to_foot)), "Forms must share anatomical scale and foot baseline per sex")
			span = placement.eye_to_foot
			var import_text := FileAccess.get_file_as_string(Artwork.body_path(sex, form) + ".import")
			_expect(import_text.contains("compress/mode=0") and import_text.contains("mipmaps/generate=false") and import_text.contains("process/size_limit=0"), "Native sheet import must retain lossless detail without mipmaps/size limit")
	var ids := []
	for material in Surface.materials.values():
		ids.append(material.get_instance_id())
	Surface.prepare()
	var after := []
	for material in Surface.materials.values():
		after.append(material.get_instance_id())
	_expect(ids == after and Artwork.sheet_placements.size() == 10, "Sheet resources must remain cached at a bounded cardinality")
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.configure_character("Ньюб", GameRules.default_attributes())
	main.state.current_form_id = "almost_human"
	main.state.highest_unlocked_form_index = 4
	main.state.skill_levels.stomach = 1
	main.state.unspent_attribute_points = 5
	main.state.add_or_refresh_status("rested", 321, 5)
	main.state.add_or_refresh_status("satiated", 200, 3)
	main._show_base("", "none")
	main._show_character()
	main._select_character_panel("inventory")
	main.set_process(false)
	for locale in ["ru", "en"]:
		Loc.set_locale(locale)
		main._apply_locale()
		await tree.process_frame
		for label in [main.character_primary_label, main.character_parameters_label, main.character_soul_level_label, main.character_attribute_points_label, main.character_derived_label]:
			_expect(label.visible and label.get_theme_font_size("font_size") >= 12, "Essential sheet labels must remain visible at >=12px")
			_expect(label.get_line_count() <= label.get_visible_line_count(), "Whole localized label must be visible in %s: %s" % [locale, label.text])
			for line in label.text.split("\n"):
				_expect(label.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x, "Localized line must fit the narrow stats column: %s / %s" % [locale, line])
		_expect(main.character_soul_level_label.text.split("\n").size() == 3 and main.character_soul_level_label.text.contains(Loc.text("FORM_ALMOST_HUMAN")), "Soul/form/appearance must show all three complete localized lines")
		_expect(main.character_status_strip.status_snapshot.size() == 2, "Both survival status chips remain present")
	main.queue_free()
	await tree.process_frame
	Loc.set_locale("ru")
	return failures

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
