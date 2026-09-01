extends SceneTree

## Mechanical crop/registration/export only. Never removes or repaints pixels.
const SOURCE := "res://art/characters/female/map-ghoul/walk-alpha.png"
const OUTPUT := "res://assets/dungeon/female-ghoul/frames/"
# Register every pose to the same belt/hip landmark, with one source-sheet scale.
# Each source cell is 418 px wide; the second row begins at y=445.
const RECIPE := [
	{"rect": Rect2i(0, 0, 418, 445), "hip": Vector2(187, 188)},
	{"rect": Rect2i(0, 445, 418, 450), "hip": Vector2(168, 188)},
	{"rect": Rect2i(836, 445, 418, 450), "hip": Vector2(190, 188)},
	{"rect": Rect2i(418, 445, 418, 450), "hip": Vector2(170, 188)},
]
const SCALE := 0.552
const RUNTIME_HIP := Vector2(120, 116)


func _init() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null or source.get_format() != Image.FORMAT_RGBA8:
		push_error("Walking master must already have real RGBA8 transparency")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var manifest: Array[Dictionary] = []
	for index in range(RECIPE.size()):
		var recipe: Dictionary = RECIPE[index]
		var crop := source.get_region(recipe.rect)
		crop.resize(roundi(crop.get_width() * SCALE), roundi(crop.get_height() * SCALE), Image.INTERPOLATE_LANCZOS)
		var output := Image.create(264, 264, false, Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		var position := Vector2i((RUNTIME_HIP - recipe.hip * SCALE).round())
		output.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), position)
		var path := OUTPUT + "walk-%02d.png" % index
		if output.save_png(path) != OK:
			push_error("Cannot save " + path)
			quit(1)
			return
		manifest.append({"frame": index, "source_rect": [recipe.rect.position.x, recipe.rect.position.y, recipe.rect.size.x, recipe.rect.size.y], "source_hip": [recipe.hip.x, recipe.hip.y], "scale": SCALE, "runtime_hip": [RUNTIME_HIP.x, RUNTIME_HIP.y], "alpha_rect": str(output.get_used_rect())})
	var file := FileAccess.open("res://art/characters/female/map-ghoul/frames-manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"source": SOURCE, "anchor": [132, 260], "canvas": [264, 264], "frames": manifest}, "\t") + "\n")
	print("FEMALE GHOUL FRAME EXPORT PASSED: 4 registered RGBA8 frames")
	quit()
