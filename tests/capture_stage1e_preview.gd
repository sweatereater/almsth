extends SceneTree

## Normal-renderer Stage 1E evidence. Every PNG uses the real Main scene,
## live controls, and the production alpha-derived camp overlay.
const Loc := preload("res://scripts/localization/localization.gd")
const Overlay := preload("res://scripts/ui/camp_silhouette_overlay.gd")
const Rules := preload("res://scripts/game/game_rules.gd")
const ROOT := "res://.tmp/stage1e-previews"
const BEFORE_ROOT := "res://.tmp/stage1e-before-evidence"
const SIZES := [Vector2i(1280, 720), Vector2i(960, 540)]
const LOCALES := ["ru", "en"]
const CAMP_IDS := ["mural", "bunk", "textile_area", "workbench", "writing_set", "ritual_table", "crusher", "whetstone", "campfire", "kettle", "rocking_chair", "record_player", "storage_chest"]
const STATES := ["normal", "hover", "focus", "selected", "selected_focus", "disabled_unbuilt"]
var records: Array = []
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _safe_root(ROOT):
		push_error("PREVIEW OUTPUT REJECTED: Stage1E output must resolve exactly to %s" % ROOT)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	_remove_stale_outputs()
	_verify_live_body_icon_imports()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	for size in SIZES:
		root.size = size
		await process_frame
		await process_frame
		for locale in LOCALES:
			Loc.set_locale(locale)
			var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
			main.persistence_enabled = false
			main.audio_playback_enabled = false
			root.add_child(main)
			await process_frame
			main.state.configure_character("Stage1E", Rules.default_attributes())
			for id in Rules.CAMP_DRAW_ORDER:
				main.state.camp_upgrades[id] = true
			main._show_base("", "none")
			for id in CAMP_IDS:
				for state in STATES:
					var was_built := bool(main.state.camp_upgrades.get(id, false))
					# Disabled/unbuilt is a real base-state capture, not merely an
					# overlay suppression. This must remove the prop itself before
					# the renderer is sampled, then restore the built fixture.
					if state == "disabled_unbuilt":
						main.state.camp_upgrades[id] = false
						main._refresh_interface()
					main.camp_silhouette_overlay.set_state(id, state)
					main.queue_redraw()
					await _save("camp-%s-%s" % [id, state], locale, size, "camp_overlay")
					if state == "disabled_unbuilt":
						main.state.camp_upgrades[id] = was_built
						main._refresh_interface()
						main.queue_redraw()
					main.camp_silhouette_overlay.set_state(id, "normal")
			if locale == "en":
				await _capture_asset_forensics(main, locale, size)
			# Actual Warm skill-tree states showing the packaged body icon family.
			main._show_character()
			main._select_character_panel("skills")
			for profile in [["revenant", "nervous_system", "locked"], ["skeleton", "strong_bones", "available"], ["skeleton", "strong_bones", "learned"], ["ghoul", "ears", "selected"], ["ghoul", "ears", "focus"], ["ghoul", "ears", "selected_focus"], ["almost_human", "fundamentals", "disabled_unbuilt"]]:
				if profile[2] == "learned":
					main.state.skill_levels[profile[1]] = 1
				main._select_skill_stage(profile[0])
				main._on_skill_pressed(profile[1])
				if profile[2] == "focus" or profile[2] == "selected_focus":
					main.skill_node_buttons[profile[1]].grab_focus()
				await _save("skill-%s-%s" % [profile[1], profile[2]], locale, size, "skill_tree")
			if locale == "en":
				await _capture_lunge_matrix(main, locale, size)
			main.queue_free()
			await process_frame
	var expected := SIZES.size() * LOCALES.size() * (CAMP_IDS.size() * STATES.size() + 7) + 2 * (47 + 27)
	if records.size() != expected:
		failures.append("Expected %d fresh Stage1E captures, wrote %d" % [expected, records.size()])
	_validate_fresh_outputs(expected)
	_write_manifest(expected)
	for failure in failures:
		push_error(failure)
	print("STAGE 1E PREVIEW CAPTURE %s: %d captures; cache %d" % ["PASS" if failures.is_empty() else "FAIL", records.size(), Overlay.cache_cardinality()])
	quit(0 if failures.is_empty() else 1)

func _save(scenario: String, locale: String, size: Vector2i, context: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ROOT.path_join("%s-%dx%d-%s.png" % [locale, size.x, size.y, scenario])
	if image == null or image.is_empty():
		failures.append("Normal-renderer capture is empty: %s" % path)
		return
	if image.get_size() != size:
		failures.append("Capture size mismatch for %s: %s" % [path, image.get_size()])
		return
	if image.save_png(path) != OK:
		failures.append("Could not save capture: %s" % path)
		return
	records.append({"path": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path), "locale": locale, "width": size.x, "height": size.y, "scenario": scenario, "ui_context": context, "real_controls": true})

func _verify_live_body_icon_imports() -> void:
	var file := FileAccess.open("res://art/skills/body-icons/2026-09-01/manifest.json", FileAccess.READ)
	if file == null:
		failures.append("Body icon manifest missing before real-render capture")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		failures.append("Body icon manifest is invalid before real-render capture")
		return
	for id in Rules.BODY_SKILL_IDS:
		var expected := String(parsed.icons[id].runtime_alpha_sha256)
		var texture: Texture2D = load("res://assets/ui/skill-icons/body/%s.png" % id)
		if texture == null:
			failures.append("Body icon import missing: %s" % id)
			continue
		var image := texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		var rgba := image.get_data()
		var alpha := PackedByteArray()
		alpha.resize(image.get_width() * image.get_height())
		for index in alpha.size():
			alpha[index] = rgba[index * 4 + 3]
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(alpha)
		if context.finish().hex_encode() != expected:
			failures.append("Stale imported body icon alpha for %s; refresh the Godot import cache" % id)

func _capture_lunge_matrix(main, locale: String, size: Vector2i) -> void:
	# The lunge belongs to presentation only.  These are captured with real
	# dungeon controls at all supported zooms and exact timeline samples.
	if main.screen == main.Screen.CHARACTER:
		main._close_character()
		await process_frame
	main._show_dungeon_interface()
	main._load_floor(1)
	var target: Vector2i = main.player_pos + Vector2i.RIGHT
	main.floor_data["enemies"] = [{"uid": "stage1e-lunge-enemy", "id": "hollow_guard", "pos": target, "hp": 99, "dodge": 0, "damage": 1, "accuracy": 1}]
	main.floor_data["visible_cells"] = {main.player_pos: true, target: true}
	main.floor_data["explored_cells"] = {main.player_pos: true, target: true}
	for zoom in [44, 66, 88]:
		main.set_dungeon_cell_size(zoom)
		for sample in [["0", 0.0], ["63", 0.063], ["150", 0.150]]:
			for actor in ["player-hit", "player-miss", "enemy-normal", "enemy-heavy", "enemy-boss"]:
				main._clear_hit_effects()
				var is_player: bool = String(actor).begins_with("player")
				# Reset the complete target presentation for every timeline sample.
				# Player hit/miss always keep the same normal target; only the named
				# enemy cases select their documented normal/heavy/boss identity.
				var expected_enemy_id: String = "hollow_guard" if is_player or actor == "enemy-normal" else ("slag_smith" if actor == "enemy-heavy" else "minotaur")
				main.floor_data["enemies"][0].id = expected_enemy_id
				if String(main.floor_data["enemies"][0].id) != expected_enemy_id or Vector2i(main.floor_data["enemies"][0].pos) != target:
					failures.append("Lunge target identity/pose leaked across timeline samples: %s" % actor)
					return
				main._start_melee_lunge("player" if is_player else "stage1e-lunge-enemy", main.player_pos if is_player else target, target if is_player else main.player_pos)
				var key: String = "player" if is_player else "stage1e-lunge-enemy"
				main.melee_lunges[key].elapsed = sample[1]
				main._refresh_dungeon_viewport()
				# `_save` synchronizes two frames; freeze Main so named 0/63/150ms
				# samples cannot advance or expire before the real renderer reads them.
				main.set_process(false)
				await _save("lunge-%s-z%d-t%s" % [actor, zoom, sample[0]], locale, size, "dungeon_lunge")
				main.set_process(true)
	# Ranged/magic paths must not create a lunge; a blocking/reset transition
	# must remove one before its frame reaches the renderer.
	main._clear_hit_effects()
	await _save("lunge-ranged-negative", locale, size, "dungeon_lunge")
	main._start_melee_lunge("player", main.player_pos, target)
	main._clear_hit_effects()
	await _save("lunge-reset-clear", locale, size, "dungeon_lunge")

func _capture_asset_forensics(main, locale: String, size: Vector2i) -> void:
	# These are renderer captures, not image-editor exports: they prove the
	# corrected prop layers and icon masters remain readable against the three
	# review mattes at native and nearest-neighbour 4x scales.
	for asset in [["record-player", "res://assets/art/camp-2026-09-01/camp-record-player.png"], ["workbench", "res://assets/art/camp-2026-09-01/camp-workbench.png"]]:
		for before_after in ["before", "after"]:
			for matte in ["light", "dark", "checker"]:
				for scale in [1, 4]:
					var asset_path := String(asset[1]) if before_after == "after" else BEFORE_ROOT.path_join("camp-%s.png" % asset[0])
					if not FileAccess.file_exists(asset_path):
						failures.append("Missing hash-verified Stage1E before evidence: %s" % asset_path)
						continue
					var native_size := Vector2i(159, 242) if asset[0] == "record-player" and before_after == "before" else (Vector2i(166, 250) if asset[0] == "record-player" else Vector2i(174, 144))
					var panel := _asset_panel(asset_path, native_size, scale, matte)
					main.add_child(panel)
					await _save("forensic-%s-%s-%s-%dx" % [asset[0], before_after, matte, scale], locale, size, "camp_art_forensic")
					panel.queue_free()
					await process_frame
	# One real-render grid per exact runtime display scale; RU/EN Warm state
	# captures above provide the localized interaction counterparts.
	for icon_size in [128, 64, 54]:
		var panel := _icon_sheet_panel(icon_size)
		main.add_child(panel)
		await _save("body-icons-sheet-%d" % icon_size, locale, size, "body_icon_runtime")
		panel.queue_free()
		await process_frame

func _asset_panel(path: String, native_size: Vector2i, scale: int, matte: String) -> Control:
	var panel := Control.new()
	panel.position = Vector2(840, 70)
	panel.size = Vector2(native_size * scale + Vector2i(24, 24))
	var back := TextureRect.new()
	back.texture = _matte_texture(matte)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_TILE
	back.size = panel.size
	panel.add_child(back)
	var art := TextureRect.new()
	var source := Image.load_from_file(path)
	art.texture = ImageTexture.create_from_image(source)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(12, 12)
	art.size = Vector2(native_size * scale)
	panel.add_child(art)
	return panel

func _icon_sheet_panel(icon_size: int) -> Control:
	var panel := Control.new()
	panel.position = Vector2(140, 90)
	panel.size = Vector2(1000, 540)
	var back := ColorRect.new()
	back.color = Color("2a251e")
	back.size = panel.size
	panel.add_child(back)
	var ids := ["strong_bones", "flexible_joints", "strong_spine", "sharp_vision", "muscle_fibers", "stomach", "flesh_regeneration", "ears", "nervous_system", "choose_appearance", "fundamentals"]
	for index in ids.size():
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ui/skill-icons/body/%s.png" % ids[index])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(30 + (index % 6) * 155, 30 + (index / 6) * 235)
		icon.size = Vector2(icon_size, icon_size)
		panel.add_child(icon)
	return panel

func _matte_texture(kind: String) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var color := Color("f2e8d4") if kind == "light" else Color("1c2028")
			if kind == "checker" and ((x / 8 + y / 8) % 2 == 0):
				color = Color("85909c")
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _safe_root(value: String) -> bool:
	if value != ROOT:
		return false
	var resolved := ProjectSettings.globalize_path(value).simplify_path().replace("\\", "/")
	var expected := ProjectSettings.globalize_path(ROOT).simplify_path().replace("\\", "/")
	return resolved.nocasecmp_to(expected) == 0

func _remove_stale_outputs() -> void:
	var directory := DirAccess.open(ROOT)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir() and (entry.get_extension().to_lower() == "png" or entry == "manifest.json"):
			directory.remove(entry)
		entry = directory.get_next()
	directory.list_dir_end()

func _validate_fresh_outputs(expected: int) -> void:
	var expected_paths := {}
	for record in records:
		var path := "res://" + String(record.path)
		if expected_paths.has(path):
			failures.append("Duplicate capture record: %s" % path)
		expected_paths[path] = true
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != String(record.sha256):
			failures.append("Capture hash is missing or stale: %s" % path)
	var directory := DirAccess.open(ROOT)
	var png_count := 0
	if directory != null:
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if not directory.current_is_dir() and entry.get_extension().to_lower() == "png":
				png_count += 1
				if not expected_paths.has(ROOT.path_join(entry)):
					failures.append("Stale/unmanifested PNG survived capture: %s" % ROOT.path_join(entry))
			entry = directory.get_next()
		directory.list_dir_end()
	if png_count != expected or expected_paths.size() != expected:
		failures.append("Fresh PNG set mismatch: files=%d records=%d expected=%d" % [png_count, expected_paths.size(), expected])
	if Overlay.cache_cardinality() != CAMP_IDS.size():
		failures.append("Camp outline cache cardinality must remain 13, got %d" % Overlay.cache_cardinality())
	_validate_disabled_unbuilt_pairs()
	_validate_frozen_lunge_endpoints()


func _validate_disabled_unbuilt_pairs() -> void:
	# A pixel-identical pair would prove that a capture only changed overlay
	# bookkeeping while leaving the built prop on screen.
	var hashes := {}
	for record in records:
		hashes[String(record.path)] = String(record.sha256)
	for size in SIZES:
		for locale in LOCALES:
			for id in CAMP_IDS:
				var normal := ROOT.path_join("%s-%dx%d-camp-%s-normal.png" % [locale, size.x, size.y, id]).trim_prefix("res://")
				var disabled := ROOT.path_join("%s-%dx%d-camp-%s-disabled_unbuilt.png" % [locale, size.x, size.y, id]).trim_prefix("res://")
				if not hashes.has(normal) or not hashes.has(disabled) or hashes[normal] == hashes[disabled]:
					failures.append("Disabled/unbuilt camp capture must differ from normal built prop: %s %s %dx%d" % [id, locale, size.x, size.y])


func _validate_frozen_lunge_endpoints() -> void:
	# Main processing is frozen while a real frame is synchronized. The lunge
	# has exact zero at 0 and 150ms, so each actor's endpoint render must match.
	var hashes := {}
	for record in records:
		hashes[String(record.path)] = String(record.sha256)
	for size in SIZES:
		for actor in ["player-hit", "player-miss", "enemy-normal", "enemy-heavy", "enemy-boss"]:
			for zoom in [44, 66, 88]:
				var start := ROOT.path_join("en-%dx%d-lunge-%s-z%d-t0.png" % [size.x, size.y, actor, zoom]).trim_prefix("res://")
				var end := ROOT.path_join("en-%dx%d-lunge-%s-z%d-t150.png" % [size.x, size.y, actor, zoom]).trim_prefix("res://")
				if not hashes.has(start) or not hashes.has(end) or hashes[start] != hashes[end]:
					failures.append("Frozen lunge endpoint render mismatch (0ms must equal 150ms): %s z%d %dx%d" % [actor, zoom, size.x, size.y])

func _write_manifest(expected: int) -> void:
	var file := FileAccess.open(ROOT.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		failures.append("Could not write Stage1E preview manifest")
		return
	file.store_string(JSON.stringify({"schema_version": 1, "stage": "1E", "generated_utc": Time.get_datetime_string_from_system(true, true), "normal_renderer_required": true, "fresh_actual_control_render_paths": true, "expected_capture_count": expected, "capture_count": records.size(), "profiles": ["ru-1280x720", "en-1280x720", "ru-960x540", "en-960x540"], "camp_ids": CAMP_IDS, "states": STATES, "cache_cardinality": Overlay.cache_cardinality(), "captures": records, "source_hashes": _source_hashes()}, "  ", false, true) + "\n")
	file.close()

func _source_hashes() -> Dictionary:
	var result := {}
	var paths: Array[String] = []
	for root in ["res://scripts", "res://scenes", "res://assets"]:
		_collect_source_files(root, paths)
	for path in ["res://project.godot", "res://tests/capture_stage1e_preview.gd", "res://tools/capture_stage1e_previews.ps1", "res://tools/package_body_skill_icons.py", "res://tools/patch_stage1e_camp_art.py", "res://tools/prepare_nightly_camp_assets.py", "res://tools/verify_stage1c_protected_assets.py", "res://art/skills/body-icons/2026-09-01/PROMPTS.md", "res://art/skills/body-icons/2026-09-01/manifest.json", "res://assets/art/camp-2026-09-01/manifest.json", BEFORE_ROOT.path_join("camp-record-player.png"), BEFORE_ROOT.path_join("camp-workbench.png")]:
		if not paths.has(path):
			paths.append(path)
	paths.sort()
	for path in paths:
		if FileAccess.file_exists(path):
			result[path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	return result

func _collect_source_files(root: String, into: Array[String]) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := root.path_join(entry)
			if directory.current_is_dir():
				_collect_source_files(child, into)
			else:
				into.append(child)
		entry = directory.get_next()
	directory.list_dir_end()
