extends SceneTree

## Technical packaging only: preserve ImageGen's RGBA, proportions and artwork.
## Never removes a matte, paints pixels, changes colours or replaces default art.
const PACK := "res://art/characters/male/"
const MANIFEST := PACK + "manifest.json"
const FORM_IDS := ["skeleton", "zombie", "ghoul", "revenant", "almost_human"]
const KINDS := ["fullbody", "head"]
const BODY_SIZE := Vector2i(264, 704)
const HEAD_SIZE := Vector2i(264, 264)
const BODY_SAFE := Rect2i(11, 12, 242, 684)
const HEAD_SAFE := Rect2i(4, 4, 256, 256)
const BODY_CROP := Rect2i(7, 8, 250, 692)
const BODY_ANCHOR := Vector2(132, 696)
const NORMALIZATION := "Transparent-margin crop; one uniform scale per source using common anatomical landmarks; premultiplied-alpha Lanczos interpolation; transparent padding only. No matte removal, alpha thresholding, recolouring, sharpening or repainting."
var failures: Array[String] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var result := 1
	if args == PackedStringArray(["--self-test"]):
		result = _self_test()
	elif args == PackedStringArray(["--check"]):
		result = _check()
	elif args == PackedStringArray(["--rebuild"]):
		var previous := _read_json(MANIFEST)
		if previous.has("recipe"):
			result = _build(previous.recipe)
	elif args.size() == 2 and args[0] == "--build":
		result = _build(_read_json(args[1]))
	elif args.size() >= 2 and args[0] == "--source-info":
		result = _source_info(args.slice(1))
	else:
		push_error("Use -- --self-test | --check | --rebuild | --build source-input.json | --source-info source.png ...")
	for failure in failures:
		push_error(failure)
	quit(result)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		failures.append("Missing JSON: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		failures.append("Expected a JSON object: " + path)
		return {}
	return parsed


func _file_id(id: String) -> String:
	return id.replace("_", "-")


func _source_path(kind: String, id: String) -> String:
	return PACK + "sources/" + kind + "/form-" + _file_id(id) + ".png"


func _runtime_path(kind: String, id: String) -> String:
	var folder := "assets/ui/character-fullbody/male/" if kind == "fullbody" else "assets/portraits/male/"
	return "res://" + folder + "form-" + _file_id(id) + ".png"


func _master_path(kind: String, id: String) -> String:
	return PACK + "masters/" + kind + "/form-" + _file_id(id) + ".png"


func _relative(path: String) -> String:
	return path.trim_prefix("res://")


func _rect_array(rect: Rect2i) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _size_array(size: Vector2i) -> Array:
	return [size.x, size.y]


func _sha_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _asset_record(path: String, image: Image, bytes: PackedByteArray) -> Dictionary:
	return {
		"path": _relative(path), "sha256": _sha_bytes(bytes),
		"size": _size_array(image.get_size()), "mode": "RGBA8" if image.get_format() == Image.FORMAT_RGBA8 else "Godot format %d" % image.get_format(),
		"alpha_bounds_xywh": _rect_array(image.get_used_rect()),
		"transparent": image.detect_alpha() != Image.ALPHA_NONE,
	}


func _load_entries(recipe: Dictionary) -> Array[Dictionary]:
	var loaded: Array[Dictionary] = []
	if not recipe.get("entries", null) is Array or recipe.entries.size() != 10:
		failures.append("The pack requires exactly five fullbodies and five heads.")
		return loaded
	var seen := {}
	for input: Variant in recipe.entries:
		if not input is Dictionary:
			failures.append("Every source entry must be an object.")
			continue
		var entry: Dictionary = input.duplicate(true)
		var id := String(entry.get("id", ""))
		var kind := String(entry.get("kind", ""))
		var key := kind + ":" + id
		if id not in FORM_IDS or kind not in KINDS or seen.has(key):
			failures.append("Unknown/duplicate source: " + key)
			continue
		seen[key] = true
		var source_path := String(entry.get("source", ""))
		if not FileAccess.file_exists(source_path) or String(entry.get("prompt", "")).is_empty():
			failures.append("Missing source or exact prompt for " + key)
			continue
		var original := Image.load_from_file(source_path)
		if original == null or original.is_empty():
			failures.append("Unreadable source: " + key)
			continue
		var crop := original.get_used_rect()
		if original.detect_alpha() == Image.ALPHA_NONE or crop.size.x <= 0 or crop.size.y <= 0:
			failures.append("Source needs genuine non-empty generated transparency: " + key)
			continue
		if crop.position.x <= 0 or crop.position.y <= 0 or crop.end.x >= original.get_width() or crop.end.y >= original.get_height():
			failures.append("Source touches its canvas boundary; inspect/regenerate, never crop its artwork: " + key)
			continue
		var landmarks: Dictionary = entry.get("landmarks", {})
		if kind == "head":
			if not landmarks.get("eye_midpoint_xy", null) is Array or landmarks.eye_midpoint_xy.size() != 2 or not landmarks.has("chin_y"):
				failures.append("Reviewed eye midpoint and chin landmark required: " + key)
				continue
			var eye := Vector2(float(landmarks.eye_midpoint_xy[0]), float(landmarks.eye_midpoint_xy[1]))
			var eye_to_chin := float(landmarks.chin_y) - eye.y
			if eye_to_chin <= 0.0 or not Rect2(crop).has_point(eye):
				failures.append("Invalid head landmarks: " + key)
				continue
			entry["anchor"] = eye
			entry["anatomical_span"] = eye_to_chin
		else:
			var center := float(landmarks.get("center_x", crop.get_center().x))
			var crown := float(landmarks.get("crown_y", crop.position.y))
			var feet := float(landmarks.get("feet_y", crop.end.y))
			if center <= crop.position.x or center >= crop.end.x or feet <= crown or absf(feet - crop.end.y) > 2.0:
				failures.append("Invalid body landmarks / visible artwork below soles: " + key)
				continue
			entry["anchor"] = Vector2(center, feet)
			entry["anatomical_span"] = feet - crown
		entry["image"] = original
		entry["crop"] = crop
		loaded.append(entry)
	loaded.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.kind != b.kind:
			return KINDS.find(a.kind) < KINDS.find(b.kind)
		return FORM_IDS.find(a.id) < FORM_IDS.find(b.id))
	return loaded


func _alignment(recipe: Dictionary, entries: Array[Dictionary]) -> Dictionary:
	var body_height := float(recipe.get("body_height_px", 684.0))
	var eye_array: Array = recipe.get("head_eye_midpoint_xy", [132.0, 118.0])
	var eye := Vector2(float(eye_array[0]), float(eye_array[1]))
	var head_span := float(recipe.get("head_eye_to_chin_px", 60.0))
	# Leave one extra pixel in fitting calculations for integer resampling.
	for entry in entries:
		var crop: Rect2i = entry.crop
		var anchor: Vector2 = entry.anchor
		var span := float(entry.anatomical_span)
		if entry.kind == "fullbody":
			body_height = minf(body_height, span * 120.0 / (anchor.x - crop.position.x))
			body_height = minf(body_height, span * 120.0 / (crop.end.x - anchor.x))
			body_height = minf(body_height, span * 683.0 / crop.size.y)
		else:
			for extent in [
				[anchor.x - crop.position.x, eye.x - 5.0],
				[crop.end.x - anchor.x, 259.0 - eye.x],
				[anchor.y - crop.position.y, eye.y - 5.0],
				[crop.end.y - anchor.y, 259.0 - eye.y],
			]:
				if float(extent[0]) > 0.0:
					head_span = minf(head_span, span * float(extent[1]) / float(extent[0]))
	return {"body_height_px": body_height, "head_eye_midpoint_xy": [eye.x, eye.y], "head_eye_to_chin_px": head_span}


func _resample(source: Image, size: Vector2i) -> Image:
	var result := source.duplicate() as Image
	if result.get_size() == size:
		result.convert(Image.FORMAT_RGBA8)
		return result
	# Same premultiplied filtering contract as normalize_stage1_assets.gd.
	# Multiply floating-point channels explicitly: Image.premultiply_alpha()
	# does not premultiply RGBAF reliably in the pinned Godot runtime.
	result.convert(Image.FORMAT_RGBAF)
	for y in range(result.get_height()):
		for x in range(result.get_width()):
			var pixel := result.get_pixel(x, y)
			pixel.r *= pixel.a
			pixel.g *= pixel.a
			pixel.b *= pixel.a
			result.set_pixel(x, y, pixel)
	result.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	for y in range(result.get_height()):
		for x in range(result.get_width()):
			var pixel := result.get_pixel(x, y)
			if pixel.a > 0.0:
				pixel.r /= pixel.a
				pixel.g /= pixel.a
				pixel.b /= pixel.a
			result.set_pixel(x, y, pixel)
	result.convert(Image.FORMAT_RGBA8)
	return result


func _normalize(entry: Dictionary, alignment: Dictionary, multiplier: int) -> Dictionary:
	var body: bool = entry.kind == "fullbody"
	var size := (BODY_SIZE if body else HEAD_SIZE) * multiplier
	var target_anchor := BODY_ANCHOR if body else Vector2(alignment.head_eye_midpoint_xy[0], alignment.head_eye_midpoint_xy[1])
	target_anchor *= multiplier
	var target_span := float(alignment.body_height_px if body else alignment.head_eye_to_chin_px) * multiplier
	var scale := target_span / float(entry.anatomical_span)
	var crop: Rect2i = entry.crop
	var source: Image = entry.image.get_region(crop)
	var resized_size := Vector2i(maxi(1, roundi(source.get_width() * scale)), maxi(1, roundi(source.get_height() * scale)))
	var resized := _resample(source, resized_size)
	var visible := resized.get_used_rect()
	var actual_scale := Vector2(float(resized_size.x) / crop.size.x, float(resized_size.y) / crop.size.y)
	var offset := Vector2i((target_anchor - (entry.anchor - Vector2(crop.position)) * actual_scale).round())
	# Re-anchor only a quantized empty bottom margin, never rescale/repaint a form.
	if body:
		offset.y = roundi(target_anchor.y) - visible.end.y
	var output := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	output.blit_rect(resized, Rect2i(Vector2i.ZERO, resized_size), offset)
	var placed_visible := Rect2i(visible.position + offset, visible.size)
	if not Rect2i(Vector2i.ZERO, size).encloses(placed_visible):
		failures.append("Normalization would clip artwork: " + String(entry.kind) + ":" + String(entry.id))
	return {
		"image": output, "uniform_scale": scale,
		"resampled_size": _size_array(resized_size), "offset_xy": [offset.x, offset.y],
		"source_crop_xywh": _rect_array(crop),
		"placed_anchor_xy": [offset.x + (entry.anchor.x - crop.position.x) * actual_scale.x, offset.y + (entry.anchor.y - crop.position.y) * actual_scale.y],
		"anatomical_span_px": float(entry.anatomical_span) * actual_scale.y,
		"integer_rounding_only": true,
	}


func _protected_assets() -> Dictionary:
	var hashes := {}
	for id: String in FORM_IDS:
		for folder: String in ["assets/ui/character-fullbody/form-", "assets/portraits/form-", "assets/dungeon/player-"]:
			var path := folder + _file_id(id) + ".png"
			if not FileAccess.file_exists("res://" + path):
				failures.append("Missing protected default art: " + path)
			else:
				hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes


func _build(recipe: Dictionary) -> int:
	if recipe.is_empty():
		return 1
	if recipe.get("canonical_male_approved", false) != true or recipe.get("generation_mode", "") != "built-in image_gen":
		failures.append("Recipe must record the user-approved canonical male and built-in image_gen provenance.")
		return 1
	var canonical_path := String(recipe.get("canonical_source", ""))
	if not FileAccess.file_exists(canonical_path):
		failures.append("Missing approved canonical sheet.")
		return 1
	var entries := _load_entries(recipe)
	var protected := _protected_assets()
	if not failures.is_empty():
		return 1
	var alignment := _alignment(recipe, entries)
	if alignment.body_height_px <= 0.0 or alignment.head_eye_to_chin_px <= 0.0:
		failures.append("The source landmarks do not fit the safe output area.")
		return 1
	var files := {}
	var records: Array[Dictionary] = []
	var local_recipe := recipe.duplicate(true)
	local_recipe["entries"] = []
	local_recipe["canonical_source"] = PACK + "sources/approved-male-five-stages.png"
	files[local_recipe.canonical_source] = FileAccess.get_file_as_bytes(canonical_path)
	var runtime_images := {}
	for entry in entries:
		var id := String(entry.id)
		var kind := String(entry.kind)
		var source_path := _source_path(kind, id)
		var original: Image = entry.image
		var source_bytes := FileAccess.get_file_as_bytes(entry.source)
		files[source_path] = source_bytes
		var local_entry: Dictionary = {"id": id, "kind": kind, "source": source_path, "prompt": entry.prompt, "landmarks": entry.get("landmarks", {})}
		local_recipe.entries.append(local_entry)
		var record := {
			"id": id, "file_id": _file_id(id), "kind": kind,
			"runtime_connected": false, "generation_mode": "built-in image_gen", "prompt": entry.prompt,
			"source": _asset_record(source_path, original, source_bytes),
			"source_original_filename": String(entry.source).get_file(),
			"landmarks": entry.get("landmarks", {}), "normalization": NORMALIZATION,
		}
		for multiplier: int in [1, 4]:
			var normalized := _normalize(entry, alignment, multiplier)
			var target: Image = normalized.image
			var destination := _runtime_path(kind, id) if multiplier == 1 else _master_path(kind, id)
			var bytes := target.save_png_to_buffer()
			files[destination] = bytes
			var detail := _asset_record(destination, target, bytes)
			normalized.erase("image")
			detail["transform"] = normalized
			record["runtime" if multiplier == 1 else "master"] = detail
			_validate_canvas(target, kind, multiplier, destination)
			if multiplier == 1:
				runtime_images[kind + ":" + id] = target
		records.append(record)
		print("Prepared %s %s" % [kind, id])
	if not failures.is_empty():
		return 1
	var preview_records := _previews(runtime_images, files)
	var file_hashes := {}
	for path: String in files:
		file_hashes[_relative(path)] = _sha_bytes(files[path])
	var manifest := {
		"schema_version": 1, "canonical_male_approved": true, "approval_date": "2026-08-31",
		"runtime_connected": false, "source_artwork_unchanged": true, "generation_mode": "built-in image_gen",
		"normalization": NORMALIZATION, "recipe": local_recipe,
		"canonical_sheet": {"path": _relative(local_recipe.canonical_source), "sha256": _sha_bytes(files[local_recipe.canonical_source]), "source_original_filename": canonical_path.get_file()},
		"alignment": alignment, "body_source_crop_xywh": _rect_array(BODY_CROP),
		"body_anchor_xy": [132, 696], "body_safe_bounds_xywh": _rect_array(BODY_SAFE),
		"head_safe_bounds_xywh": _rect_array(HEAD_SAFE), "master_scale": 4,
		"protected_default_assets": protected, "assets": records, "previews": preview_records,
		"generated_file_hashes": file_hashes,
		"import_settings": {"compress_mode": "lossless", "mipmaps": false, "fix_alpha_border": true},
		"limitations": ["No runtime selection or renderer integration is included.", "Technical masters may interpolate lower-resolution sources; they do not add painted detail.", "Semantic face/body landmark accuracy remains subject to visual review."]
	}
	var previous := _read_json(MANIFEST) if FileAccess.file_exists(MANIFEST) else {}
	var previous_hashes: Dictionary = previous.get("generated_file_hashes", {})
	if not previous.is_empty() and previous.get("protected_default_assets", {}) != protected:
		failures.append("Protected default art differs from the previous pack baseline.")
	# Complete preflight: an unknown existing file or edited previous export is never overwritten.
	for path: String in files:
		if FileAccess.file_exists(path):
			var existing := FileAccess.get_sha256(path)
			if existing != file_hashes[_relative(path)] and existing != previous_hashes.get(_relative(path), ""):
				failures.append("Refusing to overwrite untracked/edited art: " + path)
	if not failures.is_empty():
		return 1
	for path: String in files:
		if not _write_bytes(path, files[path]):
			return 1
	if _protected_assets() != protected:
		failures.append("Protected default art changed during packaging.")
		return 1
	if not _write_bytes(MANIFEST, (JSON.stringify(manifest, "\t", true, true) + "\n").to_utf8_buffer()):
		return 1
	print("MALE ASSET PACK BUILT: 5 fullbodies, 5 heads, 10 technical masters; common height=%.3f, eye-to-chin=%.3f" % [alignment.body_height_px, alignment.head_eye_to_chin_px])
	return 0


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) == _sha_bytes(bytes):
		return true
	var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if result != OK:
		failures.append("Cannot create output folder: " + path.get_base_dir())
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write " + path)
		return false
	file.store_buffer(bytes)
	return true


func _validate_canvas(image: Image, kind: String, multiplier: int, label: String) -> void:
	var expected := (BODY_SIZE if kind == "fullbody" else HEAD_SIZE) * multiplier
	var safe := BODY_SAFE if kind == "fullbody" else HEAD_SAFE
	safe = Rect2i(safe.position * multiplier, safe.size * multiplier)
	var used := image.get_used_rect()
	if image.get_format() != Image.FORMAT_RGBA8 or image.get_size() != expected:
		failures.append("Wrong canvas/format: " + label)
	if used.size.x <= 0 or used.size.y <= 0 or not safe.encloses(used):
		failures.append("Alpha outside safe area or empty: " + label + " " + str(used))
	if kind == "fullbody" and used.end.y != 696 * multiplier:
		failures.append("Incorrect foot baseline: " + label)
	if image.detect_alpha() == Image.ALPHA_NONE:
		failures.append("Missing transparency: " + label)


func _background(size: Vector2i, theme: String) -> Image:
	var result := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var color := Color("1e2025") if theme == "dark" else Color("f4f1e8")
	if theme == "checker":
		color = Color("b5b9be")
	result.fill(color)
	if theme == "checker":
		for y in range(0, size.y, 12):
			for x in range(0, size.x, 12):
				if (x / 12 + y / 12) % 2 == 1:
					result.fill_rect(Rect2i(x, y, mini(12, size.x - x), mini(12, size.y - y)), Color("d9dce0"))
	return result


func _number(image: Image, index: int, position: Vector2i, color: Color) -> void:
	# Diagnostic labels only, outside the art; no font/runtime dependency.
	var digits := ["111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001", "111100111001111"]
	for digit_index in range(2):
		var value: int = 0 if digit_index == 0 else index
		for pixel in range(15):
			if digits[value][pixel] == "1":
				image.fill_rect(Rect2i(position.x + digit_index * 10 + (pixel % 3) * 2, position.y + (pixel / 3) * 2, 2, 2), color)


func _previews(images: Dictionary, files: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for kind: String in KINDS:
		var sizes: Array[Vector2i] = [Vector2i(178, 493), Vector2i(134, 370)] if kind == "fullbody" else [Vector2i(264, 264), Vector2i(88, 88), Vector2i(66, 66), Vector2i(44, 44)]
		for size in sizes:
			for theme: String in ["dark", "light", "checker"]:
				var sheet := _background(Vector2i(24 + 5 * (size.x + 24), size.y + 56), theme)
				for index in range(FORM_IDS.size()):
					var source: Image = images[kind + ":" + FORM_IDS[index]]
					if kind == "fullbody":
						source = source.get_region(BODY_CROP)
					var thumb := _resample(source, size)
					var x := 24 + index * (size.x + 24)
					sheet.blend_rect(thumb, Rect2i(Vector2i.ZERO, size), Vector2i(x, 12))
					_number(sheet, index + 1, Vector2i(x + size.x / 2 - 8, size.y + 27), Color("ebe7de") if theme == "dark" else Color("1e2025"))
				var path := PACK + "previews/%s-%dx%d-%s.png" % [kind, size.x, size.y, theme]
				files[path] = sheet.save_png_to_buffer()
				records.append({"path": _relative(path), "kind": kind, "display_size": _size_array(size), "theme": theme, "order": FORM_IDS})
	return records


func _check() -> int:
	var manifest := _read_json(MANIFEST)
	if manifest.is_empty():
		return 1
	if manifest.get("runtime_connected", true) or not manifest.get("canonical_male_approved", false):
		failures.append("Canonical approval/runtime separation not recorded.")
	for path: String in manifest.get("generated_file_hashes", {}):
		if FileAccess.get_sha256("res://" + path) != manifest.generated_file_hashes[path]:
			failures.append("File SHA mismatch/missing: " + path)
	if _protected_assets() != manifest.get("protected_default_assets", {}):
		failures.append("Protected pre-existing default art differs from the delivery baseline.")
	var entries := _load_entries(manifest.get("recipe", {}))
	if not failures.is_empty():
		return 1
	var alignment := _alignment(manifest.recipe, entries)
	if alignment != manifest.get("alignment", {}):
		failures.append("Alignment does not match the retained recipe.")
	if manifest.get("assets", []).size() != 10 or manifest.get("previews", []).size() != 18:
		failures.append("Pack must contain 10 assets and the complete 18-sheet preview matrix.")
	for entry in entries:
		for multiplier: int in [1, 4]:
			var path := _runtime_path(entry.kind, entry.id) if multiplier == 1 else _master_path(entry.kind, entry.id)
			var actual := Image.load_from_file(path)
			if actual == null or actual.is_empty():
				failures.append("Missing final image: " + path)
				continue
			_validate_canvas(actual, entry.kind, multiplier, path)
			var expected: Image = _normalize(entry, alignment, multiplier).image
			if actual.get_data() != expected.get_data():
				failures.append("Non-reproducible transform: " + path)
			if multiplier == 1 and FileAccess.file_exists(path + ".import"):
				var config := ConfigFile.new()
				config.load(path + ".import")
				if config.get_value("params", "compress/mode", -1) != 0 or config.get_value("params", "mipmaps/generate", true) or not config.get_value("params", "process/fix_alpha_border", false):
					failures.append("Incorrect UI import settings: " + path)
	if not failures.is_empty():
		return 1
	print("MALE ASSET CHECK PASSED: 10 RGBA exports + 10 reproducible masters; 18 previews; all source/output SHA256; 15 protected defaults unchanged")
	return 0


func _source_info(paths: PackedStringArray) -> int:
	for path in paths:
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			failures.append("Unreadable image: " + path)
			continue
		print(JSON.stringify({"path": path, "size": _size_array(image.get_size()), "format": image.get_format(), "alpha_bounds_xywh": _rect_array(image.get_used_rect()), "alpha": image.detect_alpha(), "sha256": FileAccess.get_sha256(path)}))
	return 0 if failures.is_empty() else 1


func _self_test() -> int:
	# Synthetic code-native fixtures are only in memory and never become assets.
	var source := Image.create_empty(100, 200, false, Image.FORMAT_RGBA8)
	source.fill(Color(1, 0, 0, 0))
	source.fill_rect(Rect2i(30, 10, 40, 180), Color(0, 1, 0, 1))
	var tiny := _resample(source, Vector2i(10, 20))
	var has_fractional_alpha := false
	var leaked := false
	for y in range(tiny.get_height()):
		for x in range(tiny.get_width()):
			var pixel := tiny.get_pixel(x, y)
			if pixel.a > 0.0:
				if pixel.r > 0.004 or pixel.b > 0.004 or pixel.g < 0.996:
					if not leaked:
						failures.append("Premultiplied filter leaked transparent RGB at (%d,%d): %s" % [x, y, pixel])
					leaked = true
				has_fractional_alpha = has_fractional_alpha or pixel.a < 1.0
	if not has_fractional_alpha:
		failures.append("Resampling incorrectly eliminated fractional alpha.")
	var entries: Array[Dictionary] = []
	for index in range(5):
		var body := source.duplicate() as Image
		if index == 4:
			body.fill_rect(Rect2i(10, 10, 80, 180), Color.WHITE)
		entries.append({"id": FORM_IDS[index], "kind": "fullbody", "image": body, "crop": body.get_used_rect(), "anchor": Vector2(50, 190), "anatomical_span": 180.0})
	var alignment := _alignment({}, entries)
	if absf(float(alignment.body_height_px) - 540.0) > 0.001:
		failures.append("A wider final cape must constrain the common scale for every body.")
	for entry in entries:
		var result := _normalize(entry, alignment, 1)
		_validate_canvas(result.image, "fullbody", 1, "synthetic " + String(entry.id))
		if absf(float(result.anatomical_span_px) - 540.0) > 0.01:
			failures.append("Body stages lost their common anatomical height.")
	var head := Image.create_empty(100, 100, false, Image.FORMAT_RGBA8)
	head.fill_rect(Rect2i(10, 10, 80, 80), Color(0.8, 0.7, 0.5, 1))
	var head_entry := {"id": "skeleton", "kind": "head", "image": head, "crop": head.get_used_rect(), "anchor": Vector2(50, 40), "anatomical_span": 20.0}
	var head_alignment := _alignment({}, [head_entry])
	var head_result := _normalize(head_entry, head_alignment, 1)
	_validate_canvas(head_result.image, "head", 1, "synthetic head")
	if absf(float(head_result.placed_anchor_xy[0]) - 132.0) > 0.5 or absf(float(head_result.placed_anchor_xy[1]) - 118.0) > 0.5:
		failures.append("Head eye-line anchor must be preserved within integer rounding.")
	if not failures.is_empty():
		return 1
	print("MALE PACKAGING SELF-TEST PASSED: premultiplied-alpha interpolation, common body scale, safe canvases, foot baseline and head eye alignment")
	return 0
