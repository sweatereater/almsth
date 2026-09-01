extends SceneTree

const Motion := preload("res://scripts/demo/female_ghoul_motion.gd")
const Demo := preload("res://scripts/demo/female_ghoul_walk.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_motion()
	_test_asset_contract()
	var demo := Demo.new()
	root.add_child(demo)
	demo.manual_control_enabled = false
	_expect(demo.dungeon_view.runtime_cell_size == 88, "Demo starts at 88; no settings are loaded")
	_expect(demo.floor_data["width"] == 12 and demo.floor_data["height"] == 7, "Fixed review map is 12x7")
	var snapshot: Dictionary = demo.state.to_snapshot_data()
	for pixels in [44, 66, 88]:
		demo.set_zoom(pixels)
		_expect(demo.dungeon_view.camera == Vector2.ZERO, "Map fits review viewport at every scale")
		_expect(demo.dungeon_view.presentation["player_visual"]["texture"] == demo.frames[0], "Viewport forwards override texture")
	_expect(demo.state.to_snapshot_data() == snapshot, "Changing presentation never mutates RunState")
	for form in GameRules.FORM_ORDER:
		demo.state.current_form_id = form
		_expect(Renderer.player_visual_texture(demo.state) == Renderer.PLAYER_SPRITES[form], "Empty override keeps default " + form)
		_expect(Renderer.player_visual_texture(demo.state, {"texture": demo.frames[1]}) == demo.frames[1], "Explicit texture overrides only presentation")
	demo.state.current_form_id = "almost_human"
	demo.state.highest_unlocked_form_index = 4
	demo.state.display_form_id = "ghoul"
	_expect(Renderer.player_visual_texture(demo.state) == Renderer.PLAYER_SPRITES["ghoul"], "Fallback keeps display form")
	_expect(Demo.TEXT.ru.keys() == Demo.TEXT.en.keys(), "Demo RU/EN keys match")
	demo.queue_free()
	Renderer.set_runtime_cell_size(66)
	await process_frame
	for failure in failures:
		push_error(failure)
	print("FEMALE GHOUL WALK TEST PASSED" if failures.is_empty() else "FEMALE GHOUL WALK TEST FAILED")
	quit(0 if failures.is_empty() else 1)


func _test_motion() -> void:
	var floor_data := Motion.make_floor()
	var motion := Motion.new()
	var start: Vector2i = motion.cell
	_expect(motion.frame_index() == 0 and motion.offset_cells() == Vector2.ZERO, "Idle begins planted without offset")
	motion.advance(12.0)
	_expect(motion.cell == start and motion.frame_index() == 0, "Idle never cycles")
	_expect(motion.begin_step(floor_data, Vector2i.RIGHT), "Adjacent floor starts a step")
	_expect(motion.offset_cells() == Vector2.LEFT and motion.facing_right, "Image starts at old cell and mirrors rightward")
	_expect(not motion.begin_step(floor_data, Vector2i.LEFT), "Direction change cannot interrupt a step")
	motion.advance(Motion.STEP_SECONDS * 0.5)
	_expect(motion.frame_index() == 1 and motion.offset_cells().is_equal_approx(Vector2(-0.5, 0.0)), "Half step advances limbs and image smoothly")
	motion.advance(Motion.STEP_SECONDS * 0.5)
	_expect(not motion.moving and motion.frame_index() == 2 and motion.offset_cells() == Vector2.ZERO, "Release finishes on the other grounded contact")
	motion.advance(1.0)
	_expect(motion.frame_index() == 2, "Idle retains the last contact; no snap to zero")
	_expect(motion.begin_step(floor_data, Vector2i.LEFT), "Return step begins")
	motion.advance(Motion.STEP_SECONDS * 0.75)
	_expect(motion.frame_index() == 3, "Return half uses recovery pose")
	motion.advance(100.0)
	_expect(motion.cell == start and motion.frame_index() == 0, "Large delta completes only the pending cell")
	motion.cell = Vector2i(6, 2)
	_expect(not motion.begin_step(floor_data, Vector2i.RIGHT), "Wall blocks motion")
	_expect(not motion.moving and motion.frame_index() == 0, "Blocked movement remains idle")
	motion.cell = Vector2i(8, 2)
	_expect(not motion.begin_step(floor_data, Vector2i.RIGHT), "Chest blocks preview movement")
	motion.cell = Vector2i(6, 3)
	_expect(motion.begin_step(floor_data, Vector2i.RIGHT), "Open door allows passage")
	motion.advance(Motion.STEP_SECONDS)
	_expect(motion.cell == Vector2i(7, 3), "Door movement remains one cell")
	motion.reset()
	_expect(not motion.begin_step(floor_data, Vector2i(1, 1)) and not motion.begin_step(floor_data, Vector2i.ZERO), "Diagonal and zero commands do not move")
	_expect(not motion.can_enter(floor_data, Vector2i(-1, 3)), "Out of bounds cannot be entered")
	for index in range(1000):
		var requested := Vector2i.RIGHT if index % 2 == 0 else Vector2i.LEFT
		_expect(motion.begin_step(floor_data, requested), "Repeated legal movement starts")
		motion.advance(Motion.STEP_SECONDS)
	_expect(motion.cell == start and motion.frame_index() == 0 and motion.offset_cells() == Vector2.ZERO, "1000 steps do not drift or accumulate animation error")


func _test_asset_contract() -> void:
	var hashes: Array[String] = []
	var lower_halves: Array[Image] = []
	for index in range(Motion.FRAME_COUNT):
		var path: String = Demo.FRAME_PATH % index
		var image := Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		_expect(image != null and image.get_size() == Vector2i(264, 264), "Frame canvas is 264 square")
		_expect(image.get_format() == Image.FORMAT_RGBA8, "Frame has real RGBA8 alpha")
		var used := image.get_used_rect()
		_expect(used.position.x >= 4 and used.position.y >= 4 and used.end.x <= 260 and used.end.y <= 260, "Four transparent border pixels remain in frame " + str(index))
		_expect(used.end.y >= 256, "Feet stay near common y=260 anchor")
		var hash := FileAccess.get_sha256(path)
		_expect(not hashes.has(hash), "Each frame contains distinct art")
		hashes.append(hash)
		lower_halves.append(image.get_region(Rect2i(0, 160, 264, 100)))
		var import_settings := ConfigFile.new()
		_expect(import_settings.load(path + ".import") == OK, "Texture has import contract")
		_expect(import_settings.get_value("params", "compress/mode") == 0, "Lossless texture import")
		_expect(import_settings.get_value("params", "process/fix_alpha_border") == true, "Alpha border fix enabled")
		_expect(import_settings.get_value("params", "mipmaps/generate") == false, "No mip chain for bounded prototype sizes")
	for index in range(1, lower_halves.size()):
		_expect(lower_halves[index].get_data() != lower_halves[index - 1].get_data(), "Leg art changes between poses, not just a canvas bob")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
