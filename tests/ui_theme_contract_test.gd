class_name UiThemeContractTestSuite
extends RefCounted

const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const MainScene := preload("res://scripts/main.gd")
const GameRules := preload("res://scripts/game/game_rules.gd")
const InputProfile := preload("res://scripts/system/input_bindings.gd")
const BaseLayout := preload("res://scripts/ui/base_layout.gd")

const EXPECTED := {
	Palette.WARM_ARCHIVE: {
		"background": "100f0d", "panel": "2a251e", "inset": "18140f", "raised": "342e25",
		"primary": "f2e8d4", "secondary": "baab91", "neutral_border": "806f53",
		"selected_fill": "263b35", "soul": "67cdc5", "focus": "e1b965",
		"copper": "a96d4c", "danger": "d87568", "disabled": "847a6b",
		"disabled_text_contrast": "a49784", "danger_surface": "38231f",
	},
	Palette.COLD_DUNGEON: {
		"background": "070c11", "panel": "142733", "inset": "0d161f", "raised": "18303a",
		"primary": "e9f1ef", "secondary": "9ab0b5", "neutral_border": "557d91",
		"selected_fill": "123b3a", "soul": "55e0d4", "focus": "ffd078",
		"magic": "aa96d5", "danger": "ff7b72", "disabled": "70838b",
		"disabled_text_contrast": "8298a0", "danger_surface": "392224",
	},
}

const FONT_HASHES := {
	"res://assets/fonts/noto-sans/NotoSans-Regular.ttf": "f5f552c8c5edb61fe6efb824baf4d4de47b1a8689ab4925ff43f7bd6a4ebece5",
	"res://assets/fonts/noto-sans/NotoSans-Medium.ttf": "1d1570dd66d70cbcd56646c55580c3cc453c7abc505534230c165f93b55ad394",
	"res://assets/fonts/noto-sans/NotoSans-SemiBold.ttf": "bfcab863fec70318e9af8ead5266176a5231a77e693dacfc10f572754f9463a6",
	"res://assets/fonts/cormorant-garamond/CormorantGaramond-SemiBold.ttf": "dc4bc094dc3c55cf79ff2f6f0ba1e501b712fc3cf3742296cd8fdcc6e995127d",
	"res://assets/fonts/ui-symbols/stage1c-ui-symbols.svg": "58c93cbe73e6657fb5018c0ad2c5d2d76acffd9e04cd77110b7cd0ad458436e7",
	"res://assets/fonts/ui-symbols/stage1c-ui-symbols.fnt": "22c9059256e6f4690af133c775b4bf1295397fde6919d718559c932931911ef7",
}

const PREVIEW_SCENARIOS := [
	"startup-ready", "startup-from-game",
	"sex-female-selected-male-focus", "sex-male-selected-female-focus",
	"stat-lower-bounds-focus", "stat-upper-changed-finish",
	"base-materials-max-values-focus",
	"character-long-name-max-values", "character-active-statuses-focus",
	"settings-boundaries-focus", "settings-slider-focus",
	"remap-normal", "remap-capture", "remap-conflict-danger", "remap-reset-danger",
	"remap-reset-danger-hover", "remap-reset-danger-pressed",
	"save-mixed-v18-v17-v16-corrupt", "save-diagnostic-error-16",
	"save-delete-no-default-focus", "save-delete-yes-danger-focus",
	"save-delete-failure-restores-trash",
	"storage-populated", "storage-empty", "storage-over-built-camp",
	"dungeon-menu-warm-over-cold", "dungeon-settings-warm-over-cold",
	"overlay-separation-z44", "overlay-separation-z66", "overlay-separation-z88",
	"dungeon-character-warm-shell", "dungeon-character-context-restored",
	"state-sheet-warm_archive", "state-sheet-cold_dungeon",
	"inventory-all-page1-marks-focus",
	"inventory-weapons-page2-long-bound-upgraded",
	"inventory-offhand-two-handed-ghost", "inventory-offhand-conflict-resolved",
	"inventory-armor-populated", "inventory-accessories-populated",
	"inventory-backpack-populated", "inventory-empty-disabled-actions",
	"skill-skeleton-mixed-states-focus", "skill-ghoul-three-branches-selected",
	"skill-revenant-locked-inspection", "skill-almost-human-loadout-max",
	"skill-state-sheet", "skill-all-icons",
	"dungeon-cold-hud-resources-history-z44",
	"dungeon-cold-hud-resources-history-z66",
	"dungeon-cold-hud-resources-history-z88",
	"dungeon-inventory-warm-over-cold-z44", "dungeon-skills-warm-over-cold-z44",
	"dungeon-inventory-warm-over-cold-z66", "dungeon-skills-warm-over-cold-z66",
	"dungeon-inventory-warm-over-cold-z88", "dungeon-skills-warm-over-cold-z88",
]

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	_test_exact_tokens_and_contrast()
	_test_resource_cache_and_states()
	_test_fonts_and_localized_glyphs()
	_test_portrait_and_protected_assets()
	_test_preview_manifest()
	await _test_real_controls_and_context(tree)
	_test_source_boundaries()
	return failures


func _test_exact_tokens_and_contrast() -> void:
	for context in EXPECTED:
		for role in EXPECTED[context]:
			_expect(
				Palette.color(context, role).to_html(false) == EXPECTED[context][role],
				"Exact %s/%s token changed" % [context, role],
			)
	var warm_mix := Palette.color(Palette.WARM_ARCHIVE, "background").lerp(
		Palette.color(Palette.WARM_ARCHIVE, "danger"), 0.2,
	)
	var cold_mix := Palette.color(Palette.COLD_DUNGEON, "background").lerp(
		Palette.color(Palette.COLD_DUNGEON, "danger"), 0.2,
	)
	_expect(warm_mix.to_html(false) == "38231f", "Warm danger surface must be exact 20% sRGB composition")
	_expect(cold_mix.to_html(false) == "392224", "Cold danger surface must be exact 20% sRGB composition")
	_expect(_contrast(Color("a49784"), Color("2a251e")) >= 5.30, "Warm disabled text contrast regressed")
	_expect(_contrast(Color("a49784"), Color("342e25")) >= 4.68, "Warm raised disabled contrast regressed")
	_expect(_contrast(Color("8298a0"), Color("142733")) >= 5.07, "Cold disabled text contrast regressed")
	_expect(_contrast(Color("8298a0"), Color("18303a")) >= 4.55, "Cold raised disabled contrast regressed")
	_expect(Palette.OVERLAY_SCRIM.r == Palette.OVERLAY_SCRIM.g and Palette.OVERLAY_SCRIM.g == Palette.OVERLAY_SCRIM.b, "Overlay scrim must be neutral/equal-channel")


func _test_resource_cache_and_states() -> void:
	for context in EXPECTED:
		var theme_a := ThemeController.theme_for(context)
		var theme_b := ThemeController.theme_for(context)
		_expect(theme_a.get_instance_id() == theme_b.get_instance_id(), "Theme cache must return one instance for %s" % context)
		for state in ["normal", "hover", "selected", "selected_hover", "focus", "disabled"]:
			var style_a := ThemeController.style_for(context, "button", state)
			var style_b := ThemeController.style_for(context, "button", state)
			_expect(style_a.get_instance_id() == style_b.get_instance_id(), "Style cache identity failed: %s/%s" % [context, state])
		var normal := ThemeController.style_for(context, "button", "normal")
		var hover := ThemeController.style_for(context, "button", "hover")
		var selected := ThemeController.style_for(context, "button", "selected")
		var focus := ThemeController.style_for(context, "button", "focus")
		var disabled := ThemeController.style_for(context, "button", "disabled")
		var danger := ThemeController.style_for(context, "danger", "normal")
		var danger_hover := ThemeController.style_for(context, "danger", "hover")
		var danger_pressed := ThemeController.style_for(context, "danger", "pressed")
		var danger_hover_pressed := ThemeController.style_for(context, "danger", "hover_pressed")
		_expect(normal.border_width_left == 1 and hover.border_width_left == 2, "Normal/hover geometry must differ")
		_expect(selected.border_width_left >= 5 and selected.border_color == Palette.color(context, "soul"), "Selected state needs soul border and non-color marker")
		_expect(focus.bg_color.a == 0.0 and focus.border_width_left == 3 and focus.expand_margin_left >= 4.0, "Focus must be a separated external gold outline")
		_expect(focus.border_color == Palette.color(context, "focus"), "Focus outline token mismatch")
		_expect(disabled.corner_radius_top_left == 0 and disabled.border_color == Palette.color(context, "disabled"), "Disabled state must be visibly depressed")
		_expect(danger.bg_color == Palette.color(context, "danger_surface") and danger.border_width_left >= 5, "Danger needs measured surface and marker")
		for danger_state in [danger, danger_hover, danger_pressed, danger_hover_pressed]:
			_expect(
				danger_state.bg_color == Palette.color(context, "danger_surface")
				and danger_state.border_color == Palette.color(context, "danger")
				and danger_state.border_color != Palette.color(context, "soul"),
				"Danger normal/hover/pressed must retain danger identity without teal",
			)
		_expect(
			danger.border_width_top == 2
			and danger_hover.border_width_top == 3
			and danger_pressed.corner_radius_top_left == 1
			and danger_pressed.border_width_left == 7
			and danger_hover_pressed.border_width_top == 4,
			"Danger hover/pressed states need distinct non-color geometry",
		)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var expected_danger := ThemeController.style_for(context, "danger", state)
			_expect(
				theme_a.get_stylebox(state, "DangerButton").get_instance_id()
				== expected_danger.get_instance_id(),
				"DangerButton theme state must use the cached danger resource: %s/%s" % [context, state],
			)
		for state in ["normal", "hover", "disabled"]:
			for variation in ["slider_rail", "slider_fill"]:
				var slider_style := ThemeController.style_for(context, variation, state)
				_expect(
					slider_style.get_instance_id()
					== ThemeController.style_for(context, variation, state).get_instance_id(),
					"Slider style cache identity failed: %s/%s/%s" % [context, variation, state],
				)
			var grabber := ThemeController.texture_for(context, "slider_grabber", state)
			_expect(
				grabber.get_instance_id()
				== ThemeController.texture_for(context, "slider_grabber", state).get_instance_id(),
				"Slider grabber cache identity failed: %s/%s" % [context, state],
			)
		_expect(
			ThemeController.style_for(context, "slider_rail", "hover").bg_color
			== Palette.color(context, "raised")
			and ThemeController.style_for(context, "slider_fill", "normal").border_color
			== Palette.color(context, "soul")
			and ThemeController.style_for(context, "slider_fill", "disabled").border_color
			== Palette.color(context, "disabled"),
			"Semantic slider rail/fill states must use exact named tokens",
		)
	var warm_style := ThemeController.style_for(Palette.WARM_ARCHIVE, "button", "normal")
	var cold_style := ThemeController.style_for(Palette.COLD_DUNGEON, "button", "normal")
	_expect(warm_style.get_instance_id() != cold_style.get_instance_id(), "Contexts must never share mutable style resources")
	var material_normal := ThemeController.style_for(
		Palette.WARM_ARCHIVE, "material_counter", "normal"
	)
	var material_hover := ThemeController.style_for(
		Palette.WARM_ARCHIVE, "material_counter", "hover"
	)
	var material_focus := ThemeController.style_for(
		Palette.WARM_ARCHIVE, "material_counter", "focus"
	)
	_expect(
		material_normal.get_instance_id()
		== ThemeController.style_for(
			Palette.WARM_ARCHIVE, "material_counter", "normal"
		).get_instance_id()
		and material_hover.get_instance_id()
		== ThemeController.style_for(
			Palette.WARM_ARCHIVE, "material_counter", "hover"
		).get_instance_id()
		and material_normal.bg_color == Palette.color(Palette.WARM_ARCHIVE, "inset")
		and material_hover.bg_color == Palette.color(Palette.WARM_ARCHIVE, "raised")
		and material_hover.border_color == Palette.color(Palette.WARM_ARCHIVE, "neutral_border")
		and material_hover.border_color != Palette.color(Palette.WARM_ARCHIVE, "soul")
		and material_hover.border_color != Palette.color(Palette.WARM_ARCHIVE, "focus")
		and material_focus.bg_color.a == 0.0
		and material_focus.border_color == Palette.color(Palette.WARM_ARCHIVE, "focus")
		and material_focus.border_width_left == 3,
		"Base material normal/hover/focus must be cached and geometrically separate without teal/gold hover",
	)


func _test_fonts_and_localized_glyphs() -> void:
	_expect(
		ThemeController.FONT_SIZES == [12, 14, 16, 20, 28, 32]
		and ThemeController.FONT_SIZES.all(
			func(size: int) -> bool: return ThemeController.is_approved_font_size(size)
		)
		and ThemeController.approved_font_size(13) == 14
		and ThemeController.approved_font_size(18) == 20
		and ThemeController.approved_sizes_between(28, 12) == [28, 20, 16, 14, 12],
		"FONT_SIZES must actively enforce the exact discrete Stage 1C type scale",
	)
	for path in FONT_HASHES:
		_expect(FileAccess.file_exists(path), "Bundled font missing: %s" % path)
		_expect(FileAccess.get_sha256(path) == FONT_HASHES[path], "Bundled font hash changed: %s" % path)
	for license in ["res://assets/fonts/noto-sans/OFL.txt", "res://assets/fonts/cormorant-garamond/OFL.txt"]:
		var text := FileAccess.get_file_as_string(license)
		_expect(text.contains("SIL OPEN FONT LICENSE Version 1.1"), "Complete OFL text missing: %s" % license)
	var required := "−+✓←→×·•—–…%/:;↑↓[]()"
	for locale in Loc.SUPPORTED_LOCALES:
		for value in Loc.STRINGS[locale].values():
			required += String(value)
	for font in [ThemeController.functional_font(), ThemeController.functional_font("medium"), ThemeController.functional_font("semibold")]:
		for index in range(required.length()):
			var codepoint := required.unicode_at(index)
			if codepoint < 0x20:
				continue
			_expect(font.has_char(codepoint), "Functional font lacks glyph U+%04X" % codepoint)
	var protected_functional := ThemeController.functional_font()
	_expect(
		protected_functional.has_char(0x25A3) and not protected_functional.has_char(0x25C6),
		"The protected font must justify supported ▣ loot semantics without adding the absent ◆ glyph",
	)
	var tabular := ThemeController.functional_font("regular", true) as FontVariation
	var tag := TextServerManager.get_primary_interface().name_to_tag("tnum")
	_expect(tabular != null and int(tabular.variation_opentype.get(tag, 0)) == 1, "Tabular numeric FontVariation must enable tnum")
	var functional := ThemeController.functional_font() as FontVariation
	_expect(
		functional != null
		and functional.get_instance_id() == ThemeController.functional_font().get_instance_id()
		and functional.base_font is FontFile
		and not (functional.base_font as FontFile).allow_system_fallback,
		"Functional font cache must be stable and independent of system fonts",
	)
	for fallback in functional.fallbacks:
		if fallback is FontFile:
			_expect(not (fallback as FontFile).allow_system_fallback, "Semantic-symbol fallback must not reach system fonts")


func _test_portrait_and_protected_assets() -> void:
	var portrait_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/portraits/stage1c-fringe-manifest.json"))
	_expect(portrait_manifest.get("alpha_radius_source_px", 0) == 2 and portrait_manifest.get("rgb_threshold", true) == null, "Portrait cleanup must be two-pixel alpha-only without RGB threshold")
	for record in portrait_manifest.get("outputs", []):
		var path := "res://" + String(record.output)
		_expect(FileAccess.get_sha256(path) == String(record.output_sha256), "Portrait output hash mismatch: %s" % path)
		var texture := load(path) as Texture2D
		_expect(texture != null and texture.get_size() == Vector2(264, 264), "Portrait must remain 264x264: %s" % path)
		var import_text := FileAccess.get_file_as_string(path + ".import")
		_expect(import_text.contains("compress/mode=0") and import_text.contains("mipmaps/generate=false") and import_text.contains("process/fix_alpha_border=true"), "Portrait import contract changed: %s" % path)
	var protected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/stage1c-protected-assets.json"))
	var protected_by_path := {}
	for record in protected.get("files", []):
		var path := "res://" + String(record.path)
		protected_by_path[String(record.path)] = record
		_expect(FileAccess.file_exists(path) and FileAccess.get_sha256(path) == String(record.sha256), "Protected dirty-baseline art changed: %s" % path)
	_expect(
		(protected.get("authorized_runtime_exceptions", []) as Array).is_empty()
		and (protected.get("files", []) as Array).size() == 427
		and String(protected_by_path.get("assets/portraits/female/form-almost-human.png", {}).get("sha256", ""))
		== "de3b97db54c1d2180c449b7324784dbb6f0988957228e4d685137edee10282ad"
		and String(protected_by_path.get("assets/portraits/male/form-almost-human.png", {}).get("sha256", ""))
		== "ea3bcb78f6abbc31632a00b2f2990a37bc87d35a0eae2b8c144a72238681fb22"
		and int(protected_by_path.get("assets/ui/soul-icon.png", {}).get("bytes", 0)) == 4165
		and String(protected_by_path.get("assets/ui/soul-icon.png", {}).get("sha256", ""))
		== "584d86b87dfff9c5d9b64badf273a561a5359a41adeb44e444e2961c3eaf32db",
		"Stage 1E must freeze 427 exact assets after its one-way 416-to-427 guarded transition, including portraits and the shipped soul HUD texture",
	)
	var transition_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/stage1e-protected-transition.json"))
	_expect(
		transition_value is Dictionary
		and int(transition_value.get("before_records", 0)) == 416
		and int(transition_value.get("after_records", 0)) == 427
		and (transition_value.get("delta_paths", []) as Array).size() == 41
		and (transition_value.get("allowlist", []) as Array).size() == 41,
		"Stage 1E protected transition evidence must bind the exact 416-to-427 41-path allowlist",
	)


func _test_preview_manifest() -> void:
	# Stage 1C remains archival evidence; its old source hashes are intentionally
	# not a freshness oracle after Stage 1E. The active closure is the current
	# real-render Stage 1E bundle.
	const preview_root := "res://.tmp/stage1e-previews"
	const manifest_path := preview_root + "/manifest.json"
	var archived_stage1c: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.tmp/stage1c-previews/manifest.json"))
	_expect(archived_stage1c is Dictionary and String((archived_stage1c as Dictionary).get("stage", "")) == "1D", "Stage 1C preview manifest is retained as archival evidence, not a current-source freshness contract")
	_expect(FileAccess.file_exists(manifest_path), "Fresh Stage 1E preview manifest is missing")
	if not FileAccess.file_exists(manifest_path):
		return
	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	_expect(manifest_value is Dictionary, "Stage 1E preview manifest must be valid JSON")
	if not manifest_value is Dictionary:
		return
	var manifest: Dictionary = manifest_value
	var captures: Array = manifest.get("captures", [])
	_expect(
		String(manifest.get("stage", "")) == "1E"
		and int(manifest.get("expected_capture_count", 0)) == 488
		and int(manifest.get("capture_count", 0)) == 488
		and captures.size() == 488,
		"Stage 1E preview matrix must contain exactly 488 fresh real-render captures",
	)
	var paths := {}
	var profile_scenarios := {}
	for record_value in captures:
		if not record_value is Dictionary:
			_expect(false, "Every Stage 1E capture record must be a dictionary")
			continue
		var record: Dictionary = record_value
		var scenario := String(record.get("scenario", ""))
		var path := "res://" + String(record.get("path", ""))
		_expect(not paths.has(path), "Preview manifest path must be unique: %s" % path)
		paths[path] = true
		_expect(
			FileAccess.file_exists(path)
			and FileAccess.get_sha256(path) == String(record.get("sha256", "")),
			"Preview file/hash mismatch: %s" % path,
		)
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			_expect(
				image != null
				and image.get_size() == Vector2i(
					int(record.get("width", 0)), int(record.get("height", 0)),
				),
				"Preview dimensions mismatch: %s" % path,
			)
		var profile := "%s-%dx%d" % [
			String(record.get("locale", "")),
			int(record.get("width", 0)),
			int(record.get("height", 0)),
		]
		if not profile_scenarios.has(profile):
			profile_scenarios[profile] = []
		(profile_scenarios[profile] as Array).append(String(record.get("scenario", "")))
	for profile in ["ru-1280x720", "en-1280x720", "ru-960x540", "en-960x540"]:
		_expect((profile_scenarios.get(profile, []) as Array).size() == (85 if profile.begins_with("ru-") else 159), "Stage 1E preview profile cardinality changed: %s" % profile)
	var directory := DirAccess.open(preview_root)
	var disk_pngs := {}
	if directory != null:
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if not directory.current_is_dir() and entry.get_extension().to_lower() == "png":
				disk_pngs[preview_root.path_join(entry)] = true
			entry = directory.get_next()
		directory.list_dir_end()
	_expect(disk_pngs == paths, "Preview directory must contain no stale/unmanifested PNGs")

	var expected_inputs: Array[String] = []
	for root_path in ["res://scripts", "res://scenes", "res://assets"]:
		_collect_files(root_path, expected_inputs)
	for explicit_path in [
		"res://project.godot", "res://tests/capture_stage1e_preview.gd", "res://tools/capture_stage1e_previews.ps1",
		"res://tools/package_body_skill_icons.py", "res://tools/patch_stage1e_camp_art.py", "res://tools/prepare_nightly_camp_assets.py", "res://tools/verify_stage1c_protected_assets.py",
		"res://art/skills/body-icons/2026-09-01/PROMPTS.md", "res://art/skills/body-icons/2026-09-01/manifest.json", "res://assets/art/camp-2026-09-01/manifest.json",
		"res://.tmp/stage1e-before-evidence/camp-record-player.png", "res://.tmp/stage1e-before-evidence/camp-workbench.png",
	]:
		if not expected_inputs.has(explicit_path):
			expected_inputs.append(explicit_path)
	expected_inputs.sort()
	var source_hashes: Dictionary = manifest.get("source_hashes", {})
	var manifest_inputs: Array[String] = []
	for relative_path in source_hashes:
		manifest_inputs.append("res://" + String(relative_path))
		_expect(
			FileAccess.file_exists("res://" + String(relative_path))
			and FileAccess.get_sha256("res://" + String(relative_path))
			== String(source_hashes[relative_path]),
			"Preview source hash is stale: %s" % relative_path,
		)
	manifest_inputs.sort()
	_expect(
		manifest_inputs == expected_inputs and manifest_inputs.size() == 488,
		"Stage 1E manifest must hash its exact 488-input scripts/scenes/assets/recipe closure including native sheet art",
	)


func _collect_files(path: String, result: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_collect_files(child, result)
		else:
			result.append(child)
		entry = directory.get_next()
	directory.list_dir_end()


func _test_real_controls_and_context(tree: SceneTree) -> void:
	Loc.set_locale("ru")
	var main := MainScene.new()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	_expect(main.theme.get_instance_id() == ThemeController.theme_for(Palette.WARM_ARCHIVE).get_instance_id(), "Creation must use Warm Archive")
	var female: Button = main.sex_choice_panel.buttons.female
	var male: Button = main.sex_choice_panel.buttons.male
	_expect(female.size == Vector2(156, 160) and male.size == Vector2(156, 160) and male.position.x - female.position.x == 176.0, "Sex cards must stay 156x160 with 20 px gap")
	for sex in ["female", "male"]:
		var button: Button = main.sex_choice_panel.buttons[sex]
		var portrait := button.get_child(0) as TextureRect
		_expect(portrait.size == Vector2(120, 120), "Selector portrait must stay 120x120")
		_expect(not String(button.accessibility_name).is_empty() and not main.sex_choice_panel.labels[sex].visible, "Portrait-only sex card keeps its localized accessibility name")
	_expect(main.sex_choice_panel.selection_markers.female.visible != main.sex_choice_panel.selection_markers.male.visible, "Exactly one sex card needs a persistent non-color selection marker")
	main.name_input.text = "Contract"
	main._on_name_confirmed()
	_expect(main.screen == main.Screen.STAT_CREATION and main.creation_back_button.visible, "Stat step must expose Back")
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		_expect(main.attribute_minus_buttons[attribute_id].disabled, "Starting minus must be disabled: %s" % attribute_id)
		_expect(main.attribute_plus_buttons[attribute_id].focus_mode == Control.FOCUS_ALL, "Stat plus must be focusable: %s" % attribute_id)
	main.attribute_plus_buttons[GameRules.ATTRIBUTE_ORDER[0]].pressed.emit()
	_expect(not main.attribute_minus_buttons[GameRules.ATTRIBUTE_ORDER[0]].disabled and int(main.attribute_value_labels[GameRules.ATTRIBUTE_ORDER[0]].text) > GameRules.STARTING_ATTRIBUTE_VALUE, "Changed stat keeps minus active and uses plain numeric text")
	main.free_attribute_points = 0
	main._refresh_creation_preview()
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		_expect(main.attribute_plus_buttons[attribute_id].disabled, "Plus must disable at zero free points")
	_expect(not main.creation_confirm_button.disabled, "Finish must enable only at zero free points")
	main.free_attribute_points = GameRules.STARTING_FREE_ATTRIBUTE_POINTS - 1
	main._refresh_creation_preview()
	main.creation_back_button.pressed.emit()
	_expect(main.screen == main.Screen.NAME_CREATION and main.name_input.text == "Contract", "Back must preserve name and pending allocation")

	# Real settings/remap controls: cached slider resources and an actual touch
	# conflict decision must work through Main's input routing.
	main._open_settings()
	var slider = main.settings_background_slider
	_expect(
		slider.name == "SettingsBackgroundVolume"
		and slider.accessibility_name == main.settings_background_label.text
		and slider.get_theme_stylebox("slider").get_instance_id()
		== ThemeController.style_for(Palette.WARM_ARCHIVE, "slider_rail", "normal").get_instance_id()
		and slider.focus_style.border_color == Palette.color(Palette.WARM_ARCHIVE, "focus"),
		"Settings HSliders must expose cached Warm rails/grabbers, accessibility and gold focus",
	)
	slider.set_semantic_enabled(false)
	_expect(
		slider.get_theme_stylebox("slider").get_instance_id()
		== ThemeController.style_for(Palette.WARM_ARCHIVE, "slider_rail", "disabled").get_instance_id()
		and slider.get_theme_icon("grabber").get_instance_id()
		== ThemeController.texture_for(Palette.WARM_ARCHIVE, "slider_grabber", "disabled").get_instance_id(),
		"Disabled slider must use cached semantic disabled resources",
	)
	slider.set_semantic_enabled(true)
	main.settings_controls_button.pressed.emit()
	await tree.process_frame
	var remap = main.controls_remap_panel
	InputProfile.reset_to_defaults()
	remap.refresh_bindings()
	var conflict_key := InputEventKey.new()
	conflict_key.keycode = KEY_Q
	conflict_key.physical_keycode = KEY_Q
	conflict_key.pressed = true
	remap.keyboard_buttons["attack"].pressed.emit()
	main.get_viewport().push_input(conflict_key, true)
	await tree.process_frame
	_expect(
		remap.pending_event != null
		and remap.confirm_conflict_button.visible
		and remap.cancel_conflict_button.visible
		and remap.confirm_conflict_button.theme_type_variation == "DangerButton"
		and remap.status_label.theme_type_variation == "DangerLabel"
		and main.get_viewport().gui_get_focus_owner() == remap.confirm_conflict_button,
		"A binding conflict must be a focused, accessible, blocking semantic danger decision",
	)
	await _push_touch(main, tree, remap.keyboard_buttons["attack"].get_global_rect().get_center())
	_expect(
		remap.capture_action == "attack" and remap.pending_event != null,
		"A second touch on the source binding must not reset or cancel the pending conflict",
	)
	await _push_touch(main, tree, remap.cancel_conflict_button.get_global_rect().get_center())
	_expect(
		remap.capture_action.is_empty() and _has_key_binding("cast_spell", KEY_Q),
		"The explicit touch Cancel path must preserve the existing binding",
	)
	remap.keyboard_buttons["attack"].pressed.emit()
	main.get_viewport().push_input(conflict_key, true)
	await tree.process_frame
	await _push_touch(main, tree, remap.confirm_conflict_button.get_global_rect().get_center())
	_expect(
		remap.capture_action.is_empty()
		and _has_key_binding("attack", KEY_Q)
		and not _has_key_binding("cast_spell", KEY_Q)
		and not remap.confirm_conflict_button.visible,
		"InputEventScreenTouch on the explicit Replace action must apply the pending binding",
	)
	InputProfile.reset_to_defaults()
	main._close_controls_remap()
	main._close_settings()

	# Complete creation through real controls and story input, then enter a real
	# dungeon through the visible Base/expedition actions.
	main.name_confirm_button.pressed.emit()
	for attribute_id in GameRules.ATTRIBUTE_ORDER.slice(1):
		main.attribute_plus_buttons[attribute_id].pressed.emit()
	_expect(main.free_attribute_points == 0, "Real stat buttons must spend the preserved four remaining points")
	main.creation_confirm_button.pressed.emit()
	for _page in range(3):
		await _push_action(main, tree, "interact")
	_expect(main.screen == main.Screen.BASE, "Real story input must reach Base before the context transition test")
	main.state.carried_souls = 999999
	main.state.banked_souls = 999999
	main.state.resources = {"wood": 9999, "stone": 9999, "cloth": 9999}
	var base_identity_name: String = main.state.character_name
	var base_identity_form: String = main.state.current_form_id
	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		main.state.character_name = (
			"Странница Архивов с именем длиннее границ старой летописи"
			if locale == "ru"
			else "The Archive Wanderer Whose Name Outlives the Old Chronicle"
		)
		main.state.current_form_id = "almost_human"
		main._apply_locale()
		main._refresh_interface()
		await tree.process_frame
		RenderingServer.force_draw(false)
		await tree.process_frame
		var soul_font := main.souls_label.get_theme_font("font")
		var soul_font_size := main.souls_label.get_theme_font_size("font_size")
		var measured_soul_width := soul_font.get_string_size(
			main.souls_label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			soul_font_size,
		).x
		var soul_rect := Rect2(main.souls_label.position, main.souls_label.size)
		var soul_icon_rect := Rect2(main.soul_icon.position, main.soul_icon.size)
		var material_rect := Rect2(
			main.material_resources_strip.position,
			main.material_resources_strip.size,
		)
		var identity_rect := Rect2(main.stats_label.position, main.stats_label.size)
		var identity_line_count: int = main.stats_label.get_line_count()
		var visible_identity_lines: int = main.stats_label.get_visible_line_count()
		for output_size in [Vector2(1280, 720), Vector2(960, 540)]:
			var canvas_scale: float = output_size.x / 1280.0
			var scaled_soul_rect := Rect2(
				soul_rect.position * canvas_scale,
				soul_rect.size * canvas_scale,
			)
			_expect(
				main.souls_label.text == "999999 (1999998)"
				and measured_soul_width * canvas_scale <= scaled_soul_rect.size.x
				and not soul_rect.intersects(soul_icon_rect)
				and not soul_rect.intersects(material_rect)
				and main.BASE_RESOURCE_STRIP_RECT.encloses(soul_rect)
				and main.BASE_RESOURCE_STRIP_RECT.encloses(soul_icon_rect)
				and main.BASE_RESOURCE_STRIP_RECT.encloses(material_rect)
				and not main.BASE_RESOURCE_STRIP_RECT.intersects(main.BASE_TITLE_RECT)
				and not main.BASE_RESOURCE_STRIP_RECT.intersects(main.BASE_SIDEBAR_RECT),
				"Complete max Base soul counter must fit without clipping/overlap in %s at %dx%d" % [
					locale, int(output_size.x), int(output_size.y),
				],
			)
			_expect(
				identity_line_count >= 3
				and visible_identity_lines == identity_line_count
				and ThemeController.is_approved_font_size(
					main.stats_label.get_theme_font_size("font_size")
				)
				and (
					BaseLayout.HP_RECT.position.y - identity_rect.end.y
				) * canvas_scale >= 3.0,
				"Rendered max Base identity must show every wrapped name/Form line above HP in %s at %dx%d" % [
					locale, int(output_size.x), int(output_size.y),
				],
			)
	main.state.character_name = base_identity_name
	main.state.current_form_id = base_identity_form
	Loc.set_locale("ru")
	main._apply_locale()
	main._refresh_interface()
	main._configure_base_focus()
	await tree.process_frame
	var material_controls: Array[Control] = main.material_resources_strip.focusable_controls()
	_expect(
		material_controls.size() == 3
		and main.material_resources_strip.theme.get_instance_id()
		== ThemeController.theme_for(Palette.WARM_ARCHIVE).get_instance_id(),
		"Warm Base must expose exactly three locally themed material counters",
	)
	for counter_control in material_controls:
		var counter = counter_control
		var value_label: Label = counter.get("value_label")
		var value_font: Font = counter.get("value_font")
		var measured_width := value_font.get_string_size(
			value_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12
		).x
		_expect(
			value_label.get_theme_font_size("font_size") == 12
			and value_label.get_theme_font("font").get_instance_id()
			== ThemeController.functional_font("regular", true).get_instance_id()
			and value_label.get_theme_color("font_color")
			== Palette.color(Palette.WARM_ARCHIVE, "primary")
			and measured_width <= value_label.size.x
			and counter.get("normal_style").get_instance_id()
			== ThemeController.style_for(
				Palette.WARM_ARCHIVE, "material_counter", "normal"
			).get_instance_id()
			and counter.get("hover_style").get_instance_id()
			== ThemeController.style_for(
				Palette.WARM_ARCHIVE, "material_counter", "hover"
			).get_instance_id()
			and counter.get("focus_style").get_instance_id()
			== ThemeController.style_for(
				Palette.WARM_ARCHIVE, "material_counter", "focus"
			).get_instance_id()
			and not counter_control.focus_neighbor_left.is_empty()
			and not counter_control.focus_neighbor_right.is_empty()
			and not counter_control.focus_neighbor_top.is_empty()
			and not counter_control.focus_neighbor_bottom.is_empty(),
			"Material counters must use cached tabular 12px resources, fit 9999, and join Base focus",
		)
	if material_controls.size() == 3:
		_expect(
			material_controls[2].focus_neighbor_bottom == main.start_button.get_path()
			and main.start_button.focus_neighbor_top == material_controls[2].get_path(),
			"Base focus graph must connect the material strip to its surrounding Start control",
		)
	main.state.add_or_refresh_status("rested", 12, 3)
	main.state.add_or_refresh_status("satiated", 9, 2)
	main._refresh_interface()
	main.start_button.pressed.emit()
	await tree.process_frame
	main.expedition_beginning_button.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	_expect(
		main.screen == main.Screen.DUNGEON
		and main.theme.get_instance_id() == ThemeController.theme_for(Palette.COLD_DUNGEON).get_instance_id(),
		"Real Base actions must enter a Cold Dungeon context",
	)
	main.state.active_statuses["satiated"] = {"remaining_turns": 9, "temporary_hp": 2}
	main._refresh_interface()
	await tree.process_frame
	var floor_before: Dictionary = main.floor_data.duplicate(true)
	var player_before: Vector2i = main.player_pos
	var dungeon_modulate_before: Color = main.dungeon_viewport.modulate
	var dungeon_self_modulate_before: Color = main.dungeon_viewport.self_modulate
	var attack_rect_before := Rect2(main.attack_button.position, main.attack_button.size)
	var attack_style_before := main.attack_button.get_theme_stylebox("normal").get_instance_id()
	await _push_action(main, tree, "character_sheet")
	_expect(
		main.screen == main.Screen.CHARACTER
		and main.theme.get_instance_id() == ThemeController.theme_for(Palette.COLD_DUNGEON).get_instance_id()
		and main.character_modal_backdrop.visible
		and main.character_modal_backdrop.mouse_filter == Control.MOUSE_FILTER_STOP
		and main.dungeon_viewport.visible
		and main.inventory_panel.theme.get_instance_id()
		== ThemeController.theme_for(Palette.WARM_ARCHIVE).get_instance_id(),
		"Character from Dungeon must retain the Cold frozen shell and layer cached Warm modal controls above its neutral blocker",
	)
	main.inventory_mode_button.pressed.emit()
	await tree.process_frame
	var status_chips: Array[Control] = main.character_status_strip.focusable_controls()
	_expect(
		status_chips.size() == 2,
		"Character status strip must expose both active statuses as focusable controls (got %d, state %s, children %d)" % [
			status_chips.size(), main.state.active_statuses, main.character_status_strip.get_child_count(),
		],
	)
	if not status_chips.is_empty():
		var status_chip = status_chips[0]
		_expect(
			status_chip.normal_style.get_instance_id()
			== ThemeController.style_for(Palette.WARM_ARCHIVE, "status_chip", "normal").get_instance_id()
			and status_chip.text_font.get_instance_id()
			== ThemeController.functional_font("semibold", true).get_instance_id()
			and not String(status_chip.accessibility_name).is_empty()
			and not status_chip.focus_neighbor_right.is_empty(),
			"Custom-drawn statuses must use cached resources, accessibility and the character focus graph (style %s, font %s, access '%s', right '%s')" % [
				status_chip.normal_style.get_instance_id(),
				status_chip.text_font.get_instance_id(),
				status_chip.accessibility_name,
				status_chip.focus_neighbor_right,
			],
		)

	var original_name: String = main.state.character_name
	var original_form: String = main.state.current_form_id
	for locale in ["ru", "en"]:
		Loc.set_locale(locale)
		main.state.current_form_id = "skeleton"
		main.state.character_name = "Ия" if locale == "ru" else "Io"
		main._apply_locale()
		_expect(
			main.title_label.get_theme_font_size("font_size") == 28
			and main.title_label.get_theme_font("font").get_instance_id()
			== ThemeController.heading_font().get_instance_id(),
			"Short %s character heading must use Cormorant at exactly 28" % locale,
		)
		main.state.current_form_id = "almost_human"
		main.state.character_name = (
			"ОченьДлинноеИмяПерсонажа" if locale == "ru" else "ExtremelyLongCharacterNam"
		)
		main._apply_locale()
		_expect(
			main.title_label.get_theme_font_size("font_size") == 20
			and main.title_label.get_theme_font("font").get_instance_id()
			== ThemeController.functional_font("semibold").get_instance_id()
			and main.title_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
			"Long %s character heading must use Noto Sans 20 with ellipsis, never undersized Cormorant" % locale,
		)
	main.state.character_name = original_name
	main.state.current_form_id = original_form
	Loc.set_locale("ru")
	main._apply_locale()
	await _push_joypad(main, tree, JOY_BUTTON_B)
	_expect(
		main.screen == main.Screen.DUNGEON
		and main.theme.get_instance_id() == ThemeController.theme_for(Palette.COLD_DUNGEON).get_instance_id()
		and main.floor_data == floor_before
		and main.player_pos == player_before
		and main.dungeon_viewport.modulate == dungeon_modulate_before
		and main.dungeon_viewport.self_modulate == dungeon_self_modulate_before
		and Rect2(main.attack_button.position, main.attack_button.size) == attack_rect_before
		and main.attack_button.get_theme_stylebox("normal").get_instance_id() == attack_style_before,
		"Real Joypad B must restore the same cold Dungeon without changing world/HUD presentation",
	)
	main.save_menu_panel.show_menu(true)
	_expect(main.save_menu_panel.theme.get_instance_id() == ThemeController.theme_for(Palette.WARM_ARCHIVE).get_instance_id(), "Menu over dungeon must remain Warm Archive")
	_expect(main.dungeon_viewport.modulate == Color.WHITE and main.dungeon_viewport.self_modulate == Color.WHITE, "UI context must not tint the dungeon viewport")
	for control in main.creation_controls + main.settings_controls:
		if control is Label and control.visible:
			_expect(control.get_theme_font_size("font_size") >= 12, "Scoped essential label fell below 12 px: %s" % control.name)
		elif control is Button and not control.text.is_empty():
			_expect(control.get_theme_font_size("font_size") >= 12, "Scoped interactive text fell below 12 px: %s" % control.name)
	for scoped_root in [
		main.sex_choice_panel,
		main.save_menu_panel,
		main.controls_remap_panel,
		main.camp_build_panel,
		main.storage_panel,
		main.material_resources_strip,
	]:
		_assert_discrete_type_scale(scoped_root, String(scoped_root.name))
	main.queue_free()
	await tree.process_frame


func _test_source_boundaries() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var loc_source := FileAccess.get_file_as_string("res://scripts/localization/localization.gd")
	var palette_source := FileAccess.get_file_as_string("res://scripts/ui/ui_palette.gd")
	var persistence_source := FileAccess.get_file_as_string("res://scripts/system/persistence.gd")
	var status_source := FileAccess.get_file_as_string("res://scripts/ui/status_strip.gd")
	var material_source := FileAccess.get_file_as_string(
		"res://scripts/ui/base_material_resource_strip.gd"
	)
	var save_source := FileAccess.get_file_as_string("res://scripts/ui/save_menu_panel.gd")
	var skill_icon_source := FileAccess.get_file_as_string("res://scripts/ui/skill_tree_icon.gd")
	_expect(not main_source.contains("character_cheat") and not loc_source.contains("BTN_CHEAT_ADD_STATS"), "Production source/localization must contain no cheat UI")
	_expect(not palette_source.contains("lightened(") and not palette_source.contains("darkened("), "Palette must not derive arbitrary colors at runtime")
	_expect(
		not skill_icon_source.contains(".lightened(")
		and not skill_icon_source.contains(".darkened(")
		and skill_icon_source.contains("depressed_offset"),
		"Skill held/disabled states must use non-color depressed geometry and exact cached semantic tokens",
	)
	_expect(not persistence_source.contains("ui_theme") and not persistence_source.contains("warm_archive") and not persistence_source.contains("cold_dungeon"), "Theme must never enter persistence schema")
	_expect(persistence_source.contains("const SAVE_VERSION := 18") and persistence_source.contains("const MIN_SUPPORTED_SAVE_VERSION := 17"), "Stage 1C must retain v18/v17 persistence boundary")
	_expect(
		not status_source.contains("ThemeDB")
		and not status_source.contains("StyleBoxFlat.new")
		and status_source.contains("text_font")
		and status_source.contains("focus_style"),
		"StatusStrip custom draw must use cached semantic resources without system fallback or allocations",
	)
	_expect(
		not material_source.contains("ThemeDB")
		and not material_source.contains("StyleBoxFlat.new")
		and not material_source.contains("VALUE_MIN_FONT_SIZE")
		and not material_source.contains("_fit_value_text")
		and material_source.contains("const VALUE_FONT_SIZE := 12")
		and material_source.contains("normal_style")
		and material_source.contains("hover_style")
		and material_source.contains("focus_style")
		and material_source.contains('functional_font("regular", true)'),
		"Base material custom draw must use exact-scale cached semantic resources without shrink/system fallback",
	)
	_expect(
		not save_source.to_lower().contains("ffaaa1")
		and save_source.contains('color(TrashPalette.WARM_ARCHIVE, "danger")'),
		"Trash glyph must use the exact named Warm danger token",
	)
	_expect(
		not main_source.contains('souls_label.add_theme_color_override("font_color", COLOR_GOLD)')
		and main_source.contains('UiPaletteClass.WARM_ARCHIVE if screen == Screen.CHARACTER else context')
		and main_source.contains('"soul"'),
		"Character souls must use Warm soul above Cold while non-modal screens use their semantic context",
	)


func _push_action(main: Control, tree: SceneTree, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	main.get_viewport().push_input(press, true)
	await tree.process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await tree.process_frame


func _push_joypad(main: Control, tree: SceneTree, button_index: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button_index
	press.pressed = true
	main.get_viewport().push_input(press, true)
	await tree.process_frame
	var release := InputEventJoypadButton.new()
	release.button_index = button_index
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await tree.process_frame


func _push_touch(main: Control, tree: SceneTree, position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 17
	press.position = position
	press.pressed = true
	main.get_viewport().push_input(press, true)
	await tree.process_frame
	var release := InputEventScreenTouch.new()
	release.index = 17
	release.position = position
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await tree.process_frame


func _has_key_binding(action: String, keycode: Key) -> bool:
	for event in InputProfile.get_device_events(action, InputProfile.DEVICE_KEYBOARD):
		if event is InputEventKey and (
			(event as InputEventKey).keycode == keycode
			or (event as InputEventKey).physical_keycode == keycode
		):
			return true
	return false


func _assert_discrete_type_scale(root: Node, scope: String) -> void:
	if root is Label:
		var label := root as Label
		var font_size := label.get_theme_font_size("font_size")
		_expect(
			font_size >= 12 and ThemeController.is_approved_font_size(font_size),
			"%s label %s must use the exact Stage 1C type scale (got %d)" % [scope, label.name, font_size],
		)
	elif root is Button:
		var button := root as Button
		if not button.text.is_empty():
			var font_size := button.get_theme_font_size("font_size")
			_expect(
				font_size >= 12 and ThemeController.is_approved_font_size(font_size),
				"%s control %s must use the exact Stage 1C type scale (got %d)" % [scope, button.name, font_size],
			)
	for child in root.get_children():
		_assert_discrete_type_scale(child, scope)


func _contrast(foreground: Color, background: Color) -> float:
	var light := _luminance(foreground)
	var dark := _luminance(background)
	return (maxf(light, dark) + 0.05) / (minf(light, dark) + 0.05)


func _luminance(color: Color) -> float:
	var channels := [color.r, color.g, color.b]
	for index in range(channels.size()):
		channels[index] = channels[index] / 12.92 if channels[index] <= 0.04045 else pow((channels[index] + 0.055) / 1.055, 2.4)
	return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
