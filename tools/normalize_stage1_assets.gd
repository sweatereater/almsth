extends SceneTree

## Technical packaging of approved ImageGen RGBA outputs. No matte removal,
## alpha thresholding, color changes, repainting or overwrite of old assets.
const OUTPUT_MANIFEST := "res://docs/stage1-asset-manifest.json"
const IDS := {
	"E01": ["assets/dungeon/enemy-blind-scavenger.png", "world", 264, 264],
	"E03": ["assets/dungeon/enemy-arachnid.png", "world", 264, 264],
	"E06": ["assets/dungeon/enemy-bone-crossbowman.png", "world", 264, 264],
	"E09": ["assets/dungeon/enemy-slag-smith.png", "world", 264, 264],
	"I01": ["assets/items/item-rusty-sabre.png", "icon", 132, 132],
	"I04": ["assets/items/item-short-crossbow.png", "icon", 132, 132],
	"I05": ["assets/items/item-bone-buckler.png", "icon", 132, 132],
	"I06": ["assets/items/item-gravediggers-lamp.png", "icon", 132, 132],
	"I07": ["assets/items/item-watchmans-cap.png", "icon", 132, 132],
	"I08": ["assets/items/item-archivists-mask.png", "icon", 132, 132],
	"I09": ["assets/items/item-wanderers-gambeson.png", "icon", 132, 132],
	"I10": ["assets/items/item-lamellar-vest.png", "icon", 132, 132],
	"I11": ["assets/items/item-scouts-trousers.png", "icon", 132, 132],
	"I12": ["assets/items/item-heavy-leg-wraps.png", "icon", 132, 132],
	"I15": ["assets/items/item-pilgrims-boots.png", "icon", 132, 132],
	"I17": ["assets/items/item-aiming-ring.png", "icon", 132, 132],
	"I18": ["assets/items/item-thickblood-ring.png", "icon", 132, 132],
	"I19": ["assets/items/item-expedition-backpack.png", "icon", 132, 132],
	"O06": ["assets/dungeon/chest-crypt.png", "world", 264, 264],
	"D01a": ["assets/dungeon/decor-cocoon-1.png", "decor", 264, 264],
	"D01b": ["assets/dungeon/decor-cocoon-2.png", "decor", 264, 264],
	"D02a": ["assets/dungeon/decor-mosaic-1.png", "tile", 264, 264],
	"D02b": ["assets/dungeon/decor-mosaic-2.png", "tile", 264, 264],
	"D02c": ["assets/dungeon/decor-mosaic-3.png", "tile", 264, 264],
	"B02": ["assets/art/camp-kettle.png", "camp", 132, 104],
	"B03": ["assets/art/camp-bunk.png", "camp", 248, 100],
	"B05": ["assets/art/camp-mural.png", "decal", 152, 84],
}
const RETAINED_BRIEFS := {
	"E06": "Retained art brief, not the unavailable exact original prompt: Bone Crossbowman. Weathered skeletal marksman holding a short crossbow in a readable three-quarter full-body pose; restrained dark fantasy painted game sprite; real RGBA cutout; final264x264, lower-center anchor132,260, one-cell footprint.",
	"I01": "Retained art brief, not the unavailable exact original prompt: Rusty Sabre. A single worn curved iron sabre with visibly rusted blade, compact readable painterly inventory silhouette; real RGBA, no scene/text; final132x132 with8px clear padding.",
	"I04": "Retained art brief, not the unavailable exact original prompt: Short Crossbow. One compact wooden and iron crossbow with short limbs and visible stock, dark muted painterly materials; real RGBA, no scene/text; final132x132 with8px clear padding.",
	"I05": "Retained art brief, not the unavailable exact original prompt: Bone Buckler. A compact small round shield made of weathered bone and dark bindings, readable silhouette, dark fantasy painterly inventory asset; real RGBA, no scene/text; final132x132 with8px clear padding.",
	"I06": "Retained art brief, not the unavailable exact original prompt: Gravedigger's Lamp. A worn portable grave lamp, dark metal frame and handle with a small warm light, restrained painterly inventory asset; real RGBA, no scene/text; final132x132 with8px clear padding.",
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass exactly one approved source manifest after --")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not parsed is Array or parsed.size() != IDS.size():
		push_error("Expected all27 approved sources")
		quit(1)
		return
	var records: Array[Dictionary] = []
	var previous_exports := {}
	if FileAccess.file_exists(OUTPUT_MANIFEST):
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT_MANIFEST))
		if previous is Array:
			for record in previous:
				previous_exports[record.path] = record.runtime_sha256
	# Preflight every source and destination before writing any final resource.
	var images := {}
	for entry in parsed:
		if not IDS.has(entry.id) or images.has(entry.id):
			push_error("Unknown/duplicate asset: " + str(entry.id))
			quit(1)
			return
		var destination := "res://" + String(IDS[entry.id][0])
		if FileAccess.file_exists(destination) and FileAccess.get_sha256(destination) != previous_exports.get(String(IDS[entry.id][0]), ""):
			push_error("Refusing to overwrite existing asset: " + destination)
			quit(1)
			return
		var source := Image.load_from_file(entry.source)
		if source == null or source.is_empty():
			push_error("Missing source: " + str(entry.source))
			quit(1)
			return
		if IDS[entry.id][1] != "tile" and source.detect_alpha() == Image.ALPHA_NONE:
			push_error("Non-transparent source; must be fixed through ImageGen: " + str(entry.id))
			quit(1)
			return
		images[entry.id] = source
	for entry in parsed:
		var contract: Array = IDS[entry.id]
		var kind := String(contract[1])
		var size := Vector2i(contract[2], contract[3])
		var original: Image = images[entry.id]
		var source := original.duplicate() as Image
		var crop := Rect2i(Vector2i.ZERO, source.get_size()) if kind == "tile" else source.get_used_rect()
		var padding := 8 if kind in ["icon", "decal"] else 4
		var target: Image
		if kind == "tile":
			source.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
			source.convert(Image.FORMAT_RGB8)
			target = source
		else:
			source = source.get_region(crop)
			var scale := minf(float(size.x - padding * 2) / source.get_width(), float(size.y - padding * 2) / source.get_height())
			# Filter premultiplied values so invisible source RGB cannot bleed into
			# the cutout edge. This changes no artwork, only alpha interpolation.
			source.convert(Image.FORMAT_RGBAF)
			source.premultiply_alpha()
			source.resize(maxi(1, roundi(source.get_width() * scale)), maxi(1, roundi(source.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
			for y in range(source.get_height()):
				for x in range(source.get_width()):
					var pixel := source.get_pixel(x, y)
					if pixel.a > 0.0:
						pixel.r /= pixel.a
						pixel.g /= pixel.a
						pixel.b /= pixel.a
					source.set_pixel(x, y, pixel)
			source.convert(Image.FORMAT_RGBA8)
			# Downsampling can quantize very faint outer pixels to alpha zero.
			# Re-anchor the resulting visible cutout without filtering it again.
			source = source.get_region(source.get_used_rect())
			target = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
			var offset := Vector2i((size.x - source.get_width()) / 2, (size.y - source.get_height()) / 2)
			if kind in ["world", "camp"]:
				offset.y = size.y - padding - source.get_height()
			target.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), offset)
		var destination := "res://" + String(contract[0])
		if target.save_png(destination) != OK:
			push_error("Could not save " + destination)
			quit(1)
			return
		var alpha_rect := target.get_used_rect()
		records.append({
			"id": entry.id, "path": contract[0], "kind": kind,
			"source_file": String(entry.source).get_file(),
			"source_sha256": FileAccess.get_sha256(entry.source),
			"source_size": [original.get_width(), original.get_height()],
			"runtime_size": [size.x, size.y],
			"runtime_sha256": FileAccess.get_sha256(destination),
			"alpha_bounds": [alpha_rect.position.x, alpha_rect.position.y, alpha_rect.size.x, alpha_rect.size.y],
			"generation": "built-in image_gen",
			"prompt_status": "exact retained prompt" if entry.prompt != null else "retained art brief; exact early prompt unavailable",
			"prompt": entry.prompt if entry.prompt != null else RETAINED_BRIEFS[entry.id],
			"normalization": "Premultiplied-alpha Lanczos downscale only; transparent empty-margin crop and deterministic padding, no background removal or alpha cleanup" if kind != "tile" else "Full-area Lanczos downscale to RGB8; no crop, recolor or edge painting",
		})
		print("%s -> %s %s alpha=%s" % [entry.id, destination, size, alpha_rect])
	var manifest := FileAccess.open(OUTPUT_MANIFEST, FileAccess.WRITE)
	manifest.store_string(JSON.stringify(records, "\t"))
	print("STAGE1 ASSETS NORMALIZED: %d" % records.size())
	quit(0)
